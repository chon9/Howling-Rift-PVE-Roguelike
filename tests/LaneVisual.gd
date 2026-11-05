extends Node

func _ready() -> void:
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/07-hero-pool.png")
	game._start_game("ashe")
	game.set_process(false)
	GameState.player.is_bot = true
	for i in range(2100):
		game._process(1.0 / 60.0)
		if i % 60 == 0: await get_tree().process_frame
	GameState.cam_locked = false
	GameState.cam_target = Vector2(1400, 270)
	game.set_process(true)
	await get_tree().create_timer(2.0).timeout
	game.set_process(false)
	game.camera.position = GameState.cam_target
	if GameState.player.dead:
		game._respawn_champion(GameState.player)
		GameState.player.global_position = Vector2(1210, 340)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/05-moba-lane.png")
	game.lane_augments.toggle_panel()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/06-moba-augments.png")
	get_tree().quit()
