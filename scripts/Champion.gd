extends Node2D
class_name Champion
# Champion node: painted hero art, combat stats, skill dispatch and bot AI.

const kind := "champion"

var team: int
var hero_key: String
var hero: Dictionary
var owner_peer: int = 0
var sonic_target = null

var hp: float
var hp_max: float
var mp: float
var mp_max: float
var shield: float = 0.0
var hp_regen: float
var mp_regen: float
var ad: float
var atk_range: float
var atk_spd: float
var atk_cd: float = 0.0
var auto_type: String
var move_speed: float
var size: float = Constants.CHAMP_RADIUS + 4
var _blocked_time: float = 0.0

var level: int = 1
var xp: float = 0.0
var cs: int = 0
var gold: int = 1000
# Host-only carry: retain sub-gold income without changing integer wallet/item costs.
var passive_gold_remainder: float = 0.0

var skill_ranks: Array = [0, 0, 0, 0]
var skill_cds:   Array = [0.0, 0.0, 0.0, 0.0]
var skill_points: int = 0
var level_bonus: Dictionary = {}
var comeback_gold_awarded: int = 0
var last_comeback_gold: int = 0
var summoner_cds: Array = [0.0, 0.0]
var summoner_spells: Array = ["flash", "ignite"]
var item_cds: Dictionary = {}
var time_since_damage: float = 10.0
var auto_windup: float = 0.0
var queued_auto_target = null
var bonus_crit: float = 0.0
var bonus_crit_damage: float = 0.0

var is_bot: bool = false
var char_name: String = ""
var dead: bool = false
var respawn_at: float = 0.0
var is_targetable: bool = true

var attack_target = null
var move_target: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var attack_move: bool = false
var attack_move_destination: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(1, 0)
var buffs: Dictionary = {}
var passive_state: Dictionary = {}
var active_cast_id: String = ""
var cast_passive_stun: float = 0.
var last_cast_point: Vector2
var dash_target: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_speed: float = 1400.0
var stun: float = 0.0

var kills: int = 0
var deaths: int = 0
var assists: int = 0
var roster_active: bool = true
var assist_hits: Dictionary = {}
var assist_support: Dictionary = {}

var recall_time: float = -1.0
var recall_duration: float = 1.0

# Inventory and bonus stats from component-based items.
var inventory: Array = ["", "", "", "", "", ""]  # 6 slots, item IDs
var bonus_ad: float = 0.0
var bonus_hp: float = 0.0
var bonus_mp: float = 0.0
var bonus_as: float = 0.0            # +% attack speed (0.25 = +25%)
var bonus_ms: float = 0.0            # +% move speed (0.15 = +15%)
var bonus_lifesteal: float = 0.0     # 0-1 fraction
var bonus_cdr: float = 0.0           # 0-0.4 fraction
var bonus_ap: float = 0.0            # flat damage added to skills
var base_mr: float = 30.0
var bonus_armor: float = 0.0         # LoL armor formula: dmg * 100/(100+armor)
var bonus_mr: float = 0.0
var bonus_armor_pen: float = 0.0
var bonus_magic_pen: float = 0.0
var bonus_lethality: float = 0.0
var bonus_reflect: float = 0.0       # flat damage reflected on auto-hits
var bonus_heal_power: float = 0.0
var bonus_mp_regen: float = 0.0
var last_order_sequence: int = 0
var bonus_hp_regen: float = 0.0      # extra HP regen/sec
# Bot auto-buy state
var stolen_blueprint: Dictionary = {}
var stolen_skill_cursor: int = 0
var stolen_items_complete: bool = false
var purchase_history: Array = []
var augment_history: Array = []
var skill_history: Array = []
var bot_build_idx: int = 0
var bot_buy_t: float = 0.0

# Bot AI
var ai_tick: float = 0.0
var ai_flash_pt: Vector2 = Vector2.ZERO
var ai_ignite_target = null

# Visual
const Grounding = preload("res://scripts/SpriteGrounding.gd")
var name_label: Label
var hp_bar_bg: ColorRect
var shield_bar: ColorRect
var shield_bar_bg: ColorRect
var hp_bar: ColorRect
var mp_bar: ColorRect
var spin_aura: Node2D
var attack_pulse: float = 0.0   # 0..1 scale pulse on auto
var _dust_cooldown: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var manual_move: Vector2 = Vector2.ZERO
var hit_flash: float = 0.0
var run_bonus: Dictionary = {}
var consumable_bonus: Dictionary = {}
var consumable_counts: Dictionary = {}
var dive_target = null
var dive_until: float = -1.0
var dive_entered: bool = false
var brush_revealed_until: float = -1.0
var vision_teams: Array = [true,true]
var dodge_noticed: Dictionary = {}
var dodge_until: float = -1.0
var dodge_destination: Vector2 = Vector2.ZERO
var ambush_until: float = -1.0
var ambush_rest_until: float = -1.0
var flay_charge: float = 1.0
var animator: UnitAnimator
var anim_action: String = "idle"
var anim_elapsed: float = 0.0
var anim_duration: float = 0.0
var anim_windup: float = 0.2
var anim_released: bool = true
var anim_serial: int = 0
var anim_from: int = 0
var anim_to: int = 5
var champion_texture: Texture2D
var permanent_bonus: Dictionary = {}
var difficulty_stats: Dictionary = {}
var chase_target = null
var chase_origin: Vector2
var chase_until: float = 0.0
var chase_rest_until: float = 0.0

func world_pos() -> Vector2:
	return global_position

func rank(i: int) -> int:
	return skill_ranks[i]

func is_structure_attackable() -> bool:
	return false

func disable_roster_slot() -> void:
	roster_active = false
	stop_actions()
	dead = true
	hp = 0
	shield = 0
	buffs.clear()
	assist_hits.clear()
	assist_support.clear()
	is_targetable = false
	respawn_at = INF
	hide()


func setup(_team: int, _hero_key: String, _is_bot: bool, _name: String) -> void:
	team = _team
	hero_key = _hero_key
	hero = ChampionData.CHAMPIONS[_hero_key]
	champion_texture = HeroArt.texture_for(hero_key)
	var sprite_material = ShaderMaterial.new()
	sprite_material.shader = preload("res://assets/minions/team-cloth.gdshader")
	material = sprite_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	is_bot = _is_bot
	difficulty_stats = Progression.scaling(GameState.difficulty if team == Constants.RED and not GameState.is_pvp() else 1)
	if not is_bot and not GameState.is_pvp(): permanent_bonus = Progression.bonuses()
	char_name = _name
	auto_type = hero["auto_type"]
	move_speed = hero["move_speed"] * 1.1
	atk_range = hero["atk_range"]
	atk_spd = hero["atk_spd"]
	z_index = Constants.Z_UNITS
	position = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
	animator = preload("res://scripts/UnitAnimator.gd").new()
	animator.name = "UnitAnimator"
	animator.unit = self
	animator.key = "hero_"+hero_key
	add_child(animator)
	_build_children()
	_apply_items()
	hp = hp_max
	mp = mp_max
	HeroPassives.initialize(self)
	_sync_bars()
	# Level 1: 1 skill point. Bots spend immediately via priority; player chooses.
	skill_points = 1
	if is_bot:
		_bot_spend_points()

