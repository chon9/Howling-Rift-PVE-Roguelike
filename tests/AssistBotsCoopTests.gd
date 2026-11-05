extends Node
var role="host"
var game
var checks=0
var failures=0
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL ASSIST COOP "+role+": "+text)
func until(predicate: Callable,seconds: float=10.) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.025).timeout
 return predicate.call()
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false;Progression.allied_bots=role!="host";GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game)
 var key="lux" if role=="host" else "leesin" if role=="client1" else "garen"
 if role=="host":
  check(LanSession.host_game()==OK,"host starts");LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"two guests ready");LanSession.start_match();game.set_process(false)
  check(not GameState.allied_bots,"host chooses human-only rule")
  for c in GameState.champions:c.is_bot=false;c.hp_max=50000.;c.hp=50000.;c.stop_actions()
  var helper=GameState.champions.filter(func(c):return c.hero_key=="leesin" and c.team==0)[0]
  var quitter=GameState.champions.filter(func(c):return c.hero_key=="garen" and c.team==0)[0]
  var enemy=GameState.champions[3]
  helper.gold=1000
  game._tick_economy(2.)
  check(helper.gold==1000 and is_equal_approx(helper.passive_gold_remainder,.4),"host retains fractional passive gold")
  game.deal_damage(helper,enemy,20.,"magic");helper.position=Vector2(0,0);game._handle_death(GameState.player,enemy)
  check(helper.gold==1000+CombatParticipation.ASSIST_GOLD and helper.assists==1,"server awards recent contributor once")
  check(GameState.player.gold==1600 and is_equal_approx(GameState.player.xp,320.4),"host awards doubled kill reward with reduced passive XP")
  GameState.player.passive_state.assist_phase=1
  for frame in range(25):LanSession.replicate(.05);await get_tree().create_timer(.05).timeout
  check(await until(func():return LanSession.players.size()==2,5.),"guest disconnect arrives")
  check(not quitter.roster_active and quitter.dead and not quitter.is_targetable,"disconnected guest removed rather than bot-filled")
  game._tick_economy(3.)
  check(helper.gold==1001+CombatParticipation.ASSIST_GOLD and is_zero_approx(helper.passive_gold_remainder),"five seconds pays exactly one passive gold")
  GameState.player.passive_state.assist_phase=2
  for frame in range(25):LanSession.replicate(.05);await get_tree().create_timer(.05).timeout
  game._end_game(Constants.BLUE);await get_tree().create_timer(.7).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives");LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return GameState.started),"match arrives");game.set_process(false)
  check(not GameState.allied_bots and GameState.player.roster_active,"host rule replicated without removing humans")
  check(await until(func():return GameState.champions[0].passive_state.get("assist_phase",0)==1),"assist result arrives")
  var helper=GameState.champions.filter(func(c):return c.hero_key=="leesin" and c.team==0)[0]
  check(helper.gold==1000+CombatParticipation.ASSIST_GOLD and helper.assists==1,"gold and KDA replicated exactly")
  check(GameState.champions[0].gold==1600 and is_equal_approx(GameState.champions[0].xp,320.4),"doubled hero kill reward and fractional XP replicated")
  if role=="client1":
   check(await until(func():return GameState.champions[0].passive_state.get("assist_phase",0)==2),"disconnect phase arrives")
   check(helper.gold==1001+CombatParticipation.ASSIST_GOLD,"fractional passive payout replicated as integer gold")
   var quitter=GameState.champions.filter(func(c):return c.hero_key=="garen" and c.team==0)[0]
   check(not quitter.roster_active and quitter.dead and not quitter.visible,"inactive slot replicated and hidden")
   game.hud.get_node("HudRoot").scoreboard.refresh()
   check(not game.hud.get_node("HudRoot").scoreboard.rows[quitter].panel.visible,"disconnected slot removed from guest scoreboard")
   check(await until(func():return not GameState.running),"result arrives")
  else:await get_tree().create_timer(.5).timeout
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 print("ASSIST COOP %s: %d checks, %d failures" % [role,checks,failures]);get_tree().quit(0 if failures==0 else 1)
