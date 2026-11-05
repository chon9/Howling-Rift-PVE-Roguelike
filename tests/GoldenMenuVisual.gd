extends Node
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 for preset in [[1280,720,"windowed"],[1920,1080,"full-hd"],[2560,1080,"ultrawide"]]:
  get_window().size=Vector2i(preset[0],preset[1])
  await get_tree().process_frame
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/golden-main-"+preset[2]+".png")
 print("GOLDEN MENU: native windowed, Full HD and ultrawide renders captured")
 get_tree().quit()
