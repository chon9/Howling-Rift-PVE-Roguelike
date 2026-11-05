extends Node
# Captures the victory and defeat screens over a live 3D match.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL END SCREEN: " + message)

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var game: Node2D = View3DTestKit.start_3d_match(self, "lux")
	for i in range(240):
		game._process(1.0 / 60.0)
		if i % 40 == 0:
			await get_tree().process_frame
	var ui = game.hud.get_node("HudRoot")
	game._end_game(GameState.player.team)
	check(ui.end_overlay.visible and ui.end_title.text == "VICTORY", "victory screen shows")
	check(ui.end_stats.text == ui.end_stats.text.strip_edges() and not ui.end_stats.text.is_empty(), "match report is filled without stray blank lines")
	check(ui.end_overlay.team_rows[0].get_child_count() > 0 and ui.end_overlay.team_rows[1].get_child_count() > 0, "both teams are listed")
	check(ui.end_overlay.continue_button.has_focus(), "the button has keyboard focus")
	await _shot("80-end-victory.png")
	GameState.running = true
	game._end_game(1 - GameState.player.team)
	check(ui.end_title.text == "DEFEAT", "defeat screen shows")
	await _shot("81-end-defeat.png")
	print("END SCREEN VISUAL: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(1.6).timeout
	var image: Image = await View3DTestKit.capture(self)
	if image != null:
		image.save_png("res://tests/" + file)
