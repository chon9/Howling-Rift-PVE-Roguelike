extends Node

var failures = 0
var checks = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._show_menu()
	game._start_game("yasuo")
	await get_tree().process_frame
	# Both victory and defeat must decay while gameplay is stopped.
	for winner in [0, 1]:
		game._end_game(winner)
		check(not GameState.running and game.cam_shake_t == 1.0, "throne break queues end shake")
		game._process(0.01)
		var offset = game.camera.position - GameState.cam_target
		check(absf(offset.x) <= 12.0 and absf(offset.y) <= 12.0, "one-second shake stays within requested strength")
		game._process(1.1)
		check(game.cam_shake_t == 0.0 and game.cam_shake_amp == 0.0, "end-screen shake expires without simulation")
		check(game.camera.position == GameState.cam_target, "camera returns to exact follow position")
		# Returning immediately during a second effect must also clear it.
		game.camera_shake(1.0, 12.0)
		game._return_to_main_menu()
		await get_tree().process_frame
		check(game.cam_shake_t == 0.0 and game.cam_shake_amp == 0.0 and game.cam_shake_duration == 0.0, "return clears all shake state")
		game._show_menu()
		game._start_game("leesin")
		await get_tree().process_frame
		game._update_camera(0.016)
		check(game.camera.position == GameState.cam_target, "next round starts without inherited shake")
	# A later small hit must not inherit the throne's amplitude.
	game.camera_shake(0.08, 2.0)
	game._update_camera(0.01)
	check(game.cam_shake_amp == 2.0, "new hit uses its own amplitude")
	game._update_camera(0.1)
	check(game.cam_shake_t == 0.0 and game.camera.position == GameState.cam_target, "short shake expires without negative overshoot")
	game._return_to_main_menu()
	game.queue_free()
	await get_tree().process_frame
	print("CAMERA SHAKE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
