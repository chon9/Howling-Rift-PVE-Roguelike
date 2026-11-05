extends Node
## W1-STRUCT: StructureView3D (card, plinth, glow, death dissolve, rubble, respawn) against a FakeView host.
## Headless. Views are created directly (no View3D dependency); the host clock is advanced by hand.

var failures = 0
var checks = 0
var host: Node3D
var world: Node2D


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	host = View3DTestKit.make_fake_view(self)
	host.set_process(false)
	world = Node2D.new()
	world.name = "World2D"
	add_child(world)
	await get_tree().process_frame
	_test_card_formula()
	_test_parts()
	_test_grounding()
	_test_death_and_rubble()
	_test_inhibitor_respawn()
	_test_hidden_and_fade()
	_test_paused_clock()
	_test_draw_gate()
	await _test_draw_gate_frame()
	await _test_frees_with_source()
	await _test_match_structures()
	await _test_see_through()
	host.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("STRUCTURE3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _make(team: int, type: String, pos: Vector2, variant := "") -> Node2D:
	var s: Node2D = load("res://scripts/Structure.gd").new()
	world.add_child(s)
	s.setup(team, type, pos, variant)
	return s


func _view(s: Node2D) -> StructureView3D:
	var v := StructureView3D.new()
	host.add_unit_view(v)
	v.bind(s, host)
	return v


func _advance(v: StructureView3D, seconds: float, steps: int = 4) -> void:
	for i in range(steps):
		host.step(seconds / float(steps))
		v.sync(seconds / float(steps))


func _test_card_formula() -> void:
	var k := ViewConfig.S * ViewConfig.STRUCTURE_SCALE
	var cases := [[0, "turret"], [1, "turret"], [0, "nexus_turret"], [1, "inhibitor"], [0, "nexus"]]
	for c in cases:
		var s := _make(c[0], c[1], Vector2(1200 + 40 * checks, 270))
		var v := _view(s)
		var region: Rect2 = s.tower_texture.region
		var ar: Rect2 = s.art_rect
		var u := -ar.position.x / ar.size.x
		var vv := -ar.position.y / ar.size.y
		var tag := "%s team %d" % [c[1], c[0]]
		check(v.body != null and v.body.region_enabled and v.body.region_rect == region, "card region is tower_texture.region (%s)" % tag)
		check(v.body.texture == s.tower_texture.atlas, "card texture is rift-structures.png (%s)" % tag)
		check(is_equal_approx(v.body.pixel_size, k * ar.size.x / region.size.x), "pixel_size = S*STRUCTURE_SCALE*art_w/region_w (%s)" % tag)
		check(v.body.offset.is_equal_approx(Vector2(-u * region.size.x, 0.0)), "card foot stands on the deck: offset = (-u*w, 0) (%s)" % tag)
		check(v.shadow_caster.offset.is_equal_approx(Vector2(-u * region.size.x, -(1.0 - vv) * region.size.y)), "shadow card rises from the base centre (%s)" % tag)
		check(not v.body.centered, "card is not centred (%s)" % tag)
		# Feet anchor: the art_rect left edge and top land where 2D drew them (in card-local metres).
		check(absf(v.body.offset.x * v.body.pixel_size - ar.position.x * k) < 1e-4, "card left edge = art_rect.x metres (%s)" % tag)
		# Region and art_rect aspects differ by <1%, so the card height matches the 2D art height within 1%.
		check(absf(region.size.y * v.body.pixel_size - ar.size.y * k) < 0.01 * ar.size.y * k, "card height = art height (%s)" % tag)
		check(absf(v.body.pixel_size * region.size.x - ar.size.x * k) < 1e-4, "card width = art_w * S * STRUCTURE_SCALE (%s)" % tag)
		check(v.position.is_equal_approx(ViewMath.to3(s.global_position)), "view sits at to3(feet) (%s)" % tag)
		check(is_equal_approx(v.body.rotation.x, -deg_to_rad(host.pitch_deg())), "card faces the camera (rotation.x = -pitch) (%s)" % tag)
		check(is_equal_approx(v.head_height_m(), -ar.position.y * k), "head_height_m from art_rect (%s)" % tag)
		var r := v.screen_rect(host.camera())
		var mid: Vector2 = host.world_to_screen(s.global_position, -ar.position.y * 0.5)
		check(r.has_area() and r.has_point(mid), "screen_rect covers the card body (%s)" % tag)
		check(v.card_mat != null and v.card_mat.shader == StructureView3D.CARD_SHADER, "card uses unit_card.gdshader (%s)" % tag)
		check(v.card_mat.get_shader_parameter("red_team") == false, "structures are never cloth-recoloured (%s)" % tag)
		v.free()
		s.free()


func _test_parts() -> void:
	var s := _make(0, "turret", Vector2(900, 270), "outer")
	var v := _view(s)
	check(v.plinth != null and v.plinth.mesh is CylinderMesh, "plinth is a cylinder")
	var pm: CylinderMesh = v.plinth.mesh
	check(pm.radial_segments == StructureView3D.PLINTH_SEGMENTS and is_equal_approx(pm.height, 0.1), "turret plinth is low (0.1 m) and round")
	var fp := StructureView3D.footprint_px("turret", s.art_rect, host.pitch_deg())
	var want_r := StructureView3D.PLINTH_FOOTPRINT_K * minf(fp.x, fp.y) * ViewConfig.S
	check(is_equal_approx(pm.bottom_radius, want_r), "ruin plinth radius fits inside the painted footprint (%.3f m)" % pm.bottom_radius)
	check(v.plinth.material_override == WorldBuilder3D.bare_stone_material(), "plinth uses the snow-free stone variant")
	var heights := {}
	for t in ["turret", "nexus_turret", "inhibitor", "nexus"]:
		heights[StructureView3D.plinth_height(t)] = true
	check(heights.size() == 4 and StructureView3D.plinth_height("nexus") <= StructureView3D.PLINTH_H_M, "each plinth type has its own height (no coplanar tops), all <= %.2f m" % StructureView3D.PLINTH_H_M)
	check(v.shadow_caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "shadow caster is SHADOWS_ONLY")
	check(v.shadow_caster.texture == v.body.texture and v.shadow_caster.region_rect == v.body.region_rect, "shadow card shows the structure's art")
	check(is_equal_approx(v.shadow_caster.rotation.y, deg_to_rad(WorldBuilder3D.SUN_ROT.y)) and is_equal_approx(v.shadow_caster.rotation.x, 0.0), "shadow card stands upright, turned to the sun")
	check(v.body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "card casts no shadow itself")
	check(v.glow != null and v.glow.visible, "crystal glow shown while alive")
	check(v.glow_mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "glow is additive")
	var want_lift := ViewMath.art_m(ViewMath.crystal_lift_px(s.art_rect), ViewConfig.STRUCTURE_SCALE)
	var along_up: float = v.glow.position.dot(host.card_up())
	check(absf(along_up - want_lift) < 0.02, "glow sits on the crystal")
	var lights := v.find_children("*", "Light3D", true, false)
	check(lights.is_empty(), "no light nodes on structures")
	var a0: float = v.glow_mat.albedo_color.a
	_advance(v, 0.7)
	check(not is_equal_approx(a0, v.glow_mat.albedo_color.a), "glow pulses with host.anim_time()")
	check(v.is_shown(), "alive structure card is shown")
	v.free()
	s.free()


## The sim point is the painted base's ground centre: the card stands in front of it so that row lands on it on screen.
func _test_grounding() -> void:
	var cam: Camera3D = host.camera()
	var tol := 0.012 * get_viewport().get_visible_rect().size.y
	var pitch: float = host.pitch_deg()
	for c in [[0, "turret"], [1, "turret"], [0, "nexus_turret"], [0, "inhibitor"], [1, "inhibitor"], [0, "nexus"], [1, "nexus"]]:
		var s := _make(c[0], c[1], Vector2(1300, 270))
		var v := _view(s)
		var tag := "%s team %d" % [c[1], c[0]]
		var fp := StructureView3D.footprint_px(c[1], s.art_rect, pitch)
		check(not v.plinth.visible, "standing structure shows no plinth: the painted base is the foundation (%s)" % tag)
		check(is_equal_approx(v.plinth.position.z, 0.0) and is_equal_approx(v.shadow_caster.position.z, 0.0), "plinth and shadow card sit on the sim point (%s)" % tag)
		check(s.art_rect.end.y > 0.0 and is_equal_approx(v.body.position.z, StructureView3D.card_forward_m(s.art_rect, pitch)), "card foot stands in front of the sim point (%s)" % tag)
		var r: float = (v.plinth.mesh as CylinderMesh).bottom_radius
		check(r < fp.x * ViewConfig.S and r < fp.y * ViewConfig.S, "ruin plinth stays inside the painted footprint (%s)" % tag)
		# On screen, the card row at the sim point's height covers the sim point.
		var foot: Vector3 = v.global_position + v.body.position
		var row := cam.unproject_position(foot + host.card_up() * maxf(s.art_rect.end.y, 0.0) * ViewConfig.S * ViewConfig.STRUCTURE_SCALE)
		var ground := cam.unproject_position(v.global_position)
		check(row.distance_to(ground) < tol, "painted base centre lands on the sim point (%s): %.1f px apart" % [tag, row.distance_to(ground)])
		var sh := StructureView3D.contact_shadow(c[1], s.art_rect, pitch)
		check(sh.center == Vector2.ZERO and sh.radii.x <= fp.x, "contact shadow is centred under the painted base and no wider than it (%s)" % tag)
		check(sh.radii.y <= fp.y + StructureView3D.CONTACT_LIP_PX + 0.01, "contact shadow core stays close to the base (%s)" % tag)
		check(s.collision_radius > 0.0 and s.collision_radius < fp.x, "solid circle sits inside the painted base (%s)" % tag)
		v.free()
		s.free()
	# Another pitch (mlbb preset) moves the card foot with it: h / sin(pitch) in front of the sim point.
	var s2 := _make(0, "turret", Vector2(1300, 270))
	var v2 := _view(s2)
	host.pose(View3DTestKit.FOCUS_SIM, "mlbb")
	v2.sync(0.0)
	check(is_equal_approx(v2.body.position.z, StructureView3D.card_forward_m(s2.art_rect, host.pitch_deg())) and is_equal_approx(v2.body.rotation.x, -deg_to_rad(host.pitch_deg())), "card foot follows the camera pitch")
	host.pose(View3DTestKit.FOCUS_SIM, ViewConfig.DEFAULT_PRESET)
	v2.free()
	s2.free()


func _test_death_and_rubble() -> void:
	var s := _make(1, "turret", Vector2(1500, 270), "inner")
	var v := _view(s)
	check(is_zero_approx(v.dissolve_amount()) and not v.has_rubble(), "alive: intact, no rubble")
	# Exactly what Main._handle_death does for a structure.
	s.dead = true
	s.visible = false
	s.is_targetable = false
	_advance(v, 0.4)
	check(v.dissolve_amount() > 0.4 and v.dissolve_amount() < 0.6, "dissolve ramps over 0.8 s (0.4 s -> ~0.5), got %.3f" % v.dissolve_amount())
	check(not v.has_rubble(), "no rubble before the dissolve finishes")
	check(v.plinth.visible, "the ruin plinth shows once the card starts to dissolve")
	check(v.visible and v.body.visible, "card still visible while dissolving")
	check(not v.glow.visible, "glow off once dead")
	check(is_equal_approx(float(v.card_mat.get_shader_parameter("dissolve")), v.dissolve_amount()), "dissolve uniform follows")
	_advance(v, 0.5)
	check(is_equal_approx(v.dissolve_amount(), 1.0), "fully dissolved after 0.8 s")
	check(v.has_rubble(), "rubble appears after the dissolve")
	check(v.rubble.multimesh.instance_count == 12 and v.rubble_xforms.size() == 12, "rubble has 12 boxes")
	check(v.rubble.position == Vector3.ZERO and v.plinth.position.z == 0.0, "rubble sits on the ruin plinth")
	var sizes_ok := true
	for xf in v.rubble_xforms:
		var sx: float = xf.basis.get_scale().x
		if sx < 0.149 or sx > 0.351:
			sizes_ok = false
	check(sizes_ok, "rubble boxes are 0.15-0.35 m")
	check(not v.body.visible, "card hidden once dissolved")
	check(v.visible and v.plinth.is_visible_in_tree(), "dead structure keeps plinth and rubble visible")
	check(not v.is_shown(), "dead structure is not shown for picking")
	# Determinism: same structure index -> same rubble layout.
	var v2 := _view(s)
	check(v2.has_rubble() and is_equal_approx(v2.dissolve_amount(), 1.0), "a view bound after death starts as rubble")
	check(v2.rubble_xforms[3].is_equal_approx(v.rubble_xforms[3]) and not v2.rubble_xforms[3].is_equal_approx(v2.rubble_xforms[4]), "rubble layout is seeded (deterministic)")
	v2.free()
	v.free()
	s.free()


func _test_inhibitor_respawn() -> void:
	var s := _make(1, "inhibitor", Vector2(2300, 270))
	var v := _view(s)
	s.dead = true
	s.visible = false
	_advance(v, 1.0)
	check(v.has_rubble() and is_equal_approx(v.dissolve_amount(), 1.0), "inhibitor dies to rubble")
	# Exactly what Structure.update_frame does on respawn.
	s.hp = s.hp_max
	s.dead = false
	s.is_targetable = true
	s.visible = true
	_advance(v, 0.25)
	check(not v.has_rubble(), "respawn removes the rubble")
	check(v.dissolve_amount() > 0.4 and v.dissolve_amount() < 0.6, "respawn reverses the dissolve over 0.5 s, got %.3f" % v.dissolve_amount())
	check(v.body.visible, "card visible again while re-forming")
	_advance(v, 0.3)
	check(is_zero_approx(v.dissolve_amount()), "respawn fully restores the card")
	check(v.glow.visible and v.is_shown(), "respawned inhibitor shows card and glow")
	check(not v.plinth.visible, "re-formed inhibitor hides the ruin plinth again")
	v.free()
	s.free()


func _test_hidden_and_fade() -> void:
	var s := _make(0, "turret", Vector2(1100, 270), "outer")
	var v := _view(s)
	s.visible = false
	v.sync(0.0)
	check(not v.visible and not v.is_shown(), "visible=false (alive) hides the view")
	check(not v.has_rubble() and is_zero_approx(v.dissolve_amount()), "hiding alone is not a death")
	s.visible = true
	v.sync(0.0)
	check(v.visible and v.is_shown(), "visible=true shows it again")
	s.modulate.a = 0.72
	v.sync(0.0)
	check(is_equal_approx(float(v.card_mat.get_shader_parameter("fade")), 0.72), "fade follows modulate.a")
	s.modulate.a = 1.0
	s.global_position = Vector2(1180, 300)
	v.sync(0.0)
	check(v.position.is_equal_approx(ViewMath.to3(Vector2(1180, 300))), "view follows global_position")
	# Views never write sim fields.
	check(s.visible and not s.dead and s.modulate.a == 1.0 and s.global_position == Vector2(1180, 300), "sim fields untouched by the view")
	v.free()
	s.free()


func _test_paused_clock() -> void:
	var s := _make(0, "nexus", Vector2(300, 270))
	var v := _view(s)
	s.dead = true
	s.visible = false
	_advance(v, 0.2)
	var d := v.dissolve_amount()
	GameState.paused = true
	for i in range(5):
		host.step(0.1)
		v.sync(0.1)
	check(is_equal_approx(v.dissolve_amount(), d), "dissolve freezes while GameState.paused")
	GameState.paused = false
	_advance(v, 0.2)
	check(v.dissolve_amount() > d, "dissolve resumes after unpause")
	v.free()
	s.free()


func _test_draw_gate() -> void:
	var s := _make(0, "turret", Vector2(1000, 270), "outer")
	check(s.has_method("_draw_ground_3d"), "Structure has the ground-only 3D draw branch")
	s.free()


func _test_draw_gate_frame() -> void:
	# Draw once with the 3D gate on: the ground-only branch must run without errors (range ring + shadow).
	GameState.player = null
	var s := _make(0, "turret", Vector2(1000, 270), "outer")
	var was := ViewConfig.is_active()
	ViewConfig.set_active(true)
	s.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	ViewConfig.set_active(was)
	check(is_instance_valid(s), "3D draw gate ran a frame without errors")
	s.free()


func _test_frees_with_source() -> void:
	var s := _make(1, "turret", Vector2(1700, 270), "outer")
	var v := _view(s)
	var ref: WeakRef = weakref(v)
	s.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(ref.get_ref() == null, "view frees itself on source.tree_exiting")


func _test_match_structures() -> void:
	GameState.reset()
	var game: Node2D = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("garen")
	await get_tree().process_frame
	var structures: Array = GameState.structures
	check(structures.size() >= 12, "match has structures (%d)" % structures.size())
	var views := []
	var ok := true
	var types := {}
	for s in structures:
		var v := _view(s)
		views.append(v)
		types[s.type] = true
		if not (v.is_shown() and v.position.is_equal_approx(ViewMath.to3(s.global_position)) and v.body.texture != null):
			ok = false
	check(views.size() == structures.size(), "a view for every structure (%d)" % views.size())
	check(ok, "every structure view is shown at its feet with a texture")
	check(types.size() == 4, "all four structure types present")
	var seeds := {}
	for v in views:
		seeds[v._rubble_seed()] = true
	check(seeds.size() == views.size(), "rubble seeds are unique per structure index")
	print("STRUCTURE3D: %d structures in match" % structures.size())
	for v in views:
		v.free()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()


## Final fix: a structure card that hides a champion standing on or behind its painted base (spawn behind the
## nexus) fades to OCCLUDE_ALPHA in a real 3D match, and clears again once the champion stands in front of it.
func _test_see_through() -> void:
	var game: Node2D = View3DTestKit.start_3d_match(self, "garen")
	await get_tree().process_frame
	var view3d = game.view3d
	check(view3d != null and view3d.is_active(), "see-through: 3D match is active")
	if view3d == null or not view3d.is_active():
		game.queue_free()
		return
	var p = GameState.player
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.global_position = Vector2(1400, 270) if c != p else Constants.FOUNT_B
	var nexus = GameState.nexus[p.team]
	var nv = view3d.view_for(nexus)
	var front: Vector2 = nexus.global_position + Vector2(0, 90)
	var behind: Vector2 = nexus.global_position - Vector2(0, nexus.collision_radius + 20.0)
	p.global_position = front
	view3d._step(0.5)
	check(nv is StructureView3D and nv.see_through() == 1.0, "see-through: the nexus is opaque while the player stands in front of it")
	p.global_position = behind
	view3d._step(0.05)
	check(nv.see_through() < 1.0 and nv.see_through() > StructureView3D.OCCLUDE_ALPHA, "see-through: the fade eases in over several frames (%.2f)" % nv.see_through())
	view3d._step(0.5)
	check(not nv.hides_champion(), "see-through: no frame data outside View3D._step")
	var fade: float = float(nv.card_mat.get_shader_parameter("fade"))
	check(is_equal_approx(nv.see_through(), StructureView3D.OCCLUDE_ALPHA) and is_equal_approx(fade, StructureView3D.OCCLUDE_ALPHA * nexus.modulate.a), "see-through: the nexus fades over the player at the fountain (fade %.2f)" % fade)
	var others := 0
	for s in GameState.structures:
		var sv = view3d.view_for(s)
		if sv != nv and sv is StructureView3D and sv.see_through() < 1.0:
			others += 1
	check(others == 0, "see-through: no other structure fades (%d)" % others)
	check(p.global_position == behind and nexus.modulate.a == 1.0 and not nexus.dead, "see-through: sim fields untouched")
	p.global_position = front
	view3d._step(0.5)
	check(nv.see_through() == 1.0, "see-through: the nexus is opaque again once the player steps in front (%.2f)" % nv.see_through())
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
