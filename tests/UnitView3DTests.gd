extends Node
## W1-UNITS: hero, minion and corpse cards against the FakeView host (headless).
## Standalone sim units live under a plain Node2D; views are synced by hand.

const ChampionS := preload("res://scripts/Champion.gd")
const MinionS := preload("res://scripts/Minion.gd")

var failures = 0
var checks = 0
var host: Node3D
var world: Node2D


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL UNITVIEW3D: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	ViewConfig.set_active(false)
	host = View3DTestKit.make_fake_view(self)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	await get_tree().process_frame
	_test_factory()
	_test_position_and_lift()
	_test_offsets()
	_test_override_frame()
	_test_team_cloth()
	_test_visibility_and_fade()
	_test_tint_and_whiten()
	_test_rects()
	await _test_frees_with_source()
	await _test_corpse()
	await _test_2d_material_untouched()
	ViewConfig.set_active(false)
	host.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("UNITVIEW3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _champion(team: int, key: String, pos: Vector2) -> Node2D:
	var c = ChampionS.new()
	world.add_child(c)
	c.setup(team, key, true, key.capitalize())
	c.global_position = pos
	c.facing = Vector2(1, 0)
	_freeze(c)
	return c


func _minion(team: int, sub: String, pos: Vector2) -> Node2D:
	var m = MinionS.new()
	world.add_child(m)
	m.setup(team, sub, pos)
	_freeze(m)
	return m


## Stop the animator clock so poses are deterministic (test-side only).
func _freeze(unit) -> void:
	unit.animator.set_process(false)
	unit.animator.idle_phase = 0.0
	unit.animator.moving = false
	unit.set_process(false)


func _view(unit) -> Node3D:
	var view = UnitViewFactory.create(unit)
	host.add_unit_view(view)
	view.bind(unit, host)
	view.sync(0.0)
	return view


func _param(view, name: String):
	return view.card_mat.get_shader_parameter(name)


func _test_factory() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1200, 270))
	var m = _minion(Constants.BLUE, "caster", Vector2(1250, 270))
	var vc = UnitViewFactory.create(c)
	var vm = UnitViewFactory.create(m)
	check(vc is SpriteUnitView3D and vm is SpriteUnitView3D, "factory makes sprite cards for champions and minions")
	var vcorpse = UnitViewFactory.create_corpse(null)
	check(vcorpse is CorpseView3D, "factory makes corpse views")
	vcorpse.queue_free()
	check(vc.get_node_or_null("Body") is Sprite3D and vc.get_node_or_null("ShadowCaster") is Sprite3D and vc.get_node_or_null("Extras") is UnitExtras3D, "sprite view has Body, ShadowCaster and Extras")
	vc.free()
	vm.free()
	c.queue_free()
	m.queue_free()


func _test_position_and_lift() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1310, 280))
	var view = _view(c)
	check(view.global_position.distance_to(ViewMath.to3(c.global_position)) < 1e-4, "view sits at to3(world_pos)")
	check(view.feet_world().distance_to(ViewMath.to3(c.global_position)) < 1e-4, "feet_world is the ground point")
	c.global_position = Vector2(1420, 300)
	view.sync(0.016)
	check(view.global_position.distance_to(ViewMath.to3(Vector2(1420, 300))) < 1e-4, "view follows a moved source the same frame")
	c.buffs["airborne"] = {"time": 0.5, "duration": 1.0}
	view.sync(0.016)
	var lifted: Vector3 = ViewMath.to3(c.global_position) + host.card_up() * ViewMath.art_m(30.0)
	check(view.global_position.distance_to(lifted) < 1e-4, "airborne view is lifted along U by art_m(lift)")
	check(absf(view.head_height_m() - ViewMath.art_m(-ActionSpriteArt.body_rect("hero_ahri", 56.0, false).position.y + 30.0)) < 1e-4, "head height includes lift")
	c.buffs.erase("airborne")
	view.sync(0.016)
	check(view.global_position.distance_to(ViewMath.to3(c.global_position)) < 1e-4, "view lands when airborne ends")
	var body: Sprite3D = view.body
	check(is_equal_approx(body.rotation.x, -deg_to_rad(host.pitch_deg())), "card is tilted to face the camera (rotation.x = -pitch)")
	var shadow: Sprite3D = view.shadow_caster
	check(shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "shadow caster is shadows-only")
	check(shadow.texture == body.texture and shadow.region_rect == body.region_rect and shadow.flip_h == body.flip_h, "shadow card shows the current frame")
	check(is_equal_approx(shadow.rotation.y, deg_to_rad(ViewConfig.SUN_YAW_DEG)) and is_equal_approx(shadow.rotation.x, 0.0), "shadow card stands upright, turned to the sun")
	view.free()
	c.queue_free()


