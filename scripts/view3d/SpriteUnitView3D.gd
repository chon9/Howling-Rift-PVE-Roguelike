class_name SpriteUnitView3D
extends UnitView3D
## Camera-facing painted card for champions and minions (W1-UNITS; W3-READ polishes).
## Children: Body (Sprite3D with the unit_card shader), ShadowCaster (upright silhouette card), Extras (UnitExtras3D).
## Mirrors Champion/Minion._draw: same pose, atlas cell, pivot, flip, lift, tint and whitening; never writes sim fields.

const CARD_SHADER := preload("res://assets/shaders/view3d/unit_card.gdshader")
const CHAMP_TINT := Vector3(1.3, 1.15, 1.08)
const MINION_TINT := Vector3(1.10, 1.06, 1.02)
const KEY_LIGHT := 1.0
const GROUND_SHADE := 0.5
## Hover outline (W3-READ): set_hover(1) enemy red, set_hover(2) ally blue, 0 clears.
const HOVER_ENEMY := Color(1.0, 0.25, 0.2, 1.0)
const HOVER_ALLY := Color(0.3, 0.75, 1.0, 1.0)
const HOVER_OUTLINE_PX := 2.0

var body: Sprite3D
var card_mat: ShaderMaterial
var shadow_caster: Sprite3D
var shadow_mat: ShaderMaterial
var extras: Node3D
var key: String = ""
var height_px: float = 0.0          # 2D art height H: 56 for champions, size*2.7 for minions
var flipped: bool = false
var pose_action: String = "idle"
var pose_frame: int = 0
var hover_mode: int = 0
var _params: Dictionary = {}
## Per-frame change detection (plain fields, no string formatting: this runs for every unit every frame).
var _cell_key: String = ""
var _cell_action: String = ""
var _cell_frame: int = -1
var _cell_flip: bool = false
var _cell_h: float = -1.0
var _body_pitch: float = INF
var _champion: bool = false
var _p_set: bool = false                              # typed uniform cache (_sync_body)
var _p_red: bool = false
var _p_whiten: float = 0.0
var _p_tint: Vector3 = Vector3.ONE
var _p_fade: float = 1.0
var _key_animator: Object = null                      # _resolve_key cache: animator and its raw key
var _key_raw: Variant = null
var _hub: View3D = null                               # the host while its frame values are valid (sync only)
var _placed: Vector3 = Vector3(INF, INF, INF)        # last _place target and the local position it produced
var _placed_local: Vector3 = Vector3(INF, INF, INF)


func _init() -> void:
	body = make_card("Body")
	card_mat = body.material_override
	add_child(body)
	shadow_caster = make_shadow_card("ShadowCaster")
	shadow_mat = shadow_caster.material_override
	add_child(shadow_caster)
	extras = UnitExtras3D.new()
	extras.name = "Extras"
	add_child(extras)


func bind(src: Node2D, h: Node3D) -> void:
	super.bind(src, h)
	_cell_key = ""
	_cell_frame = -1
	_body_pitch = INF
	_champion = src is Champion
	_params.clear()
	_p_set = false
	_key_animator = null
	set_hover(0)
	if extras != null and extras.has_method("bind"):
		extras.bind(self)


func sync(delta: float) -> void:
	if not _source_ok():
		dispose()
		return
	var src = source
	_champion = src is Champion
	var shown := bool(src.visible) and not bool(src.dead)
	if _champion and "roster_active" in src:
		shown = shown and bool(src.roster_active)
	# Perf: inside View3D._step the hub hands every view the frame's card-up, pitch and shadow setting.
	_hub = host as View3D
	if _hub != null and not _hub.frame_valid:
		_hub = null
	var up: Vector3 = _hub.frame_up if _hub != null else _card_up()
	_place(ViewMath.to3(src.global_position) + up * ViewMath.art_m(_lift(), _scale()))
	if shown:
		shown = _sync_body()
	visible = shown
	# Wind wall, shadow clone, recall, level-up and blink are champion effects: minions skip the extras pass.
	if _champion and extras != null:
		extras.sync(delta)


## 0 none, 1 enemy (red outline), 2 ally (blue outline). Only touches this view's own card material.
func set_hover(mode: int) -> void:
	hover_mode = mode if mode == 1 or mode == 2 else 0
	_set_param("outline_px", HOVER_OUTLINE_PX)
	_set_param("outline_color", hover_color(hover_mode))


