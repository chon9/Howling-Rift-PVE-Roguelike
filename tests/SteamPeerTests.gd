extends Node
# Run on two PCs with separate Steam accounts; never simulates Steam transport.
var failures=0
var probes={}
var game
var role="host"
func check(value: bool, message: String) -> void:
 if not value:failures+=1;push_error("FAIL "+role+": "+message)
func until(predicate: Callable, seconds: float=90) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
 return predicate.call()
@rpc("any_peer","call_remote","reliable",0)
func probe_state(value: String) -> void:
 if LanSession.is_host() and value=="state":probes[0]=true
@rpc("any_peer","call_remote","reliable",1)
func probe_command(value: String) -> void:
 if LanSession.is_host() and value=="command":probes[1]=true
@rpc("any_peer","call_remote","unreliable",2)
func probe_effect(value: String) -> void:
 if LanSession.is_host() and value=="effect":probes[2]=true
func _ready() -> void:
 await get_tree().process_frame
 var args=OS.get_cmdline_user_args()
 var index=args.find("--steam-test")
 if index>=0 and index+1<args.size():role=args[index+1]
 check(SteamSession.available,"Steam available")
 if not SteamSession.available:get_tree().quit(1);return
 Progression.persistent=false;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(SteamSession.host_game()==OK,"host request")
  if not await until(func():return LanSession.is_host(),30):get_tree().quit(1);return
  print("STEAM TEST LOBBY CODE: ",SteamSession.lobby_id)
  LanSession.ready_player("yasuo",["flash","heal"],{})
  if not await until(func():return LanSession.players.size()>=2 and LanSession.can_start()):
   check(false,"remote ready guest joined");LanSession.leave();get_tree().quit(1);return
  LanSession.start_match()
  check(GameState.started,"shared Steam ARAM starts")
  var guest=GameState.champions.filter(func(c):return c.owner_peer>1)[0]
  guest.gold=2000;guest.grant_xp(Constants.xp_to_level(3))
  var origin=guest.global_position
  check(await until(func():return probes.size()==3,20),"all three Steam RPC channels delivered")
  check(await until(func():return guest.inventory.has("dagger") and guest.skill_ranks[0]==2,20),"guest buy and rank commands applied at authority")
  check(guest.global_position.distance_to(origin)>5,"remote guest moved")
  await get_tree().create_timer(2).timeout
 else:
  if index+2>=args.size():push_error("Supply host lobby code after guest");get_tree().quit(1);return
  check(SteamSession.join_game(args[index+2])==OK,"guest join request")
  if not await until(func():return LanSession.players.size()>=2,30):check(false,"guest lobby roster synced");get_tree().quit(1);return
  LanSession.ready_player("leesin",["flash","ghost"],{})
  if not await until(func():return GameState.started):check(false,"shared match starts");get_tree().quit(1);return
  check(GameState.player.hero_key=="leesin","guest owns selected hero")
  check(await until(func():return GameState.player.gold>=2000,20),"host state snapshot received")
  for i in range(8):
   probe_state.rpc_id(1,"state");probe_command.rpc_id(1,"command");probe_effect.rpc_id(1,"effect")
   await get_tree().create_timer(.1).timeout
  LanSession.send_command("buy",{"id":"dagger"})
  LanSession.send_command("rank",{"index":0})
  LanSession.send_command("order",{"type":"smart","point":GameState.player.world_pos()+Vector2(180,0)})
  check(await until(func():return GameState.player.inventory.has("dagger") and GameState.player.skill_ranks[0]==2,20),"authoritative purchase and skill rank replicate to guest")
  await get_tree().create_timer(3).timeout
 print("STEAM TWO-PC %s: %d failures" % [role,failures])
 LanSession.leave();get_tree().quit(1 if failures else 0)
