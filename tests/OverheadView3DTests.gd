extends Node
## W1-OVERHEAD: screen-space bars, StatusVisual modes, floating text, captions and Deadeye lines.
## Headless, FakeView host with standalone units (no Main, so it does not depend on other W1 packages).

const STATUS := preload("res://scripts/StatusVisual.gd")
const FOCUS := View3DTestKit.FOCUS_SIM

var failures = 0
var checks = 0
var host: Node3D
var layer: OverheadLayer
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
	var was_active := ViewConfig.is_active()
	host = View3DTestKit.make_fake_view(self)
	layer = OverheadLayer.new()
	add_child(layer)
	host.overhead = layer
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ViewConfig.set_active(true)
	var p = _champion(Constants.BLUE, "ahri", false, FOCUS)
	var enemy = _champion(Constants.RED, "ashe", true, FOCUS + Vector2(160, 30))
	var minion = _minion(Constants.RED, "melee", FOCUS + Vector2(70, 10))
	GameState.player = p
	GameState.champions = [p, enemy]
	GameState.minions = [minion]
	await get_tree().process_frame
	_test_attach(p, enemy, minion)
	_test_follow_and_visibility(p, minion)
	_test_constant_size(p)
	await _test_status_declutter(p, enemy, minion)
	await _test_floats()
	_test_captions(p, minion)
	_test_deadeye(p, enemy)
	await _test_labels(minion)
	await _test_lifecycle(p, enemy, minion)
	ViewConfig.set_active(false)
	var sv = p.get_node("StatusVisual")
	check(sv.effective_mode() == STATUS.MODE_ALL, "classic 2D keeps the unit StatusVisual in ALL mode")
	ViewConfig.set_active(was_active)
	GameState.attack_move_pending = false
	GameState.running = false
	layer.queue_free()
	world.queue_free()
	host.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("OVERHEAD3D: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _champion(team: int, key: String, bot: bool, at: Vector2) -> Node2D:
	var c = load("res://scripts/Champion.gd").new()
	world.add_child(c)
	c.setup(team, key, bot, key.capitalize())
	c.animator.set_process(false)
	c.global_position = at
	return c


func _minion(team: int, kind: String, at: Vector2) -> Node2D:
	var m = load("res://scripts/Minion.gd").new()
	world.add_child(m)
	m.setup(team, kind, at)
	m.set_process(false)
	m.animator.set_process(false)
	return m


func _test_attach(p, enemy, minion) -> void:
	layer.attach(p, null)
	layer.attach(enemy, null)
	layer.attach(minion, null)
	var bar = layer.anchor_for(p)
	check(bar is OverheadAnchor, "champion gets a BarAnchor")
	check(p.hp_bar.get_parent() is OverheadAnchor, "hp_bar is reparented into an OverheadAnchor")
	for member in ["name_label", "shield_bar_bg", "shield_bar", "hp_bar_bg", "hp_bar", "mp_bar"]:
		check(p.get(member).get_parent() == bar, "champion %s moved to the BarAnchor" % member)
	check(minion.hp_bar.get_parent() is OverheadAnchor and minion.hp_bar_bg.get_parent() == minion.hp_bar.get_parent(), "minion bars are reparented")
	check(p.get_node_or_null("StatusVisual") != null, "the unit's own StatusVisual stays under the unit")
	check(p.get_node("StatusVisual").effective_mode() == STATUS.MODE_GROUND, "unit StatusVisual is GROUND while 3D is active")
	check(p.shield_bar.position.y + p.shield_bar.size.y < p.hp_bar.position.y, "shield bar sits above the hp bar (local layout kept)")
	check(is_equal_approx(p.hp_bar.position.y, -Constants.CHAMP_ART_HEIGHT - 12.0), "hp_bar keeps its local 2D position")
	var overhead_status = bar.get_node_or_null("OverheadStatus")
	var body_status = layer.body_anchor_for(p).get_node_or_null("BodyStatus")
	check(overhead_status != null and overhead_status.mode == STATUS.MODE_OVERHEAD and overhead_status.unit == p, "BarAnchor carries an OVERHEAD StatusVisual")
	check(body_status != null and body_status.mode == STATUS.MODE_BODY and body_status.effective_mode() == STATUS.MODE_BODY, "BodyAnchor carries a BODY StatusVisual")
	var children: int = bar.get_child_count()
	layer.attach(p, null)
	check(bar.get_child_count() == children and layer.anchor_for(p) == bar, "attach is idempotent")
	var dummy := Node2D.new()
	layer.attach(dummy, null)
	check(layer.anchor_for(dummy) == null, "non-units are ignored")
	dummy.free()


## Overhead status rows are smaller than the bars (3D ground is foreshortened), minions draw a compact CC
## icon only, and overlapping champion status blocks are nudged apart on screen.
func _test_status_declutter(p, enemy, minion) -> void:
	var saved: Vector2 = enemy.global_position
	p.visible = true
	enemy.visible = true
	layer.sync(host)
	var ps = layer.anchor_for(p).get_node("OverheadStatus")
	var es = layer.anchor_for(enemy).get_node("OverheadStatus")
	var ms = layer.anchor_for(minion).get_node("OverheadStatus")
	check(ps.scale.is_equal_approx(Vector2.ONE * OverheadLayer.STATUS_SCALE_CHAMPION) and ms.scale.is_equal_approx(Vector2.ONE * OverheadLayer.STATUS_SCALE_SMALL), "overhead status rows are scaled below the bar scale")
	# Pivot line stays fixed: a point on it maps to the same bar-local y at any scale.
	var pivot: float = -Constants.CHAMP_ART_HEIGHT - OverheadLayer.STATUS_PIVOT_CHAMPION_PX
	check(absf(ps.position.y + ps.scale.y * pivot - pivot) < 0.01, "champion status scales about the line above the name")
	p.stun = 1.0
	enemy.stun = 1.0
	minion.stun = 1.0
	enemy.global_position = p.global_position + Vector2(8, 4)
	for sv in [ps, es, ms]:
		sv.refresh()
	layer.sync(host)
	check(str(ms.primary_status.get("id", "")) == "stun", "stunned minion keeps its CC status for the compact icon")
	var pb: Vector2 = layer.anchor_for(p).position
	var eb: Vector2 = layer.anchor_for(enemy).position
	var p_top: float = pb.y + ViewConfig.OVERHEAD_SCALE * ps.position.y
	var e_top: float = eb.y + ViewConfig.OVERHEAD_SCALE * es.position.y
	check(absf(p_top - e_top) > 20.0, "overlapping STUNNED badges are nudged apart (%.1f px)" % absf(p_top - e_top))
	p.stun = 0.0
	enemy.stun = 0.0
	minion.stun = 0.0
	enemy.global_position = saved
	for sv in [ps, es, ms]:
		sv.refresh()
	layer.sync(host)


func _test_follow_and_visibility(p, minion) -> void:
	var k := ViewConfig.OVERHEAD_SCALE
	layer.sync(host)
	var bar = layer.anchor_for(p)
	check(bar.visible, "anchor visible for a living, visible unit")
	var head: Vector2 = host.world_to_screen(p.global_position, Constants.CHAMP_ART_HEIGHT)
	check((bar.position - Vector2(0, Constants.CHAMP_ART_HEIGHT * k)).distance_to(head) < 0.01, "BarAnchor head line is the projected head")
	check(bar.scale.is_equal_approx(Vector2(k, k)), "BarAnchor scale is OVERHEAD_SCALE")
	var body = layer.body_anchor_for(p)
	check(body.position.distance_to(host.world_to_screen(p.global_position)) < 0.01, "BodyAnchor sits at the projected feet")
	var mbar = layer.anchor_for(minion)
	var mtop: float = -minion.art_rect().position.y
	# Minions: the head line is lifted with the minion card scale and the bars use the smaller minion overhead scale.
	var km := ViewConfig.OVERHEAD_SCALE_MINION
	var mhead: Vector2 = host.world_to_screen(minion.global_position, mtop * ViewConfig.MINION_SCALE / ViewConfig.UNIT_SCALE)
	check((mbar.position - Vector2(0, mtop * km)).distance_to(mhead) < 0.01, "minion BarAnchor uses -art_rect().position.y (minion card scale)")
	check(mbar.scale.is_equal_approx(Vector2(km, km)) and km < k, "minion bars use the smaller OVERHEAD_SCALE_MINION (%.2f < %.2f)" % [km, k])
	p.buffs.airborne = {"time": 0.5, "duration": 1.0}
	layer.sync(host)
	var lift := HeroControl.lift(p)
	check(lift > 1.0 and (bar.position - Vector2(0, Constants.CHAMP_ART_HEIGHT * k)).distance_to(host.world_to_screen(p.global_position, Constants.CHAMP_ART_HEIGHT + lift)) < 0.01, "airborne lift raises the bars along U")
	p.buffs.erase("airborne")
	p.visible = false
	layer.sync(host)
	check(not bar.visible and not body.visible, "anchors hide when the unit is hidden")
	p.visible = true
	p.dead = true
	layer.sync(host)
	check(not bar.visible, "anchors hide when the unit is dead")
	p.dead = false
	p.modulate.a = 0.72
	layer.sync(host)
	check(bar.visible and is_equal_approx(bar.modulate.a, 0.72), "anchor mirrors the unit's brush fade")
	p.modulate.a = 1.0
	layer.sync(host)


func _bar_width(control: Control) -> float:
	var xf := control.get_global_transform()
	return (xf * Vector2(control.size.x, 0) - xf * Vector2.ZERO).length()


func _test_constant_size(p) -> void:
	var start: Vector2 = p.global_position
	p.global_position = Vector2(FOCUS.x, 150)
	layer.sync(host)
	var far_width := _bar_width(p.hp_bar_bg)
	var far_body: float = layer.body_anchor_for(p).scale.x
	p.global_position = Vector2(FOCUS.x, 420)
	layer.sync(host)
	var near_width := _bar_width(p.hp_bar_bg)
	var near_body: float = layer.body_anchor_for(p).scale.x
	check(absf(far_width - near_width) < 0.001, "bar screen width is constant at two distances (%.3f vs %.3f)" % [far_width, near_width])
	check(absf(near_width - (Constants.CHAMP_BAR_WIDTH + 2.0) * ViewConfig.OVERHEAD_SCALE) < 0.01, "bar width is the 2D width times OVERHEAD_SCALE")
	check(near_body > far_body, "BodyAnchor follows perspective (nearer is larger)")
	p.global_position = start
	layer.sync(host)


func _test_floats() -> void:
	var ft = FloatingText.new()
	world.add_child(ft)
	ft.setup(FOCUS + Vector2(-40, 0), "123", Color.WHITE)
	var label = ft.label
	layer.add_float(ft)
	layer.add_float(ft)
	var holder = layer.float_for(ft)
	check(holder is ScreenFloat and label.get_parent() == holder, "float label is reparented into a ScreenFloat")
	check(layer.floats_root.get_child_count() == 1, "add_float is idempotent")
	layer.sync(host)
	var kn := ViewConfig.FLOAT_SCALE_NUMBER
	var expected: Vector2 = host.world_to_screen(Vector2(ft.global_position.x, ft.start_y), 10.0)
	check(holder.visible and holder.anchor.distance_to(expected) < 0.01 and holder.scale.is_equal_approx(Vector2(kn, kn)), "float anchor starts 10 art px above its point, numbers at FLOAT_SCALE_NUMBER")
	check(holder.position.distance_to(holder.anchor - Vector2(0.0, holder.nudge)) < 0.01 and holder.nudge >= 0.0, "float is placed at its anchor minus the upward stacking nudge")
	var y0: float = holder.anchor.y
	ft._process(0.6)
	layer.sync(host)
	check(holder.anchor.y < y0 - 1.0, "float rises on screen")
	check(label.modulate.a < 1.0, "FloatingText still fades its (reparented) label")
	ft.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(label) and not is_instance_valid(holder), "float label frees with its source")
	await _test_float_declutter()


