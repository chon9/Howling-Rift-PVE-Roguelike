extends Node
## W2-PROJ: ProjectileView3D and BeamView3D (headless). Runs inside a real 3D match (View3DTestKit) so the
## projectiles, replicas, hook casts and beams are the game's own, but binds the views under test to a FakeView
## host with a manual clock so every number is deterministic.

var failures = 0
var checks = 0
var game: Node2D
var host: Node3D
var hero


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	game = View3DTestKit.start_3d_match(self, "thresh")
	check(game.view3d != null and game.view3d.is_active() and ViewConfig.is_active(), "3D match is active")
	host = View3DTestKit.make_fake_view(self)
	host.set_process(false)
	await get_tree().process_frame
	hero = GameState.player
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.global_position = Constants.FOUNT_B if c.team == 0 else Constants.FOUNT_R
	hero.global_position = Vector2(1300, 270)
	_test_quad_uv()
	_test_axis()
	_test_lift()
	_test_turret()
	_test_replica()
	_test_kinds()
	_test_clock()
	_test_chain()
	_test_no_puff()
	await _test_beam()
	await _test_free()
	_finish()


func _finish() -> void:
	print("PROJECTILE VIEW3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- helpers ---

func _spawn(src, pos: Vector2, dir: Vector2, opts: Dictionary = {}) -> Node2D:
	var o := {"size": 8, "speed": 400, "life": 5.0, "dmg": 0.0}
	o.merge(opts, true)
	game.spawn_projectile(src, pos, dir, o)
	return GameState.projectiles.back()


func _view(p: Node2D) -> ProjectileView3D:
	var v := ProjectileView3D.new()
	host.add_fx(v)
	v.bind(p, host)
	v.sync(0.0)
	return v


func _cam() -> Camera3D:
	return host.camera()


func _screen_dir(at: Vector3, axis: Vector3) -> Vector2:
	var cam := _cam()
	return cam.unproject_position(at + axis.normalized() * 0.2) - cam.unproject_position(at)


func _lifted(p: Vector2, art_px: float) -> Vector3:
	return ViewMath.to3(p) + host.card_up() * ViewMath.art_m(art_px)


func _remove(p) -> void:
	if is_instance_valid(p):
		GameState.projectiles.erase(p)
		p.queue_free()


func _replica(packet: Dictionary) -> Node2D:
	var r: Node2D = game.ProjectileS.new()
	game.world_root.add_child(r)
	for field in packet:
		if field not in ["id", "position", "source"]:
			r.set(field, packet[field])
	r.global_position = packet.get("position", Vector2(1300, 270))
	return r


# --- tests ---

func _test_quad_uv() -> void:
	# Layers rely on QuadMesh UV (0,0) sitting at the -X/+Y corner (2D top-left of the card).
	var arrays := QuadMesh.new().get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ok := false
	for i in uvs.size():
		if uvs[i].is_zero_approx():
			ok = verts[i].x < 0.0 and verts[i].y > 0.0
	check(ok, "QuadMesh UV (0,0) is the -X/+Y corner")


func _test_axis() -> void:
	var east := _spawn(hero, Vector2(1300, 270), View3DTestKit.screen_dir(Vector2.RIGHT), {"effect_id": "thresh_q", "damage_type": "skill"})
	var v := _view(east)
	var d := _screen_dir(v.card.global_position, v.card.global_basis.x)
	check(d.x > 0.0 and absf(d.y) < 0.15 * d.x, "east projectile: card +X points to screen right (%s)" % d)
	var up := _screen_dir(v.card.global_position, v.card.global_basis.y)
	check(up.y < 0.0 and absf(up.x) < 0.15 * -up.y, "east projectile: card +Y points screen up (%s)" % up)
	var south := _spawn(hero, Vector2(1300, 270), View3DTestKit.screen_dir(Vector2.DOWN), {"effect_id": "thresh_q", "damage_type": "skill"})
	var vs := _view(south)
	var ds := _screen_dir(vs.card.global_position, vs.card.global_basis.x)
	check(ds.y > 0.0 and absf(ds.x) < 0.15 * ds.y, "south projectile: card +X points to screen down (%s)" % ds)
	var north := _spawn(hero, Vector2(1300, 270), View3DTestKit.screen_dir(Vector2.UP), {"effect_id": "thresh_q", "damage_type": "skill"})
	var vn := _view(north)
	var dn := _screen_dir(vn.card.global_position, vn.card.global_basis.x)
	check(dn.y < 0.0 and absf(dn.x) < 0.15 * -dn.y, "north projectile: card +X points to screen up (%s)" % dn)
	var worst := 0.0
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		east.rotation = dir.angle()
		v.sync(0.0)
		var want := ViewMath.screen_angle(_cam(), v.global_position, dir)
		var got := _screen_dir(v.card.global_position, v.card.global_basis.x).angle()
		worst = maxf(worst, absf(angle_difference(want, got)))
	check(worst < 0.02, "card +X follows screen_angle(travel) in 8 directions (worst %.4f rad)" % worst)
	check(v.card.global_basis.z.dot(_cam().global_basis.z) > 0.999, "card faces the camera")
	for p in [east, south, north]:
		_remove(p)


func _test_lift() -> void:
	var p := _spawn(hero, Vector2(1340, 250), Vector2.RIGHT, {"damage_type": "auto"})
	var v := _view(p)
	check(is_equal_approx(p.visual_height, 52.0 * Constants.CHAMP_ART_SCALE), "hero missile visual_height is the chest (27 art px)")
	var want := _lifted(p.global_position, p.visual_height)
	check(v.global_position.distance_to(want) < 0.001, "view position = to3(p) + U * art_m(visual_height) (%s vs %s)" % [v.global_position, want])
	check(v.card.global_position.distance_to(want) < 0.001, "missile card is centred on the lifted point")
	var w := ViewMath.art_m(p.visual_dimensions.x, ViewConfig.FX_SCALE)
	check(absf(v.card.global_basis.x.length() - w) < 0.001, "card width = visual_dimensions.x * FX_SCALE")
	check(v.mode == "missile" and not v.underlay.visible, "auto attack uses its missile cell with no trail band")
	p.global_position += Vector2(80, 40)
	v.sync(0.0)
	check(v.global_position.distance_to(_lifted(p.global_position, p.visual_height)) < 0.001, "view follows the live position")
	_remove(p)


func _test_turret() -> void:
	var tower = null
	for s in GameState.structures:
		if s.atk_dmg > 0 and not s.dead:
			tower = s
			break
	check(tower != null, "match has a turret")
	if tower == null:
		return
	var p := _spawn(tower, tower.world_pos(), Vector2.RIGHT, {"is_turret": true, "shape": "bolt"})
	var v := _view(p)
	check(is_equal_approx(v.lift_px, 110.0), "turret bolt leaves the muzzle at 110 art px (%.1f)" % v.lift_px)
	p.global_position = tower.world_pos() + Vector2(160, 0)
	v.sync(0.0)
	check(is_equal_approx(v.lift_px, lerpf(110.0, 27.0, 0.5)), "turret bolt descends with distance (%.1f)" % v.lift_px)
	p.global_position = tower.world_pos() + Vector2(400, 0)
	v.sync(0.0)
	check(is_equal_approx(v.lift_px, 27.0), "turret bolt reaches chest height after 320 px (%.1f)" % v.lift_px)
	check(v.global_position.distance_to(_lifted(p.global_position, 27.0)) < 0.001, "turret bolt view sits at the lifted point")
	# LAN replica: is_turret is not replicated, a "bolt" from a structure still counts.
	p.is_turret = false
	p.global_position = tower.world_pos()
	v.sync(0.0)
	check(is_equal_approx(v.lift_px, 110.0), "replicated structure bolt (is_turret false) keeps the muzzle height")
	check(v.mode == "shape" and int(v.card_mat.get_shader_parameter("shape")) == ProjectileView3D.SHAPES.bolt, "turret bolt uses the bolt SDF")
	_remove(p)


func _test_replica() -> void:
	var hook := _spawn(hero, Vector2(1300, 270), Vector2.RIGHT, {})
	_remove(hook)
	check(ExpansionKits.cast(hero, "thresh_q", Vector2(1700, 270)), "thresh_q casts a hook")
	hook = GameState.projectiles.back()
	var packet: Dictionary = LanSnapshot.encode().projectiles.back()
	var r := _replica(packet)
	check(r.src == null and r.effect_id == "thresh_q", "field-set replica has no source and keeps its effect id")
	var v := _view(r)
	var tex = v.card_mat.get_shader_parameter("tex")
	var region: Vector4 = v.card_mat.get_shader_parameter("region_uv")
	check(v.visible and v.card.visible, "replica view is shown")
	check(v.mode == "kit" and tex is Texture2D and tex == KitEffectArt.sheet("thresh_q"), "replica (no setup) gets the textured kit card")
	check(int(v.card_mat.get_shader_parameter("shape")) == ProjectileView3D.SHAPE_TEXTURE and region.z > region.x and region.w > region.y, "replica card samples a real atlas region")
	check(not v.chain.visible, "replica without a resolved source draws no chain")
	r.queue_free()
	# Base-hero missile replica built from raw fields only.
	var r2 := _replica({"position": Vector2(1360, 300), "rotation": 0.0, "dir": Vector2.RIGHT, "size": 8, "color": Color.ORANGE,
		"shape": "orb", "art_row": 2, "expansion_art": false, "is_ult": false, "damage_type": "skill", "animation_time": 0.1,
		"hook_chain": false, "effect_id": "", "wind_kind": -1, "visual_height": 27.04, "visual_dimensions": Vector2(30, 17), "visual_scale": 0.52})
	var v2 := _view(r2)
	check(v2.mode == "missile" and v2.card_mat.get_shader_parameter("tex") == SpellArt.missiles, "legacy missile replica uses projectiles.png")
	check(v2.underlay.visible, "skill missile replica gets the glow band underlay")
	r2.queue_free()
	_remove(hook)


func _test_kinds() -> void:
	var tower = GameState.structures[0]
	var fire := _spawn(tower, Vector2(1300, 300), Vector2.RIGHT, {"shape": "fireball", "size": 10})
	var v := _view(fire)
	check(v.mode == "shape" and int(v.card_mat.get_shader_parameter("shape")) == ProjectileView3D.SHAPES.fireball, "fireball uses the SDF shape")
	check(absf(v.card.global_basis.x.length() - ViewMath.art_m(10 * 4.4, ViewConfig.FX_SCALE)) < 0.001, "shape card is a size * 4.4 square at FX_SCALE")
	_remove(fire)
	var thrust := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"wind_kind": 0, "damage_type": "skill"})
	var vt := _view(thrust)
	check(vt.mode == "wind" and vt.card_mat.get_shader_parameter("tex") == WindArt.texture, "wind thrust uses WindArt row 0")
	_remove(thrust)
	var tornado := _spawn(hero, Vector2(1300, 300), Vector2.DOWN, {"wind_kind": 1, "damage_type": "skill"})
	var vo := _view(tornado)
	var bottom: Vector3 = vo.card.global_position - vo.card.global_basis.y * 0.5
	check(vo.mode == "tornado" and is_zero_approx(vo.lift_px), "tornado is not lifted")
	check(bottom.distance_to(ViewMath.to3(tornado.global_position)) < 0.001, "tornado is bottom-anchored at the ground point")
	check(vo.card.global_basis.x.normalized().dot(_cam().global_basis.x) > 0.999, "tornado stays upright whatever its travel")
	_remove(tornado)
	var bolt := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"effect_id": "vayne_e", "damage_type": "physical", "size": 7})
	var vb := _view(bolt)
	check(vb.mode == "vesper" and vb.underlay.visible and vb.core.visible, "Vesper bolt has rim, kit card and core line")
	check(vb.card_mat.get_shader_parameter("tex") == KitEffectArt.sheet("vayne_e"), "Condemn bolt uses the vayne_e sheet")
	_remove(bolt)
	var skill := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"effect_id": "thresh_q", "damage_type": "skill"})
	var vs := _view(skill)
	check(skill.readable_trail() and vs.underlay.visible, "readable skill shot gets the dark-plus-tint band")
	check(vs.underlay.sorting_offset < vs.card.sorting_offset and vs.card.sorting_offset < vs.core.sorting_offset, "band sorts behind the card, core in front")
	_remove(skill)
	_test_readability()


