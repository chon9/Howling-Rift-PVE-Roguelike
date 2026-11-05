extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BUILD CONTINUATION: "+message)
func blueprint(key: String,items: Array) -> Dictionary:
 return BuildStealer.validate({"hero":key,"stage":9,"kills":20,"deaths":2,"items":items,"augments":[{"level":4,"index":0,"stats":{"bonus_as":.3}}],"skill_order":[{"index":0,"rank":2}],"elixirs":{"training_ad":1}})
func reset(key: String,items: Array):
 if GameState.started:game._return_to_main_menu();game.set_process(false)
 var record=blueprint(key,items)
 game.network_config={"mode":"pve","blue":["ashe","lux","garen"],"red":[key,"zed","thresh"],"stolen_builds":[{"slot":3,"record":record}],"players":[{"peer":1,"slot":0,"spells":["flash","ignite"],"bonuses":{}}]}
 game._start_game("ashe");game.set_process(false)
 return GameState.champions[3]
func next_level(bot) -> void:
 bot.grant_xp((Constants.xp_to_level(bot.level)-bot.xp)/bot.difficulty_stats.get("experience",1.)+.001)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.difficulty=1;Progression.levels.clear();Progression.build_records.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 var bot=reset("ashe",["boots"]);bot.gold=300
 check(bot._bot_buy_next() and bot.inventory.has("boots") and bot.gold==0,"saved item buys first at its real price")
 check(not bot._bot_buy_next() and bot.stolen_items_complete and bot.consumable_counts.is_empty(),"original purchases wait for gold after the saved goal finishes")
 bot.gold=50000
 check(bot._bot_buy_next() and bot.inventory.has("long_sword"),"next purchase resumes the hero's original build")
 check(bot._bot_buy_next() and bot.inventory.has("berserker_greaves") and not bot.inventory.has("boots"),"original build upgrades the saved component")
 for attempt in range(32):
  if bot.consumable_counts.get("training_ad",0)>=1:break
  if not bot._bot_buy_next():break
 check(bot.purchase_history.count("boots")==1 and bot.stolen_items_complete,"consumed saved component is never re-bought")
 check(bot.consumable_counts.get("training_ad",0)==1 and bot.inventory.count("")==0,"remaining original items precede the recorded late-game elixir")
 var counts=bot.consumable_counts.values().reduce(func(total,value):return total+value,0)
 check(bot._bot_buy_next() and bot.consumable_counts.values().reduce(func(total,value):return total+value,0)==counts+1,"normal stat consumables continue after the saved elixir goal")
 bot=reset("ashe",["mercury_treads","infinity_edge"]);bot.gold=15000
 for attempt in range(16):
  if not bot._bot_buy_next():break
 check(bot.stolen_items_complete and bot.inventory.has("mercury_treads") and not bot.inventory.has("berserker_greaves") and not bot.inventory.has("boots"),"alternate saved boots do not block or get replaced by the original build")
 check(bot.purchase_history.count("infinity_edge")==1 and bot.inventory.has("phantom_dancer"),"owned finished items and their components are skipped while later original goals proceed")
 # Every hero with a partial saved path continues purchases, skill ranks and
 # normal randomized milestones, then earns veteran stats through level 100.
 for key in ChampionData.CHAMPIONS:
  var first=ItemData.BUILD_ORDERS[key][0];bot=reset(key,[first]);bot.gold=100000
  check(bot._bot_buy_next() and bot.purchase_history==[first],"saved purchase first: "+key)
  check(bot._bot_buy_next() and bot.stolen_items_complete and bot.purchase_history.size()==2,"original purchases resume: "+key)
  bot.level=4;bot.skill_points=1;bot._bot_spend_points();game.lane_augments.on_level_up(bot)
  check(bot.skill_ranks[0]==2 and bot.run_bonus.bonus_as==.3,"saved skill and exact roll first: "+key)
  bot.level=5;bot.skill_points=1
  var expected=-1
  for index in bot.hero.priority:
   if bot.can_level_skill(index):expected=index;break
  var previous=bot.skill_ranks.duplicate();bot._bot_spend_points()
  check(expected>=0 and bot.skill_ranks[expected]==previous[expected]+1 and bot.skill_points==0,"next point resumes original skill priority: "+key)
  next_level(bot)
  check(bot.level==6 and bot.augment_history.size()==2 and bot.augment_history[1].level==6,"next milestone uses a normal earned upgrade: "+key)
  while bot.level<100:next_level(bot)
  check(bot.skill_ranks==bot.hero.skills.map(func(skill):return skill.max) and bot.skill_points==0,"all skills finish after a partial saved path: "+key)
  check(bot.level==100 and bot.level_bonus.get("bonus_ad",0)>0 and bot.level_bonus.get("bonus_ap",0)>0 and bot.level_bonus.get("bonus_hp",0)>0,"veteran stats keep progressing to level 100: "+key)
  check(bot.augment_history.size()==8 and bot.augment_history[0].stats=={"bonus_as":.3},"saved roll remains once and normal upgrades fill every remaining milestone: "+key)
 game._return_to_main_menu();game.queue_free();GameState.reset()
 for frame in range(4):await get_tree().process_frame
 print("BUILD CONTINUATION: %d checks, %d failures" % [checks,failures]);get_tree().quit(0 if failures==0 else 1)
