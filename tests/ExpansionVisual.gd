extends Node
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game)
 game._show_menu()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/expansion-roster.png")
 for node in game.menu.get_children()[0].get_children():
  if node is ScrollContainer:node.scroll_vertical=340
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/expansion-roster-new-heroes.png")
 game._start_game("darius")
 game.set_process(false)
 for team in [Constants.BLUE,Constants.RED]:
  var point=Constants.FOUNT_B if team==Constants.BLUE else Constants.FOUNT_R
  game.camera.position=point;game.camera.reset_smoothing()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/expansion-cliff-%d.png" % team)
 game.queue_free();await get_tree().process_frame
 print("EXPANSION VISUAL: roster and both cliffs captured")
 get_tree().quit()