## Final polish: axial missiles keep a minimum on-screen size and get an additive glowing head; SDF shapes and
## tornadoes do not.
func _test_readability() -> void:
	var auto := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"damage_type": "auto"})
	var va := _view(auto)
	var ppa := ProjectileView3D.screen_px_per_art(_cam(), va.global_position)
	check(ppa > 0.0 and is_equal_approx(va.px_per_art, ppa), "px_per_art is measured at the missile (%.3f)" % ppa)
	var dims: Vector2 = auto.visual_dimensions
	var h_art: float = va.card.global_basis.y.length() / (ViewConfig.S * ViewConfig.FX_SCALE)
	var want_h := maxf(dims.y, minf(ProjectileView3D.CARD_MIN_PX / ppa, dims.y * ProjectileView3D.CARD_STRETCH_MAX))
	check(absf(h_art - want_h) < 0.01, "axial card height = max(authored, min(CARD_MIN_PX on screen, x%.1f)) (%.2f vs %.2f art px)" % [ProjectileView3D.CARD_STRETCH_MAX, h_art, want_h])
	check(absf(va.card.global_basis.x.length() - ViewMath.art_m(dims.x, ViewConfig.FX_SCALE)) < 0.001, "axial card keeps its authored length")
	check(va.glow.visible and va.glow.material_override.shader.code.contains("blend_add"), "auto attack gets an additive glow head")
	var st: Vector4 = va.glow_mat.get_shader_parameter("streak")
	check(st.w * ppa >= ProjectileView3D.HEAD_MIN_PX[1] - 0.01 and st.z * 2.0 * ppa >= ProjectileView3D.GLOW_MIN_PX[1] - 0.01, "auto glow head >= %.1f px radius and band >= %.0f px on screen" % [ProjectileView3D.HEAD_MIN_PX[1], ProjectileView3D.GLOW_MIN_PX[1]])
	check(va.glow.sorting_offset > va.underlay.sorting_offset and va.glow.sorting_offset < va.card.sorting_offset, "glow sorts between the band and the card")
	_remove(auto)
	var skill := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"effect_id": "thresh_q", "damage_type": "skill"})
	var vs := _view(skill)
	var ss: Vector4 = vs.glow_mat.get_shader_parameter("streak")
	check(vs.glow.visible and ss.w * vs.px_per_art >= ProjectileView3D.HEAD_MIN_PX[0] - 0.01 and ss.x < 0.0 and ss.y > ss.x, "skill missile: glow streak from the tail to a head >= %.1f px" % ProjectileView3D.HEAD_MIN_PX[0])
	_remove(skill)
	var bolt := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"effect_id": "vayne_auto", "damage_type": "auto", "size": 7})
	var vb := _view(bolt)
	var lines: PackedVector4Array = vb.core_mat.get_shader_parameter("lines")
	var lw := clampf(ProjectileView3D.VESPER_CORE_MIN_PX / vb.px_per_art / 1.8, 1.0, 2.5)
	check(vb.mode == "vesper" and vb.glow.visible and absf(lines[0].z - 1.8 * lw) < 0.01, "Vesper core line widens toward VESPER_CORE_MIN_PX (%.2f art px)" % lines[0].z)
	_remove(bolt)
	var thrust := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"wind_kind": 0, "damage_type": "skill"})
	var vt := _view(thrust)
	check(vt.glow.visible, "wind thrust gets a glow head")
	_remove(thrust)
	var tower = GameState.structures[0]
	var fire := _spawn(tower, Vector2(1300, 300), Vector2.RIGHT, {"shape": "fireball", "size": 10})
	var vf := _view(fire)
	check(not vf.glow.visible, "SDF shapes keep their own halo (no glow streak)")
	_remove(fire)
	var tornado := _spawn(hero, Vector2(1300, 300), Vector2.DOWN, {"wind_kind": 1, "damage_type": "skill"})
	var vo := _view(tornado)
	check(not vo.glow.visible, "tornado has no glow streak")
	_remove(tornado)