## Final fix (declutter): worded callouts are smaller than numbers and much smaller than the bars, texts spawned
## on the same spot stack instead of overlapping, and a text over a champion's name/bar block is pushed above it.
func _test_float_declutter() -> void:
	check(ScreenFloat.is_number_text("-112") and ScreenFloat.is_number_text("+42g") and not ScreenFloat.is_number_text("+75g ASSIST") and not ScreenFloat.is_number_text("Q +1"), "number vs worded float classification")
	check(ViewConfig.FLOAT_SCALE_WORD < ViewConfig.FLOAT_SCALE_NUMBER and ViewConfig.FLOAT_SCALE_NUMBER < ViewConfig.OVERHEAD_SCALE, "float scales: words < numbers < bars")
	var at := FOCUS + Vector2(-260, 40)    # clear of the test champions' blocks
	var texts := ["LEVEL 4", "LEVEL 4 • CHOOSE BUILD [U]", "TURRET DESTROYED", "-29"]
	var fts: Array = []
	for i in texts.size():
		var ft = FloatingText.new()
		world.add_child(ft)
		ft.setup(at, texts[i], Color.WHITE, i == 2)
		ft.elapsed = 0.01 * float(texts.size() - i)   # later texts are newer
		layer.add_float(ft)
		fts.append(ft)
	layer.sync(host)
	var rects: Array = []
	for ft in fts:
		var h = layer.float_for(ft)
		var r: Rect2 = h.text_rect()
		rects.append(Rect2(h.position + r.position * h.scale.x, r.size * h.scale.x))
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].grow(-0.5).intersects(rects[j].grow(-0.5)):
				overlaps += 1
	check(overlaps == 0, "four texts spawned on one spot stack without overlapping (%d overlaps)" % overlaps)
	var turret = layer.float_for(fts[2])
	var newest = layer.float_for(fts[3])
	check(turret.is_callout() and turret.nudge == 0.0, "the big callout keeps its spawn point")
	check(newest.nudge > 0.0 and newest.nudge < layer.float_for(fts[0]).nudge and is_equal_approx(newest.scale.x, ViewConfig.FLOAT_SCALE_NUMBER), "the newest of the others sits lowest above it, the oldest highest")
	var tr: Rect2 = turret.text_rect()
	check(tr.size.x * turret.scale.x < 300.0 and absf(tr.get_center().x) < 0.5, "TURRET DESTROYED is centred and under 300 px wide (%.0f px)" % (tr.size.x * turret.scale.x))
	for ft in fts:
		ft.queue_free()
	# A pile of numbers on one spot: the newest ones are shown, stacked without overlap; the overflow is dropped.
	var pile: Array = []
	for i in 14:
		var ft = FloatingText.new()
		world.add_child(ft)
		ft.setup(at + Vector2(0, 300), "-%d" % (10 + i), Color.WHITE)
		ft.elapsed = 0.01 * float(14 - i)
		layer.add_float(ft)
		pile.append(ft)
	layer.sync(host)
	var shown_rects: Array = []
	var dropped := 0
	for ft in pile:
		var h = layer.float_for(ft)
		if h.modulate.a < 0.5:
			dropped += 1
			continue
		var r: Rect2 = h.text_rect()
		shown_rects.append(Rect2(h.position + r.position * h.scale.x, r.size * h.scale.x))
	var pile_overlaps := 0
	for i in shown_rects.size():
		for j in range(i + 1, shown_rects.size()):
			if shown_rects[i].grow(-0.5).intersects(shown_rects[j].grow(-0.5)):
				pile_overlaps += 1
	var newest_pile = layer.float_for(pile[13])
	check(dropped > 0 and pile_overlaps == 0 and newest_pile.modulate.a == 1.0 and newest_pile.nudge == 0.0, "a pile of 14 numbers keeps the newest, stacks them without overlap and drops %d" % dropped)
	for ft in pile:
		ft.queue_free()
	# A text whose natural spot overlaps the player's name/bar block is lifted above it. The spawn point is walked
	# up the screen until its unnudged rect overlaps the block (the projection depends on the camera).
	var p = GameState.player
	var bar = layer.anchor_for(p)
	var ft2 = FloatingText.new()
	world.add_child(ft2)
	ft2.setup(p.global_position, "LEVEL 4", Color.WHITE, true)
	layer.add_float(ft2)
	var h2 = layer.float_for(ft2)
	var block := Rect2()
	var natural := Rect2()
	var drawn := Rect2()
	var hit := false
	for north in range(0, 260, 10):
		ft2.global_position = p.global_position + View3DTestKit.screen_dir(Vector2.UP) * north
		ft2.start_y = ft2.global_position.y
		h2.placed = false
		layer.sync(host)
		block = Rect2(bar.position + OverheadLayer.CHAMP_BLOCK.position * ViewConfig.OVERHEAD_SCALE, OverheadLayer.CHAMP_BLOCK.size * ViewConfig.OVERHEAD_SCALE)
		var r2: Rect2 = h2.text_rect()
		natural = Rect2(h2.anchor + r2.position * h2.scale.x, r2.size * h2.scale.x)
		drawn = Rect2(h2.position + r2.position * h2.scale.x, r2.size * h2.scale.x)
		if natural.intersects(block):
			hit = true
			break
	check(hit and not drawn.intersects(block) and drawn.end.y <= block.position.y, "a text over the name/bar block is drawn above it (nudge %.0f px)" % h2.nudge)
	ft2.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _caption(text: String) -> Variant:
	for item in layer.captions():
		if item.text == text:
			return item
	return null


