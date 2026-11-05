class_name FxBurst3D
extends GPUParticles3D
## One-shot additive particle burst (W2-VFX): replaces the 2D Main._BurstParticle sprays (death bursts, level-up)
## and serves FxBurst3D.emit callers (structure collapse, UnitExtras3D level-up). One GPUParticles3D per burst:
## amount = count, lifetime 0.7 s, horizontal speed 1.8-3.6 m/s, gravity -2, small additive quads.
## Frees itself LIFETIME + 0.2 s after it fires; its clock and the particles freeze while GameState.paused.
##
## Batching (VfxRegistry): the N _BurstParticle nodes one spawn call creates in a frame become ONE burst. The
## first particle registered that frame creates the burst; siblings at the same spot join it; the burst fires
## once with amount = member count on its first sync (or _process), after the whole frame's flush.

const LIFETIME := 0.7
const FREE_AFTER := LIFETIME + 0.2
const SPEED_MIN := 1.8                 # m/s (2D: 90-180 px/s)
const SPEED_MAX := 3.6
const GRAVITY := -2.0
const DAMPING := 6.0                   # 2D particles decay vel *= 0.9 per frame; damped so the spray stays local
const QUAD_M := 0.12                   # 2D dot is 8 px across (0.16 m); 0.12 m reads the same at 17.5 m
const BATCH_LIFT_PX := 16.0            # registry bursts: 2D sprays sit on the ground; lift so they read above the deck
const BATCH_RADIUS_PX := 12.0          # siblings spawned at one spot; same frame + same spot = same burst
const BATCH_DRIFT_PX_S := 200.0        # 2D spray speed bound (90-180 px/s): siblings may drift apart before registration
const UNFIRED_TIMEOUT := 2.0

static var _draw_mesh: QuadMesh
static var _batches: Dictionary = {}   # process frame -> Array of {"pos", "burst", "host", "age"}

var host: Node3D
var burst_color: Color = Color.WHITE
var members: int = 0
var fired: bool = false
var _age: float = 0.0


func _init() -> void:
	name = "FxBurst3D"
	one_shot = true
	explosiveness = 1.0
	lifetime = LIFETIME
	local_coords = false
	emitting = false
	amount = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	draw_pass_1 = _mesh()


## Emits `count` particles of `color` at a sim point, lifted lift_px art px along the host's card-up vector.
static func emit(h: Node3D, at: Vector2, color: Color, count: int, lift_px: float = 0.0) -> void:
	var b := _make(h, at, color, lift_px)
	if b != null:
		b.fire(count)


## VfxRegistry hook for one Main._BurstParticle: returns the burst it belongs to (created on first sight).
static func batch(particle: Node, h: Node3D) -> FxBurst3D:
	if particle == null or not is_instance_valid(particle) or h == null or not is_instance_valid(h):
		return null
	var frame := Engine.get_process_frames()
	for k in _batches.keys():
		if k != frame:
			_batches.erase(k)
	var pos: Vector2 = particle.global_position if particle is Node2D else Vector2.ZERO
	var col: Color = particle.get("col") if "col" in particle else Color.WHITE
	var list: Array = _batches.get(frame, [])
	var age: float = float(particle.get("elapsed")) if "elapsed" in particle else 0.0
	for e in list:
		var b = e.burst
		var reach: float = BATCH_RADIUS_PX + BATCH_DRIFT_PX_S * (age + float(e.age))
		if is_instance_valid(b) and not b.fired and e.host == h and (e.pos as Vector2).distance_to(pos) <= reach:
			b.members += 1
			return b
	var nb := _make(h, pos, col, BATCH_LIFT_PX)
	if nb == null:
		return null
	nb.members = 1
	list.append({"pos": pos, "burst": nb, "host": h, "age": age})
	_batches[frame] = list
	return nb


func fire(count: int) -> void:
	if fired:
		return
	fired = true
	amount = maxi(1, count)
	emitting = true
	restart()


## Host sync (View3D step 6). Batched bursts fire here, once every sibling has been registered.
func sync(_delta: float) -> void:
	if not fired and members > 0:
		fire(members)


## The host calls this when a member particle leaves the tree; the burst outlives its sources and frees itself.
func dispose() -> void:
	pass


func _process(delta: float) -> void:
	var paused := GameState.paused
	speed_scale = 0.0 if paused else 1.0
	if paused:
		return
	if not fired and members > 0:
		fire(members)
	_age += delta
	if (fired and _age >= FREE_AFTER) or (not fired and _age >= UNFIRED_TIMEOUT):
		queue_free()


static func _make(h: Node3D, at: Vector2, color: Color, lift_px: float) -> FxBurst3D:
	if h == null or not is_instance_valid(h) or not h.has_method("add_fx"):
		return null
	var b := FxBurst3D.new()
	b.host = h
	b.burst_color = color
	b.process_material = _process_material(color)
	h.add_fx(b)
	var up: Vector3 = h.card_up() if h.has_method("card_up") else Vector3.UP
	var p := ViewMath.to3(at) + up * ViewMath.art_m(lift_px, ViewConfig.FX_SCALE)
	if b.is_inside_tree():
		b.global_position = p
	else:
		b.position = p
	return b


static func _process_material(color: Color) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(1, 0, 0)
	m.spread = 180.0
	m.flatness = 1.0                     # horizontal ring, like the 2D radial spray
	m.initial_velocity_min = SPEED_MIN
	m.initial_velocity_max = SPEED_MAX
	m.gravity = Vector3(0, GRAVITY, 0)
	m.damping_min = DAMPING
	m.damping_max = DAMPING
	m.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var sc := CurveTexture.new()
	sc.curve = shrink
	m.scale_curve = sc
	return m


static func _mesh() -> QuadMesh:
	if _draw_mesh == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = FxCard3D.glow_texture()
		_draw_mesh = QuadMesh.new()
		_draw_mesh.size = Vector2.ONE * QUAD_M
		_draw_mesh.material = mat
	return _draw_mesh
