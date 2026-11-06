class_name StructureView3D
extends UnitView3D
## Turret / inhibitor / nexus card with plinth, glow and death rubble (W1-STRUCT).
## Reads Structure sim state only (global_position, art_rect, tower_texture, team, type, dead, visible,
## modulate); never writes it. Time comes from host.anim_time(), so the view freezes while paused.
##
## Grounding: the sim point is the ground centre of the stone base painted into the art (ViewMath.STRUCTURE_FOOTPRINT). The
## card stands on the deck at the base's front tip, in front of the sim point, leaning back with the camera, so the
## base's centre row lands exactly on the sim point on screen. While the structure stands, the painted base is the
## foundation: the plinth (the ruin's foundation) only shows once the card dissolves. A soft contact shadow and a
## shaded lower edge blend the art into the deck.

const CARD_SHADER := preload("res://assets/shaders/view3d/unit_card.gdshader")
const DISSOLVE_OUT_S := 0.8
const DISSOLVE_IN_S := 0.5
const PLINTH_H_M := 0.12          # tallest plinth (nexus); each type is a little lower (no coplanar tops)
const PLINTH_HEIGHTS := {"turret": 0.1, "nexus_turret": 0.085, "inhibitor": 0.11, "nexus": 0.12}
const PLINTH_FOOTPRINT_K := 0.9  # ruin plinth radius vs the painted footprint's smaller half-extent
const KEY_LIGHT := 1.0
const GROUND_SHADE := 0.72
const GROUND_BAND := 0.76
const CONTACT_WIDTH_K := 0.95     # contact shadow half-width vs the painted base half-width
const CONTACT_LIP_PX := 3.0       # contact shadow reaches this far (sim px) in front of the painted base tip
const PLINTH_SEGMENTS := 16
const GLOW_SIZE_M := 0.9           # fallback (unknown type)
## Objective glow (final polish): the crystal halo is sized per type so it reads as a light source around the painted
## crystal, drawn after the cards (render priority) so the card never paints over it, and its colour is lifted
## above 1.0 (GLOW_HDR) so the environment glow blooms it on Medium/High. With glow off (Low) the halo card alone
## still reads as a soft light. WorldBuilder3D adds the hot core and the wide soft halo on top.
const GLOW_SIZES := {"turret": 1.7, "nexus_turret": 1.5, "inhibitor": 1.6, "nexus": 2.4}
const GLOW_HDR := 1.25
const GLOW_ALPHA := 0.36           # pulse centre; +-GLOW_PULSE (2D crystal rate)
const GLOW_PULSE := 0.12
const GLOW_RENDER_PRIORITY := 10   # same as WorldBuilder3D.GLOW_RENDER_PRIORITY
const GLOW_TOWARD_CAMERA_M := 0.3   # keeps the additive glow off the card plane (no z-fight)
const RUBBLE_COUNT := 12
const BURST_COLOR := Color(1.0, 0.7, 0.3)
const BURST_COUNT := 14
const BURST_LIFT_PX := 40.0
## See-through (final fix): an upright card hides a champion standing on or just behind its painted base (spawn
## behind the nexus, at the inhibitor, the brush behind the inner turret). While a shown champion's body is behind
## the card's feet and at least OCCLUDE_MIN_SHARE of its on-screen body rect is covered by this card's rect, the
## card (and its crystal halo) fades to OCCLUDE_ALPHA (eased over OCCLUDE_FADE_S), so the hero stays readable like
## in classic 2D, even behind two overlapping cards (nexus and nexus turret).
const OCCLUDE_ALPHA := 0.32
const OCCLUDE_FADE_S := 0.18
const OCCLUDE_MIN_SHARE := 0.2
const OCCLUDE_FRONT_TOL_M := 0.1   # a champion level with the feet (same sim y) shares the card's depth: the card wins

# Per-view glow texture. A static var in this subclass leaks the whole script graph at exit when
# UnitView3D is loaded first (engine quirk found at the W1 gate), so the 64x64 gradient is per view.
var _glow_texture: Texture2D = null

var body: Sprite3D
var card_mat: ShaderMaterial
var plinth: MeshInstance3D
var shadow_caster: Sprite3D
var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var rubble: MultiMeshInstance3D = null
var rubble_xforms: Array[Transform3D] = []