func _build_children() -> void:
	# Name
	name_label = Label.new()
	name_label.add_theme_font_override("font",WorldTextFont.get_font())
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 12)
	var name_col: Color
	if not is_bot:
		name_col = Color(1.0, 0.86, 0.52)
	elif team == Constants.BLUE:
		name_col = Color(0.7, 0.85, 1.0)
	else:
		name_col = Color(1.0, 0.6, 0.6)
	name_label.add_theme_color_override("font_color", name_col)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.position = Vector2(-40, -Constants.CHAMP_ART_HEIGHT-33)
	name_label.size = Vector2(80, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	# Shield capacity uses the same HP scale, with its own pale meter above HP.
	shield_bar_bg = ColorRect.new()
	shield_bar_bg.name = "ShieldBarBackground"
	shield_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar_bg.position = Vector2(-Constants.CHAMP_BAR_WIDTH/2-1, -Constants.CHAMP_ART_HEIGHT-20)
	shield_bar_bg.size = Vector2(Constants.CHAMP_BAR_WIDTH+2, 6)
	shield_bar_bg.color = Color(0.03, 0.06, 0.1, 0.95)
	add_child(shield_bar_bg)
	shield_bar = ColorRect.new()
	shield_bar.name = "ShieldBar"
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar.position = Vector2(-Constants.CHAMP_BAR_WIDTH/2, -Constants.CHAMP_ART_HEIGHT-19)
	shield_bar.size = Vector2(Constants.CHAMP_BAR_WIDTH, 4)
	shield_bar.color = Color("e0f8ff")
	add_child(shield_bar)
	# HP bar
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.size = Vector2(Constants.CHAMP_BAR_WIDTH+2, 7)
	hp_bar_bg.position = Vector2(-Constants.CHAMP_BAR_WIDTH/2-1, -Constants.CHAMP_ART_HEIGHT-13)
	hp_bar_bg.color = Color(0, 0, 0, 0.75)
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.size = Vector2(Constants.CHAMP_BAR_WIDTH, 5)
	hp_bar.position = Vector2(-Constants.CHAMP_BAR_WIDTH/2, -Constants.CHAMP_ART_HEIGHT-12)
	hp_bar.color = Constants.TEAM_HP[team]
	add_child(hp_bar)

	mp_bar = ColorRect.new()
	mp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_bar.size = Vector2(Constants.CHAMP_BAR_WIDTH, 2)
	mp_bar.position = Vector2(-Constants.CHAMP_BAR_WIDTH/2, -Constants.CHAMP_ART_HEIGHT-6)
	mp_bar.color = Color(0.33, 0.67, 1.0)
	add_child(mp_bar)
	var status = preload("res://scripts/StatusVisual.gd").new()
	status.name = "StatusVisual"
	status.unit = self
	add_child(status)
	_sync_bars()

func _draw() -> void:
	if ViewConfig.is_active():
		_draw_ground_3d()
		return
	if recall_time >= 0 and not dead:
		var progress = clampf(recall_time / recall_duration, 0.0, 1.0)
		var angle = recall_time * 3.5
		var cyan = Color(0.3, 0.85, 1.0, 0.8)
		draw_colored_polygon(_ellipse_poly(Vector2.ZERO, 40*Constants.CHAMP_GROUND_MARK_SCALE, 15*Constants.CHAMP_GROUND_MARK_SCALE, 48), Color(0.15, 0.6, 1.0, 0.18))
		draw_polyline(_ellipse_poly(Vector2.ZERO, 40*Constants.CHAMP_GROUND_MARK_SCALE, 15*Constants.CHAMP_GROUND_MARK_SCALE, 48), cyan, 2.5, true)
		draw_arc(Vector2.ZERO, 36*Constants.CHAMP_GROUND_MARK_SCALE, -PI / 2, -PI / 2 + TAU * progress, 64, Color(0.7, 1, 1), 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-28, 12)*Constants.CHAMP_ART_SCALE, Vector2(-20, -130)*Constants.CHAMP_ART_SCALE, Vector2(20, -130)*Constants.CHAMP_ART_SCALE, Vector2(28, 12)*Constants.CHAMP_ART_SCALE]), Color(0.3, 0.8, 1, 0.08 + 0.08 * progress))
		for i in range(12):
			var phase = float(i) / 12.0
			var a = angle + phase * TAU
			var rise = fmod(recall_time * 34 + i * 11, 125.0)
			var dot = Vector2(cos(a) * 30, 12 + sin(a) * 10 - rise)*Constants.CHAMP_ART_SCALE
			draw_circle(dot, 2.0 + progress, Color(0.6, 0.95, 1, 1.0 - rise / 150))
	if hit_flash > 0:
		draw_circle(Vector2.ZERO, 30*Constants.CHAMP_GROUND_MARK_SCALE, Color(1, 0.8, 0.5, hit_flash * 3))
	var pulse_scale = 1.0 + attack_pulse * 0.1
	var tc = Constants.TEAM_COLOR[team]
	var tnow = Time.get_ticks_msec() / 1000.0

	# Ult-ready aura (when R is learned, ready, and we have mana)
	if self==GameState.player and skill_ranks.size() > 3 and skill_ranks[3] > 0 and skill_cds[3] <= 0 and mp >= hero["skills"][3]["cost"]:
		var ap = 0.5 + 0.5 * sin(tnow * 3.0)
		draw_arc(Vector2.ZERO, (34 + ap * 3)*Constants.CHAMP_GROUND_MARK_SCALE, 0, TAU, 48,
			Color(1.0, 0.86, 0.33, 0.5 + 0.3 * ap), 2.0, true)
		draw_circle(Vector2.ZERO, (34 + ap * 3)*Constants.CHAMP_GROUND_MARK_SCALE,
			Color(1.0, 0.86, 0.33, 0.05 + 0.05 * ap))

	# Shadow on ground (ellipse)
	draw_colored_polygon(_ellipse_poly(Vector2.ZERO, 24*Constants.CHAMP_GROUND_MARK_SCALE, 6*Constants.CHAMP_GROUND_MARK_SCALE, 20), Color(0, 0, 0, 0.55))

	# Team selection ring on ground
	draw_arc(Vector2.ZERO, 24*Constants.CHAMP_GROUND_MARK_SCALE, 0, TAU, 32, Color(tc.r, tc.g, tc.b, 0.9), 2.5, true)
	draw_arc(Vector2.ZERO, 22*Constants.CHAMP_GROUND_MARK_SCALE, 0, TAU, 32, Color(tc.r, tc.g, tc.b, 0.4), 1.0, true)

	# Player gold ring on ground (over team ring)
	if not is_bot:
		var g_pulse = 0.9 + 0.1 * sin(tnow * 2.0)
		draw_arc(Vector2.ZERO, 28*Constants.CHAMP_GROUND_MARK_SCALE, 0, TAU, 32, Color(1.0, 0.86, 0.33, g_pulse), 2.5, true)

	# Every locomotion and combat state selects a real articulated sprite frame.
	if animator != null:
		var pose = animator.pose()
		ActionSpriteArt.apply_frame_mask(material,animator.key,pose.action,pose.frame)
		material.set_shader_parameter("hit_whiten",clampf(hit_flash/.14,0.,1.)*.7)
		draw_set_transform(Vector2.ZERO,0,Vector2(-1,1) if animator.is_flipped() else Vector2.ONE)
		draw_texture_rect_region(animator.texture(),Rect2(animator.draw_rect().position-Vector2(0,HeroControl.lift(self)),animator.draw_rect().size),animator.source_rect(),Color(1.3,1.15,1.08) if hit_flash>0 else Color.WHITE)
		draw_set_transform(Vector2.ZERO)

	if buffs.has("wind_wall"):
		var direction: Vector2 = buffs.wind_wall.direction
		draw_set_transform(direction*50,direction.angle()+PI/2)
		draw_texture_rect_region(WindArt.texture,Rect2(-90,-25,180,50),WindArt.frame(2,int(tnow*12)%4))
		draw_set_transform(Vector2.ZERO)
	if hero_key == "yasuo" and buffs.has("tempest") and buffs.tempest.stacks == 2:
		draw_arc(Vector2.ZERO,33,-PI,PI,48,Color("c4efed"),2,true)
		for i in range(3):
			var angle = tnow*3+i*TAU/3
			draw_circle(Vector2(cos(angle)*32,12+sin(angle)*12),2,Color("dcffff"))
	if buffs.has("shadow"):
		var offset = buffs.shadow.point-global_position
		draw_set_transform(offset,0,Vector2(-1,1) if animator.is_flipped() else Vector2.ONE)
		draw_texture_rect_region(animator.texture(),Rect2(animator.draw_rect().position-Vector2(0,HeroControl.lift(self)),animator.draw_rect().size),animator.source_rect(),Color(0.6,0.3,0.9,0.5))
		draw_set_transform(Vector2.ZERO)

	# Facing indicator (small triangle on ground, pointing where we face)
	var fdir = facing
	var fx = fdir.x * 20*Constants.CHAMP_GROUND_MARK_SCALE
	var fy = fdir.y * 20*Constants.CHAMP_GROUND_MARK_SCALE
	var perp = Vector2(-fdir.y, fdir.x) * 4
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx, fy),
		Vector2(fx - fdir.x * 6 + perp.x, fy - fdir.y * 6 + perp.y),
		Vector2(fx - fdir.x * 6 - perp.x, fy - fdir.y * 6 - perp.y)
	]), Color(1, 1, 1, 0.85))

	# HP-bar tick marks (segmented, every 100 HP)
	var bar_x = -Constants.CHAMP_BAR_WIDTH/2
	var bar_y = -Constants.CHAMP_ART_HEIGHT-12
	var bar_w = Constants.CHAMP_BAR_WIDTH
	var ticks = int(hp_max / 100.0)
	if ticks > 1 and ticks < 25:
		for i in range(1, ticks):
			var tx = bar_x + bar_w * i * 100.0 / hp_max
			draw_line(Vector2(tx, bar_y), Vector2(tx, bar_y + 5), Color(0, 0, 0, 0.6), 1.0)

# Rift3D: ground marks only (the body is a 3D card). The overlay is seen in true perspective, so the
# hand-squashed 2D ellipses become circles. Never touches the material frame mask or animator flip.
func _draw_ground_3d() -> void:
	var gs = Constants.CHAMP_GROUND_MARK_SCALE
	var tc = Constants.TEAM_COLOR[team]
	var tnow = Time.get_ticks_msec() / 1000.0
	if recall_time >= 0 and not dead:
		var progress = clampf(recall_time / recall_duration, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 40*gs, Color(0.15, 0.6, 1.0, 0.18))
		draw_arc(Vector2.ZERO, 40*gs, 0, TAU, 48, Color(0.3, 0.85, 1.0, 0.8), 2.5, true)
		draw_arc(Vector2.ZERO, 36*gs, -PI / 2, -PI / 2 + TAU * progress, 64, Color(0.7, 1, 1), 3, true)
	if hit_flash > 0:
		draw_circle(Vector2.ZERO, 30*gs, Color(1, 0.8, 0.5, hit_flash * 3))
	if self==GameState.player and skill_ranks.size() > 3 and skill_ranks[3] > 0 and skill_cds[3] <= 0 and mp >= hero["skills"][3]["cost"]:
		var ap = 0.5 + 0.5 * sin(tnow * 3.0)
		draw_arc(Vector2.ZERO, (34 + ap * 3)*gs, 0, TAU, 48, Color(1.0, 0.86, 0.33, 0.5 + 0.3 * ap), 2.0, true)
		draw_circle(Vector2.ZERO, (34 + ap * 3)*gs, Color(1.0, 0.86, 0.33, 0.05 + 0.05 * ap))
	draw_circle(Vector2.ZERO, 31*gs, Color(0, 0, 0, 0.1))
	draw_circle(Vector2.ZERO, 27*gs, Color(0, 0, 0, 0.14))
	draw_circle(Vector2.ZERO, 21*gs, Color(0, 0, 0, 0.22))
	draw_arc(Vector2.ZERO, 24*gs, 0, TAU, 32, Color(tc.r, tc.g, tc.b, 0.9), 2.5, true)
	draw_arc(Vector2.ZERO, 22*gs, 0, TAU, 32, Color(tc.r, tc.g, tc.b, 0.4), 1.0, true)
	if not is_bot:
		var g_pulse = 0.9 + 0.1 * sin(tnow * 2.0)
		draw_arc(Vector2.ZERO, 28*gs, 0, TAU, 32, Color(1.0, 0.86, 0.33, g_pulse), 2.5, true)
	if hero_key == "yasuo" and buffs.has("tempest") and buffs.tempest.stacks == 2:
		draw_arc(Vector2.ZERO, 33, -PI, PI, 48, Color("c4efed"), 2, true)
		for i in range(3):
			var angle = tnow*3+i*TAU/3
			draw_circle(Vector2(cos(angle), sin(angle))*32, 2, Color("dcffff"))
	var fdir = facing
	var fx = fdir.x * 20*gs
	var fy = fdir.y * 20*gs
	var perp = Vector2(-fdir.y, fdir.x) * 4
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx, fy),
		Vector2(fx - fdir.x * 6 + perp.x, fy - fdir.y * 6 + perp.y),
		Vector2(fx - fdir.x * 6 - perp.x, fy - fdir.y * 6 - perp.y)
	]), Color(1, 1, 1, 0.85))