static func hover_color(mode: int) -> Color:
	if mode == 1:
		return HOVER_ENEMY
	if mode == 2:
		return HOVER_ALLY
	return Color(0.0, 0.0, 0.0, 0.0)


func head_height_m() -> float:
	if not _source_ok() or not _resolve_key():
		return 0.0
	var top := -ActionSpriteArt.body_rect(key, _height(), _is_flipped()).position.y
	return ViewMath.art_m(top + _lift(), _scale())


func screen_rect(cam: Camera3D) -> Rect2:
	if cam == null or not _source_ok() or not _resolve_key():
		return Rect2()
	var r := ActionSpriteArt.body_rect(key, _height(), _is_flipped())
	var sc := _scale()
	var origin := ViewMath.to3(source.global_position) + _card_up() * ViewMath.art_m(_lift(), sc)
	var right := cam.global_basis.x.normalized()
	var up := _card_up()
	var out := Rect2()
	var first := true
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var p: Vector3 = origin + right * ViewMath.art_m(corner.x, sc) + up * ViewMath.art_m(-corner.y, sc)
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		if first:
			out = Rect2(s, Vector2.ZERO)
			first = false
		else:
			out = out.expand(s)
	if first:
		return Rect2()
	return out.grow(6.0)


## Builds a camera-facing card: feet-anchored Sprite3D with its own unit_card material.
static func make_card(card_name: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = card_name
	sprite.centered = false
	sprite.region_enabled = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = CARD_SHADER
	mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
	mat.set_shader_parameter("key_light", KEY_LIGHT)
	mat.set_shader_parameter("ground_shade", GROUND_SHADE)
	sprite.material_override = mat
	return sprite


## Points a card at one atlas cell exactly as the 2D draw does: pixel_size = S*scale*H/body_height*rel (scale is
## UNIT_SCALE for heroes, ViewConfig.MINION_SCALE for minions and their corpses),
## offset puts the manifest pivot (feet) at the node origin, mirrored when flipped. Also pushes the frame mask.
static func apply_cell(sprite: Sprite3D, mat: ShaderMaterial, cell_key: String, action: String, frame: int, height: float, flip: bool, scale: float = ViewConfig.UNIT_SCALE) -> void:
	var data: Dictionary = ActionSpriteArt.entry(cell_key)
	var cell: Dictionary = ActionSpriteArt.frame(cell_key, action, frame)
	var texture := ActionSpriteArt.texture_for_frame(cell_key, action, frame)
	var region := ActionSpriteArt.region(cell_key, action, frame)
	var pivot := Vector2(float(cell.pivot[0]), float(cell.pivot[1]))
	if sprite.texture != texture:
		sprite.texture = texture
		mat.set_shader_parameter("tex", texture)
	sprite.region_rect = region
	sprite.pixel_size = ViewConfig.S * scale * height / float(data.body_height) * float(cell.get("relative_scale", 1.0))
	sprite.flip_h = flip
	sprite.offset = Vector2((pivot.x - region.size.x) if flip else -pivot.x, pivot.y - region.size.y)
	ActionSpriteArt.apply_frame_mask(mat, cell_key, action, frame)
	var size := Vector2(maxf(1.0, texture.get_width()), maxf(1.0, texture.get_height()))
	mat.set_shader_parameter("region_uv", Vector4(region.position.x / size.x, region.position.y / size.y, region.end.x / size.x, region.end.y / size.y))


## True when the manifest has this animation key (loads the manifest on first use).
static func has_art(cell_key: String) -> bool:
	if cell_key == "":
		return false
	if ActionSpriteArt.manifest.is_empty():
		ActionSpriteArt.entry("minion_melee")
	return ActionSpriteArt.manifest.has(cell_key)


func _sync_body() -> bool:
	if not _resolve_key():
		return false
	var h := _height()
	if h <= 0.0:
		return false
	_sync_shadow()
	var pose := _pose()
	pose_action = str(pose.action)
	pose_frame = int(pose.frame)
	flipped = _is_flipped()
	if key != _cell_key or pose_action != _cell_action or pose_frame != _cell_frame or flipped != _cell_flip or absf(h - _cell_h) > 0.0005:
		_cell_key = key
		_cell_action = pose_action
		_cell_frame = pose_frame
		_cell_flip = flipped
		_cell_h = h
		height_px = h
		apply_cell(body, card_mat, key, pose_action, pose_frame, h, flipped, _scale())
		if shadow_caster.visible:
			apply_cell(shadow_caster, shadow_mat, key, pose_action, pose_frame, h, flipped, _scale())
	var pitch: float = _hub.frame_pitch_rad if _hub != null else _pitch_rad()
	if pitch != _body_pitch:
		_body_pitch = pitch
		body.rotation = Vector3(-pitch, 0.0, 0.0)
	var src = source
	var champion := _champion
	var red := int(src.team) == Constants.RED and (not champion or ViewConfig.RECOLOR_RED_HEROES)
	var whiten := 0.0
	var tint := Vector3.ONE
	if champion:
		var flash := float(src.hit_flash)
		whiten = clampf(flash / 0.14, 0.0, 1.0) * 0.7
		if flash > 0.0:
			tint = CHAMP_TINT
	elif "flash_t" in src and float(src.flash_t) > 0.0:
		tint = MINION_TINT
	# Perf: the four per-frame uniforms compare against typed fields (no dictionary lookups).
	if red != _p_red or not _p_set:
		_p_red = red
		card_mat.set_shader_parameter("red_team", red)
	if whiten != _p_whiten or not _p_set:
		_p_whiten = whiten
		card_mat.set_shader_parameter("hit_whiten", whiten)
	if tint != _p_tint or not _p_set:
		_p_tint = tint
		card_mat.set_shader_parameter("tint", tint)
	var fade: float = src.modulate.a
	if fade != _p_fade or not _p_set:
		_p_fade = fade
		card_mat.set_shader_parameter("fade", fade)
	_p_set = true
	return true


func _sync_shadow() -> void:
	# Low quality has no shadow maps: the shadow card would only cost culling and instance updates.
	var cast: bool = _hub.frame_shadows if _hub != null else bool(ViewConfig.quality_settings().shadows)
	if shadow_caster.visible != cast:
		shadow_caster.visible = cast
		_cell_frame = -1   # re-point the card at the current frame when shadows come back


func _set_param(param: String, value) -> void:
	if _params.has(param) and _params[param] == value:
		return
	_params[param] = value
	card_mat.set_shader_parameter(param, value)


func _place(p: Vector3) -> void:
	# Perf: re-placing an unchanged card still propagates a transform change to the body, the shadow caster and the
	# extras; units standing still (attacking, frozen) skip it. Views live under plain Node3D roots at the origin.
	if p == _placed and position == _placed_local:
		return
	if is_inside_tree():
		global_position = p
	else:
		position = p
	_placed = p
	_placed_local = position


func _is_champion() -> bool:
	return source is Champion


## Card scale: ViewConfig.MINION_SCALE for minions, UNIT_SCALE for champions (and anything else).
func _scale() -> float:
	return ViewConfig.MINION_SCALE if source is Minion else ViewConfig.UNIT_SCALE


func _resolve_key() -> bool:
	if not _source_ok():
		return false
	var animator = source.get("animator")
	# Perf: the same animator with the same key resolves to the same art key (has_art already passed for it).
	if animator != null and animator == _key_animator and is_instance_valid(animator) and animator.key == _key_raw:
		return true
	var k := ""
	if animator != null and is_instance_valid(animator) and str(animator.key) != "":
		k = str(animator.key)
	elif _is_champion():
		k = "hero_" + str(source.get("hero_key"))
	else:
		k = "minion_" + str(source.get("subkind"))
	if not has_art(k):
		return false
	key = k
	if animator != null and is_instance_valid(animator) and str(animator.key) == k:
		_key_animator = animator
		_key_raw = animator.key
	else:
		_key_animator = null
	return true


func _height() -> float:
	if _is_champion():
		return Constants.CHAMP_ART_HEIGHT
	return float(source.get("size")) * 2.7


func _lift() -> float:
	var s = source
	if s == null or not ("buffs" in s) or not (s.buffs is Dictionary) or not s.buffs.has("airborne"):
		return 0.0   # HeroControl.lift is 0 without an airborne buff
	return HeroControl.lift(s)


func _pose() -> Dictionary:
	var s = source
	var animator = s.get("animator")
	if animator != null and is_instance_valid(animator):
		return animator.pose()
	if bool(s.get("dead")):
		return {"action": "death", "frame": 5}
	return {"action": "idle", "frame": 0}


func _is_flipped() -> bool:
	var animator = source.get("animator")
	if animator != null and is_instance_valid(animator):
		return animator.is_flipped()
	if _is_champion():
		var facing = source.get("facing")
		return facing is Vector2 and facing.x < 0.0
	return int(source.get("facing_sign")) < 0
