extends Node2D
class_name Minion
# Minion node. Walks toward enemy base; attacks nearest enemy in sight.

const kind := "minion"
const SPECS = {
	"melee":  { "hp":475, "dmg":12,  "atk_range":36,  "atk_spd":1.25, "speed":92,
				"size":12, "color":Color(0.565, 0.439, 0.667),
				"xp":60, "gold":21, "ai_range":180 },
	"caster": { "hp":290, "dmg":23,  "atk_range":260, "atk_spd":1.0,  "speed":92,
				"size":11, "color":Color(0.667, 0.502, 0.188),
				"xp":32, "gold":14, "ai_range":300 },
	"siege":  { "hp":875, "dmg":42,  "atk_range":300, "atk_spd":1.0,  "speed":88,
				"size":17, "color":Color(0.314, 0.376, 0.439),
				"xp":95, "gold":60, "ai_range":340 },
	"super":  { "hp":1850,"dmg":100, "atk_range":60,  "atk_spd":1.1,  "speed":92,
				"size":21, "color":Color(1.0, 0.812, 0.2),
				"xp":60, "gold":40, "ai_range":180 },
	"tibbers":{ "hp":500, "dmg":60,  "atk_range":60,  "atk_spd":0.9,  "speed":140,
				"size":26, "color":Color(0.267, 0.133, 0.067),
				"xp":0,  "gold":0, "ai_range":260 }
}

var team: int
var subkind: String
var hp: float
var hp_max: float
var atk_dmg: float
var atk_range: float
var atk_spd: float
var atk_cd: float = 0.0
var speed: float
var size: float
var xp_val: int
var gold_val: int
var ai_range: float
var dead: bool = false
var is_targetable: bool = true

var attack_target = null
var stun: float = 0.0
var buffs: Dictionary = {}
var lifetime: float = -1.0  # Only for tibbers
var dir_sign: int = 1       # +1 = push right (blue), -1 = push left (red)
var color: Color

var flash_t: float = 0.0
var animator: UnitAnimator
var anim_action: String = "idle"
var anim_elapsed: float = 0.0
var anim_duration: float = 0.0
var anim_windup: float = 0.2
var anim_released: bool = true
var anim_serial: int = 0
var anim_from: int = 0
var anim_to: int = 5
var attack_windup: float = 0.0
var corpse_spawned: bool = false
var queued_attack_target = null
var unit_texture: Texture2D
const Art = preload("res://scripts/MinionArt.gd")
var animation_time: float = 0.0
var moving: bool = false
var facing_sign: int = 1
var attack_anim: float = 0.0
var previous_visual_position: Vector2
var next_hit_feedback: float = 0.0
var next_damage_label: float = 0.0

var hp_bar_bg: ColorRect
var hp_bar: ColorRect

func world_pos() -> Vector2:
	return global_position

func is_structure_attackable() -> bool:
	return false

func setup(_team: int, _subkind: String, pos: Vector2, scale_mult: float = 1.0) -> void:
	team = _team
	subkind = _subkind
	unit_texture = ActionSpriteArt.texture("minion_"+_subkind)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var cloth = ShaderMaterial.new()
	cloth.shader = preload("res://assets/minions/team-cloth.gdshader")
	cloth.set_shader_parameter("red_team",_team == Constants.RED)
	material = cloth
	var d = SPECS[_subkind]
	hp = d["hp"] * scale_mult
	hp_max = hp
	atk_dmg = d["dmg"] * scale_mult
	atk_range = d["atk_range"]
	atk_spd = d["atk_spd"]
	speed = d["speed"]
	size = d["size"] + 4
	xp_val = int(d["xp"])
	gold_val = int(d["gold"]) * Constants.MINION_GOLD_MULTIPLIER
	ai_range = d["ai_range"]
	color = d["color"]
	dir_sign = 1 if team == Constants.BLUE else -1
	facing_sign = dir_sign
	if _subkind == "tibbers":
		lifetime = 45.0
	global_position = pos
	previous_visual_position = pos
	z_index = Constants.Z_UNITS
	animator = preload("res://scripts/UnitAnimator.gd").new()
	animator.name = "UnitAnimator"
	animator.unit = self
	animator.key = "minion_"+subkind
	add_child(animator)
	_build_children()