var _region := Rect2()
var _art_rect := Rect2()
var _type := ""
var _base_pitch: float = -1.0    # pitch the footprint offset was last placed for
var _dissolve: float = 0.0
var _gone: bool = false          # dead: dissolving out (or done), rubble pending or placed
var _last_time: float = 0.0
var _built: bool = false
var _occlude: float = 1.0        # see-through multiplier on the card fade (1 opaque .. OCCLUDE_ALPHA)


func bind(src: Node2D, h: Node3D) -> void:
	super.bind(src, h)
	name = "StructureView_%d" % src.get_instance_id()
	if not src.tree_exiting.is_connected(_on_source_exiting):
		src.tree_exiting.connect(_on_source_exiting, CONNECT_ONE_SHOT)
	_build()
	_last_time = _now()
	# A view created after the structure already died (late registration, LAN) starts as rubble, no burst.
	if bool(src.get("dead")):
		_gone = true
		_dissolve = 1.0
		_spawn_rubble()
	sync(0.0)


func _build() -> void:
	if _built:
		return
	_built = true
	var tex: Texture2D = null
	var atlas = source.get("tower_texture")
	if atlas is AtlasTexture:
		tex = atlas.atlas
		_region = atlas.region
	elif atlas is Texture2D:
		tex = atlas
		_region = Rect2(Vector2.ZERO, atlas.get_size())
	var ar = source.get("art_rect")
	_art_rect = ar if ar is Rect2 and ar.size.x > 0.0 and ar.size.y > 0.0 else Rect2(-50, -120, 100, 140)
	if _region.size.x <= 0.0 or _region.size.y <= 0.0:
		_region = Rect2(0, 0, 1, 1)

	card_mat = ShaderMaterial.new()
	card_mat.shader = CARD_SHADER
	body = Sprite3D.new()
	body.name = "Body"
	body.texture = tex
	body.region_enabled = true
	body.region_rect = _region
	body.centered = false
	body.pixel_size = card_pixel_size(_region, _art_rect)
	body.offset = Vector2(card_offset(_region, _art_rect).x, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.material_override = card_mat
	add_child(body)
	if tex != null:
		card_mat.set_shader_parameter("tex", tex)
		var ts := Vector2(tex.get_size())
		if ts.x > 0.0 and ts.y > 0.0:
			card_mat.set_shader_parameter("atlas_pixel_size", Vector2(1.0, 1.0) / ts)
			card_mat.set_shader_parameter("region_uv", Vector4(_region.position.x / ts.x, _region.position.y / ts.y, _region.end.x / ts.x, _region.end.y / ts.y))
	card_mat.set_shader_parameter("exclusion_count", 0)
	card_mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
	card_mat.set_shader_parameter("key_light", KEY_LIGHT)
	card_mat.set_shader_parameter("ground_shade", GROUND_SHADE)
	card_mat.set_shader_parameter("ground_band", GROUND_BAND)

	_type = str(source.get("type"))
	var plinth_r := plinth_radius(_type, _art_rect, _pitch())
	var plinth_h := plinth_height(_type)
	plinth = MeshInstance3D.new()
	plinth.name = "Plinth"
	var pm := CylinderMesh.new()
	pm.radial_segments = PLINTH_SEGMENTS
	pm.rings = 1
	pm.top_radius = plinth_r * 0.94     # slight chamfer
	pm.bottom_radius = plinth_r
	pm.height = plinth_h
	plinth.mesh = pm
	plinth.material_override = WorldBuilder3D.bare_stone_material()
	plinth.visible = false
	add_child(plinth)

	shadow_caster = make_shadow_card("ShadowCaster")
	shadow_caster.texture = tex
	shadow_caster.region_rect = _region
	shadow_caster.pixel_size = body.pixel_size
	shadow_caster.offset = card_offset(_region, _art_rect)
	if tex != null:
		shadow_caster.material_override.set_shader_parameter("tex", tex)
	add_child(shadow_caster)

	glow = MeshInstance3D.new()
	glow.name = "Glow"
	var gq := QuadMesh.new()
	var gs := glow_size(_type)
	gq.size = Vector2(gs, gs)
	glow.mesh = gq
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = _radial_texture()
	glow_mat.render_priority = GLOW_RENDER_PRIORITY
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	_place_base(_pitch())


## Painted base footprint on the ground in sim px around the sim point: x = half-width, y = half-depth. A card point
## h art px up along U covers the ground point h / sin(pitch) behind the card's foot, and art px become sim px through
## STRUCTURE_SCALE.
static func footprint_px(type: String, art_rect: Rect2, pitch_deg: float) -> Vector2:
	var f: Vector2 = ViewMath.STRUCTURE_FOOTPRINT.get(type, ViewMath.STRUCTURE_FOOTPRINT["turret"])
	var s := maxf(sin(deg_to_rad(pitch_deg)), 0.1)
	return Vector2(f.x * art_rect.size.x, f.y * art_rect.size.y / s) * ViewConfig.STRUCTURE_SCALE


## Ground contact shadow under the painted base (Structure._draw_ground_3d): ellipse radii in sim px around the sim
## point. It hugs the painted footprint and peeks CONTACT_LIP_PX past the front tip.
static func contact_shadow(type: String, art_rect: Rect2, pitch_deg: float) -> Dictionary:
	var fp := footprint_px(type, art_rect, pitch_deg)
	return {"center": Vector2.ZERO, "radii": Vector2(fp.x * CONTACT_WIDTH_K, fp.y + CONTACT_LIP_PX)}


## Ruin plinth radius in metres: inside the painted footprint, so the foundation left after death matches the
## base that stood there.
static func plinth_radius(type: String, art_rect: Rect2, pitch_deg: float) -> float:
	var fp := footprint_px(type, art_rect, pitch_deg)
	return PLINTH_FOOTPRINT_K * minf(fp.x, fp.y) * ViewConfig.S


## How far in front of the sim point the card's foot stands on the deck (metres).
static func card_forward_m(art_rect: Rect2, pitch_deg: float) -> float:
	return maxf(art_rect.end.y, 0.0) * ViewConfig.S * ViewConfig.STRUCTURE_SCALE / maxf(sin(deg_to_rad(pitch_deg)), 0.1)


static func plinth_height(type: String) -> float:
	return float(PLINTH_HEIGHTS.get(type, 0.1))


## Metres per atlas texel so the card is art_rect wide (times STRUCTURE_SCALE).
static func card_pixel_size(region: Rect2, art_rect: Rect2) -> float:
	return ViewConfig.S * ViewConfig.STRUCTURE_SCALE * art_rect.size.x / region.size.x


## Sprite3D (centered = false, y up) offset that puts the art_rect feet point at the node origin.
static func card_offset(region: Rect2, art_rect: Rect2) -> Vector2:
	var u := -art_rect.position.x / art_rect.size.x
	var v := -art_rect.position.y / art_rect.size.y
	return Vector2(-u * region.size.x, -(1.0 - v) * region.size.y)


## Crystal halo quad side (metres) for a structure type.
static func glow_size(type: String) -> float:
	return float(GLOW_SIZES.get(type, GLOW_SIZE_M))


func _radial_texture() -> Texture2D:
	if _glow_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow_texture = t
	return _glow_texture


func sync(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		dispose()
		return
	if not _built:
		return
	var now := _now()
	var dt := maxf(now - _last_time, 0.0)
	_last_time = now
	position = ViewMath.to3(source.global_position)

	var dead := bool(source.get("dead"))
	var shown_alive := source.visible and not dead
	if dead:
		_gone = true
		if _dissolve < 1.0:
			_dissolve = minf(1.0, _dissolve + dt / DISSOLVE_OUT_S)
		if _dissolve >= 1.0 and rubble == null:
			_spawn_rubble()
			FxBurst3D.emit(host, source.global_position, BURST_COLOR, BURST_COUNT, BURST_LIFT_PX)
	elif shown_alive:
		if _gone:
			# Respawn (inhibitor): reverse the dissolve and clear the rubble.
			_gone = false
			_clear_rubble()
		if _dissolve > 0.0:
			_dissolve = maxf(0.0, _dissolve - dt / DISSOLVE_IN_S)

	# Alive but hidden (visible = false without dying): hide the whole view. Dead: keep plinth + rubble.
	# The plinth is the ruin's foundation; while the card stands, its painted base is the foundation.
	visible = dead or source.visible
	body.visible = _dissolve < 1.0
	plinth.visible = _gone or _dissolve > 0.0
	shadow_caster.visible = _dissolve < 0.5 and bool(ViewConfig.quality_settings().shadows)
	glow.visible = shown_alive and _dissolve <= 0.0
	# Real frame delta (not the paused-frozen anim clock), so the card still clears while the game is paused.
	var see_target := OCCLUDE_ALPHA if shown_alive and hides_champion() else 1.0
	if delta > 0.0:
		_occlude = move_toward(_occlude, see_target, delta * (1.0 - OCCLUDE_ALPHA) / OCCLUDE_FADE_S)

	var pitch := _pitch()
	body.rotation = Vector3(-deg_to_rad(pitch), ViewConfig.yaw_rad(), 0.0)
	if pitch != _base_pitch:
		_place_base(pitch)
	_apply_card_params()
	_sync_glow(now)


func _apply_card_params() -> void:
	if card_mat == null:
		return
	card_mat.set_shader_parameter("red_team", false)
	card_mat.set_shader_parameter("hit_whiten", 0.0)
	card_mat.set_shader_parameter("tint", Vector3(1, 1, 1))
	card_mat.set_shader_parameter("fade", clampf(source.modulate.a, 0.0, 1.0) * _occlude)
	card_mat.set_shader_parameter("dissolve", _dissolve)


func _sync_glow(now: float) -> void:
	if not glow.visible:
		return
	var lift := ViewMath.art_m(ViewMath.crystal_lift_px(_art_rect), ViewConfig.STRUCTURE_SCALE)
	var toward := Vector3.ZERO
	var cam := _cam()
	if cam != null:
		toward = cam.global_basis.z.normalized() * GLOW_TOWARD_CAMERA_M
	glow.position = _up() * lift + toward
	var tc: Color = Constants.TEAM_COLOR.get(source.get("team"), Color(1, 1, 1))
	var hot := tc.lerp(Color.WHITE, 0.2)
	# Same pulse rate as the 2D crystal glow (Structure._draw: sin(pulse_t * 2)).
	var a := GLOW_ALPHA + GLOW_PULSE * sin(now * 2.0)
	glow_mat.albedo_color = Color(hot.r * GLOW_HDR, hot.g * GLOW_HDR, hot.b * GLOW_HDR, a * clampf(source.modulate.a, 0.0, 1.0) * _occlude)


func _spawn_rubble() -> void:
	if rubble != null:
		return
	var radius: float = plinth_radius(_type, _art_rect, _pitch())
	var base_h: float = PLINTH_H_M
	if plinth != null and plinth.mesh is CylinderMesh:
		radius = (plinth.mesh as CylinderMesh).bottom_radius
		base_h = (plinth.mesh as CylinderMesh).height
	rubble_xforms = rubble_transforms(_rubble_seed(), radius, base_h)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = rubble_xforms.size()
	for i in range(rubble_xforms.size()):
		mm.set_instance_transform(i, rubble_xforms[i])
	rubble = MultiMeshInstance3D.new()
	rubble.name = "Rubble"
	rubble.multimesh = mm
	rubble.material_override = WorldBuilder3D.bare_stone_material()
	add_child(rubble)


## Deterministic rubble layout: RUBBLE_COUNT unit boxes scaled to 0.15-0.35 m, scattered on the plinth.
static func rubble_transforms(seed_value: int, radius: float, base_h: float = PLINTH_H_M) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(RUBBLE_COUNT):
		var s := rng.randf_range(0.15, 0.35)
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius * 0.85
		var rot := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var b := rot * Basis.from_scale(Vector3(s, s * rng.randf_range(0.6, 1.0), s))
		out.append(Transform3D(b, Vector3(cos(ang) * r, base_h + s * 0.3, sin(ang) * r)))
	return out


func _clear_rubble() -> void:
	if rubble != null:
		remove_child(rubble)
		rubble.queue_free()
		rubble = null
		rubble_xforms = []


func _rubble_seed() -> int:
	var idx := GameState.structures.find(source)
	if idx >= 0:
		return 7919 * (idx + 1)
	return int(absf(source.global_position.x) * 31.0 + absf(source.global_position.y) * 17.0) + 1


func head_height_m() -> float:
	return ViewMath.art_m(-_art_rect.position.y, ViewConfig.STRUCTURE_SCALE)


func screen_rect(cam: Camera3D) -> Rect2:
	if cam == null or source == null or not is_instance_valid(source):
		return Rect2()
	var feet := ViewMath.to3(source.global_position)
	var x := cam.global_basis.x.normalized()
	var up := ViewMath.card_up(cam)
	var k := ViewConfig.S * ViewConfig.STRUCTURE_SCALE
	var out := Rect2()
	var first := true
	for corner in [_art_rect.position, Vector2(_art_rect.end.x, _art_rect.position.y), _art_rect.end, Vector2(_art_rect.position.x, _art_rect.end.y)]:
		var p: Vector3 = feet + x * (corner.x * k) + up * (-corner.y * k)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if first:
			out = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			out = out.expand(sp)
	if first:
		return Rect2()
	return out.grow(6.0)


func is_shown() -> bool:
	return is_visible_in_tree() and body != null and body.visible and not _gone


func set_hover(mode: int) -> void:
	if card_mat == null:
		return
	var c := Color(0, 0, 0, 0)
	if mode == 1:
		c = Color(1.0, 0.3, 0.25, 1.0)
	elif mode == 2:
		c = Color(0.4, 0.8, 1.0, 1.0)
	card_mat.set_shader_parameter("outline_color", c)


## True when this frame's host occludee list (View3D.frame_occludees) has a champion whose body this card hides:
## the champion's feet are behind (or level with, OCCLUDE_FRONT_TOL_M) the card's feet along the camera's view
## direction and this card's screen rect
## covers at least OCCLUDE_MIN_SHARE of its body rect. False outside View3D._step (no frame data).
func hides_champion() -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var frame_valid = host.get("frame_valid")
	if not (frame_valid is bool) or not frame_valid:
		return false
	var list = host.get("frame_occludees")
	if not (list is Array) or list.is_empty():
		return false
	var cam := _cam()
	if cam == null:
		return false
	var mine := screen_rect(cam)
	if mine.get_area() <= 0.0:
		return false
	var forward := -cam.global_basis.z.normalized()
	var feet := ViewMath.to3(source.global_position)
	for o in list:
		var r: Rect2 = o.rect
		var area := r.get_area()
		if area <= 0.0 or (o.feet - feet).dot(forward) < -OCCLUDE_FRONT_TOL_M or not mine.intersects(r):
			continue
		if mine.intersection(r).get_area() >= OCCLUDE_MIN_SHARE * area:
			return true
	return false


## See-through multiplier currently applied to the card fade (1 opaque .. OCCLUDE_ALPHA); tests and tooling.
func see_through() -> float:
	return _occlude


## Current dissolve amount (0 intact .. 1 gone); read-only helper for tests and tooling.
func dissolve_amount() -> float:
	return _dissolve


func has_rubble() -> bool:
	return rubble != null


func dispose() -> void:
	if source != null and is_instance_valid(source) and source.tree_exiting.is_connected(_on_source_exiting):
		source.tree_exiting.disconnect(_on_source_exiting)
	if not is_queued_for_deletion():
		queue_free()


func _on_source_exiting() -> void:
	# One-shot connection: already being removed by the emitter, so only free the view.
	if not is_queued_for_deletion():
		queue_free()


## The card's foot follows the camera pitch so the base stays centred on the sim point.
func _place_base(pitch: float) -> void:
	_base_pitch = pitch
	body.position = Basis(Vector3.UP, ViewConfig.yaw_rad()) * Vector3(0.0, 0.0, card_forward_m(_art_rect, pitch))
	if plinth != null:
		plinth.position = Vector3(0.0, plinth_height(_type) * 0.5, 0.0)


func _pitch() -> float:
	if host != null and is_instance_valid(host) and host.has_method("pitch_deg"):
		return float(host.pitch_deg())
	return float(ViewConfig.camera_preset().pitch)


func _now() -> float:
	if host != null and is_instance_valid(host) and host.has_method("anim_time"):
		return float(host.anim_time())
	return 0.0


func _cam() -> Camera3D:
	if host != null and is_instance_valid(host) and host.has_method("camera"):
		var c = host.camera()
		if c != null and c.is_inside_tree():
			return c
	return null


func _up() -> Vector3:
	var c := _cam()
	if c != null:
		return ViewMath.card_up(c)
	var p := deg_to_rad(float(ViewConfig.camera_preset().pitch))
	return Basis(Vector3.UP, ViewConfig.yaw_rad()) * Vector3(0.0, cos(p), -sin(p))