func _test_captions(p, minion) -> void:
	var k := ViewConfig.OVERHEAD_SCALE
	GameState.running = true
	GameState.cursor_world = FOCUS + Vector2(30, 60)
	layer.sync(host)
	check(_caption("A • CLICK TO ATTACK") == null, "no A-move caption while not pending")
	GameState.attack_move_pending = true
	minion.hp = 1.0
	layer.sync(host)
	var a_move = _caption("A • CLICK TO ATTACK")
	check(a_move != null, "ReticleText A-move caption appears when attack_move_pending")
	if a_move != null:
		# Windowed builds anchor cursor captions to the real mouse; headless projects the cursor point.
		var cursor: Vector2 = host.world_to_screen(GameState.cursor_world) if DisplayServer.get_name() == "headless" else get_viewport().get_mouse_position()
		var at: Vector2 = cursor + Vector2(18, -18) * k
		check(a_move.pos.distance_to(at) < 0.01 and a_move.size == roundi(15 * k), "cursor caption at cursor + offset*k, scaled font")
	var last_hit = _caption("LAST HIT")
	check(last_hit != null, "LAST HIT caption for a killable enemy minion in range")
	if last_hit != null:
		check(last_hit.pos.distance_to(layer.anchor_for(minion).position + Vector2(-16, -42) * k) < 0.01, "unit caption follows the BarAnchor")
	GameState.attack_move_pending = false
	layer.sync(host)
	check(_caption("A • CLICK TO ATTACK") == null and _caption("LAST HIT") == null, "captions clear when A-move ends")
	minion.hp = minion.hp_max


