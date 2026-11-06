extends Node
## W1-ARENA: WorldBuilder3D geometry, clearance rule, deck coverage, materials, brush and lighting (headless).
## W3-POLISH: brush sway and eased fade, snow / mist / fountain pulse / crystal cores / ice clusters, the
## death-cam desaturation, quality toggles, and the CameraRig3D runtime preset switch plus wheel spring.

var failures = 0
var checks = 0


class FakeUnit:
	extends Node2D
	var dead := false
	func world_pos() -> Vector2:
		return global_position


class FakeStructure:
	extends Node2D
	var dead := false
	var team := 0
	var art_rect := Rect2(-52, -180, 104, 180)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	var host: Node3D = View3DTestKit.make_fake_view(self)
	var arena := WorldBuilder3D.new()
	add_child(arena)
	arena.build(null)
	await get_tree().process_frame
	_test_structure(arena)
	_test_clearance(arena)
	_test_deck(arena)
	_test_walls_outside_walkable(arena)
	_test_materials(arena)
	_test_brush(arena, host)
	_test_lighting(arena)
	_test_fountains(arena, host)
	_test_polish(arena, host)
	_test_rig()
	await _test_with_overlay()
	arena.queue_free()
	host.queue_free()
	await get_tree().process_frame
	print("ARENA3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_structure(arena: WorldBuilder3D) -> void:
	check(arena.name == "Arena", "arena node is named Arena")
	for n in ["Environment", "Sun", "Rim", "Deck", "Slab", "Walls", "Pillars", "Fountains", "Abyss", "Brush", "Props", "Ice", "Mist", "Snow", "CrystalGlow"]:
		check(arena.get_node_or_null(n) != null, "arena has child %s" % n)
	var abyss := arena.get_node_or_null("Abyss") as MeshInstance3D
	if abyss != null:
		check(is_equal_approx(abyss.position.y, -12.0), "abyss plane sits at y = -12")
		check((abyss.mesh as PlaneMesh).size == Vector2(300, 200), "abyss plane is 300 x 200 m")
	var props := 0
	var props_root := arena.get_node_or_null("Props")
	if props_root != null:
		for c in props_root.get_children():
			if c is MultiMeshInstance3D:
				props += c.multimesh.instance_count
	check(props == 30, "about 30 abyss props (got %d)" % props)
	var pillars := arena.get_node_or_null("Pillars") as MultiMeshInstance3D
	check(pillars != null and pillars.multimesh.instance_count >= 9, "pillars every 300 px under the near edge")
	if pillars != null:
		check(pillars.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "piers cast no shadow lattice")
		var pier_box: AABB = pillars.multimesh.mesh.get_aabb()
		check(pier_box.size.x <= 0.9 and pier_box.size.y > 10.0, "piers are slim stone piers with a capital (%.2f m wide, %.1f m tall)" % [pier_box.size.x, pier_box.size.y])
		var pier_mat := pillars.material_override as ShaderMaterial
		check(pier_mat == WorldBuilder3D.pier_stone_material() and is_zero_approx(float(pier_mat.get_shader_parameter("snow_amount"))) and float(pier_mat.get_shader_parameter("masonry")) > 0.5, "piers use the dark snow-free dressed stone (masonry courses)")
	var arches := arena.get_node_or_null("Arches") as MeshInstance3D
	check(arches != null and arches.mesh != null and arches.mesh.get_aabb().end.y <= -0.3 and arches.mesh.get_aabb().size.x > 40.0, "spandrel arches span the piers under the slab")
	var walls_mat := WorldBuilder3D.stone_material() as ShaderMaterial
	check(walls_mat != null and float(walls_mat.get_shader_parameter("masonry")) > 0.5, "walls are dressed masonry (ashlar courses, coping)")
	var ice_node := arena.get_node_or_null("Ice") as MultiMeshInstance3D
	check(ice_node != null and ice_node.material_override is ShaderMaterial and (ice_node.material_override as ShaderMaterial).shader.resource_path.ends_with("ice_crystal.gdshader"), "ice clusters use the faceted ice shader")
	var rocks := arena.get_node_or_null("Props/Rocks") as MultiMeshInstance3D
	check(rocks != null and rocks.material_override == WorldBuilder3D.deep_stone_material(), "abyss rocks carry no snow cap")
	var bare := WorldBuilder3D.bare_stone_material() as ShaderMaterial
	check(bare != null and is_zero_approx(float(bare.get_shader_parameter("snow_amount"))) and bare != WorldBuilder3D.stone_material(), "bare stone variant has snow_amount 0")
	var again := arena.get_child_count()
	arena.build(null)
	check(arena.get_child_count() == again, "build is idempotent")


func _test_clearance(arena: WorldBuilder3D) -> void:
	var profile := arena.wall_profile()
	check(profile.size() > 30, "wall_profile lists the far parapet, merlons and apron walls (%d)" % profile.size())
	var worst := -INF
	for e in profile:
		var y: float = float(e.z) / ViewConfig.S
		var limit := 0.0115 * (110.0 - y)
		worst = maxf(worst, float(e.top_m) - limit)
		check(float(e.top_m) <= limit + 1e-6, "far wall at y %.1f: top %.3f m <= clearance %.3f m" % [y, e.top_m, limit])
		check(y <= 110.0, "far wall element lies north of the walkable band (y %.1f)" % y)
	check(worst <= 1e-6, "clearance rule holds for every far-wall point (worst margin %.4f)" % worst)
	var parapet := profile.filter(func(e): return is_equal_approx(float(e.z), 70.0 * ViewConfig.S))
	check(not parapet.is_empty() and is_equal_approx(float(parapet[0].top_m), 0.42), "far parapet face at y 70 has top 0.42 m")
	var merlons := profile.filter(func(e): return is_equal_approx(float(e.z), 56.0 * ViewConfig.S))
	var tallest := 0.0
	var lowest := INF
	var heights := {}
	var gaps: Array = []
	var last_x := -INF
	for m in merlons:
		tallest = maxf(tallest, float(m.top_m))
		lowest = minf(lowest, float(m.top_m))
		heights[snappedf(float(m.top_m), 0.01)] = true
		var cx: float = (float(m.x0) + float(m.x1)) * 0.5
		if cx - last_x > 30.0:
			if last_x > -INF:
				gaps.append(cx - last_x)
			last_x = cx
	check(merlons.size() >= 30 and is_equal_approx(tallest, 0.62) and lowest >= 0.42, "merlons reach 0.42..0.62 m (%d pieces, %.2f..%.2f)" % [merlons.size(), lowest, tallest])
	# Final polish: the far parapet is not one repeated box: varied heights, broken stubs and an irregular rhythm.
	check(heights.size() >= 8, "merlon tops vary (%d distinct heights)" % heights.size())
	check(lowest < 0.53, "some merlons are broken stubs (lowest top %.2f m)" % lowest)
	var gmin := INF
	var gmax := 0.0
	for g in gaps:
		gmin = minf(gmin, g)
		gmax = maxf(gmax, g)
	check(gaps.size() >= 25 and gmax - gmin >= 8.0 and gmin >= 44.0, "merlon spacing wanders around 60 px (%.0f..%.0f px)" % [gmin, gmax])


func _walkable() -> Rect2:
	var lo := GameState.clamp_walkable(Vector2(-1e6, -1e6))
	var hi := GameState.clamp_walkable(Vector2(1e6, 1e6))
	return Rect2(lo, hi - lo)


func _test_deck(arena: WorldBuilder3D) -> void:
	var need := _walkable().grow(40.0)
	var rects: Array = arena._deck_rects
	check(not rects.is_empty(), "deck rects recorded")
	var missing := 0
	var y := need.position.y
	while y <= need.end.y + 0.01:
		var x := need.position.x
		while x <= need.end.x + 0.01:
			var hit := false
			for r in rects:
				if r.grow(0.01).has_point(Vector2(x, y)):
					hit = true
					break
			if not hit:
				missing += 1
			x += 20.0
		y += 20.0
	check(missing == 0, "deck covers the clamp_walkable rect +-40 (%d uncovered samples)" % missing)
	var deck := arena.get_node_or_null("Deck") as MeshInstance3D
	if deck == null:
		return
	var box := deck.get_aabb()
	var lo := ViewMath.to3(need.position)
	var hi := ViewMath.to3(need.end)
	check(box.position.x <= lo.x + 1e-3 and box.end.x >= hi.x - 1e-3 and box.position.z <= lo.z + 1e-3 and box.end.z >= hi.z - 1e-3, "deck mesh AABB spans the walkable rect +-40")
	check(absf(box.position.y) < 1e-4 and absf(box.end.y) < 1e-4, "deck top is flat at y = 0")
	check(deck.material_override == arena.ground_material, "deck uses ground_material")


func _test_walls_outside_walkable(arena: WorldBuilder3D) -> void:
	var walk := _walkable()
	for n in ["Walls", "Slab"]:
		var mi := arena.get_node_or_null(n) as MeshInstance3D
		if mi == null:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bad := 0
		for v in verts:
			var p := ViewMath.to2(v)
			if v.y > 0.001 and p.x > walk.position.x + 0.5 and p.x < walk.end.x - 0.5 and p.y > walk.position.y + 0.5 and p.y < walk.end.y - 0.5:
				bad += 1
		check(bad == 0, "%s: no raised geometry inside clamp_walkable (%d vertices)" % [n, bad])
		if n == "Slab":
			check(mi.get_aabb().end.y <= 0.0, "slab top stays below the deck")
	# Near rail stays low: every raised vertex south of the walkable band is at most 0.28 m.
	var walls := arena.get_node_or_null("Walls") as MeshInstance3D
	if walls != null:
		var verts: PackedVector3Array = walls.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var tallest := 0.0
		for v in verts:
			var p := ViewMath.to2(v)
			if p.y >= walk.end.y and p.x > -59.0 and p.x < 2859.0:
				tallest = maxf(tallest, v.y)
		check(tallest <= 0.28 + 1e-4 and tallest > 0.1, "near rail and apron walls are low (max %.3f m)" % tallest)


func _test_materials(arena: WorldBuilder3D) -> void:
	var gm := arena.ground_material
	check(gm != null and gm.shader != null and gm.shader.resource_path.ends_with("ground_deck.gdshader"), "ground_material uses ground_deck.gdshader")
	if gm == null or gm.shader == null:
		return
	var names: Array = []
	for u in gm.shader.get_shader_uniform_list():
		names.append(u.name)
	check(names.has("overlay_tex") and names.has("overlay_rect"), "ground_material has both overlay uniforms")
	check(names.has("albedo_tex") and gm.get_shader_parameter("albedo_tex") is Texture2D, "ground_material samples rift-lane")
	check(not gm.shader.code.contains("source_color"), "ground_deck never uses source_color")
	var stone := WorldBuilder3D.stone_material()
	check(stone is ShaderMaterial and stone == WorldBuilder3D.stone_material(), "stone_material is a cached ShaderMaterial")
	if stone is ShaderMaterial:
		check(stone.shader.resource_path.ends_with("stone.gdshader"), "stone_material uses stone.gdshader")
	for n in ["stone", "brush_card", "brush_card_fade", "abyss", "ground_deck"]:
		var sh: Shader = load("res://assets/shaders/view3d/%s.gdshader" % n)
		check(sh != null and sh.code.contains("view3d_common.gdshaderinc") and not sh.code.contains("source_color"), "%s follows the colour contract" % n)
	var abyss := arena.get_node_or_null("Abyss") as MeshInstance3D
	if abyss != null and abyss.material_override is ShaderMaterial:
		check(abyss.material_override.shader.resource_path.ends_with("abyss.gdshader"), "abyss uses abyss.gdshader")


func _test_brush(arena: WorldBuilder3D, _host: Node3D) -> void:
	var root := arena.get_node_or_null("Brush")
	if root == null:
		check(false, "brush root exists")
		return
	var total := 0
	var patches := 0
	for c in root.get_children():
		if c is MultiMeshInstance3D:
			patches += 1
			total += c.multimesh.instance_count
			var mat := c.material_override as ShaderMaterial
			check(mat != null and mat.shader.resource_path.ends_with("brush_card.gdshader"), "%s uses brush_card.gdshader" % c.name)
	check(patches == BrushVision.PATCHES.size(), "one brush patch per BrushVision patch")
	check(total == 6 * 22, "brush card count is 6 x 22 (got %d)" % total)
	# Every card stands inside (or within 22 px of) its patch rect.
	for i in range(mini(patches, BrushVision.PATCHES.size())):
		# MultiMesh transforms live on the RenderingServer (unreadable headless); the builder keeps a CPU copy.
		var points: PackedVector2Array = arena._brush_points[i]
		var rect: Rect2 = BrushVision.PATCHES[i].grow(22.0)
		var outside := 0
		for pt in points:
			if not rect.has_point(pt):
				outside += 1
		check(points.size() == 22, "patch %d records 22 card points" % i)
		check(outside == 0, "patch %d cards stay inside the patch (%d outside)" % [i, outside])
	# Fade follows the local player's patch.
	var unit := FakeUnit.new()
	add_child(unit)
	var saved = GameState.player
	GameState.player = unit
	unit.global_position = BrushVision.PATCHES[1].get_center()
	arena.update(_host, 0.016)
	var first := arena._brush_fade(1)
	check(first < 1.0 and first > 0.45, "patch 1 fade eases (not snapped) on the first frame (%.3f)" % first)
	var faded_early := root.get_node_or_null("Patch1") as MultiMeshInstance3D
	check(faded_early != null and (faded_early.material_override as ShaderMaterial).shader.resource_path.ends_with("brush_card_fade.gdshader"), "patch switches to the blended material as soon as it starts fading")
	_settle(arena, _host)
	check(is_equal_approx(arena._brush_fade(1), 0.45), "patch 1 settles at 0.45 while the player is inside")
	var faded_node := root.get_node_or_null("Patch1") as MultiMeshInstance3D
	var faded_mat: ShaderMaterial = null
	if faded_node != null:
		faded_mat = faded_node.material_override as ShaderMaterial
	check(faded_mat != null and faded_mat.shader.resource_path.ends_with("brush_card_fade.gdshader") and is_equal_approx(float(faded_mat.get_shader_parameter("fade")), 0.45), "faded patch swaps to the smooth alpha-blended brush material")
	var brush_inc := FileAccess.get_file_as_string("res://assets/shaders/view3d/brush_card.gdshaderinc")
	check(brush_inc != "" and not brush_inc.contains("screen_door"), "no screen-door dither in the brush shaders")
	var others_opaque := true
	for i in [0, 2, 3, 4, 5]:
		others_opaque = others_opaque and is_equal_approx(arena._brush_fade(i), 1.0)
	check(others_opaque, "other patches stay opaque")
	unit.global_position = Vector2(1400, 270)
	arena.update(_host, 0.016)
	check(arena._brush_fade(1) > 0.45 and arena._brush_fade(1) < 1.0, "patch 1 eases back toward opaque after the player leaves")
	_settle(arena, _host)
	check(is_equal_approx(arena._brush_fade(1), 1.0), "patch 1 is opaque again after the player leaves")
	if faded_node != null:
		check((faded_node.material_override as ShaderMaterial).shader.resource_path.ends_with("brush_card.gdshader"), "patch 1 returns to the opaque alpha-scissor material")
	GameState.player = null
	arena.update(_host, 0.016)
	check(is_equal_approx(arena._brush_fade(1), 1.0), "update without a player is safe")
	GameState.player = saved
	unit.queue_free()


func _test_lighting(arena: WorldBuilder3D) -> void:
	var sun := arena.get_node_or_null("Sun") as DirectionalLight3D
	var rim := arena.get_node_or_null("Rim") as DirectionalLight3D
	var we := arena.get_node_or_null("Environment") as WorldEnvironment
	check(sun != null and rim != null and we != null, "sun, rim and environment exist")
	if sun == null or rim == null or we == null:
		return
	# Compatibility uses its calibrated profile (lit-surface parity with Forward+).
	var fwd := WorldBuilder3D.light_profile("forward_plus")
	check(fwd.sun_energy > fwd.ambient_energy and fwd.sun_color.r > fwd.sun_color.b and fwd.ambient_color.b > fwd.ambient_color.r, "warm key light over cool ambient")
	var compat := WorldBuilder3D.light_profile("gl_compatibility")
	check(compat.sun_energy < fwd.sun_energy and compat.rim_energy < fwd.rim_energy, "Compatibility profile compensates display-space lighting (dimmer sun and rim)")
	var light := WorldBuilder3D.light_profile(RenderingServer.get_current_rendering_method())
	check(sun.rotation_degrees.is_equal_approx(WorldBuilder3D.SUN_ROT) and is_equal_approx(sun.light_energy, light.sun_energy), "sun pose and energy (%s profile)" % RenderingServer.get_current_rendering_method())
	check(sun.shadow_opacity <= 0.6 and sun.shadow_blur >= 2.0 and sun.rotation_degrees.x <= -60.0, "shadows stay short, soft and light")
	check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.directional_shadow_max_distance, 45.0), "sun PSSM 2 splits, 45 m")
	check(rim.rotation_degrees.is_equal_approx(WorldBuilder3D.RIM_ROT) and is_equal_approx(rim.light_energy, light.rim_energy) and not rim.shadow_enabled, "rim light without shadow")
	var e := we.environment
	check(e.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(e.tonemap_exposure, 1.0), "tonemap LINEAR, exposure 1")
	check(e.background_color.is_equal_approx(Color(0.02, 0.03, 0.06)), "background colour")
	check(fwd.fog_color.is_equal_approx(Color(0.06, 0.10, 0.18)), "Forward+ fog colour (0.06, 0.10, 0.18)")
	check(e.fog_enabled and is_equal_approx(e.fog_density, 0.012) and e.fog_light_color.is_equal_approx(light.fog_color), "depth fog colour and density")
	check(is_equal_approx(e.glow_hdr_threshold, 1.0) and is_equal_approx(e.glow_intensity, 0.6), "glow threshold 1.0, intensity 0.6")
	check(is_equal_approx(e.ambient_light_energy, light.ambient_energy) and e.ambient_light_color.is_equal_approx(light.ambient_color), "ambient from the renderer's light profile")
	check(e.fog_height < 0.0 and e.fog_height_density > 0.0, "height fog below the deck (off-lane space fades out)")
	arena.apply_quality(ViewConfig.QUALITY["low"])
	check(not sun.shadow_enabled and not e.glow_enabled, "low quality: no shadows, no glow")
	check(not arena.snow.visible and not arena.snow.emitting, "low quality: no snow")
	check(is_zero_approx(float(arena._brush_mats[0].get_shader_parameter("sway_m"))), "low quality: no brush sway")
	arena.apply_quality(ViewConfig.QUALITY["medium"])
	check(arena.snow.visible and arena.snow.emitting and is_equal_approx(float(arena._brush_mats[0].get_shader_parameter("sway_m")), 0.04), "medium quality: snow and sway on")
	arena.apply_quality(ViewConfig.QUALITY["high"])
	check(sun.shadow_enabled and e.glow_enabled, "high quality: shadows and glow")
	check(arena.snow.visible and arena.snow.emitting, "high quality: snow")
	# No OmniLight3D / SpotLight3D / Decal anywhere (Compatibility rules).
	var forbidden := 0
	var stack: Array = [arena]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is OmniLight3D or n is SpotLight3D or n is Decal:
			forbidden += 1
		stack.append_array(n.get_children())
	check(forbidden == 0, "no omni/spot lights or decals in the arena")