func art_rect() -> Rect2:
	return ActionSpriteArt.body_rect("hero_"+hero_key,Constants.CHAMP_ART_HEIGHT,animator.is_flipped())

func G_sin_t() -> float:
	# Shared animation phase for all living FX
	return Time.get_ticks_msec() / 400.0

func _draw_weapon(pulse: float) -> void:
	# Weapon is held on the right side (positive x) and faces away from body center.
	# We rotate it visually to point in the champion's facing direction.
	var ang = facing.angle()
	match hero_key:
		"ashe":
			# Bow — curved line + arrow
			var cx = cos(ang) * 15; var cy = sin(ang) * 15 - 2
			var bow_pts = PackedVector2Array()
			for i in range(9):
				var ba = -PI / 2.3 + i * (PI / 1.15) / 8.0 + ang + PI / 2
				bow_pts.append(Vector2(cx + cos(ba) * 7, cy + sin(ba) * 7))
			draw_polyline(bow_pts, Color(0.7, 0.5, 0.3), 2.0, true)
			# Arrow (horizontal in facing direction)
			var ax = cos(ang) * 18; var ay = sin(ang) * 18 - 1
			var tipx = cos(ang) * 24; var tipy = sin(ang) * 24 - 1
			draw_line(Vector2(ax, ay), Vector2(tipx, tipy), Color(0.9, 0.9, 1.0), 1.5)
			# Arrow tip
			draw_circle(Vector2(tipx, tipy), 2, Color(0.5, 0.8, 1.0))
		"annie":
			# Teddy bear held at side (Tibbers plushy)
			var tx = cos(ang + PI / 3) * 14
			var ty = sin(ang + PI / 3) * 14 + 2
			draw_circle(Vector2(tx, ty), 5, Color(0.3, 0.15, 0.05))
			draw_circle(Vector2(tx - 2, ty - 2), 1.5, Color(1.0, 0.3, 0))
			draw_circle(Vector2(tx + 2, ty - 2), 1.5, Color(1.0, 0.3, 0))
			# Fire aura around teddy
			draw_circle(Vector2(tx, ty), 7, Color(1.0, 0.5, 0.0, 0.35))
		"garen":
			# Sword — long diagonal line
			var hx = cos(ang) * 10; var hy = sin(ang) * 10 + 2
			var tx = cos(ang) * 28; var ty = sin(ang) * 28 - 4
			# Blade
			draw_line(Vector2(hx, hy), Vector2(tx, ty), Color(0.88, 0.88, 0.95), 3.5)
			# Crossguard (perpendicular)
			var perp = Vector2(-sin(ang), cos(ang)) * 4
			draw_line(Vector2(hx - perp.x, hy - perp.y),
				Vector2(hx + perp.x, hy + perp.y), Color(1.0, 0.75, 0.2), 2.5)
			# Hilt dot
			draw_circle(Vector2(hx - cos(ang) * 2, hy - sin(ang) * 2), 2, Color(0.4, 0.2, 0.0))

func _ellipse_poly(c: Vector2, rx: float, ry: float, pts: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts):
		var a = TAU * float(i) / float(pts)
		out.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	return out

# ============== Stats / Leveling ==============
func _recompute_stats() -> void:
	var lv_ = level - 1
	var prev_hp = hp_max
	var prev_mp = mp_max
	hp_max = hero["hp"] + hero["hp_per_lv"] * lv_ + bonus_hp
	hp_max *= difficulty_stats.get("health", 1.0)
	if buffs.has("dominion"):hp_max+=buffs.dominion.health
	mp_max = 200. if hero_key in ["leesin","zed"] else 0. if hero["mp"]<=0 else hero["mp"] + hero["mp_per_lv"] * lv_ + bonus_mp
	base_mr = hero.get("mr", 35.0 if auto_type == "melee" else 30.0) + 1.25 * lv_
	ad = hero["ad"] + hero["ad_per_lv"] * lv_ + bonus_ad
	hp_regen = hero["hp_regen"] + hero["hp_regen_per_lv"] * lv_ + bonus_hp_regen
	mp_regen = 10. if hero_key in ["leesin","zed"] else (hero["mp_regen"] + hero["mp_regen_per_lv"] * lv_) * 1.25 + bonus_mp_regen
	if prev_hp > 0:
		hp = min(hp_max, hp + (hp_max - prev_hp))
	if prev_mp > 0:
		mp = min(mp_max, mp + (mp_max - prev_mp))

func _apply_items() -> void:
	# Zero all bonus stats, then re-sum from inventory.
	bonus_ad = 0; bonus_hp = 0; bonus_mp = 0
	bonus_as = 0; bonus_ms = 0; bonus_lifesteal = 0
	bonus_cdr = 0; bonus_ap = 0
	bonus_armor = 0; bonus_reflect = 0; bonus_hp_regen = 0
	bonus_crit = 0; bonus_crit_damage = 0
	bonus_heal_power = 0; bonus_mp_regen = 0
	bonus_mr=0;bonus_armor_pen=0;bonus_magic_pen=0;bonus_lethality=0
	for id in inventory:
		if id == "": continue
		var it = ItemData.ITEMS[id]
		for stat in it["stats"].keys():
			var v: float = it["stats"][stat]
			match stat:
				"bonus_ad":        bonus_ad += v
				"bonus_hp":        bonus_hp += v
				"bonus_mp":        bonus_mp += v
				"bonus_as":        bonus_as += v
				"bonus_ms":        bonus_ms += v
				"bonus_lifesteal": bonus_lifesteal += v
				"bonus_cdr":       bonus_cdr += v
				"bonus_ap":        bonus_ap += v
				"bonus_armor":     bonus_armor += v
				"bonus_mr": bonus_mr += v
				"bonus_armor_pen": bonus_armor_pen = maxf(bonus_armor_pen,v)
				"bonus_magic_pen": bonus_magic_pen = maxf(bonus_magic_pen,v)
				"bonus_lethality": bonus_lethality += v
				"bonus_reflect":   bonus_reflect += v
				"bonus_heal_power": bonus_heal_power += v
				"bonus_mp_regen": bonus_mp_regen += v
				"bonus_hp_regen":  bonus_hp_regen += v
				"bonus_crit": bonus_crit += v
				"bonus_crit_damage": bonus_crit_damage += v
	for stat in run_bonus:
		set(stat, get(stat) + run_bonus[stat])
	for stat in consumable_bonus:
		set(stat, get(stat) + consumable_bonus[stat])
	for stat in level_bonus:
		set(stat, get(stat) + level_bonus[stat])
	for stat in permanent_bonus:
		set(stat, get(stat) + permanent_bonus[stat])
	bonus_cdr = min(bonus_cdr, 0.4)
	if inventory.has("archangel"): bonus_ap += (hero.mp + hero.mp_per_lv * (level - 1) + bonus_mp) * 0.025 if hero.mp>0 and hero_key not in ["leesin","zed"] else 0.
	if buffs.get("storm_shield",{}).get("shield",0.)>0:bonus_ad+=buffs.storm_shield.get("ad",0.)
	if inventory.has("rabadon"): bonus_ap *= 1.3
	if buffs.has("flowing"):bonus_ap+=20.
	if hero_key=="syndra" and passive_state.get("transcendent_ap",false):bonus_ap*=1.15
	_recompute_stats()
	if dead: hp = 0

func can_shop() -> bool:
	return is_bot or dead or world_pos().distance_to(Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R) <= 170
func try_buy_item(id: String) -> bool:
	if LanSession.is_local(self):
		LanSession.send_command("buy",{"id":id})
		return true
	if not can_shop() or not ItemData.ITEMS.has(id): return false
	var plan = ItemData.purchase_plan(id, inventory, consumable_counts)
	if not plan.valid or gold < plan.cost: return false
	var next_inventory = inventory.duplicate()
	for slot in plan.consume: next_inventory[slot] = ""
	if ItemData.ITEMS[id].get("consumable",false):
		consumable_counts[id] = consumable_counts.get(id,0)+1
		for stat in ItemData.ITEMS[id].stats:
			consumable_bonus[stat] = consumable_bonus.get(stat,0.0)+ItemData.ITEMS[id].stats[stat]
	else:
		next_inventory[plan.slot] = id
	if not ItemData.ITEMS[id].get("consumable",false):
		purchase_history.append(id)
		if purchase_history.size()>128:purchase_history.pop_front()
	gold -= plan.cost
	inventory = next_inventory
	_apply_items()
	if not is_bot:
		get_tree().call_group("game_main", "play_sfx", "coin", self)
		get_tree().call_group("game_main", "floating_text", world_pos(), "+ " + ItemData.ITEMS[id].name, Color("ffe090"), false)
	return true
func try_sell_item(slot: int) -> bool:
	if LanSession.is_local(self):
		LanSession.send_command("sell",{"index":slot})
		return true
	if not can_shop() or slot < 0 or slot >= 6 or inventory[slot] == "": return false
	gold += ItemData.sell_value(inventory[slot])
	inventory[slot] = ""
	_apply_items()
	return true


func _bot_auto_buy(delta: float) -> void:
	bot_buy_t -= delta
	if bot_buy_t > 0: return
	bot_buy_t = 3.0
	# Spend catch-up gold through normal prices/recipes, with a bounded purchase batch.
	for purchase in range(6):
		if not _bot_buy_next():break

func _bot_buy_next() -> bool:
	if not stolen_blueprint.is_empty():return BuildStealer.buy_next(self)
	return _bot_buy_original()

func _bot_buy_original(continuation: bool=false) -> bool:
	var build = ItemData.BUILD_ORDERS.get(hero_key, [])
	if continuation:
		# Keep following this hero's original plan after the saved purchases.
		# Owned upgrades cover their components. Full slots or alternate boots
		# must not prevent later recipe upgrades or late-game consumables.
		for id in build:
			if inventory.any(func(owned):return owned!="" and (owned==id or BuildStealer.contains_component(owned,id))):continue
			var plan=ItemData.purchase_plan(id,inventory,consumable_counts)
			if not plan.valid:continue
			return try_buy_item(id)
		return BuildStealer.buy_training(self)
	if bot_build_idx >= build.size():
		return _bot_buy_training()
	var next_id = build[bot_build_idx]
	if inventory.has(next_id):
		bot_build_idx += 1
		return true
	if gold >= ItemData.purchase_plan(next_id, inventory).cost and try_buy_item(next_id):
		bot_build_idx += 1
		return true
	return false