func _test_offsets() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1300, 270))
	var view = _view(c)
	var body: Sprite3D = view.body
	var cell: Dictionary = ActionSpriteArt.frame("hero_ahri", "idle", 0)
	var region := ActionSpriteArt.region("hero_ahri", "idle", 0)
	check(view.pose_action == "idle" and view.pose_frame == 0, "frozen ahri shows idle 0")
	check(not body.flip_h and body.offset.distance_to(Vector2(-69.4, -3.0)) < 0.05, "unflipped ahri idle0 offset is (-69.4, -3): %s" % body.offset)
	check(body.offset.is_equal_approx(Vector2(-float(cell.pivot[0]), float(cell.pivot[1]) - region.size.y)), "unflipped offset formula")
	check(body.region_enabled and body.region_rect == region and not body.centered, "region rect is the atlas cell")
	var expected_px := ViewConfig.S * ViewConfig.UNIT_SCALE * 56.0 / float(ActionSpriteArt.entry("hero_ahri").body_height)
	check(is_equal_approx(body.pixel_size, expected_px), "pixel_size = S*UNIT_SCALE*H/body_height")
	check(absf(body.pixel_size * float(ActionSpriteArt.entry("hero_ahri").body_height) - 1.4) < 1e-4, "hero body is 1.40 m tall")
	c.facing = Vector2(-1, 0)
	view.sync(0.016)
	check(body.flip_h, "facing west flips the card")
	check(body.offset.is_equal_approx(Vector2(float(cell.pivot[0]) - region.size.x, float(cell.pivot[1]) - region.size.y)), "flipped offset formula (pivot.x - w, pivot.y - h): %s" % body.offset)
	check(body.offset.distance_to(Vector2(-57.6, -3.0)) < 0.05, "flipped ahri idle0 offset is (-57.6, -3)")
	var tex: Texture2D = view.card_mat.get_shader_parameter("tex")
	check(tex != null and tex == body.texture, "shader tex follows the body texture")
	var uv: Vector4 = view.card_mat.get_shader_parameter("region_uv")
	var ts := Vector2(tex.get_width(), tex.get_height())
	check(uv.is_equal_approx(Vector4(region.position.x / ts.x, region.position.y / ts.y, region.end.x / ts.x, region.end.y / ts.y)), "region_uv is (u0, v0, u1, v1) of the cell")
	check(view.card_mat.get_meta("action_frame_mask", "") == "hero_ahri:idle:0", "frame mask applied to the card material")
	view.free()
	c.queue_free()


func _test_override_frame() -> void:
	var c = _champion(Constants.BLUE, "yasuo", Vector2(1300, 270))
	var view = _view(c)
	var body: Sprite3D = view.body
	var idle_px := body.pixel_size
	var idle_tex := body.texture
	c.anim_action = "r"
	c.anim_elapsed = 0.0
	c.anim_duration = 1.0
	c.anim_from = 0
	c.anim_to = 5
	view.sync(0.016)
	var cell: Dictionary = ActionSpriteArt.frame("hero_yasuo", "r", 0)
	check(view.pose_action == "r", "yasuo shows the r row")
	check(absf(float(cell.get("relative_scale", 1.0)) - 0.447) < 0.001, "yasuo r frame uses relative_scale 0.447")
	check(absf(body.pixel_size / idle_px - float(cell.relative_scale)) < 1e-4, "pixel_size changes per frame with relative_scale")
	check(body.texture != idle_tex and body.texture == ActionSpriteArt.texture_for_frame("hero_yasuo", "r", 0), "override frame swaps to its own atlas")
	check(view.card_mat.get_shader_parameter("tex") == body.texture, "shader tex follows the override atlas")
	c.anim_action = "idle"
	view.sync(0.016)
	check(is_equal_approx(body.pixel_size, idle_px) and body.texture == idle_tex, "back to the base atlas after the override row")
	view.free()
	c.queue_free()


