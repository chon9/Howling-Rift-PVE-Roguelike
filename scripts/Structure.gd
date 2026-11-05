extends Node2D
class_name Structure
# Turrets, Inhibitors, Nexus. Attack logic for turrets only.

const kind := "structure"

const SPECS = {
	"turret":       { "hp":3000, "dmg":160, "range":320, "atk_spd":0.95, "w":44, "h":74, "gold":150 },
	"nexus_turret": { "hp":2500, "dmg":110, "range":280, "atk_spd":1.0,  "w":40, "h":62, "gold":100 },
	"inhibitor":    { "hp":4000, "dmg":0,   "range":0,   "atk_spd":0,    "w":48, "h":48, "gold":50, "respawn":180 },
	"nexus":        { "hp":6000, "dmg":0,   "range":0,   "atk_spd":0,    "w":64, "h":84, "gold":0 }
}

var team: int
var type: String
var variant: String = ""
var hp: float
var hp_max: float
var atk_dmg: float
var atk_range: float
var atk_spd: float
var atk_cd: float = 0.0
var gold_val: int
var size: float
var dead: bool = false
var is_targetable: bool = true
var respawn_timer: float = 0.0
var target = null
var consec_hits: int = 0
var aggro_target = null
var aggro_until: float = 0.0
var tower_texture: Texture2D
var art_rect: Rect2
var collision_radius: float = 0.0

const COLLISION_K := 1.06  # solid circle radius vs the base half-width as authored (the 3D card draws it 1.25x)

func provoke(attacker) -> void:
	if is_instance_valid(attacker) and not attacker.dead and world_pos().distance_to(attacker.world_pos()) <= atk_range:
		aggro_target = attacker
		aggro_until = GameState.time + 2.5

var pulse_t: float = 0.0
var hp_bar: ColorRect
var hp_bar_bg: ColorRect

func world_pos() -> Vector2:
	return global_position

func setup(_team: int, _type: String, pos: Vector2, _variant: String = "") -> void:
	team = _team
	type = _type
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/structures/rift-structures.png")
	var column = 0 if team == Constants.BLUE else 512
	match type:
		"turret", "nexus_turret":
			atlas.region = Rect2(column + 64, 0, 400, 576)
			art_rect = Rect2(-52, -126, 104, 150) if type == "turret" else Rect2(-46, -108, 92, 132)
		"inhibitor":
			atlas.region = Rect2(column + 24, 576, 464, 376)
			art_rect = Rect2(-55, -65, 110, 89)
		"nexus":
			atlas.region = Rect2(column + 8, 952, 504, 584)
			art_rect = Rect2(-67, -130, 134, 155)
	var anchor_type = "turret" if type == "nexus_turret" else type
	art_rect = preload("res://scripts/SpriteGrounding.gd").rect("structure_%d_%s" % [team,anchor_type],art_rect.size)
	collision_radius = ViewMath.STRUCTURE_FOOTPRINT[type].x * art_rect.size.x * COLLISION_K
	art_rect.position.y += ViewMath.STRUCTURE_FOOTPRINT[type].y * art_rect.size.y
	atlas.filter_clip = true
	tower_texture = atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	variant = _variant
	var d = SPECS[_type]
	hp = d["hp"]; hp_max = hp
	atk_dmg = d["dmg"]
	if team == Constants.RED and not GameState.is_pvp():
		var scaling = Progression.scaling(GameState.difficulty)
		hp_max *= scaling.structure_health
		hp = hp_max
		atk_dmg *= scaling.structure_damage
	atk_range = d["range"]
	atk_spd = d["atk_spd"]
	gold_val = d["gold"]
	size = max(d["w"], d["h"]) * 0.5 + 6
	global_position = pos
	z_index = Constants.Z_UNITS
	_build_children()

func _build_children() -> void:
	var d = SPECS[type]
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.size = Vector2(d["w"] * 1.3, 7)
	hp_bar_bg.position = Vector2(-d["w"] * 0.65, -d["h"] * 0.5 - 20)
	hp_bar_bg.position.y = art_rect.position.y - 12
	hp_bar_bg.color = Color(0, 0, 0, 0.75)
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.size = Vector2(d["w"] * 1.3 - 2, 5)
	hp_bar.position = Vector2(-d["w"] * 0.65 + 1, -d["h"] * 0.5 - 19)
	hp_bar.position.y = art_rect.position.y - 11
	hp_bar.color = Constants.TEAM_HP[team]
	add_child(hp_bar)

func _draw() -> void:
	if ViewConfig.is_active():
		_draw_ground_3d()
		return
	var tc = Constants.TEAM_COLOR[team]
	var player = GameState.player
	if atk_dmg > 0 and is_instance_valid(player) and player.team != team and global_position.distance_to(player.world_pos()) < atk_range + 140:
		var danger = is_instance_valid(target) and target == player
		draw_arc(Vector2.ZERO, atk_range, 0, TAU, 64, Color(1, 0.25, 0.2, 0.8 if danger else 0.25), 2, true)
	draw_colored_polygon(_ellipse_poly(Vector2.ZERO, art_rect.size.x*0.34, 8, 24), Color(0, 0, 0, 0.4))
	if tower_texture != null:
		draw_texture_rect(tower_texture, art_rect, false)
		var glow_point = Vector2(0, art_rect.position.y + art_rect.size.y * 0.25)
		draw_circle(glow_point, 18, Color(tc.r, tc.g, tc.b, 0.04 + 0.025 * sin(pulse_t * 2)))

