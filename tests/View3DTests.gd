extends Node
## W1-HUB: View3D hub, camera rig and ground overlay (headless; run with "-- --view3d" or HOWLING_VIEW=3d).
## Starts a real match through View3DTestKit.start_3d_match and checks the scene contract, the registration
## funnel (incl. LAN-style replicas), screen <-> ground maths, overlay coverage, read-only mirroring,
## process priorities and the return-to-menu lifecycle.

const DECK_VISIBLE := Rect2(-60.0, 20.0, 2920.0, 500.0)  # deck + base aprons (W1-ARENA geometry)

var failures = 0
var checks = 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	var game: Node2D = View3DTestKit.start_3d_match(self, "ashe")
	var v = game.view3d
	check(v != null and v is View3D, "Main builds View3D when ViewConfig.enabled")
	if v == null:
		_finish()
		return
	await get_tree().process_frame
	game._update_camera(1.0)
	v.sync_now()
	_test_tree(game, v)
	_test_views(game, v)
	await _test_replicas(game, v)
	_test_round_trip(game, v)
	_test_overlay(game, v)
	_test_read_only(v)
	_test_priorities(v)
	_test_rig(game, v)
	await _test_return(game)
	_finish()


func _finish() -> void:
	print("VIEW3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_tree(game: Node2D, v: View3D) -> void:
	check(View3D.current == v, "View3D.current is the match view")
	check(v.name == "View3D" and v.get_parent() == game, "View3D is a direct child of Main named View3D")
	check(v.is_active() and ViewConfig.is_active(), "activate() marks the view and ViewConfig active")
	check(v.visible, "View3D is visible once active")
	check(game.world_root.get_parent() == v.overlay and v.overlay is GroundOverlay, "world_root lives in the GroundOverlay SubViewport")
	check(game.world_root.is_visible_in_tree(), "world_root stays visible inside the overlay")
	check(game.camera.is_current(), "Camera2D facade stays current in the root viewport")
	check(v.camera() != null and v.camera().is_current(), "rig Camera3D is current")
	check(v.camera().get_viewport() == get_viewport(), "Camera3D renders in the root viewport")
	check(v.overlay.ground_cam != null and v.overlay.ground_cam.name == "GroundCam" and v.overlay.ground_cam.is_current(), "GroundCam is current inside the overlay")
	check(v.overlay.transparent_bg and v.overlay.disable_3d, "overlay is transparent and 2D-only")
	check(v.overlay.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "overlay renders while live")
	check(v.overlay.size == ViewConfig.quality_settings().overlay, "overlay size follows the quality preset")
	check(not game.map_renderer.visible, "MapRenderer is hidden in 3D")
	for pair in [["CameraRig", v.rig], ["GroundOverlay", v.overlay], ["Arena", v.arena], ["OverheadLayer", v.overhead]]:
		check(pair[1] != null and pair[1].get_parent() == v and pair[1].name == pair[0], "View3D child %s exists" % pair[0])
	check(v.get_node_or_null("Units") is Node3D and v.get_node_or_null("Fx") is Node3D, "Units and Fx view roots exist")
	check(v.overhead.layer == 5 and v.overhead.visible, "OverheadLayer is layer 5 and visible once active")
	check(v.picker != null, "picker is created")
	check(get_viewport().msaa_3d == ViewConfig.quality_settings().msaa, "activate applies the quality MSAA")
	check(v.overhead_layer() == v.overhead and v.camera() == v.rig.camera, "ViewHost accessors return the hub parts")
	check(absf(v.pitch_deg() - float(ViewConfig.camera_preset().pitch)) < 1e-4, "pitch_deg follows the preset")
	check(v.card_up().is_equal_approx(v.camera().global_basis.y.normalized()), "card_up is the camera basis Y")
	check(v.local_team() == GameState.player.team, "local_team is the player's team")


func _test_views(game: Node2D, v: View3D) -> void:
	check(GameState.champions.size() > 0 and GameState.structures.size() > 0, "match has champions and structures")
	var missing := []
	for list in [GameState.champions, GameState.minions, GameState.structures]:
		for u in list:
			var view = v.view_for(u)
			if view == null or not is_instance_valid(view):
				missing.append(str(u.name))
			elif view.get_parent() != v.units_root:
				missing.append(str(u.name) + "(parent)")
	check(missing.is_empty(), "every champion, minion and structure has a unit view %s" % [missing])
	check(v.policy_of(game.skill_aimer) == VfxRegistry.Policy.FLAT and game.skill_aimer.visible, "SkillAimer stays FLAT and visible")
	check(v.policy_of(game.reticle_node) >= 0 and game.reticle_node.visible, "Reticles are registered and stay visible")
	check(v.policy_of(game.map_renderer) == VfxRegistry.Policy.HIDE, "MapRenderer is classified HIDE")
	var a := v.view_for(GameState.player)
	v.register(GameState.player)
	check(v.view_for(GameState.player) == a, "register is idempotent")
	var dbl := 0
	for child in v.units_root.get_children():
		if child is UnitView3D and child.source == GameState.player:
			dbl += 1
	check(dbl == 1, "the player has exactly one unit view")


func _test_replicas(game: Node2D, v: View3D) -> void:
	# LAN-style replicas as LanSnapshot.reconcile builds them: a set-up minion and a field-only projectile.
	var created := []
	v.view_created.connect(func(src, _view): created.append(src))
	var creep = game.MinionS.new()
	game.world_root.add_child(creep)
	creep.setup(1, "melee", Vector2(1500, 300))
	GameState.minions.append(creep)
	var proj = game.ProjectileS.new()
	proj.z_index = Constants.Z_PROJ
	game.world_root.add_child(proj)
	GameState.projectiles.append(proj)
	proj.global_position = Vector2(1400, 260)
	proj.dir = Vector2.RIGHT
	proj.shape = "arrow"
	proj.visual_height = 27.0
	check(v.view_for(creep) == null, "replica minion is pending until the next sync")
	v.sync_now()
	var creep_view = v.view_for(creep)
	check(creep_view != null, "replica minion gets a view after sync_now")
	check(created.has(creep), "view_created fires for the replica minion")
	check(v.policy_of(proj) >= 0, "replica projectile (no setup) is registered after sync_now")
	var pol: int = v.policy_of(proj)
	if pol == VfxRegistry.Policy.VIEW or pol == VfxRegistry.Policy.BOTH:
		check(v.view_for(proj) != null, "replica projectile with a VIEW/BOTH policy has a view")
	else:
		check(proj.visible, "unviewed replica projectile keeps drawing flat (never vanishes)")
	var proj_view = v.view_for(proj)
	# Reparent survives (remove_child/add_child keeps the view).
	var pre = v.view_for(creep)
	game.world_root.remove_child(creep)
	game.world_root.add_child(creep)
	await get_tree().process_frame
	await get_tree().process_frame
	check(v.view_for(creep) == pre and is_instance_valid(pre), "reparenting a source keeps its view")
	GameState.minions.erase(creep)
	GameState.projectiles.erase(proj)
	creep.queue_free()
	proj.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(creep_view), "replica minion view is freed after the source is freed")
	check(proj_view == null or not is_instance_valid(proj_view), "replica projectile view is freed after the source is freed")
	# A node added and removed before the flush never registers.
	var ghost = game.MinionS.new()
	game.world_root.add_child(ghost)
	ghost.setup(0, "caster", Vector2(1300, 300))
	game.world_root.remove_child(ghost)
	v.sync_now()
	check(v.policy_of(ghost) == -1, "a node removed before the flush is dropped from the pending list")
	ghost.free()