func _test_deadeye(p, enemy) -> void:
	layer.sync(host)
	check(layer.deadeye_lines().is_empty(), "no Deadeye line without a channel")
	enemy.buffs.deadeye = {"time": 0.5, "duration": 1.0, "serial": 0, "target": Roster12Kits.ref(p), "origin": enemy.world_pos()}
	check(not DeadeyeCue.channel(enemy).is_empty(), "fake Deadeye channel resolves")
	layer.sync(host)
	var lines := layer.deadeye_lines()
	check(lines.size() == 1, "Deadeye line appears with a fake channel buff")
	if lines.size() == 1:
		var up: Vector3 = host.card_up()
		var cam: Camera3D = host.camera()
		check(lines[0].from.distance_to(cam.unproject_position(OverheadLayer.chest3(enemy, up))) < 0.01, "line starts at the caster's projected chest")
		check(lines[0].to.distance_to(host.world_to_screen(p.global_position, OverheadLayer.CHEST_ART_PX)) < 0.01, "line ends at the target's projected chest")
		check(is_equal_approx(lines[0].progress, 0.5), "line carries the channel progress")
	enemy.visible = false
	layer.sync(host)
	check(layer.deadeye_lines().is_empty(), "hidden caster draws no Deadeye line")
	enemy.visible = true
	enemy.buffs.erase("deadeye")
	layer.sync(host)
	check(layer.deadeye_lines().is_empty(), "Deadeye line clears with the buff")


