extends Node
## W1-UNITS windowed visual: every hero and minion key, both teams, idle and attack frames, as 3D cards
## on a lit test floor with magenta feet markers and capsule shadows. Writes res://tests/64-3d-unit-grid.png.
## Pixel checks: the magenta marker in front of each unit's feet is visible (feet sit on markers) and
## the card body above the feet differs from the floor.

const ChampionS := preload("res://scripts/Champion.gd")
const MinionS := preload("res://scripts/Minion.gd")
const OUT := "res://tests/64-3d-unit-grid.png"
const COLS := 16
const DX := 92.0
const DY := 96.0
const ORIGIN := Vector2(560.0, 20.0)
const FLOOR_COLOR := Color(0.32, 0.36, 0.42)
const MAGENTA := Color(1.0, 0.0, 1.0)

var failures = 0
var checks = 0
var host: Node3D
var world: Node2D
var entries: Array = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL UNIT GRID: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	if DisplayServer.get_name() == "headless":
		print("UNIT GRID VISUAL: windowed only, skipped in headless")
		print("UNIT GRID VISUAL: 0 checks, 0 failures")
		get_tree().quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	host = View3DTestKit.make_fake_view(self)
	world = Node2D.new()
	world.name = "SimUnits"
	world.visible = false      # the 2D sim nodes never draw; only their 3D cards are seen
	add_child(world)
	_build_stage()
	_build_units()
	var rows := int(ceil(entries.size() / float(COLS)))
	var centre := ORIGIN + Vector2((COLS - 1) * DX * 0.5, (rows - 1) * DY * 0.5)
	_pose_camera(centre, 30.0)
	for i in 4:
		for e in entries:
			e.view.sync(0.016)
		await get_tree().process_frame
	var img: Image = await View3DTestKit.capture(self)
	check(img != null, "captured the frame")
	if img != null:
		img.save_png(OUT)
		_pixel_checks(img)
	print("UNIT GRID VISUAL: %d units, wrote %s" % [entries.size(), OUT])
	print("UNIT GRID VISUAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _build_stage() -> void:
	# Same per-renderer lights as the arena, so the lit floor matches between Compatibility and Forward+.
	var light := WorldBuilder3D.current_light_profile()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = light.ambient_color
	env.ambient_light_energy = light.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	host.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = light.sun_energy
	sun.light_color = light.sun_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	host.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80.0, 40.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR
	floor_mat.roughness = 0.95
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.material_override = floor_mat
	ground.position = ViewMath.to3(Vector2(1300, 500))
	host.add_child(ground)


func _build_units() -> void:
	if ActionSpriteArt.manifest.is_empty():
		ActionSpriteArt.entry("minion_melee")
	var keys: Array = ActionSpriteArt.manifest.keys()
	keys.sort()
	var heroes: Array = keys.filter(func(k): return str(k).begins_with("hero_"))
	var minions: Array = keys.filter(func(k): return str(k).begins_with("minion_"))
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.07
	marker_mesh.bottom_radius = 0.07
	marker_mesh.height = 0.01
	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = MAGENTA
	var index := 0
	for team in [Constants.BLUE, Constants.RED]:
		for action in ["idle", "attack"]:
			for key in heroes + minions:
				var pos := ORIGIN + Vector2((index % COLS) * DX, int(index / COLS) * DY)
				var unit = _make_unit(str(key), team, pos)
				if action == "attack":
					unit.anim_action = "attack"
					unit.anim_released = true
					unit.anim_elapsed = 0.0
					unit.anim_duration = 1000.0
				var view = UnitViewFactory.create(unit)
				host.add_unit_view(view)
				view.bind(unit, host)
				var marker := MeshInstance3D.new()
				marker.mesh = marker_mesh
				marker.material_override = marker_mat
				marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				marker.position = ViewMath.to3(pos, 0.006)
				host.add_child(marker)
				entries.append({"unit": unit, "view": view, "pos": pos, "key": key, "team": team, "action": action})
				index += 1


func _make_unit(key: String, team: int, pos: Vector2):
	var unit
	if key.begins_with("hero_"):
		unit = ChampionS.new()
		world.add_child(unit)
		var hero := key.trim_prefix("hero_")
		unit.setup(team, hero, true, hero)
		unit.facing = Vector2(1, 0) if team == Constants.BLUE else Vector2(-1, 0)
	else:
		unit = MinionS.new()
		world.add_child(unit)
		unit.setup(team, key.trim_prefix("minion_"), pos)
		unit.facing_sign = 1 if team == Constants.BLUE else -1
	unit.global_position = pos
	unit.set_process(false)
	unit.animator.set_process(false)
	unit.animator.idle_phase = 0.0
	return unit


func _pose_camera(focus: Vector2, distance: float) -> void:
	host.pose(focus)
	var cam: Camera3D = host.camera()
	var p: Dictionary = ViewConfig.camera_preset()
	var pitch := deg_to_rad(float(p.pitch))
	var target := ViewMath.to3(focus) + Vector3(0.0, 0.0, float(p.focus_z))
	cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * distance


func _pixel_checks(img: Image) -> void:
	var cam: Camera3D = host.camera()
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var on_marker := 0
	var bodies := 0
	var inside := 0
	for e in entries:
		var feet := ViewMath.to3(e.pos)
		var mark_px := cam.unproject_position(feet + Vector3(0.0, 0.006, 0.05)) * scale
		var body_px := cam.unproject_position(feet + host.card_up() * ViewMath.art_m(e.view.height_px * 0.3)) * scale
		var r := Rect2(Vector2.ZERO, Vector2(img.get_size()) - Vector2.ONE)
		if not r.has_point(mark_px) or not r.has_point(body_px):
			continue
		inside += 1
		if _magenta_near(img, Vector2i(mark_px), 3):
			on_marker += 1
		else:
			print("UNIT GRID: marker hidden in front of %s team %d %s at %s (likely a neighbour card)" % [e.key, e.team, e.action, mark_px])
		var bc := img.get_pixelv(Vector2i(body_px))
		var floor_like := absf(bc.r - FLOOR_COLOR.r) < 0.06 and absf(bc.g - FLOOR_COLOR.g) < 0.06 and absf(bc.b - FLOOR_COLOR.b) < 0.06
		if not floor_like:
			bodies += 1
	check(inside == entries.size(), "every unit is inside the frame (%d/%d)" % [inside, entries.size()])
	check(on_marker >= int(entries.size() * 0.95), "feet markers visible in front of the feet (%d/%d)" % [on_marker, inside])
	check(bodies >= int(entries.size() * 0.9), "card bodies drawn above the feet (%d/%d)" % [bodies, inside])
	for corner in [Vector2i(2, 2), Vector2i(img.get_width() - 3, 2), Vector2i(2, img.get_height() - 3), Vector2i(img.get_width() - 3, img.get_height() - 3)]:
		var c := img.get_pixelv(corner)
		check(c.a > 0.99, "opaque frame corner %s" % corner)
	print("UNIT GRID: markers %d/%d, bodies %d/%d" % [on_marker, inside, bodies, inside])


## Any clearly magenta pixel within radius px (neighbouring cards may overlap part of a marker).
func _magenta_near(img: Image, at: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var q := at + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
				continue
			var c := img.get_pixelv(q)
			if c.r > 0.75 and c.b > 0.75 and c.g < 0.3:
				return true
	return false
