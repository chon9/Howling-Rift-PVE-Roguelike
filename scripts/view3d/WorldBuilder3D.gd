class_name WorldBuilder3D
extends Node3D
## Procedural frozen bridge, abyss, walls, bases, brush and lighting (W1-ARENA; W3-POLISH adds motion).
## Pure presentation: reads GameState / BrushVision, never writes sim state. Sim px -> metres via ViewMath.
## W3-POLISH: brush sway (vertex, 1.3 Hz, 0.04 m) and an eased patch fade, snow GPUParticles3D around the
## camera focus (Medium/High), a drifting abyss mist sheet, pulsing fountain rings with bloomed halos, HDR
## crystal cores on living structures (objective glow), ice clusters on the base aprons, a death-cam
## desaturation (Environment adjustments) and a higher sun so unit shadows stay short.
## W3 fix (screenshot review): walls are dressed masonry (stone.gdshader ashlar courses on every wall face,
## coping slabs, pilasters and buttresses, merlons of varied width and height with caps, newel posts on the
## near rail); the abyss piers are tapered stone piers with capitals carrying a viaduct of spandrel arches
## under the bridge and the base aprons; ice uses a faceted gradient shader (ice_crystal.gdshader); the abyss
## spires sit only south of the deck (north ones floated in the sky past the far wall).
## All walkable surfaces are at y = 0; raised geometry stays outside GameState.clamp_walkable, and every far
## (north) wall obeys the clearance rule top_m <= 0.0115 * (110 - y) so leaning cards never lose their heads.

const DECK_RECTS := [
	Rect2(-60, 70, 2920, 400),       # bridge deck plus the base floors between the apron strips
	Rect2(-60, 20, 480, 50), Rect2(-60, 470, 480, 50),        # blue apron strips (north, south)
	Rect2(2380, 20, 480, 50), Rect2(2380, 470, 480, 50),      # red apron strips (north, south)
]
const BRIDGE_X := Vector2(420, 2380)
const SLAB_M := 0.35
const ABYSS_Y := -12.0
const ABYSS_SIZE := Vector2(300, 200)
const CLEARANCE_K := 0.0115
const CLEARANCE_Y := 110.0
const FAR_PARAPET := {"y0": 40.0, "y1": 70.0, "top": 0.42}
const MERLON := {"w": 26.0, "y0": 40.0, "y1": 56.0, "top": 0.62, "step": 60.0}
const NEAR_RAIL := {"y0": 470.0, "y1": 482.0, "top": 0.28, "baluster_step": 40.0}
const APRON_WALL_TOP := 0.95
const END_WALL_TOP := 0.6
const PILLAR_STEP := 300.0
const PILLAR_M := 0.55             # slim piers (0.9 m boxes fanned into screen-filling diagonals)
const PIER_CAP_M := 0.85           # pier capital width (carries the arch springers)
const PIER_CAP_H := 0.32
const ARCH_RISE_M := 1.7           # spandrel arch: crown under the slab, springing this far lower
const ARCH_DEPTH_M := 0.5          # arch wall thickness along z
const ARCH_SEGMENTS := 14
const PILASTER_STEP := 240.0       # far parapet pilasters (sim px)
const BUTTRESS_STEP := 80.0        # base apron wall buttresses (sim px)
const POST_STEP := 200.0           # near rail newel posts (sim px)
const FOUNTAIN_R := 78.0
const FOUNTAIN_H := 0.05
const RING_HDR := 2.0
const FOUNTAIN_PULSE := 0.3        # ring emission swings +-30% around RING_HDR
const FOUNTAIN_PULSE_HZ := 0.5
const HALO_ENERGY := 1.6           # fountain halo colour multiplier (> 1: blooms at hdr_threshold 1.0)
const HALO_SCALE := 1.6            # halo diameter / fountain disc diameter
const CRYSTAL_CORE_M := 0.75       # hot core billboard over each structure crystal
const CRYSTAL_ENERGY := 2.0
## Final polish: a wide soft halo card (glow_add mode 2) around every crystal, so objectives read as light sources
## in both renderers and on Low (no post glow). Per structure type, metres; its energy stays near 1 so only the
## core and the crystal itself cross the bloom threshold.
const CRYSTAL_HALO_M := {"turret": 2.8, "nexus_turret": 2.4, "inhibitor": 2.6, "nexus": 3.8}
const CRYSTAL_HALO_ENERGY := 1.05
const CRYSTAL_HALO_ALPHA := 0.32
const FOUNTAIN_BEACON_M := Vector2(4.4, 3.4)   # standing soft light over each fountain (width, height)
const FOUNTAIN_BEACON_LIFT_M := 1.1
const FOUNTAIN_BEACON_ALPHA := 0.11
const CRYSTAL_BIAS_M := 0.45       # pulled toward the camera past StructureView3D's own glow (0.3 m)
const GLOW_RENDER_PRIORITY := 10
const POOL_FOUNTAIN := Vector2(190.0, 0.3)   # light pool radius (sim px), intensity
const POOL_STRUCTURE := {"turret": Vector2(150.0, 0.6), "nexus_turret": Vector2(130.0, 0.55), "inhibitor": Vector2(140.0, 0.6), "nexus": Vector2(230.0, 0.75)}
const SHAFT_COUNT := 6
const SHAFT_STEP_M := 4.6
const SHAFT_WIDTH_M := 1.5
const SHAFT_LENGTH_M := 13.0
const SHAFT_HEIGHT_M := 3.0
const SHAFT_LEAN_DEG := -24.0
const BRUSH_CARDS := 22
const BRUSH_FADE := 0.45
const BRUSH_TINT := Color(0.78, 0.9, 0.9)
const BRUSH_FADE_RATE := 9.0       # 1/s exponential ease of the patch fade (about 0.3 s to settle)
const SWAY_M := 0.04
const SWAY_HZ := 1.3
const SNOW_COUNT := 300
const SNOW_BOX := Vector3(13.0, 0.4, 9.0)   # half extents (m) of the emission box around the camera focus
const SNOW_HEIGHT_M := 6.5
const MIST_Y := -2.2               # drifting mist sheet between the deck and the abyss floor
const DEATH_SATURATION := 0.35     # death-cam: world saturation while the local player is dead
const DEATH_EASE := 2.5            # 1/s
const ICE_PER_CLUSTER := 3
## Ice clusters on the base aprons, blue side (red mirrors x about WORLD_W): [sim point, height m]. All lie
## outside GameState.clamp_walkable; north ones obey the far-wall clearance rule, south ones stay <= 0.28 m.
const ICE_SPOTS := [
	[Vector2(-30, 34), 0.8], [Vector2(95, 30), 0.7], [Vector2(230, 33), 0.75], [Vector2(345, 30), 0.65],
	[Vector2(-38, 200), 0.85], [Vector2(-34, 345), 0.75], [Vector2(60, 497), 0.27], [Vector2(300, 500), 0.25],
]
const PROP_COUNT := 30
const ICE_SHADER := preload("res://assets/shaders/view3d/ice_crystal.gdshader")
## A high, warm sun over cool ambient: shadows stay short, soft and light, a pool beside the feet rather than a
## second dark figure on the ground, so units and the floor stay readable.
const SUN_ROT := Vector3(-64, ViewConfig.SUN_YAW_DEG, 0)
const SHADOW_OPACITY := 0.5
const SHADOW_BLUR := 3.0
const RIM_ROT := Vector3(-25, 160 + ViewConfig.YAW_DEG, 0)
## Off-lane depth: height fog below the deck so the abyss, piers and props fade into a dark, soft mist
## (the eye stays on the lane, as in LoL / MLBB).
const FOG_HEIGHT_M := -0.6
const FOG_HEIGHT_DENSITY := 0.14