func _build_children() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.size = Vector2(size * 2 + 4, 5)
	hp_bar_bg.position = Vector2(-size - 2, art_rect().position.y - 8)
	hp_bar_bg.color = Color(0, 0, 0, 0.7)
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.size = Vector2(size * 2 + 2, 3)
	hp_bar.position = Vector2(-size - 1, art_rect().position.y - 7)
	hp_bar.color = Constants.TEAM_HP[team]
	add_child(hp_bar)
	var status = preload("res://scripts/StatusVisual.gd").new()
	status.name = "StatusVisual"
	status.unit = self
	add_child(status)

func _draw() -> void:
	if ViewConfig.is_active():
		_draw_ground_3d()
		return
	var tc = Constants.TEAM_COLOR[team]
	# Shadow ellipse
	var shadow_poly := PackedVector2Array()
	for i in range(16):
		var a = TAU * i / 16.0
		shadow_poly.append(Vector2(cos(a) * size * 1.1, sin(a) * size * 0.25))
	draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.5))

	# Last-hit glow: if an enemy minion is within player's one-shot AD, pulse gold
	if GameState.player != null and not GameState.player.dead and team != GameState.player.team:
		if hp <= GameState.last_hit_damage(GameState.player,self):
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_arc(Vector2.ZERO, size * 1.3, 0, TAU, 24,
				Color(1.0, 0.86, 0.33, 0.6 + 0.4 * pulse), 2.5 + pulse, true)
			draw_circle(Vector2.ZERO, size * 1.1,
				Color(1.0, 0.86, 0.33, 0.1 * pulse))

	# Team ring on ground
	draw_arc(Vector2.ZERO, size * 0.95, 0, TAU, 20, tc, 1.5, true)

	if unit_texture != null:
		var pose = animator.pose()
		ActionSpriteArt.apply_frame_mask(material,animator.key,pose.action,pose.frame)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing_sign,1))
		draw_texture_rect_region(animator.texture(),Rect2(animator.draw_rect().position-Vector2(0,HeroControl.lift(self)),animator.draw_rect().size),animator.source_rect(),Color(1.10,1.06,1.02) if flash_t>0 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)

# Rift3D: ground marks only (the body is a 3D card); ellipses become true circles on the perspective deck.
func _draw_ground_3d() -> void:
	var tc = Constants.TEAM_COLOR[team]
	draw_circle(Vector2.ZERO, size * 1.35, Color(0, 0, 0, 0.1))
	draw_circle(Vector2.ZERO, size * 1.12, Color(0, 0, 0, 0.14))
	draw_circle(Vector2.ZERO, size * 0.88, Color(0, 0, 0, 0.22))
	if GameState.player != null and not GameState.player.dead and team != GameState.player.team:
		if hp <= GameState.last_hit_damage(GameState.player,self):
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_arc(Vector2.ZERO, size * 1.3, 0, TAU, 24,
				Color(1.0, 0.86, 0.33, 0.6 + 0.4 * pulse), 2.5 + pulse, true)
			draw_circle(Vector2.ZERO, size * 1.1,
				Color(1.0, 0.86, 0.33, 0.1 * pulse))
	draw_arc(Vector2.ZERO, size * 0.95, 0, TAU, 20, tc, 1.5, true)

func art_rect() -> Rect2:
	return ActionSpriteArt.body_rect("minion_"+subkind,size*2.7,facing_sign<0)

func animation_frame() -> int:
	return animator.pose().frame

func _process(delta: float) -> void:
	if GameState.paused or dead: return
	animation_time += delta
	if LanSession.is_client():
		moving = global_position.distance_squared_to(previous_visual_position)>0.01
	previous_visual_position = global_position
	queue_redraw()

