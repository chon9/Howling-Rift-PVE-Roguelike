extends Node
var checks=0
var failures=0
var role="host"
var mode="pve"
var drop_test=false
var game
var finished={}
var release=false
class SlowMain extends "res://scripts/Main.gd":
 func _start_network_match(config: Dictionary) -> void:
  await get_tree().create_timer(2.5).timeout
  if get_meta("drop",false):_return_to_main_menu();return
  super._start_network_match(config)
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("LOADING NETWORK "+role+": "+message)
func until(predicate: Callable,seconds: float=15.) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000.)
 while not predicate.call() and Time.get_ticks_msec()<end:await get_tree().create_timer(.02).timeout
 return predicate.call()
@rpc("any_peer","call_remote","reliable")
func done() -> void:finished[multiplayer.get_remote_sender_id()]=true
@rpc("authority","call_remote","reliable")
func finish() -> void:release=true
func _ready() -> void:
 var args=OS.get_cmdline_user_args();role=args[0];mode=args[1] if args.size()>1 and args[1] in ["pve","pvp"] else "pve"
 drop_test=args.has("--drop-test")
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.vsync_enabled=false;Progression.frame_limit=120
 game=SlowMain.new() if role in ["slow","drop"] else load("res://scripts/Main.gd").new();add_child(game);game.force_match_loading=true;game.set_meta("drop",role=="drop")
 if role=="host":
  check(LanSession.host_game(mode,2,true)==OK,"host creates room")
  LanSession.ready_player("yasuo",["heal","ghost"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"three peers ready")
  LanSession.start_match()
  check(not GameState.running and LanSession.loading_match,"host enters loading barrier")
  check(await until(func():return GameState.started and game.match_loader!=null and not game.match_loader.pending),"host finishes its own warmup")
  check(LanSession.loading_match and not GameState.running,"host waits for slow guest after its own loading")
  var wait_start=Time.get_ticks_msec()
  var end=Time.get_ticks_msec()+15000
  while not GameState.running and Time.get_ticks_msec()<end:
   check(GameState.time==0. and GameState.minions.is_empty() and GameState.score==[0,0],"no combat or farming during barrier")
   await get_tree().create_timer(.04).timeout
  check(GameState.running and not LanSession.loading_match,"host releases when everyone acknowledges")
  check(Time.get_ticks_msec()-wait_start>600,"deliberately slow guest actually held the barrier")
  check(LanSession.loaded_peers.size()==(2 if drop_test else 3),"host received acknowledgements from every remaining player")
  if drop_test:check(LanSession.players.size()==2 and GameState.champions.filter(func(c):return c.owner_peer>1).size()==1,"departing player does not hold barrier or keep a human-owned slot")
  check(await until(func():return finished.size()==(1 if drop_test else 2)),"both guests finish checks")
  finish.rpc()
  await get_tree().create_timer(.3).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest joins")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives")
  LanSession.ready_player("janna" if role=="slow" else "thresh",["heal","ghost"],{})
  if role=="drop":
   check(await until(func():return not LanSession.active),"guest can leave during loading")
   game.queue_free();await get_tree().process_frame
   print("MATCH LOADING NETWORK drop: %d checks, %d failures" % [checks,failures]);get_tree().quit(0 if failures==0 else 1);return
  check(await until(func():return GameState.running),"guest starts after barrier release")
  check(not LanSession.loading_match and game.match_loader!=null and not game.match_loader.pending,"guest never starts before its own assets finish")
  check(GameState.match_mode==mode,"correct PvE/PvP mode")
  check(game.match_loader.errors.is_empty(),"guest has all required assets")
  check(not is_instance_valid(game.match_loader.overlay),"guest loading screen dismissed")
  done.rpc_id(1)
  check(await until(func():return release),"host confirmed checks")
 print("MATCH LOADING NETWORK %s %s: %d checks, %d failures" % [mode,role,checks,failures])
 LanSession.leave();game.queue_free();GameState.reset()
 for frame in range(4):await get_tree().process_frame
 get_tree().quit(0 if failures==0 else 1)
