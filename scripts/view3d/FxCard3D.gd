class_name FxCard3D
extends Node3D
## Camera-facing atlas burst card for upright FX (W2-VFX). Frame and alpha logic is copied from the 2D source
## scripts and read live every sync; sizes are 2D px x FX_SCALE; cards face the camera via ViewMath.card_basis
## and are pulled FX_RAY_BIAS_M toward the camera in the fx_card shaders. Never writes sim fields.
##
## Kinds: spell_burst (SpellBurst), wind_burst (WindBurst), hero_impact (HeroImpact), impact (Main._ImpactFx),
## minion_hit (MinionHit) and the unbound "flare" (FxCard3D.flare, a 0.3 s additive flash used by UnitExtras3D).
## Bound cards are synced by the host (View3D step 6) and free when their source leaves the tree; flares drive
## themselves from _process and free after FLARE_LIFE.
##
## Readability (W2 fix): hit bursts sit in front of the body they hit, so spell_burst and wind_burst draw
## additively (light over the champion, never an opaque sheet) and are capped at BURST_MAX_PX, about 1.2x the
## hero height, as LoL / MLBB hit FX are. Their last quarter fades out so stacked bursts do not smear.

const MIX_SHADER := preload("res://assets/shaders/view3d/fx_card_mix.gdshader")
const ADD_SHADER := preload("res://assets/shaders/view3d/fx_card_add.gdshader")
const KINDS := ["spell_burst", "wind_burst", "hero_impact", "impact", "minion_hit", "flare"]

const CHEST_LIFT_PX := 27.0           # spell_burst / wind_burst / impact (ViewConfig.CHEST_PX)
const HERO_IMPACT_LIFT_PX := 30.0     # rows 0-2 are spawned at victim + (0, -30): placed at (pos + (0, 30)) lifted 30
const HERO_IMPACT_CORE := 0.24        # white contact core lasts this fraction of the impact's progress
const MINION_HIT_LIFT_PX := 12.0
const MINION_HIT_DURATION := 0.12     # MinionHit.DURATION
const FLARE_LIFE := 0.3
const FLARE_MAX_REAL := 1.0           # real-time cap: a flare frozen by a pause still frees after this many seconds
const FLARE_RADIUS_PX := 22.0         # upright blink flash card (impacts row FLARE_ROW); the flat Main._FlashFx ring still draws on the ground
const FLARE_GROWTH := 0.35            # the card grows to (1 + FLARE_GROWTH) x over the flare
const FLARE_ROW := 2                  # SpellArt.impacts row: white-gold star that opens into a ring of sparks
const BURST_MAX_PX := 1.2 * 56.0      # 1.2 x Constants.CHAMP_ART_HEIGHT: spell / wind burst card cap (art px)
const BURST_ALPHA := 0.7              # additive gain of spell bursts
const BURST_FADE_FROM := 0.75         # bursts fade out over the last quarter of their life
const X_TEX_SIZE := 32

static var _quad: QuadMesh
static var _glow_tex: Texture2D
static var _x_tex: Texture2D

var source: Node
var host: Node3D
var kind: String = ""
var card: MeshInstance3D               # main atlas card
var core: MeshInstance3D               # hero_impact white contact core (rows 0-2 only)
var card_mat: ShaderMaterial
var core_mat: ShaderMaterial
var additive: bool = false
var flare_color: Color = Color.WHITE
var flare_lift_px: float = 0.0
var flare_at: Vector2 = Vector2.ZERO
var _self_driven: bool = false
var _elapsed: float = 0.0
var _sim_t0: float = 0.0               # GameState.time when a flare was spawned (it also ages with the sim clock)
var _real_age: float = 0.0             # real seconds since a flare was spawned, paused or not


func _init() -> void:
	name = "FxCard3D"
	top_level = true
	card = _make_quad("Card")
	add_child(card)
	_configure_blend(false)


func bind(src: Node, h: Node3D, k: String) -> void:
	source = src
	host = h
	kind = k
	_configure_blend((kind == "hero_impact" and _row() != 3) or kind in ["flare", "spell_burst", "wind_burst"])
	if src != null and is_instance_valid(src) and not src.tree_exiting.is_connected(dispose):
		src.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)


