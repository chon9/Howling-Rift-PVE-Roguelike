extends Node
## W0-A contract tests: ViewConfig, ViewMath, the FakeView host and every Rift3D stub.
## Headless by default. Run windowed to also compile every view3d shader on a visible card.

const SHADERS := [
	"unit_card", "ground_deck", "stone", "brush_card", "abyss", "fx_card_mix", "fx_card_add",
	"projectile_shape", "beam_scroll", "hook_chain", "pillar_add",
]

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
	_test_math()
	_test_config()
	var host: Node3D = View3DTestKit.make_fake_view(self)
	await get_tree().process_frame
	_test_fake_view(host)
	_test_card_basis(host)
	await _test_stubs(host)
	_test_kit_helpers()
	if DisplayServer.get_name() != "headless":
		await _test_shaders(host)
	host.queue_free()
	await get_tree().process_frame
	print("VIEW CONTRACTS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_math() -> void:
	for v in [Vector2.ZERO, Vector2(1300, 270), Vector2(-60, 470), Vector2(2860.5, 20.25)]:
		var p := ViewMath.to3(v)
		check(p.y == 0.0 and p.is_equal_approx(Vector3(v.x * 0.02, 0.0, v.y * 0.02)), "to3 maps sim px to (x*S, 0, y*S) for %s" % v)
		check(ViewMath.to2(p).distance_to(v) < 1e-3, "to2(to3(v)) round trips for %s" % v)
	check(ViewMath.to3(Vector2(10, 20), 1.5).y == 1.5, "to3 keeps the height argument")
	check(is_equal_approx(ViewMath.art_m(56.0), 1.4), "art_m(56) is 1.4 m (UNIT_SCALE 1.25)")
	check(is_equal_approx(ViewMath.art_m(56.0, 1.0), 1.12), "art_m honours an explicit scale")
	check(ViewMath.lifted(Vector2(100, 100), 0.0, Vector3.UP).is_equal_approx(ViewMath.to3(Vector2(100, 100))), "lifted with 0 art px is the feet point")
	check(ViewMath.lifted(Vector2(100, 100), 56.0, Vector3.UP).is_equal_approx(Vector3(2.0, 1.4, 2.0)), "lifted moves along the up vector")
	check(ViewConfig.S == 0.02 and ViewConfig.UNIT_SCALE == 1.25 and ViewConfig.OVERHEAD_SCALE == 1.75, "locked scale constants")
	check(ViewConfig.PROCESS_PRIORITY == 100, "View3D process priority constant is 100")


func _test_config() -> void:
	var saved_enabled := ViewConfig.enabled
	var saved_env := OS.get_environment("HOWLING_VIEW")
	var args := OS.get_cmdline_user_args()
	var flag3 := args.has("--view3d")
	var flag2 := args.has("--view2d")
	# Expected result after configure() from flags alone, given a starting value.
	var by_flags = func(start: bool) -> bool:
		var e := start
		if flag3: e = true
		if flag2: e = false
		return e
	OS.set_environment("HOWLING_VIEW", "3d")
	ViewConfig.enabled = false
	ViewConfig.configure()
	check(ViewConfig.enabled == by_flags.call(true), "HOWLING_VIEW=3d enables 3D (flags still win)")
	OS.set_environment("HOWLING_VIEW", "2D")
	ViewConfig.enabled = true
	ViewConfig.configure()
	check(ViewConfig.enabled == by_flags.call(false), "HOWLING_VIEW=2d (any case) disables 3D (flags still win)")
	OS.set_environment("HOWLING_VIEW", "")
	ViewConfig.enabled = false
	ViewConfig.configure()
	check(ViewConfig.enabled == by_flags.call(false), "no env var keeps the default unless a flag is passed")
	ViewConfig.enabled = true
	ViewConfig.configure()
	check(ViewConfig.enabled == by_flags.call(true), "no env var keeps an enabled value unless --view2d is passed")
	if saved_env == "":
		OS.unset_environment("HOWLING_VIEW")
	else:
		OS.set_environment("HOWLING_VIEW", saved_env)
	ViewConfig.enabled = saved_enabled
	check(not ViewConfig.is_active(), "ViewConfig starts inactive")
	ViewConfig.set_active(true)
	check(ViewConfig.is_active(), "set_active(true) activates")
	ViewConfig.set_active(false)
	check(not ViewConfig.is_active(), "set_active(false) deactivates")
	check(ViewConfig.camera_preset().pitch == 56.0 and ViewConfig.camera_preset().fov == 40.0, "default preset is LoL 56/40")
	var saved_preset := ViewConfig.preset
	ViewConfig.preset = "mlbb"
	check(ViewConfig.camera_preset().pitch == 50.0, "mlbb preset selectable")
	ViewConfig.preset = "nonsense"
	check(ViewConfig.camera_preset().pitch == 56.0, "unknown preset falls back to LoL")
	ViewConfig.preset = saved_preset
	var saved_quality := ViewConfig.quality
	ViewConfig.quality = "low"
	check(ViewConfig.quality_settings().overlay == Vector2i(2048, 1024) and not ViewConfig.quality_settings().shadows, "low quality settings")
	ViewConfig.quality = "bogus"
	check(ViewConfig.quality_settings().msaa == Viewport.MSAA_4X, "unknown quality falls back to high")
	ViewConfig.quality = saved_quality


func _test_fake_view(host: Node3D) -> void:
	var cam: Camera3D = host.camera()
	check(cam != null and cam.is_current(), "FakeView camera is current")
	check(is_equal_approx(host.pitch_deg(), 56.0), "FakeView pitch is 56")
	check(host.card_up().is_equal_approx(Basis(Vector3.UP, ViewConfig.yaw_rad()) * Vector3(0.0, cos(deg_to_rad(56.0)), -sin(deg_to_rad(56.0)))), "card_up is the camera basis Y")
	var vp := get_viewport().get_visible_rect().size
	var centre: Vector2 = host.world_to_screen(View3DTestKit.FOCUS_SIM)
	check(absf(centre.x - vp.x * 0.5) < 1.0, "focus is horizontally centred")
	for x in [1100.0, 1300.0, 1500.0]:
		for y in [200.0, 270.0, 340.0]:
			var p := Vector2(x, y)
			var back: Vector2 = host.screen_to_ground(host.world_to_screen(p))
			check(back.distance_to(p) < 0.5, "world_to_screen/screen_to_ground round trip at %s" % p)
	var head: Vector2 = host.world_to_screen(View3DTestKit.FOCUS_SIM, 56.0)
	check(head.y < centre.y - 20.0, "art px lift moves up the screen")
	check(host.screen_to_ground(Vector2(vp.x * 0.5, -5000.0)) == host.screen_to_ground(Vector2(vp.x * 0.5, -6000.0)), "above-horizon ray keeps the last ground point")
	check(host.local_team() == 0, "local_team defaults to 0 without a player")
	check(host.overhead_layer() == null, "FakeView overhead layer may be null")
	var t0: float = host.anim_time()
	host.step(0.5)
	check(is_equal_approx(host.anim_time() - t0, 0.5), "anim_time advances while not paused")
	GameState.paused = true
	host.step(0.5)
	check(is_equal_approx(host.anim_time() - t0, 0.5), "anim_time freezes while paused")
	GameState.paused = false


func _test_card_basis(host: Node3D) -> void:
	var cam: Camera3D = host.camera()
	var p := ViewMath.to3(View3DTestKit.FOCUS_SIM)
	var s := cam.unproject_position(p)
	var east := ViewMath.card_basis(cam, ViewMath.screen_angle(cam, p, View3DTestKit.screen_dir(Vector2.RIGHT)))
	var east_tip := (cam.unproject_position(p + east.x * 0.5) - s).normalized()
	check(east_tip.x > 0.99, "card_basis: east-moving card +X points to screen +x (%s)" % east_tip)
	var south := ViewMath.card_basis(cam, ViewMath.screen_angle(cam, p, View3DTestKit.screen_dir(Vector2.DOWN)))
	var south_tip := (cam.unproject_position(p + south.x * 0.5) - s).normalized()
	check(south_tip.y > 0.99, "card_basis: south-moving card +X points to screen +y (%s)" % south_tip)
	check(absf(ViewMath.screen_angle(cam, p, View3DTestKit.screen_dir(Vector2.RIGHT))) < 0.01, "screen_angle of screen right is 0")
	check(south.z.is_equal_approx(cam.global_basis.z), "card_basis keeps the camera-facing normal")
	var hit = ViewMath.ground_hit(cam, s)
	check(hit != null and (hit as Vector3).distance_to(p) < 1e-3, "ground_hit inverts unproject_position")


func _test_stubs(host: Node3D) -> void:
	# View3D hub (inactive stub): 2D canvas maths, ViewHost interface.
	var main := Node2D.new()
	add_child(main)
	var hub := View3D.new()
	hub.name = "View3D"
	main.add_child(hub)
	hub.setup(main)
	check(View3D.current == hub, "View3D.setup sets current")
	check(hub.process_priority == 100, "View3D priority is 100")
	check(not hub.is_active() and not ViewConfig.is_active(), "View3D stub stays inactive")
	check(hub.picker is Picker3D, "View3D stub creates a picker")
	check(hub.footprint_sim().is_empty() and hub.view_for(main) == null, "footprint/view_for defaults")
	hub.register(main)
	hub.watch(main)
	hub.activate()
	hub.sync_now()
	await hub.warm_up()
	var pt := Vector2(321, 123)
	check(hub.screen_to_ground(hub.world_to_screen(pt)).distance_to(pt) < 1e-3, "View3D stub 2D maths round trip")
	check(hub.world_to_screen(pt, 10.0) == main.get_canvas_transform() * Vector2(321, 113), "View3D stub world_to_screen lifts by art px")
	check(hub.picker.pick_point(hub.world_to_screen(pt), 0, Picker3D.Pick.ANY).distance_to(pt) < 1e-3, "Picker3D stub pick_point falls back to the ground point")
	check(hub.picker.pick_unit(Vector2.ZERO, 0, Picker3D.Pick.ENEMY) == null, "Picker3D stub picks nothing")
	hub.picker.poll(main)
	check(hub.camera() == null and hub.card_up() == Vector3.UP and hub.pitch_deg() == 56.0 and hub.anim_time() == 0.0 and hub.local_team() == 0, "View3D stub host defaults")
	check(hub.overhead_layer() == null, "View3D stub has no overhead layer")
	var fx := Node3D.new()
	hub.add_fx(fx)
	var uv := Node3D.new()
	hub.add_unit_view(uv)
	check(fx.get_parent() == hub and uv.get_parent() == hub, "View3D stub parents views")
	main.queue_free()
	await get_tree().process_frame
	check(View3D.current == null and not ViewConfig.is_active(), "View3D exit clears current and active")

	var rig := CameraRig3D.new()
	add_child(rig)
	check(rig.camera is Camera3D and rig.camera.get_parent() == rig, "CameraRig3D creates its Camera3D")
	rig.apply_preset("lol")
	rig.follow(Vector2(1300, 270), Vector2.ZERO, 1.7, 0.016)
	rig.wheel(1.0)
	check(rig.pitch() == 56.0 and rig.distance() == 17.5, "CameraRig3D preset numbers")
	rig.queue_free()

	var overlay := GroundOverlay.new()
	add_child(overlay)
	overlay.configure(Vector2i(64, 32))
	overlay.adopt(Node2D.new())
	overlay.bind_material(ShaderMaterial.new())
	overlay.sync(host.camera())
	overlay.set_live(true)
	check(overlay.overlay_rect() is Rect2 and overlay.overlay_rect().has_area(), "GroundOverlay rect covers the view after sync")
	overlay.queue_free()

	var arena := WorldBuilder3D.new()
	add_child(arena)
	arena.build(null)
	arena.apply_quality(ViewConfig.quality_settings())
	arena.update(host, 0.016)
	check(arena.wall_profile() is Array, "WorldBuilder3D wall_profile is an Array")
	check(WorldBuilder3D.stone_material() is Material and WorldBuilder3D.stone_material() == WorldBuilder3D.stone_material(), "stone_material is a cached Material")
	arena.queue_free()

	var src := Node2D.new()
	src.global_position = Vector2(500, 250)
	add_child(src)
	var view := UnitViewFactory.create(src)
	check(view is UnitView3D, "UnitViewFactory.create returns a UnitView3D")
	host.add_unit_view(view)
	view.bind(src, host)
	view.sync(0.016)
	check(view.source == src and view.host == host, "UnitView3D.bind stores refs")
	check(view.feet_world().is_equal_approx(ViewMath.to3(src.global_position)), "UnitView3D.feet_world defaults to to3(source)")
	check(view.head_height_m() == 0.0 and view.screen_rect(host.camera()) == Rect2() and view.is_shown(), "UnitView3D defaults")
	view.set_hover(1)
	view.dispose()
	for klass in [SpriteUnitView3D, StructureView3D]:
		var v = klass.new()
		check(v is UnitView3D, "%s extends UnitView3D" % v.get_script().resource_path.get_file())
		# Real binding needs a Champion/Minion/Structure source; covered by UnitView3DTests and Structure3DTests.
		v.free()
	var corpse = UnitViewFactory.create_corpse(src)
	check(corpse is CorpseView3D, "create_corpse returns a CorpseView3D")
	# CorpseView3D binding needs an AnimatedCorpse source; covered by UnitView3DTests.
	corpse.free()

	var extras := UnitExtras3D.new()
	var dummy_view := Node3D.new()
	extras.bind(dummy_view)
	extras.sync(0.0)
	check(VfxRegistry.classify(src) == VfxRegistry.Policy.FLAT, "VfxRegistry stub classifies FLAT")
	check(VfxRegistry.create_view(src, host) == null, "VfxRegistry stub creates no view")
	check(VfxRegistry.POLICY_TABLE is Dictionary, "POLICY_TABLE is a Dictionary")
	var card := FxCard3D.new()
	card.bind(src, host, "impact")
	card.sync(0.0)
	FxCard3D.flare(host, Vector2(1, 2), "blink", Color.WHITE, 10.0)
	var burst := FxBurst3D.new()
	FxBurst3D.emit(host, Vector2(1, 2), Color.WHITE, 14, 40.0)
	check(burst is GPUParticles3D, "FxBurst3D is GPUParticles3D")
	for node in [ProjectileView3D.new(), BeamView3D.new(), ZoneProp3D.new()]:
		node.bind(src, host)
		node.sync(0.0)
		node.free()
	check(not ZoneProp3D.wants(src), "ZoneProp3D stub wants nothing")
	var overhead := OverheadLayer.new()
	add_child(overhead)
	check(overhead.layer == 5, "OverheadLayer is layer 5")
	overhead.attach(src, host)
	overhead.add_float(src)
	overhead.add_label(src, "X", Color.WHITE, Vector2.ZERO)
	overhead.sync(host)
	check(overhead.anchor_for(src) == null, "OverheadLayer stub has no anchor")
	overhead.detach(src)
	overhead.queue_free()
	var anchor := OverheadAnchor.new()
	anchor.unit = src
	var sf := ScreenFloat.new()
	sf.source = src
	check(anchor.unit == src and sf.source == src, "OverheadAnchor/ScreenFloat fields")
	check(ReticleText.labels(Vector2.ZERO) is Array, "ReticleText.labels returns an Array")
	await ViewWarmup.run(host)
	for n in [extras, dummy_view, card, burst, anchor, sf]:
		n.free()
	src.queue_free()
	await get_tree().process_frame


func _test_kit_helpers() -> void:
	var a := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	a.fill(Color.BLACK)
	var b := a.duplicate()
	check(View3DTestKit.diff_ratio(a, b, Rect2i(0, 0, 8, 8)) == 0.0, "diff_ratio of equal images is 0")
	b.fill_rect(Rect2i(0, 0, 4, 8), Color.WHITE)
	check(is_equal_approx(View3DTestKit.diff_ratio(a, b, Rect2i(0, 0, 8, 8)), 0.5), "diff_ratio counts differing pixels")
	check(View3DTestKit.diff_ratio(a, null, Rect2i(0, 0, 8, 8)) == 1.0, "diff_ratio of a missing image is 1")


func _test_shaders(host: Node3D) -> void:
	# Windowed only: every stub shader must compile in the active renderer (SHADER ERROR fails the run).
	var tex := ImageTexture.create_from_image(Image.create(4, 4, true, Image.FORMAT_RGBA8))
	var meshes: Array = []
	var i := 0
	for n in SHADERS:
		var shader: Shader = load("res://assets/shaders/view3d/%s.gdshader" % n)
		check(shader != null and shader.code.contains("view3d_common.gdshaderinc"), "%s loads and includes the common file" % n)
		if shader == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		for param in ["tex", "albedo_tex", "overlay_tex"]:
			mat.set_shader_parameter(param, tex)
		var mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		mesh.mesh = quad
		mesh.material_override = mat
		mesh.position = ViewMath.to3(View3DTestKit.FOCUS_SIM + Vector2(-220 + 45 * i, 0), 0.5)
		host.add_fx(mesh)
		meshes.append(mesh)
		i += 1
	for _f in range(3):
		await RenderingServer.frame_post_draw
	for m in meshes:
		m.queue_free()