func _test_round_trip(_game: Node2D, v: View3D) -> void:
	var focus: Vector2 = GameState.cam_target
	var worst := 0.0
	for dy in [-90.0, 0.0, 90.0]:
		for dx in [-300.0, 0.0, 300.0]:
			var p: Vector2 = focus + Vector2(dx, dy)
			var s := v.world_to_screen(p)
			worst = maxf(worst, v.screen_to_ground(s).distance_to(p))
	check(worst < 0.5, "world_to_screen -> screen_to_ground round trip within 0.5 px (worst %.4f)" % worst)
	var vr := get_viewport().get_visible_rect()
	var worst_s := 0.0
	for fy in [0.3, 0.5, 0.8]:
		for fx in [0.2, 0.5, 0.8]:
			var s: Vector2 = vr.position + vr.size * Vector2(fx, fy)
			worst_s = maxf(worst_s, v.world_to_screen(v.screen_to_ground(s)).distance_to(s))
	check(worst_s < 0.5, "screen_to_ground -> world_to_screen round trip within 0.5 px (worst %.4f)" % worst_s)
	var lifted := v.world_to_screen(focus, 56.0)
	var feet := v.world_to_screen(focus)
	check(lifted.y < feet.y - 10.0 and absf(lifted.x - feet.x) < 1.0, "world_to_screen height lifts straight up the screen")
	var last := v.screen_to_ground(vr.get_center())
	var sky := v.screen_to_ground(Vector2(vr.get_center().x, vr.position.y - 50000.0))
	check(sky.distance_to(last) < 1e-3, "screen_to_ground above the horizon returns the last valid point")
	var far := v.screen_to_ground(Vector2(vr.position.x - 100000.0, vr.end.y))
	check(far.x >= -200.0 and far.x <= 3000.0 and far.y >= -200.0 and far.y <= 740.0, "screen_to_ground clamps to the world margin")


