extends Node
## W1-HUB windowed visual for Rift3D (run without --headless, "-- --view3d", 1920x1080).
## Writes 60-3d-lane.png, 61-3d-base.png, 62-3d-teamfight.png and 63-3d-brush.png under res://tests/ and runs
## pixel checks: (a) centre luminance variance >= 0.002, (b) no screen corner shows the clear colour (no void),
## (c) the player's body rect changes > 25% between hero-visible and hero-hidden captures,
## (d) the player's hp_bar centre pixel is within 0.12 of Constants.TEAM_HP[team].
## (a)-(b) gate W1-HUB; (c)-(d) depend on W1-UNITS / W1-OVERHEAD and gate the W1 wave.
## W2-VFX adds 66-3d-spells.png (FastVisual-style): every champion in a cast pose with spell bursts, wind bursts,
## hero impacts (rows 0-3), impact sparks, minion hits and particle bursts frozen mid-animation. Checks (e) every
## FX source has a camera-facing view whose card sits above its ground point, (f) the card pixels differ from a
## capture with the FX views hidden (they actually render), (g) no VIEW source draws flat in the overlay.
## W3-POLISH adds 69-3d-mlbb.png (ViewConfig.preset switched to "mlbb" mid-match: the rig blends to pitch 50,
## FOV 45, 17 m) and 70-3d-low.png (Low quality applied at runtime: no sun shadows, no glow, no snow, no
## brush sway, 2048x1024 overlay), then restores the LoL preset and High quality. The brush shot waits for
## the eased patch fade to settle.

const OUT := "res://tests/"
const BOT_FRAMES := 900
const BOT_DT := 1.0 / 60.0
## Deterministic matches, so Compatibility and Forward+ captures show the same frame (renderer A/B diffs):
## fixed RNG seed, pinned roster (no shuffle, no stolen builds) and fixed-step animators in the bot loop.
const MATCH_SEED := 20261013
const ROSTER := {"blue": ["ashe", "garen", "lux"], "red": ["darius", "annie", "ezreal"]}
const AIM_SKILL := 1   # Skadi W "Volley": a 450 px line skillshot (her Q is a self buff with no indicator)

var failures = 0
var checks = 0
var game: Node2D
var view: View3D


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("ok: " + message)


func _ready() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("VIEW3D VISUAL: skipped in headless")
		print("VIEW3D VISUAL: 0 checks, 0 failures")
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
	GameState.running = true
	GameState.paused = false
	await _shot_lane()
	await _shot_base()
	await _shot_teamfight()
	await _shot_brush()
	await _shot_spells()
	await _shot_mlbb()
	await _shot_low()
	_finish()


