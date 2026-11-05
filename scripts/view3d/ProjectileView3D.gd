class_name ProjectileView3D
extends Node3D
## Axial missile card, trail and hook chain for a Projectile (W2-PROJ).
## Reads every field live and never relies on Projectile.setup() having run, so LAN replicas (fields set by
## LanSnapshot.reconcile) render exactly like host projectiles. Never writes sim fields.
##
## Layout mirrors Projectile._draw: the view origin is the lifted missile point to3(pos) + U * art_m(lift); the
## card is camera-facing and rotated in the image plane so its local +X follows the on-screen travel direction.
## Every layer is a quad mapped onto a box in the projectile's 2D local px space (+X forward, +Y screen-down),
## sized with ViewMath.art_m(px, FX_SCALE). Layers: Underlay (trail band / Vesper rim), Glow (additive streak and
## hot head, glow_add mode 1), Card (atlas cell or projectile_shape SDF), Core (Vesper core line), Chain (hook
## ribbon), Trail (GPUParticles3D, created lazily).
##
## Readability (final polish): authored missile art is often a 6-10 px tall streak that ends up 2-3 screen px thick
## at the gameplay camera. Axial missiles (kit / missile / Vesper / wind thrust) therefore keep a minimum ON-SCREEN
## size: the card is stretched across its axis up to CARD_MIN_PX (at most CARD_STRETCH_MAX), the Vesper lines widen,
## and the additive Glow layer draws a tapered band plus a glowing head never thinner than GLOW_MIN_PX. All minima
## are converted from screen px to art px through px_per_art (measured at the missile each frame), so they hold at
## every zoom and preset without making near missiles bigger than authored.

const SHAPE_SHADER := preload("res://assets/shaders/view3d/projectile_shape.gdshader")
const GLOW_SHADER := preload("res://assets/shaders/view3d/glow_add.gdshader")
const CHAIN_SHADER := preload("res://assets/shaders/view3d/hook_chain.gdshader")

const SHAPES := {"orb": 0, "arrow": 1, "fireball": 2, "bolt": 3, "ice": 4, "wave": 5, "heart": 6}
const SHAPE_TEXTURE := -1
const SHAPE_LINES := 10
const SHAPE_BOX := 4.4                  # SDF shapes draw into a square of size * 4.4 px
const TURRET_TOP_PX := 110.0            # turret bolt muzzle height (art px)
const TURRET_FALL_PX := 320.0           # ... descending to chest height over this travel distance
const CHAIN_WIDTH_M := 0.06
const CHAIN_DASH_M := 0.3
const TRAIL_AMOUNT := 48
const TRAIL_LIFETIME := 0.35
const TRAIL_SIZE_M := Vector2(0.08, 0.14)
const LAYER_SORT := 0.01                # sorting_offset step: Underlay < Card < Core
## Underlay trail lines taper toward their tail (projectile_shape `taper`): width shrinks to TRAIL_TAPER_MIN and
## alpha fades to 0, so trails read as light streaming off the missile rather than hard-ended rods.
const TRAIL_TAPER := 1.0
const TRAIL_DARK_ALPHA := 0.45          # dark contrast core of the readable trail (was 0.85: read as a rod)
const TRAIL_TINT_ALPHA := 0.7
## Minimum on-screen sizes (screen px at the current camera) for axial missiles. Autos stay a little smaller.
const CARD_MIN_PX := 15.0               # card height across the travel axis
const CARD_STRETCH_MAX := 1.7           # ... but never stretched more than this across its axis
const GLOW_MIN_PX := Vector2(13.0, 9.0)       # glow band thickness (skill, auto)
const HEAD_MIN_PX := Vector2(6.5, 5.0)        # glowing head radius (skill, auto)
const VESPER_CORE_MIN_PX := 5.0         # Vesper core line width
const GLOW_ENERGY := 1.35               # > 1: the head blooms on High (hdr_threshold 1.0)
const GLOW_ALPHA := Vector2(0.85, 0.7)  # glow strength (skill, auto)