func _test_fountains(arena: WorldBuilder3D, host: Node3D) -> void:
	for pair in [["FountainBlue", Constants.FOUNT_B], ["FountainRed", Constants.FOUNT_R]]:
		var f := arena.get_node_or_null("Fountains/" + pair[0]) as Node3D
		check(f != null, "%s exists" % pair[0])
		if f == null:
			continue
		check(f.position.is_equal_approx(ViewMath.to3(pair[1])), "%s sits at its fountain" % pair[0])
		var disc := f.get_node("Disc") as MeshInstance3D
		var cyl := disc.mesh as CylinderMesh
		check(is_equal_approx(cyl.top_radius, 78.0 * ViewConfig.S) and is_equal_approx(cyl.height, 0.05), "%s disc r 78 px, 0.05 m" % pair[0])
		var ring := f.get_node("Ring") as MeshInstance3D
		var glow := ring.material_override as StandardMaterial3D
		check(glow != null and glow.emission_enabled and glow.emission_energy_multiplier >= 2.0 * 0.69 and glow.emission_energy_multiplier <= 2.0 * 1.31, "%s ring is emissive about x2 (pulsing, %.2f)" % [pair[0], glow.emission_energy_multiplier])
		var halo := f.get_node_or_null("Halo") as MeshInstance3D
		check(halo != null and halo.material_override is ShaderMaterial and float(halo.material_override.get_shader_parameter("energy")) > 1.0, "%s has an HDR halo (blooms)" % pair[0])
	arena.ground_material.set_shader_parameter("overlay_rect", Vector4(10, 20, 300, 400))
	arena.update(host, 0.0)
	var disc_mat := (arena.get_node("Fountains/FountainBlue/Disc") as MeshInstance3D).material_override as ShaderMaterial
	check(disc_mat.get_shader_parameter("overlay_rect") == Vector4(10, 20, 300, 400), "fountain discs follow the deck's overlay rect")