## Lighting per renderer. Forward+ lights in linear space (plan values). Compatibility applies the same
## lights to display-space albedo (probe 2.1 holds for unshaded cards only), which made every lit surface
## ~30% brighter and bluer; its profile is calibrated so lit surfaces match Forward+ (Arena3DVisual parity).
const LIGHT_FORWARD := {
	"sun_energy": 1.6, "sun_color": Color(1.0, 0.83, 0.6),
	"ambient_color": Color(0.5, 0.54, 0.7), "ambient_energy": 0.46,
	"rim_energy": 0.4, "rim_color": Color(0.5, 0.68, 1.0),
	"fog_color": Color(0.06, 0.10, 0.18),
}
const LIGHT_COMPAT := {
	"sun_energy": 0.84, "sun_color": Color(1.0, 0.8, 0.56),
	"ambient_color": Color(0.5, 0.53, 0.64), "ambient_energy": 0.62,
	"rim_energy": 0.2, "rim_color": Color(0.5, 0.68, 1.0),
	# Fog blends in display space here (linear in Forward+), which darkened partly fogged scenery.
	"fog_color": Color(0.085, 0.125, 0.205),
}

static var _stone: Material = null
static var _stone_variants: Dictionary = {}

var ground_material: ShaderMaterial

var environment: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var _profile: Array = []
var _deck_rects: Array = []
var _brush_mats: Array = []
var _brush_fade_mats: Array = []
var _brush_nodes: Array = []
var _brush_points: Array = []   # per patch: PackedVector2Array of card feet (sim px), CPU-side copy
var _brush_patch := -2
var _fountain_mats: Array = []
var _fountain_rings: Array = []      # StandardMaterial3D per fountain (pulsing emission)
var _fountain_halos: Array = []      # glow_add ShaderMaterial per fountain
var _fountain_beacons: Array = []    # glow_add ShaderMaterial per fountain (standing halo)
var _brush_fade_val := PackedFloat32Array()
var snow: GPUParticles3D
var mist_material: ShaderMaterial
var _crystal_root: Node3D
var _crystal_cores: Dictionary = {}  # structure instance id -> {"node", "mat"}
var _ice_points: Array = []          # [{pos: Vector2, r_px, top_m}] CPU copy (MultiMesh is unreadable headless)
var _saturation := 1.0
var _post: CanvasLayer
var _shaft_root: Node3D
var _shaft_mats: Array = []
var _pool_mask := -1
var _quality: Dictionary = {}
var _built := false


func _init() -> void:
	name = "Arena"


func build(overlay: GroundOverlay) -> void:
	if _built:
		return
	_built = true
	_quality = ViewConfig.quality_settings()
	ground_material = _make_ground_material(Vector3(0.93, 0.89, 0.83))
	_build_environment()
	_build_deck()
	_build_slab_and_walls()
	_build_pillars()
	_build_fountains()
	_build_abyss()
	_build_brush()
	_build_props()
	_build_ice()
	_build_mist()
	_build_snow()
	_build_shafts()
	_build_post()
	_crystal_root = Node3D.new()
	_crystal_root.name = "CrystalGlow"
	add_child(_crystal_root)
	if overlay != null:
		overlay.bind_material(ground_material)
	apply_quality(_quality)


func apply_quality(q: Dictionary) -> void:
	_quality = q
	if sun != null:
		sun.shadow_enabled = bool(q.get("shadows", true))
	if environment != null:
		environment.glow_enabled = bool(q.get("glow", true))
	var sway := SWAY_M if bool(q.get("sway", true)) else 0.0
	for m in _brush_mats + _brush_fade_mats:
		m.set_shader_parameter("sway_m", sway)
	if snow != null:
		var on := bool(q.get("snow", true))
		snow.visible = on
		snow.emitting = on
	if _shaft_root != null:
		_shaft_root.visible = bool(q.get("glow", true))


func update(host: Node3D, delta: float) -> void:
	var t := 0.0
	if host != null and host.has_method("anim_time"):
		t = float(host.anim_time())
	var p = GameState.player
	var has_player: bool = p != null and is_instance_valid(p)
	_update_brush(p if has_player else null, t, delta)
	_update_fountains(t)
	if mist_material != null:
		mist_material.set_shader_parameter("mist_time", t)
	_update_snow(host)
	_update_death_cam(has_player and p.get("dead") == true, delta)
	_update_crystals(host, t)
	_update_light_pools()
	_update_shafts(host, t)
	if _post != null:
		_post.visible = bool(_quality.get("hd2d", true))
	# Fountain discs share the deck shader: mirror the overlay binding GroundOverlay keeps on ground_material.
	if ground_material != null:
		var rect = ground_material.get_shader_parameter("overlay_rect")
		var tex = ground_material.get_shader_parameter("overlay_tex")
		for m in _fountain_mats:
			if rect != null:
				m.set_shader_parameter("overlay_rect", rect)
			if tex != null:
				m.set_shader_parameter("overlay_tex", tex)


func wall_profile() -> Array:
	# [{z, top_m}] for every far-wall element (z = metres of its southmost face; y = the same in sim px).
	return _profile.duplicate(true)


static func stone_material() -> Material:
	if _stone == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/view3d/stone.gdshader")
		m.set_shader_parameter("albedo_tex", load("res://assets/environment/rift-lane.png"))
		m.set_shader_parameter("masonry", 1.0)
		_stone = m
	return _stone


## Snow-free stone (structure plinths, rubble): same triplanar paving, no white cap on the top faces.
static func bare_stone_material() -> Material:
	return _stone_variant("bare", 0.0, 0.56)


## Dark snow-free stone for scenery below the deck (abyss rocks): reads as background, not as props.
static func deep_stone_material() -> Material:
	return _stone_variant("deep", 0.0, 0.36)


## Dark snow-free dressed stone for the viaduct (piers and arches): deep_stone tones with ashlar courses.
static func pier_stone_material() -> Material:
	return _stone_variant("pier", 0.0, 0.44, 1.0)


static func _stone_variant(key: String, snow: float, tint: float, masonry: float = 0.0) -> Material:
	if not _stone_variants.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/view3d/stone.gdshader")
		m.set_shader_parameter("albedo_tex", load("res://assets/environment/rift-lane.png"))
		m.set_shader_parameter("snow_amount", snow)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("masonry", masonry)
		if masonry > 0.0:
			# Bigger blocks on the tall piers, read from the gameplay camera 10-25 m away.
			m.set_shader_parameter("block_m", Vector2(0.9, 0.36))
			m.set_shader_parameter("mortar_m", 0.035)
		_stone_variants[key] = m
	return _stone_variants[key]