var source: Node2D
var host: Node3D
var card: MeshInstance3D
var card_mat: ShaderMaterial
var underlay: MeshInstance3D
var underlay_mat: ShaderMaterial
var core: MeshInstance3D
var core_mat: ShaderMaterial
var glow: MeshInstance3D
var glow_mat: ShaderMaterial
var chain: MeshInstance3D
var chain_mat: ShaderMaterial
var trail: GPUParticles3D = null
var local_t: float = 0.0                # animation clock: max(src.animation_time, locally advanced time)
var mode: String = ""                   # "vesper" | "wind" | "tornado" | "kit" | "missile" | "shape" (diagnostic)
var lift_px: float = 0.0                # art px above the ground point this frame
var screen_rot: float = 0.0             # on-screen travel angle used for the card basis
var px_per_art: float = 0.0             # screen px per art px at the missile this frame (0 = unknown)

var _last_host_t: float = -1.0
var _tex: Texture2D = null
var _trail_color: Color = Color(0, 0, 0, 0)


func _init() -> void:
	name = "ProjectileView3D"
	underlay = _make_layer("Underlay", SHAPE_SHADER, 0.0)
	underlay_mat = underlay.material_override
	underlay_mat.set_shader_parameter("shape", SHAPE_LINES)
	underlay_mat.set_shader_parameter("taper", TRAIL_TAPER)
	glow = _make_layer("Glow", GLOW_SHADER, LAYER_SORT * 0.5)
	glow_mat = glow.material_override
	glow_mat.set_shader_parameter("mode", 1)
	glow_mat.set_shader_parameter("energy", GLOW_ENERGY)
	card = _make_layer("Card", SHAPE_SHADER, LAYER_SORT)
	card_mat = card.material_override
	card_mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
	core = _make_layer("Core", SHAPE_SHADER, LAYER_SORT * 2.0)
	core_mat = core.material_override
	core_mat.set_shader_parameter("shape", SHAPE_LINES)
	chain = _make_layer("Chain", CHAIN_SHADER, -LAYER_SORT)
	chain_mat = chain.material_override
	chain_mat.set_shader_parameter("dash_m", CHAIN_DASH_M)
	for layer in [underlay, glow, core, chain]:
		layer.visible = false


func bind(src: Node2D, h: Node3D) -> void:
	source = src
	host = h
	_last_host_t = -1.0
	local_t = 0.0
	if _source_ok():
		if _readable_source():
			var s: Variant = src
			local_t = float(s.animation_time)
		if not src.tree_exiting.is_connected(_on_source_exiting):
			src.tree_exiting.connect(_on_source_exiting)


func sync(_delta: float) -> void:
	if not _source_ok():
		dispose()
		return
	var cam := _camera()
	if cam == null or not cam.is_inside_tree() or not _readable_source():
		visible = false
		return
	var p: Variant = source
	var t := _clock()
	var up := _card_up()
	var pos: Vector2 = source.global_position
	var travel := Vector2.from_angle(float(p.rotation))
	var tornado := int(p.wind_kind) == 1
	lift_px = 0.0 if tornado else _lift()
	var origin := ViewMath.lifted(pos, lift_px, up)
	_place(origin)
	screen_rot = 0.0 if tornado else ViewMath.screen_angle(cam, origin, travel)
	var cb := ViewMath.card_basis(cam, screen_rot)
	px_per_art = screen_px_per_art(cam, origin)
	_sync_layers(p, t, cb)
	_sync_chain(p, cam, origin)
	_sync_trail(p)
	visible = true


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


## Lift above the ground point in art px: visual_height, or the turret bolt's muzzle-to-chest descent.
func _lift() -> float:
	var p: Variant = source
	if _is_turret_bolt():
		var d := TURRET_FALL_PX
		if is_instance_valid(p.src):
			d = (p.src.world_pos() as Vector2).distance_to(source.global_position)
		return lerpf(TURRET_TOP_PX, ViewConfig.CHEST_PX, clampf(d / TURRET_FALL_PX, 0.0, 1.0))
	return float(p.visual_height)


