class_name UnitExtras3D
extends Node3D
## Unit-attached effects (W2-EXTRAS): wind wall, Zed shadow clone, recall pillar, level-up pillar and
## burst, blink flares. Child "Extras" of a SpriteUnitView3D; synced by the view every frame, even while
## the view is hidden, so level-up and blink detection never miss a frame.
## Reads sim state only (buffs, recall_time, level, dead, global_position, visible); never writes it.
## The node is top_level with an identity transform, so its children are placed in world space. Their
## visibility still follows the view (brush-hidden or dead units hide their extras too).
## Clocks come from host.anim_time(), so everything freezes while GameState.paused.
## Pillars (recall, level-up) stand along the camera's card-up vector, like the unit cards they wrap, so they
## read as screen-upright columns of light anywhere on screen instead of perspective-leaning tubes.

const PILLAR_SHADER := preload("res://assets/shaders/view3d/pillar_add.gdshader")

const WIND_WIDTH_PX := 180.0          # 2D Rect2(-90, -25, 180, 50)
const WIND_HEIGHT_ART := 80.0         # art px along world up
const WIND_OFFSET_PX := 50.0          # feet + dir * 50
const WIND_ROW := 2
const WIND_FPS := 12.0
const WIND_SIDE_DIR_X := 0.7          # abs(dir.x) above this: wall would be edge-on, use a camera-facing card
const WIND_SIDE_WIDTH := 0.6

const CLONE_TINT := Vector3(0.6, 0.3, 0.9)
const CLONE_FADE := 0.5

const RECALL_RADIUS_M := 0.45
const RECALL_HEIGHT_M := 2.6
const RECALL_COLOR := Color(0.3, 0.85, 1.0)

const LEVEL_LIFE := 0.6
const LEVEL_RADIUS_M := 0.4
const LEVEL_HEIGHT_M := 2.4
const LEVEL_COLOR := Color(1.0, 0.86, 0.33)
const LEVEL_BURST_COUNT := 18
const LEVEL_BURST_LIFT := 20.0

const BLINK_PX := 120.0
const BLINK_COLOR := Color(1.0, 1.0, 0.8)
const BLINK_LIFT := 20.0
## A blink is a jump the sim made in game time: the sim clock (GameState.time) must have advanced since the
## last sync, and the jump must beat BLINK_PX plus what the unit could have walked in that time (buffed move
## speed x margin). Position writes outside the sim (match setup, test placement, paused frames), several sim
## steps batched between two syncs and frame hitches never flare; a gap above BLINK_MAX_DT s is not judged.
const BLINK_WALK_MARGIN := 1.6
const BLINK_MAX_DT := 1.0
const MAX_EVENTS := 32

var view: Node3D
var wind_wall: MeshInstance3D
var wind_mat: ShaderMaterial
var wind_side := false                # true while the camera-facing fallback card is used
var shadow_clone: Sprite3D
var clone_mat: ShaderMaterial
var recall_pillar: MeshInstance3D
var recall_mat: ShaderMaterial
var level_pillar: MeshInstance3D
var level_mat: ShaderMaterial
## Diagnostic log of triggered one-shot effects: {type: "level_up"|"blink_from"|"blink_to", at: Vector2, time: float}.
var events: Array = []

var _local_t := 0.0
var _level := -1
var _level_t0 := -1.0
var _has_prev := false
var _prev_pos := Vector2.ZERO
var _prev_dead := false
var _prev_moved := false               # airborne / forced_motion / recalling / dashing last frame
var _prev_shown := false
var _prev_sim_t := 0.0
var _clone_stamp := ""


func _init() -> void:
	top_level = true


func bind(v: Node3D) -> void:
	view = v
	_reset_tracking()
	_hide_all()


func sync(delta: float) -> void:
	transform = Transform3D.IDENTITY
	var src = _source()
	if src == null:
		_hide_all()
		_reset_tracking()
		return
	var host = view.get("host")
	var now := _clock(host, delta)
	var shown := _shown(src)
	_sync_wind_wall(src, host, now)
	_sync_shadow_clone(src, host)
	_sync_recall(src, now)
	_detect_level_up(src, host, now, shown)
	_detect_blink(src, host, now, shown)
	_sync_level_pillar(src, now)


