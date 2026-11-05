extends Node
var game
var failures=0
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.difficulty=10;Progression.vsync_enabled=false
 game=load("res://scripts/Main.gd").new();add_child(game)
 game.network_config={"mode":"pve","blue":["janna","soraka","xinzhao"],"red":["leesin","lux","darius"],"players":[{"peer":1,"slot":0,"name":"You","spells":["heal","ghost"],"bonuses":{}}]}
 game._start_game("janna")
 for c in GameState.champions:
  c.global_position=Vector2(1200 if c.team==0 else 1430,210+GameState.champions.find(c)%3*60)
  c.skill_ranks=[3,3,3,2];c.mp=c.mp_max;c.gold=7000;c.hp=c.hp_max
  if c.hero_key=="soraka":c.inventory=["moonstone","redemption"];c._apply_items()
  if c==GameState.player:c.is_bot=true
 await get_tree().create_timer(3.).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/support-battle.png")
 var frames=[];var end=Time.get_ticks_msec()+12000
 while Time.get_ticks_msec()<end:
  frames.append(get_process_delta_time());await get_tree().process_frame
  for c in GameState.champions:
   if not c.world_pos().is_finite() or not is_finite(c.hp) or c.shield<-.01:failures+=1
 frames.sort();var median=frames[frames.size()/2];var p95=frames[int(frames.size()*.95)]
 print("SUPPORT BATTLE: median %.2fms / p95 %.2fms, kills %s, %d failures" % [median*1000.,p95*1000.,GameState.score,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
