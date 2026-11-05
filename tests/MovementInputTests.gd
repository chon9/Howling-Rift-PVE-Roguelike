extends Node
var failures = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func right_click(game, world: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = game.world_to_screen(world)
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
func _ready() -> void:
	await get_tree().process_frame
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe")
	var p = GameState.player
	for hero in GameState.champions:
		hero.is_bot = false
		hero.stop_actions()
		hero.global_position = Constants.FOUNT_B if hero.team == 0 else Constants.FOUNT_R
	p.global_position = Vector2(1300, 270)
	game._update_camera(1)
	await get_tree().process_frame
	await get_tree().process_frame
	# Exercise real viewport/GUI dispatch rather than calling command handlers.
	right_click(game, Vector2(1400, 370))
	check(p.has_move_target and p.move_target.distance_to(Vector2(1400, 370)) < 0.1, "battlefield right-click reaches movement handler with exact event position")
	var previous = p.world_pos()
	p.update_frame(0.1)
	check(p.world_pos().distance_to(previous) > 10, "hero moves after ground click")
	p.stop_actions()
	var point = p.hp_bar.get_global_transform_with_canvas() * (p.hp_bar.size * 0.5)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = point
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	check(p.has_move_target, "hero health bar does not swallow movement clicks")
	var creep = game.MinionS.new()
	game.world_root.add_child(creep)
	creep.setup(0, "melee", Vector2(1450, 320))
	GameState.minions.append(creep)
	p.stop_actions()
	click.pressed = true
	click.position = creep.hp_bar.get_global_transform_with_canvas() * (creep.hp_bar.size * 0.5)
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	check(p.has_move_target, "creep health bar does not swallow movement clicks")
	p.stop_actions()
	p.stun = 0.5
	game._issue_player_order({"type":"smart", "point":Vector2(1510, 350)})
	check(p.has_move_target and p.move_target == Vector2(1510, 350), "movement command survives crowd control")
	previous = p.world_pos()
	p.update_frame(0.2)
	check(p.world_pos() == previous, "queued movement does not bypass stun")
	p.update_frame(0.4)
	check(p.world_pos().distance_to(previous) > 10, "hero resumes queued movement when stun ends")
	game._issue_player_order({"type":"smart", "point":Vector2(1500, -300)})
	check(p.move_target == Vector2(1500, 110), "off-bridge click maps to walkable lane boundary")
	for frame in range(200): p.update_frame(0.02)
	check(not p.has_move_target and p.world_pos().distance_to(Vector2(1500, 110)) < 3.1, "boundary move finishes instead of getting stuck")
	# A dash toward the cliff used to stay active forever because world clamping
	# prevented the hero from ever reaching the unbounded destination.
	p.global_position = Vector2(1400, 120)
	p._ashe_e(Vector2(1400, -200))
	check(p.dash_target.y == 110, "dash destination is reachable")
	for frame in range(100): p.update_frame(0.02)
	check(not p.is_dashing, "dash into bridge edge finishes")
	game._issue_player_order({"type":"smart", "point":Vector2(1430, 330)})
	previous = p.world_pos()
	p.update_frame(0.1)
	check(p.world_pos().distance_to(previous) > 10, "movement works immediately after edge dash")
	var enemy = GameState.champions[3]
	enemy.global_position = Vector2(1600, 270)
	game._issue_player_order({"type":"smart", "point":enemy.world_pos()})
	check(p.attack_target == enemy, "right-click still targets enemies")
	right_click(game, Vector2(1450, 380))
	check(p.attack_target == null and p.has_move_target and not p.attack_move, "ground click immediately breaks attack lock")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Battlefield movement input tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
