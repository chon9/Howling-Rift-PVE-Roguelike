class_name View3DTestKit
extends RefCounted
## Shared helpers for Rift3D package tests (W0-A; frozen). Owners add private helpers only in their own tests.

const FOCUS_SIM := Vector2(1300, 270)


## A ViewHost (plan 5.4) with a real Camera3D in the "lol" preset pose, for testing views in isolation.
class FakeView:
	extends Node3D

	var cam: Camera3D
	var units_root: Node3D
	var fx_root: Node3D
	var overhead: CanvasLayer = null
	var team: int = -1           # >= 0 overrides local_team()
	var focus: Vector2 = FOCUS_SIM
	var preset_name: String = ViewConfig.DEFAULT_PRESET
	var last_ground: Vector2 = FOCUS_SIM
	var _time: float = 0.0

	func _init() -> void:
		name = "FakeView"
		cam = Camera3D.new()
		cam.name = "Camera3D"
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.near = 0.5
		cam.far = 250.0
		add_child(cam)
		units_root = Node3D.new()
		units_root.name = "Units"
		add_child(units_root)
		fx_root = Node3D.new()
		fx_root.name = "Fx"
		add_child(fx_root)
		pose(FOCUS_SIM)

	func _ready() -> void:
		cam.make_current()

	## Re-aim the camera at a sim focus point (optionally with another preset).
	func pose(focus_sim: Vector2, preset := "") -> void:
		if preset != "":
			preset_name = preset
		focus = focus_sim
		var p: Dictionary = ViewConfig.PRESETS.get(preset_name, ViewConfig.PRESETS[ViewConfig.DEFAULT_PRESET])
		var pitch := deg_to_rad(float(p.pitch))
		var target := ViewMath.to3(focus_sim) + Vector3(0.0, 0.0, float(p.focus_z))
		cam.fov = float(p.fov)
		cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * float(p.distance)
		cam.rotation_degrees = Vector3(-float(p.pitch), 0.0, 0.0)

	func _process(delta: float) -> void:
		if not GameState.paused:
			_time += delta

	func camera() -> Camera3D:
		return cam

	func card_up() -> Vector3:
		return ViewMath.card_up(cam)

	func pitch_deg() -> float:
		return -cam.rotation_degrees.x

	func anim_time() -> float:
		return _time

	func local_team() -> int:
		if team >= 0:
			return team
		if GameState.player != null and is_instance_valid(GameState.player):
			return int(GameState.player.team)
		return 0

	func add_fx(node: Node3D) -> void:
		fx_root.add_child(node)

	func add_unit_view(node: Node3D) -> void:
		units_root.add_child(node)

	func overhead_layer() -> CanvasLayer:
		return overhead

	func world_to_screen(p: Vector2, h_art_px: float = 0.0) -> Vector2:
		return cam.unproject_position(ViewMath.lifted(p, h_art_px, card_up()))

	func screen_to_ground(screen: Vector2) -> Vector2:
		var hit = ViewMath.ground_hit(cam, screen)
		if hit != null:
			last_ground = ViewMath.to2(hit)
		return last_ground

	## Advance the fake clock by hand (tests that run with processing disabled).
	func step(delta: float) -> void:
		_process(delta)


static func make_fake_view(parent: Node) -> Node3D:
	var view := FakeView.new()
	parent.add_child(view)
	return view


## Starts a real match with the 3D view enabled (View3D is built by Main once W0-B lands).
static func start_3d_match(test: Node, hero: String) -> Node2D:
	Progression.persistent = false
	GameState.reset()
	ViewConfig.enabled = true
	# Main._ready re-runs ViewConfig.configure(); without this a HOWLING_VIEW=2d suite run turns 3D back off.
	OS.set_environment("HOWLING_VIEW", "3d")
	var game: Node2D = load("res://scripts/Main.gd").new()
	test.add_child(game)
	game.set_process(false)
	game._start_game(hero)
	return game


## Captures the root viewport after the next draw. Windowed only: returns null in headless.
static func capture(test: Node) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	return test.get_viewport().get_texture().get_image()


## Fraction (0..1) of pixels inside rect whose largest RGBA channel difference exceeds threshold (default 0.1).
## Rect is clipped to both images; returns 1.0 if either image is missing or the clipped rect is empty.
static func diff_ratio(a: Image, b: Image, rect: Rect2i, threshold: float = 0.1) -> float:
	if a == null or b == null:
		return 1.0
	var r := rect.intersection(Rect2i(Vector2i.ZERO, a.get_size())).intersection(Rect2i(Vector2i.ZERO, b.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return 1.0
	var differing := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), maxf(absf(ca.b - cb.b), absf(ca.a - cb.a))) > threshold:
				differing += 1
	return float(differing) / float(r.size.x * r.size.y)