func sync(_delta: float) -> void:
	if _self_driven:
		return
	if not _source_ok():
		dispose()
		return
	var cam := _camera()
	if cam == null or not cam.is_inside_tree() or not source.is_inside_tree():
		visible = false
		return
	visible = true
	match kind:
		"spell_burst":
			_sync_spell_burst(cam)
		"wind_burst":
			_sync_wind_burst(cam)
		"hero_impact":
			_sync_hero_impact(cam)
		"impact":
			_sync_impact(cam)
		"minion_hit":
			_sync_minion_hit(cam)
		_:
			visible = false


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


## Non-bound additive flash (0.3 s) at a sim point, e.g. blink start/end. k is a label only ("blink", ...).
static func flare(h: Node3D, at: Vector2, k: String, color: Color, lift_px: float = 0.0) -> void:
	if h == null or not is_instance_valid(h) or not h.has_method("add_fx"):
		return
	var f := FxCard3D.new()
	f.host = h
	f.kind = "flare"
	f.name = "Flare_" + k
	f.flare_at = at
	f.flare_color = color
	f.flare_lift_px = lift_px
	f._self_driven = true
	f._sim_t0 = GameState.time
	f._configure_blend(true)
	h.add_fx(f)
	f._sync_flare()


func _process(delta: float) -> void:
	if not _self_driven:
		return
	_real_age += delta
	if not GameState.paused:
		_elapsed += delta
	# A sim that steps faster than the render clock (batched test loops, catch-up frames) ages the flare too,
	# so a flash never outlives the 0.3 s of game time it marks.
	var sim_age := GameState.time - _sim_t0
	if sim_age > _elapsed:
		_elapsed = sim_age
	# The flash holds its frame through a short pause, but never outlives FLARE_MAX_REAL s of real time: a pause
	# (menu, frozen capture) cannot leave a stale flare on screen.
	if _elapsed >= FLARE_LIFE or _real_age >= FLARE_MAX_REAL:
		dispose()
		return
	_sync_flare()


# --- kinds ---

func _sync_spell_burst(cam: Camera3D) -> void:
	var duration := maxf(float(_field("duration", 0.45)), 0.001)
	var elapsed := float(_field("elapsed", 0.0))
	var radius := float(_field("radius", 40.0))
	var tex: Texture2D = SpellArt.impacts
	var frame := mini(7, int(elapsed / duration * 8.0))
	var region := SpellArt.frame(tex, _row(), frame)
	var side := burst_side_px(radius)
	_draw_card(card, card_mat, tex, region, cam, _lifted(_pos(), CHEST_LIFT_PX), 0.0, Vector2.ONE * side, Color(1, 1, 1, BURST_ALPHA * burst_fade(elapsed / duration)))


func _sync_wind_burst(cam: Camera3D) -> void:
	var duration := maxf(float(_field("duration", 0.3)), 0.001)
	var elapsed := float(_field("elapsed", 0.0))
	var radius := float(_field("radius", 50.0))
	var region := WindArt.frame(_row(), mini(3, int(elapsed / duration * 4.0)))
	var a := (1.0 - elapsed / duration * 0.4) * burst_fade(elapsed / duration)
	_draw_card(card, card_mat, WindArt.texture, region, cam, _lifted(_pos(), CHEST_LIFT_PX), 0.0, Vector2.ONE * burst_side_px(radius), Color(1, 1, 1, a))


