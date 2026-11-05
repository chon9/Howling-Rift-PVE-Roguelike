extends Node
var failures = 0

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func descendants(node: Node) -> Array:
	var result = [node]
	for child in node.get_children(): result.append_array(descendants(child))
	return result

func _ready() -> void:
	await get_tree().process_frame
	for stage in [12]:
		GameState.reset()
		Progression.levels.clear()
		Progression.credits = 1000
		Progression.difficulty = 12
		var game = load("res://scripts/Main.gd").new()
		add_child(game)
		game.set_process(false)
		game._start_game("ashe")
		var event = InputEventKey.new()
		event.pressed = true
		event.keycode = KEY_M
		game._input(event)
		check(GameState.paused and game.in_game_menu.has_node("MatchPanel"), "M opens paused menu")
		var time_before = GameState.time
		game._process(0.05)
		check(GameState.time == time_before, "combat does not advance while menu open")
		game._show_pause_upgrades()
		var p = GameState.player
		var max_before = p.hp_max
		var hp_before = p.hp
		for node in descendants(game.in_game_menu):
			if node is Button and node.text.begins_with("Vitality"): node.pressed.emit()
		check(p.hp_max == max_before and p.hp == hp_before, "permanent stats cannot change during a run")
		check(Progression.credits == 1000 and Progression.levels.get("vitality",0) == 0, "in-match account purchases are blocked")
		var enemy = GameState.champions[3]
		enemy.hp = enemy.hp_max * 0.5
		var old_max = enemy.hp_max
		for node in descendants(game.in_game_menu):
			if node is SpinBox: node.value = 99
		game.change_match_difficulty(99)
		check(GameState.difficulty == 12 and enemy.hp_max == old_max and absf(enemy.hp/enemy.hp_max-0.5)<0.001, "difficulty is locked without changing existing enemies")
		check(GameState.reward_difficulty == 12, "reward uses the difficulty selected before launch")
		game.change_match_difficulty(3)
		check(GameState.difficulty == 12 and Progression.difficulty == 12, "lowering difficulty mid-run is blocked")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://tests/11-in-game-menu.png")
		game.in_game_menu.get_node("MatchPanel/UpgradeLayer").queue_free()
		await get_tree().process_frame
		event.keycode = KEY_ESCAPE
		game._input(event)
		check(not GameState.paused and not game.in_game_menu.has_node("MatchPanel"), "Escape closes menu and resumes combat")
		GameState.paused = true
		game.toggle_in_game_menu()
		game.toggle_in_game_menu()
		check(GameState.paused, "closing preserves an existing pause")
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Progression.levels.clear()
	Progression.difficulty = 1
	print("In-game menu tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