## Hides every attached effect (used when the source is gone).
func _hide_all() -> void:
	for n in [wind_wall, shadow_clone, recall_pillar, level_pillar]:
		if n != null:
			n.visible = false


func _reset_tracking() -> void:
	_level = -1
	_level_t0 = -1.0
	_has_prev = false
	_prev_sim_t = GameState.time
	_clone_stamp = ""


func _source():
	if view == null or not is_instance_valid(view):
		return null
	var src = view.get("source")
	if src == null or not is_instance_valid(src) or not (src is Node2D) or src.is_queued_for_deletion():
		return null
	return src


func _clock(host, delta: float) -> float:
	if host != null and is_instance_valid(host) and host.has_method("anim_time"):
		return float(host.anim_time())
	if not GameState.paused:
		_local_t += delta
	return _local_t


## Same rule as the unit card: visible, alive, and on the roster for champions.
func _shown(src) -> bool:
	if not bool(src.visible) or bool(src.get("dead")):
		return false
	if "roster_active" in src and not bool(src.roster_active):
		return false
	return true


func _buffs(src) -> Dictionary:
	var b = src.get("buffs")
	return b if b is Dictionary else {}


func _up(host) -> Vector3:
	if host != null and is_instance_valid(host) and host.has_method("card_up"):
		return host.card_up()
	return Vector3.UP


func _camera(host) -> Camera3D:
	if host != null and is_instance_valid(host) and host.has_method("camera"):
		return host.camera()
	return null


func _pitch_rad(host) -> float:
	if host != null and is_instance_valid(host) and host.has_method("pitch_deg"):
		return deg_to_rad(float(host.pitch_deg()))
	return deg_to_rad(float(ViewConfig.camera_preset().pitch))


func _lift(src) -> float:
	if not _buffs(src).has("airborne"):
		return 0.0
	return HeroControl.lift(src)


func _pillar_material(color: Color, height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PILLAR_SHADER
	mat.set_shader_parameter("mode", 1)
	mat.set_shader_parameter("height_m", height)
	mat.set_shader_parameter("tint", color)
	return mat


func _pillar_mesh(node_name: String, radius: float, height: float, mat: ShaderMaterial) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 24
	cyl.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = cyl
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	add_child(mesh)
	return mesh


# --- Wind wall (buffs.wind_wall.direction) -------------------------------------------------------

func _sync_wind_wall(src, host, now: float) -> void:
	var b := _buffs(src)
	var wall = b.get("wind_wall")
	if not (wall is Dictionary) or not (wall.get("direction") is Vector2) or bool(src.get("dead")):
		if wind_wall != null:
			wind_wall.visible = false
		return
	var dir: Vector2 = wall.direction
	dir = Vector2.UP if dir.length_squared() < 1e-6 else dir.normalized()
	if wind_wall == null:
		wind_mat = ShaderMaterial.new()
		wind_mat.shader = PILLAR_SHADER
		wind_mat.set_shader_parameter("mode", 0)
		wind_mat.set_shader_parameter("tex", WindArt.texture)
		wind_mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		wind_wall = MeshInstance3D.new()
		wind_wall.name = "WindWall"
		wind_wall.mesh = quad
		wind_wall.material_override = wind_mat
		wind_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wind_wall)
	var region := WindArt.frame(WIND_ROW, int(floor(now * WIND_FPS)) % 4)
	var ts := WindArt.texture.get_size()
	wind_mat.set_shader_parameter("region_uv", Vector4(region.position.x / ts.x, region.position.y / ts.y, region.end.x / ts.x, region.end.y / ts.y))
	var base := ViewMath.to3(src.global_position + dir * WIND_OFFSET_PX)
	var width := WIND_WIDTH_PX * ViewConfig.S
	var height := ViewMath.art_m(WIND_HEIGHT_ART)
	var x_axis: Vector3
	var y_axis: Vector3
	var cam := _camera(host)
	wind_side = absf(dir.x) > WIND_SIDE_DIR_X and cam != null
	if wind_side:
		# A wall perpendicular to an east/west direction is seen edge-on: show a camera-facing card instead.
		var cb := ViewMath.card_basis(cam, 0.0)
		x_axis = cb.x.normalized() * width * WIND_SIDE_WIDTH
		y_axis = cb.y.normalized() * height
	else:
		# World-vertical quad perpendicular to dir; its right axis points screen-right (+x) so the art is not mirrored.
		var right := Vector3(-dir.y, 0.0, dir.x)
		if right.x < 0.0 or (is_zero_approx(right.x) and right.z > 0.0):
			right = -right
		x_axis = right.normalized() * width
		y_axis = Vector3.UP * height
	var z_axis := x_axis.cross(y_axis).normalized()
	wind_wall.transform = Transform3D(Basis(x_axis, y_axis, z_axis), base + y_axis * 0.5)
	wind_wall.visible = true


