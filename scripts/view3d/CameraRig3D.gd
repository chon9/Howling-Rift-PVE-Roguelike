class_name CameraRig3D
extends Node3D
## LoL / MLBB perspective camera rig (W1-HUB; W3-POLISH polishes).
## follow() receives the Camera2D facade focus in sim px (shake removed); the camera itself lives in `camera`.
## The rig node carries the whole pose (position + pitch); the Camera3D child sits at the rig origin and only
## owns the projection settings and the screen-space shake (h_offset / v_offset).
## W3-POLISH: the wheel distance follows a critically damped spring (no snap at the start or the end of a
## zoom), and ViewConfig.preset can change mid-match: follow() notices the new value and blends pitch, FOV,
## focus offset and distance to the new preset over PRESET_BLEND_S. apply_preset() still snaps.
## W3 fix: follow() clamps the focus row to a deck band computed from the frustum (ViewConfig.CAM_DECK_Y /
## CAM_FRAME), locked or unlocked, so a hero at the south edge of the lane never pulls the deck into the top
## half of the screen with the abyss below it. x is never clamped.

const NEAR_M := 0.5
const FAR_M := 250.0
const MIN_DIST_M := 8.0
const MAX_DIST_M := 60.0
const PRESET_BLEND_S := 0.45      # runtime preset switch duration (smoothstep)

var camera: Camera3D
var preset_name: String = ViewConfig.DEFAULT_PRESET

var _preset: Dictionary = ViewConfig.PRESETS[ViewConfig.DEFAULT_PRESET]
var _zoom_target: float = 17.5     # wheel target distance (metres at the 2D reference zoom)
var _zoom_dist: float = 17.5       # eased wheel distance
var _zoom_vel: float = 0.0         # spring velocity (m/s)
var _dist: float = 17.5            # effective distance after the 2D zoom mapping
var _seen_config: String = ""      # last ViewConfig.preset value acted on (runtime switch detection)
var _blend: float = 1.0            # 0..1 progress of a runtime preset blend (1 = settled)
var _from: Dictionary = {}         # pose at the start of the blend {pitch, fov, focus_z}
var _pitch: float = 56.0           # current (possibly blending) values
var _fov: float = 40.0
var _focus_z: float = 0.8


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	_seen_config = ViewConfig.preset
	apply_preset(ViewConfig.preset)


## Snaps to a preset (pose, FOV and wheel distance). Unknown names fall back to the default preset.
func apply_preset(preset: String) -> void:
	preset_name = preset if ViewConfig.PRESETS.has(preset) else ViewConfig.DEFAULT_PRESET
	_preset = ViewConfig.PRESETS[preset_name]
	_zoom_target = float(_preset.distance)
	_zoom_dist = _zoom_target
	_zoom_vel = 0.0
	_dist = _zoom_dist
	_blend = 1.0
	_pitch = float(_preset.pitch)
	_fov = float(_preset.fov)
	_focus_z = float(_preset.focus_z)
	camera.fov = _fov
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = NEAR_M
	camera.far = FAR_M
	rotation_degrees = Vector3(-pitch(), 0.0, 0.0)


## Starts a smooth switch to another preset (runtime settings change). The wheel distance springs to the
## new preset distance; pitch, FOV and focus offset blend with a smoothstep over PRESET_BLEND_S.
func transition_to(preset: String) -> void:
	var target := preset if ViewConfig.PRESETS.has(preset) else ViewConfig.DEFAULT_PRESET
	if target == preset_name and _blend >= 1.0:
		return
	_from = {"pitch": _pitch, "fov": _fov, "focus_z": _focus_z}
	preset_name = target
	_preset = ViewConfig.PRESETS[preset_name]
	_zoom_target = float(_preset.distance)
	_blend = 0.0


func is_blending() -> bool:
	return _blend < 1.0


