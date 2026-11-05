extends Node
var role="host"
var game
var checks=0
var failures=0
var completed={}
var released=false
var single=false
var partial=false
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BUILD NETWORK "+role+": "+message)
func until(predicate: Callable,seconds: float=15.) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000.)
 while not predicate.call() and Time.get_ticks_msec()<end:await get_tree().create_timer(.03).timeout
 return predicate.call()
@rpc("any_peer","call_remote","reliable")
func done() -> void:completed[multiplayer.get_remote_sender_id()]=true
@rpc("authority","call_remote","reliable")
func release() -> void:released=true
func _process(delta: float) -> void:
 if LanSession.is_host() and GameState.running:
  GameState.time+=delta;LanSession.replicate(delta)
func record(key: String) -> Dictionary:
 return BuildStealer.validate({"hero":key,"name":"Previous Champion","stage":14,"kills":20,"deaths":2,"assists":4,"won":true,"items":["boots"] if partial else ["berserker_greaves","infinity_edge","bloodthirster","phantom_dancer","warmog","lord_dominik"] if key=="ashe" else ["sorcerer_shoes","rabadon","void_staff","ludens","banshee","warmog"],"augments":[{"level":4,"index":0 if key=="ashe" else 1,"stats":{"bonus_as":.3} if key=="ashe" else {"bonus_ap":32.}}],"spells":["heal","ghost"],"skill_order":[{"index":0,"rank":2}],"elixirs":{}})
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];single=OS.get_cmdline_user_args().has("--single-hero");Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.difficulty=7;Progression.build_records.clear()
 partial=OS.get_cmdline_user_args().has("--partial-build")
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 if role=="host":
  Progression.build_records=[record("ashe"),record("lux")]
  if single:
   var weaker=record("ashe");weaker.stage=1;weaker.items=["long_sword"];Progression.build_records=[weaker,record("ashe")]
  check(LanSession.host_game()==OK,"host creates room")
  LanSession.ready_player("ashe" if single else "garen",["heal","ghost"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"three players ready")
  LanSession.start_match();check(await until(func():return GameState.running),"shared match begins")
  var echoes=GameState.champions.filter(func(c):return not c.stolen_blueprint.is_empty())
  check(echoes.size()==(1 if single else 2),"host has one Echo per distinct archived hero, capped at two")
  check(distinct(GameState.champions.filter(func(c):return c.team==1).map(func(c):return c.hero_key)).size()==3,"host enemy heroes never repeat")
  for bot in echoes:
   bot.gold=50000
   for attempt in range(30):
    if bot.stolen_blueprint.items.all(func(id):return bot.inventory.has(id)):break
    if not bot._bot_buy_next():break
   bot.level=4;bot.skill_points=1;bot._bot_spend_points();game.lane_augments.on_level_up(bot)
  check(await until(func():return completed.size()==2),"both guests see learned builds and stats")
  completed.clear()
  if partial:
   for bot in echoes:
    for attempt in range(30):
     if not bot._bot_buy_next():break
    for level in [5,6]:
     bot.level=level;bot.skill_points=1;bot._bot_spend_points();game.lane_augments.on_level_up(bot)
    check(bot.stolen_items_complete and not bot.inventory.has("boots") and bot.inventory.count("")<=2 and not bot.consumable_counts.is_empty(),"host continues original items and consumables after saved boots")
    check(bot.augment_history.size()==2 and bot.skill_history.size()==3,"host continues normal skill ranks and level-up upgrades")
   check(await until(func():return completed.size()==2),"both guests see original progression after the saved path ends")
   completed.clear()
  for c in GameState.champions:
   if c.owner_peer>0:
    c.kills=15;c.deaths=2;c.inventory=["long_sword","","","","",""];c.purchase_history=["long_sword"]
  game._end_game(Constants.BLUE)
  check(Progression.build_records.size()==(1 if single else 5),"host keeps one best blueprint per qualifying hero")
  if single:check(Progression.build_records[0].stage==14 and Progression.build_records[0].items.size()==6,"lower-scored same-hero co-op runs cannot replace the archived build")
  check(await until(func():return completed.size()==2),"guests receive end report")
  release.rpc();await get_tree().create_timer(.3).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives")
  LanSession.ready_player("ashe" if single else "janna" if role=="guest1" else "soraka",["heal","ghost"],{})
  check(await until(func():return GameState.running),"shared match begins")
  var echoes=GameState.champions.filter(func(c):return not c.stolen_blueprint.is_empty())
  check(echoes.size()==(1 if single else 2) and GameState.champions.filter(func(c):return c.team==1 and c.stolen_blueprint.is_empty()).size()==(2 if single else 1),"guest sees matching Echo and normal-opponent counts")
  check(distinct(GameState.champions.filter(func(c):return c.team==1).map(func(c):return c.hero_key)).size()==3,"guest enemy heroes never repeat")
  if single:check(GameState.champions.filter(func(c):return c.team==0).all(func(c):return c.hero_key=="ashe") and echoes[0].hero_key=="ashe","co-op allows duplicate allied heroes and an enemy mirror")
  check(await until(func():return echoes.all(func(c):return c.stolen_blueprint.items.all(func(id):return c.inventory.has(id)) and not c.run_bonus.is_empty() and c.skill_ranks[0]==2)),"items, rolled upgrades and skill path synchronize")
  for bot in echoes:
   var upgrade=bot.stolen_blueprint.augments[0]
   check(bot.hero_key==bot.stolen_blueprint.hero and bot.summoner_spells==["heal","ghost"],"right hero and summoners")
   check(bot.run_bonus==upgrade.stats,"exact recorded roll reaches guest")
   check(bot.permanent_bonus.is_empty() and bot.stolen_blueprint.stage==14 and is_equal_approx(bot.difficulty_stats.health,Progression.scaling(7).health),"current difficulty applies, source stage is metadata")
  done.rpc_id(1)
  if partial:
   check(await until(func():return echoes.all(func(c):return c.level==6 and c.skill_ranks.reduce(func(total,value):return total+value,0)==6 and c.run_bonus!=c.stolen_blueprint.augments[0].stats and not c.inventory.has("boots") and c.inventory.count("")<=2 and not c.consumable_counts.is_empty())),"continued original items, skill ranks, upgrades and elixirs synchronize")
   done.rpc_id(1)
  check(await until(func():return not GameState.running),"final result arrives")
  check(Progression.build_records.is_empty(),"guest never writes host's learned builds to its own archive")
  check(game.hud.get_node("HudRoot").end_stats.text.contains("3 qualifying"),"host learning report reaches guests")
  done.rpc_id(1);check(await until(func():return released),"host completes scenario")
 print("BUILD STEALER NETWORK %s: %d checks, %d failures" % [role,checks,failures])
 LanSession.leave();game.queue_free();GameState.reset()
 for frame in range(4):await get_tree().process_frame
 get_tree().quit(0 if failures==0 else 1)

func distinct(values: Array) -> Dictionary:
 var seen={}
 for value in values:seen[value]=true
 return seen