func _test_clock() -> void:
	var r := _replica({"position": Vector2(1300, 270), "rotation": 0.0, "size": 8, "color": Color.WHITE, "shape": "orb",
		"art_row": 2, "expansion_art": false, "damage_type": "skill", "animation_time": 0.2, "effect_id": "", "wind_kind": -1,
		"visual_height": 27.04, "visual_dimensions": Vector2(30, 17), "visual_scale": 0.52})
	var v := _view(r)
	check(is_equal_approx(v.local_t, 0.2), "clock starts at the replicated animation_time")
	host.step(0.1)
	v.sync(0.0)
	check(is_equal_approx(v.local_t, 0.3), "clock advances locally between snapshots (%.3f)" % v.local_t)
	GameState.paused = true
	host.step(0.1)
	v.sync(0.0)
	check(is_equal_approx(v.local_t, 0.3), "clock freezes while paused")
	GameState.paused = false
	r.animation_time = 0.6
	v.sync(0.0)
	check(is_equal_approx(v.local_t, 0.6), "clock catches up with a newer snapshot")
	r.queue_free()


func _test_chain() -> void:
	hero.global_position = Vector2(1400, 150)
	check(BrushVision.patch_at(hero.world_pos()) >= 0, "caster stands in a brush patch")
	check(ExpansionKits.cast(hero, "thresh_q", Vector2(1800, 150)), "hook cast from the brush")
	var hook = GameState.projectiles.back()
	check(hook.hook_chain, "hook projectile carries hook_chain")
	hook.global_position = Vector2(1560, 150)
	hero.brush_revealed_until = -1.0
	var v := _view(hook)
	host.team = hero.team
	v.sync(0.0)
	check(v.chain.visible, "own-team view shows the hook chain")
	var start: Vector3 = v.chain.global_position - v.chain.global_basis.x * 0.5
	var finish: Vector3 = v.chain.global_position + v.chain.global_basis.x * 0.5
	check(start.distance_to(_lifted(hero.world_pos(), hook.visual_height)) < 0.001, "chain starts at the caster's chest")
	check(finish.distance_to(v.global_position) < 0.001, "chain ends at the hook card")
	check(absf(v.chain.global_basis.y.length() - ProjectileView3D.CHAIN_WIDTH_M) < 0.0001, "chain ribbon is 0.06 m wide")
	var enemy_team: int = 1 - hero.team
	check(not BrushVision.visible_to(hero, enemy_team), "caster is brush-hidden from the enemy team")
	host.team = enemy_team
	v.sync(0.0)
	check(not v.chain.visible, "hook chain is hidden when the caster is brush-hidden")
	check(v.card.visible, "the hook itself stays visible")
	hero.brush_revealed_until = GameState.time + 5.0
	v.sync(0.0)
	check(v.chain.visible, "revealed caster shows the chain again")
	hero.brush_revealed_until = -1.0
	host.team = -1
	_remove(hook)
	hero.global_position = Vector2(1300, 270)


