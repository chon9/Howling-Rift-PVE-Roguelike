extends Node

func _ready() -> void:
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game.set_fullscreen(true)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	print("Fullscreen window: ", DisplayServer.window_get_size(), " rendered viewport: ", get_viewport().get_texture().get_size())
	get_viewport().get_texture().get_image().save_png("res://tests/15-fullscreen-roster.png")
	game._start_game("ashe")
	GameState.player.global_position = Vector2(1320, 345)
	game._update_camera(0.05)
	game.hud.get_node("HudRoot").refresh(0.01)
	for row in range(6):
		var burst = load("res://scripts/SpellBurst.gd").new()
		burst.row = row
		burst.radius = 45
		burst.duration = 10
		burst.elapsed = 2.5 + row * 0.6
		game.world_root.add_child(burst)
		burst.global_position = Vector2(1040 + row * 110, 200)
		var missile = game.ProjectileS.new()
		game.world_root.add_child(missile)
		missile.setup(GameState.player, Vector2(1040 + row * 110, 300), Vector2.RIGHT, {"size":16, "life":20})
		missile.art_row = row
		missile.animation_time = row * 0.06
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/16-spell-sprites-fullscreen.png")
	game.toggle_in_game_menu()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/17-fullscreen-menu.png")
	game.set_fullscreen(false)
	get_tree().quit()
