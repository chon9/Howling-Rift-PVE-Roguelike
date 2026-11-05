extends Node
var failures=0
var checks=0
var role="host"
var size=1
var game
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("PVP "+role+": "+message)
func until(predicate: Callable,seconds: float=15.) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<end:await get_tree().create_timer(.05).timeout
 return predicate.call()
func _ready() -> void:
 var args=OS.get_cmdline_user_args();role=args[0];size=int(args[1])
 Progression.fullscreen_enabled=false;Progression.frame_limit=120;Progression.vsync_enabled=false
 Progression.persistent=false;Progression.credits=54321;Progression.difficulty=99
 Progression.levels.clear();Progression.gear_stash.clear();Progression.daily.clear()
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game("pvp",size,false)==OK,"host opens PvP")
  LanSession.ready_player("ashe",["heal","ghost"],{"bonus_ad":10000})
  if not await until(func():return LanSession.players.size()==size*2 and LanSession.can_start()):
   check(false,"all human teams ready");get_tree().quit(1);return
  LanSession.start_match()
  check(await until(func():return GameState.running),"all peers finish asset loading before scenario")
  check(GameState.champions.filter(func(c):return c.roster_active).size()==size*2,"all active slots human")
  check(GameState.champions.filter(func(c):return c.roster_active).all(func(c):return not c.is_bot and c.permanent_bonus.is_empty()),"all humans have fair stats")
  check(await until(func():return GameState.champions.filter(func(c):return c.owner_peer>1).all(func(c):return c.summoner_cds[1]>0 and c.inventory.has("dagger"))),"commands from both teams execute on host")
  for c in GameState.champions:
   if c.owner_peer>1:c.grant_xp(Constants.xp_to_level(3))
  check(await until(func():return GameState.champions.filter(func(c):return c.owner_peer>1).all(func(c):return not c.run_bonus.is_empty())),"both teams apply their own level-up drafts")
  await get_tree().create_timer(2.).timeout
  var victim=GameState.champions[3]
  var killer=GameState.champions[0]
  if size>1:CombatParticipation.hit(GameState.champions[1],victim)
  var before=killer.gold
  game.deal_damage(killer,victim,100000.,"true")
  check(victim.dead and killer.gold>=before+Constants.HERO_KILL_GOLD and GameState.score[0]==1,"combat produces PvP kill gold and scoreboard")
  if size>1:check(GameState.champions[1].assists==1,"ally participation produces an assist")
  check(await until(func():return not victim.dead,8),"PvP respawn runs on host")
  await get_tree().create_timer(1.).timeout
  if size==1:
   var guest=GameState.champions[3];guest.gold=4321;guest.skill_cds[0]=30.
   var old_peer=guest.owner_peer
   multiplayer.multiplayer_peer.disconnect_peer(old_peer)
   check(await until(func():return not LanSession.disconnected.is_empty()),"host reserves disconnected slot")
   check(guest.roster_active and not guest.is_bot,"no-fill disconnected hero stays vulnerable")
   check(await until(func():return guest.owner_peer>1 and guest.owner_peer!=old_peer and LanSession.disconnected.is_empty(),20),"reconnect reclaims same red champion")
   check(guest.gold>=4321 and guest.inventory.has("dagger") and not guest.run_bonus.is_empty(),"reconnect preserves items gold and draft")
   if not OS.get_cmdline_user_args().has("--end-during-reconnect"):await get_tree().create_timer(2.).timeout
  game._end_game(Constants.RED)
  await get_tree().create_timer(2.).timeout
  check(Progression.credits==54321,"host gains no PvE credits")
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  if not await until(func():return LanSession.players.has(multiplayer.get_unique_id())):
   check(false,"lobby arrives");get_tree().quit(1);return
  LanSession.ready_player("ashe",["heal","ghost"],{"bonus_hp":10000})
  if not await until(func():return GameState.running):
   check(false,"match begins");get_tree().quit(1);return
  var p=GameState.player
  check(p.owner_peer==multiplayer.get_unique_id() and not p.is_bot,"owns local champion")
  check(GameState.is_pvp() and GameState.difficulty==1 and p.permanent_bonus.is_empty(),"fair PvP snapshot")
  check(GameState.champions.filter(func(c):return c.roster_active).size()==size*2,"guest sees correct roster")
  p.try_buy_item("dagger")
  check(await until(func():return p.inventory.has("dagger")),"purchase replicated")
  game.cast_summoner(p,1)
  check(await until(func():return p.summoner_cds[1]>0),"summoner replicated")
  var destination=p.world_pos()+Vector2(-100 if p.team==1 else 100,0)
  game._issue_player_order({"type":"smart","point":destination})
  check(await until(func():return p.world_pos().distance_to(destination)<25,4),"red and blue movement replicated")
  check(await until(func():return not game.lane_augments.choices.is_empty()),"own draft arrives")
  if not game.lane_augments.choices.is_empty():game.lane_augments.choose(game.lane_augments.choices[0])
  check(await until(func():return not p.run_bonus.is_empty()),"own draft confirmed")
  check(await until(func():return GameState.score[0]==1),"kill scoreboard replicated")
  if p==GameState.champions[3]:
   check(p.dead,"victim death replicated")
   check(await until(func():return not p.dead,8),"victim respawn replicated")
  if p==GameState.champions[1]:check(p.assists==1,"assist replicated")
  if size==1:
   check(await until(func():return not LanSession.active),"network interruption received")
   check(LanSession.can_reconnect(),"reconnect option retained")
   check(LanSession.reconnect_game()==OK,"reconnect opens")
   if OS.get_cmdline_user_args().has("--end-during-reconnect"):
    check(await until(func():return not LanSession.pending_finish.is_empty()),"match result buffers during native warmup")
   check(await until(func():return GameState.started and LanSession.match_started and not LanSession.resume_requested),"resumed match rebuilds")
   p=GameState.player
   check(await until(func():return p.gold>=4321 and p.inventory.has("dagger") and p.skill_cds[0]>0),"same champion inventory cooldown and gold restored")
   check(p.team==1 and not p.run_bonus.is_empty(),"red team and draft restored")
   if OS.get_cmdline_user_args().has("--end-during-reconnect"):check(LanSession.pending_finish.is_empty() and not GameState.running,"buffered result applies after warmup")
  check(await until(func():return GameState.started and not GameState.running,20),"authoritative victory received")
  check(Progression.credits==54321 and Progression.gear_stash.is_empty(),"guest gains no PvE credits or drops")
 print("PVP network %dv%d %s: %d checks, %d failures" % [size,size,role,checks,failures])
 LanSession.leave();game.queue_free();GameState.reset()
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
