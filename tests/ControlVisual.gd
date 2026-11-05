extends Node
# Sends real mouse events through the 3D view, then captures what the player sees during a fight.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL CONTROL VISUAL: " + message)

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var game: Node2D = View3DTestKit.start_3d_match(self, "garen")
	await _frames(game, 30)
	game.lane_augments.choose_mayhem(0)
	var hero = GameState.player
	var foe = null
	for c in GameState.champions:
		if c.team != hero.team and c.roster_active and foe == null:
			foe = c
	hero.global_position = Vector2(1300, 270)
	foe.global_position = Vector2(1500, 250)
	foe.is_bot = false
	foe.stop_actions()
	GameState.cam_target = hero.global_position
	GameState.cam_locked = true
	await _frames(game, 40)
	# A right click on the ground beside the enemy is a move, with arrows on the ground.
	var ground: Vector2 = game.world_to_screen(Vector2(1420, 370))
	_press(game, ground)
	check(hero.attack_target == null and hero.has_move_target, "right click on the ground walks")
	await _frames(game, 6)
	await _shot("84-control-move.png")
	# A right click on the body, high above its feet, attacks that hero.
	var body: Vector2 = game.world_to_screen(foe.world_pos(), Constants.CHAMP_ART_HEIGHT * 0.6)
	check(game.click_target(body) == foe, "the painted body counts as the hero")
	_press(game, body)
	check(hero.attack_target == foe, "right click on the body attacks that hero")
	await _frames(game, 6)
	GameState.hover_unit = foe
	await _shot("85-control-attack.png")
	# The hero wins over a minion standing right in front of it.
	var creep = game.MinionS.new()
	game.world_root.add_child(creep)
	creep.setup(foe.team, "melee", foe.world_pos() + Vector2(0, 12), 1.0)
	GameState.minions.append(creep)
	await _frames(game, 2)
	check(game.click_target(game.world_to_screen(foe.world_pos() + Vector2(0, 8))) == foe, "a hero beats a minion at its feet")
	print("CONTROL VISUAL: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _press(game, screen: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = screen
	game._unhandled_input(event)

func _frames(game, count: int) -> void:
	for i in range(count):
		game._process(1.0 / 60.0)
		await get_tree().process_frame

func _shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = await View3DTestKit.capture(self)
	if image != null:
		image.save_png("res://tests/" + file)
