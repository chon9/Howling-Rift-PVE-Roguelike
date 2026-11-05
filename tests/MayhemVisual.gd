extends Node
# Captures the Mayhem cards at the start of a 3D match, then a giant hero mid-match.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL MAYHEM VISUAL: " + message)

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var game: Node2D = View3DTestKit.start_3d_match(self, "garen")
	for i in range(120):
		game._process(1.0 / 60.0)
		if i % 40 == 0:
			await get_tree().process_frame
	var cards = game.lane_augments
	check(cards.mayhem_bar.visible and cards.mayhem_bar.get_child_count() == 3, "three cards show at the start")
	await _shot("82-mayhem-cards.png")
	cards.choose_mayhem(0)
	check(not cards.mayhem_bar.visible or cards.mayhem_choices.is_empty(), "the row closes after a pick")
	Mayhem.grant(GameState.player, "titan")
	for i in range(600):
		game._process(1.0 / 60.0)
		if i % 40 == 0:
			await get_tree().process_frame
	await _shot("83-mayhem-titan.png")
	print("MAYHEM VISUAL: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(1.0).timeout
	var image: Image = await View3DTestKit.capture(self)
	if image != null:
		image.save_png("res://tests/" + file)
