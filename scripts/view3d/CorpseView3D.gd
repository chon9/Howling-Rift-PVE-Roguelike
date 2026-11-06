class_name CorpseView3D
extends Node3D
## Death-row card for AnimatedCorpse with fade and dissolve (W1-UNITS).
## Reads corpse.key/height/flipped/elapsed/modulate; uses texture_for_frame so override atlases show the right cell.
## Frees itself when the corpse leaves the tree for good.

const DEATH_FRAMES_TIME := 0.72
const DISSOLVE_START := 1.2
const DISSOLVE_END := 1.8

var corpse: Node2D
var host: Node3D
var body: Sprite3D
var card_mat: ShaderMaterial
var frame: int = -1
var dissolve: float = 0.0
var _stamp: String = ""
## Perf: last applied cell (key, frame, flip, height) and shader values, compared as plain fields every frame.
var _cell_frame: int = -1
var _cell_flip: bool = false
var _cell_height: float = -1.0
var _placed: Vector3 = Vector3(INF, INF, INF)
var _pitch: float = INF
var _fade: float = -1.0
var _dissolve: float = -1.0


func _init() -> void:
	body = SpriteUnitView3D.make_card("Body")
	card_mat = body.material_override
	add_child(body)


func bind(c: Node2D, h: Node3D) -> void:
	corpse = c
	host = h
	_stamp = ""
	_cell_frame = -1
	_fade = -1.0
	_dissolve = -1.0
	if c != null and is_instance_valid(c):
		if not c.tree_exiting.is_connected(_on_corpse_exiting):
			c.tree_exiting.connect(_on_corpse_exiting)
		var mat = c.material
		var red := false
		if mat is ShaderMaterial:
			var value = mat.get_shader_parameter("red_team")
			red = value is bool and value
		card_mat.set_shader_parameter("red_team", red)


func sync(_delta: float) -> void:
	if corpse == null or not is_instance_valid(corpse) or corpse.is_queued_for_deletion():
		dispose()
		return
	var c = corpse
	var key := str(c.key)
	var height := float(c.height)
	if not SpriteUnitView3D.has_art(key) or height <= 0.0:
		visible = false
		return
	var elapsed := float(c.elapsed)
	frame = clampi(int(elapsed / DEATH_FRAMES_TIME * 6.0), 0, 5)
	var flip := bool(c.flipped)
	if key != _stamp or frame != _cell_frame or flip != _cell_flip or absf(height - _cell_height) > 0.0005:
		_stamp = key
		_cell_frame = frame
		_cell_flip = flip
		_cell_height = height
		var scale := ViewConfig.MINION_SCALE if key.begins_with("minion_") else ViewConfig.UNIT_SCALE
		SpriteUnitView3D.apply_cell(body, card_mat, key, "death", frame, height, flip, scale)
	var p := ViewMath.to3(c.global_position)
	if p != _placed or position != p:
		_placed = p
		if is_inside_tree():
			global_position = p
		else:
			position = p
	var pitch := deg_to_rad(float(ViewConfig.camera_preset().pitch))
	if host != null and is_instance_valid(host) and host.has_method("pitch_deg"):
		pitch = deg_to_rad(float(host.pitch_deg()))
	if pitch != _pitch:
		_pitch = pitch
		body.rotation = Vector3(-pitch, ViewConfig.yaw_rad(), 0.0)
	dissolve = clampf((elapsed - DISSOLVE_START) / (DISSOLVE_END - DISSOLVE_START), 0.0, 1.0)
	var fade: float = c.modulate.a
	if fade != _fade:
		_fade = fade
		card_mat.set_shader_parameter("fade", fade)
	if dissolve != _dissolve:
		_dissolve = dissolve
		card_mat.set_shader_parameter("dissolve", dissolve)
	visible = true


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _on_corpse_exiting() -> void:
	if corpse == null or not is_instance_valid(corpse) or corpse.is_queued_for_deletion():
		dispose()
	else:
		_check_corpse.call_deferred()


func _check_corpse() -> void:
	if corpse == null or not is_instance_valid(corpse) or corpse.is_queued_for_deletion() or not corpse.is_inside_tree():
		dispose()