func _test_overlay(_game: Node2D, v: View3D) -> void:
	var r: Rect2 = v.overlay.overlay_rect()
	check(r.size.x > 0.0 and r.size.y > 0.0, "overlay rect is set")
	check(r.has_point(GameState.player.world_pos()), "overlay rect contains the player %s in %s" % [GameState.player.world_pos(), r])
	var fp: PackedVector2Array = v.footprint_sim()
	check(fp.size() == 4, "footprint_sim returns four corners")
	if fp.size() == 4:
		check(fp[0].y < fp[3].y and fp[1].y < fp[2].y, "footprint order is TL, TR, BR, BL (top rows farther north)")
		check(fp[0].x < fp[1].x and fp[3].x < fp[2].x, "footprint left corners are west of right corners")
		check((fp[1].x - fp[0].x) > (fp[2].x - fp[3].x), "footprint is a trapezoid (far edge wider)")
		var box := Rect2(fp[0], Vector2.ZERO)
		for p in fp:
			box = box.expand(p)
		var vis := box.intersection(DECK_VISIBLE)
		check(vis.size.x > 0.0 and r.grow(0.5).encloses(vis), "overlay rect %s covers the deck-visible footprint %s" % [r, vis])
	var z: float = v.overlay.ground_cam.zoom.x
	check(z <= ViewConfig.OVERLAY_TEXELS_PER_SIM_PX + 1e-4, "overlay zoom never exceeds 1.7 texels per sim px")
	check(r.size.is_equal_approx(Vector2(v.overlay.size) / z), "overlay rect matches GroundCam zoom and size")
	check(v.overlay.ground_cam.get_screen_center_position().distance_to(r.get_center()) < 0.5, "GroundCam centre equals the overlay rect centre (no lag)")
	var mat := ShaderMaterial.new()
	v.overlay.bind_material(mat)
	var o = mat.get_shader_parameter("overlay_rect")
	check(o is Vector4 and Vector2(o.x, o.y).is_equal_approx(r.position) and Vector2(o.z, o.w).is_equal_approx(r.size), "bind_material pushes overlay_rect")
	# Moving the camera moves the overlay.
	var saved_lock = GameState.cam_locked
	var saved_target: Vector2 = GameState.cam_target
	GameState.cam_locked = false
	GameState.cam_target = Vector2(1400, 270)
	_game.camera.position = GameState.cam_target
	v.sync_now()
	var r2: Rect2 = v.overlay.overlay_rect()
	check(r2.has_point(Vector2(1400, 270)) and r2.get_center().x > r.get_center().x + 500.0, "overlay follows the camera to mid lane")
	var o2 = mat.get_shader_parameter("overlay_rect")
	check(o2 is Vector4 and is_equal_approx(o2.x, r2.position.x), "bound materials receive the new overlay_rect every sync")
	GameState.cam_locked = saved_lock
	GameState.cam_target = saved_target
	_game.camera.position = saved_target
	v.sync_now()


