extends Node
var failures = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _ready() -> void:
	await get_tree().process_frame
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe")
	var ui = game.hud.get_node("HudRoot")
	var p = GameState.player
	for tower in GameState.structures:
		check(tower.tower_texture is AtlasTexture and tower.tower_texture.region.end.x <= 1024 and tower.tower_texture.region.end.y <= 1536, tower.type + " painted sprite stays in atlas bounds")
		check(tower.hp_bar.position.y < tower.art_rect.position.y, "health bars sit above enlarged structures")
	var map = ui.minimap
	map.player = p
	for point in [Vector2.ZERO, Constants.FOUNT_B, Constants.FOUNT_R, Vector2(Constants.WORLD_W, Constants.WORLD_H)]:
		check(map.map_to_world(map.world_to_map(point)).distance_to(point) < 0.01, "minimap world coordinate round trip")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_map(Vector2(1550, 270))
	map._gui_input(click)
	check(not GameState.cam_locked and GameState.cam_target.distance_to(Vector2(1550, 270)) < 0.01, "minimap click moves camera")
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	check(p.move_target.distance_to(Vector2(1550, 270)) < 0.01, "minimap right-click moves hero")
	ui.refresh(0)
	await get_tree().process_frame
	await get_tree().process_frame
	for slot in ui.summoner_slots:
		var bounds = slot.panel.get_global_rect()
		check(bounds.encloses(slot.icon.get_global_rect()), "summoner icon stays inside framed button")
	# Actual GUI input verifies the generated panel backdrop does not eat clicks.
	click = InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = ui.summoner_slots[0].panel.get_global_rect().get_center()
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	check(p.summoner_cds[0] > 0, "Flash button remains clickable through decorative art")
	GameState.paused = true
	p.summoner_cds[0] = 0
	click.pressed = true
	get_viewport().push_input(click, true)
	check(p.summoner_cds[0] == 0, "paused combat cannot cast via action bar")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Generated environment and UI tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
