extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BUILD STEALER: "+message)
func raw(hero: String="ashe",stage: int=1,kills: int=15,deaths: int=3,items: Array=["berserker_greaves","infinity_edge","phantom_dancer","bloodthirster","lord_dominik","warmog"]) -> Dictionary:
 return {"hero":hero,"name":"Test Player","stage":stage,"kills":kills,"deaths":deaths,"assists":5,"won":true,"items":items,"augments":[{"level":4,"index":0,"stats":{"bonus_as":.3}}],"elixirs":{"training_ad":2},"skill_order":[{"index":0,"rank":2},{"index":3,"rank":1}],"spells":["heal","ghost"]}
func reset(blue: Array=["ashe","lux","garen"],red: Array=["zed","thresh","leesin"],stolen: Array=[]) -> void:
 if GameState.started:game._return_to_main_menu();game.set_process(false)
 game.network_config={"mode":"pve","allied_bots":true,"blue":blue,"red":red,"stolen_builds":stolen,"players":[{"peer":1,"slot":0,"name":"You","spells":["flash","ignite"],"bonuses":{}}]}
 game._start_game(blue[0]);game.set_process(false)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.build_records.clear();Progression.levels.clear();Progression.difficulty=1
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);reset()
 check(not BuildStealer.qualifies(14,0) and not BuildStealer.qualifies(15,4),"strict minimum kills and K/D")
 check(BuildStealer.qualifies(15,3) and BuildStealer.qualifies(15,0),"threshold boundary and deathless run")
 var record=BuildStealer.validate(raw())
 check(not record.is_empty() and record.stage==1 and record.score>0,"valid scored record")
 var tampered=raw();tampered.score=999999999;tampered.permanent_bonus={"bonus_ad":999999};tampered.augments[0].stats.bonus_as=INF
 check(BuildStealer.validate(tampered).is_empty(),"non-finite upgrade rejected")
 tampered=raw();tampered.score=999999999;tampered.permanent_bonus={"bonus_ad":999999}
 var safe=BuildStealer.validate(tampered)
 check(safe.score==record.score and not safe.has("permanent_bonus"),"score recalculated and permanent account fields stripped")
 for invalid in [raw("unknown"),raw("ashe",1,14),raw("ashe",1,15,4),raw("ashe",1,15,0,["missing"]),raw("ashe",1,15,0,["training_ad"]),raw("ashe",1,15,0,["boots","berserker_greaves"])]:check(BuildStealer.validate(invalid).is_empty(),"malformed or ineligible record rejected")
 var candidates=[]
 for i in range(20):candidates.append(raw("ashe",i+1,15+i,2))
 var best=BuildStealer.ranked(candidates)
 # Every hero occupies one slot regardless of changed items, spells or rolls.
 check(best.size()==1,"identical builds keep only their best performance")
 var alternate=raw("ashe",30,20,2,["long_sword"]);alternate.spells=["flash","ignite"];alternate.augments[0].stats.bonus_as=.4
 var stronger=BuildStealer.validate(alternate)
 check(BuildStealer.validate(raw("ashe",30)).score>record.score,"higher difficulty raises an otherwise matching run's score")
 best=BuildStealer.ranked([record,alternate,raw()])
 check(best.size()==1 and best[0]==stronger,"better score replaces that hero's entire blueprint; worse runs cannot replace it")
 var tied=alternate.duplicate(true);tied.items=["dagger"]
 check(BuildStealer.ranked([stronger,tied])[0].id==stronger.id,"equal score preserves the existing build")
 check(BuildStealer.ranked([alternate,record])[0]==stronger,"highest-scoring hero build wins in either input order")
 var keys=ChampionData.CHAMPIONS.keys();candidates=[]
 for i in range(20):
  var candidate=raw(keys[i],i+1,15+i,2);candidate.augments[0].stats.bonus_as=.22+i*.005;candidates.append(candidate)
 best=BuildStealer.ranked(candidates)
 check(best.size()==10 and best[0].score>=best[9].score,"twenty distinct candidates reduce to top ten")
 check(distinct(best.map(func(entry):return entry.hero)).size()==10,"all ten saved builds belong to different heroes")
 var hero=GameState.player;hero.kills=15;hero.deaths=3;hero.assists=4;hero.inventory=record.items.duplicate();hero.purchase_history=record.items.duplicate();hero.augment_history=[{"level":4,"index":0,"stats":{"bonus_as":.3}}];hero.skill_history=record.skill_order.duplicate(true);hero.summoner_spells=["heal","ghost"];hero.permanent_bonus={"bonus_ad":9999};hero.level_bonus={"bonus_ad":900};hero.consumable_counts={"training_ad":2};hero._apply_items()
 var capture=BuildStealer.capture(hero,9,true)
 check(capture.hero=="ashe" and capture.items==record.items and capture.augments[0].stats.bonus_as==.3 and capture.elixirs.training_ad==2,"capture actual items, exact rolls and elixir goals")
 check(not capture.has("permanent_bonus") and not capture.has("level_bonus") and not capture.has("gold"),"starting account power, levels and money excluded")
 hero.is_bot=true;check(BuildStealer.capture(hero,9,true).is_empty(),"AI never teaches its own build");hero.is_bot=false
 # Save and reload an isolated host profile, including existing credits and gear.
 var old_path=Progression.save_path;Progression.save_path="res://tests/build-stealer-profile.tmp";Progression.persistent=true;Progression.credits=4321;Progression.build_records=best.duplicate(true)
 check(Progression.save_profile(),"profile saves archive atomically")
 Progression.build_records.clear();Progression.credits=0;Progression.load_profile()
 check(Progression.build_records.size()==10 and Progression.credits==4321,"archive survives reload without losing existing progression")
 Progression.build_records=[record,stronger,BuildStealer.validate(tied)];Progression.save_profile();Progression.load_profile()
 check(Progression.build_records.size()==1 and Progression.build_records[0]==stronger and Progression.credits==4321,"legacy same-hero archives consolidate to their best score on reload")
 Progression.persistent=false;Progression.save_path=old_path
 # Host-owned completed match records all human participants, including a remote teammate.
 Progression.build_records.clear();GameState.reward_difficulty=9
 var guest=GameState.champions[1];guest.is_bot=false;guest.owner_peer=42;guest.kills=20;guest.deaths=2;guest.inventory=["rabadon","sorcerer_shoes","","","",""];guest.purchase_history=["sorcerer_shoes","rabadon"]
 var report=BuildStealer.record_match(Constants.BLUE)
 check(Progression.build_records.size()==2 and report.contains("2 qualifying"),"host records dominant host and co-op teammate")
 var config={"mode":"pve","blue":["ashe","lux","garen"],"red":["zed","thresh","leesin"]};BuildStealer.assign(config)
 check(config.stolen_builds.size()==2 and config.stolen_builds[0].slot!=config.stolen_builds[1].slot,"exactly two distinct bot slots borrow builds")
 check(config.stolen_builds[0].record.hero!=config.stolen_builds[1].record.hero,"different archived heroes preferred")
 var normal=[3,4,5].filter(func(slot):return not config.stolen_builds.any(func(entry):return entry.slot==slot))[0]
 check(config.red[normal-3]!=config.stolen_builds[0].record.hero and config.red[normal-3]!=config.stolen_builds[1].record.hero,"third enemy uses a fresh distinct hero")
 reset(config.blue,config.red,config.stolen_builds)
 for entry in config.stolen_builds:
  var bot=GameState.champions[entry.slot]
  check(bot.hero_key==entry.record.hero and not bot.stolen_blueprint.is_empty() and bot.inventory.all(func(id):return id=="") and bot.run_bonus.is_empty(),"echo uses right hero and starts without free endgame power")
  check(bot.summoner_spells==entry.record.spells and bot.permanent_bonus.is_empty(),"echo learns summoners without stealing account bonuses")
  bot.gold=100000
  var steps=0
  while steps<80 and not entry.record.items.all(func(id):return bot.inventory.count(id)>=entry.record.items.count(id)):
   if not bot._bot_buy_next():break
   steps+=1
  check(entry.record.items.all(func(id):return bot.inventory.count(id)>=entry.record.items.count(id)),"saved six-slot build completes through normal recipes")
  check(bot.gold<100000,"every stolen item costs gold")
  bot._bot_buy_next();bot._bot_buy_next()
  if entry.record.elixirs.has("training_ad"):check(bot.consumable_counts.get("training_ad",0)==2,"late-game elixirs reproduce paid stacks")
  var upgrade=BuildStealer.upgrade_at(bot,4)
  if not upgrade.is_empty():
   bot.level=4;game.lane_augments.on_level_up(bot)
   check(bot.run_bonus.bonus_as==.3 and bot.augment_history.size()==1,"exact saved roll unlocks at its earned level")
   game.lane_augments.on_level_up(bot);check(bot.augment_history.size()==1 and bot.run_bonus.bonus_as==.3,"milestone cannot apply twice")
  bot.skill_points=1;bot.level=4;bot._bot_spend_points()
  if not entry.record.skill_order.is_empty():check(bot.skill_ranks[0]==2,"saved skill path spends legal point")
 # Small budgets buy useful recipe components rather than waiting empty-handed.
 var test_bot=GameState.champions[3];test_bot.is_bot=true;test_bot.inventory=["","","","","",""];test_bot.consumable_counts.clear();test_bot.stolen_items_complete=false;test_bot.stolen_blueprint=BuildStealer.validate(raw("ashe",3,15,0,["infinity_edge"]));test_bot.gold=400
 check(test_bot._bot_buy_next() and test_bot.inventory.has("long_sword") and test_bot.gold==50,"affordable component starts the stolen build")
 check(not test_bot._bot_buy_next() and test_bot.gold==50,"no free purchase when cash runs out")
 # Every existing recommended six-slot build can finish, even on a crowded inventory.
 for key in ChampionData.CHAMPIONS:
  var targets=[]
  for id in ItemData.BUILD_ORDERS.get(key,[]):
   for component in targets.duplicate():
    if BuildStealer.contains_component(id,component):targets.erase(component)
   if not targets.has(id):targets.append(id)
  targets=targets.slice(-6)
  var blueprint=BuildStealer.validate(raw(key,3,20,2,targets))
  check(not blueprint.is_empty(),"recommended goals validate: "+key)
  test_bot.stolen_items_complete=false;test_bot.stolen_blueprint=blueprint;test_bot.inventory=["","","","","",""];test_bot.gold=500000;test_bot.consumable_counts.clear()
  var attempts=0
  while attempts<100 and not blueprint.items.all(func(id):return test_bot.inventory.count(id)>=blueprint.items.count(id)):
   if not test_bot._bot_buy_next():break
   attempts+=1
  check(blueprint.items.all(func(id):return test_bot.inventory.count(id)>=blueprint.items.count(id)),"full stolen plan completes: "+key)
 # Components intentionally retained in the final inventory are purchased after their parents.
 var mixed=BuildStealer.validate(raw("ashe",1,15,0,["long_sword","infinity_edge","warmog","thornmail","berserker_greaves","bloodthirster"]))
 test_bot.stolen_items_complete=false;test_bot.stolen_blueprint=mixed;test_bot.inventory=["","","","","",""];test_bot.gold=50000
 for attempt in range(30):
  if mixed.items.all(func(id):return test_bot.inventory.count(id)>=mixed.items.count(id)):break
  if not test_bot._bot_buy_next():break
 check(mixed.items.all(func(id):return test_bot.inventory.count(id)>=mixed.items.count(id)),"final component and its parent both survive the completed loadout")
 test_bot.stolen_items_complete=false;test_bot.stolen_blueprint=config.stolen_builds.filter(func(entry):return entry.slot==3)[0].record if config.stolen_builds.any(func(entry):return entry.slot==3) else {}
 var ordinary=GameState.champions[normal]
 check(ordinary.stolen_blueprint.is_empty(),"one bot keeps ordinary progression")
 var before=Progression.build_records.duplicate(true);var pvp=config.duplicate(true);pvp.mode="pvp";BuildStealer.assign(pvp)
 check(pvp.stolen_builds.is_empty(),"PvP never borrows builds")
 GameState.match_mode="pvp";check(BuildStealer.record_match(1)=="" and Progression.build_records==before,"PvP never writes build archive");GameState.match_mode="pve"
 # A single learned hero supplies only one Echo. Mirrors and duplicate allies remain allowed.
 Progression.build_records=[record,stronger];config={"mode":"pve","blue":["ashe","ashe","ashe"],"red":["ashe","ashe","ashe"]};BuildStealer.assign(config)
 check(config.stolen_builds.size()==1 and config.stolen_builds[0].record==stronger,"multiple saved variants of one hero supply only one best Echo")
 check(distinct(config.red).size()==3 and config.blue==["ashe","ashe","ashe"] and config.red.has("ashe"),"enemy team is unique while allied duplicates and cross-team mirrors remain allowed")
 reset(config.blue,config.red,config.stolen_builds)
 check(GameState.champions.filter(func(c):return c.team==1 and c.stolen_blueprint.is_empty()).size()==2,"single-record match builds one Echo and two ordinary opponents")
 var ashe_ally=GameState.champions[1];GameState.player.inventory[0]="long_sword";GameState.player.skill_cds[0]=8.
 check(ashe_ally.inventory[0]=="" and ashe_ally.skill_cds[0]==0.,"same allied heroes keep independent inventories and cooldowns")
 Progression.build_records.clear();config.red=["zed","zed","zed"];BuildStealer.assign(config)
 check(config.stolen_builds.is_empty() and distinct(config.red).size()==3,"empty archive repairs duplicate enemy choices and uses normal bots")
 Progression.build_records=best
 for round_index in range(50):
  config={"mode":"pve","blue":["ashe","ashe","ashe"],"red":["zed","zed","zed"]};BuildStealer.assign(config)
  check(config.stolen_builds.size()==2 and distinct(config.red).size()==3,"full-library rotation never repeats an enemy hero")
 reset();Progression.build_records.clear();hero=GameState.player;hero.kills=15;hero.deaths=2;hero.gold=500;hero.try_buy_item("long_sword");GameState.reward_difficulty=12
 game._end_game(Constants.BLUE)
 check(Progression.build_records.size()==1 and Progression.build_records[0].stage==12,"real completed match captures immediately")
 check(game.hud.get_node("HudRoot").end_stats.text.contains("1 qualifying"),"end screen reports host learning")
 var completed=Progression.build_records.duplicate(true)
 reset();GameState.player.kills=100;GameState.player.deaths=0;game._return_to_main_menu();game.set_process(false)
 check(Progression.build_records==completed,"abandoning a run does not teach a build")
 game._return_to_main_menu();game.set_process(false);BuildLibraryMenu.show(game)
 check(game.menu.has_node("BuildLibrary") and game.menu.find_child("BuildLibraryAction",true,false)!=null,"readable archive browser is on main menu")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/build-library-v069.png")
 game.queue_free();GameState.reset()
 for frame in range(4):await get_tree().process_frame
 print("BUILD STEALER: %d checks, %d failures" % [checks,failures]);get_tree().quit(0 if failures==0 else 1)

func distinct(values: Array) -> Dictionary:
 var seen={}
 for value in values:seen[value]=true
 return seen