func _sync_hero_impact(cam: Camera3D) -> void:
	var row := _row()
	if additive != (row != 3):
		_configure_blend(row != 3)
	var duration := maxf(float(_field("duration", 0.26)), 0.001)
	var progress := clampf(float(_field("elapsed", 0.0)) / duration, 0.0, 1.0)
	var frame := mini(3, int(progress * 4.0))
	var scale_factor := lerpf(0.96, 1.04, progress) if row == 3 else lerpf(0.9, 1.05, progress)
	var r := float(_field("radius", 20.0)) * scale_factor
	var fade := 1.0 - smoothstep(0.65, 1.0, progress)
	var tex := CombatFeedbackArt.impact_texture()
	var region := CombatFeedbackArt.frame(tex, row, frame, 4)
	if row == 3:
		# Soul flame: bottom-anchored at the victim's feet, Rect(-.7r, -2.2r, 1.4r, 2.2r), never rotated.
		_draw_card(card, card_mat, tex, region, cam, _lifted(_pos(), r * 1.1), 0.0, Vector2(r * 1.4, r * 2.2), Color(1, 1, 1, fade * 0.85))
		if core != null:
			core.visible = false
		return
	var hit := _lifted(_pos() + Vector2(0.0, HERO_IMPACT_LIFT_PX), HERO_IMPACT_LIFT_PX)
	var angle := float(_field("angle", 0.0))
	var rot := ViewMath.screen_angle(cam, hit, Vector2.from_angle(angle))
	_draw_card(card, card_mat, tex, region, cam, hit, rot, Vector2.ONE * r * 2.0, Color(1, 1, 1, fade))
	# A very short white contact core keeps the hit readable over spell pools (HeroImpact._draw).
	if progress < HERO_IMPACT_CORE:
		if core == null:
			core = _make_quad("Core")
			core_mat = _material(true)
			core.material_override = core_mat
			add_child(core)
		var core_r := lerpf(3.0, 1.0, progress / HERO_IMPACT_CORE)
		var a := (1.0 - progress / HERO_IMPACT_CORE) * 0.8
		var glow := glow_texture()
		_draw_card(core, core_mat, glow, Rect2(Vector2.ZERO, glow.get_size()), cam, hit, 0.0, Vector2.ONE * core_r * 4.0, Color(1, 1, 0.9, a))
	elif core != null:
		core.visible = false


func _sync_impact(cam: Camera3D) -> void:
	var life := maxf(float(_field("life", 0.2)), 0.001)
	var elapsed := float(_field("elapsed", 0.0))
	var start_sz := float(_field("start_sz", 12.0))
	var alpha: float = (source as CanvasItem).modulate.a if source is CanvasItem else 1.0
	var src_scale: float = (source as Node2D).scale.x if source is Node2D else 1.0
	var tex := CombatFeedbackArt.impact_texture()
	var region := CombatFeedbackArt.frame(tex, 1, mini(3, int(elapsed / life * 4.0)), 4)
	_draw_card(card, card_mat, tex, region, cam, _lifted(_pos(), CHEST_LIFT_PX), 0.0, Vector2.ONE * start_sz * 2.0 * src_scale, Color(1, 1, 1, 0.75 * alpha))


func _sync_minion_hit(cam: Camera3D) -> void:
	var t := clampf(float(_field("elapsed", 0.0)) / MINION_HIT_DURATION, 0.0, 1.0)
	var length := 3.0 + t * 3.0
	var tex := x_texture()
	var side := length * 2.0 * float(X_TEX_SIZE) / float(X_TEX_SIZE - 4)
	_draw_card(card, card_mat, tex, Rect2(Vector2.ZERO, tex.get_size()), cam, _lifted(_pos(), MINION_HIT_LIFT_PX), 0.0, Vector2.ONE * side, Color(1, 1, 1, (1.0 - t) * 0.6))


func _sync_flare() -> void:
	var cam := _camera()
	if cam == null or not cam.is_inside_tree():
		visible = false
		return
	visible = true
	var t := clampf(_elapsed / FLARE_LIFE, 0.0, 1.0)
	var r := FLARE_RADIUS_PX * (1.0 + t * FLARE_GROWTH)
	var c := flare_color
	# Blink art: the impacts row FLARE_ROW star opening into a spark ring over the flare's life (additive).
	var tex: Texture2D = SpellArt.impacts
	var region := SpellArt.frame(tex, FLARE_ROW, mini(7, int(t * 8.0)))
	_draw_card(card, card_mat, tex, region, cam, _lifted(flare_at, flare_lift_px), 0.0, Vector2.ONE * r * 2.0, Color(c.r, c.g, c.b, (1.0 - t * 0.6) * 0.9 * c.a))


# --- helpers ---

## Card side (art px) of a spell / wind burst of the given 2D radius: 2 * radius, capped at BURST_MAX_PX.
static func burst_side_px(radius: float) -> float:
	return minf(maxf(radius, 0.0) * 2.0, BURST_MAX_PX)


## Alpha multiplier of a burst at progress p (0..1): full, then fading out over the last quarter.
static func burst_fade(p: float) -> float:
	return 1.0 - smoothstep(BURST_FADE_FROM, 1.0, clampf(p, 0.0, 1.0))