## Ice material: faceted gradient crystal (ice_crystal.gdshader). Bright on the aprons, dim for abyss spires.
static func ice_material(deep: Color, tip: Color, glow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ICE_SHADER
	m.set_shader_parameter("deep_color", Vector3(deep.r, deep.g, deep.b))
	m.set_shader_parameter("tip_color", Vector3(tip.r, tip.g, tip.b))
	m.set_shader_parameter("glow", glow)
	return m


## Light profile for a rendering method name ("forward_plus", "mobile", "gl_compatibility").
static func light_profile(method: String) -> Dictionary:
	return LIGHT_COMPAT if method == "gl_compatibility" else LIGHT_FORWARD


static func current_light_profile() -> Dictionary:
	return light_profile(RenderingServer.get_current_rendering_method())


## Fade currently applied to brush patch i (1.0 = opaque). Test/diagnostic helper.
func _brush_fade(i: int) -> float:
	if i < 0 or i >= _brush_fade_val.size():
		return 1.0
	return _brush_fade_val[i]


## Current world saturation (1.0 = normal, DEATH_SATURATION while the local player is dead). Test helper.
func death_saturation() -> float:
	return _saturation


## Ice cluster crystals [{pos, r_px, top_m}] (sim px / metres). Test helper.
func ice_points() -> Array:
	return _ice_points.duplicate(true)


## Crystal cores currently shown (one per shown structure glow). Test helper.
func crystal_core_count() -> int:
	var n := 0
	for id in _crystal_cores:
		if _crystal_cores[id].node.visible:
			n += 1
	return n


# --- per-frame polish ---------------------------------------------------------------------------

## Brush: the patch holding the local player eases to BRUSH_FADE (smooth alpha-blended copy while not
## fully opaque); every card sways on the host clock (frozen while paused). The fade eases on the real
## frame time so it still settles while the game is paused.
func _update_brush(p, t: float, delta: float) -> void:
	var patch := -1
	if p != null and p.has_method("world_pos"):
		patch = BrushVision.patch_at(p.world_pos())
	_brush_patch = patch
	var k := 1.0 - exp(-BRUSH_FADE_RATE * maxf(delta, 0.0))
	var sway := bool(_quality.get("sway", true))   # Low: no sway, so no per-frame uniform updates either
	for i in range(_brush_mats.size()):
		var target := BRUSH_FADE if i == patch else 1.0
		var v: float = _brush_fade_val[i]
		if v != target:
			v = lerpf(v, target, k)
			if absf(v - target) < 0.004:
				v = target
			_brush_fade_val[i] = v
			_brush_mats[i].set_shader_parameter("fade", v)
			_brush_fade_mats[i].set_shader_parameter("fade", v)
		# Not fully opaque: the smooth alpha-blended copy (no shadows, no dither). Opaque: alpha-scissor cards.
		var want: Material = _brush_fade_mats[i] if v < 0.999 else _brush_mats[i]
		if _brush_nodes[i].material_override != want:
			_brush_nodes[i].material_override = want
		if sway:
			_brush_mats[i].set_shader_parameter("sway_time", t)
			_brush_fade_mats[i].set_shader_parameter("sway_time", t)


func _update_fountains(t: float) -> void:
	var s := sin(t * TAU * FOUNTAIN_PULSE_HZ)
	for m in _fountain_rings:
		m.emission_energy_multiplier = RING_HDR * (1.0 + FOUNTAIN_PULSE * s)
	for m in _fountain_halos:
		m.set_shader_parameter("alpha", 0.55 + 0.15 * s)
	for m in _fountain_beacons:
		m.set_shader_parameter("alpha", FOUNTAIN_BEACON_ALPHA * (1.0 + 0.25 * s))


## The snow box follows the camera's look-at point on the deck; particles live in world space, so panning
## leaves them behind naturally. Frozen while paused.
func _update_snow(host: Node3D) -> void:
	if snow == null or not snow.visible:
		return
	snow.speed_scale = 0.0 if GameState.paused else 1.0
	if host == null or not host.has_method("camera"):
		return
	var cam: Camera3D = host.camera()
	if cam == null or not cam.is_inside_tree():
		return
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.global_position, -cam.global_basis.z)
	if hit != null:
		var at := (hit as Vector3) + Vector3(0.0, SNOW_HEIGHT_M, 0.0)
		var jump := snow.global_position.distance_to(at) > 12.0
		snow.global_position = at
		if jump:
			# Camera jumped (respawn, recall, first frame): refill the new box at once (preprocess).
			snow.restart()


## Death cam: the world desaturates while the local player is dead (Environment adjustments; the HUD and the
## overhead UI are 2D layers and keep their colours). Eased on the real frame time.
func _update_death_cam(dead: bool, delta: float) -> void:
	if environment == null:
		return
	var target := DEATH_SATURATION if dead else 1.0
	if _saturation == target:
		return
	_saturation = lerpf(_saturation, target, 1.0 - exp(-DEATH_EASE * maxf(delta, 0.0)))
	if absf(_saturation - target) < 0.005:
		_saturation = target
	environment.adjustment_enabled = _saturation < 0.999
	environment.adjustment_saturation = _saturation


## Objective glow: a small HDR core over every shown structure's crystal, so the environment glow blooms it
## (the unshaded card never exceeds 1.0). Placed with StructureView3D's crystal formula
## (U * art_m(-art_rect.y * 0.75)) and hidden whenever the structure view hides its own glow.
func _update_crystals(host: Node3D, t: float) -> void:
	if _crystal_root == null:
		return
	var seen := {}
	var up := Vector3.UP
	if host != null and host.has_method("card_up"):
		up = host.card_up()
	for s in GameState.structures:
		if not is_instance_valid(s) or not s.is_inside_tree():
			continue
		var id: int = s.get_instance_id()
		seen[id] = true
		var e = _crystal_cores.get(id)
		if e == null:
			e = _make_crystal_core(s)
			_crystal_cores[id] = e
		var shown: bool = s.visible and s.get("dead") != true
		var see_through := 1.0   # the structure card's see-through fade (StructureView3D) dims its core and halo too
		if shown and host != null and host.has_method("view_for"):
			var v = host.view_for(s)
			if v != null and "glow" in v and v.glow != null:
				shown = v.glow.visible
			if v != null and v.has_method("see_through"):
				see_through = float(v.see_through())
		e.node.visible = shown
		if not shown:
			continue
		var ar = s.get("art_rect")
		var lift := 2.0
		if ar is Rect2:
			lift = ViewMath.art_m(ViewMath.crystal_lift_px(ar), ViewConfig.STRUCTURE_SCALE)
		e.node.global_position = ViewMath.to3(s.global_position) + up * lift
		var fade := clampf(s.modulate.a, 0.0, 1.0) * see_through
		e.mat.set_shader_parameter("alpha", (0.75 + 0.25 * sin(t * 2.0)) * fade)
		e.halo_mat.set_shader_parameter("alpha", CRYSTAL_HALO_ALPHA * (0.85 + 0.15 * sin(t * 2.0)) * fade)
	for id in _crystal_cores.keys():
		if not seen.has(id):
			var e = _crystal_cores[id]
			if is_instance_valid(e.node):
				e.node.queue_free()
			_crystal_cores.erase(id)


## Coloured light on the deck around fountains and standing crystals. Updated only when a structure falls or returns.
func _update_light_pools() -> void:
	var mask := 0
	for i in range(GameState.structures.size()):
		var s = GameState.structures[i]
		if is_instance_valid(s) and s.get("dead") != true:
			mask |= 1 << i
	if mask == _pool_mask or ground_material == null:
		return
	_pool_mask = mask
	var pools := PackedVector4Array()
	var colors := PackedVector4Array()
	for team in [Constants.BLUE, Constants.RED]:
		var tc: Color = Constants.TEAM_COLOR[team]
		var point: Vector2 = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
		pools.append(Vector4(point.x, point.y, POOL_FOUNTAIN.x, POOL_FOUNTAIN.y))
		colors.append(Vector4(tc.r, tc.g, tc.b, 1.0))
	for i in range(GameState.structures.size()):
		if not (mask & (1 << i)) or pools.size() >= 16:
			continue
		var s = GameState.structures[i]
		var tc: Color = Constants.TEAM_COLOR.get(s.get("team"), Color.WHITE)
		var pool: Vector2 = POOL_STRUCTURE.get(str(s.get("type")), POOL_FOUNTAIN)
		pools.append(Vector4(s.global_position.x, s.global_position.y, pool.x, pool.y))
		colors.append(Vector4(tc.r, tc.g, tc.b, 1.0))
	for m in [ground_material] + _fountain_mats:
		m.set_shader_parameter("pools", pools)
		m.set_shader_parameter("pool_colors", colors)
		m.set_shader_parameter("pool_count", pools.size())


