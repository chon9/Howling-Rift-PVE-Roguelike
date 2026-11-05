extends Node
var role="host"
var failures=0
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error("FAIL HOOK COOP "+role+": "+message)
func until(predicate: Callable,seconds: float=8.) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.025).timeout
 return predicate.call()
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false;GameState.reset()
 var game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game()==OK,"host starts")
  LanSession.ready_player("thresh",["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"two guests ready")
  LanSession.start_match();game.set_process(false)
  for c in GameState.champions:c.is_bot=false;c.global_position=Vector2(1200,270) if c.team==0 else Constants.FOUNT_R
  var hero=GameState.player;hero.global_position=Vector2(1320,270)
  check(ExpansionKits.cast(hero,"thresh_q",Vector2(1700,270)),"host fires real hook")
  var hook=GameState.projectiles.back();hook.global_position=Vector2(1640,270)
  for frame in range(75):
   if frame==25:hero.global_position+=Vector2(30,20)
   GameState.time+=.04;LanSession.replicate(.04);await get_tree().create_timer(.04).timeout
  game._end_game(Constants.BLUE);await get_tree().create_timer(1.).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest joins")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives")
  LanSession.ready_player("vayne" if role=="client1" else "lux",["flash","heal"],{})
  check(await until(func():return GameState.started),"match arrives")
  check(await until(func():return GameState.projectiles.any(func(p):return p.hook_chain)),"hook arrives over chunked network")
  var hooks=GameState.projectiles.filter(func(p):return p.hook_chain)
  if not hooks.is_empty():
   var hook=hooks[0]
   check(hook.src==GameState.champions[0] and hook.src.hero_key=="thresh","remote owner is restored")
   check(hook.hook_world_segment().size()==2 and hook.effect_id=="thresh_q","guest can draw real chain and current hook animation")
   var initial=hook.hook_world_segment()[0]
   check(await until(func():return hook.hook_world_segment()[0].distance_to(initial)>20),"chain anchor follows authoritative hero movement")
  check(await until(func():return not GameState.running),"result arrives reliably")
 print("HOOK COOP "+role+": "+str(failures)+" failures")
 await get_tree().create_timer(.2).timeout
 LanSession.leave();game.queue_free();GameState.reset()
 await get_tree().process_frame;await get_tree().process_frame
 get_tree().quit(0 if failures==0 else 1)