func _is_turret_bolt() -> bool:
	var p: Variant = source
	if bool(p.is_turret):
		return true
	return str(p.shape) == "bolt" and is_instance_valid(p.src) and str(p.src.kind) == "structure"


## Card / underlay / glow / core layers, in Projectile._draw order (vesper, readable trail, wind, art row, shape).
func _sync_layers(p: Variant, t: float, cb: Basis) -> void:
	var dims: Vector2 = p.visual_dimensions
	if dims.x <= 0.0 or dims.y <= 0.0:
		var w := clampf(float(p.size) * 3.8, 22.0, 42.0)
		dims = Vector2(w, w * 0.58)
	var col: Color = p.color
	var under_lines: Array = []
	var under_dot := Vector4.ZERO
	var under_dot_color := Color.WHITE
	var core_lines: Array = []
	var core_dot := Vector4.ZERO
	var auto: bool = str(p.damage_type) == "auto"
	var vesper := _is_vesper(p)
	var glow_kind := -1                 # -1 none, 0 skill missile, 1 auto attack
	var glow_dims := dims
	var glow_color := col
	if vesper:
		mode = "vesper"
		var condemn: bool = str(p.effect_id) == "vayne_e"
		var vt := Color("ffd889") if condemn else Color("9ee6ff")
		# Lines widen (up to 2.5x) until the core is VESPER_CORE_MIN_PX on screen.
		var lw := clampf(min_art_px(VESPER_CORE_MIN_PX) / 1.8, 1.0, 2.5)
		var tail := -dims.x * 0.85
		under_lines.append([tail, dims.x * 0.32, 5.5 * lw, Color(0.025, 0.055, 0.12, 0.75)])
		under_lines.append([tail, -2.0, 3.5 * lw, Color(vt.r, vt.g, vt.b, 0.55)])
		var id := "vayne_e" if condemn else "vayne_q"
		_set_card_texture(KitEffectArt.sheet(id), KitEffectArt.region(id, int(t * 16.0) % 4), axial_rect(dims), cb)
		core_lines.append([-dims.x * 0.25, dims.x * 0.38, 1.8 * lw, Color("fff4d7") if condemn else Color("effcff")])
		core_dot = Vector4(dims.x * 0.38, 0.0, 1.5 * lw, 1.0)
		glow_kind = 1 if auto and not condemn else 0
		glow_color = vt
	else:
		if not auto and _readable_trail(p):
			var length := clampf(dims.x * 0.85, 18.0, 42.0)
			under_lines.append([-length, 2.0, 4.5, Color(0.015, 0.025, 0.04, TRAIL_DARK_ALPHA)])
			under_lines.append([-length, 2.0, 2.2, Color(col.lightened(0.4), TRAIL_TINT_ALPHA)])
			under_dot = Vector4(2.0, 0.0, 2.0, 1.0)
			under_dot_color = Color("fff4da")
		var wind := int(p.wind_kind)
		if wind >= 0:
			var vs := float(p.visual_scale)
			var frame := int(t * 14.0) % 4
			if wind == 1:
				mode = "tornado"
				_set_card_texture(WindArt.texture, WindArt.frame(1, frame), Rect2(Vector2(-30, -104) * vs, Vector2(60, 104) * vs), cb)
			else:
				mode = "wind"
				glow_dims = Vector2(76, 28) * vs
				_set_card_texture(WindArt.texture, WindArt.frame(0, frame), axial_rect(glow_dims), cb)
				glow_kind = 0
				glow_color = Color(0.8, 0.94, 1.0)
		elif int(p.art_row) >= 0:
			var effect: String = str(p.effect_id)
			if not auto:
				var glow_w := maxf(3.0, dims.y * 0.45)
				under_lines.append([-dims.x * 0.45, dims.x * 0.3, glow_w, Color(col.r, col.g, col.b, 0.45), glow_w * 0.5])
			if KitEffectArt.has_effect(effect):
				mode = "kit"
				_set_card_texture(KitEffectArt.sheet(effect), KitEffectArt.region(effect, int(t * 16.0) % 4), axial_rect(dims), cb)
			else:
				mode = "missile"
				var sheet := SpellArt.missile_sheet(bool(p.expansion_art))
				_set_card_texture(sheet, SpellArt.missile_frame(sheet, int(p.art_row), int(t * 18.0) % 8), axial_rect(dims), cb)
			glow_kind = 1 if auto else 0
		else:
			mode = "shape"
			_set_card_shape(str(p.shape), float(p.size), col, cb)
	_set_lines(underlay, underlay_mat, under_lines, under_dot, under_dot_color, cb)
	_set_lines(core, core_mat, core_lines, core_dot, Color.WHITE, cb)
	_set_glow(glow_kind, glow_color, glow_dims, cb)


