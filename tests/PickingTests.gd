extends Node
## W1-PICK: screen-space picking against a FakeView camera with standalone units (headless).
## W3-READ adds: the 6 px champion priority over minions on padded near-ties, hover outline wiring
## (Picker3D.set_hover_unit -> SpriteUnitView3D.set_hover), the shadow caster shape and, when windowed, a real
## 3D teamfight where poll() hovers the enemy under the mouse (71-3d-hover.png, red outline pixel check).

const OUT := "res://tests/"
const MATCH_SEED := 20261013
const ROSTER := {"blue": ["ashe", "garen", "lux"], "red": ["darius", "annie", "ezreal"]}

var failures = 0
var checks = 0
var host: Node3D
var world: Node2D
var picker: Picker3D


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
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	await get_tree().process_frame
	picker = Picker3D.new(host)
	_test_ground_maths()
	_test_priority()
	_test_hover()
	_test_picking()
	_test_horizon()
	GameState.reset()
	world.queue_free()
	host.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _test_hover_visual()
	print("PICKING: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _champion(team: int, key: String, pos: Vector2, label: String) -> Node2D:
	var c: Node2D = load("res://scripts/Champion.gd").new()
	world.add_child(c)
	c.setup(team, key, true, label)
	c.global_position = pos
	c.set_process(false)
	GameState.champions.append(c)
	return c


func _minion(team: int, pos: Vector2) -> Node2D:
	var m: Node2D = load("res://scripts/Minion.gd").new()
	m.setup(team, "melee", pos)
	world.add_child(m)
	m.global_position = pos
	m.set_process(false)
	GameState.minions.append(m)
	return m


func _top_px(u) -> float:
	return -Picker3D.body_rect_of(u).position.y


func _test_ground_maths() -> void:
	var cam: Camera3D = host.camera()
	for p in [Vector2(1300, 270), Vector2(1000, 150), Vector2(1650, 420)]:
		var s := picker.world_to_screen(p)
		check(s.distance_to(cam.unproject_position(ViewMath.to3(p))) < 0.01, "world_to_screen uses the host camera at %s" % [p])
		check(picker.screen_to_ground(s).distance_to(p) < 0.05, "screen_to_ground round trip at %s" % [p])
		var lifted := picker.world_to_screen(p, 40.0)
		check(lifted.y < s.y - 1.0 and absf(lifted.x - s.x) < 1.0, "lifted art px project straight up-screen at %s" % [p])


func _test_picking() -> void:
	var player := _champion(Constants.BLUE, "ahri", Vector2(1080, 300), "Player")
	GameState.player = player
	var enemy := _champion(Constants.RED, "ahri", Vector2(1300, 270), "Enemy")
	var B := Constants.BLUE
	var E := Picker3D.Pick.ENEMY
	var top := _top_px(enemy)
	check(top > 30.0, "hero body rect has a head above the feet (top %.1f)" % top)

	# Head and feet of the hero pick it.
	var head := picker.world_to_screen(enemy.world_pos(), top * 0.9)
	var feet := picker.world_to_screen(enemy.world_pos())
	check(picker.pick_unit(head, B, E) == enemy, "projected head point picks the hero")
	check(picker.pick_unit(feet, B, E) == enemy, "feet pick the hero")
	check(picker.pick_unit(head, B, Picker3D.Pick.ANY) == enemy, "ANY mode picks the enemy hero")
	check(picker.pick_unit(head, B, Picker3D.Pick.ALLY) == null, "ALLY mode ignores the enemy hero")
	var far := picker.world_to_screen(enemy.world_pos() + Vector2(260, 0))
	check(picker.pick_unit(far, B, E) == null, "empty ground picks nothing")

	# pick-then-snap: the order point is the unit's ground point, and the host's 2D lookup resolves it.
	var point := picker.pick_point(head, B, E)
	check(point.distance_to(enemy.world_pos()) < 0.001, "pick_point snaps to the hero's world_pos")
	check(GameState.find_target_at(point, B, 8) == enemy, "find_target_at resolves the snapped point to the same hero")
	var ground := picker.pick_point(far, B, E)
	check(ground.distance_to(picker.screen_to_ground(far)) < 0.001, "pick_point falls back to the ground hit")

	# Airborne: the lifted head still picks.
	enemy.buffs["airborne"] = {"time": 0.5, "duration": 1.0}
	var lift := HeroControl.lift(enemy)
	check(lift > 25.0, "airborne lift is active (%.1f)" % lift)
	var air_head := picker.world_to_screen(enemy.world_pos(), (top + lift) * 0.95)
	check(picker.pick_unit(air_head, B, E) == enemy, "airborne hero's lifted head picks it")
	enemy.buffs.erase("airborne")

	# A minion's feet beat the hero's padding.
	var cam: Camera3D = host.camera()
	var info := picker.unit_screen_info(cam, enemy)
	var rect: Rect2 = info.rect
	var pad_point := Vector2(rect.end.x + Picker3D.PAD_PX * 0.5, picker.world_to_screen(enemy.world_pos()).y)
	var minion := _minion(Constants.RED, picker.screen_to_ground(pad_point))
	var mfeet := picker.world_to_screen(minion.world_pos())
	check(not rect.has_point(mfeet) and rect.grow(Picker3D.PAD_PX).has_point(mfeet), "minion feet sit in the hero's padding only")
	check(picker.pick_unit(mfeet, B, E) == minion, "minion feet win over the hero's padding")
	check(picker.pick_unit(head, B, E) == enemy, "hero head still picks the hero next to the minion")

	# Untargetable units are excluded.
	enemy.is_targetable = false
	check(picker.pick_unit(feet, B, E) != enemy, "untargetable hero is not picked")
	enemy.is_targetable = true
	enemy.dead = true
	check(picker.pick_unit(feet, B, E) != enemy, "dead hero is not picked")
	enemy.dead = false
	check(picker.pick_unit(feet, B, E) == enemy, "hero is pickable again when restored")

	# Brush-hidden enemy is excluded; revealing it makes it pickable.
	var patch_centre: Vector2 = BrushVision.PATCHES[1].get_center()
	var lurker := _champion(Constants.RED, "garen" if ChampionData.CHAMPIONS.has("garen") else "ahri", patch_centre, "Lurker")
	check(BrushVision.patch_at(lurker.world_pos()) == 1, "lurker stands in brush patch 1")
	check(not BrushVision.visible_to(lurker, B), "lurker is hidden from blue")
	var lhead := picker.world_to_screen(lurker.world_pos(), _top_px(lurker) * 0.6)
	check(picker.pick_unit(lhead, B, E) != lurker, "brush-hidden enemy is not picked")
	check(picker.pick_unit(lhead, B, Picker3D.Pick.ANY) != lurker, "brush-hidden enemy is not picked in ANY mode")
	lurker.brush_revealed_until = GameState.time + 5.0
	check(picker.pick_unit(lhead, B, E) == lurker, "revealed brush enemy is picked")
	lurker.brush_revealed_until = -1.0

	# The player is never picked; allies are picked in ALLY and ANY, never in ENEMY.
	var pfeet := picker.world_to_screen(player.world_pos())
	var phead := picker.world_to_screen(player.world_pos(), _top_px(player) * 0.8)
	for mode in [Picker3D.Pick.ENEMY, Picker3D.Pick.ALLY, Picker3D.Pick.ANY]:
		check(picker.pick_unit(pfeet, B, mode) == null, "player feet pick nothing (mode %d)" % mode)
		check(picker.pick_unit(phead, B, mode) == null, "player head picks nothing (mode %d)" % mode)
	var ally := _minion(Constants.BLUE, Vector2(1650, 300))
	var afeet := picker.world_to_screen(ally.world_pos())
	check(picker.pick_unit(afeet, B, Picker3D.Pick.ALLY) == ally, "ALLY mode picks an allied minion")
	check(picker.pick_unit(afeet, B, Picker3D.Pick.ANY) == ally, "ANY mode picks an allied minion")
	check(picker.pick_unit(afeet, B, Picker3D.Pick.ENEMY) == null, "ENEMY mode ignores allied minions")
	ally.visible = false
	check(picker.pick_unit(afeet, B, Picker3D.Pick.ALLY) == null, "hidden (visible=false) unit is not picked")
	ally.visible = true

	# poll() is windowed only and must not touch state in headless.
	if DisplayServer.get_name() == "headless":
		GameState.hover_unit = null
		GameState.cursor_world = Vector2(-7, -7)
		picker.poll(world)
		check(GameState.hover_unit == null and GameState.cursor_world == Vector2(-7, -7), "poll is a no-op in headless")

	# Sim state untouched by picking.
	check(enemy.global_position == Vector2(1300, 270) and enemy.visible and not enemy.dead, "picking never writes sim fields")


func _drop(units: Array) -> void:
	for u in units:
		GameState.champions.erase(u)
		GameState.minions.erase(u)
		if is_instance_valid(u):
			u.free()


## The 6 px champion priority: padded near-ties go to the champion, exact hits still win.
func _test_priority() -> void:
	var B := Constants.BLUE
	var E := Picker3D.Pick.ENEMY
	var player := _champion(B, "ahri", Vector2(700, 420), "PriorityPlayer")
	GameState.player = player
	# Pure scoring rule.
	check(Picker3D.hit_score("minion", true, 10.0, 30.0) < Picker3D.hit_score("champion", false, 0.0, 0.0), "an exact minion hit beats any padded champion hit")
	check(Picker3D.hit_score("champion", false, 10.0, 40.0) < Picker3D.hit_score("minion", false, 6.0, 40.0), "padded near-tie (within 6 px) goes to the champion")
	check(Picker3D.hit_score("champion", false, 20.0, 40.0) > Picker3D.hit_score("minion", false, 6.0, 40.0), "padded minion clearly nearer (> 6 px) still wins")
	check(is_equal_approx(Picker3D.hit_score("champion", true, 12.0, 9.0), Picker3D.hit_score("minion", true, 12.0, 9.0)), "exact hits are scored by distance only")
	check(is_equal_approx(Picker3D.hit_score("structure", false, 5.0, 5.0), Picker3D.hit_score("champion", false, 5.0, 5.0)), "the bias only applies to minions")

	# Geometry: an enemy hero and a red minion whose padding bands overlap in a small gap.
	var cam: Camera3D = host.camera()
	var hero := _champion(Constants.RED, "ahri", Vector2(1580, 270), "PriorityHero")
	check(BrushVision.patch_at(hero.world_pos()) < 0 and BrushVision.visible_to(hero, B), "priority hero stands outside the brush")
	var hinfo := picker.unit_screen_info(cam, hero)
	var hrect: Rect2 = hinfo.rect
	var minion := _minion(Constants.RED, Vector2(1630, 270))
	var mrect := Rect2()
	var gap := -1.0
	for dx in range(10, 160):
		minion.global_position = hero.world_pos() + Vector2(dx, 0)
		mrect = picker.unit_screen_info(cam, minion).rect
		gap = mrect.position.x - hrect.end.x
		if gap >= 8.0:
			break
	check(gap >= 8.0 and gap < Picker3D.PAD_PX * 2.0, "minion placed with a padded gap of %.1f px next to the hero" % gap)
	var minfo := picker.unit_screen_info(cam, minion)
	var tie_found := false
	var tie_ok := true
	var clear_found := false
	var clear_ok := true
	var y := maxf(hrect.position.y, mrect.position.y)
	while y < minf(hrect.end.y, mrect.end.y):
		var x := hrect.end.x + 0.5
		while x < mrect.position.x:
			var pt := Vector2(x, y)
			if not hrect.has_point(pt) and not mrect.has_point(pt) and hrect.grow(Picker3D.PAD_PX).has_point(pt) and mrect.grow(Picker3D.PAD_PX).has_point(pt):
				var hs := minf(pt.distance_to(hinfo.feet), pt.distance_to(hinfo.centre))
				var ms := minf(pt.distance_to(minfo.feet), pt.distance_to(minfo.centre))
				var got := picker.pick_unit(pt, B, E)
				if ms < hs - 0.25 and hs < ms + Picker3D.MINION_PAD_BIAS_PX - 0.25:
					tie_found = true
					tie_ok = tie_ok and got == hero
				elif hs > ms + Picker3D.MINION_PAD_BIAS_PX + 0.25:
					clear_found = true
					clear_ok = clear_ok and got == minion
			x += 1.0
		y += 2.0
	check(tie_found and tie_ok, "padded near-tie points pick the champion (found %s)" % tie_found)
	check(clear_found and clear_ok, "padded points clearly nearer the minion pick the minion (found %s)" % clear_found)
	var mfeet := picker.world_to_screen(minion.world_pos())
	check(mrect.has_point(mfeet) and picker.pick_unit(mfeet, B, E) == minion, "the minion's exact feet hit still wins next to the hero")
	_drop([player, hero, minion])
	GameState.player = null


func _bind_view(u: Node2D) -> SpriteUnitView3D:
	var v := SpriteUnitView3D.new()
	host.add_unit_view(v)
	v.bind(u, host)
	v.sync(0.0)
	return v


func _outline(v: SpriteUnitView3D) -> Color:
	var c = v.card_mat.get_shader_parameter("outline_color")
	return c if c is Color else Color(0, 0, 0, 0)


## Hover outline wiring: the picker moves set_hover between views and clears the previous one.
func _test_hover() -> void:
	var B := Constants.BLUE
	var player := _champion(B, "ahri", Vector2(1100, 420), "HoverPlayer")
	GameState.player = player
	var enemy := _champion(Constants.RED, "ahri", Vector2(1350, 380), "HoverEnemy")
	var ally := _minion(B, Vector2(1200, 330))
	var ev := _bind_view(enemy)
	var av := _bind_view(ally)
	check(picker.view_for_unit(enemy) == ev and picker.view_for_unit(ally) == av, "view_for_unit finds the bound views on the host")
	check(_outline(ev).a == 0.0 and _outline(av).a == 0.0, "views start without an outline")

	picker.set_hover_unit(enemy, B)
	check(_outline(ev) == SpriteUnitView3D.HOVER_ENEMY and _outline(ev) == Color(1, 0.25, 0.2, 1), "hovered enemy gets the red outline")
	check(is_equal_approx(float(ev.card_mat.get_shader_parameter("outline_px")), 2.0), "outline_px is 2")
	check(picker.hovered_view() == ev and picker.hover_mode() == Picker3D.HOVER_ENEMY and ev.hover_mode == 1, "picker tracks the hovered enemy view")
	ev.sync(0.016)
	check(_outline(ev) == SpriteUnitView3D.HOVER_ENEMY, "the outline survives a view sync")

	picker.set_hover_unit(ally, B)
	check(_outline(ev).a == 0.0, "moving the hover clears the previous view's outline")
	check(_outline(av) == SpriteUnitView3D.HOVER_ALLY and _outline(av) == Color(0.3, 0.75, 1, 1), "hovered ally gets the blue outline")
	check(picker.hover_mode() == Picker3D.HOVER_ALLY, "picker reports ally hover")

	picker.set_hover_unit(null, B)
	check(_outline(av).a == 0.0 and _outline(ev).a == 0.0 and picker.hovered_view() == null, "hovering nothing clears every outline")

	# Hovering a unit without a view is safe and leaves no outline behind.
	var bare := _minion(Constants.RED, Vector2(1400, 200))
	picker.set_hover_unit(enemy, B)
	picker.set_hover_unit(bare, B)
	check(_outline(ev).a == 0.0 and picker.hovered_view() == null and picker.hover_mode() == 0, "a unit without a view clears the old outline")

	# A freed hovered view is forgotten.
	picker.set_hover_unit(enemy, B)
	ev.free()
	check(picker.hovered_view() == null and picker.hover_mode() == 0, "a freed hovered view is dropped")
	picker.set_hover_unit(null, B)

	# Shadow caster (W3-READ tuning): short, wide capsule, not a full-height pill; wider for wider bodies.
	check(av.shadow_caster is Sprite3D and av.shadow_caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "minion shadow is a silhouette card")
	check(enemy.global_position == Vector2(1350, 380) and enemy.visible and not enemy.dead, "hover never writes sim fields")
	av.free()
	_drop([player, enemy, ally, bare])
	GameState.player = null


func _test_horizon() -> void:
	var p := Picker3D.new(host)
	var valid := Vector2(1240, 330)
	var s := p.world_to_screen(valid)
	var g := p.screen_to_ground(s)
	check(g.distance_to(valid) < 0.05, "valid ground hit before the horizon test")
	var sky := Vector2(s.x, -20000.0)
	check(ViewMath.ground_hit(host.camera(), sky) == null, "the sky point misses the ground plane")
	check(p.screen_to_ground(sky).distance_to(g) < 0.001, "screen_to_ground above the horizon returns the last valid point")
	check(p.pick_point(sky, Constants.BLUE, Picker3D.Pick.ENEMY).distance_to(g) < 0.001, "pick_point above the horizon returns the last valid point")
	var none := Picker3D.new(null)
	check(none.pick_unit(s, Constants.BLUE, Picker3D.Pick.ANY) == null, "picker without a host picks nothing")


# --- windowed: real 3D teamfight, poll() hovers the enemy under the mouse ---

func _test_hover_visual() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	seed(MATCH_SEED)
	Progression.persistent = false
	GameState.reset()
	ViewConfig.enabled = true
	OS.set_environment("HOWLING_VIEW", "3d")
	var game: Node2D = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	seed(MATCH_SEED)
	game._start_game(ROSTER.blue[0], {"blue": ROSTER.blue.duplicate(), "red": ROSTER.red.duplicate(), "mode": "pve", "stolen_builds": []})
	var view = game.view3d
	check(view != null and view.is_active(), "visual: 3D view is active")
	if view == null or not view.is_active():
		return
	GameState.running = true
	var blue := []
	var red := []
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.hit_flash = 0.0
		(blue if c.team == Constants.BLUE else red).append(c)
	for i in blue.size():
		blue[i].global_position = Vector2(1290 - i * 28, 225 + i * 50)
		blue[i].facing = Vector2.RIGHT
	for i in red.size():
		red[i].global_position = Vector2(1430 + i * 34, 235 + i * 55)
		red[i].facing = Vector2.LEFT
	var kinds := ["melee", "melee", "caster", "siege"]
	for i in kinds.size():
		for team in [Constants.BLUE, Constants.RED]:
			var m = game.MinionS.new()
			game.world_root.add_child(m)
			var x := 1220.0 - i * 30.0 if team == Constants.BLUE else 1520.0 + i * 30.0
			m.setup(team, kinds[i], Vector2(x, 250 + i * 40))
			GameState.minions.append(m)
	GameState.cam_locked = false
	GameState.cam_target = Vector2(1360, 290)
	game.camera.position = Vector2(1360, 290)
	game.camera_shake_offset = Vector2.ZERO
	GameState.paused = true
	for u in GameState.champions + GameState.minions:
		if is_instance_valid(u) and u.animator != null:
			u.animator.set_process(false)
	view.sync_now()
	await _frames(3)

	var target = red[0]
	var info: Dictionary = view.picker.unit_screen_info(view.camera(), target)
	var chest: Vector2 = view.world_to_screen(target.world_pos(), 28.0)
	var scale := _screen_scale()
	# Mouse on the enemy's chest: View3D's own frame pipeline polls the picker and outlines the enemy.
	Input.warp_mouse(chest * scale)
	await _frames(6)
	var tview = view.view_for(target)
	var got = GameState.hover_unit
	check(got == target, "visual: poll hovers the enemy under the mouse (mouse %s, chest %s, got %s)" % [get_viewport().get_mouse_position(), chest, str(got)])
	check(tview != null and view.picker.hovered_view() == tview and tview.hover_mode == 1, "visual: the hovered enemy's view shows the enemy outline")
	var hovered := await _capture("71-3d-hover.png")
	# Same frame and same hover state with only the outline switched off (picker polling paused), so the
	# pixel difference is the outline alone (the 2D hover reticle on the ground stays in both captures).
	var picker_ref = view.picker
	view.picker = null
	if tview != null:
		tview.set_hover(0)
	var plain := await _capture("")
	view.picker = picker_ref
	if hovered != null and plain != null:
		var r: Rect2 = info.rect
		var img_rect := Rect2i(Vector2i((r.position * scale).floor()), Vector2i((r.size * scale).ceil())).grow(4)
		var red_on := _count_outline(hovered, img_rect)
		var red_off := _count_outline(plain, img_rect)
		print("outline pixels: %d hovered vs %d without outline in %s" % [red_on, red_off, img_rect])
		check(red_on > red_off + 60, "visual: red outline pixels around the hovered enemy (%d hovered vs %d not)" % [red_on, red_off])
	# Mouse on empty ground: the outline clears.
	Input.warp_mouse(view.world_to_screen(Vector2(1360, 160)) * scale)
	await _frames(6)
	check(tview != null and tview.hover_mode == 0 and view.picker.hovered_view() == null, "visual: the outline clears when the mouse leaves the unit")
	# Ally hover through the same pipeline gets the blue outline.
	var ally = blue[1]
	Input.warp_mouse(view.world_to_screen(ally.world_pos(), 28.0) * scale)
	await _frames(6)
	var aview = view.view_for(ally)
	check(GameState.hover_unit == ally and aview != null and aview.hover_mode == 2, "visual: hovering an ally shows the ally outline")
	await _capture("71-3d-hover-ally.png")
	GameState.paused = false
	game.queue_free()
	await _frames(2)


func _count_outline(img: Image, rect: Rect2i) -> int:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var n := 0
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			var c := img.get_pixel(xx, yy)
			if c.r > 0.8 and c.g < 0.4 and c.b < 0.4 and c.r - maxf(c.g, c.b) > 0.45:
				n += 1
	return n


func _screen_scale() -> Vector2:
	var img_size := Vector2(get_viewport().get_texture().get_size())
	var vr := get_viewport().get_visible_rect().size
	return img_size / vr


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(file: String) -> Image:
	await _frames(3)
	var img: Image = await View3DTestKit.capture(self)
	if img != null and file != "":
		img.save_png(OUT + file)
		print("saved %s %s" % [file, img.get_size()])
	check(img != null, "visual: captured %s" % (file if file != "" else "comparison frame"))
	return img
