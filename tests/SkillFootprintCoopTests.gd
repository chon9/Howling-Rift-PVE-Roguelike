extends Node
var role="host"
var checks=0
var failures=0
var game
var observers={}
var seen={}
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL FOOTPRINT COOP "+role+": "+message)
func until(predicate: Callable,seconds: float=15.) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<end:await get_tree().create_timer(.025).timeout
 return predicate.call()
@rpc("any_peer","call_remote","reliable")
func ready_observer() -> void:
 if LanSession.is_host():observers[multiplayer.get_remote_sender_id()]=true
func _process(delta: float) -> void:
 if not GameState.started:return
 if LanSession.is_host() and observers.size()<2:LanSession.replicate(delta)
 for a in GameState.aoes:
  if a.effect_id=="xerath_q" and a.footprint_kind=="capsule" and a.footprint_width==30. and a.effect_dir==Vector2.DOWN and a.radius==300.:seen.beam=true
  if a.effect_id=="syndra_e" and a.footprint().shape=="cone" and is_equal_approx(a.arc,PI*2./3.) and a.cone_ang==PI*.5:seen.cone=true
  if a.effect_id=="thresh_e" and a.footprint_kind=="rectangle" and a.footprint_width==65. and a.effect_dir==Vector2.LEFT:seen.flay=true
  if a.zone_kind=="box" and a.broken_walls[2]:seen.broken_wall=true
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game()==OK,"host starts");LanSession.ready_player("xinzhao",["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"two guests ready")
  LanSession.start_match();game.set_process(false)
  for c in GameState.champions:c.is_bot=false;c.stop_actions()
  check(await until(func():return observers.size()==2),"both guests observing")
  var caster=GameState.player
  for opts in [
   {"effect_id":"xerath_q","radius":300.,"footprint_kind":"capsule","footprint_width":30.,"effect_dir":Vector2.DOWN},
   {"effect_id":"syndra_e","radius":210.,"cone_ang":PI*.5,"arc":PI*2./3.},
   {"effect_id":"thresh_e","radius":220.,"footprint_kind":"rectangle","footprint_width":65.,"effect_dir":Vector2.LEFT},
   {"effect_id":"thresh_r","radius":180.,"zone_kind":"box"}]:
   opts.duration=4.;game.spawn_aoe(caster,caster.world_pos(),opts)
  GameState.aoes.back().broken_walls[2]=true
  for i in range(40):GameState.time+=.04;LanSession.replicate(.04);await get_tree().create_timer(.04).timeout
  game._end_game(Constants.BLUE);await get_tree().create_timer(.5).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby received")
  LanSession.ready_player("xerath" if role=="client1" else "lucian",["flash","heal"],{})
  check(await until(func():return GameState.started),"match received")
  # started is set before the host releases the loading barrier; "not running" must mean the match ended, not that it is still loading.
  check(await until(func():return GameState.running),"match loading released")
  game.set_process(false);ready_observer.rpc_id(1)
  check(await until(func():return not GameState.running),"result received")
 for id in ["beam","cone","flay","broken_wall"]:check(seen.has(id),id+" has correct replicated hit geometry")
 LanSession.leave();print("FOOTPRINT COOP %s: %d checks, %d failures" % [role,checks,failures]);get_tree().quit(1 if failures else 0)
