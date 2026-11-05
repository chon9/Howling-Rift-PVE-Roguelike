extends Node
var role="host"
var checks=0
var failures=0
var game
var observers={}
var times=[]
var serials={}
var saw_lock=false
var saw_boundary=false
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL DEADEYE COOP "+role+": "+message)
func until(predicate: Callable,seconds: float=12.) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.025).timeout
 return predicate.call()
@rpc("any_peer","call_remote","reliable")
func ready_observer() -> void:
 if LanSession.is_host():observers[multiplayer.get_remote_sender_id()]=true
func _process(delta: float) -> void:
 if not GameState.started:return
 if LanSession.is_host() and observers.size()<2:LanSession.replicate(delta)
 var caster=GameState.champions[0]
 var charge=DeadeyeCue.channel(caster)
 if not charge.is_empty():
  serials[charge.serial]=true
  if times.size()<200:times.append(charge.time)
  saw_lock=saw_lock or DeadeyeCue.locks_on(GameState.champions[3]).size()==1
 for a in GameState.aoes:
  if a.effect_id=="brand_w" and a.readable_boundary:saw_boundary=true
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game()==OK,"host starts")
  LanSession.ready_player("caitlyn",["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"guests ready")
  LanSession.start_match();game.set_process(false)
  for i in range(GameState.champions.size()):
   var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.global_position=Vector2(2500,270)
   c.skill_ranks=[1,1,1,1];c.hp_max=50000.;c.hp=50000.;c.hp_regen=0.;c.mp_max=1000.;c.mp=1000.
  var caster=GameState.champions[0];var target=GameState.champions[3]
  caster.global_position=Vector2(1250,270);target.global_position=Vector2(1600,270)
  game.camera.global_position=caster.world_pos()
  check(await until(func():return observers.size()==2),"both clients ready to observe")
  var area=game.AoES.new();game.world_root.add_child(area)
  area.setup(caster,Vector2(1450,380),{"effect_id":"brand_w","radius":65.,"dmg":100.,"arm_delay":2.,"duration":8.})
  GameState.aoes.append(area)
  for frame in range(190):
   if frame in [5,100]:
    caster.skill_cds[3]=0.;caster.mp=caster.mp_max;caster.stop_actions()
    check(caster.try_cast_skill(3,target.world_pos()),"host starts charge")
   if frame==120:caster.has_move_target=true;caster.move_target=caster.world_pos()+Vector2(-100,0)
   for c in GameState.champions:c.update_frame(.02)
   for p in GameState.projectiles.duplicate():if is_instance_valid(p) and not p.is_queued_for_deletion():p.update_frame(.02)
   for a in GameState.aoes.duplicate():if is_instance_valid(a) and not a.is_queued_for_deletion():a.update_frame(.02)
   GameState.time+=.02;LanSession.replicate(.02)
   await get_tree().create_timer(.02).timeout
   if frame==25 and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("res://tests/deadeye-coop-host.png")
  check(target.hp<target.hp_max,"first shot lands")
  game._end_game(Constants.BLUE);await get_tree().create_timer(.6).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives")
  LanSession.ready_player("leona" if role=="client1" else "brand",["flash","heal"],{})
  check(await until(func():return GameState.started),"match arrives")
  game.set_process(false)
  check(await until(func():return GameState.champions[0].skill_ranks[3]>0),"ranks arrive")
  game.camera.global_position=Vector2(1400,270)
  ready_observer.rpc_id(1)
  check(await until(func():return not GameState.running,15.),"match completes")
 check(serials.size()==2,"both charge serials observed")
 check(times.size()>3 and times.min()<.3 and times.max()>.7,"countdown runs across received authoritative timings")
 check(saw_lock,"correct enemy has visible target lock")
 check(saw_boundary,"ground boundary reaches every peer")
 check(int(game.sound_fx.counts.get("deadeye_charge",0))==2,"charge audio plays once for each cast")
 check(int(game.sound_fx.counts.get("gun_ultimate",0))==1,"only completed cast plays firing audio")
 check(DeadeyeCue.channel(GameState.champions[0]).is_empty(),"interrupted lock removed on all peers")
 check(game.sound_fx.charge_voices.is_empty(),"interrupted charge audio removed")
 if role=="host":await until(func():return LanSession.players.size()==1,3.)
 else:await get_tree().create_timer(.3 if role=="client1" else .6).timeout
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 print("DEADEYE COOP %s: %d checks, %d failures" % [role,checks,failures])
 get_tree().quit(0 if failures==0 else 1)
