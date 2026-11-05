extends Node
# Autoload: GameState — shared references and match stats.
# Entity references so AI / HUD can iterate without passing refs around.

var running: bool = false
var started: bool = false
var paused: bool = false
var difficulty: int = 1
var reward_difficulty: int = 1
var allied_bots: bool = true
var match_mode: String = "pve"
var team_size: int = 3
var fill_bots: bool = true
func is_pvp() -> bool:return match_mode=="pvp"
var time: float = 0.0

var player = null
var champions: Array = []
var minions: Array = []
var structures: Array = []
var projectiles: Array = []
var aoes: Array = []

var score := [0, 0]           # champion kills per team
var wave_num: int = 0
var next_wave_at: float = Constants.FIRST_WAVE_AT

var inhibitors := [null, null]
var nexus := [null, null]

# Camera control
var cam_target: Vector2 = Vector2(Constants.FOUNT_B.x, Constants.LANE_Y)
var cam_locked: bool = true
var attack_move_pending: bool = false
# Presentation cursor (sim px). 2D: the canvas mouse; Rift3D: the ground pick. hover_unit is set by the 3D picker.
var cursor_world: Vector2 = Vector2.ZERO
var hover_unit = null

func reset() -> void:
	match_mode="pve";team_size=3;fill_bots=true
	allied_bots = true
	paused = false
	running = false
	started = false
	time = 0.0
	player = null
	champions.clear()
	minions.clear()
	structures.clear()
	projectiles.clear()
	aoes.clear()
	score = [0, 0]
	wave_num = 0
	next_wave_at = Constants.FIRST_WAVE_AT
	inhibitors = [null, null]
	nexus = [null, null]
	cam_locked = true
	attack_move_pending = false
	hover_unit = null

# Convenience filter helpers
func enemies_of(team: int) -> Array:
	var out := []
	for c in champions:
		if c and not c.dead and c.team != team:
			out.append(c)
	return out

func target_click_rect(unit) -> Rect2:
	# Hit-test the visible body as well as the ground position.
	match unit.kind:
		"champion": return Rect2(unit.world_pos()+unit.art_rect().position,unit.art_rect().size).merge(Rect2(unit.world_pos()-Vector2(unit.size*0.7,6),Vector2(unit.size*1.4,12)))
		"minion": return Rect2(unit.world_pos()+unit.art_rect().position,unit.art_rect().size).merge(Rect2(unit.world_pos()-Vector2(unit.size*0.7,6),Vector2(unit.size*1.4,12)))
		"structure": return Rect2(unit.world_pos()+unit.art_rect.position,unit.art_rect.size)
	return Rect2(unit.world_pos()-Vector2.ONE*unit.size,Vector2.ONE*unit.size*2)

func find_target_at(pos: Vector2, for_team: int, radius: float = 8.0):
	var best = null
	var best_d = INF
	for lst in [champions,minions,structures]:
		for unit in lst:
			if not is_instance_valid(unit) or unit.dead or not unit.is_targetable or unit.team == for_team: continue
			if not BrushVision.visible_to(unit,for_team): continue
			if unit.kind == "structure" and not unit.is_structure_attackable(): continue
			var bounds = target_click_rect(unit)
			if not bounds.grow(radius).has_point(pos): continue
			# Exact body hits beat padding; among overlapping units choose the closest center/feet.
			var distance = minf(pos.distance_to(unit.world_pos()),pos.distance_to(bounds.get_center()))
			if not bounds.has_point(pos): distance += 1000
			if distance < best_d: best_d = distance; best = unit
	return best

func find_nearest_enemy(src, origin: Vector2, radius: float):
	var best = null
	var best_d = radius
	for lst in [champions, minions, structures]:
		for u in lst:
			if u == null or u.dead or not u.is_targetable: continue
			if u.team == src.team or not BrushVision.visible_to(u,src.team): continue
			if u.kind == "structure" and not u.is_structure_attackable(): continue
			var d = origin.distance_to(u.world_pos())
			if d < best_d:
				best_d = d; best = u
	return best