func _bot_buy_training() -> bool:
	var preferred = "training_ap" if bonus_ap > bonus_ad else "training_ad"
	if hero_key in ["garen","darius","malphite","thresh"]: preferred = "training_hp"
	var choices = [preferred,"training_hp","training_armor","training_mr"]
	var cheapest = preferred
	for id in choices:
		if MatchTraining.price(id,consumable_counts) < MatchTraining.price(cheapest,consumable_counts): cheapest = id
	return try_buy_item(cheapest)

func grant_comeback_gold() -> int:
	last_comeback_gold=0
	if GameState.is_pvp() or not is_bot or team!=Constants.RED:return 0
	last_comeback_gold=Constants.enemy_death_gold(deaths)
	gold+=last_comeback_gold;comeback_gold_awarded+=last_comeback_gold
	if last_comeback_gold>0:bot_buy_t=0.
	return last_comeback_gold

func can_level_skill(idx: int) -> bool:
	# Check if a specific skill can be ranked up right now.
	if idx < 0 or idx >= 4 or skill_points <= 0: return false
	var sk = hero["skills"][idx]
	if skill_ranks[idx] >= sk["max"]: return false
	if idx < 3 and skill_ranks[idx] >= int((level + 1) / 2): return false
	if idx == 3:  # R gating by character level
		var r = skill_ranks[3]
		if r == 0 and level < 6: return false
		if r == 1 and level < 11: return false
		if r == 2 and level < 16: return false
	return true

func try_level_skill(idx: int) -> bool:
	if LanSession.is_local(self):
		LanSession.send_command("rank",{"index":idx})
		return true
	if not can_level_skill(idx): return false
	skill_ranks[idx] += 1
	if skill_history.size()<18:skill_history.append({"index":idx,"rank":skill_ranks[idx]})
	if hero_key=="vayne" and idx==1:ExpansionKits.tick(self,0.)
	skill_points -= 1
	_recompute_stats()
	get_tree().call_group("game_main", "floating_text",
		global_position, "%s +1" % hero["skills"][idx]["key"],
		Color(1.0, 0.86, 0.33), false)
	return true

func _bot_spend_points() -> void:
	# Bots dump their points immediately following champion priority.
	var prio = hero["priority"]
	while skill_points > 0:
		var picked = -1
		var path=stolen_blueprint.get("skill_order",[])
		while stolen_skill_cursor<path.size() and skill_ranks[path[stolen_skill_cursor].index]>=path[stolen_skill_cursor].rank:stolen_skill_cursor+=1
		if stolen_skill_cursor<path.size() and can_level_skill(path[stolen_skill_cursor].index):picked=path[stolen_skill_cursor].index
		for idx in ([] if picked>=0 else prio):
			if can_level_skill(idx):
				picked = idx; break
		if picked < 0: break
		try_level_skill(picked)

func grant_xp(amount: float) -> void:
	if dead or level>=Constants.MAX_LEVEL or not is_finite(amount) or amount<=0:return
	var multiplier=difficulty_stats.get("experience",1.) if is_bot and team==Constants.RED and not GameState.is_pvp() else 1.
	xp += amount*multiplier
	while level < Constants.MAX_LEVEL and xp >= Constants.xp_to_level(level):
		xp -= Constants.xp_to_level(level)
		level += 1
		HeroPassives.on_level(self)
		if hero_key == "kayle" and level >= 6:
			atk_range = 350
			auto_type = "ranged"
		var available=0
		for index in range(4):available+=hero.skills[index].max-skill_ranks[index]
		if skill_points<available:skill_points+=1
		else:
			for stat in Constants.VETERAN_STATS:level_bonus[stat]=level_bonus.get(stat,0.)+Constants.VETERAN_STATS[stat]
		_apply_items()
		if is_bot:
			_bot_spend_points()
		hp = min(hp_max, hp + 60)
		mp = min(mp_max, mp + 40)
		get_tree().call_group("game_main", "on_level_up", self)
	if level>=Constants.MAX_LEVEL:xp=0.

# ============== Buffs helpers ==============
func effective_move_speed() -> float:
	var m = move_speed * SupportCombat.move_multiplier(self) * (1.0 + bonus_ms) * difficulty_stats.get("speed", 1.0)
	if buffs.has("haste"): m *= buffs["haste"]["mult"]
	if buffs.has("ghost"): m *= buffs.ghost.mult
	if inventory.has("force_nature") and buffs.has("nature_guard"): m *= 1.08
	if buffs.has("slow"): m *= (1.0 - buffs["slow"]["pct"])
	return m * HeroPassives.move_speed(self)

func effective_attack_range() -> float:
	return HeroPassives.attack_range(self,attack_target) + (100 if buffs.has("rockets") else 0) + (40 if buffs.has("exile") else 0)

func effective_atk_spd() -> float:
	var m = atk_spd * (1.0 + bonus_as + (.2 if buffs.has("ardent") else 0.)) * difficulty_stats.get("attack_speed", 1.0) * HeroPassives.attack_speed(self)
	if buffs.has("roster_as"): m *= buffs.roster_as.mult
	if buffs.has("focus"): m *= 1.4
	if buffs.has("cripple"): m *= .8
	return m

func effective_cd(base_cd: float) -> float:
	return base_cd * 0.8 * (1.0 - bonus_cdr)

# ============== Public: cast skill ==============
# Called by Main.gd (player) or AI. Returns false if didn't cast.
func try_cast_skill(idx: int, pt: Vector2) -> bool:
	if idx < 0 or idx >= 4: return false
	if LanSession.is_local(self):
		LanSession.send_command("skill",{"index":idx,"point":pt})
		return true
	if dead or stun > 0: return false
	if buffs.has("monsoon") and idx!=3: return false
	if buffs.has("silence"): return false
	if buffs.has("parry") or (buffs.has("artillery") and idx!=3) or (buffs.has("culling") and idx!=3):return false
	var look = (pt-world_pos()).normalized()
	var rooted_dash = buffs.has("root") and ((hero_key in ["leesin","thresh","riven"] and idx==0) or (hero_key=="renekton" and idx==2) or (hero_key=="zed" and idx==1))
	if not rooted_dash and NewHeroKits.recast(self,idx,pt):
		if look.length_squared()>0.01: facing = look
		HeroPassives.on_cast(self,idx)
		BrushVision.reveal(self)
		animator.start(["q","w","e","r"][idx],0.3)
		if hero_key == "leesin" and idx == 0: anim_from=3
		get_tree().call_group("game_main","play_sfx","dash",self)
		return true
	if skill_ranks[idx] <= 0:
		get_tree().call_group("game_main", "floating_text",
			global_position, "Not learned", Color(1,1,0.3), false); return false
	if skill_cds[idx] > 0: return false
	var sk = hero["skills"][idx]
	if buffs.has("root") and sk.cast_id in ["ezreal_e","ahri_r","yasuo_e","leesin_w","katarina_e","zed_r","malphite_r","vayne_q","riven_q","riven_e","renekton_e","xinzhao_e","fiora_q","lucian_e"]:return false
	if sk.kind=="passive":return false
	if mp < sk["cost"]:
		get_tree().call_group("game_main", "floating_text",
			global_position, "No energy" if hero_key in ["leesin","zed"] else "No mana", Color(0.3,0.7,1.0), false); return false
	var cast_pt = pt
	# Range clamp
	if sk["range"] > 0:
		var d = global_position.distance_to(pt)
		if d > sk["range"]:
			cast_pt = global_position + (pt - global_position).normalized() * sk["range"]
	# Dispatch
	active_cast_id=sk.cast_id;last_cast_point=cast_pt;cast_passive_stun=HeroPassives.prepare_cast(self,idx)
	var ok = _dispatch_cast(sk["cast_id"], cast_pt)
	active_cast_id="";cast_passive_stun=0.
	if not ok: return false
	HeroPassives.on_cast(self,idx)
	BrushVision.reveal(self)
	if sk.range>0 and look.length_squared()>0.01: facing = look
	animator.start(["q","w","e","r"][idx],0.42 if idx==3 else 0.3)
	if hero_key == "leesin" and idx == 0: anim_to=2
	if inventory.has("sheen") or inventory.has("trinity") or inventory.has("essence_reaver"): buffs["spellblade"] = {"time":5.0}
	mp -= sk["cost"]
	skill_cds[idx] = effective_cd(sk["cd"])
	if hero_key=="syndra" and idx==0 and passive_state.get("splinters",0)>=40:skill_cds[0]=0. if passive_state.get("q_charges",0)>0 else passive_state.q_recharge
	if idx==3 and passive_state.get("reset_r",false):skill_cds[3]=0.;passive_state.erase("reset_r")
	if recall_time >= 0: recall_time = -1.0
	if not (hero_key=="caitlyn" and idx==3):
		get_tree().call_group("game_main", "play_sfx", "ultimate" if idx == 3 else "spell", self)
	if hero_key != "yasuo" and not ExpansionRoster.KEYS.has(hero_key) and not hero_key in RosterExpansion12.KEYS and not hero_key in SupportRoster.KEYS: get_tree().call_group("game_main", "spawn_spell_burst", self, global_position, 45.0 if idx != 3 else 70.0)
	return true

func _dispatch_cast(cast_id: String, pt: Vector2) -> bool:
	if hero_key in SupportRoster.KEYS: return SupportKits.cast(self,cast_id,pt)
	if hero_key in RosterExpansion12.KEYS: return Roster12Kits.cast(self,cast_id,pt)
	if ExpansionRoster.KEYS.has(hero_key): return ExpansionKits.cast(self,cast_id,pt)
	match cast_id:
		"lux_q": _lux_q(pt)
		"lux_w": _lux_w()
		"lux_e": _lux_e(pt)
		"lux_r": _lux_r(pt)
		"ahri_q": _ahri_q(pt)
		"ahri_w": return _spirit_bolts(35 + 15 * rank(1))
		"ahri_e": _ahri_e(pt)
		"ahri_r": _ahri_r(pt)
		"ezreal_q": _ezreal_q(pt)
		"ezreal_w": _ezreal_w(pt)
		"ezreal_e": _ezreal_e(pt)
		"ezreal_r": _ezreal_r(pt)
		"ashe_q":  _ashe_q()
		"ashe_w":  _ashe_w(pt)
		"ashe_e":  _ashe_e(pt)
		"ashe_r":  _ashe_r(pt)
		"annie_q": return _annie_q(pt)
		"annie_w": _annie_w(pt)
		"annie_e": _annie_e()
		"annie_r": _annie_r(pt)
		"garen_q": _garen_q()
		"garen_w": _garen_w()
		"garen_e": _garen_e()
		"garen_r": return _garen_r(pt)
		_: return NewHeroKits.cast(self,cast_id,pt)
	return true

