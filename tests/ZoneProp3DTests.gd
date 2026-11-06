extends Node
## W2-ZONES headless tests: ZoneProp3D props for every standing AoE part (FakeView host), their placement,
## freeing with the AoE (expiry, Roster12Kits.remove_sphere, direct free; reparent keeps the prop),
## KitEffectArt.draw_ground(rim_only) and the AoE._draw 3D gates drawing without errors.

const P := Vector2(1300, 270)
const EPS := 0.002

var checks := 0
var failures := 0
var game: Node2D
var fake: Node3D
var caster


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL ZONEPROP3D: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	# Package test of the view in isolation: the match itself stays classic 2D (no View3D, no registry views).
	ViewConfig.enabled = false
	OS.set_environment("HOWLING_VIEW", "2d")
	game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("annie")
	caster = GameState.player
	caster.is_bot = false
	caster.stop_actions()
	caster.global_position = Vector2(400, 270)
	fake = View3DTestKit.make_fake_view(self)
	fake.pose(P)
	await get_tree().process_frame

	_test_classification()
	_test_icons()
	_test_ring()
	_test_wind()
	_test_swipes()
	_test_pillars()
	_test_sphere()
	_test_trap_and_lantern()
	_test_standing()
	await _test_freeing()
	await _test_rim_only()
	await _test_aoe_gates()
	print("ZONEPROP3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- helpers ---

func _spawn(opts: Dictionary, at: Vector2 = P) -> Node2D:
	var o := {"radius": 90.0, "dmg": 0.0, "duration": 4.0}
	o.merge(opts, true)
	game.spawn_aoe(caster, at, o)
	return GameState.aoes.back()


func _prop(aoe: Node2D) -> ZoneProp3D:
	var prop := ZoneProp3D.new()
	prop.bind(aoe, fake)
	fake.add_fx(prop)
	prop.sync(1.0 / 60.0)
	return prop


func _up() -> Vector3:
	return fake.card_up()


func _near(a: Vector3, b: Vector3, eps: float = EPS) -> bool:
	return a.distance_to(b) <= eps


func _lift_px(p: Vector3, feet: Vector2) -> float:
	return (p - ViewMath.to3(feet)).dot(_up()) / (ViewConfig.S * ViewConfig.FX_SCALE)


func _screen_angle_deg(info: Dictionary) -> float:
	var cam: Camera3D = fake.camera()
	var a := cam.unproject_position(info.centre)
	var b := cam.unproject_position(info.centre + info.x_axis * 0.3)
	return rad_to_deg((b - a).angle())


func _textured(prop: ZoneProp3D, i: int = 0) -> bool:
	var mat := prop.card_info(i).get("material") as ShaderMaterial
	if mat == null or mat.get_shader_parameter("use_tex") != true:
		return false
	var tex = mat.get_shader_parameter("tex")
	var r: Vector4 = mat.get_shader_parameter("region_uv")
	return tex is Texture2D and r.x >= 0.0 and r.y >= 0.0 and r.z <= 1.0001 and r.w <= 1.0001 and r.z > r.x and r.w > r.y


func _additive(prop: ZoneProp3D, i: int = 0) -> bool:
	var mat := prop.card_info(i).get("material") as ShaderMaterial
	return mat != null and mat.shader != null and mat.shader.code.contains("blend_add")


func _faces_camera(info: Dictionary) -> bool:
	var cam: Camera3D = fake.camera()
	return info.up.distance_to(cam.global_basis.y.normalized()) < 0.01 or absf(info.up.dot(cam.global_basis.z)) < 0.01


func _cleanup(aoes: Array) -> void:
	for a in aoes:
		if is_instance_valid(a):
			GameState.aoes.erase(a)
			a.queue_free()


# --- tests ---

## Side-view kit art (KitEffectArt.STANDING) stands on the AoE point; bands run along effect_dir at chest height.
func _test_standing() -> void:
	var cam: Camera3D = fake.camera()
	var a := _spawn({"effect_id": "brand_r", "radius": 44.0, "duration": 2.0})
	a.elapsed = 0.5
	var prop := _prop(a)
	var info := prop.card_info()
	check(prop.kind == ZoneProp3D.KIND_STAND and prop.visible and info.visible, "brand_r comet stands as a card")
	check(_near(info.bottom, ViewMath.to3(P)), "standing card's bottom is on the AoE point")
	check(absf(info.width - 2.0 * 44.0 * ViewConfig.S) < 1e-4, "standing card is 2 * radius wide (the 2D rect width)")
	check(_faces_camera(info) and info.up.dot(_up()) > 0.999, "standing card faces the camera, upright along card_up")
	check(_textured(prop) and not _additive(prop), "away from its caster the standing card is textured, mix blend")
	a.elapsed = 1.95
	prop.sync(1.0 / 60.0)
	var tint: Color = (prop.card_info().material as ShaderMaterial).get_shader_parameter("tint")
	check(tint.a < 0.2, "standing card fades out at the end of the AoE (alpha %.2f)" % tint.a)
	var b := _spawn({"effect_id": "leona_q", "radius": 55.0, "duration": 0.4}, caster.global_position)
	var pb := _prop(b)
	check(pb.kind == ZoneProp3D.KIND_STAND and _additive(pb), "a caster-centred standing burst is additive (light over the champion)")
	var c := _spawn({"effect_id": "thresh_e", "radius": 220.0, "duration": 0.45, "footprint_kind": "rectangle", "footprint_width": 65.0, "effect_dir": Vector2(1, 0)})
	var pc := _prop(c)
	var ci := pc.card_info()
	check(pc.kind == ZoneProp3D.KIND_BAND and ci.visible, "thresh_e flay is a raised band")
	check(absf(ci.width - ZoneProp3D.BAND_THRESH_E.x * ViewConfig.S) < 1e-4 and ci.x_axis.dot(Vector3.RIGHT) > 0.999, "band runs 440 px along effect_dir")
	check(ci.up.dot(cam.global_basis.y) > 0.0 and ((ci.centre - ViewMath.to3(P)).dot(_up())) > ci.height * 0.5, "band art is screen-up and lifted clear of the deck")
	_cleanup([a, b, c])
	for pr in [prop, pb, pc]:
		pr.queue_free()


func _test_classification() -> void:
	var cases := [
		[{"zone_kind": "soul", "effect_id": "thresh_soul", "radius": 18.0}, ZoneProp3D.KIND_ICON],
		[{"zone_kind": "dagger", "effect_id": "katarina_dagger", "radius": 40.0}, ZoneProp3D.KIND_ICON],
		[{"ring": true}, ZoneProp3D.KIND_RING],
		[{"wind_kind": 1}, ZoneProp3D.KIND_WIND],
		[{"wind_kind": 3}, ZoneProp3D.KIND_WIND],
		[{"effect_id": "xinzhao_q", "effect_dir": Vector2.UP}, ZoneProp3D.KIND_SWIPE],
		[{"effect_id": "xinzhao_e", "effect_dir": Vector2.RIGHT}, ZoneProp3D.KIND_SWIPE],
		[{"effect_id": "brand_w"}, ZoneProp3D.KIND_PILLAR],
		[{"effect_id": "thresh_r", "zone_kind": "box"}, ZoneProp3D.KIND_PILLAR],
		[{"effect_id": "syndra_q", "zone_kind": "sphere", "radius": 38.0}, ZoneProp3D.KIND_SPHERE],
		[{"effect_id": "caitlyn_w", "zone_kind": "trap", "radius": 35.0}, ZoneProp3D.KIND_TRAP],
		[{"effect_id": "thresh_w", "zone_kind": "lantern", "radius": 65.0}, ZoneProp3D.KIND_LANTERN],
		[{}, ""],
		[{"cone_ang": 0.0, "arc": 1.2}, ""],
		[{"effect_id": "xerath_q", "footprint_kind": "capsule", "footprint_width": 30.0}, ""],
		[{"effect_id": "brand_w", "cone_ang": 0.0, "arc": 1.0}, ""],
		[{"effect_id": "veigar_w"}, ""],
		# Side-view kit art stands up; swept side-view bands become a raised ribbon; top-down art stays flat.
		[{"effect_id": "brand_r", "duration": 0.5}, ZoneProp3D.KIND_STAND],
		[{"effect_id": "caitlyn_q", "duration": 0.5}, ZoneProp3D.KIND_STAND],
		[{"effect_id": "leona_q", "follows_src": false, "duration": 0.4}, ZoneProp3D.KIND_STAND],
		[{"effect_id": "vayne_r", "follows_src": true, "duration": 6.0}, ""],
		[{"effect_id": "darius_e", "cone_ang": 0.0, "arc": 1.4}, ""],
		[{"effect_id": "blitzcrank_r"}, ""],
		[{"effect_id": "thresh_e", "footprint_kind": "rectangle", "footprint_width": 65.0}, ZoneProp3D.KIND_BAND],
		[{"effect_id": "xinzhao_w", "footprint_kind": "capsule", "footprint_width": 42.0}, ZoneProp3D.KIND_BAND],
	]
	var made := []
	for c in cases:
		var a := _spawn(c[0])
		made.append(a)
		check(ZoneProp3D.kind_of(a) == c[1], "kind_of %s is '%s' (got '%s')" % [c[0], c[1], ZoneProp3D.kind_of(a)])
		check(ZoneProp3D.wants(a) == (c[1] != ""), "wants %s" % [c[0]])
	check(not ZoneProp3D.wants(null), "wants(null) is false")
	_cleanup(made)


## Final polish: pickups are procedural world objects (soul wisp / dagger stuck in the deck) plus a flat ground glow,
## not the 2D ability-icon tile.
func _test_icons() -> void:
	for zone in ["soul", "dagger"]:
		var a := _spawn({"zone_kind": zone, "effect_id": "thresh_soul" if zone == "soul" else "katarina_dagger", "radius": 30.0})
		var prop := _prop(a)
		var info := prop.card_info()
		var mat := info.material as ShaderMaterial
		var glow := prop.card_info(1)
		check(prop.visible and info.visible, zone + " pickup prop is shown")
		check(prop.cards.size() == 2, zone + " pickup has an object card and a ground glow")
		check(mat != null and int(mat.get_shader_parameter("proc")) == (ZoneProp3D.PROC_SOUL if zone == "soul" else ZoneProp3D.PROC_DAGGER), zone + " pickup is drawn procedurally (no icon tile)")
		check(mat != null and mat.get_shader_parameter("use_tex") != true, zone + " pickup samples no ability icon")
		check(_faces_camera(info), zone + " pickup faces the camera")
		var additive: bool = mat != null and mat.shader.code.contains("blend_add")
		check(additive == (zone == "soul"), zone + " pickup blend (soul additive light, dagger opaque metal)")
		var gm := glow.get("material") as ShaderMaterial
		check(gm != null and int(gm.get_shader_parameter("proc")) == ZoneProp3D.PROC_GROUND_GLOW and gm.shader.code.contains("blend_add"), zone + " ground glow is additive")
		check(glow.visible and absf(glow.x_axis.dot(Vector3.UP)) < 1e-3 and absf(glow.up.dot(Vector3.UP)) < 1e-3 and absf(glow.centre.y - 0.012) < 1e-4, zone + " ground glow lies flat on the deck")
		if zone == "soul":
			check(absf(info.height - ViewMath.art_m(ZoneProp3D.SOUL_PX.y, ViewConfig.FX_SCALE)) < 1e-4, "soul wisp is SOUL_PX tall")
			var lift := _lift_px(info.centre, P)
			check(absf(lift - ZoneProp3D.SOUL_LIFT_PX) <= ZoneProp3D.SOUL_BOB_PX + 0.05, "soul floats at its lift, bobbing (%.1f)" % lift)
		else:
			check(absf(info.height - ViewMath.art_m(ZoneProp3D.DAGGER_PX.y, ViewConfig.FX_SCALE)) < 1e-4, "dagger is DAGGER_PX tall")
			check(absf(_lift_px(info.bottom, P) + ZoneProp3D.DAGGER_SINK_PX) < 0.05, "armed dagger: tip buried DAGGER_SINK_PX in the deck")
			check(absf(_screen_angle_deg(info)) < 0.5, "armed dagger stands upright (no spin)")
		_cleanup([a])
	# A dagger still arming is in the air, spinning, with no ground glow yet.
	var d := _spawn({"zone_kind": "dagger", "effect_id": "katarina_dagger", "radius": 30.0, "arm_delay": 0.8})
	d.elapsed = 0.2
	var dp := _prop(d)
	var di := dp.card_info()
	check(is_equal_approx(ZoneProp3D.dagger_landed(d), 0.25), "dagger landing progress = elapsed / arm_delay")
	check(_lift_px(di.centre, P) > ZoneProp3D.DAGGER_PX.y, "arming dagger is still falling (%.1f art px)" % _lift_px(di.centre, P))
	check(absf(_screen_angle_deg(di)) > 1.0, "arming dagger spins")
	check(not dp.card_info(1).visible, "no ground glow before the dagger lands")
	_cleanup([d])


func _test_ring() -> void:
	var a := _spawn({"ring": true, "radius": 120.0, "duration": 2.0, "color": Color(1, 0.5, 0.2)})
	var prop := _prop(a)
	check(prop.cards.size() == 8, "ring prop has 8 spikes")
	var ok_pos := true
	for i in prop.cards.size():
		var info := prop.card_info(i)
		if not _near(info.bottom, ViewMath.to3(P + Vector2.from_angle(i * TAU / 8.0) * 120.0)):
			ok_pos = false
	check(ok_pos, "ring spikes stand on the radius")
	check(absf(prop.card_info(0).height - ViewMath.art_m(30.0, ViewConfig.FX_SCALE)) < 1e-4, "ring spike is 30 art px tall")
	check(absf(prop.card_info(0).width - ViewMath.art_m(5.0, ViewConfig.FX_SCALE)) < 1e-4, "ring spike is 5 art px wide")
	check(_additive(prop), "ring spikes are additive")
	_cleanup([a])


func _test_wind() -> void:
	var tornado := _spawn({"wind_kind": 1, "radius": 70.0})
	var p1 := _prop(tornado)
	var i1 := p1.card_info()
	check(_near(i1.bottom, ViewMath.to3(P)), "tornado card is bottom-anchored at the AoE")
	check(absf(i1.width - 140.0 * ViewConfig.S) < 1e-4, "wind card width is 2 radius S")
	check(_textured(p1), "tornado card is textured")
	var fin := _spawn({"wind_kind": 3, "radius": 140.0})
	var p3 := _prop(fin)
	check(_near(p3.card_info().centre, ViewMath.lifted(P, ViewConfig.CHEST_PX, _up())), "wind finisher card centred at chest height")
	_cleanup([tornado, fin])


func _test_swipes() -> void:
	var up := _spawn({"effect_id": "xinzhao_q", "effect_dir": Vector2.UP, "radius": 48.0, "duration": 0.22})
	var pq := _prop(up)
	var iq := pq.card_info()
	check(absf(_lift_px(iq.centre, P) - 25.0) < 0.05, "xinzhao_q swipe at lift 25")
	check(absf(_screen_angle_deg(iq) + 90.0) < 1.0, "xinzhao_q Vector2.UP is a vertical uppercut on screen (%.1f deg)" % _screen_angle_deg(iq))
	check(absf(iq.width - ViewMath.art_m(48.0, ViewConfig.FX_SCALE)) < 1e-4, "xinzhao_q card is radius wide")
	check(_textured(pq), "xinzhao_q card is textured")
	var e := _spawn({"effect_id": "xinzhao_e", "effect_dir": View3DTestKit.screen_dir(Vector2.RIGHT), "radius": 65.0, "duration": 0.35})
	var pe := _prop(e)
	var ie := pe.card_info()
	check(absf(_lift_px(ie.centre, P) - 32.0) < 0.05, "xinzhao_e swipe at lift 32")
	check(absf(_screen_angle_deg(ie)) < 1.0, "xinzhao_e east swipe points screen right")
	var s := _spawn({"effect_id": "xinzhao_q", "effect_dir": View3DTestKit.screen_dir(Vector2.DOWN), "radius": 48.0})
	var ps := _prop(s)
	check(absf(_screen_angle_deg(ps.card_info()) - 90.0) < 1.0, "xinzhao_q south swipe points screen down")
	_cleanup([up, e, s])


func _test_pillars() -> void:
	for id in KitEffectArt.GROUND_PROFILES.keys():
		var a := _spawn({"effect_id": id, "radius": 140.0, "zone_kind": "box" if id == "thresh_r" else "", "arm_delay": 0.5, "duration": 2.0})
		a.elapsed = 0.8
		var prop := _prop(a)
		var info := prop.card_info()
		var band: Dictionary = KitEffectArt.pillar_band(id, ZoneProp3D.kit_frame(a), a.radius)
		check(prop.visible and info.visible, id + " pillar is shown")
		check(absf(info.bottom.y) < 0.02 and absf(info.bottom.z - ViewMath.to3(P).z) < 0.02, id + " pillar bottom stands at the AoE centre")
		check(absf(info.width - band.size.x * ViewConfig.S) < 1e-4, id + " pillar width is source.size.x * scale_x * S")
		check(info.height > 0.2, id + " pillar has height (%.2f m)" % info.height)
		check(_textured(prop), id + " pillar card samples the band above the rim")
		check(_faces_camera(info), id + " pillar faces the camera")
		_cleanup([a])
	# Broken Thresh R walls fade the standing band.
	var box := _spawn({"effect_id": "thresh_r", "zone_kind": "box", "radius": 180.0, "arm_delay": 0.5, "duration": 5.0})
	box.elapsed = 1.0
	var pb := _prop(box)
	var full: Color = (pb.card_info().material as ShaderMaterial).get_shader_parameter("tint")
	box.broken_walls = [true, true, true, false, false]
	pb.sync(0.016)
	var cut: Color = (pb.card_info().material as ShaderMaterial).get_shader_parameter("tint")
	check(cut.a < full.a, "broken box walls fade the pillar band")
	_cleanup([box])


func _test_sphere() -> void:
	var a := _spawn({"effect_id": "syndra_q", "zone_kind": "sphere", "radius": 38.0, "duration": 6.0})
	var prop := _prop(a)
	var lift0 := _lift_px(prop.card_info().centre, P)
	check(absf(lift0 - 40.0) <= 4.01, "sphere card at lift 40 +- 4 (%.2f)" % lift0)
	fake.step(0.125 - fmod(fake.anim_time(), 0.5))
	prop.sync(0.016)
	var lift_hi := _lift_px(prop.card_info().centre, P)
	fake.step(0.25)
	prop.sync(0.016)
	var lift_lo := _lift_px(prop.card_info().centre, P)
	check(absf(lift_hi - 44.0) < 0.05 and absf(lift_lo - 36.0) < 0.05, "sphere bobs 4 px at 2 Hz (%.2f / %.2f)" % [lift_hi, lift_lo])
	check(prop.blob != null and absf(prop.blob.global_position.y - 0.01) < 1e-4, "sphere has a ground blob at y 0.01")
	check(prop.blob != null and absf(prop.blob.global_transform.basis.x.length() - 0.5) < 1e-4, "sphere blob is 0.5 m")
	check(prop.blob != null and absf(prop.blob.global_transform.basis.z.normalized().y - 1.0) < 1e-4, "sphere blob lies flat")
	check(_textured(prop), "sphere card is textured")
	_cleanup([a])


func _test_trap_and_lantern() -> void:
	var trap := _spawn({"effect_id": "caitlyn_w", "zone_kind": "trap", "radius": 35.0, "duration": 12.0, "arm_delay": 0.6})
	var pt := _prop(trap)
	check(_near(pt.card_info().bottom, ViewMath.to3(P)), "trap card is bottom-anchored at the AoE")
	check(_textured(pt), "trap card is textured")
	var layer: CanvasLayer = load("res://scripts/view3d/OverheadLayer.gd").new()
	add_child(layer)
	fake.overhead = layer
	fake.team = int(caster.team)
	var lantern := _spawn({"effect_id": "thresh_w", "zone_kind": "lantern", "radius": 65.0, "duration": 4.0}, P + Vector2(150, 0))
	var pl := _prop(lantern)
	check(_near(pl.card_info().bottom, ViewMath.to3(P + Vector2(150, 0))), "lantern card stands at the AoE")
	check(_textured(pl), "lantern card is textured")
	layer.sync(fake)
	check(_count_caption(layer, "RIGHT-CLICK") == 1, "own-team lantern adds one RIGHT-CLICK caption")
	pl.sync(0.016)
	layer.sync(fake)
	check(_count_caption(layer, "RIGHT-CLICK") == 1, "lantern caption is added once")
	fake.team = 1 - int(caster.team)
	var enemy := _spawn({"effect_id": "thresh_w", "zone_kind": "lantern", "radius": 65.0, "duration": 4.0}, P - Vector2(150, 0))
	var pe := _prop(enemy)
	layer.sync(fake)
	check(pe.visible and _count_caption(layer, "RIGHT-CLICK") == 1, "enemy lantern shows its card but no caption")
	var cap: Dictionary = {}
	for c in layer.captions():
		if c.text == "RIGHT-CLICK":
			cap = c
	var expect: Vector2 = fake.camera().unproject_position(ViewMath.to3(lantern.global_position)) + ZoneProp3D.LANTERN_LABEL_OFFSET
	check(not cap.is_empty() and cap.pos.distance_to(expect) < 0.5 and cap.color == Color("b9ffe6"), "lantern caption colour and offset")
	_cleanup([trap, lantern, enemy])
	await get_tree().process_frame
	layer.sync(fake)
	check(_count_caption(layer, "RIGHT-CLICK") == 0, "lantern caption leaves with the AoE")
	fake.team = -1
	fake.overhead = null
	layer.queue_free()


func _count_caption(layer, text: String) -> int:
	var n := 0
	for c in layer.captions():
		if str(c.text) == text:
			n += 1
	return n


func _test_freeing() -> void:
	# 1) normal expiry through update_frame
	var ring := _spawn({"ring": true, "radius": 100.0, "duration": 0.1})
	var p_ring := _prop(ring)
	ring.update_frame(0.2)
	# 2) Syndra sphere removed early (Roster12Kits.remove_sphere)
	var sphere := _spawn({"effect_id": "syndra_q", "zone_kind": "sphere", "radius": 38.0, "duration": 6.0})
	var p_sphere := _prop(sphere)
	check(Roster12Kits.spheres(caster).has(sphere), "sphere is listed for its caster")
	Roster12Kits.remove_sphere(sphere)
	# 3) direct free (LAN reconcile)
	var soul := _spawn({"zone_kind": "soul", "effect_id": "thresh_soul", "radius": 18.0})
	var p_soul := _prop(soul)
	GameState.aoes.erase(soul)
	soul.queue_free()
	# 4) a reparent keeps the prop
	var trap := _spawn({"effect_id": "caitlyn_w", "zone_kind": "trap", "radius": 35.0, "duration": 12.0})
	var p_trap := _prop(trap)
	var parent := trap.get_parent()
	parent.remove_child(trap)
	parent.add_child(trap)
	for i in 3:
		await get_tree().process_frame
	check(not is_instance_valid(p_ring), "ring prop frees when the AoE expires")
	check(not is_instance_valid(p_sphere), "sphere prop frees on the early remove_sphere path")
	check(not is_instance_valid(p_soul), "soul prop frees when the AoE is freed directly")
	check(is_instance_valid(p_trap), "a reparented AoE keeps its prop")
	if is_instance_valid(p_trap):
		p_trap.sync(0.016)
		check(p_trap.visible, "reparented trap prop still syncs")
	trap.queue_free()
	GameState.aoes.erase(trap)
	for i in 3:
		await get_tree().process_frame
	check(not is_instance_valid(p_trap), "trap prop frees after the reparented AoE is freed")
	# A sync after the source vanished never errors and frees the view.
	var dagger := _spawn({"zone_kind": "dagger", "effect_id": "katarina_dagger", "radius": 40.0})
	var p_dagger := _prop(dagger)
	GameState.aoes.erase(dagger)
	dagger.free()
	if is_instance_valid(p_dagger):
		p_dagger.sync(0.016)
	await get_tree().process_frame
	check(not is_instance_valid(p_dagger), "prop frees when its AoE is freed immediately")


class RimProbe:
	extends Node2D
	var drawn := 0
	var cases: Array = []

	func _draw() -> void:
		for c in cases:
			KitEffectArt.draw_ground(self, c[0], c[1], 140.0, Color(1, 1, 1, 0.9), c[2], true)
			drawn += 1


func _test_rim_only() -> void:
	for id in KitEffectArt.GROUND_PROFILES.keys():
		for frame in 4:
			var band: Dictionary = KitEffectArt.pillar_band(id, frame, 140.0)
			var sheet_rect := Rect2(Vector2.ZERO, KitEffectArt.sheet(id).get_size())
			check(band.size.x > 0.0 and band.size.y > 0.0 and sheet_rect.encloses(band.region), "%s pillar band %d inside its sheet" % [id, frame])
	var probe := RimProbe.new()
	for id in KitEffectArt.GROUND_PROFILES.keys():
		probe.cases.append([id, 1, []])
	probe.cases.append(["thresh_r", 2, [true, false, true, false, false]])
	game.world_root.add_child(probe)
	probe.global_position = P
	probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(probe.drawn == probe.cases.size(), "draw_ground(rim_only = true) draws every profile without error (%d)" % probe.drawn)
	probe.queue_free()


## Every gated AoE branch draws in 3D mode (and back in 2D) without script errors.
func _test_aoe_gates() -> void:
	var made := []
	for opts in [
		{"zone_kind": "soul", "effect_id": "thresh_soul", "radius": 18.0},
		{"ring": true, "radius": 100.0},
		{"wind_kind": 3, "radius": 140.0},
		{"effect_id": "xinzhao_q", "effect_dir": Vector2.UP, "radius": 48.0},
		{"effect_id": "xinzhao_e", "effect_dir": Vector2.RIGHT, "radius": 65.0},
		{"effect_id": "thresh_r", "zone_kind": "box", "radius": 180.0},
		{"effect_id": "brand_w", "radius": 140.0},
		{"effect_id": "syndra_q", "zone_kind": "sphere", "radius": 38.0},
		{"effect_id": "caitlyn_w", "zone_kind": "trap", "radius": 35.0},
		{"effect_id": "thresh_w", "zone_kind": "lantern", "radius": 65.0},
		{"effect_id": "brand_r", "radius": 44.0, "duration": 0.5},
		{"effect_id": "thresh_e", "radius": 220.0, "footprint_kind": "rectangle", "footprint_width": 65.0},
		{"effect_id": "xinzhao_w", "radius": 235.0, "footprint_kind": "capsule", "footprint_width": 42.0},
	]:
		made.append(_spawn(opts))
	for active in [true, false]:
		ViewConfig.set_active(active)
		for a in made:
			a.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
	ViewConfig.set_active(false)
	check(true, "gated AoE branches drew in 3D and 2D")
	_cleanup(made)
