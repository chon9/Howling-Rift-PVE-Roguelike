class_name BeamView3D
extends Node3D
## Beam presentation (W2-PROJ, reworked by the W2 fix). Beam is a VIEW source in 3D: its opaque 2D ground strip
## (white core over the deck) is hidden and this view draws both parts:
##   Ribbon: the raised laser, an axial ribbon at chest height (U * art_m(LIFT_PX)) from the caster along
##           Vector2.from_angle(beam.rotation), length * S long and RIBBON_WIDTH_K * width * S wide, facing the
##           camera around its axis; beam_scroll tiles one SpellArt.missiles cell every 2 m, scrolling 4 tiles/s.
##   Ground: a flat quad on the deck over the hit band (length * S by 2 * width * S) that only glows faintly
##           with a thin tinted rim, so the hit area still reads without washing out the deck or the brush.
## Both are additive with alpha = life / 0.4. Reads Beam fields live (Beam has no class_name, so it is read
## dynamically); never writes them.

const BEAM_SHADER := preload("res://assets/shaders/view3d/beam_scroll.gdshader")
const LIFT_PX := 27.0                # ViewConfig.CHEST_PX: the laser leaves the caster's chest, not its feet
const RIBBON_WIDTH_K := 0.9          # ribbon width = RIBBON_WIDTH_K * width * S (the hit band is 2 * width)
const GROUND_Y_M := 0.015            # ground rim quad height above the deck
const TILE_M := 2.0
const SCROLL_TILES_PER_S := 4.0
const LIFE := 0.4

var source: Node2D
var host: Node3D
var ribbon: MeshInstance3D
var ribbon_mat: ShaderMaterial
var ground: MeshInstance3D
var ground_mat: ShaderMaterial
var scroll: float = 0.0             # tiles scrolled so far (host clock; frozen while paused)
var length_m: float = 0.0
var width_m: float = 0.0            # ribbon width (m)
var band_m: float = 0.0             # ground hit-band width, 2 * width * S (m)

var _last_host_t: float = -1.0


func _init() -> void:
	name = "BeamView3D"
	ribbon = MeshInstance3D.new()
	ribbon.name = "Ribbon"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	ribbon.mesh = quad
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon_mat = ShaderMaterial.new()
	ribbon_mat.shader = BEAM_SHADER
	ribbon_mat.set_shader_parameter("tex", SpellArt.missiles)
	ribbon_mat.set_shader_parameter("tile_m", TILE_M)
	ribbon_mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
	ribbon_mat.set_shader_parameter("bias_m", ViewConfig.FX_RAY_BIAS_M)
	ribbon.material_override = ribbon_mat
	add_child(ribbon)
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = quad
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = BEAM_SHADER
	ground_mat.set_shader_parameter("ground_mode", 1)
	ground_mat.set_shader_parameter("bias_m", 0.0)
	ground.material_override = ground_mat
	add_child(ground)


func bind(src: Node2D, h: Node3D) -> void:
	source = src
	host = h
	scroll = 0.0
	_last_host_t = -1.0
	if _source_ok() and not src.tree_exiting.is_connected(_on_source_exiting):
		src.tree_exiting.connect(_on_source_exiting)


func sync(_delta: float) -> void:
	if not _source_ok():
		dispose()
		return
	var cam := _camera()
	if cam == null or not cam.is_inside_tree() or not ("length" in source and "life" in source and "art_row" in source):
		visible = false
		return
	var b: Variant = source
	_advance_clock()
	var dir := Vector2.from_angle(float(b.rotation))
	length_m = maxf(float(b.length), 0.0) * ViewConfig.S
	band_m = 2.0 * maxf(float(b.width), 0.0) * ViewConfig.S
	width_m = RIBBON_WIDTH_K * maxf(float(b.width), 0.0) * ViewConfig.S
	var life := float(b.life)
	if length_m <= 0.001 or width_m <= 0.0001 or life <= 0.0:
		visible = false
		return
	var start := ViewMath.lifted(source.global_position, LIFT_PX, _card_up())
	_place(start)
	var axis := Vector3(dir.x, 0.0, dir.y) * length_m
	var across := axis.cross(cam.global_basis.z)
	if across.length_squared() < 0.000001:
		across = axis.cross(Vector3.UP)
	across = across.normalized()
	var normal := axis.normalized().cross(across).normalized()
	ribbon.transform = Transform3D(Basis(axis, across * width_m, normal), axis * 0.5)
	# Ground rim: flat on the deck under the lifted start point (the node origin is lifted along U).
	var side := Vector3(dir.y, 0.0, -dir.x) * band_m   # axis x side = +Y: right-handed, faces up
	var ground_origin := ViewMath.to3(source.global_position, GROUND_Y_M) - start
	ground.transform = Transform3D(Basis(axis, side, Vector3.UP), ground_origin + axis * 0.5)
	var row := clampi(int(b.art_row), 0, 5)
	var frame := mini(7, int((LIFE - life) * 20.0))
	var region := SpellArt.frame(SpellArt.missiles, row, frame)
	var size := Vector2(SpellArt.missiles.get_size())
	ribbon_mat.set_shader_parameter("region_uv", Vector4(region.position.x / size.x, region.position.y / size.y, region.end.x / size.x, region.end.y / size.y))
	ribbon_mat.set_shader_parameter("tint", Color(1, 1, 1, clampf(life / LIFE, 0.0, 1.0)))
	ribbon_mat.set_shader_parameter("core_color", b.color)
	ribbon_mat.set_shader_parameter("length_m", length_m)
	ribbon_mat.set_shader_parameter("scroll", scroll)
	ground_mat.set_shader_parameter("tint", Color(1, 1, 1, clampf(life / LIFE, 0.0, 1.0)))
	ground_mat.set_shader_parameter("core_color", b.color)
	ground_mat.set_shader_parameter("length_m", length_m)
	visible = true


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _advance_clock() -> void:
	var ht := -1.0
	if host != null and is_instance_valid(host) and host.has_method("anim_time"):
		ht = float(host.anim_time())
	if ht >= 0.0 and _last_host_t >= 0.0:
		scroll += maxf(ht - _last_host_t, 0.0) * SCROLL_TILES_PER_S
	_last_host_t = ht


func _place(origin: Vector3) -> void:
	if is_inside_tree():
		global_position = origin
	else:
		position = origin


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


func _on_source_exiting() -> void:
	if not _source_ok():
		dispose()
	else:
		_check_source.call_deferred()


func _check_source() -> void:
	if not _source_ok() or not source.is_inside_tree():
		dispose()