# --- Zed shadow clone (buffs.shadow.point) -------------------------------------------------------

func _sync_shadow_clone(src, host) -> void:
	var b := _buffs(src)
	var shadow = b.get("shadow")
	var key := str(view.get("key")) if "key" in view else ""
	var h := float(view.get("height_px")) if "height_px" in view else 0.0
	if not (shadow is Dictionary) or not (shadow.get("point") is Vector2) or bool(src.get("dead")) or key == "" or h <= 0.0:
		if shadow_clone != null:
			shadow_clone.visible = false
		return
	if shadow_clone == null:
		# The card helpers are reached through the view's script: naming SpriteUnitView3D here would make a
		# script reference cycle (it creates this node), which leaks the whole script graph at exit.
		shadow_clone = view.get_script().make_card("ShadowClone")
		clone_mat = shadow_clone.material_override
		clone_mat.set_shader_parameter("tint", CLONE_TINT)
		clone_mat.set_shader_parameter("red_team", false)
		add_child(shadow_clone)
	var action := str(view.get("pose_action"))
	var frame := int(view.get("pose_frame"))
	var flip := bool(view.get("flipped"))
	var stamp := "%s|%s|%d|%s|%.3f" % [key, action, frame, flip, h]
	if stamp != _clone_stamp:
		_clone_stamp = stamp
		view.get_script().apply_cell(shadow_clone, clone_mat, key, action, frame, h, flip)
	var body_mat = view.get("card_mat")
	if body_mat is ShaderMaterial:
		var red = body_mat.get_shader_parameter("red_team")
		clone_mat.set_shader_parameter("red_team", bool(red) if red != null else false)
	clone_mat.set_shader_parameter("fade", CLONE_FADE * src.modulate.a)
	shadow_clone.position = ViewMath.to3(shadow.point) + _up(host) * ViewMath.art_m(_lift(src))
	shadow_clone.rotation = Vector3(-_pitch_rad(host), ViewConfig.yaw_rad(), 0.0)
	shadow_clone.visible = true


# --- Recall pillar (recall_time >= 0) ------------------------------------------------------------

func _sync_recall(src, now: float) -> void:
	var t = src.get("recall_time")
	if t == null or float(t) < 0.0 or bool(src.get("dead")):
		if recall_pillar != null:
			recall_pillar.visible = false
		return
	if recall_pillar == null:
		recall_mat = _pillar_material(RECALL_COLOR, RECALL_HEIGHT_M)
		recall_pillar = _pillar_mesh("RecallPillar", RECALL_RADIUS_M, RECALL_HEIGHT_M, recall_mat)
	var duration := float(src.get("recall_duration")) if src.get("recall_duration") != null else 1.0
	var progress := clampf(float(t) / maxf(duration, 0.001), 0.0, 1.0)
	var c := RECALL_COLOR
	c.a = 0.24 + 0.24 * progress
	recall_mat.set_shader_parameter("tint", c)
	recall_mat.set_shader_parameter("phase", now)
	recall_pillar.transform = pillar_transform(src.global_position, RECALL_HEIGHT_M, 1.0, _up(view.get("host")))
	recall_pillar.visible = true


## Transform of a pillar cylinder (mesh centred on its origin, axis local +Y) standing on `feet`: its axis follows
## the card-up vector `up` (screen-upright, like the unit cards), radius scaled by `grow`, foot on the ground point.
static func pillar_transform(feet: Vector2, height: float, grow: float, up: Vector3) -> Transform3D:
	var y := up.normalized() if up.length_squared() > 1e-6 else Vector3.UP
	var x := Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	x = Vector3.RIGHT if x.length_squared() < 1e-6 else x.normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x * grow, y, z * grow), ViewMath.to3(feet) + y * height * 0.5)