func _build_shafts() -> void:
	_shaft_root = Node3D.new()
	_shaft_root.name = "LightShafts"
	_shaft_root.rotation.y = ViewConfig.yaw_rad()
	add_child(_shaft_root)
	var shader: Shader = load("res://assets/shaders/view3d/light_shaft.gdshader")
	var pitch := deg_to_rad(float(ViewConfig.camera_preset().pitch))
	var lean := Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, deg_to_rad(SHAFT_LEAN_DEG))
	for i in range(SHAFT_COUNT):
		var mesh := MeshInstance3D.new()
		mesh.name = "Shaft%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(SHAFT_WIDTH_M + 0.9 * (i % 3), SHAFT_LENGTH_M)
		mesh.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("phase", float(i) * 1.7)
		mat.render_priority = GLOW_RENDER_PRIORITY - 1
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.basis = lean
		mesh.position = Vector3((float(i) - (SHAFT_COUNT - 1) * 0.5) * SHAFT_STEP_M, SHAFT_HEIGHT_M, 0.0)
		_shaft_root.add_child(mesh)
		_shaft_mats.append(mat)


func _update_shafts(host: Node3D, t: float) -> void:
	if _shaft_root == null or not _shaft_root.visible or host == null or not host.has_method("camera"):
		return
	var cam: Camera3D = host.camera()
	if cam == null or not cam.is_inside_tree():
		return
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.global_position, -cam.global_basis.z)
	if hit != null:
		_shaft_root.global_position = Vector3((hit as Vector3).x, 0.0, (hit as Vector3).z)
	for mat in _shaft_mats:
		mat.set_shader_parameter("shaft_time", t)


## HD-2D finish over the world: above the FXAA layer, below the overhead UI and HUD.
func _build_post() -> void:
	_post = CanvasLayer.new()
	_post.name = "HD2DPost"
	_post.layer = 2
	_post.visible = false
	var rect := ColorRect.new()
	rect.name = "Finish"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fx := ShaderMaterial.new()
	fx.shader = load("res://assets/shaders/view3d/hd2d_post.gdshader")
	rect.material = fx
	_post.add_child(rect)
	add_child(_post)


func _make_crystal_core(s: Node) -> Dictionary:
	var tc: Color = Constants.TEAM_COLOR.get(s.get("team"), Color(1, 1, 1))
	var core := Color(tc.r, tc.g, tc.b).lerp(Color.WHITE, 0.35)
	var m := _glow_material(core, CRYSTAL_ENERGY, true, CRYSTAL_BIAS_M)
	m.set_shader_parameter("falloff", 2.6)
	var mi := MeshInstance3D.new()
	mi.name = "Core%d" % _crystal_root.get_child_count()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * CRYSTAL_CORE_M
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	_crystal_root.add_child(mi)
	# Wide soft halo: a child of the core (freed and hidden with it).
	var hm := _glow_material(Color(tc.r, tc.g, tc.b).lerp(Color.WHITE, 0.1), CRYSTAL_HALO_ENERGY, true, CRYSTAL_BIAS_M)
	hm.set_shader_parameter("mode", 2)
	hm.set_shader_parameter("falloff", 1.7)
	hm.set_shader_parameter("alpha", CRYSTAL_HALO_ALPHA)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var hq := QuadMesh.new()
	hq.size = Vector2.ONE * float(CRYSTAL_HALO_M.get(str(s.get("type")), CRYSTAL_HALO_M["turret"]))
	halo.mesh = hq
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 3.0
	mi.add_child(halo)
	return {"node": mi, "mat": m, "halo_mat": hm}


