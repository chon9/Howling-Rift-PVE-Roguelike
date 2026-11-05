extends Node
## W2-PROJ windowed visual (run without --headless, 1920x1080; "-- --view3d" optional, the match forces 3D).
## Freezes every hero's auto attack and Q/W/E/R missiles mid-flight in a real 3D match and captures:
##   67-3d-projectiles.png        heroes 1-9 (one row of auto, Q, W, E, R per hero)
##   67-3d-projectiles-b/c/d.png  heroes 10-18, 19-27, 28-32
##   67-3d-projectiles-e.png      minion/turret shapes, a turret bolt at its muzzle, wind thrust and tornado,
##                                Vesper bolts, hook chains, the Lux R beam and moving ult trails
##   67-3d-hover-outline.png      final polish: the unit_card hover outline on real champion views (enemy red,
##                                ally blue), checked against the same frame with the outline off
##   67-3d-float-text.png         final polish: floating combat text (ScreenFloat style: heavy outline, lift
##                                clear of the chest-height hit burst) over a real impact and particle burst
##   67-3d-objective-glow(-low).png  final polish: blue base (fountain beacon, nexus, nexus turrets, inhibitor) at
##                                the current quality and at Low (no post glow): crystal halos must still read
## The gallery sits on the open bridge between the two outer turrets and between the brush rows, so no
## structure or brush card stands in front of a missile.
## Missile presentation fields are set exactly as Projectile.setup()/configure_presentation() would for that
## hero (art row, expansion sheet, kit effect id, damage type, visual size), on the match's real projectiles.
## Checks: every projectile has a shown ProjectileView3D, every card lands on screen, and every card changes
## its pixels between a capture with and without the FX root (nothing is lost or painted flat).

const OUT := "res://tests/"
const MATCH_SEED := 20261013
const ROSTER := {"blue": ["thresh", "ashe", "lux"], "red": ["darius", "annie", "ezreal"]}
const SLOTS := ["auto", "q", "w", "e", "r"]
const FOCUS := Vector2(1400, 270)
const COLS := 3
const PAGE := 9
const COL_W := 240.0
const ROW_H := 50.0
const SLOT_W := 44.0
const ORIGIN := Vector2(1060, 212)

var failures = 0
var checks = 0
var game: Node2D
var view: View3D
var own_views: Array = []          # views this test made because the registry did not (VfxRegistry stub)
var page_nodes: Array = []         # projectiles / beams of the current page
var labels: CanvasLayer
var movers: Array = []             # [projectile, velocity, start] moving every frame (trail demo)
var movers_frozen := false


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("ok: " + message)


func _ready() -> void:
	process_priority = 200   # after View3D (100): our own views sync with this frame's camera
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("PROJECTILE3D VISUAL: skipped in headless")
		print("PROJECTILE3D VISUAL: 0 checks, 0 failures")
		get_tree().quit(0)
		return
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	game = _start_match()
	view = game.view3d
	check(view != null and view.is_active(), "3D view is active in the match")
	if view == null:
		_finish()
		return
	labels = CanvasLayer.new()
	labels.layer = 50
	add_child(labels)
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.global_position = Constants.FOUNT_B if c.team == 0 else Constants.FOUNT_R
	GameState.running = true
	GameState.paused = false
	_aim_camera(FOCUS)
	var heroes := _hero_keys()
	check(heroes.size() == 32, "gallery covers all 32 heroes (%d)" % heroes.size())
	var files := ["67-3d-projectiles.png", "67-3d-projectiles-b.png", "67-3d-projectiles-c.png", "67-3d-projectiles-d.png"]
	for page in files.size():
		await _hero_page(heroes.slice(page * PAGE, mini((page + 1) * PAGE, heroes.size())), files[page])
	await _special_page("67-3d-projectiles-e.png")
	await _hover_page("67-3d-hover-outline.png")
	await _float_page("67-3d-float-text.png")
	await _glow_page("67-3d-objective-glow.png", "67-3d-objective-glow-low.png")
	_finish()