# ============== Skill implementations ==============
func _spawn_projectile(dir: Vector2, dmg: float, speed: float, color: Color,
	size_px: float, pierce: int = 0, life: float = 2.0,
	stun_time: float = 0.0, slow_pct: float = 0.0, slow_dur: float = 0.0,
	trail: bool = false, refund_mp_on_kill: float = 0.0,
	homing = null, is_ult: bool = false, is_turret: bool = false,
	shape: String = "orb", damage_type: String = "skill", boomerang: bool = false, mark_bonus: float = 0.0) -> void:
	get_tree().call_group("game_main", "spawn_projectile",
		self, global_position, dir, {
			"dmg": dmg, "speed": speed, "color": color, "size": size_px,
			"pierce": pierce, "life": life, "stun": stun_time,
			"slow": slow_pct, "slow_dur": slow_dur, "trail": trail,
			"refund_mp_on_kill": refund_mp_on_kill, "homing": homing,
			"is_ult": is_ult, "is_turret": is_turret, "shape": shape, "damage_type": damage_type,
			"boomerang": boomerang, "mark_bonus": mark_bonus
		})

func _spawn_aoe(pos: Vector2, radius: float, dmg: float, color: Color,
	duration: float, cone_ang: float = -999.0, arc: float = 0.0) -> void:
	get_tree().call_group("game_main", "spawn_aoe", self, pos, {
		"radius": radius, "dmg": dmg, "color": color,
		"duration": duration, "cone_ang": cone_ang, "arc": arc
	})

# ----- Ashe -----
func _lux_q(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 70 + 30 * rank(0), 650, Color("ffe9a5"), 10, 1, 0.9, 1.5, 0, 0, true)

func _lux_w() -> void:
	for ally in GameState.champions:
		if ally.team == team and not ally.dead and ally.world_pos().distance_to(global_position) <= 250:
			CombatEffects.shield(ally,"prismatic_shield",60 + 35 * rank(1) + bonus_ap * 0.5,3.,self)
			HeroPassives.support(self,ally)
	_spawn_aoe(global_position, 250, 0, Color("ffe9a5"), 0.45)

func _lux_e(pt: Vector2) -> void:
	get_tree().call_group("game_main", "spawn_aoe", self, pt, {"radius":120, "dmg":65 + 35 * rank(2), "duration":0.5, "color":Color("ffe9a5"), "slow":0.35, "slow_dur":2.0})

func _lux_r(pt: Vector2) -> void:
	get_tree().call_group("game_main", "spawn_beam", self, (pt - global_position).normalized(), 1100.0, 32.0, 180 + 100 * rank(3), Color("fff2ba"))

func _ahri_q(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 45 + 25 * rank(0), 650, Color("87eff5"), 13, 99, 1.6, 0, 0, 0, true, 0, null, false, false, "orb", "skill", true)

func _spirit_bolts(damage: float) -> bool:
	var target = GameState.find_nearest_enemy(self, global_position, 420)
	if target == null: return false
	for i in range(3):
		var direction = Vector2.from_angle((target.world_pos() - global_position).angle() + (i - 1) * 0.4)
		_spawn_projectile(direction, damage, 550, hero.accent, 8, 0, 1.2, 0, 0, 0, true, 0, target)
	return true

func _ahri_e(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 55 + 25 * rank(2), 650, Color("f59ad0"), 12, 0, 0.9, 1.4, 0, 0, true, 0, null, false, false, "heart")

func _ahri_r(pt: Vector2) -> void:
	dash_target = GameState.clamp_walkable(pt)
	is_dashing = true
	dash_speed = 1300
	_spirit_bolts(45 + 25 * rank(3))

func _ezreal_q(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 20 + 20 * rank(0) + ad * 1.1, 850, Color("7cecff"), 8, 0, 0.8, 0, 0, 0, true, 0, null, false, false, "bolt")

func _ezreal_w(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 0, 650, Color("edcd7f"), 11, 0, 0.9, 0, 0, 0, true, 0, null, false, false, "orb", "mark", false, 60 + 30 * rank(1))

func _ezreal_e(pt: Vector2) -> void:
	get_tree().call_group("game_main", "spawn_impact", global_position, hero.accent, 24)
	global_position = GameState.clamp_walkable(pt)
	get_tree().call_group("game_main", "spawn_impact", global_position, hero.accent, 24)
	var target = GameState.find_nearest_enemy(self, global_position, 420)
	if target != null:
		_spawn_projectile((target.world_pos() - global_position).normalized(), 50 + 30 * rank(2), 750, hero.accent, 10, 0, 1.0, 0, 0, 0, true, 0, target)

func _ezreal_r(pt: Vector2) -> void:
	_spawn_projectile((pt - global_position).normalized(), 150 + 100 * rank(3) + ad * 0.8, 650, Color("91eafa"), 30, 99, 2.2, 0, 0, 0, true, 0, null, true, false, "wave")

func _ashe_q() -> void:
	buffs["focus"] = { "time": 4.0 }

func _ashe_w(pt: Vector2) -> void:
	var base_ang = (pt - global_position).angle()
	var dmg = 20.0 + 20.0 * rank(1) + ad * 0.6
	var volley_hits: Array=[]
	for i in range(-4, 5):
		var a = base_ang + i * 0.09
		var dir = Vector2(cos(a), sin(a))
		_spawn_projectile(dir, dmg, 620, Color(0.533, 0.867, 1.0), 7, 0, 1.5,
			0.0, 0.3, 2.0, true, 0.0, null, false, false, "arrow")
		if not GameState.projectiles.is_empty():GameState.projectiles.back().hit_set=volley_hits

func _ashe_e(pt: Vector2) -> void:
	var d = min(300.0, global_position.distance_to(pt))
	var dir = (pt - global_position).normalized()
	dash_target = GameState.clamp_walkable(global_position + dir * d)
	is_dashing = true
	dash_speed = 1400

func _ashe_r(pt: Vector2) -> void:
	var ang = (pt - global_position).angle()
	var dir = Vector2(cos(ang), sin(ang))
	var dmg = 150.0 + 100.0 * rank(3) + ad * 0.6
	_spawn_projectile(dir, dmg, 700, Color(0.4, 1.0, 1.0), 16, 0, 4.0,
		1.5 + rank(3) * 0.3, 0.0, 0.0, true, 0.0, null, true, false, "ice")
	get_tree().call_group("game_main", "camera_shake", 0.2, 4.0,world_pos())

# ----- Annie -----
func _annie_q(pt: Vector2) -> bool:
	var ang = (pt - global_position).angle()
	var dir = Vector2(cos(ang), sin(ang))
	var locked = GameState.find_target_at(pt, team, 40)
	if locked==null or locked.kind=="structure":return false
	_spawn_projectile(dir, 60.0 + 25.0 * rank(0) + ad * 0.3, 600,
		Color(1.0, 0.33, 0.0), 12, 0, 2.0, 0.0, 0.0, 0.0, true, 60.0,
		locked, false, false, "fireball")
	return true

func _annie_w(pt: Vector2) -> void:
	var ang = (pt - global_position).angle()
	var cx = global_position
	_spawn_aoe(cx, 300, 70.0 + 30.0 * rank(1) + ad * 0.3,
		Color(1.0, 0.2, 0.0), 0.5, ang, 1.2)
	get_tree().call_group("game_main", "camera_shake", 0.08, 2.0,world_pos())

func _annie_e() -> void:
	CombatEffects.shield(self,"molten_shield",50.0 + 30.0 * rank(2),3.)
	buffs["molten"] = { "time": 3.0, "reflect": 20.0 + 10.0 * rank(2) }

func _annie_r(pt: Vector2) -> void:
	_spawn_aoe(pt, 200, 150.0 + 125.0 * rank(3) + ad * 0.3,
		Color(1.0, 0.27, 0.0), 0.6)
	get_tree().call_group("game_main", "spawn_tibbers", self, pt)
	get_tree().call_group("game_main", "camera_shake", 0.4, 8.0,world_pos())
	get_tree().call_group("game_main", "camera_flash", 0.3, Color(1.0, 0.59, 0.2),world_pos())

# ----- Garen -----
func _garen_q() -> void:
	buffs["decisive"] = { "time": 4.5, "bonus": 30.0 + 25.0 * rank(0) + ad * 0.4, "used": false }
	buffs["haste"]    = { "time": 1.5, "mult": 1.3 }

func _garen_w() -> void:
	CombatEffects.shield(self,"courage_shield",60.0 + 40.0 * rank(1),3.)
	buffs["courage"] = { "time": 3.0, "dr": 0.3 + 0.03 * rank(1) }

func _garen_e() -> void:
	buffs["spin"] = { "time": 3.0, "tick": 0.0, "dmg": 12.0 + 8.0 * rank(2) + ad * 0.4 }

func _garen_r(pt: Vector2) -> bool:
	var e = GameState.find_nearest_enemy(self, pt, 180)
	if e == null or e.kind != "champion" or global_position.distance_to(e.world_pos()) > 180 + e.size * 0.3:
		get_tree().call_group("game_main", "floating_text",
			global_position, "No target!", Color(1,1,0.3), false)
		return false
	var base = 150.0 + 150.0 * rank(3)
	var missing = e.hp_max - e.hp
	var dmg = base + missing * (0.2 + 0.05 * rank(3))
	_spawn_aoe(e.global_position, 90, 0, Color(1.0, 1.0, 0.4), 0.4)
	get_tree().call_group("game_main", "deal_damage", self, e, dmg, "exec")
	get_tree().call_group("game_main", "camera_shake", 0.3, 6.0,world_pos())
	get_tree().call_group("game_main", "camera_flash", 0.2, Color(1.0, 0.9, 0.6),world_pos())
	return true