## Places one quad: camera-facing, rotated in the image plane by rot, size in 2D px (x FX_SCALE), tinted.
func _draw_card(mesh: MeshInstance3D, mat: ShaderMaterial, tex: Texture2D, region: Rect2, cam: Camera3D, centre: Vector3, rot: float, size_px: Vector2, tint: Color) -> void:
	mesh.visible = tint.a > 0.001 and size_px.x > 0.0 and size_px.y > 0.0
	if not mesh.visible:
		return
	var b := ViewMath.card_basis(cam, rot)
	var w := maxf(ViewMath.art_m(size_px.x, ViewConfig.FX_SCALE), 0.001)
	var h := maxf(ViewMath.art_m(size_px.y, ViewConfig.FX_SCALE), 0.001)
	position = centre
	mesh.transform = Transform3D(Basis(b.x * w, b.y * h, b.z), Vector3.ZERO)
	if mat.get_shader_parameter("tex") != tex:
		mat.set_shader_parameter("tex", tex)
	var ts := tex.get_size()
	if ts.x > 0.0 and ts.y > 0.0:
		mat.set_shader_parameter("region_uv", Vector4(region.position.x / ts.x, region.position.y / ts.y, region.end.x / ts.x, region.end.y / ts.y))
	mat.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, tint.a))


func _configure_blend(add: bool) -> void:
	additive = add
	card_mat = _material(add)
	card.material_override = card_mat


static func _material(add: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ADD_SHADER if add else MIX_SHADER
	mat.set_shader_parameter("bias_m", ViewConfig.FX_RAY_BIAS_M)
	mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
	return mat


static func _make_quad(quad_name: String) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.name = quad_name
	m.mesh = _quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _lifted(p: Vector2, lift_px: float) -> Vector3:
	return ViewMath.to3(p) + _card_up() * ViewMath.art_m(lift_px, ViewConfig.FX_SCALE)


func _pos() -> Vector2:
	if source is Node2D:
		var n := source as Node2D
		return n.global_position if n.is_inside_tree() else n.position
	return Vector2.ZERO


func _row() -> int:
	return int(_field("row", 0))


func _field(field: String, fallback: Variant) -> Variant:
	if source != null and is_instance_valid(source) and field in source:
		return source.get(field)
	return fallback


func _source_ok() -> bool:
	return source != null and is_instance_valid(source) and not source.is_queued_for_deletion()


func _camera() -> Camera3D:
	if host != null and is_instance_valid(host) and host.has_method("camera"):
		return host.camera()
	return null


func _card_up() -> Vector3:
	if host != null and is_instance_valid(host) and host.has_method("card_up"):
		return host.card_up()
	return Vector3.UP


## Soft white radial glow (flares, hero-impact contact core). Built once.
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow_tex = t
	return _glow_tex


## The MinionHit X mark (two crossed anti-aliased strokes in the 2D colours), generated once at runtime.
static func x_texture() -> Texture2D:
	if _x_tex == null:
		var img := Image.create(X_TEX_SIZE, X_TEX_SIZE, false, Image.FORMAT_RGBA8)
		var ca := Color(0.9, 0.83, 0.65, 1.0)
		var cb := Color(1.0, 0.94, 0.8, 0.7)
		var lo := 1.0
		var hi := float(X_TEX_SIZE) - 1.0
		for y in X_TEX_SIZE:
			for x in X_TEX_SIZE:
				var p := Vector2(x + 0.5, y + 0.5)
				var c := Color(0, 0, 0, 0)
				if p.x >= lo and p.x <= hi and p.y >= lo and p.y <= hi:
					# "\" stroke (top-left to bottom-right) and "/" stroke (bottom-left to top-right).
					var d1 := absf(p.x - p.y) / sqrt(2.0)
					var d2 := absf(p.x + p.y - float(X_TEX_SIZE)) / sqrt(2.0)
					var a1 := clampf(1.9 - d1, 0.0, 1.0) * ca.a
					var a2 := clampf(1.5 - d2, 0.0, 1.0) * cb.a
					if a1 >= a2 and a1 > 0.0:
						c = Color(ca.r, ca.g, ca.b, a1)
					elif a2 > 0.0:
						c = Color(cb.r, cb.g, cb.b, a2)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_x_tex = ImageTexture.create_from_image(img)
	return _x_tex