func _count_puffs() -> int:
	var n := 0
	for child in game.world_root.get_children():
		if child.get("fx_kind") == "puff" and not child.is_queued_for_deletion():
			n += 1
	return n


func _test_no_puff() -> void:
	var p := _spawn(hero, Vector2(1200, 470), Vector2.RIGHT, {"trail": true, "effect_id": "thresh_q", "damage_type": "skill", "speed": 100})
	var v := _view(p)
	var before := _count_puffs()
	for i in 10:
		p.update_frame(0.02)
		v.sync(0.02)
	check(_count_puffs() == before, "projectiles spawn no _PuffFx trail in 3D")
	check(v.trail != null and v.trail.emitting and not v.trail.local_coords, "view emits its own world-space trail particles")
	check(v.trail != null and v.trail.amount == 48 and is_equal_approx(v.trail.lifetime, 0.35), "trail is 48 particles / 0.35 s")
	ViewConfig.set_active(false)
	for i in 10:
		p.update_frame(0.02)
	var control := _count_puffs()
	ViewConfig.set_active(true)
	check(control > before, "control: the same projectile spawns puffs in 2D (%d)" % (control - before))
	_remove(p)
	var plain := _spawn(hero, Vector2(1200, 470), Vector2.RIGHT, {"damage_type": "auto"})
	var vp := _view(plain)
	check(vp.trail == null, "untrailed projectiles create no particle system")
	_remove(plain)