# ============== Per-frame update called by Main ==============
func update_frame(delta: float) -> void:
	tick_cooldowns(delta)
	if dead:
		return
	if buffs.has("cc_guard"):
		stun=0.;buffs.erase("silence")
	hit_flash = max(0.0, hit_flash - delta)

	ForcedMotion.tick(self,delta)
	ExpansionKits.tick(self,delta)
	ExpansionCombat.tick(self,delta)
	SupportKits.tick(self,delta)
	SupportCombat.tick(self,delta)
	Roster12Combat.tick(self,delta)
	HeroPassives.tick(self,delta)
	if dead:return
	# Tick damage-over-time before expiry so the final half-second is not lost.
	if buffs.has("ignite"):
		var ignite=buffs.ignite
		ignite.tick=ignite.get("tick",0.)+minf(delta,ignite.time)
		while ignite.tick>=.5 and not dead:
			ignite.tick-=.5
			get_tree().call_group("game_main","deal_damage",ignite.src,self,ignite.total/10.,"exec")
	if dead:return
	# Buff decay
	var expired := []
	for k in buffs.keys():
		buffs[k]["time"] -= delta * (1.0 / .75 if inventory.has("mercury_treads") and k in ["slow","silence"] else 1.0)
		if buffs[k]["time"] <= 0: expired.append(k)
	for k in expired:
		ExpansionCombat.expire(self,k)
		var value = buffs[k].duplicate()
		buffs.erase(k)
		if k in ["flowing","storm_shield"]:_apply_items()
		NewHeroKits.expire(self,k,value)


	# Cooldowns
	if dead: return
	stun = max(0.0, stun - delta * (1.0 / .75 if inventory.has("mercury_treads") else 1.0))
	if buffs.has("airborne"):stun=maxf(stun,buffs.airborne.time)
	if attack_pulse > 0: attack_pulse = max(0.0, attack_pulse - delta * 10.0)

	# Recall
	if recall_time >= 0:
		recall_time += delta
		if recall_time >= recall_duration:
			global_position = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
			recall_time = -1.0
			_fountain_recovery(delta)
		_sync_bars()
		queue_redraw()
		return
	_fountain_recovery(delta)
	if stun > 0:
		cancel_auto()
		_sync_bars()
		return

	# Regen
	hp = min(hp_max, hp + hp_regen * delta * ExpansionCombat.healing_multiplier(self))
	mp = min(mp_max, mp + mp_regen * delta)

	time_since_damage += delta
	if inventory.has("warmog") and time_since_damage >= 6:
		hp = minf(hp_max, hp + hp_max * 0.02 * delta * ExpansionCombat.healing_multiplier(self))
	if queued_auto_target != null:
		if not is_instance_valid(queued_auto_target) or queued_auto_target.dead or not queued_auto_target.is_targetable or not BrushVision.visible_to(queued_auto_target,team):
			cancel_auto()
		else:
			auto_windup -= delta
			if auto_windup <= 0:
				var victim = queued_auto_target
				queued_auto_target = null
				if world_pos().distance_to(victim.world_pos()) <= auto_attack_reach(victim)+20:
					_perform_auto(victim)
				else:
					# A target escaping before contact should not consume a full attack cooldown.
					auto_windup = 0
					animator.cancel_attack()
					atk_cd = 0

	if buffs.has("artillery") or buffs.has("parry") or buffs.has("deadeye") or buffs.has("monsoon"):
		_sync_bars();queue_redraw();return

	# Dash
	if buffs.has("root"):is_dashing=false
	if is_dashing:
		dash_target = GameState.clamp_walkable(dash_target)
		var d = global_position.distance_to(dash_target)
		if d < 2:
			is_dashing = false
		else:
			var dir = (dash_target - global_position).normalized()
			var step = dash_speed * delta
			global_position += dir * min(step, d)

	# Spin aura toggling
	if buffs.has("spin"):
		buffs["spin"]["tick"] -= delta
		if spin_aura == null:
			spin_aura = _make_spin_aura()
			add_child(spin_aura)
		if buffs["spin"]["tick"] <= 0:
			buffs["spin"]["tick"] = 0.25
			var tgts = GameState.champions + GameState.minions + GameState.structures
			for e in tgts:
				if e == null or e.dead or e.team == team or not e.is_targetable: continue
				if e.kind == "structure" and not e.is_structure_attackable(): continue
				if global_position.distance_to(e.world_pos()) < buffs.spin.get("radius",72) + e.size * 0.3:
					get_tree().call_group("game_main", "deal_damage",
						self, e, buffs["spin"]["dmg"], "skill")
	elif spin_aura != null:
		spin_aura.queue_free()
		spin_aura = null

	# AI
	if is_bot:
		_run_bot_ai(delta)
		_bot_auto_buy(delta)

	# Resolve invalid target
	if attack_target != null and (not is_instance_valid(attack_target) or attack_target.dead or not attack_target.is_targetable or not BrushVision.visible_to(attack_target,team)):
		attack_target = null
		has_move_target = false
		if attack_move:
			move_target = attack_move_destination
			has_move_target = true

	# Combat behaviour: acquire before moving, then approach the edge of attack range.
	var steering = manual_move.length_squared() > 0.01
	if attack_move and attack_target == null:
		attack_target = GameState.find_nearest_enemy(self,global_position,effective_attack_range()+30) if is_bot else GameState.find_attack_move_target(self,attack_move_destination)
	if is_bot and attack_target != null and not BotSafety.can_enter(self,BotSafety.approach(self,attack_target),attack_target.kind == "champion"):
		cancel_auto()
		attack_target = null
		attack_move = false
	if attack_target != null:
		var offset = attack_target.world_pos()-global_position
		var distance = offset.length()
		var reach = auto_attack_reach(attack_target)
		if queued_auto_target != null:
			has_move_target = false
		elif distance > reach and not steering:
			move_target = GameState.clamp_walkable(attack_target.world_pos()-offset.normalized()*maxf(0,reach-6))
			has_move_target = true
		elif distance <= reach:
			has_move_target = false
			if distance > 0.01: facing = offset.normalized()
			if atk_cd <= 0 and (not steering or is_bot):
				queued_auto_target = attack_target
				auto_windup = clampf(0.18/effective_atk_spd(),0.07,0.24)
				attack_pulse = 0.6
				animator.begin_attack(auto_windup)
				atk_cd = 1.0/effective_atk_spd()

	# Movement
	if steering and not is_dashing and queued_auto_target == null and not buffs.has("root"):
		facing = manual_move.normalized()
		global_position += manual_move.limit_length() * effective_move_speed() * delta
		has_move_target = false
	elif has_move_target and not is_dashing and not buffs.has("root"):
		var dir = move_target - global_position
		var d = dir.length()
		if d < 3:
			has_move_target = false
		else:
			var way = UnitCollision.steer(self, move_target, UnitCollision.HERO_RADIUS, attack_target) - global_position
			facing = way.normalized() if way.length_squared() > 0.01 else dir / d
			var step = effective_move_speed() * delta
			global_position += facing * min(step, d)

	if not is_dashing and not buffs.has("forced_motion") and not buffs.has("airborne"):
		UnitCollision.resolve_champion(self)

	# Clamps
	global_position.y = clamp(global_position.y, Constants.LANE_Y - Constants.LANE_HALF + 20, Constants.LANE_Y + Constants.LANE_HALF - 20)
	global_position.x = clamp(global_position.x, 40, Constants.WORLD_W - 40)

	# Movement dust: emit a puff every so often while actually moving
	var moved = global_position.distance_squared_to(_last_pos)
	# Walled in by a crowd: give up on the order instead of walking on the spot.
	_blocked_time = _blocked_time + delta if has_move_target and attack_target == null and moved < 0.04 else 0.0
	if _blocked_time > 0.6:
		has_move_target = false
		_blocked_time = 0.0
	_dust_cooldown -= delta
	if moved > 4.0 and _dust_cooldown <= 0.0:
		_dust_cooldown = 0.3
		get_tree().call_group("game_main", "spawn_trail",
			global_position + Vector2.ZERO, Color(0.6, 0.52, 0.4, 0.5), 5.0)
	_last_pos = global_position

	# Enemy fountain damage (anti-backdoor)
	var enemy_fount = Constants.FOUNT_R if team == Constants.BLUE else Constants.FOUNT_B
	if global_position.distance_to(enemy_fount) < 100:
		get_tree().call_group("game_main", "deal_damage",
			{"team": 1 - team, "kind": "fountain"}, self, 500 * delta, "skill")

	if is_bot: BotTactics.space(self,delta)
	_sync_bars()
	queue_redraw()

func _sync_bars() -> void:
	if hp_bar == null: return
	hp_bar.size.x = max(0.0, Constants.CHAMP_BAR_WIDTH * hp / hp_max)
	shield_bar.visible = not dead and shield > 0
	shield_bar_bg.visible = shield_bar.visible
	shield_bar.size.x = clampf(Constants.CHAMP_BAR_WIDTH * shield / maxf(hp_max, 1), 2.0, Constants.CHAMP_BAR_WIDTH) if shield > 0 else 0.0
	hp_bar.visible = not dead
	hp_bar_bg.visible = not dead
	mp_bar.visible = not dead and (mp_max > 0 or hero_key=="renekton")
	if hero_key=="renekton":
		mp_bar.color=Color("de784a");mp_bar.size.x=Constants.CHAMP_BAR_WIDTH*buffs.get("fury",{}).get("value",0.)/100.
	if mp_max > 0:
		mp_bar.size.x = max(0.0, Constants.CHAMP_BAR_WIDTH * mp / mp_max)
	name_label.visible = not dead

func auto_attack_reach(target) -> float:
	var reach = HeroPassives.attack_range(self,target)+(100 if buffs.has("rockets") else 0)+(40 if buffs.has("exile") else 0)+target.size*0.3
	# A building can always be hit by a hero touching it.
	if target.kind == "structure": reach = maxf(reach, UnitCollision.contact_distance(self, target) + UnitCollision.REACH_MARGIN)
	return reach

