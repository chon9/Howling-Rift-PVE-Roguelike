extends Node
func _ready() -> void:
 await get_tree().process_frame
 seed(19204)
 Progression.persistent = false
 Progression.levels.clear()
 Progression.difficulty = 1
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game.network_config = {"blue":["jinx","leesin","lux"],"red":["jinx","leesin","lux"],"players":[{"peer":1,"hero":"jinx","spells":["flash","ignite"],"bonuses":{},"name":"Rixa Audit"}],"stage":1}
 game._start_game("jinx")
 game.lane_augments.rng.seed = 19204
 for c in GameState.champions:
  c.is_bot = true
  c.permanent_bonus.clear()
  c._apply_items()
  c.hp = c.hp_max
  c.mp = c.mp_max
 var steps = 0
 while GameState.running and GameState.time<120:
  game._process(1.0/30.0)
  steps+=1
  if steps%10==0: await get_tree().process_frame
 for c in GameState.champions:
  print("LANE AUDIT: team %d %s level %d K/D/A %d/%d/%d CS %d AD %.0f AP %.0f HP %.0f items %s" % [c.team,c.hero_key,c.level,c.kills,c.deaths,c.assists,c.cs,c.ad,c.bonus_ap,c.hp_max,str(c.inventory)])
 print("RIXA LANE AUDIT: %.1fs, score %s" % [GameState.time,str(GameState.score)])
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit()
