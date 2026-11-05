extends Node
func capture(path: String) -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 Progression.persistent=false;GameState.reset()
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._show_menu();await get_tree().process_frame
 game.menu.find_children("*","ScrollContainer",true,false)[0].scroll_vertical=10000
 await capture("res://tests/roster30-selection-v050.png")
 game._start_game("leona")
 for batch in range(2):
  for i in range(6):
   var old=GameState.champions[i];var c=game.ChampionS.new();game.world_root.add_child(c);var key=RosterExpansion12.KEYS[batch*6+i]
   c.setup(0,key,false,ChampionData.CHAMPIONS[key].name);c.global_position=Vector2(1130+i*155,270);c.skill_ranks=[1,1,1,1];c.bonus_ap=100.;c.mp=1000.;c.mp_max=1000.;c.is_bot=false;GameState.champions[i]=c;old.queue_free()
  GameState.player=GameState.champions[0];game.camera.position=Vector2(1510,270)
  await capture("res://tests/roster12-idle-%d-v050.png" % batch)
  for c in GameState.champions:c.animator.start("attack",2.);c.anim_elapsed=.7;c.queue_redraw()
  await capture("res://tests/roster12-attack-%d-v050.png" % batch)
 print("ROSTER12 VISUAL: selection and twelve idle/attack heroes captured")
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit()
