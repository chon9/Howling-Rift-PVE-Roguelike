extends Node
## W2-ZONES windowed visual (run without --headless, "-- --view3d", 1920x1080; both renderers).
## 68-3d-zones.png: the five GROUND_PROFILE pillars (Thresh R box included), Syndra sphere, Caitlyn trap, Thresh lantern
## + caption. 68-3d-zones-b.png: ring spikes, tornado, wind finisher, Xin Zhao swipes (uppercut and east), soul, dagger.
## 68-3d-zones-kits-a/b.png: every Roster12 and expansion kit's Q/W/E/R AoE (SkillFootprintTests-style gallery).
## Checks: each prop exists, is shown, and its projected card rect changes when the Fx root is hidden.
## Props come from View3D (VfxRegistry, W2-VFX) when it creates them; otherwise this test binds its own.

const OUT := "res://tests/"
const MATCH_SEED := 20261068
const ROSTER := {"blue": ["thresh", "xinzhao", "syndra"], "red": ["brand", "caitlyn", "xerath"]}
const FOCUS := Vector2(1400, 270)

var failures := 0
var checks := 0
var game: Node2D
var view: View3D
var own_props: Array = []
var hub_props := 0             # props View3D created through VfxRegistry (W2-VFX)
var own_count := 0             # props this test had to bind itself


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("ok: " + message)


func _ready() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("ZONE3D VISUAL: skipped in headless")
		print("ZONE3D VISUAL: 0 checks, 0 failures")
		get_tree().quit(0)
		return
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	game = _start_match()
	view = game.view3d
	check(view != null and view.is_active(), "3D view is active in the match")
	if view == null or not view.is_active():
		_finish()
		return
	GameState.running = true
	GameState.paused = true   # freeze clocks: the sim never steps here, AoEs keep their elapsed
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.global_position = Constants.FOUNT_R if c.team == 1 else Constants.FOUNT_B
	Input.warp_mouse(Vector2(4, 4))
	_aim_camera(FOCUS)
	await _shot_props()
	await _shot_kits("68-3d-zones-kits-a.png", RosterExpansion12.KEYS.slice(0, 9))
	await _shot_kits("68-3d-zones-kits-b.png", RosterExpansion12.KEYS.slice(9) + ExpansionRoster.KEYS)
	_finish()