## Current recall pillar alpha (tests and diagnostics).
func recall_alpha() -> float:
	if recall_mat == null:
		return 0.0
	return float(recall_mat.get_shader_parameter("tint").a)


# --- Level-up: gold pillar for LEVEL_LIFE s plus an 18-particle gold burst ---------------------

func _detect_level_up(src, host, now: float, shown: bool) -> void:
	var lv = src.get("level")
	if lv == null:
		return
	var level := int(lv)
	if _level >= 0 and level > _level:
		_level_t0 = now
		_log("level_up", src.global_position, now)
		if shown and host != null and is_instance_valid(host):
			FxBurst3D.emit(host, src.global_position, LEVEL_COLOR, LEVEL_BURST_COUNT, LEVEL_BURST_LIFT)
	_level = level


func _sync_level_pillar(src, now: float) -> void:
	var age := now - _level_t0
	if _level_t0 < 0.0 or age < 0.0 or age >= LEVEL_LIFE:
		if level_pillar != null:
			level_pillar.visible = false
		if age >= LEVEL_LIFE:
			_level_t0 = -1.0
		return
	if level_pillar == null:
		level_mat = _pillar_material(LEVEL_COLOR, LEVEL_HEIGHT_M)
		level_mat.set_shader_parameter("scroll", 2.4)
		level_pillar = _pillar_mesh("LevelPillar", LEVEL_RADIUS_M, LEVEL_HEIGHT_M, level_mat)
	var k := age / LEVEL_LIFE
	var c := LEVEL_COLOR
	c.a = 0.55 * (1.0 - k)
	level_mat.set_shader_parameter("tint", c)
	level_mat.set_shader_parameter("phase", now)
	var grow := 1.0 + 0.6 * k
	level_pillar.transform = pillar_transform(src.global_position, LEVEL_HEIGHT_M, grow, _up(view.get("host")))
	level_pillar.visible = true


# --- Blink flare: a jump > BLINK_PX in one frame (not respawn, airborne, forced motion or recall) --

func _detect_blink(src, host, now: float, shown: bool) -> void:
	var pos: Vector2 = src.global_position
	var dead := bool(src.get("dead"))
	var b := _buffs(src)
	var rt = src.get("recall_time")
	var moved: bool = b.has("airborne") or b.has("forced_motion") or (rt != null and float(rt) >= 0.0) or src.get("is_dashing") == true
	var sim_t := GameState.time
	var dt_sim := sim_t - _prev_sim_t
	var jump := pos.distance_to(_prev_pos)
	# Cheap gates first; the walking reach (which reads the speed buffs) is only computed for a real candidate.
	# A gap longer than BLINK_MAX_DT of sim time (a long hitch, a snapshot burst) is a discontinuity, not a blink.
	if src is Champion and _has_prev and not GameState.paused and dt_sim > 0.0 and dt_sim <= BLINK_MAX_DT \
			and not dead and not _prev_dead and not moved and not _prev_moved and jump > BLINK_PX \
			and jump > BLINK_PX + _walk_speed(src) * BLINK_WALK_MARGIN * dt_sim:
		_log("blink_from", _prev_pos, now)
		_log("blink_to", pos, now)
		if host != null and is_instance_valid(host):
			if _prev_shown:
				FxCard3D.flare(host, _prev_pos, "blink", BLINK_COLOR, BLINK_LIFT)
			if shown:
				FxCard3D.flare(host, pos, "blink", BLINK_COLOR, BLINK_LIFT)
	_has_prev = true
	_prev_pos = pos
	_prev_dead = dead
	_prev_moved = moved
	_prev_shown = shown
	_prev_sim_t = sim_t


## Fastest the unit can currently walk (sim px / s): its buffed speed when the sim exposes it, never below the base.
func _walk_speed(src) -> float:
	var speed: float = float(src.get("move_speed")) if src.get("move_speed") != null else 0.0
	if src.has_method("effective_move_speed"):
		speed = maxf(speed, float(src.effective_move_speed()))
	return maxf(speed, 0.0)


func _log(type: String, at: Vector2, time: float) -> void:
	events.append({"type": type, "at": at, "time": time})
	if events.size() > MAX_EVENTS:
		events.pop_front()