## Screen px per art px (FX_SCALE) at a world point, measured along the camera's up axis. 0 when unknown.
static func screen_px_per_art(cam: Camera3D, at: Vector3) -> float:
	if cam == null or not cam.is_inside_tree() or cam.is_position_behind(at):
		return 0.0
	var step := ViewMath.art_m(10.0, ViewConfig.FX_SCALE)
	var a := cam.unproject_position(at)
	var b := cam.unproject_position(at + cam.global_basis.y.normalized() * step)
	return a.distance_to(b) / 10.0


## Art px that cover `screen_px` on screen at this missile (0 when the scale is unknown).
func min_art_px(screen_px: float) -> float:
	return screen_px / px_per_art if px_per_art > 0.0 else 0.0


## Card rect for an axial missile of authored size dims (centred): the full authored length, and a height of at
## least CARD_MIN_PX on screen (stretched across the travel axis by at most CARD_STRETCH_MAX).
func axial_rect(dims: Vector2) -> Rect2:
	var h := maxf(dims.y, minf(min_art_px(CARD_MIN_PX), dims.y * CARD_STRETCH_MAX))
	return Rect2(-dims.x * 0.5, -h * 0.5, dims.x, h)


## Additive glow streak behind an axial missile: a tapered band from the tail to a glowing head near the card's
## front, both kept at a minimum on-screen size (GLOW_MIN_PX / HEAD_MIN_PX). kind -1 hides it.
func _set_glow(kind: int, col: Color, dims: Vector2, cb: Basis) -> void:
	if kind < 0 or px_per_art <= 0.0:
		glow.visible = false
		return
	var half := maxf(dims.y * 0.3, min_art_px(GLOW_MIN_PX[kind]) * 0.5)
	var head_r := maxf(dims.y * 0.2, min_art_px(HEAD_MIN_PX[kind]))
	var head_x := dims.x * 0.22         # just ahead of the missile point (the hit position), inside the art
	var tail_x := -dims.x * (0.5 if kind == 1 else 0.8)
	var pad_y := maxf(half * 1.7, head_r * 2.2)
	var x0 := tail_x - half
	var x1 := head_x + head_r * 2.4
	var rect := Rect2(x0, -pad_y, x1 - x0, pad_y * 2.0)
	glow_mat.set_shader_parameter("box_px", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	glow_mat.set_shader_parameter("streak", Vector4(tail_x, head_x, half, head_r))
	glow_mat.set_shader_parameter("color", glow_rgb(col))
	glow_mat.set_shader_parameter("alpha", GLOW_ALPHA[kind])
	_place_quad(glow, rect, cb)
	glow.visible = true


## Display-space glow colour for a missile colour: greys and whites become a cool white, dark colours are lifted.
static func glow_rgb(col: Color) -> Vector3:
	var c := col
	if c.s < 0.15:
		c = Color(0.85, 0.93, 1.0)
	elif c.v < 0.75:
		c = Color.from_hsv(c.h, minf(c.s, 0.85), 0.85)
	return Vector3(c.r, c.g, c.b)


func _is_vesper(p: Variant) -> bool:
	if p.has_method("is_vesper_bolt"):
		return bool(p.is_vesper_bolt())
	return str(p.effect_id) in ["vayne_auto", "vayne_e"]


func _readable_trail(p: Variant) -> bool:
	if p.has_method("readable_trail"):
		return bool(p.readable_trail())
	return false


func _set_card_texture(tex: Texture2D, region: Rect2, rect_px: Rect2, cb: Basis) -> void:
	if tex == null:
		card.visible = false
		return
	if tex != _tex:
		_tex = tex
		card_mat.set_shader_parameter("tex", tex)
	var size := Vector2(tex.get_size())
	card_mat.set_shader_parameter("shape", SHAPE_TEXTURE)
	card_mat.set_shader_parameter("region_uv", Vector4(region.position.x / size.x, region.position.y / size.y, region.end.x / size.x, region.end.y / size.y))
	_place_quad(card, rect_px, cb)
	card.visible = true


func _set_card_shape(shape: String, size_px: float, col: Color, cb: Basis) -> void:
	var half := size_px * SHAPE_BOX * 0.5
	var rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	card_mat.set_shader_parameter("shape", int(SHAPES.get(shape, 0)))
	card_mat.set_shader_parameter("color", col)
	card_mat.set_shader_parameter("size_px", size_px)
	card_mat.set_shader_parameter("box_px", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_place_quad(card, rect, cb)
	card.visible = true


## lines: [[x0, x1, width, Color, softness_px = 0], ...] along the local X axis at y = 0; dot: (x, y, radius, enabled).
func _set_lines(layer: MeshInstance3D, mat: ShaderMaterial, lines: Array, dot: Vector4, dot_color: Color, cb: Basis) -> void:
	if lines.is_empty() and dot.w <= 0.0:
		layer.visible = false
		return
	var x0 := INF
	var x1 := -INF
	var half_h := 0.0
	var packed: Array = []
	var colors: Array = []
	for l in lines:
		x0 = minf(x0, float(l[0]))
		x1 = maxf(x1, float(l[1]))
		half_h = maxf(half_h, float(l[2]) * 0.5)
		packed.append(Vector4(float(l[0]), float(l[1]), float(l[2]), float(l[4]) if l.size() > 4 else 0.0))
		colors.append(l[3])
	if dot.w > 0.0:
		x0 = minf(x0, dot.x - dot.z)
		x1 = maxf(x1, dot.x + dot.z)
		half_h = maxf(half_h, dot.z)
	while packed.size() < 4:
		packed.append(Vector4.ZERO)
		colors.append(Color(0, 0, 0, 0))
	var pad := 2.0
	var rect := Rect2(x0 - pad, -half_h - pad, (x1 - x0) + pad * 2.0, (half_h + pad) * 2.0)
	mat.set_shader_parameter("line_count", lines.size())
	mat.set_shader_parameter("lines", PackedVector4Array(packed))
	mat.set_shader_parameter("line_colors", PackedColorArray(colors))
	mat.set_shader_parameter("head_dot", Vector4(dot.x, dot.y, dot.z if dot.w > 0.0 else 0.0, 0.0))
	mat.set_shader_parameter("head_dot_color", dot_color)
	mat.set_shader_parameter("box_px", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_place_quad(layer, rect, cb)
	layer.visible = true


## Places a unit quad over a 2D-local px rect in the card frame (local +Y is 2D -y).
func _place_quad(layer: MeshInstance3D, rect_px: Rect2, cb: Basis) -> void:
	var c := rect_px.get_center()
	var w := maxf(ViewMath.art_m(rect_px.size.x, ViewConfig.FX_SCALE), 0.0001)
	var h := maxf(ViewMath.art_m(rect_px.size.y, ViewConfig.FX_SCALE), 0.0001)
	var bx := cb.x.normalized()
	var by := cb.y.normalized()
	var offset := bx * ViewMath.art_m(c.x, ViewConfig.FX_SCALE) - by * ViewMath.art_m(c.y, ViewConfig.FX_SCALE)
	layer.transform = Transform3D(Basis(bx * w, by * h, cb.z.normalized()), offset)


## Hook chain: caster chest (visual_height above its feet) to the card, hidden when the caster is brush-hidden.
func _sync_chain(p: Variant, cam: Camera3D, origin: Vector3) -> void:
	var caster: Variant = p.src
	var show := bool(p.hook_chain) and is_instance_valid(caster)
	if show:
		show = BrushVision.visible_to(caster, _local_team())
	if not show:
		chain.visible = false
		return
	var a := ViewMath.lifted(caster.world_pos(), float(p.visual_height), _card_up())
	var axis := origin - a
	var length := axis.length()
	if length < 0.01:
		chain.visible = false
		return
	var across := axis.cross(cam.global_basis.z)
	if across.length_squared() < 0.000001:
		across = axis.cross(Vector3.UP)
	across = across.normalized()
	var normal := axis.normalized().cross(across).normalized()
	chain.transform = Transform3D(Basis(axis, across * CHAIN_WIDTH_M, normal), (a + origin) * 0.5 - origin)
	chain_mat.set_shader_parameter("length_m", length)
	chain.visible = true


## Trail particles on every peer (replaces the host-only spawn_trail puffs in 3D).
func _sync_trail(p: Variant) -> void:
	var want := bool(p.trail) or bool(p.is_ult)
	if not want:
		if trail != null:
			trail.emitting = false
		return
	if trail == null:
		trail = _make_trail()
		add_child(trail)
	var col: Color = p.color
	if col != _trail_color:
		_trail_color = col
		(trail.process_material as ParticleProcessMaterial).color = Color(col.r, col.g, col.b, 0.5)
	trail.emitting = true


func _make_trail() -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "Trail"
	gp.amount = TRAIL_AMOUNT
	gp.lifetime = TRAIL_LIFETIME
	gp.local_coords = false
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3.ZERO
	pm.scale_min = TRAIL_SIZE_M.x
	pm.scale_max = TRAIL_SIZE_M.y
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.5))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = shrink
	pm.scale_curve = scale_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	gp.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = _soft_dot()
	quad.material = mat
	gp.draw_pass_1 = quad
	return gp


static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex


## t = max(src.animation_time, local_t); local_t advances with the host clock (frozen while paused), so 30 Hz
## LAN replicas animate smoothly between snapshots.
func _clock() -> float:
	var p: Variant = source
	var ht := -1.0
	if host != null and is_instance_valid(host) and host.has_method("anim_time"):
		ht = float(host.anim_time())
	if ht >= 0.0 and _last_host_t >= 0.0:
		local_t += maxf(ht - _last_host_t, 0.0)
	_last_host_t = ht
	local_t = maxf(local_t, float(p.animation_time))
	return local_t


func _place(origin: Vector3) -> void:
	if is_inside_tree():
		global_position = origin
	else:
		position = origin


func _make_layer(layer_name: String, shader: Shader, sort: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = layer_name
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = sort
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("bias_m", ViewConfig.FX_RAY_BIAS_M)
	mi.material_override = mat
	add_child(mi)
	return mi


func _source_ok() -> bool:
	return source != null and is_instance_valid(source) and not source.is_queued_for_deletion()


## True when the source carries the Projectile presentation fields (anything else stays hidden, never errors).
func _readable_source() -> bool:
	return "visual_height" in source and "animation_time" in source and "wind_kind" in source


func _camera() -> Camera3D:
	if host != null and is_instance_valid(host) and host.has_method("camera"):
		return host.camera()
	return null


func _card_up() -> Vector3:
	if host != null and is_instance_valid(host) and host.has_method("card_up"):
		return host.card_up()
	return Vector3.UP


func _local_team() -> int:
	if host != null and is_instance_valid(host) and host.has_method("local_team"):
		return int(host.local_team())
	return 0


func _on_source_exiting() -> void:
	# tree_exiting also fires on a plain reparent; only a real removal frees the view.
	if not _source_ok():
		dispose()
	else:
		_check_source.call_deferred()


func _check_source() -> void:
	if not _source_ok() or not source.is_inside_tree():
		dispose()