func cancel_auto() -> void:
	if queued_auto_target != null:
		queued_auto_target = null
		auto_windup = 0
		if animator != null: animator.cancel_attack()
		atk_cd = 0

func _perform_auto(target) -> void:
	if not BrushVision.visible_to(target,team): return
	BrushVision.reveal(self)
	animator.release_attack(clampf(0.2/effective_atk_spd(),0.08,0.24))
	get_tree().call_group("game_main", "play_sfx", "attack", self)
	var frost_slow=(.2+.01*mini(level,18))*(2. if randf()<HeroPassives.critical_chance(self) else 1.) if hero_key=="ashe" else 0.
	var dmg = ad
	if hero_key!="ashe" and randf() < HeroPassives.critical_chance(self):dmg *= (1.75 + bonus_crit_damage)*(.9 if hero_key=="yasuo" else 1.)
	dmg += Roster12Combat.before_auto(self,target) + HeroPassives.auto_bonus(self,target)
	if buffs.has("hunt"):dmg+=buffs.hunt.damage
	if buffs.has("empowered"):
		dmg+=buffs.empowered.damage
		if buffs.empowered.slow>0 and "buffs" in target and not target.buffs.has("cc_guard"):target.buffs.slow={"time":2.,"pct":buffs.empowered.slow}
		buffs.erase("empowered")
	if buffs.has("righteous"): dmg += buffs.righteous.bonus
	if inventory.has("blade_ruined_king"):
		dmg += minf(target.hp * 0.06, 60.0) if target.kind == "minion" else target.hp * 0.06
	if buffs.has("spellblade"):
		dmg += TankADCombat.spellblade_damage(self)
		if inventory.has("essence_reaver"): mp = minf(mp_max,mp+mp_max*.08)
		buffs.erase("spellblade")
	if buffs.has("decisive") and not buffs["decisive"]["used"]:
		if "buffs" in target and not target.buffs.has("cc_guard") and not target.buffs.has("parry"): target.buffs["silence"] = {"time": 1.5}
		dmg += buffs["decisive"]["bonus"]
		buffs["decisive"]["used"] = true
		buffs.erase("decisive")
	attack_pulse = 1.0
	if auto_type == "melee":
		get_tree().call_group("game_main","spawn_melee_strike",self,target.world_pos(),target.kind == "minion")
		get_tree().call_group("game_main", "deal_damage", self, target, dmg, "auto")
	else:
		var ang = (target.world_pos() - global_position).angle()
		var shots = 3 if buffs.has("focus") else 1
		if shots>1:dmg=dmg*(1.05+.05*rank(0))/shots
		var auto_shape = "arrow" if hero_key == "ashe" else ("fireball" if hero_key == "annie" else "orb")
		for i in range(shots):
			var spread = (i - (shots - 1) * 0.5) * 0.08
			var a = ang + spread
			_spawn_projectile(Vector2(cos(a), sin(a)), dmg, 700,
				hero["auto_color"], 7, 0, 2.0, 0.0,
				frost_slow, 2.0, false, 0.0, target,
				false, false, auto_shape, "attack_fragment" if i>0 else "auto")

# ============== Bot AI ==============
func estimate_kill_damage(target) -> float:
	var travel = maxf(0.0, global_position.distance_to(target.world_pos()) - atk_range) / maxf(1.0, effective_move_speed())
	var window = maxf(0.5, 3.0 - travel)
	var damage = ad * maxf(0.0, window - atk_cd) * effective_atk_spd() * 100.0 / (100.0 + ExpansionCombat.resist(target,self,"auto"))
	var mana = mp
	for i in range(4):
		if skill_ranks[i] <= 0 or skill_cds[i] > travel + 0.5: continue
		var sk = hero.skills[i]
		if mana < sk.cost: continue
		var r = float(rank(i))
		var value = 0.0
		match sk.cast_id:
			"yasuo_q": value = 45+25*r+ad*0.6
			"yasuo_e": value = 45+25*r+ad*0.4
			"yasuo_r":
				if target.stun > 0: value = 150+100*r
			"leesin_q": value = 55+30*r+ad*0.6
			"leesin_e": value = 50+30*r
			"leesin_r": value = 150+100*r+ad*0.8
			"zed_q": value = (40+25*r+ad*0.65)*(1.7 if buffs.has("shadow") else 1.0)
			"zed_e": value = 40+30*r
			"zed_r": value = 90+80*r+ad*0.5
			"jinx_w": value = 40+30*r+ad*0.8
			"jinx_r": value = 150+100*r+ad*0.6
			"katarina_q", "katarina_e": value = 45+30*r
			"katarina_w": value = 35+25*r
			"katarina_r": value = (30+20*r)*minf(10,window*4)
			"kayle_q": value = 45+30*r
			"kayle_e": value = (25+15*r)*window
			"lux_q": value = 70 + 30 * r
			"lux_e": value = 65 + 35 * r
			"lux_r": value = 180 + 100 * r
			"ahri_q": value = (45 + 25 * r) * 1.5
			"ahri_w": value = (25 + 20 * r) * 2
			"ahri_e": value = 55 + 25 * r
			"ahri_r": value = (45 + 25 * r) * 2
			"ezreal_q": value = 20 + 20 * r + ad * 1.1
			"ezreal_w": value = 60 + 30 * r
			"ezreal_e": value = 50 + 30 * r
			"ezreal_r": value = 150 + 100 * r + ad * 0.8
			"ashe_q": value = ad * window * 0.5
			"ashe_w": value = 20 + 20 * r + ad * 0.6
			"ashe_r":
				if global_position.distance_to(target.world_pos()) >= 400: value = 150 + 100 * r + ad * 0.6
			"annie_q": value = 60 + 25 * r + ad * 0.3
			"annie_w": value = 70 + 30 * r + ad * 0.3
			"annie_r": value = 150 + 125 * r + ad * 0.3
			"garen_q": value = 30 + 25 * r + ad * 0.4
			"garen_e": value = (12 + 8 * r + ad * 0.4) * minf(4.0, window * 2)
			"garen_r":
				if target.hp < target.hp_max * 0.4: value = 150 + 150 * r + (target.hp_max - target.hp) * (0.2 + 0.05 * r)
		if hero_key in SupportRoster.KEYS and ((hero_key=="soraka" and i in [0,2]) or (hero_key=="janna" and i in [0,1])):value=SupportKits.amount(self,i)
		if hero_key in RosterExpansion12.KEYS and sk.cast_id not in ["riven_e","fiora_r"]:value=Roster12Kits.amount(self,sk.cast_id)
		if ExpansionKits.FORMULAS.has(sk.cast_id) and sk.cast_id not in ["darius_w","malphite_w","morgana_e","thresh_w","vayne_q","vayne_r"]:
			value = ExpansionKits.amount(self,sk.cast_id)
			if sk.cast_id == "morgana_w": value *= minf(3.0,window)
			if sk.cast_id == "morgana_r": value *= 1.5
			if sk.cast_id == "darius_r": value += (target.hp_max-target.hp)*0.2
			if sk.cast_id == "veigar_r": value *= 1.0+minf(1.,(1.0-target.hp/target.hp_max)*1.5)
		if value > 0:
			mana -= sk.cost
			var kind = "magic" if hero_key in SupportRoster.KEYS else "skill"
			if hero_key in RosterExpansion12.KEYS:kind="physical" if Roster12Kits.physical(self) else "magic"
			if ExpansionRoster.KEYS.has(hero_key): kind = "physical" if hero_key in ["darius","vayne"] else "magic"
			if sk.cast_id in ["darius_r","garen_r"]: kind = "exec"
			var resistance = 0.0 if kind == "exec" else ExpansionCombat.resist(target,self,kind)
			damage += (value + (bonus_ap * preload("res://scripts/SkillScaling.gd").legacy_ap_ratio(hero_key) if kind == "skill" else 0.0)) * 0.7 * 100.0 / (100.0 + resistance)
	damage *= difficulty_stats.get("damage", 1.0)
	if target.buffs.has("courage"): damage *= 1.0 - target.buffs.courage.dr
	return damage

func can_secure_kill(target) -> bool:
	if not is_instance_valid(target) or target.dead: return false
	return estimate_kill_damage(target) >= target.hp + target.shield + target.hp_regen * 3

func _safe_pursuit(target) -> bool:
	if not BotSafety.can_enter(self,BotSafety.approach(self,target),true,target): return false
	var enemy_fountain = Constants.FOUNT_R if team == Constants.BLUE else Constants.FOUNT_B
	if target.world_pos().distance_to(enemy_fountain) < 150: return false
	var incoming = 0.0
	for enemy in GameState.champions:
		if enemy.dead or enemy.team == team: continue
		if enemy.world_pos().distance_to(target.world_pos()) < 420:
			incoming += enemy.ad * enemy.effective_atk_spd() * 2.0 * enemy.difficulty_stats.get("damage", 1.0)
	for tower in GameState.structures:
		if tower.dead or tower.team == team or tower.atk_dmg <= 0: continue
		if tower.world_pos().distance_to(target.world_pos()) < tower.atk_range + 30:
			# Attacking a defender provokes towers even with allied minions present.
			incoming += tower.atk_dmg * 2
	incoming *= 100.0 / (100.0 + bonus_armor)
	return hp + shield > incoming + hp_max * 0.12

