class_name GroundOverlay
extends SubViewport
## Camera-following SubViewport that hosts Main.world_root; its texture is composited onto the 3D deck (W1-HUB).
## The SubViewport stores premultiplied display-space RGBA (plan 2.2); ground_deck.gdshader composites it with
## v3d_overlay(). Every frame sync() fits GroundCam to the Camera3D's ground footprint clipped to the deck box,
## so the texture always covers what the 3D camera can see of the walkable world at up to 1.7 texels per sim px.

const DECK_BOX := Rect2(-100.0, -60.0, 3000.0, 660.0)  # sim px; everything the overlay ever needs to cover
const GROW_PX := 40.0
const MAX_ZOOM := ViewConfig.OVERLAY_TEXELS_PER_SIM_PX
const FAR_HIT_M := 250.0

var ground_cam: Camera2D

var _materials: Array[ShaderMaterial] = []
var _rect: Rect2 = Rect2()
var _live: bool = false
var _frame: int = 0
## Frames this overlay was scheduled to render (diagnostics: Low quality renders every Nth frame).
var render_count: int = 0


func _init() -> void:
	name = "GroundOverlay"
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	ground_cam = Camera2D.new()
	ground_cam.name = "GroundCam"
	ground_cam.zoom = Vector2.ONE * MAX_ZOOM
	ground_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	add_child(ground_cam)
	configure(ViewConfig.quality_settings().overlay)


func _ready() -> void:
	ground_cam.make_current()


func configure(overlay_size: Vector2i) -> void:
	size = Vector2i(maxi(overlay_size.x, 16), maxi(overlay_size.y, 16))
	_apply_cam(ground_cam.position, ground_cam.zoom.x)


## Moves the 2D world into this viewport (remove_child / add_child keeps the global position).
func adopt(world_root: Node2D) -> void:
	if world_root == null or world_root.get_parent() == self:
		return
	var gp := world_root.global_position
	var parent := world_root.get_parent()
	if parent != null:
		var source_vp := parent.get_viewport()
		if source_vp != null:
			canvas_item_default_texture_filter = source_vp.canvas_item_default_texture_filter
			canvas_item_default_texture_repeat = source_vp.canvas_item_default_texture_repeat
		parent.remove_child(world_root)
	add_child(world_root)
	world_root.global_position = gp


## Registers a ground material: it receives overlay_tex (windowed only) and overlay_rect every sync.
func bind_material(m: ShaderMaterial) -> void:
	if m == null:
		return
	if not _materials.has(m):
		_materials.append(m)
	if DisplayServer.get_name() != "headless":
		m.set_shader_parameter("overlay_tex", get_texture())
	_push_rect(m)


func sync(cam: Camera3D) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	# Low quality renders the overlay every Nth frame. Camera, rect and the render move together, so between
	# renders the deck keeps showing the last frame at its own (still correct) world rect.
	var every := maxi(1, int(ViewConfig.quality_settings().get("overlay_every", 1)))
	if _live:
		if every <= 1:
			if render_target_update_mode != SubViewport.UPDATE_ALWAYS:
				render_target_update_mode = SubViewport.UPDATE_ALWAYS
			render_count += 1
		else:
			_frame += 1
			if _frame % every != 0:
				return
			render_target_update_mode = SubViewport.UPDATE_ONCE
			render_count += 1
	var pts := corner_hits(cam)
	var box := Rect2(pts[0], Vector2.ZERO)
	for i in range(1, pts.size()):
		box = box.expand(pts[i])
	var clipped := box.intersection(DECK_BOX)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		clipped = DECK_BOX
	clipped = clipped.grow(GROW_PX)
	var z := minf(MAX_ZOOM, minf(float(size.x) / clipped.size.x, float(size.y) / clipped.size.y))
	# Perf: a resting camera keeps the same fit; skip the scroll update and the per-material uniform pushes.
	var center := clipped.get_center()
	if center == ground_cam.position and Vector2(z, z) == ground_cam.zoom and _rect.size == Vector2(size) / maxf(z, 0.01):
		return
	_apply_cam(center, z)


func overlay_rect() -> Rect2:
	return _rect


func set_live(on: bool) -> void:
	_live = on
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func is_live() -> bool:
	return _live


## Ground hits (sim px) of the four visible-rect corners [TL, TR, BR, BL]. A ray that misses the ground
## (above the horizon) uses its far point at 250 m projected onto the ground.
static func corner_hits(cam: Camera3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	var vr := cam.get_viewport().get_visible_rect()
	for c in [vr.position, Vector2(vr.end.x, vr.position.y), vr.end, Vector2(vr.position.x, vr.end.y)]:
		var hit = ViewMath.ground_hit(cam, c)
		if hit == null:
			hit = cam.project_ray_origin(c) + cam.project_ray_normal(c) * FAR_HIT_M
		out.append(ViewMath.to2(hit))
	return out


func _apply_cam(center: Vector2, z: float) -> void:
	z = maxf(z, 0.01)
	ground_cam.position = center
	ground_cam.zoom = Vector2(z, z)
	if ground_cam.is_inside_tree():
		ground_cam.force_update_scroll()
	var span := Vector2(size) / z
	_rect = Rect2(center - span * 0.5, span)
	for m in _materials:
		_push_rect(m)


func _push_rect(m: ShaderMaterial) -> void:
	if m != null:
		m.set_shader_parameter("overlay_rect", Vector4(_rect.position.x, _rect.position.y, _rect.size.x, _rect.size.y))