func _finish() -> void:
	print("VIEW3D VISUAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## View3DTestKit.start_3d_match with a fixed seed and roster (the kit is frozen; this is a private helper).
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


## Advances every unit animator by a fixed step (their own _process would use the real frame delta).
func _step_animators(dt: float) -> void:
	for u in GameState.champions + GameState.minions:
		if is_instance_valid(u) and u.animator != null:
			u.animator.set_process(false)
			u.animator.advance(dt)


# --- scenes ---

func _shot_lane() -> void:
	# Bots play the lane while the player waits at the fountain (deterministic: the player never dies, so no
	# death tint or DEAD HUD state leaks into the captures).
	var p = GameState.player
	p.is_bot = false
	seed(MATCH_SEED + 1)
	# The views sync after every sim step (as in play: one sim frame per view frame), so blink detection and the
	# FX clocks see each step rather than 30 steps batched between two rendered frames.
	var t0 := Time.get_ticks_msec()
	for i in range(BOT_FRAMES):
		p.stop_actions()
		p.global_position = Constants.FOUNT_B
		game._process(BOT_DT)
		_step_animators(BOT_DT)
		view.sync_now()
		if i % 30 == 0:
			await get_tree().process_frame
	var blinks := 0
	for c in GameState.champions:
		var cv = view.view_for(c)
		var ex = cv.get("extras") if cv != null else null
		if ex != null:
			for e in ex.events:
				if e.type.begins_with("blink"):
					print("  %s %s at %s (t %.2f)" % [c.hero_key, e.type, e.at, e.time])
				if e.type == "blink_to":
					blinks += 1
	print("lane bot loop: %d sim steps with per-step view sync in %d ms, %d blink flares logged" % [BOT_FRAMES, Time.get_ticks_msec() - t0, blinks])
	if p.dead:
		game._respawn_champion(p)
	p.stop_actions()
	p.global_position = Vector2(1380, 300)
	_full_hp(p)
	_aim_camera(Vector2(1400, 270))
	_freeze(true)
	var img := await _capture("60-3d-lane.png")
	_pixel_checks(img, "lane")
	_check_hp_bar(img, p)
	# (c) body rect visible vs hidden. Upright FX (W2) and allies standing on the player can cover the body in the
	# frozen lane frame, so this pair of captures is taken with the FX views hidden and the player moved to the
	# clearest nearby spot.
	p.global_position = _clear_spot(p, [Vector2(1380, 300), Vector2(1380, 410), Vector2(1300, 410), Vector2(1460, 410), Vector2(1300, 140), Vector2(1460, 140)])
	view.fx_root.visible = false
	view.sync_now()
	await _frames(2)
	var rect := _body_rect(p, img)
	var body_img := await View3DTestKit.capture(self)
	p.visible = false
	await _frames(2)
	var hidden := await View3DTestKit.capture(self)
	p.visible = true
	view.fx_root.visible = true
	var ratio := View3DTestKit.diff_ratio(body_img, hidden, rect)
	check(ratio > 0.25, "(c) player body rect %s differs %.1f%% between visible and hidden (> 25%%)" % [rect, ratio * 100.0])
	_freeze(false)


func _shot_base() -> void:
	_aim_camera(Constants.FOUNT_B + Vector2(350, 0))
	_freeze(true)
	var img := await _capture("61-3d-base.png")
	_pixel_checks(img, "base")
	_freeze(false)


func _shot_teamfight() -> void:
	var blue := []
	var red := []
	for c in GameState.champions:
		if c.dead:
			game._respawn_champion(c)
		c.is_bot = false
		c.stop_actions()
		(blue if c.team == 0 else red).append(c)
	for i in blue.size():
		blue[i].global_position = Vector2(1290 - i * 28, 225 + i * 50)
		blue[i].facing = Vector2.RIGHT
	for i in red.size():
		red[i].global_position = Vector2(1420 + i * 28, 235 + i * 45)
		red[i].facing = Vector2.LEFT
	var kinds := ["melee", "melee", "caster", "siege"]
	for i in kinds.size():
		for team in [0, 1]:
			var m = game.MinionS.new()
			game.world_root.add_child(m)
			var x := 1230.0 - i * 30.0 if team == 0 else 1480.0 + i * 30.0
			m.setup(team, kinds[i], Vector2(x, 250 + i * 28))
			GameState.minions.append(m)
	var p = GameState.player
	_full_hp(p)
	_aim_camera(Vector2(1350, 270))
	# Player skillshot aim pending (W line, range 450), cursor toward the red team.
	var aim_at: Vector2 = p.world_pos() + Vector2(260, -20)
	game.pending_skill = AIM_SKILL
	game.skill_aimer.set_aim(p, AIM_SKILL)
	var sk: Dictionary = p.hero["skills"][AIM_SKILL]
	check(float(sk.get("range", 0.0)) > 0.0 and SkillFootprint.preview(p, sk).shape != "none", "teamfight aims a skill with a range ring and footprint (%s)" % sk.get("name", "?"))
	# The range ring lies on the deck: foreshortened (shorter north-south than east-west on screen).
	var rng_px := float(sk.get("range", 0.0))
	var ring_w := view.world_to_screen(p.world_pos() + Vector2(rng_px, 0)).x - view.world_to_screen(p.world_pos() - Vector2(rng_px, 0)).x
	var ring_h := view.world_to_screen(p.world_pos() + Vector2(0, rng_px)).y - view.world_to_screen(p.world_pos() - Vector2(0, rng_px)).y
	check(ring_w > 0.0 and ring_h > 0.0 and ring_h < ring_w * 0.9, "range ring foreshortened on screen (%.0f x %.0f px)" % [ring_w, ring_h])
	GameState.cursor_world = aim_at
	game.mouse_world = aim_at
	view.sync_now()
	Input.warp_mouse(view.world_to_screen(aim_at) * _screen_scale())
	_freeze(true)
	var img := await _capture("62-3d-teamfight.png")
	_pixel_checks(img, "teamfight")
	_freeze(false)
	game._cancel_pending_skill()


func _shot_brush() -> void:
	var p = GameState.player
	var patch: Rect2 = BrushVision.PATCHES[1]
	p.global_position = patch.get_center()
	_aim_camera(patch.get_center() + Vector2(0, 110))
	_freeze(true)
	# The patch fade eases on the real frame time (W3-POLISH): let it settle before the capture.
	await _frames(40)
	check(absf(view.arena._brush_fade(1) - WorldBuilder3D.BRUSH_FADE) < 0.01, "brush patch 1 settled at its fade (%.3f)" % view.arena._brush_fade(1))
	var img := await _capture("63-3d-brush.png")
	_pixel_checks(img, "brush")
	_freeze(false)


## W2-VFX: all champions casting, with every card-backed FX kind and both particle sprays on screen.
func _shot_spells() -> void:
	var blue := []
	var red := []
	for c in GameState.champions:
		if c.dead:
			game._respawn_champion(c)
		c.is_bot = false
		c.stop_actions()
		_full_hp(c)
		(blue if c.team == 0 else red).append(c)
	for i in blue.size():
		blue[i].global_position = Vector2(1215 - (i % 2) * 30, 200 + i * 70)
		blue[i].facing = Vector2.RIGHT
	for i in red.size():
		red[i].global_position = Vector2(1500 + (i % 2) * 30, 205 + i * 68)
		red[i].facing = Vector2.LEFT
	# Minions left over from the teamfight shot are hidden for this shot so the FX read clearly.
	var hidden_minions := []
	for m in GameState.minions:
		if is_instance_valid(m) and m.visible and m.world_pos().distance_to(Vector2(1355, 280)) < 520.0:
			m.visible = false
			hidden_minions.append(m)
	var casters: Array = blue + red
	for i in casters.size():
		var c = casters[i]
		if c.animator != null:
			c.animator.start(["q", "w", "e", "r"][i % 4], 10.0)
			c.anim_elapsed = 3.0 + 0.4 * i
	_aim_camera(Vector2(1355, 290))
	GameState.paused = false
	var sources := []
	# Spell bursts on the opposing champion's body, one per caster (its own spell row; Yasuo-style wind for one).
	for i in casters.size():
		var c = casters[i]
		var foes: Array = red if c.team == 0 else blue
		if foes.is_empty():
			continue
		var target = foes[i % foes.size()]
		var row: int = maxi(0, SpellArt.row_for(c))
		var burst: Node2D = load("res://scripts/WindBurst.gd" if i == casters.size() - 1 else "res://scripts/SpellBurst.gd").new()
		burst.row = 0 if i == casters.size() - 1 else row
		burst.radius = 30.0
		burst.duration = 10.0
		game.world_root.add_child(burst)
		burst.global_position = target.world_pos() + Vector2(-26 if c.team == 0 else 26, -8)
		sources.append(burst)
	# Hero impacts rows 0-2 on red bodies (spawned at victim + (0, -30) like Main.spawn_hero_impact), soul flame row 3.
	for i in mini(3, red.size()):
		var hi: Node2D = load("res://scripts/HeroImpact.gd").new()
		hi.row = i
		hi.radius = 22.0
		hi.angle = PI + 0.4 * (i - 1)
		hi.duration = 10.0
		game.world_root.add_child(hi)
		hi.global_position = red[i].world_pos() + Vector2(14, -30)
		sources.append(hi)
	var flame: Node2D = load("res://scripts/HeroImpact.gd").new()
	flame.row = 3
	flame.radius = 20.0
	flame.duration = 10.0
	game.world_root.add_child(flame)
	flame.global_position = Vector2(1355, 330)
	sources.append(flame)
	# Impact sparks (Main._ImpactFx) and a death + level-up spray (Main._BurstParticle).
	for k in 3:
		game.spawn_impact(Vector2(1320 + k * 30, 250 + k * 24), Color(1.0, 0.7, 0.3), 12.0)
	game._death_burst(Vector2(1395, 330), Color(0.95, 0.3, 0.25))
	var consts: Dictionary = (game.get_script() as GDScript).get_script_constant_map()
	if consts.has("_BurstParticle") and not blue.is_empty():
		for i in range(18):
			var bp: Node2D = consts._BurstParticle.new()
			bp.vel = Vector2.from_angle(TAU * i / 18.0) * 140.0
			bp.col = Color(1.0, 0.86, 0.33)
			bp.global_position = blue[0].world_pos()
			game.world_root.add_child(bp)
	for n in game.world_root.get_children():
		if "fx_kind" in n and str(n.fx_kind) == "impact":
			n.life = 10.0
			sources.append(n)
	# Let the sprays spread a little, then freeze everything (cards follow their frozen sources).
	await _frames(12)
	_freeze(true)
	for i in sources.size():
		var s = sources[i]
		if is_instance_valid(s) and "elapsed" in s and not ("fx_kind" in s):
			s.elapsed = 2.2 + 0.55 * (i % 6)
	# Minion hits last only 0.12 s and freeze with the pause: spawn them now.
	var minion_spots := [Vector2(1300, 395), Vector2(1335, 405), Vector2(1380, 400)]
	for spot in minion_spots:
		game.spawn_minion_hit(spot)
	for n in game.world_root.get_children():
		if n is Node2D and n.get_script() != null and str(n.get_script().resource_path).ends_with("/MinionHit.gd"):
			n.elapsed = 0.03
			sources.append(n)
	view.sync_now()
	var img := await _capture("66-3d-spells.png")
	_pixel_checks(img, "spells")
	# (e) every FX source has a camera-facing view above its ground point; (g) none draws flat.
	var cam := view.camera()
	var missing := []
	var flat := []
	var cards := []
	for s in sources:
		if not is_instance_valid(s):
			continue
		if (s as CanvasItem).visible:
			flat.append(str(s.get_script().resource_path.get_file()) if s.get_script() != null else s.name)
		var v = view.view_for(s)
		if not (v is FxCard3D) or not v.visible:
			missing.append(s.get_script().resource_path.get_file() if s.get_script() != null else str(s))
			continue
		cards.append(v)
		var faces: bool = v.card.global_basis.z.normalized().dot(cam.global_basis.z) > 0.999
		var above: bool = cam.unproject_position(v.global_position).y < cam.unproject_position(ViewMath.to3(s.global_position)).y + 0.5
		if not faces or not above:
			missing.append("%s(faces=%s above=%s)" % [v.kind, faces, above])
	var particles := 0
	var particle_views := {}
	for n in game.world_root.get_children():
		if "fx_kind" in n and str(n.fx_kind) == "burst_particle":
			particles += 1
			var bv = view.view_for(n)
			if bv != null:
				particle_views[bv.get_instance_id()] = true
			if (n as CanvasItem).visible:
				flat.append("burst_particle")
	check(particles == 32 and particle_views.size() == 2, "(e) 14 + 18 spray particles batch into 2 bursts (%d particles, %d bursts)" % [particles, particle_views.size()])
	var bursts := 0
	for v in view.fx_root.get_children():
		if v is FxBurst3D and v.fired:
			bursts += 1
	check(missing.is_empty() and cards.size() >= 14, "(e) %d FX cards face the camera above their ground points (problems: %s)" % [cards.size(), missing])
	check(flat.is_empty(), "(g) no VIEW FX source draws flat in the overlay (%s)" % [flat])
	check(bursts >= 2, "(e) %d particle bursts fired (%d source particles hidden)" % [bursts, particles])
	# (f) the cards render: their screen neighbourhoods change when the FX views are hidden.
	view.fx_root.visible = false
	await _frames(2)
	var bare := await View3DTestKit.capture(self)
	view.fx_root.visible = true
	var px_scale := _screen_scale()
	var drawn := 0
	var dark := []
	for v in cards:
		var c := cam.unproject_position(v.global_position)
		var half_m: float = maxf(0.05, v.card.global_basis.x.length() * 0.35)
		var half_px := maxf(6.0, (cam.unproject_position(v.global_position + cam.global_basis.x * half_m) - c).length())
		var rect := Rect2i(Vector2i((c - Vector2.ONE * half_px) * px_scale), Vector2i(Vector2.ONE * half_px * 2.0 * px_scale))
		var ratio := View3DTestKit.diff_ratio(img, bare, rect, 0.06)
		if ratio > 0.08:
			drawn += 1
		else:
			dark.append("%s %.0f%%" % [v.kind, ratio * 100.0])
	check(cards.size() > 0 and drawn >= int(ceil(cards.size() * 0.75)), "(f) %d of %d FX cards visibly render (>= 75%%; faint: %s)" % [drawn, cards.size(), dark])
	for m in hidden_minions:
		if is_instance_valid(m):
			m.visible = true
	_freeze(false)


## W3-POLISH: the camera preset switches to MLBB at runtime (settings change mid-match) and blends there.
func _shot_mlbb() -> void:
	var saved := ViewConfig.preset
	_lane_line_up()
	_aim_camera(Vector2(1400, 270))
	_freeze(true)
	ViewConfig.preset = "mlbb"
	await _frames(2)
	check(view.rig.preset_name == "mlbb" and view.rig.is_blending(), "runtime preset switch to mlbb starts a blend")
	# The wheel spring eases over ~0.6 s (4 m from LoL to MLBB): wait on time, not on a frame count.
	var waited := 0
	while waited < 600 and (view.rig.is_blending() or absf(view.rig.distance() - float(ViewConfig.PRESETS.mlbb.distance)) > 0.01):
		await _frames(1)
		waited += 1
	await _frames(2)
	var cam := view.camera()
	var mp: Dictionary = ViewConfig.PRESETS.mlbb
	check(not view.rig.is_blending() and is_equal_approx(view.rig.pitch(), float(mp.pitch)) and is_equal_approx(cam.fov, float(mp.fov)) and absf(view.rig.distance() - float(mp.distance)) < 0.02, "mlbb pose reached (pitch %.2f, fov %.2f, %.2f m)" % [view.rig.pitch(), cam.fov, view.rig.distance()])
	check(absf(cam.global_rotation_degrees.x + 50.0) < 0.01, "camera pitches 50 degrees down")
	var img := await _capture("69-3d-mlbb.png")
	_pixel_checks(img, "mlbb")
	ViewConfig.preset = saved
	await _frames(2)
	var back := 0
	while back < 600 and view.rig.is_blending():
		await _frames(1)
		back += 1
	await _frames(30)
	check(view.rig.preset_name == saved and not view.rig.is_blending() and is_equal_approx(view.rig.pitch(), float(ViewConfig.camera_preset().pitch)), "preset restored to %s" % saved)
	_freeze(false)


## W3-POLISH: Low quality applied at runtime, then High restored.
func _shot_low() -> void:
	var low: Dictionary = ViewConfig.QUALITY["low"]
	var high: Dictionary = ViewConfig.quality_settings()
	_lane_line_up()
	_aim_camera(Vector2(1400, 270))
	_freeze(true)
	get_viewport().msaa_3d = low.msaa
	view.overlay.configure(low.overlay)
	view.arena.apply_quality(low)
	await _frames(2)
	var arena: WorldBuilder3D = view.arena
	check(not arena.sun.shadow_enabled and not arena.environment.glow_enabled, "low: no sun shadows, no glow")
	check(not arena.snow.visible and is_zero_approx(float(arena._brush_mats[0].get_shader_parameter("sway_m"))), "low: no snow, no brush sway")
	check(view.overlay.size == Vector2i(2048, 1024), "low: 2048x1024 ground overlay (%s)" % view.overlay.size)
	var img := await _capture("70-3d-low.png")
	_pixel_checks(img, "low")
	get_viewport().msaa_3d = high.msaa
	view.overlay.configure(high.overlay)
	arena.apply_quality(high)
	await _frames(2)
	check(arena.sun.shadow_enabled and arena.snow.visible, "high quality restored")
	_freeze(false)


## Puts every champion back on the lane (alive, full HP, no actions) for the polish shots.
func _lane_line_up() -> void:
	var i := 0
	for c in GameState.champions:
		if c.dead:
			game._respawn_champion(c)
		c.is_bot = false
		c.stop_actions()
		_full_hp(c)
		c.global_position = Vector2(1290 + (i % 3) * 60 + (110 if c.team == 1 else 0), 220 + (i % 3) * 60)
		c.facing = Vector2.RIGHT if c.team == 0 else Vector2.LEFT
		i += 1


# --- helpers ---

## The candidate point farthest from every other living unit (for unobstructed body captures).
func _clear_spot(p, candidates: Array) -> Vector2:
	var best: Vector2 = candidates[0]
	var best_d := -1.0
	for c in candidates:
		var d := INF
		for u in GameState.champions + GameState.minions:
			if u != p and is_instance_valid(u) and not u.dead and u.visible:
				d = minf(d, u.world_pos().distance_to(c))
		if d > best_d:
			best_d = d
			best = c
	return best


func _aim_camera(focus: Vector2) -> void:
	GameState.cam_locked = false
	GameState.cam_target = focus
	game.camera.position = focus
	game.camera_shake_offset = Vector2.ZERO


## Freezes the sim and animators so consecutive captures differ only by what the test changes.
func _freeze(on: bool) -> void:
	game.set_process(false)
	GameState.paused = on
	for u in GameState.champions + GameState.minions:
		if is_instance_valid(u) and u.animator != null:
			u.animator.set_process(not on)


func _full_hp(p) -> void:
	p.hp = p.hp_max
	if p.has_method("_sync_bars"):
		p._sync_bars()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(file: String) -> Image:
	await _frames(4)
	# Unbound blink flares are short flashes: none may linger from an earlier shot or the bot loop. They age on
	# real time even while the test is frozen, so wait for them to expire on their own (then check none remain).
	var waited := 0
	while not _flares().is_empty() and waited < 120:
		await _frames(1)
		waited += 1
	var left := _flares()
	check(left.is_empty(), "%s: no blink flare lingers at capture (%d left after %d frames)" % [file, left.size(), waited])
	var img: Image = await View3DTestKit.capture(self)
	if img != null:
		img.save_png(OUT + file)
		print("saved %s %s" % [file, img.get_size()])
	check(img != null, "captured %s" % file)
	return img


## Live unbound flares (FxCard3D.flare) under the view's FX root.
func _flares() -> Array:
	var out: Array = []
	if view == null or view.fx_root == null:
		return out
	for n in view.fx_root.get_children():
		# Match on the kind, not the name: duplicate "Flare_blink" names get an engine-generated prefix.
		if n is FxCard3D and n.kind == "flare" and not n.is_queued_for_deletion():
			out.append(n)
	return out


## Image px per base (1920x1080 canvas) px.
func _screen_scale() -> Vector2:
	var img_size := Vector2(get_viewport().get_texture().get_size())
	var vr := get_viewport().get_visible_rect().size
	return img_size / vr


func _clear_colours() -> Array:
	var out := [RenderingServer.get_default_clear_color()]
	var stack: Array = [view]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is WorldEnvironment and n.environment != null:
			out.append(n.environment.background_color)
		stack.append_array(n.get_children())
	return out


func _pixel_checks(img: Image, tag: String) -> void:
	if img == null:
		check(false, "(a)/(b) %s: no image" % tag)
		return
	var w := img.get_width()
	var h := img.get_height()
	# (a) centre luminance variance
	var sum := 0.0
	var sum2 := 0.0
	var n := 0
	for y in range(int(h * 0.3), int(h * 0.7), 4):
		for x in range(int(w * 0.3), int(w * 0.7), 4):
			var l := img.get_pixel(x, y).get_luminance()
			sum += l
			sum2 += l * l
			n += 1
	var mean := sum / maxf(n, 1)
	var variance := sum2 / maxf(n, 1) - mean * mean
	check(variance >= 0.002, "(a) %s centre luminance variance %.4f >= 0.002" % [tag, variance])
	# (b) corners are not the clear colour
	var clears := _clear_colours()
	var inset := 6
	for c in [Vector2i(inset, inset), Vector2i(w - 1 - inset, inset), Vector2i(w - 1 - inset, h - 1 - inset), Vector2i(inset, h - 1 - inset)]:
		var px := img.get_pixelv(c)
		var void_px := false
		for cc in clears:
			if maxf(maxf(absf(px.r - cc.r), absf(px.g - cc.g)), absf(px.b - cc.b)) < 0.02:
				void_px = true
		check(not void_px, "(b) %s corner %s %s differs from the clear colour" % [tag, c, px])


func _body_rect(p, img: Image) -> Rect2i:
	var s := _screen_scale()
	var r := Rect2()
	var pv = view.view_for(p)
	if pv != null and pv.has_method("screen_rect"):
		r = pv.screen_rect(view.camera())
	if r.size.x < 4.0 or r.size.y < 4.0:
		# Fallback: 56 art px tall card centred on the feet.
		var feet := view.world_to_screen(p.world_pos())
		var head := view.world_to_screen(p.world_pos(), 56.0)
		var hh := feet.y - head.y
		r = Rect2(Vector2(feet.x - hh * 0.35, head.y), Vector2(hh * 0.7, hh))
	var ri := Rect2i(Vector2i(r.position * s), Vector2i(r.size * s))
	return ri.intersection(Rect2i(Vector2i.ZERO, img.get_size()))


func _check_hp_bar(img: Image, p) -> void:
	if img == null or p.hp_bar == null:
		check(false, "(d) hp bar check needs an image and hp_bar")
		return
	var bar: Control = p.hp_bar
	var xf: Transform2D = bar.get_global_transform_with_canvas()
	var centre: Vector2 = xf * (bar.size * 0.5)
	var pix := Vector2i(centre * _screen_scale())
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	var inside := bounds.has_point(pix)
	var want: Color = Constants.TEAM_HP[p.team]
	# Best match over a 9 x 3 grid of the bar fill (centre included): floating combat text is drawn above the
	# bars by design and can drift across the centre pixel while it fades, which made the single-pixel check flaky.
	var got := img.get_pixelv(pix) if inside else Color(0, 0, 0, 0)
	var diff := 9.0
	for fx in range(1, 10):
		for fy in [0.3, 0.5, 0.7]:
			var sp := Vector2i((xf * (bar.size * Vector2(fx / 10.0, fy))) * _screen_scale())
			if not bounds.has_point(sp):
				continue
			var c := img.get_pixelv(sp)
			var d := maxf(maxf(absf(c.r - want.r), absf(c.g - want.g)), absf(c.b - want.b))
			if d < diff:
				diff = d
				got = c
				pix = sp
	check(inside and bar.is_visible_in_tree() and diff <= 0.12, "(d) player hp_bar fill best pixel %s %s within 0.12 of %s (diff %.3f)" % [pix, got, want, diff])