func update_frame(delta: float) -> void:
	if dead: return
	ForcedMotion.tick(self,delta)
	moving = false
	attack_anim = maxf(0,attack_anim-delta)
	atk_cd = max(0.0, atk_cd - delta)
	stun = max(0.0, stun - delta)
	if flash_t > 0: flash_t = max(0.0, flash_t - delta * 10.0)

	ExpansionCombat.tick(self,delta)
	if dead:return
	Roster12Combat.tick(self,delta)
	HeroPassives.tick(self,delta)
	for key in buffs.keys():
		buffs[key]["time"] -= delta
		if buffs[key]["time"] <= 0:
			var expired=buffs[key].duplicate();buffs.erase(key);Roster12Combat.expire(self,key,expired)

	# Lifetime (Tibbers)
	if lifetime > 0:
		lifetime -= delta
		if lifetime <= 0: dead = true; return

	if buffs.has("airborne"):stun=maxf(stun,buffs.airborne.time)
	if stun > 0:
		queued_attack_target = null
		attack_windup = 0
		animator.cancel_attack()
		_sync_bar(); return
	if queued_attack_target != null:
		if not is_instance_valid(queued_attack_target) or queued_attack_target.dead or not BrushVision.visible_to(queued_attack_target,team) or world_pos().distance_to(queued_attack_target.world_pos())>_attack_reach(queued_attack_target)+20:
			queued_attack_target = null
			attack_windup = 0
			animator.cancel_attack()
		else:
			attack_windup -= delta
			if attack_windup<=0:
				var victim = queued_attack_target
				queued_attack_target = null
				_attack(victim)
			_sync_bar(); return

	# Target search
	var best = null
	var best_d = ai_range
	for lst in [GameState.minions, GameState.champions, GameState.structures]:
		for u in lst:
			if u == null or u.dead or not u.is_targetable: continue
			if u.team == team or not BrushVision.visible_to(u,team): continue
			if u.kind == "structure" and not u.is_structure_attackable(): continue
			var d = global_position.distance_to(u.world_pos())
			if d < best_d: best_d = d; best = u
	attack_target = best

	if attack_target != null:
		var d = global_position.distance_to(attack_target.world_pos())
		var eff_range = _attack_reach(attack_target)
		if d <= eff_range:
			if atk_cd <= 0:
				queued_attack_target = attack_target
				attack_windup = clampf(0.15/effective_atk_spd(),0.08,0.2)
				if absf(attack_target.world_pos().x-world_pos().x)>0.1: facing_sign = 1 if attack_target.world_pos().x>world_pos().x else -1
				animator.begin_attack(attack_windup)
				atk_cd = 1.0 / effective_atk_spd()
		else:
			_move_toward(attack_target.world_pos(), delta, attack_target)
	else:
		# March toward enemy base along the center lane. Snap Z toward lane center
		# more aggressively so the wave looks like a tidy column, not a drift.
		var tx = Constants.WORLD_W if dir_sign == 1 else 0.0
		var ty = lerp(global_position.y, Constants.LANE_Y, 0.1)
		_move_toward(Vector2(tx, ty), delta)

	global_position.y = clamp(global_position.y,
		Constants.LANE_Y - Constants.LANE_HALF + 10,
		Constants.LANE_Y + Constants.LANE_HALF - 10)
	_sync_bar()
	queue_redraw()

## Attack range to a target; a building can always be hit by a minion touching it.
func _attack_reach(target) -> float:
	var reach = atk_range + target.size * 0.5
	if target.kind == "structure":
		reach = maxf(reach, UnitCollision.contact_distance(self, target) + UnitCollision.REACH_MARGIN)
	return reach

func _move_toward(pt: Vector2, delta: float, ignore = null) -> void:
	var d = global_position.distance_to(pt)
	if d < 0.1: return
	var dir = (UnitCollision.steer(self, pt, UnitCollision.radius_of(self), ignore) - global_position).normalized()
	var mult = 1.0
	if buffs.has("slow"): mult *= (1.0 - buffs["slow"]["pct"])
	moving = true
	if absf(dir.x)>0.1: facing_sign = 1 if dir.x>0 else -1
	global_position += dir * min(d, speed * mult * delta)
	UnitCollision.resolve_minion(self)

func effective_atk_spd() -> float:
	return atk_spd*(.8 if buffs.has("cripple") else 1.)

func _attack(target) -> void:
	animator.release_attack(0.22)
	attack_anim = 0.22
	if absf(target.world_pos().x-global_position.x)>0.1: facing_sign = 1 if target.world_pos().x>global_position.x else -1
	if atk_range >= 100:
		var ang = (target.world_pos() - global_position).angle()
		var dir = Vector2(cos(ang), sin(ang))
		get_tree().call_group("game_main", "spawn_projectile",
			self, global_position, dir, {
				"dmg": atk_dmg, "speed": 500,
				"color": Color(0.667, 0.867, 0.267) if team == Constants.BLUE else Color(0.867, 0.333, 0.267),
				"size": 6, "pierce": 0, "life": 2.0,
				"stun": 0.0, "slow": 0.0, "slow_dur": 0.0,
				"trail": false, "refund_mp_on_kill": 0.0,
				"homing": target, "is_ult": false, "is_turret": false
			})
	else:
		get_tree().call_group("game_main", "deal_damage", self, target, atk_dmg, "auto")

func _sync_bar() -> void:
	if hp_bar == null: return
	hp_bar.size.x = max(0.0, (size * 2 + 2) * hp / hp_max)
	hp_bar.visible = not dead
	hp_bar_bg.visible = not dead

func take_flash() -> void:
	flash_t = 0.45
	animator.hit()