func _test_team_cloth() -> void:
	var red_minion = _minion(Constants.RED, "melee", Vector2(1350, 260))
	var blue_minion = _minion(Constants.BLUE, "melee", Vector2(1250, 260))
	var red_champ = _champion(Constants.RED, "garen", Vector2(1400, 260))
	var vr = _view(red_minion)
	var vb = _view(blue_minion)
	var vc = _view(red_champ)
	check(_param(vr, "red_team") == true, "red minion card has red_team")
	check(_param(vb, "red_team") == false, "blue minion card has no red_team")
	check(_param(vc, "red_team") == false, "red champion card is not recoloured")
	var h: float = red_minion.size * 2.7
	check(is_equal_approx(vr.height_px, h), "minion H is size*2.7")
	red_minion.facing_sign = -1
	vr.sync(0.016)
	check(vr.body.flip_h, "minion flip follows facing_sign")
	for v in [vr, vb, vc]:
		v.free()
	for u in [red_minion, blue_minion, red_champ]:
		u.queue_free()


func _test_visibility_and_fade() -> void:
	var c = _champion(Constants.RED, "lux", Vector2(1300, 270))
	var view = _view(c)
	check(view.visible and view.is_shown(), "live visible champion is shown")
	c.modulate.a = 0.72
	view.sync(0.016)
	check(absf(float(_param(view, "fade")) - 0.72) < 1e-4, "fade follows modulate.a")
	c.modulate.a = 1.0
	c.dead = true
	view.sync(0.016)
	check(not view.visible, "dead champion is hidden")
	c.dead = false
	c.visible = false
	view.sync(0.016)
	check(not view.visible, "visible=false champion is hidden")
	c.visible = true
	c.roster_active = false
	view.sync(0.016)
	check(not view.visible, "inactive roster slot is hidden")
	c.roster_active = true
	view.sync(0.016)
	check(view.visible and absf(float(_param(view, "fade")) - 1.0) < 1e-4, "shown again with full fade")
	view.free()
	c.queue_free()


func _test_tint_and_whiten() -> void:
	var c = _champion(Constants.BLUE, "garen", Vector2(1300, 270))
	var m = _minion(Constants.BLUE, "caster", Vector2(1330, 270))
	var vc = _view(c)
	var vm = _view(m)
	check(_param(vc, "tint") == Vector3.ONE and is_equal_approx(float(_param(vc, "hit_whiten")), 0.0), "no flash: neutral tint")
	c.hit_flash = 0.07
	m.flash_t = 0.3
	vc.sync(0.016)
	vm.sync(0.016)
	check(Vector3(_param(vc, "tint")).is_equal_approx(Vector3(1.3, 1.15, 1.08)), "champion hit tint")
	check(absf(float(_param(vc, "hit_whiten")) - 0.35) < 1e-4, "champion hit_whiten = clamp(hit_flash/.14)*.7")
	check(Vector3(_param(vm, "tint")).is_equal_approx(Vector3(1.10, 1.06, 1.02)), "minion flash tint")
	c.hit_flash = 0.0
	m.flash_t = 0.0
	vc.sync(0.016)
	vm.sync(0.016)
	check(_param(vc, "tint") == Vector3.ONE and _param(vm, "tint") == Vector3.ONE, "tint resets after the flash")
	vc.free()
	vm.free()
	c.queue_free()
	m.queue_free()


func _test_rects() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1300, 270))
	var view = _view(c)
	var cam: Camera3D = host.camera()
	var r: Rect2 = view.screen_rect(cam)
	var feet := cam.unproject_position(ViewMath.to3(c.global_position))
	var head := cam.unproject_position(ViewMath.to3(c.global_position) + host.card_up() * view.head_height_m())
	check(r.size.x > 0.0 and r.size.y > 0.0, "screen rect is non-empty")
	check(r.has_point(feet + Vector2(0, -2)) and r.has_point(head + Vector2(0, 2)), "screen rect covers feet to head")
	check(head.y < feet.y, "head projects above the feet")
	view.free()
	c.queue_free()