func _test_with_overlay() -> void:
	# A GroundOverlay (stub or the W1-HUB one) can be passed to build(); headless never binds a texture.
	var overlay := GroundOverlay.new()
	add_child(overlay)
	overlay.configure(Vector2i(256, 128))
	var arena := WorldBuilder3D.new()
	add_child(arena)
	arena.build(overlay)
	await get_tree().process_frame
	check(arena.get_node_or_null("Deck") != null and arena.ground_material != null, "build(overlay) builds the deck")
	check(arena.ground_material.get_shader_parameter("overlay_tex") is Texture2D, "overlay_tex always has a texture")
	arena.queue_free()
	overlay.queue_free()
	await get_tree().process_frame


func _settle(arena: WorldBuilder3D, host: Node3D) -> void:
	for i in 60:
		arena.update(host, 0.05)


func _test_polish(arena: WorldBuilder3D, host: Node3D) -> void:
	# Sway: every brush material sways (1.3 Hz, 0.04 m) on the host clock, frozen while paused.
	var bm := arena._brush_mats[0] as ShaderMaterial
	check(is_equal_approx(float(bm.get_shader_parameter("sway_hz")), 1.3) and is_equal_approx(float(bm.get_shader_parameter("sway_m")), 0.04), "brush sway 1.3 Hz, 0.04 m")
	var inc := FileAccess.get_file_as_string("res://assets/shaders/view3d/brush_card.gdshaderinc")
	check(inc.contains("sway_time") and inc.contains("VERTEX +="), "brush shader sways in vertex()")
	host.step(0.5)
	arena.update(host, 0.016)
	var t0 := float(bm.get_shader_parameter("sway_time"))
	check(t0 > 0.0 and is_equal_approx(t0, host.anim_time()), "sway clock is the host anim_time (%.2f)" % t0)
	var mist := arena.mist_material
	check(mist != null and is_equal_approx(float(mist.get_shader_parameter("mist_time")), host.anim_time()), "mist scrolls on the host clock")
	var mist_node := arena.get_node_or_null("Mist") as MeshInstance3D
	check(mist_node != null and mist_node.position.y < 0.0 and mist_node.position.y > -12.0, "mist sheet lies between the deck and the abyss")
	# Fountain pulse follows the clock.
	var ring := (arena.get_node("Fountains/FountainBlue/Ring") as MeshInstance3D).material_override as StandardMaterial3D
	var e0 := ring.emission_energy_multiplier
	host.step(0.5)
	arena.update(host, 0.016)
	check(not is_equal_approx(e0, ring.emission_energy_multiplier), "fountain ring pulses (%.2f -> %.2f)" % [e0, ring.emission_energy_multiplier])
	# Snow: 300 flakes, world-space, following the camera focus.
	var snow := arena.snow
	check(snow != null and snow.amount == 300 and not snow.local_coords, "snow: 300 world-space particles")
	var cam: Camera3D = host.camera()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.global_position, -cam.global_basis.z)
	check(hit != null and Vector2(snow.global_position.x, snow.global_position.z).distance_to(Vector2(hit.x, hit.z)) < 0.01 and snow.global_position.y > 3.0, "snow box hovers over the camera focus")
	GameState.paused = true
	arena.update(host, 0.016)
	check(is_zero_approx(snow.speed_scale), "snow freezes while paused")
	GameState.paused = false
	arena.update(host, 0.016)
	check(is_equal_approx(snow.speed_scale, 1.0), "snow resumes")
	# Ice clusters: outside clamp_walkable; north ones obey the clearance rule (they are in wall_profile).
	var walk := _walkable()
	var ice := arena.ice_points()
	var inside := 0
	var tall_south := 0
	var bad_clear := 0
	for pt in ice:
		var r := Rect2(pt.pos - Vector2.ONE * pt.r_px, Vector2.ONE * pt.r_px * 2.0)
		if r.intersects(walk):
			inside += 1
		if pt.pos.y - pt.r_px > walk.end.y and pt.top_m > 0.28 + 1e-4:
			tall_south += 1
		if pt.pos.y + pt.r_px < 110.0 and pt.top_m > 0.0115 * (110.0 - (pt.pos.y + pt.r_px)) + 1e-6:
			bad_clear += 1
	check(ice.size() == 48, "48 ice crystals in 16 clusters (%d)" % ice.size())
	check(inside == 0, "ice clusters stay outside clamp_walkable (%d inside)" % inside)
	check(tall_south == 0, "south ice stays <= 0.28 m (%d taller)" % tall_south)
	check(bad_clear == 0, "north ice obeys the clearance rule (%d violations)" % bad_clear)
	check(arena.wall_profile().filter(func(e): return e.get("kind", "") == "ice").size() > 0, "north ice is listed in wall_profile")
	# Death cam: desaturates while the local player is dead, eases back on respawn.
	var unit := FakeUnit.new()
	add_child(unit)
	unit.global_position = Vector2(1400, 270)
	var saved = GameState.player
	GameState.player = unit
	arena.update(host, 0.016)
	check(is_equal_approx(arena.death_saturation(), 1.0) and not arena.environment.adjustment_enabled, "alive: no colour adjustment")
	unit.dead = true
	arena.update(host, 0.1)
	var mid := arena.death_saturation()
	check(mid < 1.0 and mid > 0.35, "death cam eases toward grey (%.2f)" % mid)
	_settle(arena, host)
	check(is_equal_approx(arena.death_saturation(), 0.35) and arena.environment.adjustment_enabled and is_equal_approx(arena.environment.adjustment_saturation, 0.35), "dead: world saturation 0.35")
	unit.dead = false
	_settle(arena, host)
	check(is_equal_approx(arena.death_saturation(), 1.0) and not arena.environment.adjustment_enabled, "respawn: colours restored")
	GameState.player = saved
	unit.queue_free()
	# Crystal cores: one HDR core per shown structure, hidden when dead or invisible, freed with the structure.
	var saved_structs: Array = GameState.structures.duplicate()
	var st := FakeStructure.new()
	add_child(st)
	st.global_position = Vector2(900, 270)
	GameState.structures = [st]
	arena.update(host, 0.016)
	check(arena.crystal_core_count() == 1, "a live structure gets a crystal core")
	var core_root := arena.get_node("CrystalGlow")
	var core := core_root.get_child(0) as MeshInstance3D if core_root.get_child_count() > 0 else null
	check(core != null, "crystal core node exists")
	if core != null:
		var want: Vector3 = ViewMath.to3(st.global_position) + host.card_up() * ViewMath.art_m(ViewMath.crystal_lift_px(st.art_rect), ViewConfig.STRUCTURE_SCALE)
		check(core.global_position.distance_to(want) < 1e-3, "core sits on the crystal")
		var cm := core.material_override as ShaderMaterial
		check(cm != null and float(cm.get_shader_parameter("energy")) > 1.0 and cm.get_shader_parameter("billboard") == true, "core is an HDR billboard")
	st.dead = true
	arena.update(host, 0.016)
	check(arena.crystal_core_count() == 0, "dead structure: no core")
	st.dead = false
	st.visible = false
	arena.update(host, 0.016)
	check(arena.crystal_core_count() == 0, "hidden structure: no core")
	GameState.structures = []
	arena.update(host, 0.016)
	var live := 0
	for c in core_root.get_children():
		if not c.is_queued_for_deletion():
			live += 1
	check(live == 0, "crystal cores are freed with their structure (%d left)" % live)
	GameState.structures = saved_structs
	st.queue_free()
	for n in ["glow_add", "abyss_mist"]:
		var sh: Shader = load("res://assets/shaders/view3d/%s.gdshader" % n)
		check(sh != null and sh.code.contains("view3d_common.gdshaderinc") and not sh.code.contains("source_color"), "%s follows the colour contract" % n)