func _run_bot_ai(delta: float) -> void:
	if BotDodge.update(self,delta): return
	ai_tick -= delta
	if ai_tick > 0: return
	ai_tick = difficulty_stats.get("reaction", 0.3)
	manual_move = Vector2.ZERO

	var fount = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
	var in_fount = global_position.distance_to(fount) < 100
	var low_hp = hp < hp_max * 0.25
	var dangerous_tower = BotSafety.retreat_from(self)
	if dangerous_tower != null:
		cancel_auto()
		is_dashing = false
		attack_target = null
		attack_move = false
		chase_target = null
		chase_rest_until = GameState.time+2
		move_target = BotSafety.waiting_point(self,dangerous_tower)
		has_move_target = true
		return

	# A pursuit has a fixed deadline and leash; never renew it every decision.
	if is_instance_valid(chase_target):
		if chase_target.dead or not BrushVision.visible_to(chase_target,team) or GameState.time > chase_until or global_position.distance_to(chase_origin) > difficulty_stats.get("vision", 440.0) + 180 or not can_secure_kill(chase_target) or not _safe_pursuit(chase_target):
			chase_target = null
			chase_rest_until = GameState.time + 2.0
	var closest_champ = BotTactics.select_target(self)
	if closest_champ != null and can_secure_kill(closest_champ) and GameState.time >= chase_rest_until:
		if chase_target != closest_champ:
			chase_origin = global_position
			chase_until = GameState.time + difficulty_stats.get("chase", 3.5)
		chase_target = closest_champ
		BotSafety.commit_dive(self,closest_champ)
	if low_hp and not in_fount and closest_champ == null:
		move_target = fount
		has_move_target = true
		attack_target = null
		attack_move = false
		return
	if in_fount and hp < hp_max * 0.9:
		has_move_target = false
		attack_target = null
		return

	var supported = SupportKits.bot_support(self)
	# Poke from spell range while farming instead of waiting for autoattack range.
	if closest_champ == null and not low_hp:
		var poke_target = null
		var poke_distance = difficulty_stats.get("vision", 440.0)
		for enemy in GameState.champions:
			if enemy.dead or enemy.team == team or not BrushVision.visible_to(enemy,team) or not _safe_pursuit(enemy): continue
			var distance = global_position.distance_to(enemy.world_pos())
			if distance < poke_distance:
				poke_distance = distance
				poke_target = enemy
		if poke_target != null and not supported: _try_bot_cast(poke_target)

	# Short, purposeful flank waits; bots leave rather than camping forever.
	if closest_champ==null and not low_hp:
		var ambush=BrushVision.ambush_point(self)
		if ambush!=null:
			if ambush_until<0: ambush_until=GameState.time+2.5
			if GameState.time<ambush_until:
				attack_target=null;attack_move=false;move_target=ambush;has_move_target=world_pos().distance_to(ambush)>8
				return
		ambush_until=-1.;ambush_rest_until=GameState.time+3.
	else:
		if ambush_until>=0: ambush_rest_until=GameState.time+5.
		ambush_until=-1.

	# Nearest enemy minion in sight
	var near_minion = null
	var m_score = -INF
	for m in GameState.minions:
		if m == null or m.team == team or m.dead: continue
		var d = global_position.distance_to(m.world_pos())
		if d>220. or not BotSafety.can_enter(self,BotSafety.approach(self,m)):continue
		var score=(160. if m.hp<=GameState.last_hit_damage(self,m) else 0.)-d
		if m==attack_target:score+=20.
		if score>m_score:m_score=score;near_minion=m

	var target = closest_champ if closest_champ != null else near_minion

	if closest_champ != null and not supported:
		_try_bot_cast(closest_champ)

	if target != null:
		attack_target = target
		attack_move = false
		has_move_target = false
		if target.kind == "champion" and auto_type == "ranged" and global_position.distance_to(target.world_pos()) < atk_range * 0.55:
			manual_move = (global_position - target.world_pos()).normalized()
	else:
		# Push toward nearest attackable enemy structure
		attack_target = null
		var push_s = null
		var ps_d = INF
		for s in GameState.structures:
			if s == null or s.team == team or s.dead or not s.is_structure_attackable(): continue
			var d = global_position.distance_to(s.world_pos())
			if d < ps_d: ps_d = d; push_s = s
		if push_s != null:
			var approach = BotSafety.approach(self,push_s)
			if BotSafety.can_enter(self,approach):
				move_target = approach
				attack_target = push_s
				attack_move = false
			else:
				move_target = BotSafety.waiting_point(self,push_s)
				attack_move = false
			has_move_target = true

func _try_bot_cast(target) -> void:
	if not is_instance_valid(target) or target.dead: return
	var distance = global_position.distance_to(target.world_pos())
	var order = {"ashe": [3, 1, 0, 2], "annie": [3, 0, 1, 2], "garen": [3, 0, 2, 1], "lux": [0, 2, 3, 1], "ahri": [2, 0, 1, 3], "ezreal": [1, 0, 3, 2]}.get(hero_key,hero.priority)
	if hero_key == "thresh" and not NewHeroKits.recast_info(self,0).is_empty() and try_cast_skill(0,target.world_pos()):return
	if hero_key == "leesin" and is_instance_valid(sonic_target) and sonic_target == target and distance <= 650 and BotSafety.can_enter(self,target.world_pos(),target.kind == "champion") and try_cast_skill(0,target.world_pos()):return
	if hero_key == "zed" and buffs.has("shadow") and not buffs.shadow.swapped and distance > 180 and hp > hp_max*0.5 and try_cast_skill(1,target.world_pos()):return
	if hero_key in RosterExpansion12.KEYS:
		for i in range(4):
			if not Roster12Kits.recast_info(self,i).is_empty():
				if (hero_key != "xerath" or i != 0 or buffs.arcanopulse.time < .5) and try_cast_skill(i,target.world_pos()):return
	var casts = 0
	for i in order:
		if skill_ranks[i] <= 0 or skill_cds[i] > 0: continue
		var sk = hero.skills[i]
		if (hero_key=="soraka" and i in [1,3]) or (hero_key=="janna" and i in [2,3]): continue
		if hero_key in RosterExpansion12.KEYS and sk.kind == "self" and distance > (atk_range+40 if i==0 or sk.cast_id in ["blitzcrank_e","fiora_e","sivir_w"] else 210): continue
		if mp < sk.cost or (sk.range > 0 and distance > sk.range): continue
		match sk.cast_id:
			"darius_q","darius_e","malphite_e","thresh_e":
				if distance>190:continue
			"darius_r":
				if target.hp>target.hp_max*.45:continue
			"morgana_r","thresh_r":
				if distance>200:continue
			"vayne_w","vayne_r","darius_w":
				if distance>atk_range+40:continue
			"malphite_w":
				if hp>hp_max*.8 and distance>150:continue
			"katarina_w", "katarina_r", "leesin_e", "zed_e":
				if distance > 180: continue
			"kayle_w":
				if hp > hp_max*0.8: continue
			"kayle_r":
				if hp > hp_max*0.45: continue
			"garen_r":
				if target.hp > target.hp_max * 0.45 or distance > 180: continue
			"garen_e":
				if distance > 120: continue
			"garen_q":
				if distance > 330: continue
			"garen_w", "annie_e", "lux_w":
				if hp > hp_max * 0.75 and distance > 150: continue
			"ashe_q":
				if distance > atk_range + 30: continue
			"ashe_e", "ezreal_e", "ahri_r":
				if hp > hp_max * 0.45 and not can_secure_kill(target): continue
			"ahri_w":
				if distance > 420: continue
			"ashe_r":
				if distance < 160: continue
		var point = target.world_pos()
		if sk.kind in ["line", "target"]:
			var velocity = target.manual_move * target.effective_move_speed()
			if velocity.length_squared() < 1 and target.has_move_target:
				velocity = (target.move_target - target.world_pos()).normalized() * target.effective_move_speed()
			point += velocity * minf(0.45, distance / 700.0)
		if sk.cast_id in ["ashe_e", "ezreal_e", "ahri_r"] and hp < hp_max * 0.45:
			point = global_position + (global_position - target.world_pos()).normalized() * 250
		if sk.cast_id in ["ashe_e","ezreal_e","ahri_r"]:
			var landing = GameState.clamp_walkable(global_position+(point-global_position).limit_length(sk.range))
			if not BotSafety.can_enter(self,landing,hp>=hp_max*0.45): continue
		if try_cast_skill(i, point):
			casts += 1
			if casts >= 1: break
	for slot in range(2):
		if summoner_cds[slot]>0:continue
		match summoner_spells[slot]:
			"ignite":
				if not can_secure_kill(target) or distance>=240:continue
				ai_ignite_target=target
			"flash":
				if hp>=hp_max*.25 or distance>=180:continue
				ai_flash_pt=GameState.clamp_walkable(global_position+(global_position-target.world_pos()).normalized()*280)
				if not BotSafety.can_enter(self,ai_flash_pt,false):continue
			"heal":
				var rescue=hp<hp_max*.45
				for ally in GameState.champions:
					if ally!=self and ally.team==team and not ally.dead and ally.hp<ally.hp_max*.35 and ally.world_pos().distance_to(world_pos())<450:rescue=true
				if not rescue:continue
			"ghost":
				if not ((hp<hp_max*.35 and distance<350) or (can_secure_kill(target) and distance>atk_range+35)):continue
		get_tree().call_group("game_main","cast_summoner",self,slot)

# ============== Visual helpers ==============
func _make_spin_aura() -> Node2D:
	var n = Node2D.new()
	n.set_script(load("res://scripts/SpinAura.gd"))
	return n

func start_recall() -> void:
	if LanSession.is_local(self):
		ClientMovement.cancel()
		LanSession.send_command("recall")
		return
	if dead or stun > 0: return
	if recall_time >= 0:
		recall_time = -1.0
		queue_redraw()
		return
	manual_move = Vector2.ZERO
	is_dashing = false
	cancel_auto()
	recall_time = 0.0
	has_move_target = false
	attack_target = null
	attack_move = false

func stop_actions() -> void:
	if LanSession.is_local(self):
		ClientMovement.cancel()
		LanSession.send_command("stop")
		return
	cancel_auto()
	recall_time = -1.0
	manual_move = Vector2.ZERO
	queue_redraw()
	has_move_target = false
	attack_target = null
	attack_move = false


func tick_cooldowns(delta: float) -> void:
	for item in item_cds: item_cds[item] = maxf(0, item_cds[item] - delta)
	for i in range(4): skill_cds[i] = maxf(0.0, skill_cds[i] - delta)
	HeroPassives.cooldowns(self,delta)
	for i in range(2): summoner_cds[i] = maxf(0.0, summoner_cds[i] - delta)
	atk_cd = maxf(0.0, atk_cd - delta)

func _fountain_recovery(delta: float) -> void:
	var fountain = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
	if dead or world_pos().distance_to(fountain)>=100: return
	var contested = false
	for enemy in GameState.champions + GameState.minions:
		if is_instance_valid(enemy) and not enemy.dead and enemy.team != team and enemy.world_pos().distance_to(fountain)<550:
			contested = true
			break
	if not contested:
		hp = hp_max
		mp = mp_max
	else:
		hp = minf(hp_max,hp+120*delta)
		mp = minf(mp_max,mp+80*delta)
