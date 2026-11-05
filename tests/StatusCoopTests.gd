extends Node
var role="host"
var checks=0
var failures=0
var game
var observers={}
var seen_silence=false
var seen_slow=false
var seen_shield=false
var times=[]
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL STATUS COOP "+role+": "+message)
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
 var target=GameState.champions[3];var fx=target.get_node("StatusVisual");fx.refresh()
 if fx.silence_remaining>0:
  seen_silence=seen_silence or fx.visible and fx.primary_status.label=="SILENCED" and target.visible
  if times.size()<200:times.append(fx.silence_remaining)
 seen_slow=seen_slow or fx.statuses.any(func(s):return s.id=="slow")
 var caster_fx=GameState.champions[0].get_node("StatusVisual");caster_fx.refresh()
 seen_shield=seen_shield or caster_fx.shield_amount>0 and caster_fx.statuses.any(func(s):return s.id=="shield")
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game()==OK,"host starts")
  LanSession.ready_player("garen",["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"guests ready")
  LanSession.start_match();game.set_process(false)
  for i in range(6):
   var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.global_position=Vector2(1400+i*80,270)
   c.skill_ranks=[1,1,1,1];c.hp_max=50000.;c.hp=50000.;c.hp_regen=0.;c.mp_max=1000.;c.mp=1000.;c.buffs.clear();c.shield=0.;c.ad=80.;c.inventory=["","","","","",""]
  var caster=GameState.champions[0];var target=GameState.champions[3]
  caster.global_position=Vector2(1250,270);target.global_position=Vector2(1330,270)
  check(await until(func():return observers.size()==2),"both clients observing")
  for frame in range(100):
   if frame==5:
    check(caster.try_cast_skill(0,target.world_pos()),"real Bastion Q casts")
    caster._perform_auto(target);CombatEffects.shield(caster,"test_shield",180.,2.)
    target.buffs.slow={"time":2.,"pct":.4}
    check(not target.try_cast_skill(0,caster.world_pos()),"host enforces silence")
   for c in GameState.champions:c.update_frame(.03)
   GameState.time+=.03;LanSession.replicate(.03)
   await get_tree().create_timer(.03).timeout
  game._end_game(Constants.BLUE);await get_tree().create_timer(.6).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby received")
  LanSession.ready_player("lux" if role=="client1" else "leona",["flash","heal"],{})
  check(await until(func():return GameState.started),"match received")
  # started is set before the host releases the loading barrier; "not running" must mean the match ended, not that it is still loading.
  check(await until(func():return GameState.running),"match loading released")
  game.set_process(false);ready_observer.rpc_id(1)
  check(await until(func():return not GameState.running,15.),"match completes")
 check(seen_silence,"silence icon, name and enemy model visible on this peer")
 check(seen_slow and seen_shield,"simultaneous slow and shield reach this peer")
 check(times.size()>3 and times.min()<.3 and times.max()>1.2,"remaining duration counts down from host snapshots")
 var fx=GameState.champions[3].get_node("StatusVisual");fx.refresh()
 check(fx.silence_remaining==0 and not fx.statuses.any(func(s):return s.id=="silence"),"expired silence removes cue on every peer")
 if role=="host":await until(func():return LanSession.players.size()==1,3.)
 else:await get_tree().create_timer(.3 if role=="client1" else .6).timeout
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 print("STATUS COOP %s: %d checks, %d failures" % [role,checks,failures]);get_tree().quit(1 if failures else 0)
