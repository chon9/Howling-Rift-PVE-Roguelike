extends Node

func buttons_under(node: Node) -> Array:
	var result = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons_under(child))
	return result

func _ready() -> void:
	GameState.reset()
	Progression.persistent = false
	Progression.levels.clear()
	Progression.credits = 1320
	Progression.difficulty = 12
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/08-difficulty-menu.png")
	for button in buttons_under(game.menu):
		if button.text == "PERMANENT UPGRADES / SETTINGS": button.pressed.emit()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/09-permanent-upgrades.png")
	for button in buttons_under(game.menu):
		if button.text.begins_with("Vitality"): button.pressed.emit()
	assert(Progression.levels.get("vitality", 0) == 1 and Progression.credits == 820)
	Progression.difficulty = 1
	game._start_game("ahri")
	GameState.player.global_position = Vector2(1300, 340)
	game._update_camera(0.05)
	game.hud.get_node("HudRoot").refresh(0.01)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/10-hero-follow.png")
	print("Progression UI purchase and screenshots passed")
	get_tree().quit()