# Rift3D (ViewConfig active): ground marks only. The card, plinth and glow are drawn by StructureView3D.
# The contact shadow is a soft pool under the painted stone base that spreads just past its outline.
func _draw_ground_3d() -> void:
	var player = GameState.player
	if atk_dmg > 0 and is_instance_valid(player) and player.team != team and global_position.distance_to(player.world_pos()) < atk_range + 140:
		var danger = is_instance_valid(target) and target == player
		draw_arc(Vector2.ZERO, atk_range, 0, TAU, 64, Color(1, 0.25, 0.2, 0.8 if danger else 0.25), 2, true)
	var shadow: Dictionary = StructureView3D.contact_shadow(type, art_rect, float(ViewConfig.camera_preset().pitch))
	var r: Vector2 = shadow.radii
	for layer in [[1.5, 0.08], [1.32, 0.1], [1.16, 0.14], [1.0, 0.24]]:
		draw_colored_polygon(_ellipse_poly(Vector2.ZERO, r.x * layer[0], r.y * layer[0], 40), Color(0, 0, 0, layer[1]))

func update_frame(delta: float) -> void:
	pulse_t += delta
	if dead:
		if type == "inhibitor":
			respawn_timer -= delta
			if respawn_timer <= 0:
				hp = hp_max; dead = false; is_targetable = true
				visible = true
				get_tree().call_group("game_main", "floating_text",
					global_position, "Inhibitor respawned",
					Constants.TEAM_COLOR[team], true)
		return

	# Draw refresh for pulse
	queue_redraw()
	_sync_bar()

	if atk_dmg == 0: return
	atk_cd -= delta

	# Target priority
	var best = null; var best_score = -INF
	for m in GameState.minions:
		if m.team == team or m.dead: continue
		var d = global_position.distance_to(m.world_pos())
		if d > atk_range: continue
		var sc = -d
		if m.subkind == "siege": sc += 100
		elif m.subkind == "super": sc += 200
		if sc > best_score: best_score = sc; best = m
	if is_instance_valid(aggro_target) and not aggro_target.dead and GameState.time < aggro_until and global_position.distance_to(aggro_target.world_pos()) <= atk_range:
		best = aggro_target
	elif best == null:
		var distance = atk_range
		for c in GameState.champions:
			if c.team == team or c.dead: continue
			var d = global_position.distance_to(c.global_position)
			if d < distance:
				distance = d
				best = c

	if is_instance_valid(target) and not target.dead and \
			global_position.distance_to(target.world_pos()) <= atk_range + 24 and \
			(best == target or (target.kind == "minion" and best != aggro_target)):
		pass  # keep locked target
	else:
		target = best
		consec_hits = 0

	if target != null and atk_cd <= 0:
		var dmg = atk_dmg * (1.0 + 0.25 * min(consec_hits, 2))
		var ang = (target.world_pos() - global_position).angle()
		var dir = Vector2(cos(ang), sin(ang))
		get_tree().call_group("game_main", "spawn_projectile",
			self, global_position, dir, {
				"dmg": dmg, "speed": 900,
				"color": Color(0.4, 0.67, 1.0) if team == Constants.BLUE else Color(1.0, 0.4, 0.4),
				"size": 10, "pierce": 0, "life": 1.5,
				"stun": 0.0, "slow": 0.0, "slow_dur": 0.0,
				"trail": true, "refund_mp_on_kill": 0.0,
				"homing": target, "is_ult": false, "is_turret": true,
				"shape": "bolt"
			})
		atk_cd = 1.0 / atk_spd
		consec_hits += 1

func _sync_bar() -> void:
	if hp_bar == null: return
	var d = SPECS[type]
	hp_bar.size.x = max(0.0, (d["w"] * 1.3 - 2) * hp / hp_max)
	hp_bar.visible = not dead
	hp_bar_bg.visible = not dead

func _ellipse_poly(c: Vector2, rx: float, ry: float, pts: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts):
		var a = TAU * i / float(pts)
		out.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	return out

func is_structure_attackable() -> bool:
	if dead: return false
	# Enforce attack order within team
	var mates = []
	for s in GameState.structures:
		if s.team == team: mates.append(s)
	var outer = null; var inner = null; var inhib = null
	var nxt = []
	var nxs = null
	for s in mates:
		if s.type == "turret" and s.variant == "outer": outer = s
		elif s.type == "turret" and s.variant == "inner": inner = s
		elif s.type == "inhibitor": inhib = s
		elif s.type == "nexus_turret": nxt.append(s)
		elif s.type == "nexus": nxs = s
	if self == outer: return true
	if self == inner: return outer == null or outer.dead
	if self == inhib: return inner == null or inner.dead
	if type == "nexus_turret": return inner == null or inner.dead
	if self == nxs:
		for t in nxt:
			if not t.dead: return false
		return true
	return true