func _finish() -> void:
	print("props from View3D/VfxRegistry: %d, bound by this test: %d" % [hub_props, own_count])
	print("ZONE3D VISUAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _start_match() -> Node2D:
	seed(MATCH_SEED)
	Progression.persistent = false
	GameState.reset()
	ViewConfig.enabled = true
	OS.set_environment("HOWLING_VIEW", "3d")
	var g: Node2D = load("res://scripts/Main.gd").new()
	add_child(g)
	g.set_process(false)
	g._start_game(ROSTER.blue[0], {"blue": ROSTER.blue.duplicate(), "red": ROSTER.red.duplicate(), "mode": "pve", "stolen_builds": []})
	return g


func _aim_camera(focus: Vector2) -> void:
	GameState.cam_locked = false
	GameState.cam_target = focus
	game.camera.position = focus
	game.camera_shake_offset = Vector2.ZERO


func _process(delta: float) -> void:
	for p in own_props:
		if is_instance_valid(p):
			p.sync(delta)


func _spawn(at: Vector2, opts: Dictionary, elapsed: float) -> Node2D:
	var o := {"dmg": 0.0, "duration": 4.0}
	o.merge(opts, true)
	game.spawn_aoe(GameState.player, at, o)
	var a: Node2D = GameState.aoes.back()
	a.elapsed = elapsed
	return a


## The prop for an AoE: View3D's own (registry) or one bound here.
func _prop_for(a: Node2D) -> Node3D:
	var v = view.view_for(a)
	if v is ZoneProp3D:
		hub_props += 1
		return v
	var p := ZoneProp3D.new()
	p.bind(a, view)
	view.add_fx(p)
	p.sync(0.0)
	own_props.append(p)
	own_count += 1
	return p


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(file: String) -> Image:
	await _frames(4)
	var img: Image = await View3DTestKit.capture(self)
	if img != null:
		img.save_png(OUT + file)
		print("saved %s %s" % [file, img.get_size()])
	check(img != null, "captured %s" % file)
	return img


## Image px per base (1920x1080 canvas) px.
func _screen_scale() -> Vector2:
	return Vector2(get_viewport().get_texture().get_size()) / get_viewport().get_visible_rect().size


## Projected image-space rect of all cards of a prop.
func _prop_rect(p: ZoneProp3D) -> Rect2i:
	var cam: Camera3D = view.camera()
	var pts := PackedVector2Array()
	for i in p.cards.size():
		var info: Dictionary = p.card_info(i)
		var hx: Vector3 = info.x_axis * info.width * 0.5
		var hy: Vector3 = info.up * info.height * 0.5
		for c in [info.centre - hx - hy, info.centre + hx - hy, info.centre + hx + hy, info.centre - hx + hy]:
			pts.append(cam.unproject_position(c) * _screen_scale())
	if pts.is_empty():
		return Rect2i()
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return Rect2i(r.position.floor(), r.size.ceil())


## Two shots of 4 x 2 props between the outer turrets: tall parts in the back row (y 205), short ones in front (y 300).
const COLUMNS := [1130.0, 1310.0, 1490.0, 1670.0]
const ROWS := [205.0, 300.0]


func _shot_props() -> void:
	await _prop_shot("68-3d-zones.png", [
		["brand_w", {"effect_id": "brand_w", "radius": 60.0, "arm_delay": 0.7, "duration": 1.1}, 0.8],
		["leona_r", {"effect_id": "leona_r", "radius": 60.0, "arm_delay": 0.65, "duration": 1.1}, 0.75],
		["xerath_w", {"effect_id": "xerath_w", "radius": 60.0, "arm_delay": 0.65, "duration": 1.1}, 0.75],
		["xerath_r", {"effect_id": "xerath_r", "radius": 60.0, "arm_delay": 0.65, "duration": 1.1}, 0.75],
		["thresh_r box", {"effect_id": "thresh_r", "zone_kind": "box", "radius": 60.0, "arm_delay": 0.5, "duration": 5.0}, 1.0],
		["syndra sphere", {"effect_id": "syndra_q", "zone_kind": "sphere", "radius": 38.0, "duration": 6.0}, 1.0],
		["caitlyn trap", {"effect_id": "caitlyn_w", "zone_kind": "trap", "radius": 35.0, "duration": 12.0, "arm_delay": 0.6}, 1.0],
		["thresh lantern", {"effect_id": "thresh_w", "zone_kind": "lantern", "radius": 50.0, "duration": 4.0}, 1.0],
	], 1)
	await _prop_shot("68-3d-zones-b.png", [
		["ring", {"ring": true, "radius": 60.0, "duration": 2.0, "color": Color(1.0, 0.55, 0.2)}, 0.4],
		["tornado", {"wind_kind": 1, "radius": 55.0, "duration": 0.6}, 0.2],
		["wind finisher", {"wind_kind": 3, "radius": 70.0, "duration": 0.6}, 0.2],
		["xinzhao_e", {"effect_id": "xinzhao_e", "radius": 65.0, "duration": 0.35, "effect_dir": Vector2(1, 0.3).normalized()}, 0.12],
		["soul", {"zone_kind": "soul", "effect_id": "thresh_soul", "radius": 18.0, "duration": 12.0}, 1.0],
		["dagger", {"zone_kind": "dagger", "effect_id": "katarina_dagger", "radius": 40.0, "duration": 5.0}, 1.0],
		["xinzhao_q uppercut", {"effect_id": "xinzhao_q", "radius": 48.0, "duration": 0.22, "effect_dir": Vector2.UP}, 0.08],
		["xinzhao_q east", {"effect_id": "xinzhao_q", "radius": 48.0, "duration": 0.22, "effect_dir": Vector2.RIGHT}, 0.08],
	], 0)


func _prop_shot(file: String, specs: Array, expected_labels: int) -> void:
	var aoes := []
	for i in specs.size():
		aoes.append(_spawn(Vector2(COLUMNS[i % 4], ROWS[i / 4]), specs[i][1], specs[i][2]))
	await _frames(3)
	var props := []
	for i in aoes.size():
		var a: Node2D = aoes[i]
		check(ZoneProp3D.wants(a), "%s wants a prop" % specs[i][0])
		props.append(_prop_for(a))
	await _frames(2)
	for i in props.size():
		var p: ZoneProp3D = props[i]
		check(is_instance_valid(p) and p.visible and p.kind != "", "%s prop is shown (%s)" % [specs[i][0], p.kind if is_instance_valid(p) else "-"])
	var shown := await _capture(file)
	view.fx_root.visible = false
	await _frames(3)
	var hidden: Image = await View3DTestKit.capture(self)
	view.fx_root.visible = true
	for i in props.size():
		var r := _prop_rect(props[i])
		var ratio := View3DTestKit.diff_ratio(shown, hidden, r, 0.06)
		check(r.size.x > 2 and r.size.y > 2 and ratio > 0.08, "%s prop renders (%.1f%% of %s changed)" % [specs[i][0], ratio * 100.0, r])
	var labels := 0
	for c in view.overhead.captions():
		if str(c.text) == "RIGHT-CLICK":
			labels += 1
	check(labels == expected_labels, "%s: %d RIGHT-CLICK caption(s) (own-team lanterns)" % [file, labels])
	await _clear(aoes)


func _shot_kits(file: String, keys: Array) -> void:
	var aoes := []
	for k in keys.size():
		for s in 4:
			var id: String = keys[k] + "_" + ["q", "w", "e", "r"][s]
			var at := Vector2(930 + k * 117, 140 + s * 92)
			aoes.append(_spawn(at, {"effect_id": id, "radius": 44.0, "duration": 2.0, "arm_delay": 0.3}, 0.7))
	await _frames(3)
	var standing := 0
	for a in aoes:
		if ZoneProp3D.wants(a):
			_prop_for(a)
			standing += 1
	print("%s: %d AoEs, %d with standing parts" % [file, aoes.size(), standing])
	await _capture(file)
	await _clear(aoes)


func _clear(aoes: Array) -> void:
	for a in aoes:
		if is_instance_valid(a):
			GameState.aoes.erase(a)
			a.queue_free()
	await _frames(2)
	own_props = own_props.filter(func(p): return is_instance_valid(p))
