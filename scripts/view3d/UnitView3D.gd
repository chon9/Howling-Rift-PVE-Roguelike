class_name UnitView3D
extends Node3D
const SHADOW_SHADER := preload("res://assets/shaders/view3d/card_shadow.gdshader")
## Base unit view: a 3D presentation of one 2D sim unit (W1-UNITS).
## Views read sim state only; they never write sim fields. A bound view frees itself when its
## source leaves the tree for good (queue_free / free / remove without re-adding).

var source: Node2D
var host: Node3D


func bind(src: Node2D, h: Node3D) -> void:
	source = src
	host = h
	if src != null and is_instance_valid(src) and not src.tree_exiting.is_connected(_on_source_exiting):
		src.tree_exiting.connect(_on_source_exiting)


func sync(_delta: float) -> void:
	if not _source_ok():
		dispose()


func head_height_m() -> float:
	return 0.0


func feet_world() -> Vector3:
	if _source_ok():
		return ViewMath.to3(source.global_position)
	return global_position


func screen_rect(_cam: Camera3D) -> Rect2:
	return Rect2()


func is_shown() -> bool:
	return visible


func set_hover(_mode: int) -> void:
	# 0 none, 1 enemy, 2 ally. Outline lands in W3-READ.
	pass


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


## True while the source can be read.
func _source_ok() -> bool:
	return source != null and is_instance_valid(source) and not source.is_queued_for_deletion()


## Host camera, or null when the host is gone.
func _camera() -> Camera3D:
	if host != null and is_instance_valid(host) and host.has_method("camera"):
		return host.camera()
	return null


## Camera card-up vector U (world Y when no camera is available).
func _card_up() -> Vector3:
	if host != null and is_instance_valid(host) and host.has_method("card_up"):
		return host.card_up()
	return Vector3.UP


func _pitch_rad() -> float:
	if host != null and is_instance_valid(host) and host.has_method("pitch_deg"):
		return deg_to_rad(float(host.pitch_deg()))
	return deg_to_rad(float(ViewConfig.camera_preset().pitch))


func _on_source_exiting() -> void:
	# tree_exiting also fires on a plain reparent; only a real removal frees the view.
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		dispose()
	else:
		_check_source.call_deferred()


func _check_source() -> void:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():
		dispose()


## Sun shadow: an upright, shadow-only card turned toward the sun. It shows the same art as the body, so the shadow on
## the ground is the unit's silhouette.
static func make_shadow_card(card_name: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = card_name
	sprite.centered = false
	sprite.region_enabled = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sprite.rotation = Vector3(0.0, deg_to_rad(ViewConfig.SUN_YAW_DEG), 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	sprite.material_override = mat
	return sprite
