extends Node
# Captures the camera angle where it matters: a lane fight, beside a tower, at both lane edges and in the bases.
func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var game: Node2D = View3DTestKit.start_3d_match(self, "garen")
	await _run(game, 0.5)
	game.lane_augments.choose_mayhem(0)
	var hero = GameState.player
	for c in GameState.champions:
		if c.roster_active:
			c.global_position = Vector2(1300 + (120 if c.team != hero.team else -120), 270 + randf_range(-90, 90))
	hero.global_position = Vector2(1300, 270)
	GameState.cam_target = hero.global_position
	GameState.cam_locked = true
	# Let the first waves meet so the frame holds a real crowd.
	await _run(game, 42.0)
	await _shot(game, hero, hero.global_position, "90-angle-fight.png")
	await _shot(game, hero, Vector2(760, 270), "91-angle-tower.png")
	await _shot(game, hero, Vector2(1300, 95), "92-angle-north.png")
	await _shot(game, hero, Vector2(1300, 445), "93-angle-south.png")
	await _shot(game, hero, Vector2(260, 270), "94-angle-base.png")
	await _shot(game, hero, Vector2(2500, 270), "95-angle-red-base.png")
	get_tree().quit(0)

func _run(game, seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		game._process(1.0 / 60.0)
		if i % 20 == 0:
			await get_tree().process_frame

func _shot(game, hero, at: Vector2, file: String) -> void:
	hero.global_position = at
	hero.stop_actions()
	GameState.cam_target = at
	await _run(game, 0.2)
	var image: Image = await View3DTestKit.capture(self)
	if image != null:
		image.save_png("res://tests/" + file)