# Ground attack move prefers a nearby cursor target, then falls back to the
# nearest enemy already in attack range. A missed click can approach a target,
# but never selects an enemy across the map just because it is near the cursor.
func find_attack_move_target(src, cursor: Vector2, direct_click: bool = false):
	if direct_click: return find_target_at(cursor,src.team,8)
	var cursor_target = null
	var nearest_target = null
	var cursor_distance = INF
	var nearest_distance = INF
	for units in [minions,champions,structures]:
		for unit in units:
			if not is_instance_valid(unit) or unit.dead or not unit.is_targetable or unit.team == src.team: continue
			if unit.kind == "structure" and not unit.is_structure_attackable(): continue
			if not BrushVision.visible_to(unit,src.team): continue
			var reach = src.auto_attack_reach(unit)
			var from_hero = src.world_pos().distance_to(unit.world_pos())
			var from_cursor = cursor.distance_to(unit.world_pos())
			if from_hero <= reach+100 and from_cursor <= 140 and from_cursor < cursor_distance:
				cursor_target = unit
				cursor_distance = from_cursor
			if from_hero <= reach and from_hero < nearest_distance:
				nearest_target = unit
				nearest_distance = from_hero
	return cursor_target if cursor_target != null else nearest_target

func last_hit_damage(src, target) -> float:
	var damage = src.ad + Roster12Combat.preview_auto_bonus(src,target) + HeroPassives.auto_bonus(src,target)
	if src.buffs.has("hunt"):damage+=src.buffs.hunt.damage
	if src.buffs.has("empowered"):damage+=src.buffs.empowered.damage
	if src.buffs.has("decisive") and not src.buffs.decisive.used: damage += src.buffs.decisive.bonus
	if src.inventory.has("blade_ruined_king"): damage += minf(target.hp * 0.06, 60.0) if target.kind == "minion" else target.hp * 0.06
	if src.buffs.has("spellblade"): damage += TankADCombat.spellblade_damage(src)
	if src.buffs.has("righteous"): damage += src.buffs.righteous.bonus
	damage *= src.difficulty_stats.get("damage", 1.0) * 100.0 / (100.0 + ExpansionCombat.resist(target,src,"auto"))
	var predicted=floor(damage)
	if src.buffs.has("focus"):predicted=3.*floor(damage*(1.05+.05*src.rank(0))/3.)
	if src.hero_key=="leona" and src.buffs.has("roster_attack"):predicted+=floor(src.buffs.roster_attack.damage*100./(100.+ExpansionCombat.resist(target,src,"item_magic")))
	if src.hero_key=="thresh" and src.rank(2)>0:predicted+=floor(src.ad*(.2+.2*src.rank(2))*src.flay_charge*100./(100.+ExpansionCombat.resist(target,src,"item_magic")))
	if src.hero_key=="kayle" and src.rank(2)>0:predicted+=floor((5.+src.rank(2)*5.+src.bonus_ap*.2)*100./(100.+ExpansionCombat.resist(target,src,"passive_magic")))
	if src.hero_key=="vayne" and src.rank(1)>0 and src.buffs.get("silver",{}).get("target_id",0)==target.get_instance_id() and src.buffs.silver.stacks==2:predicted+=minf(80.,target.hp_max*(.04+.01*src.rank(1)))
	if src.inventory.has("titanic_hydra"):predicted+=floor(src.hp_max*.01*src.difficulty_stats.get("damage",1.)*100./(100.+ExpansionCombat.resist(target,src,"item_physical")))
	if src.inventory.has("kraken") and src.buffs.get("kraken",{}).get("target_id",0)==target.get_instance_id() and src.buffs.kraken.stacks==2:predicted+=floor((30.+src.ad*.45)*src.difficulty_stats.get("damage",1.)*100./(100.+ExpansionCombat.resist(target,src,"item_physical")))
	if src.inventory.has("dead_mans") and src.buffs.get("momentum",{}).get("stacks",0.)>=100.:predicted+=floor(50.*src.difficulty_stats.get("damage",1.)*100./(100.+ExpansionCombat.resist(target,src,"item_physical")))
	if src.inventory.has("nashor"):predicted+=floor((15.+src.bonus_ap*.15)*src.difficulty_stats.get("damage",1.)*100./(100.+ExpansionCombat.resist(target,src,"item_magic")))
	return predicted

func clamp_walkable(point: Vector2) -> Vector2:
	var low := Vector2(40, Constants.LANE_Y - Constants.LANE_HALF + 20)
	var high := Vector2(Constants.WORLD_W - 40, Constants.LANE_Y + Constants.LANE_HALF - 20)
	return UnitCollision.push_out_of_structures(point.clamp(low, high), UnitCollision.HERO_RADIUS).clamp(low, high)