func _glow_material(color: Color, energy: float, billboard: bool, bias_m: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/view3d/glow_add.gdshader")
	m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("bias_m", bias_m)
	# Drawn after the other transparent cards: the glow writes no depth, so a unit or structure card sorted
	# after it would paint over it. It is still depth-tested against their prepass depth.
	m.render_priority = GLOW_RENDER_PRIORITY
	return m


# --- construction -------------------------------------------------------------------------------

func _make_ground_material(tint: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/view3d/ground_deck.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/environment/rift-lane.png"))
	m.set_shader_parameter("sim_scale", ViewConfig.S)
	m.set_shader_parameter("base_tint", tint)
	m.set_shader_parameter("bridge_x", BRIDGE_X)
	# Transparent until GroundOverlay binds its texture (headless never binds one).
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	m.set_shader_parameter("overlay_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("overlay_rect", Vector4(0, 0, 1, 1))
	return m


func _build_environment() -> void:
	var light := current_light_profile()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.03, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = light.ambient_color
	environment.ambient_light_energy = light.ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_hdr_threshold = 1.0
	# Wider bloom for the HDR sources (crystal cores, fountain rings, missile heads): level 4 adds a soft skirt.
	environment.set_glow_level(3, 0.5)
	environment.fog_enabled = true
	environment.fog_light_color = light.fog_color
	environment.fog_density = 0.012
	environment.fog_height = FOG_HEIGHT_M
	environment.fog_height_density = FOG_HEIGHT_DENSITY
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROT
	sun.light_energy = light.sun_energy
	sun.light_color = light.sun_color
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = SHADOW_BLUR
	sun.shadow_opacity = SHADOW_OPACITY
	add_child(sun)
	rim = DirectionalLight3D.new()
	rim.name = "Rim"
	rim.rotation_degrees = RIM_ROT
	rim.light_energy = light.rim_energy
	rim.light_color = light.rim_color
	rim.shadow_enabled = false
	add_child(rim)


func _build_deck() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in DECK_RECTS:
		_deck_rects.append(r)
		var plane := PlaneMesh.new()
		plane.size = Vector2(r.size.x, r.size.y) * ViewConfig.S
		plane.subdivide_width = maxi(0, int(r.size.x / 200.0) - 1)
		plane.subdivide_depth = maxi(0, int(r.size.y / 200.0) - 1)
		st.append_from(plane, 0, Transform3D(Basis(), ViewMath.to3(r.get_center())))
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	deck.mesh = st.commit()
	deck.material_override = ground_material
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deck)


## Adds an axis-aligned box spanning sim rect (x0..x1, y0..y1) and heights h0..h1 metres.
func _box(st: SurfaceTool, x0: float, x1: float, y0: float, y1: float, h0: float, h1: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3((x1 - x0) * ViewConfig.S, h1 - h0, (y1 - y0) * ViewConfig.S)
	var centre := ViewMath.to3(Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5), (h0 + h1) * 0.5)
	st.append_from(box, 0, Transform3D(Basis(), centre))


## A far (north) wall element: its top is clamped to the clearance rule and recorded in the profile.
func _far_box(st: SurfaceTool, x0: float, x1: float, y0: float, y1: float, h0: float, top: float) -> void:
	var limit := CLEARANCE_K * (CLEARANCE_Y - y1)
	var h := minf(top, limit)
	_box(st, x0, x1, y0, y1, h0, h)
	_profile.append({"z": y1 * ViewConfig.S, "y": y1, "top_m": h, "x0": x0, "x1": x1})


func _build_slab_and_walls() -> void:
	var slab := SurfaceTool.new()
	slab.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := -0.01
	_box(slab, BRIDGE_X.x, BRIDGE_X.y, FAR_PARAPET.y0, NEAR_RAIL.y1, -SLAB_M, top)
	_box(slab, -80, BRIDGE_X.x, 0, 540, -SLAB_M, top)
	_box(slab, BRIDGE_X.y, 2880, 0, 540, -SLAB_M, top)
	# Cornice: a slightly proud band under the deck edge on the near side, so the slab reads as a bridge edge.
	_box(slab, BRIDGE_X.x, BRIDGE_X.y, NEAR_RAIL.y1 - 2, NEAR_RAIL.y1 + 4, -SLAB_M - 0.12, -0.2)
	_add_stone_mesh("Slab", slab)

	var rng := RandomNumberGenerator.new()
	rng.seed = 5309
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Far parapet along the bridge, with a base course, pilasters on its face and merlons on its back half.
	_far_box(walls, BRIDGE_X.x, BRIDGE_X.y, FAR_PARAPET.y0, FAR_PARAPET.y1, -0.01, FAR_PARAPET.top)
	_far_box(walls, BRIDGE_X.x, BRIDGE_X.y, FAR_PARAPET.y1, FAR_PARAPET.y1 + 3, -0.01, 0.08)
	var x := BRIDGE_X.x + PILASTER_STEP * 0.5
	while x < BRIDGE_X.y - 40.0:
		_far_box(walls, x - 9, x + 9, FAR_PARAPET.y1 - 2, FAR_PARAPET.y1 + 5, -0.01, FAR_PARAPET.top - 0.03)
		x += PILASTER_STEP
	# Merlons (final polish): an irregular rhythm instead of a repeated box. The spacing wanders around MERLON.step,
	# widths and heights vary, caps differ in thickness and overhang, every fourth one is a wide tower merlon with a
	# stepped crown, and a few are broken stubs with a fallen block beside them. Every piece goes through _far_box,
	# so the clearance rule still clamps them all.
	x = BRIDGE_X.x + 30.0
	var n := 0
	while x + MERLON.w * 0.5 <= BRIDGE_X.y - 10.0:
		var tower := n % 4 == 3
		var broken := not tower and n > 0 and rng.randf() < 0.14
		var w: float = 40.0 if tower else MERLON.w + rng.randf_range(-5.0, 6.0)
		var base_h: float = FAR_PARAPET.top - 0.01
		if broken:
			# A stub with a jagged top (two blocks of different heights) and a fallen block on the parapet.
			var stub: float = FAR_PARAPET.top + rng.randf_range(0.05, 0.1)
			var split: float = rng.randf_range(0.35, 0.65)
			_far_box(walls, x - w * 0.5, x - w * 0.5 + w * split, MERLON.y0, MERLON.y1, base_h, stub)
			_far_box(walls, x - w * 0.5 + w * split, x + w * 0.5, MERLON.y0, MERLON.y1, base_h, maxf(stub - rng.randf_range(0.03, 0.06), base_h + 0.03))
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var fx: float = x + side * (w * 0.5 + rng.randf_range(4.0, 9.0))
			_far_box(walls, fx - 5.0, fx + 5.0, MERLON.y0 + 2.0, MERLON.y1 - 3.0, base_h, FAR_PARAPET.top + 0.05)
		else:
			var h: float = MERLON.top if (tower or n == 0) else MERLON.top - rng.randf_range(0.0, 0.09)
			var cap_t: float = rng.randf_range(0.04, 0.07)
			var over: float = rng.randf_range(1.5, 3.0)
			if tower:
				# Stepped crown: body, a proud cap band and a narrower top course.
				_far_box(walls, x - w * 0.5, x + w * 0.5, MERLON.y0, MERLON.y1, base_h, h - 0.06)
				_far_box(walls, x - w * 0.5 - 3.0, x + w * 0.5 + 3.0, MERLON.y0 - 2, MERLON.y1, h - 0.1, h - 0.05)
				_far_box(walls, x - w * 0.32, x + w * 0.32, MERLON.y0 + 1, MERLON.y1 - 1, h - 0.06, h)
			else:
				_far_box(walls, x - w * 0.5, x + w * 0.5, MERLON.y0, MERLON.y1, base_h, h)
				_far_box(walls, x - w * 0.5 - over, x + w * 0.5 + over, MERLON.y0 - 1, MERLON.y1, h - cap_t, h)
		x += MERLON.step + rng.randf_range(-8.0, 8.0)
		n += 1
	# Base aprons: north walls with a coping, a base course and buttresses, and the connectors down to the
	# bridge parapet.
	for span in [Vector2(-80, BRIDGE_X.x), Vector2(BRIDGE_X.y, 2880)]:
		_far_box(walls, span.x, span.y, 0, 20, -0.01, APRON_WALL_TOP)
		_far_box(walls, span.x, span.y, -2, 22, APRON_WALL_TOP - 0.06, APRON_WALL_TOP + 0.03)
		_far_box(walls, span.x, span.y, 20, 23, -0.01, 0.1)
		x = span.x + BUTTRESS_STEP * 0.5
		while x < span.y - 20.0:
			_far_box(walls, x - 8, x + 8, 20, 27, -0.01, APRON_WALL_TOP - 0.18)
			x += BUTTRESS_STEP
	_far_box(walls, BRIDGE_X.x, BRIDGE_X.x + 20, 0, FAR_PARAPET.y0, -0.01, 0.78)
	_far_box(walls, BRIDGE_X.y - 20, BRIDGE_X.y, 0, FAR_PARAPET.y0, -0.01, 0.78)
	# End walls behind the fountains (lateral; never in front of a card), with a coping and pilasters on
	# their inner face (north of the walkable band's south edge only: the south stays low).
	for ex in [Vector2(-80, -60), Vector2(2860, 2880)]:
		_box(walls, ex.x, ex.y, 20, 520, -0.01, END_WALL_TOP)
		# Coping overhangs outward only (the inner face is the lateral edge of the walkable band's ends).
		_box(walls, ex.x - (2.0 if ex.x < 0.0 else 0.0), ex.y + (0.0 if ex.x < 0.0 else 2.0), 18, 522, END_WALL_TOP - 0.05, END_WALL_TOP + 0.03)
		var inner: float = ex.y if ex.x < 0.0 else ex.x
		var dir: float = 1.0 if ex.x < 0.0 else -1.0
		for py in [80.0, 180.0, 280.0, 380.0]:
			var a: float = inner
			var b: float = inner + dir * 6.0
			_box(walls, minf(a, b), maxf(a, b), py - 8, py + 8, -0.01, END_WALL_TOP - 0.04)
	# Near (south) side stays low: curb, balusters, newel posts and a top rail on the bridge; low walls with a
	# coping on the aprons.
	var rail_top: float = minf(NEAR_RAIL.top, 0.28)
	_box(walls, BRIDGE_X.x, BRIDGE_X.y, NEAR_RAIL.y0, NEAR_RAIL.y1, -0.01, 0.08)
	_box(walls, BRIDGE_X.x, BRIDGE_X.y, NEAR_RAIL.y0 + 1, NEAR_RAIL.y1 - 1, rail_top - 0.06, rail_top)
	x = BRIDGE_X.x + NEAR_RAIL.baluster_step * 0.5
	while x < BRIDGE_X.y:
		if fmod(x - BRIDGE_X.x, POST_STEP) > NEAR_RAIL.baluster_step:
			_box(walls, x - 3, x + 3, NEAR_RAIL.y0 + 3, NEAR_RAIL.y1 - 3, 0.08, rail_top - 0.06)
		x += NEAR_RAIL.baluster_step
	x = BRIDGE_X.x + POST_STEP
	while x < BRIDGE_X.y - 10.0:
		_box(walls, x - 7, x + 7, NEAR_RAIL.y0 - 1, NEAR_RAIL.y1 + 1, -0.01, rail_top)
		x += POST_STEP
	for span in [Vector2(-80, BRIDGE_X.x), Vector2(BRIDGE_X.y, 2880)]:
		_box(walls, span.x, span.y, 520, 532, -0.01, 0.22)
		_box(walls, span.x, span.y, 518, 534, 0.2, 0.26)
	_box(walls, BRIDGE_X.x, BRIDGE_X.x + 20, NEAR_RAIL.y1, 520, -0.01, 0.26)
	_box(walls, BRIDGE_X.y - 20, BRIDGE_X.y, NEAR_RAIL.y1, 520, -0.01, 0.26)
	_add_stone_mesh("Walls", walls)


func _add_stone_mesh(node_name: String, st: SurfaceTool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = stone_material()
	add_child(mi)
	return mi


func _build_pillars() -> void:
	var height := -ABYSS_Y - SLAB_M
	var spots: Array = []
	var x := 0.0
	while x <= Constants.WORLD_W:
		var bridge := x > BRIDGE_X.x and x < BRIDGE_X.y
		var y: float = (NEAR_RAIL.y1 if bridge else 540.0) - PILLAR_M * 0.5 / ViewConfig.S - 4.0
		spots.append(Vector2(x, y))
		x += PILLAR_STEP
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pier_mesh(height)
	mm.instance_count = spots.size()
	for i in range(spots.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), ViewMath.to3(spots[i], -SLAB_M - height * 0.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pillars"
	mmi.multimesh = mm
	mmi.material_override = pier_stone_material()
	# No shadows: the piers' shadows on the abyss crossed them into a high-contrast lattice.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Spandrel arches between neighbouring piers on the same line: a viaduct under the bridge and aprons.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(spots.size() - 1):
		var a: Vector2 = spots[i]
		var b: Vector2 = spots[i + 1]
		if not is_equal_approx(a.y, b.y):
			continue
		_arch(st, a.x * ViewConfig.S + PIER_CAP_M * 0.5, b.x * ViewConfig.S - PIER_CAP_M * 0.5, a.y * ViewConfig.S)
	var arches := MeshInstance3D.new()
	arches.name = "Arches"
	arches.mesh = st.commit()
	arches.material_override = pier_stone_material()
	arches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arches)


## Pier mesh centred on its origin (height metres tall): a slim shaft that widens slightly toward the foot, a
## projecting capital under the slab and a plinth block at the foot.
func _pier_mesh(height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := height * 0.5
	var bottom := -height * 0.5
	var r := PILLAR_M * 0.5
	_frustum(st, bottom + 1.2, top - PIER_CAP_H, r * 1.18, r)
	_frustum(st, top - PIER_CAP_H, top, PIER_CAP_M * 0.5, PIER_CAP_M * 0.5)
	_frustum(st, top - PIER_CAP_H - 0.12, top - PIER_CAP_H, r * 1.22, r * 1.22)
	_frustum(st, bottom, bottom + 1.2, r * 1.5, r * 1.5)
	return st.commit()


## A square frustum (y0..y1, half-widths r0 at the bottom and r1 at the top) with outward normals and caps.
func _frustum(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float) -> void:
	var lo := [Vector3(-r0, y0, -r0), Vector3(r0, y0, -r0), Vector3(r0, y0, r0), Vector3(-r0, y0, r0)]
	var hi := [Vector3(-r1, y1, -r1), Vector3(r1, y1, -r1), Vector3(r1, y1, r1), Vector3(-r1, y1, r1)]
	for k in range(4):
		var j := (k + 1) % 4
		var mid: Vector3 = (lo[k] + lo[j] + hi[k] + hi[j]) * 0.25
		var outward := Vector3(mid.x, 0.0, mid.z).normalized()
		_quad(st, lo[k], lo[j], hi[j], hi[k], outward)
	_quad(st, hi[0], hi[1], hi[2], hi[3], Vector3.UP)
	_quad(st, lo[0], lo[1], lo[2], lo[3], Vector3.DOWN)


## Spandrel arch wall from x0 to x1 (metres) centred on z: flat top just under the slab, a segmental arch
## opening (crown ARCH_RISE_M above the springing line), ARCH_DEPTH_M thick.
func _arch(st: SurfaceTool, x0: float, x1: float, z: float) -> void:
	var top := -SLAB_M - 0.01
	var crown := top - 0.28
	var spring := crown - ARCH_RISE_M
	var w := (x1 - x0) * 0.5
	var radius := (w * w + ARCH_RISE_M * ARCH_RISE_M) / (2.0 * ARCH_RISE_M)
	var cx := (x0 + x1) * 0.5
	var cy := crown - radius
	var zf := z + ARCH_DEPTH_M * 0.5
	var zb := z - ARCH_DEPTH_M * 0.5
	var prev := Vector2.ZERO
	for k in range(ARCH_SEGMENTS + 1):
		var xk := x0 + (x1 - x0) * float(k) / float(ARCH_SEGMENTS)
		var yk := cy + sqrt(maxf(radius * radius - (xk - cx) * (xk - cx), 0.0))
		var cur := Vector2(xk, maxf(yk, spring))
		if k > 0:
			# Front and back spandrel faces between the intrados and the top.
			_quad(st, Vector3(prev.x, prev.y, zf), Vector3(cur.x, cur.y, zf), Vector3(cur.x, top, zf), Vector3(prev.x, top, zf), Vector3.BACK)
			_quad(st, Vector3(prev.x, prev.y, zb), Vector3(cur.x, cur.y, zb), Vector3(cur.x, top, zb), Vector3(prev.x, top, zb), Vector3.FORWARD)
			# Intrados (the arch soffit), facing down toward the arch centre.
			var mid := (prev + cur) * 0.5
			var nrm := Vector3(cx - mid.x, cy - mid.y, 0.0).normalized()
			_quad(st, Vector3(prev.x, prev.y, zb), Vector3(cur.x, cur.y, zb), Vector3(cur.x, cur.y, zf), Vector3(prev.x, prev.y, zf), nrm)
		prev = cur
	# Arch ring: a proud voussoir band on the front face, following the intrados.
	var ring := 0.22
	prev = Vector2.ZERO
	var prev_out := Vector2.ZERO
	for k in range(ARCH_SEGMENTS + 1):
		var xk := x0 + (x1 - x0) * float(k) / float(ARCH_SEGMENTS)
		var yk := cy + sqrt(maxf(radius * radius - (xk - cx) * (xk - cx), 0.0))
		var cur := Vector2(xk, maxf(yk, spring))
		var outv := (cur - Vector2(cx, cy)).normalized() * ring
		var cur_out := Vector2(cur.x + outv.x, minf(cur.y + outv.y, top))
		if k > 0:
			_quad(st, Vector3(prev.x, prev.y, zf + 0.06), Vector3(cur.x, cur.y, zf + 0.06), Vector3(cur_out.x, cur_out.y, zf + 0.06), Vector3(prev_out.x, prev_out.y, zf + 0.06), Vector3.BACK)
		prev = cur
		prev_out = cur_out


## Adds quad a-b-c-d (any winding) as two triangles facing `normal` (Godot front faces wind clockwise).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(st, a, b, c, normal)
	_tri(st, a, c, d, normal)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)


func _build_fountains() -> void:
	var root := Node3D.new()
	root.name = "Fountains"
	add_child(root)
	for team in [Constants.BLUE, Constants.RED]:
		var point: Vector2 = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
		var tc: Color = Constants.TEAM_COLOR[team]
		var f := Node3D.new()
		f.name = "FountainBlue" if team == Constants.BLUE else "FountainRed"
		f.position = ViewMath.to3(point)
		root.add_child(f)
		var r := FOUNTAIN_R * ViewConfig.S
		var disc := MeshInstance3D.new()
		disc.name = "Disc"
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = FOUNTAIN_H
		cyl.radial_segments = 48
		cyl.rings = 1
		disc.mesh = cyl
		disc.position.y = FOUNTAIN_H * 0.5 - 0.002
		var mat := _make_ground_material(Vector3(0.82, 0.86, 0.9).lerp(Vector3(tc.r, tc.g, tc.b), 0.25))
		disc.material_override = mat
		_fountain_mats.append(mat)
		f.add_child(disc)
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.07
		torus.outer_radius = r + 0.07
		torus.rings = 64
		torus.ring_segments = 8
		ring.mesh = torus
		ring.scale = Vector3(1.0, 0.4, 1.0)
		ring.position.y = FOUNTAIN_H
		var glow := StandardMaterial3D.new()
		glow.albedo_color = tc * 0.6
		glow.emission_enabled = true
		glow.emission = tc
		glow.emission_energy_multiplier = RING_HDR
		ring.material_override = glow
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(ring)
		_fountain_rings.append(glow)
		# Halo: an additive HDR glow lying on the disc, so the fountain blooms like an objective.
		var halo := MeshInstance3D.new()
		halo.name = "Halo"
		var hq := PlaneMesh.new()
		hq.size = Vector2.ONE * r * 2.0 * HALO_SCALE
		halo.mesh = hq
		halo.position.y = FOUNTAIN_H + 0.01
		var hm := _glow_material(tc, HALO_ENERGY, false, 0.0)
		hm.set_shader_parameter("falloff", 1.6)
		hm.set_shader_parameter("alpha", 0.28)
		halo.material_override = hm
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(halo)
		_fountain_halos.append(hm)
		# Beacon: a standing soft light over the fountain (billboard), so the fountain reads as a landmark.
		var beacon := MeshInstance3D.new()
		beacon.name = "Beacon"
		var bq := QuadMesh.new()
		bq.size = FOUNTAIN_BEACON_M
		beacon.mesh = bq
		beacon.position.y = FOUNTAIN_BEACON_LIFT_M
		var bm := _glow_material(Color(tc.r, tc.g, tc.b).lerp(Color.WHITE, 0.15), 1.0, true, 0.0)
		bm.set_shader_parameter("mode", 2)
		bm.set_shader_parameter("falloff", 1.4)
		bm.set_shader_parameter("alpha", FOUNTAIN_BEACON_ALPHA)
		beacon.material_override = bm
		beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(beacon)
		_fountain_beacons.append(bm)


func _build_abyss() -> void:
	var plane := PlaneMesh.new()
	plane.size = ABYSS_SIZE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/view3d/abyss.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/environment/rift-chasm.png"))
	var deck_z := Vector2(FAR_PARAPET.y0, NEAR_RAIL.y1) * ViewConfig.S
	m.set_shader_parameter("bridge_z", deck_z)
	var abyss := MeshInstance3D.new()
	abyss.name = "Abyss"
	abyss.mesh = plane
	abyss.material_override = m
	abyss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	abyss.position = ViewMath.to3(Vector2(Constants.WORLD_W, Constants.WORLD_H) * 0.5, ABYSS_Y)
	add_child(abyss)


## Two upright quads crossed at +-40 degrees, 1 m wide and 1 m tall with the bottom at y = 0 (scaled per instance).
func _crossed_card_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for yaw in [deg_to_rad(40.0), deg_to_rad(-40.0)]:
		var b := Basis(Vector3.UP, yaw)
		var right: Vector3 = b * Vector3(0.5, 0, 0)
		var n: Vector3 = b * Vector3(0, 0, 1)
		var corners := [
			[-right + Vector3(0, 1, 0), Vector2(0, 0)], [right + Vector3(0, 1, 0), Vector2(1, 0)],
			[right, Vector2(1, 1)], [-right, Vector2(0, 1)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_color(Color.WHITE)
			st.set_uv(corners[idx][1])
			st.add_vertex(corners[idx][0])
	return st.commit()


func _build_brush() -> void:
	var root := Node3D.new()
	root.name = "Brush"
	add_child(root)
	var card := _crossed_card_mesh()
	var tex: Texture2D = load("res://assets/environment/frost-brush-v1.png")
	for i in range(BrushVision.PATCHES.size()):
		var rect: Rect2 = BrushVision.PATCHES[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7100 + i
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = card
		mm.instance_count = BRUSH_CARDS
		var cols := int(ceil(BRUSH_CARDS / 2.0))
		var points := PackedVector2Array()
		for k in range(BRUSH_CARDS):
			var col := k % cols
			var row := floori(float(k) / cols)
			var pos := Vector2(
				rect.position.x + (col + 0.5) * rect.size.x / cols + rng.randf_range(-8.0, 8.0),
				rect.position.y + (row + 0.5) * rect.size.y / 2.0 + rng.randf_range(-12.0, 12.0))
			var w := rng.randf_range(40.0, 56.0) * ViewConfig.S * ViewConfig.UNIT_SCALE
			var h := rng.randf_range(30.0, 42.0) * ViewConfig.S * ViewConfig.UNIT_SCALE
			var basis := Basis(Vector3.UP, ViewConfig.yaw_rad() + rng.randf_range(-0.35, 0.35)).scaled(Vector3(w, h, w))
			mm.set_instance_transform(k, Transform3D(basis, ViewMath.to3(pos, -0.02)))
			points.append(pos)
			var shade := rng.randf_range(0.9, 1.08)
			mm.set_instance_color(k, Color(shade, shade * rng.randf_range(0.97, 1.03), shade, 1.0))
			mm.set_instance_custom_data(k, Color(rng.randf_range(0.10, 0.62), rng.randf_range(0.15, 0.22), 0.26, 0.36))
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/view3d/brush_card.gdshader")
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("tint", Vector3(BRUSH_TINT.r, BRUSH_TINT.g, BRUSH_TINT.b))
		mat.set_shader_parameter("fade", 1.0)
		var fade_mat := ShaderMaterial.new()
		fade_mat.shader = load("res://assets/shaders/view3d/brush_card_fade.gdshader")
		fade_mat.set_shader_parameter("tex", tex)
		fade_mat.set_shader_parameter("tint", Vector3(BRUSH_TINT.r, BRUSH_TINT.g, BRUSH_TINT.b))
		fade_mat.set_shader_parameter("fade", 1.0)
		for bm in [mat, fade_mat]:
			bm.set_shader_parameter("sway_hz", SWAY_HZ)
			bm.set_shader_parameter("sway_m", SWAY_M)
		_brush_mats.append(mat)
		_brush_fade_mats.append(fade_mat)
		_brush_fade_val.append(1.0)
		_brush_points.append(points)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Patch%d" % i
		mmi.multimesh = mm
		mmi.material_override = mat
		root.add_child(mmi)
		_brush_nodes.append(mmi)


func _build_props() -> void:
	# Background scenery only: everything stays below the deck, is dark and unemissive enough to sit in the
	# height fog, and uses faceted irregular meshes instead of primitive cones and eggs.
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var spire_count := 18
	var rock_count := PROP_COUNT - spire_count
	var spires := MultiMesh.new()
	spires.transform_format = MultiMesh.TRANSFORM_3D
	spires.mesh = _crystal_mesh(rng)
	spires.instance_count = spire_count
	for i in range(spire_count):
		# South only: north spires showed past the far wall as pale cones floating in the sky.
		var north := false
		var p := _prop_point(rng, north)
		var height := rng.randf_range(4.0, 9.0)
		# Tips stay under the deck: north ones (seen past the far wall at the top of the frame) and south ones.
		var top := minf(ABYSS_Y + height, -2.6 if north else -3.0)
		height = top - ABYSS_Y
		var r := rng.randf_range(0.45, 1.0)
		var tilt_axis := rng.randf_range(0.0, TAU)
		var b := Basis(Vector3(cos(tilt_axis), 0.0, sin(tilt_axis)), rng.randf_range(0.0, 0.14)) * Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(r, height, r))
		spires.set_instance_transform(i, Transform3D(b, Vector3(p.x, ABYSS_Y, p.z)))
	var ice := ice_material(Color(0.03, 0.06, 0.12), Color(0.2, 0.32, 0.46), 0.08)
	ice.set_shader_parameter("rim_strength", 0.3)
	var spire_node := MultiMeshInstance3D.new()
	spire_node.name = "Spires"
	spire_node.multimesh = spires
	spire_node.material_override = ice
	spire_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(spire_node)
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.mesh = _rock_mesh(rng)
	rocks.instance_count = rock_count
	for i in range(rock_count):
		var north := i < 8
		var p := _prop_point(rng, north)
		var s := Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.6, 1.1), rng.randf_range(0.8, 1.8))
		var y := rng.randf_range(-9.0, -4.0) if north else rng.randf_range(-10.0, -6.0)
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)) * Basis.from_scale(s)
		rocks.set_instance_transform(i, Transform3D(b, Vector3(p.x, y, p.z)))
	var rock_node := MultiMeshInstance3D.new()
	rock_node.name = "Rocks"
	rock_node.multimesh = rocks
	rock_node.material_override = deep_stone_material()
	rock_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rock_node)