func _test_beam() -> void:
	hero.global_position = Constants.FOUNT_B + Vector2(80, 0)
	var beam: Node2D = load("res://scripts/Beam.gd").new()
	game.world_root.add_child(beam)
	beam.setup(hero, Vector2.RIGHT, 300.0, 20.0, 0.0, Color(1.0, 0.6, 0.2))
	var bv := BeamView3D.new()
	host.add_fx(bv)
	bv.bind(beam, host)
	bv.sync(0.0)
	check(bv.visible and bv.ribbon.visible, "beam ribbon is shown")
	check(bv.global_position.distance_to(_lifted(beam.global_position, BeamView3D.LIFT_PX)) < 0.001, "beam starts at the caster lifted to chest height (%.0f art px)" % BeamView3D.LIFT_PX)
	var axis: Vector3 = bv.ribbon.global_basis.x
	check(absf(axis.length() - 300.0 * ViewConfig.S) < 0.001 and axis.normalized().dot(Vector3.RIGHT) > 0.999, "ribbon runs length * S along the beam direction")
	check(absf(bv.ribbon.global_basis.y.length() - BeamView3D.RIBBON_WIDTH_K * 20.0 * ViewConfig.S) < 0.001, "ribbon is a narrow laser (RIBBON_WIDTH_K * width * S wide)")
	var start: Vector3 = bv.ribbon.global_position - axis * 0.5
	check(start.distance_to(bv.global_position) < 0.001, "ribbon begins at the caster point")
	# The hit band lies flat on the deck as a faint rim (the 2D strip is hidden: Beam is a VIEW source).
	var gb: Basis = bv.ground.global_basis
	var g_start: Vector3 = bv.ground.global_position - gb.x * 0.5
	check(bv.ground.visible and absf(gb.x.length() - 300.0 * ViewConfig.S) < 0.001 and absf(gb.y.length() - 40.0 * ViewConfig.S) < 0.001, "ground rim covers the hit band (length * S by 2 * width * S)")
	check(gb.z.normalized().dot(Vector3.UP) > 0.999 and Vector2(g_start.x, g_start.z).distance_to(Vector2(beam.global_position.x, beam.global_position.y) * ViewConfig.S) < 0.001 and absf(g_start.y - BeamView3D.GROUND_Y_M) < 0.001, "ground rim lies flat on the deck from the caster")
	check(VfxRegistry.classify(beam) == VfxRegistry.Policy.VIEW, "Beam is a VIEW source in 3D (no opaque 2D strip)")
	beam.life = 0.2
	bv.sync(0.0)
	var tint: Color = bv.ribbon_mat.get_shader_parameter("tint")
	check(is_equal_approx(tint.a, 0.5), "alpha = life / 0.4 (%.3f)" % tint.a)
	var s0 := bv.scroll
	host.step(0.25)
	bv.sync(0.0)
	check(is_equal_approx(bv.scroll - s0, 1.0), "beam scrolls 4 tiles per second (%.3f)" % (bv.scroll - s0))
	beam.rotation = PI / 2.0
	bv.sync(0.0)
	check(bv.ribbon.global_basis.x.normalized().dot(Vector3.BACK) > 0.999, "south beam runs along +Z")
	beam.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(bv), "beam view frees with its source")