func _test_labels(minion) -> void:
	var holder := Node2D.new()
	world.add_child(holder)
	holder.global_position = FOCUS + Vector2(0, 80)
	layer.add_label(holder, "LANTERN", Color.WHITE, Vector2(-20, -30), 12)
	layer.sync(host)
	var item = _caption("LANTERN")
	check(item != null and item.pos.distance_to(host.world_to_screen(holder.global_position) + Vector2(-20, -30)) < 0.01, "add_label follows its source")
	holder.queue_free()
	await get_tree().process_frame
	layer.sync(host)
	check(_caption("LANTERN") == null, "add_label caption ends with its source")


func _test_lifecycle(p, enemy, minion) -> void:
	# A plain reparent (tree_exiting without freeing) keeps the attachment.
	world.remove_child(p)
	world.add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	check(layer.anchor_for(p) != null and p.hp_bar.get_parent() is OverheadAnchor, "reparenting the unit keeps its anchors")
	# detach() while the unit lives returns its Controls unchanged.
	var enemy_bar = layer.anchor_for(enemy)
	layer.detach(enemy)
	check(enemy.hp_bar.get_parent() == enemy and enemy.name_label.get_parent() == enemy, "detach returns Controls to a living unit")
	check(layer.anchor_for(enemy) == null, "detached unit has no anchor")
	await get_tree().process_frame
	check(not is_instance_valid(enemy_bar), "detached anchor is freed")
	# Freeing the unit frees its anchors and the reparented Controls.
	var bar = layer.anchor_for(minion)
	var hp_bar = minion.hp_bar
	GameState.minions.erase(minion)
	minion.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(bar) and not is_instance_valid(hp_bar), "anchors and bars free with their unit")
	layer.sync(host)