## A faceted ice crystal 1 m wide and 1 m tall (base at y = 0): a jittered 7-sided prism that narrows
## into an off-centre point, flat shaded.
func _crystal_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sides := 7
	var base: Array = []
	var mid: Array = []
	for k in range(sides):
		var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / sides
		var r0 := rng.randf_range(0.7, 1.0)
		base.append(Vector3(cos(a) * r0, 0.0, sin(a) * r0))
		var r1 := r0 * rng.randf_range(0.45, 0.6)
		mid.append(Vector3(cos(a) * r1, rng.randf_range(0.5, 0.62), sin(a) * r1))
	var apex := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(sides):
		var j := (k + 1) % sides
		for v in [base[k], base[j], mid[j], base[k], mid[j], mid[k], mid[k], mid[j], apex]:   # clockwise = front
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## An irregular boulder about 2 m across: a low-poly sphere with seam-consistent radial jitter, flat shaded.
func _rock_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var phase := Vector3(rng.randf_range(0.0, 10.0), rng.randf_range(0.0, 10.0), rng.randf_range(0.0, 10.0))
	var bumped := PackedVector3Array()
	for v in verts:
		var n := v.normalized() if v.length() > 0.0001 else Vector3.UP
		# Smooth lumps from the direction only, so duplicated seam vertices move together.
		var lump := 0.16 * sin(n.x * 3.1 + phase.x) * cos(n.z * 2.7 + phase.y) + 0.1 * sin(n.y * 4.3 + phase.z)
		var flat := 0.75 if n.y < -0.4 else 1.0   # a flatter underside
		bumped.append(Vector3(v.x, v.y * flat, v.z) * (1.0 + lump))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in indices:
		st.add_vertex(bumped[idx])
	st.generate_normals()
	return st.commit()