func _test_read_only(v: View3D) -> void:
	var before := {}
	for u in GameState.champions + GameState.minions:
		before[u] = [u.anim_serial, u.global_position, u.visible, u.modulate]
	for i in 120:
		v.sync_now()
	var changed := []
	for u in before:
		if not is_instance_valid(u):
			continue
		var b: Array = before[u]
		if u.anim_serial != b[0] or u.global_position != b[1] or u.visible != b[2] or u.modulate != b[3]:
			changed.append(str(u.name))
	check(changed.is_empty(), "120 sync_now() calls leave anim_serial/position/visible/modulate untouched %s" % [changed])


func _test_priorities(v: View3D) -> void:
	check(v.process_priority == 100, "View3D process_priority is 100")
	var offenders := []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != v and n.process_priority >= 100:
			offenders.append(str(n.get_path()))
		stack.append_array(n.get_children())
	check(offenders.is_empty(), "no other node has process_priority >= 100 %s" % [offenders])


func _test_rig(game: Node2D, v: View3D) -> void:
	var rig: CameraRig3D = v.rig
	var preset := ViewConfig.camera_preset()
	check(is_equal_approx(rig.pitch(), float(preset.pitch)), "rig pitch follows the preset")
	check(absf(rig.distance() - float(preset.distance)) < 1e-3, "rig distance is the preset distance at zoom 1.7")
	var cam := rig.camera
	check(cam.keep_aspect == Camera3D.KEEP_HEIGHT and is_equal_approx(cam.fov, float(preset.fov)) and is_equal_approx(cam.near, 0.5) and is_equal_approx(cam.far, 250.0), "Camera3D fov/near/far/keep_aspect per contract")
	var focus3: Vector3 = ViewMath.to3(game.camera.position - game.camera_shake_offset) + Basis(Vector3.UP, ViewConfig.yaw_rad()) * Vector3(0, 0, float(preset.focus_z))
	check(cam.global_position.distance_to(focus3) - rig.distance() < 1e-3 and absf(cam.global_position.distance_to(focus3) - rig.distance()) < 1e-3, "camera sits at the preset distance from the focus")
	check(absf(cam.global_rotation_degrees.x + float(preset.pitch)) < 1e-3, "camera pitches down by the preset pitch")
	var centre = ViewMath.ground_hit(cam, get_viewport().get_visible_rect().get_center())
	check(centre != null and (centre as Vector3).distance_to(focus3) < 1e-2, "screen centre looks at the focus point")
	# The lane climbs the screen from the blue base to the red base, and screen directions map onto the sim.
	var here: Vector2 = game.camera.position
	var at := cam.unproject_position(ViewMath.to3(here))
	var ahead := cam.unproject_position(ViewMath.to3(here + Vector2(200, 0))) - at
	check(ahead.x > 0.0 and ahead.y < 0.0, "walking toward the red base goes up and right on screen (%s)" % ahead)
	var climb := rad_to_deg(atan2(-ahead.y, ahead.x))
	check(climb > 30.0 and climb < 50.0, "the lane runs diagonally across the screen (%.1f degrees)" % climb)
	check(ViewConfig.screen_x(Vector2.DOWN) > 0.0 and ViewConfig.screen_x(Vector2.UP) < 0.0 and ViewConfig.screen_x(Vector2.RIGHT) > 0.0, "facing follows the screen side, not sim x")
	var pan_up := cam.unproject_position(ViewMath.to3(here + ViewConfig.pan_to_sim(Vector2(0, -100)))) - at
	check(pan_up.y < 0.0 and absf(pan_up.x) < 0.2 * -pan_up.y, "panning up moves the view straight up the screen (%s)" % pan_up)
	var pan_right := cam.unproject_position(ViewMath.to3(here + ViewConfig.pan_to_sim(Vector2(100, 0)))) - at
	check(pan_right.x > 0.0 and absf(pan_right.y) < 0.2 * pan_right.x, "panning right moves the view straight right (%s)" % pan_right)
	# Wheel: eased, clamped to the preset range.
	for i in 20:
		rig.wheel(1.0)
	check(is_equal_approx(rig.zoom_target(), float(preset.zoom_max)), "wheel out clamps to zoom_max")
	rig.follow(GameState.cam_target, Vector2.ZERO, 1.7, 1.0 / 60.0)
	check(rig.distance() > float(preset.distance) and rig.distance() < float(preset.zoom_max), "zoom eases toward the wheel target")
	for i in 60:
		rig.follow(GameState.cam_target, Vector2.ZERO, 1.7, 0.1)
	check(absf(rig.distance() - float(preset.zoom_max)) < 0.01, "zoom reaches the wheel target")
	for i in 40:
		rig.wheel(-1.0)
	check(is_equal_approx(rig.zoom_target(), float(preset.zoom_min)), "wheel in clamps to zoom_min")
	rig.apply_preset(ViewConfig.preset)
	# 2D zoom maps to distance; shake maps to lens offsets.
	rig.follow(GameState.cam_target, Vector2(10, -5), 0.85, 0.0)
	check(absf(rig.distance() - float(preset.distance) * 2.0) < 1e-3, "camera.zoom 0.85 doubles the distance")
	check(is_equal_approx(cam.h_offset, 0.2) and is_equal_approx(cam.v_offset, 0.1), "shake maps to h_offset/v_offset")
	rig.apply_preset("mlbb")
	rig.follow(GameState.cam_target, Vector2.ZERO, 1.7, 0.0)
	var mp: Dictionary = ViewConfig.PRESETS.mlbb
	check(is_equal_approx(rig.pitch(), float(mp.pitch)) and is_equal_approx(cam.fov, float(mp.fov)) and absf(rig.distance() - float(mp.distance)) < 1e-3, "mlbb preset applies its pitch, fov and distance (%.0f, %.0f, %.1f m)" % [mp.pitch, mp.fov, mp.distance])
	rig.apply_preset("nonexistent")
	check(rig.preset_name == ViewConfig.DEFAULT_PRESET, "unknown preset falls back to lol")
	rig.apply_preset(ViewConfig.preset)
	v.sync_now()


func _test_return(game: Node2D) -> void:
	var old = game.view3d
	game._return_to_main_menu()
	check(not ViewConfig.is_active(), "ViewConfig is inactive after returning to the main menu")
	check(View3D.current != old, "View3D.current no longer points at the freed match view")
	await get_tree().process_frame
	check(not is_instance_valid(old), "old View3D is freed")
	var fresh = game.view3d
	check(fresh != null and fresh != old and not fresh.is_active(), "menu rebuilds an inactive View3D")
	check(fresh != null and game.world_root.get_parent() == fresh.overlay, "rebuilt view adopts the new world_root")
	game.set_process(false)
	game._start_game("ashe")
	await get_tree().process_frame
	check(fresh != null and fresh.is_active() and ViewConfig.is_active(), "a fresh _start_game activates 3D again")
	if fresh != null:
		fresh.sync_now()
		var missing := 0
		for u in GameState.champions + GameState.structures:
			if fresh.view_for(u) == null:
				missing += 1
		check(missing == 0, "second match registers every unit")