func _finish() -> void:
	print("PROJECTILE3D VISUAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _process(delta: float) -> void:
	for m in ([] if movers_frozen else movers):
		var p = m[0]
		if is_instance_valid(p):
			p.global_position += m[1] * delta
			if p.global_position.x > m[2].x + 230.0:
				p.global_position.x = m[2].x
			p.animation_time += delta
	for v in own_views:
		if is_instance_valid(v):
			v.sync(delta)


## View3DTestKit.start_3d_match with a fixed seed and roster (private helper; the kit is frozen).
func _start_match() -> Node2D:
	seed(MATCH_SEED)
	Progression.persistent = false
	GameState.reset()
	ViewConfig.enabled = true
	OS.set_environment("HOWLING_VIEW", "3d")
	var g: Node2D = load("res://scripts/Main.gd").new()
	add_child(g)
	g.set_process(false)
	seed(MATCH_SEED)
	g._start_game(ROSTER.blue[0], {"blue": ROSTER.blue.duplicate(), "red": ROSTER.red.duplicate(), "mode": "pve", "stolen_builds": []})
	return g


func _hero_keys() -> Array:
	var out: Array = []
	for list in [["ashe", "annie", "garen", "lux", "ahri", "ezreal"], HeroArt.KEYS, ExpansionRoster.KEYS, SupportRoster.KEYS, RosterExpansion12.KEYS]:
		for k in list:
			if not out.has(k):
				out.append(k)
	return out


func _aim_camera(focus: Vector2) -> void:
	GameState.cam_locked = false
	GameState.cam_target = focus
	game.camera.position = focus
	game.camera_shake_offset = Vector2.ZERO


# --- pages ---

func _hero_page(keys: Array, file: String) -> void:
	_clear_page()
	var cards: Array = []
	for i in keys.size():
		var key: String = keys[i]
		var base := ORIGIN + Vector2((i % COLS) * COL_W, (i / COLS) * ROW_H)
		var tint := Color.from_hsv(float(i) / PAGE, 0.55, 1.0)
		for s in SLOTS.size():
			var p := _hero_missile(key, SLOTS[s], base + Vector2(s * SLOT_W, 0), tint, s)
			cards.append(p)
		_label(key.to_upper(), base + Vector2(-34, 0), 27.0, Vector2(-30, -38))
	await _shoot(file, cards)


func _special_page(file: String) -> void:
	_clear_page()
	var cards: Array = []
	var hero = GameState.player
	var tower = null
	for st in GameState.structures:
		if st.atk_dmg > 0 and (tower == null or absf(st.world_pos().x - 1000.0) < absf(tower.world_pos().x - 1000.0)):
			tower = st
	# Minion / turret SDF shapes (art_row -1), at caster-minion chest height (18 art px).
	var shapes := ["orb", "arrow", "fireball", "bolt", "ice", "wave", "heart"]
	for i in shapes.size():
		var p := _raw_missile(tower, Vector2(1110 + i * 58, 205), Vector2.RIGHT, {"shape": shapes[i], "size": 7 if shapes[i] != "wave" else 12, "color": Color.from_hsv(i / 7.0, 0.6, 1.0)})
		p.visual_height = 18.0
		cards.append(p)
		_label(shapes[i], p.global_position, 18.0, Vector2(-14, -38))
	# Turret bolt shortly after leaving the nearest turret's muzzle (lift 110 descending to the chest).
	var tb := _raw_missile(tower, tower.world_pos() + Vector2(110, 0), Vector2.RIGHT, {"shape": "bolt", "is_turret": true, "size": 8, "color": Color(1.0, 0.75, 0.35)})
	cards.append(tb)
	_label("TURRET BOLT", tb.global_position, 0.0, Vector2(-40, 12))
	# Yasuo wind thrust and tornado, Vesper bolts.
	var thrust := _hero_raw(hero, Vector2(1530, 205), Vector2.RIGHT, "yasuo", {"wind_kind": 0, "shape": "wave", "size": 9, "damage_type": "skill"})
	cards.append(thrust)
	_label("YASUO Q / Q3", thrust.global_position, 27.0, Vector2(-30, -40))
	var tornado := _hero_raw(hero, Vector2(1610, 215), Vector2.RIGHT, "yasuo", {"wind_kind": 1, "shape": "wave", "size": 20, "damage_type": "skill"})
	cards.append(tornado)
	var vauto := _hero_raw(hero, Vector2(1690, 205), Vector2.RIGHT, "vayne", {"damage_type": "auto", "size": 7, "effect_id": "vayne_auto"})
	cards.append(vauto)
	var vcond := _hero_raw(hero, Vector2(1750, 205), Vector2.RIGHT, "vayne", {"damage_type": "physical", "size": 7, "effect_id": "vayne_e"})
	cards.append(vcond)
	_label("VAYNE AUTO / E", vauto.global_position, 27.0, Vector2(-20, -40))
	# Hook chains: thresh_q and blitzcrank_q flying away from their casters.
	var a1 = GameState.champions[1]
	a1.global_position = Vector2(1060, 262)
	var hook := _hero_raw(a1, Vector2(1260, 256), Vector2.RIGHT.rotated(-0.03), "thresh", {"effect_id": "thresh_q", "hook_chain": true, "damage_type": "magic"})
	cards.append(hook)
	_label("THRESH Q", hook.global_position, 27.0, Vector2(-20, -40))
	var a2 = GameState.champions[2]
	a2.global_position = Vector2(1060, 318)
	var grab := _hero_raw(a2, Vector2(1260, 322), Vector2.RIGHT.rotated(0.02), "blitzcrank", {"effect_id": "blitzcrank_q", "hook_chain": true, "damage_type": "magic"})
	cards.append(grab)
	_label("BLITZCRANK Q", grab.global_position, 27.0, Vector2(-20, -40))
	# Lux R beam, south of the brush row.
	hero.global_position = Vector2(1000, 445)
	var beam: Node2D = load("res://scripts/Beam.gd").new()
	game.world_root.add_child(beam)
	beam.setup(hero, Vector2.RIGHT, 760.0, 32.0, 0.0, Color("fff2ba"))
	beam.art_row = SpellArt.ROWS.lux
	beam.life = 0.32
	page_nodes.append(beam)
	_label("LUX R BEAM", Vector2(1080, 445), 20.0, Vector2(0, -44))
	# Moving ult trails (particles on every peer instead of 2D puffs).
	for i in 3:
		var start := Vector2(1340, 262 + i * 28)
		var key: String = ["ashe", "jinx", "ezreal"][i]
		var m := _hero_raw(hero, start, Vector2.RIGHT, key, {"damage_type": "skill", "is_ult": true, "trail": true, "size": 14, "color": [Color(0.6, 0.85, 1.0), Color(1.0, 0.45, 0.6), Color(1.0, 0.85, 0.4)][i]})
		movers.append([m, Vector2(420, 0), start])
		cards.append(m)
	_label("ULT TRAILS", Vector2(1450, 262), 27.0, Vector2(0, -44))
	GameState.paused = true   # freezes the beam's life and the view clocks; movers keep flying
	await _frames(30)   # let the movers lay down a trail
	await _shoot(file, cards, beam if is_instance_valid(beam) else null)


## Hover outline (unit_card.gdshader) on real SpriteUnitView3D cards: an enemy and an ally hovered side by side.
## The picker is paused for the page so it cannot clear the outlines (PickingTests covers the mouse wiring).
func _hover_page(file: String) -> void:
	_clear_page()
	GameState.paused = false
	var enemy = GameState.champions[3]
	var ally = GameState.champions[1]
	var spots := {enemy: Vector2(1330, 280), ally: Vector2(1480, 280)}
	for c in spots:
		c.global_position = spots[c]
		c.stop_actions()
	_aim_camera(Vector2(1400, 270))
	var picker = view.picker
	view.picker = null
	await _frames(6)
	view.sync_now()
	var ev = view.view_for(enemy)
	var av = view.view_for(ally)
	check(ev != null and ev.has_method("set_hover") and av != null and av.has_method("set_hover"), "%s: both champions have unit views" % file)
	if ev == null or av == null:
		view.picker = picker
		return
	ev.set_hover(1)
	av.set_hover(2)
	var img := await _capture(file)
	ev.set_hover(0)
	av.set_hover(0)
	await _frames(3)
	var bare: Image = await View3DTestKit.capture(self)
	view.picker = picker
	if img == null or bare == null:
		return
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	for pair in [[ev, Color(1.0, 0.25, 0.2), "enemy red"], [av, Color(0.3, 0.75, 1.0), "ally blue"]]:
		var r: Rect2 = pair[0].screen_rect(view.camera())
		var rect := Rect2i(Rect2(r.position * scale, r.size * scale).grow(6.0))
		var n := 0
		var hue := 0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var a := img.get_pixel(x, y)
				var b := bare.get_pixel(x, y)
				if maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > 0.12:
					n += 1
					var want: Color = pair[1]
					if Vector3(a.r - want.r, a.g - want.g, a.b - want.b).length() < 0.45:
						hue += 1
		print("%s %s: %d changed px, %d near the outline colour" % [file, pair[2], n, hue])
		check(n > 400 and hue > n / 3, "%s: %s outline drawn around the card (%d changed px, %d in colour)" % [file, pair[2], n, hue])


## Floating combat text over a hit: Main.floating_text at the game's own damage offset (world_pos + (0, -20)) plus
## the impact burst and particles a hit makes, frozen a few frames in.
func _float_page(file: String) -> void:
	_clear_page()
	GameState.paused = false
	var enemy = GameState.champions[3]
	var ally = GameState.champions[1]
	var before: Array = game.world_root.get_children()
	game.spawn_impact(enemy.world_pos(), Color(1.0, 0.55, 0.3), 14.0)
	FxBurst3D.emit(view, enemy.world_pos(), Color(1.0, 0.6, 0.3), 18, ViewConfig.CHEST_PX)
	game.floating_text(enemy.world_pos() + Vector2(0, -20), "-245", Color(1.0, 0.36, 0.26), true)
	game.floating_text(ally.world_pos() + Vector2(0, -20), "-87", Color(0.75, 0.55, 1.0))
	game.spawn_impact(ally.world_pos(), Color(0.7, 0.5, 1.0), 12.0)
	var fts: Array = []
	for n in game.world_root.get_children():
		if not before.has(n) and n is FloatingText:
			fts.append(n)
	await _frames(10)
	GameState.paused = true
	await _frames(2)
	check(fts.size() == 2, "%s: two floating texts spawned (%d)" % [file, fts.size()])
	for ft in fts:
		var holder = view.overhead.float_for(ft) if is_instance_valid(ft) else null
		var lbl: Label = holder.label if holder != null else null
		check(holder is ScreenFloat and lbl != null and holder.visible, "%s: %s is shown through a ScreenFloat" % [file, ft.label.text if lbl == null else lbl.text])
		if lbl == null:
			continue
		var big := lbl.get_theme_font_size("font_size") >= 20
		check(lbl.get_theme_constant("outline_size") == (ScreenFloat.OUTLINE_BIG if big else ScreenFloat.OUTLINE_SMALL), "%s: %s has the heavy outline" % [file, lbl.text])
		check(is_equal_approx(lbl.position.y, -10.0 - ScreenFloat.LIFT_PX), "%s: %s is lifted %.0f local px (%.0f screen px)" % [file, lbl.text, ScreenFloat.LIFT_PX, ScreenFloat.LIFT_PX * holder.scale.x])
		check(lbl.modulate.a > 0.99, "%s: %s is at full opacity early in its life (%.2f)" % [file, lbl.text, lbl.modulate.a])
		# The text's centre sits above the chest-height burst point of its unit.
		var src = enemy if ft.global_position.x == enemy.world_pos().x else ally
		var chest: Vector2 = view.world_to_screen(src.world_pos(), ViewConfig.CHEST_PX)
		var centre: Vector2 = holder.position + (lbl.position + lbl.size * 0.5) * holder.scale.x
		check(centre.y < chest.y - 20.0, "%s: %s sits above the chest burst (text y %.0f, chest y %.0f)" % [file, lbl.text, centre.y, chest.y])
	await _capture(file)
	GameState.paused = false


## Objective glow at the blue base: every crystal changes its surroundings against the same frame with the glow
## layers culled, at the configured quality and again at Low (environment glow off).
func _glow_page(file: String, file_low: String) -> void:
	_clear_page()
	GameState.paused = false
	for i in GameState.champions.size():
		GameState.champions[i].global_position = Vector2(1500 + 40 * i, 300)
	_aim_camera(Vector2(470, 270))
	await _frames(8)
	GameState.paused = true
	var quality := ViewConfig.quality_settings()
	await _glow_shot(file, true)
	view.arena.apply_quality(ViewConfig.QUALITY["low"])
	await _glow_shot(file_low, false)
	view.arena.apply_quality(quality)
	GameState.paused = false


func _glow_shot(file: String, glow_on: bool) -> void:
	check(view.arena.environment.glow_enabled == glow_on, "%s: environment glow %s" % [file, "on" if glow_on else "off"])
	var img := await _capture(file)
	var glows: Array = []
	for st in GameState.structures:
		var v = view.view_for(st)
		if v is StructureView3D and v.glow.visible:
			glows.append([st, v])
	var cores: Node3D = view.arena.get_node("CrystalGlow")
	cores.visible = false
	for g in glows:
		g[1].glow.layers = 0
	await _frames(3)
	var bare: Image = await View3DTestKit.capture(self)
	cores.visible = true
	for g in glows:
		g[1].glow.layers = 1
	if img == null or bare == null:
		return
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var shown := 0
	var weak: Array = []
	for g in glows:
		var st = g[0]
		var ar: Rect2 = st.art_rect
		var c: Vector2 = view.world_to_screen(st.world_pos(), -ar.position.y * 0.75 * ViewConfig.STRUCTURE_SCALE / ViewConfig.UNIT_SCALE) * scale
		if not Rect2(Vector2(40, 40), Vector2(img.get_size()) - Vector2(80, 80)).has_point(c):
			continue
		shown += 1
		var r := 46
		var ratio := View3DTestKit.diff_ratio(img, bare, Rect2i(Vector2i(c) - Vector2i(r, r), Vector2i(r * 2, r * 2)), 0.04)
		print("%s %s glow ratio %.2f" % [file, st.type, ratio])
		if ratio < 0.3:
			weak.append("%s %.2f" % [st.type, ratio])
	check(shown >= 4, "%s: base crystals on screen (%d)" % [file, shown])
	check(weak.is_empty(), "%s: every crystal halo lights >= 30%% of a 92 px box around it %s" % [file, weak])


func _clear_page() -> void:
	movers.clear()
	movers_frozen = false
	for v in own_views:
		if is_instance_valid(v):
			v.queue_free()
	own_views.clear()
	for n in page_nodes:
		if is_instance_valid(n):
			GameState.projectiles.erase(n)
			n.queue_free()
	page_nodes.clear()
	for l in labels.get_children():
		l.queue_free()


## A projectile set up from `src` (gameplay fields), then dressed as `key` would dress it.
func _hero_missile(key: String, slot: String, pos: Vector2, tint: Color, index: int) -> Node2D:
	var auto := slot == "auto"
	var opts := {"damage_type": "auto" if auto else "skill", "size": 6 if auto else (14 if slot == "r" else 9), "color": tint}
	if slot == "r":
		opts["is_ult"] = true
	if auto:
		if key == "vayne":
			opts["effect_id"] = "vayne_auto"
		elif key in SupportRoster.KEYS or key in RosterExpansion12.KEYS:
			opts["effect_id"] = key + "_auto"
	elif KitEffectArt.has_effect(key + "_" + slot):
		opts["effect_id"] = key + "_" + slot
	var p := _hero_raw(GameState.player, pos, Vector2.RIGHT, key, opts)
	p.animation_time = 0.07 * index
	p.is_ult = false   # keep the ult's size, but no trail particles on a frozen gallery card
	return p


func _hero_raw(src, pos: Vector2, dir: Vector2, key: String, opts: Dictionary) -> Node2D:
	var p := _raw_missile(src, pos, dir, opts)
	p.art_row = int(SpellArt.ROWS.get(key, 5))
	p.expansion_art = ExpansionRoster.KEYS.has(key)
	if p.expansion_art:
		p.art_row = ExpansionRoster.KEYS.find(key)
	p.effect_id = str(opts.get("effect_id", ""))
	p.configure_presentation()
	return p


func _raw_missile(src, pos: Vector2, dir: Vector2, opts: Dictionary) -> Node2D:
	var p: Node2D = game.ProjectileS.new()
	game.world_root.add_child(p)
	var o := {"speed": 0.0, "life": 999.0, "dmg": 0.0}
	o.merge(opts, true)
	p.setup(src, pos, dir, o)
	p.effect_id = str(opts.get("effect_id", p.effect_id))
	page_nodes.append(p)
	return p


func _label(text: String, world: Vector2, lift_px: float, offset: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
	l.add_theme_constant_override("outline_size", 5)
	l.set_meta("world", world)
	l.set_meta("lift", lift_px)
	l.set_meta("offset", offset)
	labels.add_child(l)


func _place_labels() -> void:
	for l in labels.get_children():
		var s: Vector2 = view.world_to_screen(l.get_meta("world"), l.get_meta("lift"))
		l.position = s + l.get_meta("offset")


## Makes sure every node has a 3D view (the registry's when VfxRegistry provides one, else our own), then
## captures with and without the FX root and checks every card.
func _shoot(file: String, cards: Array, beam: Node2D = null) -> void:
	view.sync_now()
	var views: Array = []
	for p in cards + ([beam] if beam != null else []):
		var v = view.view_for(p)
		if v == null:
			v = (BeamView3D.new() if p == beam else ProjectileView3D.new())
			view.add_fx(v)
			v.bind(p, view)
			own_views.append(v)
		v.sync(0.0)
		views.append(v)
	GameState.paused = true
	movers_frozen = true
	_place_labels()
	var shown := 0
	for i in cards.size():
		var v = views[i]
		if v is ProjectileView3D and v.visible and v.card.visible:
			shown += 1
	check(shown == cards.size(), "%s: every projectile has a shown ProjectileView3D card (%d/%d)" % [file, shown, cards.size()])
	if beam != null:
		var bv = views.back()
		check(bv is BeamView3D and bv.visible and bv.ribbon.visible, "%s: the beam has a shown BeamView3D ribbon" % file)
	var img := await _capture(file)
	view.fx_root.visible = false
	await _frames(3)
	var bare: Image = await View3DTestKit.capture(self)
	view.fx_root.visible = true
	GameState.paused = false
	if img == null or bare == null:
		return
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var off_screen := 0
	var faint: Array = []
	for i in cards.size():
		var v = views[i]
		if not (v is ProjectileView3D):
			continue
		var s: Vector2 = view.camera().unproject_position(v.card.global_position) * scale
		if not Rect2(Vector2(20, 20), Vector2(img.get_size()) - Vector2(40, 40)).has_point(s):
			off_screen += 1
			continue
		var r := _card_rect(v.card, scale)
		var ratio := View3DTestKit.diff_ratio(img, bare, r, 0.06)
		if ratio < 0.1:
			faint.append("%s@%s %.2f" % [cards[i].effect_id if cards[i].effect_id != "" else "row%d" % cards[i].art_row, Vector2i(s), ratio])
	check(off_screen == 0, "%s: every card is on screen (%d off)" % [file, off_screen])
	check(faint.is_empty(), "%s: every card changes >= 10%% of its screen rect %s" % [file, faint])
	if beam != null:
		var a: Vector2 = view.world_to_screen(beam.global_position + Vector2(150, 0), 20.0) * scale
		var b: Vector2 = view.world_to_screen(beam.global_position + Vector2(550, 0), 20.0) * scale
		var ra := View3DTestKit.diff_ratio(img, bare, Rect2i(Vector2i(a) - Vector2i(8, 8), Vector2i(16, 16)), 0.06)
		var rb := View3DTestKit.diff_ratio(img, bare, Rect2i(Vector2i(b) - Vector2i(8, 8), Vector2i(16, 16)), 0.06)
		check(ra > 0.5 and rb > 0.5, "%s: the beam ribbon covers its length (%.2f, %.2f)" % [file, ra, rb])


## Screen rect (image px) of a card quad.
func _card_rect(card: MeshInstance3D, scale: Vector2) -> Rect2i:
	var cam := view.camera()
	var out := Rect2()
	for i in 4:
		var corner := Vector3(-0.5 if i % 2 == 0 else 0.5, -0.5 if i < 2 else 0.5, 0.0)
		var sp := cam.unproject_position(card.global_transform * corner) * scale
		out = Rect2(sp, Vector2.ZERO) if i == 0 else out.expand(sp)
	return Rect2i(out)


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
