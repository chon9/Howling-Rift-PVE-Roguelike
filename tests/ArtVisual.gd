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
	game._start_game("lux")
	var p = GameState.player
	p.is_bot = true
	for frame in range(1200):
		game._process(0.05)
		if frame % 100 == 0: await get_tree().process_frame
	for node in game.world_root.get_children():
		if node is FloatingText: node.queue_free()
	var feed = game.hud.get_node("HudRoot").kill_feed
	for index in range(maxi(0, feed.get_child_count() - 2)):
		feed.get_child(index).queue_free()
	p.is_bot = false
	if p.dead: game._respawn_champion(p)
	p.stop_actions()
	p.global_position = Vector2(1320, 320)
	GameState.cam_locked = true
	game._update_camera(1)
	game.hud.get_node("HudRoot").refresh(0.1)
	await capture("res://tests/20-art-lane-fullscreen.png")
	p.global_position = Vector2(420, 300)
	game._update_camera(1)
	game.hud.get_node("HudRoot").refresh(0.1)
	await capture("res://tests/21-art-base-fullscreen.png")
	p.global_position = Vector2(1320, 320)
	game._update_camera(1)
	game.set_fullscreen(false)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.3).timeout
	game.hud.get_node("HudRoot").refresh(0.1)
	await capture("res://tests/22-art-lane-windowed.png")
	print("ARAM painted graphics captured")
	get_tree().quit()