func _test_free() -> void:
	var p := _spawn(hero, Vector2(1300, 300), Vector2.RIGHT, {"effect_id": "thresh_q", "damage_type": "skill"})
	var v := _view(p)
	var parent := p.get_parent()
	parent.remove_child(p)
	parent.add_child(p)
	await get_tree().process_frame
	check(is_instance_valid(v), "a reparented projectile keeps its view")
	var hub = View3D.current
	if hub != null and hub.view_for(p) != null:
		check(hub.view_for(p) is ProjectileView3D, "the hub's registry view for a projectile is a ProjectileView3D")
	p._destroy()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(v), "view frees after its projectile is destroyed")
	# A view bound before it enters the tree (registry style) still lands on the lifted point.
	var q := _spawn(hero, Vector2(1320, 300), Vector2.RIGHT, {"damage_type": "auto"})
	var early := ProjectileView3D.new()
	early.bind(q, host)
	early.sync(0.0)
	host.add_fx(early)
	early.sync(0.0)
	check(early.global_position.distance_to(_lifted(q.global_position, q.visual_height)) < 0.001, "view bound outside the tree syncs to the lifted point")
	_remove(q)
	# Sources without projectile / beam fields are tolerated (hidden, no script error).
	var plain := Node2D.new()
	add_child(plain)
	var pv := ProjectileView3D.new()
	var bv := BeamView3D.new()
	host.add_fx(pv)
	host.add_fx(bv)
	pv.bind(plain, host)
	bv.bind(plain, host)
	pv.sync(0.0)
	bv.sync(0.0)
	check(not pv.visible and not bv.visible, "views bound to a plain Node2D stay hidden")
	plain.queue_free()
