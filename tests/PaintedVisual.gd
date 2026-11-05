extends Node

func _ready() -> void:
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/12-painted-roster.png")
	game._start_game("ahri")
	# Put all six identities on screen to check scale, transparency and team readability.
	var index = 0
	for key in ChampionData.CHAMPIONS:
		var hero = game.ChampionS.new()
		game.world_root.add_child(hero)
		hero.setup(index % 2, key, true, ChampionData.CHAMPIONS[key].name)
		hero.global_position = Vector2(1070 + index * 125, 270)
		hero.facing = Vector2(-1, 0) if index % 2 == 0 else Vector2(1, 0)
		index += 1
	GameState.player.global_position = Vector2(1360, 385)
	GameState.cam_target = Vector2(1400, 270)
	game.camera.position = GameState.cam_target
	game.hud.get_node("HudRoot").refresh(0.01)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/13-painted-lane.png")
	game.hud.get_node("HudRoot").skill_slots[0].hover_entered.emit()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/14-skill-description.png")
	print("Painted roster, lane and skill hover screenshots saved")
	get_tree().quit()
