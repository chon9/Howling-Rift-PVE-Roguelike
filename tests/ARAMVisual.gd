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
 game._show_menu()
 game.set_fullscreen(true)
 await get_tree().create_timer(0.3).timeout
 await capture("res://tests/24-aram-roster.png")
 game.selected_summoners = ["heal","ghost"]
 game._start_game("ashe")
 var ui = game.hud.get_node("HudRoot")
 ui.refresh(0)
 ui.toggle_shop()
 ui.shop_panel.selected = "infinity_edge"
 ui.shop_panel.refresh_shop(true)
 await capture("res://tests/25-aram-shop.png")
 ui.close_shop()
 var p = GameState.player
 p.grant_xp(Constants.xp_to_level(3))
 p.global_position = Vector2(1350,270)
 game._update_camera(1)
 game.lane_augments.toggle_panel()
 ui.flash_rect.color = Color(0,0,0,0)
 ui.refresh(0)
 await capture("res://tests/26-aram-level-up.png")
 game.lane_augments.panel.hide()
 game.set_fullscreen(false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 await get_tree().create_timer(0.3).timeout
 ui.toggle_shop()
 await capture("res://tests/27-aram-shop-windowed.png")
 print("ARAM interface captures complete")
 get_tree().quit()