func _test_rig() -> void:
	var saved := ViewConfig.preset
	ViewConfig.preset = "lol"
	var rig := CameraRig3D.new()
	add_child(rig)
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 0.0)
	check(is_equal_approx(rig.pitch(), 56.0) and is_equal_approx(rig.camera.fov, 40.0), "rig starts in the lol preset")
	# Runtime switch: ViewConfig.preset changes mid-match -> smooth blend, then exact mlbb values.
	ViewConfig.preset = "mlbb"
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	check(rig.preset_name == "mlbb" and rig.is_blending(), "preset change detected and blending")
	check(rig.pitch() < 56.0 and rig.pitch() > 50.0, "pitch blends between presets (%.2f)" % rig.pitch())
	for i in 120:
		rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	var mp: Dictionary = ViewConfig.PRESETS.mlbb
	check(not rig.is_blending() and is_equal_approx(rig.pitch(), float(mp.pitch)) and is_equal_approx(rig.camera.fov, float(mp.fov)) and absf(rig.distance() - float(mp.distance)) < 0.01, "mlbb reached: pitch %.0f, fov %.0f, %.1f m (%.2f, %.2f, %.3f)" % [mp.pitch, mp.fov, mp.distance, rig.pitch(), rig.camera.fov, rig.distance()])
	var focus := ViewMath.to3(Vector2(1300, 270)) + Basis(Vector3.UP, ViewConfig.yaw_rad()) * Vector3(0, 0, 0.3)
	check(absf(rig.camera.global_position.distance_to(focus) - rig.distance()) < 1e-3, "mlbb focus offset +0.3 m")
	# apply_preset snaps and does not fight the config (View3DTests relies on this).
	rig.apply_preset("lol")
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	check(rig.preset_name == "lol" and is_equal_approx(rig.pitch(), 56.0), "apply_preset snaps and sticks while ViewConfig.preset is unchanged")
	ViewConfig.preset = "lol"
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	check(not rig.is_blending(), "switching to the preset already shown does not blend")
	# Wheel spring: eases in (slow start), never overshoots, settles on the target.
	for i in 3:
		rig.wheel(1.0)
	var d0 := rig.distance()
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	var d1 := rig.distance()
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
	var d2 := rig.distance()
	check(d1 > d0 and d2 - d1 > d1 - d0, "wheel zoom eases in (%.4f, %.4f)" % [d1 - d0, d2 - d1])
	var over := false
	for i in 240:
		rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 1.0 / 60.0)
		over = over or rig.distance() > 20.5 + 1e-4
	check(not over and absf(rig.distance() - 20.5) < 1e-3, "wheel zoom settles on 20.5 m without overshoot (%.3f)" % rig.distance())
	ViewConfig.preset = saved
	rig.queue_free()
