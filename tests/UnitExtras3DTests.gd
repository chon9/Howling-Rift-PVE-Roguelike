extends Node
## W2-EXTRAS: unit-attached effects (UnitExtras3D) against the FakeView host.
## Headless: every trigger (wind wall, shadow clone, recall pillar, level-up, blink flare and its exclusions).
## Windowed: also renders all effects once and saves .godot/v3d-logs/W2-EXTRAS-shots/69-3d-extras.png.

const ChampionS := preload("res://scripts/Champion.gd")
const SHOT_DIR := "res://.godot/v3d-logs/W2-EXTRAS-shots"

var failures = 0
var checks = 0
var host: Node3D
var world: Node2D


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL UNITEXTRAS3D: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	GameState.paused = false
	ViewConfig.set_active(false)
	host = View3DTestKit.make_fake_view(self)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	await get_tree().process_frame
	_test_contract_shapes()
	_test_idle_has_nothing()
	_test_wind_wall()
	_test_shadow_clone()
	_test_recall()
	_test_level_up()
	_test_blink()
	_test_paused_clock()
	await _test_flare_pause()
	await _test_frees_with_source()
	if DisplayServer.get_name() != "headless":
		await _visual_shot()
	GameState.paused = false
	host.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("UNITEXTRAS3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _champion(team: int, key: String, pos: Vector2) -> Node2D:
	var c = ChampionS.new()
	world.add_child(c)
	c.setup(team, key, true, key.capitalize())
	c.global_position = pos
	c.facing = Vector2(1, 0)
	c.animator.set_process(false)
	c.animator.idle_phase = 0.0
	c.animator.moving = false
	c.set_process(false)
	return c


func _view(unit) -> Node3D:
	var view = UnitViewFactory.create(unit)
	host.add_unit_view(view)
	view.bind(unit, host)
	view.sync(0.0)
	return view


## One sim frame: the sim clock advances (as Main._simulate_step does), then the view syncs.
func _tick(view) -> void:
	GameState.time += 0.016
	view.sync(0.016)


func _types(extras) -> Array:
	var out: Array = []
	for e in extras.events:
		out.append(e.type)
	return out


func _test_contract_shapes() -> void:
	# Unbound / sourceless use (as ViewContractsTests does) must be a silent no-op.
	var lone := UnitExtras3D.new()
	add_child(lone)
	lone.sync(0.016)
	var dummy := Node3D.new()
	lone.bind(dummy)
	lone.sync(0.016)
	check(lone.get_child_count() == 0 and lone.events.is_empty(), "sourceless extras create nothing")
	check(lone.top_level, "extras are top_level (children are placed in world space)")
	lone.free()
	dummy.free()


func _test_idle_has_nothing() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	for i in range(3):
		view.sync(0.016)
	check(ex.events.is_empty(), "an idle champion triggers no one-shot effects")
	for n in [ex.wind_wall, ex.shadow_clone, ex.recall_pillar, ex.level_pillar]:
		check(n == null or not n.visible, "idle champion shows no attached effect")
	check(ex.global_transform.is_equal_approx(Transform3D.IDENTITY), "extras root keeps an identity world transform")
	view.free()
	c.queue_free()


func _test_wind_wall() -> void:
	var c = _champion(Constants.BLUE, "yasuo", Vector2(1300, 280))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	c.buffs["wind_wall"] = {"direction": Vector2(0, -1), "time": 3.0}
	view.sync(0.016)
	var wall: MeshInstance3D = ex.wind_wall
	check(wall != null and wall.visible and wall.is_visible_in_tree(), "wind wall appears with buffs.wind_wall")
	if wall == null:
		return
	var width := 180.0 * ViewConfig.S
	var height := ViewMath.art_m(80.0)
	var b := wall.global_transform.basis
	var base := ViewMath.to3(c.global_position + Vector2(0, -1) * 50.0)
	check(not ex.wind_side, "north-facing wall is a world-vertical quad")
	check(absf(b.x.length() - width) < 1e-4 and absf(b.y.length() - height) < 1e-4, "wall is 180*S wide and art_m(80) high: %s x %s" % [b.x.length(), b.y.length()])
	check(b.y.normalized().is_equal_approx(Vector3.UP), "wall stands world-vertical")
	check(absf(b.x.normalized().dot(Vector3(0, 0, -1))) < 1e-4 and b.x.x > 0.0, "wall spans perpendicular to the direction, art left-to-right on screen")
	check(wall.global_position.distance_to(base + Vector3.UP * height * 0.5) < 1e-4, "wall bottom sits on the ground at feet + dir*50")
	var mat := wall.material_override as ShaderMaterial
	check(mat != null and mat.shader == UnitExtras3D.PILLAR_SHADER and int(mat.get_shader_parameter("mode")) == 0, "wall uses pillar_add atlas mode (additive)")
	check(mat != null and mat.get_shader_parameter("tex") == WindArt.texture, "wall samples the WindArt atlas")
	var ts := WindArt.texture.get_size()
	var seen := {}
	for i in range(8):
		host.step(1.0 / 12.0)
		view.sync(1.0 / 12.0)
		var uv: Vector4 = mat.get_shader_parameter("region_uv")
		seen[uv] = true
		check(absf(uv.y - 2.0 / 4.0) < 1e-4 and absf((uv.w - uv.y) - 0.25) < 1e-4, "wall frames come from WindArt row 2")
	check(seen.size() == 4, "wall animates through the 4 row-2 frames at 12 fps (%d distinct)" % seen.size())
	# East/west: the vertical wall would be edge-on, so a camera-facing card at 60% width is used.
	c.buffs["wind_wall"] = {"direction": Vector2(1, 0.1), "time": 3.0}
	view.sync(0.016)
	b = wall.global_transform.basis
	check(ex.wind_side, "east-facing wall switches to the camera-facing card")
	check(absf(b.x.length() - width * 0.6) < 1e-4, "side card is 60% wide")
	check(b.y.normalized().is_equal_approx(host.card_up()) and b.x.normalized().is_equal_approx(host.camera().global_basis.x.normalized()), "side card faces the camera")
	var dir := Vector2(1, 0.1).normalized()
	var base2 := ViewMath.to3(c.global_position + dir * 50.0)
	check(wall.global_position.distance_to(base2 + host.card_up() * height * 0.5) < 1e-4, "side card bottom sits at feet + dir*50")
	c.buffs.erase("wind_wall")
	view.sync(0.016)
	check(not wall.visible, "wind wall hides when the buff ends")
	view.free()
	c.queue_free()


func _test_shadow_clone() -> void:
	var c = _champion(Constants.RED, "zed", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	var point := Vector2(1400, 300)
	c.buffs["shadow"] = {"time": 4.0, "point": point, "swapped": false}
	view.sync(0.016)
	var clone: Sprite3D = ex.shadow_clone
	check(clone != null and clone.visible, "shadow clone appears with buffs.shadow")
	if clone == null:
		return
	var body: Sprite3D = view.body
	check(clone.global_position.distance_to(ViewMath.to3(point)) < 1e-4, "clone stands at buffs.shadow.point")
	check(clone.texture == body.texture and clone.region_rect == body.region_rect and clone.offset == body.offset and clone.flip_h == body.flip_h and is_equal_approx(clone.pixel_size, body.pixel_size), "clone shows the body's current frame")
	check(is_equal_approx(clone.rotation.x, -deg_to_rad(host.pitch_deg())), "clone faces the camera like the body")
	var mat := clone.material_override as ShaderMaterial
	check(mat != null and mat.get_shader_parameter("tint") == Vector3(0.6, 0.3, 0.9), "clone tint is (0.6, 0.3, 0.9)")
	check(mat != null and is_equal_approx(float(mat.get_shader_parameter("fade")), 0.5), "clone fade is 0.5")
	check(mat != null and mat.get_shader_parameter("red_team") == false, "clone of a red champion is not recoloured")
	c.facing = Vector2(-1, 0)
	view.sync(0.016)
	check(clone.flip_h == body.flip_h and clone.flip_h and clone.offset == body.offset, "clone follows the body flip")
	c.modulate.a = 0.72
	view.sync(0.016)
	check(absf(float(mat.get_shader_parameter("fade")) - 0.36) < 1e-4, "clone fade follows modulate.a (0.5 * 0.72)")
	c.modulate.a = 1.0
	c.buffs["airborne"] = {"time": 0.5, "duration": 1.0}
	view.sync(0.016)
	check(clone.global_position.distance_to(ViewMath.to3(point) + host.card_up() * ViewMath.art_m(30.0)) < 1e-4, "clone is lifted like the body (2D draws it with the same lift)")
	c.buffs.erase("airborne")
	c.buffs.erase("shadow")
	view.sync(0.016)
	check(not clone.visible, "clone hides when the shadow ends")
	view.free()
	c.queue_free()


func _test_recall() -> void:
	var c = _champion(Constants.BLUE, "garen", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	c.recall_time = 0.0
	view.sync(0.016)
	var pillar: MeshInstance3D = ex.recall_pillar
	check(pillar != null and pillar.visible, "recall pillar appears while recall_time >= 0")
	if pillar == null:
		return
	var cyl := pillar.mesh as CylinderMesh
	check(cyl != null and is_equal_approx(cyl.top_radius, 0.45) and is_equal_approx(cyl.bottom_radius, 0.45) and is_equal_approx(cyl.height, 2.6) and not cyl.cap_top and not cyl.cap_bottom, "recall pillar is an open cylinder r 0.45 m h 2.6 m")
	var up: Vector3 = host.card_up()
	check(pillar.global_position.distance_to(ViewMath.to3(c.global_position) + up * 1.3) < 1e-4, "recall pillar stands on the feet")
	check(pillar.global_basis.y.normalized().dot(up) > 0.9999, "recall pillar axis follows card_up (screen-upright like the unit cards)")
	check(absf(ex.recall_alpha() - 0.24) < 1e-4, "recall alpha starts at 0.24")
	var mat := pillar.material_override as ShaderMaterial
	var tint: Color = mat.get_shader_parameter("tint")
	check(int(mat.get_shader_parameter("mode")) == 1 and tint.b > tint.r and tint.g > tint.r, "recall pillar is a cyan procedural pillar")
	c.recall_time = c.recall_duration * 0.5
	view.sync(0.016)
	check(absf(ex.recall_alpha() - 0.36) < 1e-4, "recall alpha is 0.24 + 0.24*progress (0.36 at half)")
	var p0 = mat.get_shader_parameter("phase")
	host.step(0.25)
	view.sync(0.25)
	check(mat.get_shader_parameter("phase") != p0, "recall streaks scroll with the host clock")
	c.recall_time = -1.0
	view.sync(0.016)
	check(not pillar.visible, "recall pillar hides when the recall ends")
	c.recall_time = 0.3
	c.dead = true
	view.sync(0.016)
	check(not pillar.visible, "no recall pillar on a dead champion")
	view.free()
	c.queue_free()


func _test_level_up() -> void:
	var c = _champion(Constants.BLUE, "lux", Vector2(1300, 270))
	c.level = 3
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	view.sync(0.016)
	check(ex.events.is_empty(), "binding to a level-3 champion is not a level-up")
	c.level = 4
	view.sync(0.016)
	check(_types(ex).count("level_up") == 1, "a level increase triggers one level-up")
	var pillar: MeshInstance3D = ex.level_pillar
	check(pillar != null and pillar.visible, "gold level-up pillar is shown")
	if pillar == null:
		return
	var mat := pillar.material_override as ShaderMaterial
	var tint: Color = mat.get_shader_parameter("tint")
	check(tint.r > 0.9 and tint.g > 0.8 and tint.b < 0.5, "level-up pillar is gold")
	var foot: Vector3 = pillar.global_position - pillar.global_basis.y * UnitExtras3D.LEVEL_HEIGHT_M * 0.5
	check(foot.distance_to(ViewMath.to3(c.global_position)) < 1e-4 and pillar.global_basis.y.normalized().dot(host.card_up()) > 0.9999, "level-up pillar stands on the champion along card_up")
	view.sync(0.016)
	check(_types(ex).count("level_up") == 1, "an unchanged level does not retrigger")
	host.step(0.3)
	view.sync(0.3)
	check(pillar.visible and float(mat.get_shader_parameter("tint").a) < tint.a, "level-up pillar fades over its life")
	host.step(0.35)
	view.sync(0.35)
	check(not pillar.visible, "level-up pillar is gone after 0.6 s")
	c.level = 6
	view.sync(0.016)
	check(_types(ex).count("level_up") == 2 and pillar.visible, "a later level-up (even skipping levels) triggers again")
	c.level = 1
	view.sync(0.016)
	check(_types(ex).count("level_up") == 2, "a level decrease (reset) is not a level-up")
	# Replica-style: a champion whose level field is written by a snapshot (no setup) behaves the same.
	c.level = 2
	view.sync(0.016)
	check(_types(ex).count("level_up") == 3, "field-set level increase triggers (works on every peer)")
	view.free()
	c.queue_free()


func _test_blink() -> void:
	var c = _champion(Constants.BLUE, "ezreal", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	_tick(view)
	c.global_position += Vector2(60, 0)
	_tick(view)
	check(ex.events.is_empty(), "a 60 px step is not a blink")
	var from: Vector2 = c.global_position
	c.global_position += Vector2(200, 30)
	_tick(view)
	var t := _types(ex)
	check(t.count("blink_from") == 1 and t.count("blink_to") == 1, "a >120 px jump in one frame flares twice")
	if t.size() >= 2:
		check(ex.events[0].at == from and ex.events[1].at == c.global_position, "flares sit at the old and the new positions")
	ex.events.clear()
	# Airborne knock-ups, forced motion, recall teleports and respawns are not blinks.
	c.buffs["airborne"] = {"time": 0.5, "duration": 1.0}
	c.global_position += Vector2(200, 0)
	_tick(view)
	c.buffs.erase("airborne")
	_tick(view)
	c.buffs["forced_motion"] = {"time": 0.2, "destination": c.global_position + Vector2(300, 0)}
	c.global_position += Vector2(200, 0)
	_tick(view)
	c.buffs.erase("forced_motion")
	c.global_position += Vector2(-200, 0)
	_tick(view)
	check(ex.events.is_empty(), "no flare for airborne or forced motion (including the frame it ends)")
	c.recall_time = 0.9
	_tick(view)
	c.recall_time = -1.0
	c.global_position = Vector2(200, 270)
	_tick(view)
	check(ex.events.is_empty(), "no flare for the recall teleport")
	c.dead = true
	_tick(view)
	c.dead = false
	c.global_position = Vector2(1500, 270)
	_tick(view)
	check(ex.events.is_empty(), "no flare on respawn (dead was true)")
	_tick(view)
	c.global_position += Vector2(-250, 0)
	_tick(view)
	check(_types(ex).count("blink_to") == 1, "blinks are detected again after respawn")
	# Blink while hidden in enemy brush still logs, but emits nothing visible (FX calls are gated on visibility).
	ex.events.clear()
	c.visible = false
	_tick(view)
	c.global_position += Vector2(250, 0)
	_tick(view)
	check(_types(ex).count("blink_to") == 1, "hidden blink is still tracked")
	c.visible = true
	# Position writes outside a sim step (match setup, test placement) and paused frames never flare.
	ex.events.clear()
	c.global_position += Vector2(300, 0)
	view.sync(0.016)
	check(ex.events.is_empty(), "a jump without a sim step (setup / placement) is not a blink")
	GameState.paused = true
	GameState.time += 0.016
	c.global_position += Vector2(-300, 0)
	view.sync(0.016)
	GameState.paused = false
	check(ex.events.is_empty(), "a jump while GameState.paused is not a blink")
	# A batched catch-up step (0.5 s of sim between two syncs) may walk far: only beyond walking reach flares.
	var walk := float(c.move_speed) * 0.5
	GameState.time += 0.5
	c.global_position += Vector2(walk, 0)
	view.sync(0.016)
	check(ex.events.is_empty(), "walking %.0f px over a 0.5 s sim step is not a blink" % walk)
	_tick(view)
	c.global_position += Vector2(260, 0)
	_tick(view)
	check(_types(ex).count("blink_to") == 1, "a 260 px jump in one sim frame still flares")
	# Batched sim steps (View3DVisual's bot loop: 30 x 1/60 s per rendered frame) walking at full buffed speed.
	ex.events.clear()
	c.buffs["haste"] = {"time": 5.0, "mult": 1.3}
	var fast: float = c.effective_move_speed()
	for frame in range(6):
		for step in range(30):
			GameState.time += 1.0 / 60.0
			c.global_position += Vector2(fast / 60.0, 0)
		view.sync(0.016)
	check(ex.events.is_empty(), "30 batched sim steps per sync walking at %.0f px/s (%.0f px per sync) are not blinks" % [fast, fast * 0.5])
	# A frame hitch: Main subdivides one 0.15 s frame into 0.02 s sim steps, the view syncs once after them.
	GameState.time += 0.15
	c.global_position += Vector2(fast * 0.15, 0)
	view.sync(0.15)
	check(ex.events.is_empty(), "a 0.15 s frame hitch walking %.0f px is not a blink" % (fast * 0.15))
	c.buffs.erase("haste")
	# A long gap (> BLINK_MAX_DT of sim between syncs) is a discontinuity, never judged as a blink.
	GameState.time += 2.0
	c.global_position += Vector2(-900, 0)
	view.sync(0.016)
	check(ex.events.is_empty(), "a 2 s sim gap with a 900 px move is not judged as a blink")
	# A real Flash (400 px) inside a batched 0.25 s gap still flares at both ends.
	from = c.global_position
	GameState.time += 0.25
	c.global_position += Vector2(400, 0)
	view.sync(0.016)
	t = _types(ex)
	check(t.count("blink_from") == 1 and t.count("blink_to") == 1, "a 400 px Flash inside a 0.25 s batched gap still flares")
	if t.size() >= 2:
		check(ex.events[0].at == from and ex.events[1].at == c.global_position, "batched Flash flares at both ends")
	view.free()
	c.queue_free()


## Unbound flares (blink flashes) hold through a short pause but never stay on screen indefinitely.
func _test_flare_pause() -> void:
	var flares_before := _flares().size()
	FxCard3D.flare(host, Vector2(1300, 270), "blink", UnitExtras3D.BLINK_COLOR, UnitExtras3D.BLINK_LIFT)
	var made := _flares()
	check(made.size() == flares_before + 1, "flare spawned under the host")
	var f = made.back() if not made.is_empty() else null
	GameState.paused = true
	await get_tree().create_timer(0.2).timeout
	check(is_instance_valid(f) and not f.is_queued_for_deletion(), "a flare holds its frame through a short pause")
	await get_tree().create_timer(FxCard3D.FLARE_MAX_REAL).timeout
	await get_tree().process_frame
	check(not is_instance_valid(f), "a flare frozen by a pause still frees after FLARE_MAX_REAL s of real time")
	GameState.paused = false
	# Batched sim steps age a flare by game time: 0.5 s of sim in one frame ends a 0.3 s flash immediately.
	FxCard3D.flare(host, Vector2(1300, 270), "blink", UnitExtras3D.BLINK_COLOR, UnitExtras3D.BLINK_LIFT)
	var g = _flares().back() if not _flares().is_empty() else null
	GameState.time += 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(g), "a flare ends when the sim clock outruns its 0.3 s life (batched steps)")


func _flares() -> Array:
	var out: Array = []
	for n in host.fx_root.get_children():
		if n is FxCard3D and n.kind == "flare" and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _test_paused_clock() -> void:
	var c = _champion(Constants.BLUE, "yasuo", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	c.buffs["wind_wall"] = {"direction": Vector2(0, 1), "time": 3.0}
	view.sync(0.016)
	var mat := ex.wind_wall.material_override as ShaderMaterial
	var uv0 = mat.get_shader_parameter("region_uv")
	GameState.paused = true
	for i in range(4):
		host.step(1.0 / 12.0)
		view.sync(1.0 / 12.0)
	check(mat.get_shader_parameter("region_uv") == uv0, "wind wall frames freeze while GameState.paused")
	GameState.paused = false
	host.step(1.0 / 12.0)
	view.sync(1.0 / 12.0)
	check(mat.get_shader_parameter("region_uv") != uv0, "wind wall resumes after the pause")
	view.free()
	c.queue_free()


func _test_frees_with_source() -> void:
	var c = _champion(Constants.BLUE, "zed", Vector2(1300, 270))
	var view = _view(c)
	var ex: UnitExtras3D = view.extras
	c.buffs["shadow"] = {"time": 4.0, "point": Vector2(1350, 270), "swapped": false}
	c.recall_time = 0.2
	view.sync(0.016)
	var clone = ex.shadow_clone
	c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(ex) and not is_instance_valid(clone), "extras and their effects free with the source")


## Windowed only: every effect at once, for a human look. Not part of any gate screenshot set.
func _visual_shot() -> void:
	# Let the bursts and flares spawned by the logic tests above expire first.
	await get_tree().create_timer(1.2).timeout
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 20)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.16, 0.19, 0.25)
	floor_mesh.material_override = fm
	floor_mesh.position = ViewMath.to3(View3DTestKit.FOCUS_SIM, -0.01)
	host.add_fx(floor_mesh)
	# The 2D sim units would draw over the 3D frame in the root canvas; hide their parent (not the units).
	world.visible = false
	var views: Array = []
	var units: Array = []
	var yasuo = _champion(Constants.BLUE, "yasuo", Vector2(1080, 300))
	yasuo.buffs["wind_wall"] = {"direction": Vector2(0, -1), "time": 3.0}
	var yasuo2 = _champion(Constants.BLUE, "yasuo", Vector2(1180, 220))
	yasuo2.buffs["wind_wall"] = {"direction": Vector2(1, 0), "time": 3.0}
	var zed = _champion(Constants.RED, "zed", Vector2(1290, 300))
	zed.buffs["shadow"] = {"time": 4.0, "point": Vector2(1360, 250), "swapped": false}
	var garen = _champion(Constants.BLUE, "garen", Vector2(1450, 300))
	garen.recall_time = 0.6
	var lux = _champion(Constants.BLUE, "lux", Vector2(1560, 260))
	var ezreal = _champion(Constants.BLUE, "ezreal", Vector2(1700, 330))
	units = [yasuo, yasuo2, zed, garen, lux, ezreal]
	for u in units:
		views.append(_view(u))
	for i in range(10):
		await get_tree().process_frame
		for v in views:
			v.sync(0.016)
	lux.level = 2
	GameState.time += 0.016
	ezreal.global_position = Vector2(1790, 190)
	for i in range(8):
		for v in views:
			v.sync(0.016)
		await get_tree().process_frame
	check(lux.level == 2 and views[4].extras.level_pillar.visible, "shot: level-up pillar is up")
	check(_types(views[5].extras).count("blink_to") == 1, "shot: ezreal blink flared")
	var img: Image = await View3DTestKit.capture(self)
	check(img != null, "windowed capture works")
	if img != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		img.save_png(SHOT_DIR + "/69-3d-extras.png")
		print("UNITEXTRAS3D shot: ", ProjectSettings.globalize_path(SHOT_DIR + "/69-3d-extras.png"))
	for v in views:
		v.free()
	for u in units:
		u.queue_free()
	floor_mesh.queue_free()
	world.visible = true
	await get_tree().process_frame