## Ice clusters on the base aprons (outside the walkable rect): ICE_PER_CLUSTER small faceted crystals per
## spot, mirrored for the red base. North ones are clamped to the far-wall clearance rule and recorded in
## the wall profile.
func _build_ice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7411
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _crystal_mesh(rng)
	mm.instance_count = ICE_SPOTS.size() * 2 * ICE_PER_CLUSTER
	var k := 0
	for side in [0, 1]:
		for spot in ICE_SPOTS:
			var base_pt: Vector2 = spot[0]
			if side == 1:
				base_pt.x = Constants.WORLD_W - base_pt.x
			for j in range(ICE_PER_CLUSTER):
				var pos := base_pt + Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-4.0, 4.0))
				var r_m := rng.randf_range(0.16, 0.24) * (1.0 if j == 0 else 0.7)
				var r_px := r_m / ViewConfig.S
				var top: float = float(spot[1]) * (1.0 if j == 0 else rng.randf_range(0.5, 0.75))
				var south := pos.y + r_px
				if south < CLEARANCE_Y:
					top = minf(top, CLEARANCE_K * (CLEARANCE_Y - south))
					_profile.append({"z": south * ViewConfig.S, "y": south, "top_m": top, "x0": pos.x - r_px, "x1": pos.x + r_px, "kind": "ice"})
				var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				var tilt := 0.0 if j == 0 else rng.randf_range(0.05, 0.3)
				var lean := Basis(axis.normalized(), tilt) if axis.length() > 0.01 else Basis()
				var b := lean * Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(r_m, top, r_m))
				mm.set_instance_transform(k, Transform3D(b, ViewMath.to3(pos, -0.02)))
				_ice_points.append({"pos": pos, "r_px": r_px, "top_m": top})
				k += 1
	var ice := ice_material(Color(0.07, 0.16, 0.32), Color(0.55, 0.8, 1.0), 0.32)
	var node := MultiMeshInstance3D.new()
	node.name = "Ice"
	node.multimesh = mm
	node.material_override = ice
	add_child(node)