## Places the rig. focus_sim is the 2D look-at point (Camera2D facade position minus shake), shake_sim the 2D
## shake offset (applied as a screen-space lens offset) and zoom2d the facade zoom (1.7 = reference distance).
func follow(focus_sim: Vector2, shake_sim: Vector2, zoom2d: float, delta: float) -> void:
	if ViewConfig.preset != _seen_config:
		_seen_config = ViewConfig.preset
		transition_to(ViewConfig.preset)
	if delta > 0.0:
		_step_zoom(delta)
		_step_blend(delta)
	_dist = clampf(_zoom_dist * ViewConfig.ZOOM_2D_REFERENCE / maxf(zoom2d, 0.05), MIN_DIST_M, MAX_DIST_M)
	var p := deg_to_rad(pitch())
	var band := focus_band()
	focus_sim.y = clampf(focus_sim.y, band.x, band.y)
	var focus := ViewMath.to3(focus_sim) + Vector3(0.0, 0.0, _focus_z)
	position = focus + Vector3(0.0, sin(p), cos(p)) * _dist
	rotation_degrees = Vector3(-pitch(), 0.0, 0.0)
	camera.fov = _fov
	camera.h_offset = shake_sim.x * ViewConfig.S
	camera.v_offset = -shake_sim.y * ViewConfig.S


## Mouse wheel: positive notches zoom out (farther), negative zoom in, clamped to the preset's range.
func wheel(notches: float) -> void:
	_zoom_target = clampf(_zoom_target + notches * ViewConfig.ZOOM_STEP_M, float(_preset.zoom_min), float(_preset.zoom_max))


func pitch() -> float:
	return _pitch


## Allowed focus rows (sim y, min..max) for the current pitch, FOV, distance and focus offset: the far
## parapet stays at or above screen row CAM_FRAME.x and the near rail at or below CAM_FRAME.y. When the
## camera is too far out for both, the band collapses to the midpoint of the two limits.
func focus_band() -> Vector2:
	var deck := ViewConfig.CAM_DECK_Y
	var frame := ViewConfig.CAM_FRAME
	# Focus (look point minus focus offset) that puts a deck row exactly on a screen row.
	var lo := (deck.x * ViewConfig.S - ground_offset_m(frame.x) - _focus_z) / ViewConfig.S
	var hi := (deck.y * ViewConfig.S - ground_offset_m(frame.y) - _focus_z) / ViewConfig.S
	if lo > hi:
		var mid := (lo + hi) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)


## Ground offset (metres along +Z, south) from the look point to the ground point seen at a screen row
## (0 top, 1 bottom) through the vertical centre line. KEEP_HEIGHT: independent of the aspect ratio.
func ground_offset_m(row: float) -> float:
	var p := deg_to_rad(pitch())
	var half := deg_to_rad(_fov) * 0.5
	var below := p - atan((1.0 - 2.0 * row) * tan(half))   # ray angle below the horizon
	var cam_h := _dist * sin(p)
	if below <= 0.01:
		return -1e4                                       # at or above the horizon: far north
	return _dist * cos(p) - cam_h / tan(below)


func distance() -> float:
	return _dist


func zoom_target() -> float:
	return _zoom_target


## Critically damped spring toward the wheel target (stiffness ViewConfig.ZOOM_EASE): eases in and out and
## never overshoots. Integrated in closed form, so it is stable for any delta.
func _step_zoom(delta: float) -> void:
	var w := ViewConfig.ZOOM_EASE
	var x := _zoom_dist - _zoom_target
	var e := exp(-w * delta)
	var c := _zoom_vel + w * x
	_zoom_dist = _zoom_target + (x + c * delta) * e
	_zoom_vel = (_zoom_vel - w * c * delta) * e
	if absf(_zoom_dist - _zoom_target) < 1e-4 and absf(_zoom_vel) < 1e-3:
		_zoom_dist = _zoom_target
		_zoom_vel = 0.0


func _step_blend(delta: float) -> void:
	if _blend >= 1.0:
		return
	_blend = minf(1.0, _blend + delta / PRESET_BLEND_S)
	var k := smoothstep(0.0, 1.0, _blend)
	_pitch = lerpf(float(_from.pitch), float(_preset.pitch), k)
	_fov = lerpf(float(_from.fov), float(_preset.fov), k)
	_focus_z = lerpf(float(_from.focus_z), float(_preset.focus_z), k)
	if _blend >= 1.0:
		_pitch = float(_preset.pitch)
		_fov = float(_preset.fov)
		_focus_z = float(_preset.focus_z)
