extends Node
## W2-VFX: VfxRegistry, FxCard3D and FxBurst3D in a real 3D match (headless; "-- --view3d" or HOWLING_VIEW=3d).
## - classify returns the POLICY_TABLE value for every listed class and inner fx_kind;
## - a scan of every node under world_root during 600 bot frames finds no node with an unknown policy;
## - each spawn_* produces a view (VIEW and BOTH), HIDE sources are invisible, FLAT sources stay visible;
## - card placement (chest lift, hero-impact offsets, soul flame bottom anchor, camera facing) and burst batching;
## - views free after their source lifetime.

const BOT_FRAMES := 600
const BOT_DT := 1.0 / 60.0
const EPS := 0.002

var failures = 0
var checks = 0
var game: Node2D
var view: View3D
var inner: Dictionary = {}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	game = View3DTestKit.start_3d_match(self, "ashe")
	view = game.view3d
	check(view != null and view.is_active(), "3D match has an active View3D")
	if view == null or not view.is_active():
		_finish()
		return
	inner = (game.get_script() as GDScript).get_script_constant_map()
	await get_tree().process_frame
	game._update_camera(1.0)
	view.sync_now()
	_test_table()
	_test_classify()
	await _test_bot_scan()
	await _test_spawns()
	await _test_static_helpers()
	_finish()


