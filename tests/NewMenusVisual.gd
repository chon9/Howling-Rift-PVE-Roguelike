extends Node
func capture(path: String) -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 GameState.reset()
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game.set_fullscreen(true)
 await get_tree().create_timer(0.3).timeout
 await capture("res://tests/28-main-menu.png")
 game._show_menu()
 await capture("res://tests/29-twelve-heroes.png")
 game._select_hero("yasuo")
 game._start_game("yasuo")
 game.toggle_in_game_menu()
 await capture("res://tests/30-esc-menu.png")
 game._show_pause_upgrades()
 await capture("res://tests/31-pause-upgrades.png")
 game._return_to_main_menu()
 await capture("res://tests/32-return-main-menu.png")
 game.set_fullscreen(false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 await get_tree().create_timer(0.3).timeout
 game._show_menu()
 await capture("res://tests/33-roster-windowed.png")
 print("Title, roster and Esc menus captured")
 get_tree().quit()