func _test_frees_with_source() -> void:
	var m = _minion(Constants.BLUE, "melee", Vector2(1300, 300))
	var view = _view(m)
	world.remove_child(m)
	world.add_child(m)
	for i in 3:
		await get_tree().process_frame
	check(is_instance_valid(view), "a plain reparent keeps the view")
	m.queue_free()
	for i in 3:
		await get_tree().process_frame
	check(not is_instance_valid(view), "unit view frees with its source")


func _test_corpse() -> void:
	var m = _minion(Constants.RED, "caster", Vector2(1300, 300))
	var corpse = AnimatedCorpse.spawn(m)
	corpse.set_process(false)
	var cv = UnitViewFactory.create_corpse(corpse)
	host.add_unit_view(cv)
	cv.bind(corpse, host)
	cv.sync(0.0)
	check(cv.visible and cv.frame == 0, "corpse view starts on death frame 0")
	check(cv.global_position.distance_to(ViewMath.to3(corpse.global_position)) < 1e-4, "corpse view at the corpse feet")
	check(cv.card_mat.get_shader_parameter("red_team") == true, "corpse keeps the red cloth from the unit material")
	check(cv.body.texture == ActionSpriteArt.texture_for_frame("minion_caster", "death", 0), "corpse uses texture_for_frame")
	corpse.elapsed = 0.5
	cv.sync(0.016)
	check(cv.frame == clampi(int(0.5 / 0.72 * 6), 0, 5), "corpse frame advances with elapsed")
	corpse.elapsed = 1.5
	corpse.modulate.a = 0.5
	cv.sync(0.016)
	check(cv.frame == 5 and absf(cv.dissolve - 0.5) < 1e-4, "dissolve ramps over 1.2..1.8 s")
	check(absf(float(cv.card_mat.get_shader_parameter("fade")) - 0.5) < 1e-4, "corpse fade follows modulate.a")
	corpse.flipped = true
	cv.sync(0.016)
	check(cv.body.flip_h, "corpse flip follows corpse.flipped")
	corpse.queue_free()
	for i in 3:
		await get_tree().process_frame
	check(not is_instance_valid(cv), "corpse view frees with the corpse")
	m.queue_free()


func _test_2d_material_untouched() -> void:
	var c = _champion(Constants.BLUE, "ahri", Vector2(1300, 270))
	var m = _minion(Constants.RED, "melee", Vector2(1340, 270))
	await get_tree().process_frame
	var stamp = c.material.get_meta("action_frame_mask", "")
	var mstamp = m.material.get_meta("action_frame_mask", "")
	ViewConfig.set_active(true)
	var vc = _view(c)
	var vm = _view(m)
	c.anim_action = "attack"
	c.anim_released = true
	c.anim_elapsed = 0.0
	c.anim_duration = 10.0
	c.hit_flash = 0.1
	c.recall_time = 0.3
	c.buffs["tempest"] = {"stacks": 2, "time": 5.0}
	c.queue_redraw()
	m.queue_redraw()
	vc.sync(0.016)
	vm.sync(0.016)
	await get_tree().process_frame
	await get_tree().process_frame
	check(c.material.get_meta("action_frame_mask", "") == stamp, "champion 2D material frame mask unchanged while 3D is active")
	check(m.material.get_meta("action_frame_mask", "") == mstamp, "minion 2D material frame mask unchanged while 3D is active")
	var pose: Dictionary = c.animator.pose()
	check(vc.card_mat.get_meta("action_frame_mask", "") == "hero_ahri:%s:%d" % [pose.action, pose.frame], "card material gets the new frame mask")
	check(pose.action == "recall", "recalling champion shows the recall row")
	c.hit_flash = 0.0
	c.recall_time = -1.0
	c.buffs.erase("tempest")
	ViewConfig.set_active(false)
	vc.free()
	vm.free()
	c.queue_free()
	m.queue_free()
	await get_tree().process_frame