func _finish() -> void:
	print("VFX COVERAGE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- classify ---

func _test_table() -> void:
	var P := VfxRegistry.Policy
	var want := {
		"res://scripts/SpellBurst.gd": P.VIEW, "res://scripts/WindBurst.gd": P.VIEW, "res://scripts/HeroImpact.gd": P.VIEW,
		"res://scripts/MinionHit.gd": P.VIEW, "res://scripts/Projectile.gd": P.VIEW, "res://scripts/Beam.gd": P.VIEW,
		"res://scripts/AoE.gd": P.BOTH, "res://scripts/MeleeStrike.gd": P.FLAT, "res://scripts/Champion.gd": P.VIEW,
		"res://scripts/Minion.gd": P.VIEW, "res://scripts/Structure.gd": P.VIEW, "res://scripts/AnimatedCorpse.gd": P.HIDE,
		"res://scripts/FloatingText.gd": P.HIDE, "res://scripts/MapRenderer.gd": P.HIDE, "res://scripts/SkillAimer.gd": P.FLAT,
		"impact": P.VIEW, "burst_particle": P.VIEW, "puff": P.FLAT, "target_ring": P.FLAT, "levelup_ring": P.FLAT,
		"flash": P.FLAT, "reticles": P.FLAT,
	}
	for k in want:
		check(VfxRegistry.POLICY_TABLE.get(k, -1) == want[k], "POLICY_TABLE[%s] == %d (plan 4.5)" % [k, want[k]])
	for k in VfxRegistry.POLICY_TABLE:
		if str(k).begins_with("res://"):
			check(ResourceLoader.exists(str(k)), "POLICY_TABLE script %s exists" % k)


func _test_classify() -> void:
	var P := VfxRegistry.Policy
	var cases := [
		[load("res://scripts/SpellBurst.gd").new(), P.VIEW],
		[load("res://scripts/WindBurst.gd").new(), P.VIEW],
		[load("res://scripts/HeroImpact.gd").new(), P.VIEW],
		[load("res://scripts/MinionHit.gd").new(), P.VIEW],
		[load("res://scripts/MeleeStrike.gd").new(), P.FLAT],
		[load("res://scripts/Beam.gd").new(), P.VIEW],
		[game.ProjectileS.new(), P.VIEW],
		[load("res://scripts/FloatingText.gd").new(), P.HIDE],
	]
	for kind in ["_PuffFx", "_ImpactFx", "_TargetRing", "_LevelUpRing", "_FlashFx", "_BurstParticle"]:
		check(inner.has(kind), "Main declares inner class %s" % kind)
		if inner.has(kind):
			var n: Node = inner[kind].new()
			var expect: int = VfxRegistry.POLICY_TABLE.get(str(n.get("fx_kind")), -2)
			cases.append([n, expect])
	for c in cases:
		var n: Node = c[0]
		var label := _label(n)
		check(VfxRegistry.is_known(n), "%s has a table entry" % label)
		check(VfxRegistry.classify(n) == c[1], "classify(%s) == %d (got %d)" % [label, c[1], VfxRegistry.classify(n)])
		n.free()
	var reticles: Node = null
	for n in game.world_root.get_children():
		if "fx_kind" in n and str(n.get("fx_kind")) == "reticles":
			reticles = n
	check(reticles != null and VfxRegistry.classify(reticles) == P.FLAT, "reticle layer classifies FLAT")
	check(VfxRegistry.classify(game.skill_aimer) == P.FLAT, "SkillAimer classifies FLAT")
	check(VfxRegistry.classify(game.map_renderer) == P.HIDE, "MapRenderer classifies HIDE")
	check(VfxRegistry.classify(GameState.champions[0]) == P.VIEW, "Champion classifies VIEW")
	check(VfxRegistry.classify(GameState.structures[0]) == P.VIEW, "Structure classifies VIEW")
	var plain := Node2D.new()
	check(not VfxRegistry.is_known(plain) and VfxRegistry.classify(plain) == P.FLAT, "unknown Node2D classifies FLAT")
	check(VfxRegistry.create_view(plain, view) == null, "unknown Node2D gets no view")
	plain.free()
	# AoE: BOTH exactly when ZoneProp3D.wants it.
	var aoe = game.AoES.new()
	game.world_root.add_child(aoe)
	aoe.setup(GameState.player, Vector2(1300, 270), {"radius": 80, "duration": 0.2})
	var expect_aoe := P.BOTH if ZoneProp3D.wants(aoe) else P.FLAT
	check(VfxRegistry.classify(aoe) == expect_aoe, "AoE classifies %d (ZoneProp3D.wants=%s)" % [expect_aoe, ZoneProp3D.wants(aoe)])
	GameState.aoes.append(aoe)


# --- coverage guard ---

func _test_bot_scan() -> void:
	var p = GameState.player
	p.is_bot = true
	GameState.running = true
	GameState.paused = false
	var unknown := {}
	var seen := {}
	var flat_view_leaks := []
	for i in range(BOT_FRAMES):
		game._process(BOT_DT)
		if i % 6 == 0:
			await get_tree().process_frame
			for n in game.world_root.get_children():
				var key := VfxRegistry.policy_key(n)
				if key == "":
					unknown[_label(n)] = true
				else:
					seen[key] = int(seen.get(key, 0)) + 1
				var pol := view.policy_of(n)
				if pol == VfxRegistry.Policy.VIEW and not (n is Champion or n is Minion or n is Structure) and (n as CanvasItem).visible:
					flat_view_leaks.append(_label(n))
	check(unknown.is_empty(), "600 bot frames: every world_root node has a policy (unknown: %s)" % [unknown.keys()])
	check(flat_view_leaks.is_empty(), "VIEW FX sources never draw flat; units use their own ground gate (%s)" % [flat_view_leaks])
	check(seen.size() >= 6, "bot scan saw %d node kinds: %s" % [seen.size(), seen])
	print("bot scan kinds: ", seen)
	p.is_bot = false
	GameState.running = false


# --- spawn_* funnel ---

func _test_spawns() -> void:
	var c = GameState.player
	if c.dead:
		game._respawn_champion(c)
	var at := Vector2(1320, 270)
	game.spell_hit_times = {}
	game.hero_impact_times = {}
	var before := {}
	for n in game.world_root.get_children():
		before[n.get_instance_id()] = true
	game.spawn_spell_burst(c, at, 40.0)
	game.spawn_hero_impact(at + Vector2(60, -30), 1, 20.0, 0.6)
	game.spawn_hero_impact(at + Vector2(-60, 0), 3, 18.0)
	game.spawn_minion_hit(at + Vector2(0, 40))
	game.spawn_impact(at + Vector2(30, 30), Color.ORANGE, 12.0)
	game.spawn_trail(at + Vector2(-30, 30), Color.CYAN, 5.0)
	game.spawn_melee_strike(c, at + Vector2(20, 0))
	game._spawn_target_marker(at + Vector2(0, -40))
	game.floating_text(at, "TEST", Color.WHITE)
	game._death_burst(at + Vector2(100, 0), Color(0.9, 0.2, 0.2))
	game.spawn_projectile(c, at, Vector2.RIGHT, {"size": 16, "life": 2.0, "speed": 10.0})
	game.spawn_beam(c, Vector2.RIGHT, 200.0, 20.0, 0.0, Color.SKY_BLUE)
	game.spawn_aoe(c, at + Vector2(0, 60), {"radius": 70, "duration": 0.3})
	# Level-up spray as Main.on_level_up builds it (without the draft UI side effects).
	var ring: Node2D = inner._LevelUpRing.new()
	ring.global_position = at
	game.world_root.add_child(ring)
	for i in range(18):
		var bp: Node2D = inner._BurstParticle.new()
		bp.vel = Vector2.from_angle(TAU * i / 18.0) * 120.0
		bp.col = Color(1.0, 0.86, 0.33)
		bp.global_position = at + Vector2(-100, 0)
		game.world_root.add_child(bp)
	var fresh := []
	for n in game.world_root.get_children():
		if not before.has(n.get_instance_id()):
			fresh.append(n)
	view.sync_now()
	var by_key := {}
	for n in fresh:
		var key := VfxRegistry.policy_key(n)
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(n)
	for key in ["res://scripts/SpellBurst.gd", "res://scripts/HeroImpact.gd", "res://scripts/MinionHit.gd", "impact", "puff", "res://scripts/MeleeStrike.gd", "target_ring", "res://scripts/FloatingText.gd", "burst_particle", "res://scripts/Projectile.gd", "res://scripts/Beam.gd", "res://scripts/AoE.gd", "levelup_ring"]:
		check(by_key.has(key), "spawn funnel created a %s node" % key)
	var cards := []
	for n in fresh:
		var pol := view.policy_of(n)
		var v = view.view_for(n)
		var label := _label(n)
		check(pol == VfxRegistry.classify(n) or n is FloatingText, "%s registered with its table policy (%d)" % [label, pol])
		if pol == VfxRegistry.Policy.VIEW or pol == VfxRegistry.Policy.BOTH:
			check(v != null and v is Node3D and v.is_inside_tree(), "%s has a 3D view" % label)
			if pol == VfxRegistry.Policy.VIEW:
				check(not (n as CanvasItem).visible, "VIEW source %s is hidden in the overlay" % label)
			else:
				check((n as CanvasItem).visible, "BOTH source %s stays visible in the overlay" % label)
			if v is FxCard3D:
				cards.append([n, v])
		elif pol == VfxRegistry.Policy.FLAT:
			check(v == null and (n as CanvasItem).visible, "FLAT source %s stays visible with no view" % label)
		elif pol == VfxRegistry.Policy.HIDE:
			if n is FloatingText:
				var ov = view.overhead
				check(ov == null or not ov.has_method("float_for") or ov.float_for(n) != null, "FloatingText is handed to the overhead layer")
			else:
				check(not (n as CanvasItem).visible, "HIDE source %s is invisible" % label)
		else:
			check(false, "%s was not registered by View3D" % label)
	check(not game.map_renderer.visible, "HIDE MapRenderer is invisible")
	_check_cards(cards)
	_check_bursts(by_key.get("burst_particle", []))
	# Lifetimes: cards follow their sources; bursts free LIFETIME + 0.2 s after firing.
	var watched := []
	for pair in cards:
		watched.append(pair[1])
	for n in by_key.get("burst_particle", []):
		var b = view.view_for(n)
		if b != null and not watched.has(b):
			watched.append(b)
	await get_tree().create_timer(1.3).timeout
	await get_tree().process_frame
	var alive := []
	for v in watched:
		if is_instance_valid(v) and not v.is_queued_for_deletion():
			alive.append(v.name)
	check(watched.size() >= 6 and alive.is_empty(), "%d FX views freed after their source lifetime (alive: %s)" % [watched.size(), alive])
	var leftovers := 0
	for v in view.fx_root.get_children():
		if (v is FxCard3D or v is FxBurst3D) and not v.is_queued_for_deletion():
			leftovers += 1
	check(leftovers == 0, "no FxCard3D/FxBurst3D left under Fx after the sources expired (%d)" % leftovers)


func _check_cards(cards: Array) -> void:
	var cam := view.camera()
	var up := view.card_up()
	var kinds := {}
	for pair in cards:
		var src: Node2D = pair[0]
		var card: FxCard3D = pair[1]
		kinds[card.kind] = true
		check(card.top_level and card.get_parent() == view.fx_root, "%s card lives under View3D/Fx" % card.kind)
		var basis := card.card.global_basis
		check(basis.z.normalized().dot(cam.global_basis.z) > 0.999, "%s card faces the camera" % card.kind)
		var want := Vector3.ZERO
		match card.kind:
			"spell_burst", "impact":
				want = ViewMath.to3(src.global_position) + up * ViewMath.art_m(27.0, ViewConfig.FX_SCALE)
				if card.kind == "spell_burst":
					# Hit bursts are light over the body they hit: additive and capped near the hero height.
					check(card.card.material_override.shader == FxCard3D.ADD_SHADER, "spell_burst is additive")
					var side := FxCard3D.burst_side_px(float(src.radius))
					check(side <= FxCard3D.BURST_MAX_PX + 0.001 and absf(card.card.global_basis.x.length() - ViewMath.art_m(side, ViewConfig.FX_SCALE)) < 0.001, "spell_burst card is min(2 r, %.0f) art px wide" % FxCard3D.BURST_MAX_PX)
				else:
					check(card.card.material_override.shader == FxCard3D.MIX_SHADER, "%s uses the mix shader" % card.kind)
			"minion_hit":
				want = ViewMath.to3(src.global_position) + up * ViewMath.art_m(12.0, ViewConfig.FX_SCALE)
			"hero_impact":
				if int(src.row) == 3:
					var r := float(src.radius) * lerpf(0.96, 1.04, clampf(float(src.elapsed) / float(src.duration), 0.0, 1.0))
					want = ViewMath.to3(src.global_position) + up * ViewMath.art_m(r * 1.1, ViewConfig.FX_SCALE)
					var bottom := card.global_position - card.card.global_basis.y * 0.5
					check(absf((bottom - ViewMath.to3(src.global_position)).dot(up)) < 0.01, "soul flame card is bottom-anchored at the feet")
					check(card.card.material_override.shader == FxCard3D.MIX_SHADER, "soul flame uses the mix shader")
				else:
					want = ViewMath.to3(src.global_position + Vector2(0, 30)) + up * ViewMath.art_m(30.0, ViewConfig.FX_SCALE)
					check(card.card.material_override.shader == FxCard3D.ADD_SHADER, "hero impact rows 0-2 are additive")
					var rot := ViewMath.screen_angle(cam, want, Vector2.from_angle(float(src.angle)))
					var bx: Vector3 = card.card.global_basis.x.normalized()
					var expect_x := cam.global_basis.x * cos(rot) - cam.global_basis.y * sin(rot)
					check(bx.dot(expect_x) > 0.999, "hero impact card is rotated by screen_angle(angle)")
					check(card.core != null and card.core.visible, "hero impact shows the white contact core early")
		if want != Vector3.ZERO:
			check(card.global_position.distance_to(want) < EPS, "%s card centre %s == %s" % [card.kind, card.global_position, want])
			var s_card := cam.unproject_position(card.global_position)
			var s_feet := cam.unproject_position(ViewMath.to3(src.global_position))
			check(s_card.y < s_feet.y, "%s card sits above its ground point on screen" % card.kind)
	for k in ["spell_burst", "hero_impact", "minion_hit", "impact"]:
		check(kinds.has(k), "an FxCard3D of kind %s was created" % k)


func _check_bursts(particles: Array) -> void:
	var bursts := {}
	for n in particles:
		var b = view.view_for(n)
		check(b is FxBurst3D, "burst particle maps to an FxBurst3D")
		if b is FxBurst3D:
			bursts[b.get_instance_id()] = b
	check(bursts.size() == 2, "14 death + 18 level-up particles batch into 2 bursts (got %d)" % bursts.size())
	var amounts := []
	for b in bursts.values():
		check(b.fired and b.one_shot and is_equal_approx(b.lifetime, FxBurst3D.LIFETIME), "burst fired one-shot with lifetime 0.7")
		amounts.append(b.amount)
		check(b.process_material is ParticleProcessMaterial and is_equal_approx(b.process_material.initial_velocity_min, 1.8) and is_equal_approx(b.process_material.initial_velocity_max, 3.6), "burst speed 1.8-3.6 m/s")
		check(is_equal_approx(b.process_material.gravity.y, -2.0), "burst gravity -2")
	amounts.sort()
	check(amounts == [14, 18], "burst amounts equal the sibling counts (got %s)" % [amounts])


# --- static helpers (EXTRAS / STRUCT entry points) ---

func _test_static_helpers() -> void:
	var n0 := view.fx_root.get_child_count()
	FxCard3D.flare(view, Vector2(1300, 260), "blink", Color(0.6, 0.9, 1.0), 20.0)
	FxBurst3D.emit(view, Vector2(1300, 260), Color(1, 0.86, 0.33), 18, 30.0)
	var flare: FxCard3D = null
	var burst: FxBurst3D = null
	for v in view.fx_root.get_children():
		if v is FxCard3D and v.kind == "flare":
			flare = v
		elif v is FxBurst3D and v.fired and v.amount == 18:
			burst = v
	check(view.fx_root.get_child_count() == n0 + 2, "flare and emit each add one FX node")
	check(flare != null and flare.card.material_override.shader == FxCard3D.ADD_SHADER and flare.visible, "flare is a visible additive card")
	if flare != null:
		var want := ViewMath.to3(Vector2(1300, 260)) + view.card_up() * ViewMath.art_m(20.0, ViewConfig.FX_SCALE)
		check(flare.global_position.distance_to(want) < EPS, "flare sits at the lifted point")
	check(burst != null and burst.emitting, "emit fires an 18-particle burst")
	if burst != null:
		var want_b := ViewMath.to3(Vector2(1300, 260)) + view.card_up() * ViewMath.art_m(30.0, ViewConfig.FX_SCALE)
		check(burst.global_position.distance_to(want_b) < EPS, "emit places the burst at the lifted point")
	# Paused: clocks freeze.
	GameState.paused = true
	await get_tree().create_timer(0.5).timeout
	check(is_instance_valid(flare) and not flare.is_queued_for_deletion(), "flare does not expire while paused")
	check(is_instance_valid(burst) and burst.speed_scale == 0.0, "burst particles freeze while paused")
	GameState.paused = false
	await get_tree().create_timer(1.2).timeout
	await get_tree().process_frame
	check(not is_instance_valid(flare), "flare frees after 0.3 s")
	check(not is_instance_valid(burst), "emitted burst frees after lifetime + 0.2 s")
	# Unbound hosts are ignored safely.
	FxCard3D.flare(null, Vector2.ZERO, "blink", Color.WHITE)
	FxBurst3D.emit(null, Vector2.ZERO, Color.WHITE, 4)
	check(true, "null hosts are ignored")


func _label(n: Node) -> String:
	if n == null:
		return "<null>"
	if "fx_kind" in n:
		return "%s(%s)" % [n.get_class(), n.get("fx_kind")]
	var s: Script = n.get_script() as Script
	return s.resource_path.get_file() if s != null and s.resource_path != "" else n.get_class()