## Drifting mist sheet between the deck and the abyss floor (scrolls on the host clock).
func _build_mist() -> void:
	var plane := PlaneMesh.new()
	plane.size = ABYSS_SIZE
	mist_material = ShaderMaterial.new()
	mist_material.shader = load("res://assets/shaders/view3d/abyss_mist.gdshader")
	var c := ViewMath.to3(Vector2(Constants.WORLD_W, Constants.WORLD_H) * 0.5)
	mist_material.set_shader_parameter("centre", Vector2(c.x, c.z))
	mist_material.set_shader_parameter("half_size", ABYSS_SIZE * 0.5)
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	mist.mesh = plane
	mist.material_override = mist_material
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.position = ViewMath.to3(Vector2(Constants.WORLD_W, Constants.WORLD_H) * 0.5, MIST_Y)
	add_child(mist)


## Light snowfall: SNOW_COUNT soft flakes emitted from a box above the camera focus (Medium/High only).
func _build_snow() -> void:
	snow = GPUParticles3D.new()
	snow.name = "Snow"
	snow.amount = SNOW_COUNT
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.local_coords = false
	snow.randomness = 0.5
	snow.visibility_aabb = AABB(Vector3(-20, -12, -16), Vector3(40, 16, 32))
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = SNOW_BOX
	pm.direction = Vector3(0.18, -1.0, 0.08)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.25
	pm.gravity = Vector3(0.0, -0.05, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	snow.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_color = Color(0.86, 0.92, 1.0, 0.8)
	fm.albedo_texture = _soft_dot_texture()
	fm.disable_receive_shadows = true
	quad.material = fm
	snow.draw_pass_1 = quad
	add_child(snow)


func _soft_dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _prop_point(rng: RandomNumberGenerator, north: bool) -> Vector3:
	var x := rng.randf_range(-12.0, 68.0)
	var z := rng.randf_range(-36.0, -7.0) if north else rng.randf_range(14.0, 40.0)
	return Vector3(x, 0.0, z)
