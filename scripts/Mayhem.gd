class_name Mayhem
extends RefCounted
## Mayhem upgrades: game-changing picks that make every match play differently. Everyone gets a pick at the start of
## the match and again at levels 7, 11 and 15. All effects run on the host, on top of the normal stat upgrades.

const LEVELS := [3, 7, 11, 15]
const SILVER := 0
const GOLD := 1
const PRISMATIC := 2
const TIER_NAMES := ["SILVER", "GOLD", "PRISMATIC"]
const TIER_COLORS := [Color("c3ccd8"), Color("f0c75e"), Color("d68cff")]
const TIER_WEIGHTS := {3: [6, 3, 0], 7: [3, 6, 1], 11: [1, 6, 3], 15: [0, 4, 6]}
const CARDS := {
	"ward": {"name": "Spell Shield", "tier": SILVER, "desc": "Every spell you cast gives a shield worth 5% of your max health."},
	"siege": {"name": "Siege Breaker", "tier": SILVER, "desc": "Deal double damage to buildings and 40% more to minions."},
	"vamp": {"name": "Soul Drinker", "tier": SILVER, "desc": "Your spells heal you for 18% of the damage they deal to heroes."},
	"frenzy": {"name": "Bloodrush", "tier": SILVER, "desc": "Takedowns grant a burst of move speed and attack speed, and you run through minions."},
	"storm": {"name": "Thunderclap", "tier": SILVER, "desc": "Every third attack shocks all nearby enemies."},
	"crit": {"name": "Spell Crits", "tier": SILVER, "desc": "Your spells have a 25% chance to deal 75% more damage."},
	"burn": {"name": "Immolate", "tier": SILVER, "desc": "Burn every enemy around you, all the time."},
	"chain": {"name": "Chain Lightning", "tier": GOLD, "desc": "Your spells arc to 2 nearby enemies for 30% of their damage."},
	"blast": {"name": "Detonator", "tier": GOLD, "desc": "Enemies you kill explode and can set off more explosions."},
	"echo": {"name": "Spell Echo", "tier": GOLD, "desc": "Every fourth spell has no cooldown."},
	"feast": {"name": "Feast", "tier": GOLD, "desc": "Takedowns and kills grow your damage and health this match, up to 20 times."},
	"landing": {"name": "Impact Landing", "tier": GOLD, "desc": "Your dashes and blinks end with a slowing shockwave."},
	"laststand": {"name": "Last Stand", "tier": GOLD, "desc": "Below 35% health, deal 35% more damage and heal 20% of it."},
	"ricochet": {"name": "Ricochet", "tier": GOLD, "desc": "Your attacks bounce to another enemy for 50% damage."},
	"trance": {"name": "Battle Trance", "tier": GOLD, "desc": "After each spell, your next attack hits far harder."},
	"flow": {"name": "Flow State", "tier": GOLD, "desc": "For 6 seconds after a takedown, your spells cost nothing."},
	"titan": {"name": "Titan", "tier": GOLD, "desc": "Grow to giant size: +300 health and +15 attack damage."},
	"thrill": {"name": "Thrill of the Hunt", "tier": PRISMATIC, "desc": "Takedowns instantly refresh Q, W and E."},
	"undying": {"name": "Undying", "tier": PRISMATIC, "desc": "Once every 90 seconds, a killing blow leaves you at 30% health and briefly invulnerable."},
	"execute": {"name": "Executioner", "tier": PRISMATIC, "desc": "Enemy heroes you hit below 15% health die instantly."},
	"necro": {"name": "Necromancer", "tier": PRISMATIC, "desc": "Minions you kill often rise to fight for you."},
	"ult": {"name": "Ultimate Power", "tier": PRISMATIC, "desc": "Your ultimate has 40% less cooldown, and takedowns shorten it by 10 seconds."},
}
const CHAIN_RANGE := 230.0
const BLAST_RADIUS := 150.0
const STORM_RADIUS := 130.0
const BURN_RADIUS := 135.0
const LANDING_RADIUS := 140.0
const BOUNCE_RANGE := 270.0
const NECRO_CHANCE := 0.4
const NECRO_MAX := 6
const NECRO_LIFE := 14.0
const UNDYING_COOLDOWN := 90.0
const BLINK_DISTANCE := 90.0
const MAX_BLAST_DEPTH := 2
const FEAST_MAX := 20.0

static var _proc_depth := 0
static var _blast_depth := 0


static func has(c, id: String) -> bool:
	return c.mayhem.has(id)


## Three different cards this hero does not have yet, weighted toward rarer tiers later in the match.
static func offer(c, level: int, count: int = 3) -> Array:
	var weights: Array = TIER_WEIGHTS.get(level, TIER_WEIGHTS[11])
	var pool := []
	for id in CARDS:
		if not c.mayhem.has(id):
			pool.append(id)
	pool.shuffle()
	var picked := []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += maxf(float(weights[CARDS[id].tier]), 0.05)
		var roll := randf() * total
		var chosen = pool[0]
		for id in pool:
			roll -= maxf(float(weights[CARDS[id].tier]), 0.05)
			if roll <= 0.0:
				chosen = id
				break
		pool.erase(chosen)
		picked.append(chosen)
	return picked


static func grant(c, id: String) -> void:
	if not CARDS.has(id) or c.mayhem.has(id):
		return
	c.mayhem[id] = true
	if id == "titan":
		c.run_bonus["bonus_hp"] = c.run_bonus.get("bonus_hp", 0.0) + 300.0
		c.run_bonus["bonus_ad"] = c.run_bonus.get("bonus_ad", 0.0) + 15.0
		c.visual_scale = 1.22
		var before: float = c.hp_max
		c._apply_items()
		c.hp += maxf(0.0, c.hp_max - before)


## Damage changes before armor. Returns the new damage.
static func modify_damage(main, src, target, dmg: float, dmg_type: String) -> float:
	if src.mayhem.is_empty() or src.team == target.team:
		return dmg
	if src.mayhem.has("laststand") and src.hp < src.hp_max * 0.35:
		dmg *= 1.35
	if src.mayhem.has("siege"):
		if target.kind == "structure":
			dmg *= 2.0
		elif target.kind == "minion":
			dmg *= 1.4
	if dmg_type in ["auto", "secondary_auto"] and src.mayhem_state.get("trance", false):
		src.mayhem_state.trance = false
		dmg += src.ad * 0.7 + src.bonus_ap * 0.45
		_say(main, src, target.world_pos(), "TRANCE", Color("9fe8ff"))
	if _is_spell(dmg_type) and _proc_depth == 0 and src.mayhem.has("crit") and randf() < 0.25:
		dmg *= 1.75
		_say(main, src, target.world_pos(), "CRIT", Color("ffb347"))
	return dmg


## After damage lands: chaining, healing and on-hit effects. Damage dealt by these effects does not trigger them again.
static func after_damage(main, src, target, dmg_type: String, dealt: float) -> void:
	if _proc_depth > 0 or src.mayhem.is_empty() or src.dead or src.team == target.team or dealt <= 0.0 or target.kind == "structure":
		return
	var spell := _is_spell(dmg_type)
	var attack := dmg_type in ["auto", "secondary_auto"]
	_proc_depth += 1
	if spell and src.mayhem.has("vamp") and target.kind == "champion":
		_heal(src, dealt * 0.18)
	if src.mayhem.has("laststand") and src.hp < src.hp_max * 0.35:
		_heal(src, dealt * 0.2)
	if spell and src.mayhem.has("chain") and GameState.time >= float(src.mayhem_state.get("chain_at", 0.0)):
		src.mayhem_state.chain_at = GameState.time + 0.3
		var hops := 0
		for other in _enemies_near(src, target.world_pos(), CHAIN_RANGE):
			if other == target:
				continue
			main.deal_damage(src, other, dealt * 0.3, "item_magic")
			main.spawn_impact(other.world_pos(), Color(0.65, 0.85, 1.0), 26.0)
			hops += 1
			if hops >= 2:
				break
	if attack and src.mayhem.has("ricochet"):
		for other in _enemies_near(src, target.world_pos(), BOUNCE_RANGE):
			if other != target:
				main.deal_damage(src, other, dealt * 0.5, "splash")
				main.spawn_impact(other.world_pos(), Color(1.0, 0.8, 0.4), 22.0)
				break
	if attack and src.mayhem.has("storm"):
		var hits := int(src.mayhem_state.get("storm_hits", 0)) + 1
		src.mayhem_state.storm_hits = hits % 3
		if hits >= 3:
			_blast(main, src, target.world_pos(), STORM_RADIUS, 35.0 + src.level * 4.0 + src.ad * 0.4 + src.bonus_ap * 0.3, Color(0.6, 0.8, 1.0))
	if src.mayhem.has("execute") and target.kind == "champion" and target.hp > 0.0 and target.hp < target.hp_max * 0.15:
		_say(main, src, target.world_pos(), "EXECUTED", Color(1.0, 0.3, 0.9), true)
		main.deal_damage(src, target, target.hp + 1.0, "exec")
	_proc_depth -= 1


## True when Undying saved this hero from a killing blow.
static func cheat_death(main, target) -> bool:
	if target.kind != "champion" or not target.mayhem.has("undying") or GameState.time < float(target.mayhem_state.get("undying_at", 0.0)):
		return false
	target.mayhem_state.undying_at = GameState.time + UNDYING_COOLDOWN
	target.hp = target.hp_max * 0.3
	target.buffs["divine"] = {"time": 1.5, "src": null, "dmg": 0.0}
	main.floating_text(target.world_pos(), "UNDYING", Color("d68cff"), true)
	main.spawn_impact(target.world_pos(), Color("d68cff"), 60.0)
	return true


## A hero took part in killing an enemy hero.
static func on_takedown(main, c, victim) -> void:
	if c.mayhem.is_empty():
		return
	if c.mayhem.has("thrill"):
		for i in range(3):
			c.skill_cds[i] = 0.0
		_say(main, c, c.world_pos(), "REFRESH", Color("d68cff"), true)
	if c.mayhem.has("ult"):
		c.skill_cds[3] = maxf(0.0, c.skill_cds[3] - 10.0)
	if c.mayhem.has("frenzy"):
		c.buffs["ghost"] = {"time": 4.0, "mult": 1.3}
		c.buffs["ardent"] = {"time": 4.0, "magic": 6.0 + c.level}
	if c.mayhem.has("flow"):
		c.mayhem_state.flow_until = GameState.time + 6.0
	if c.mayhem.has("feast"):
		_feast(main, c, 6.0, 10.0, 45.0, "FEAST")


## The killing hero's own kill of a hero or minion.
static func on_kill(main, killer, victim) -> void:
	if killer.mayhem.is_empty():
		return
	if killer.mayhem.has("blast") and _blast_depth < MAX_BLAST_DEPTH:
		_blast_depth += 1
		_blast(main, killer, victim.world_pos(), BLAST_RADIUS, 25.0 + victim.hp_max * 0.12, Color(1.0, 0.55, 0.2))
		_blast_depth -= 1
	if victim.kind != "minion":
		return
	if killer.mayhem.has("feast"):
		var count := int(killer.mayhem_state.get("feast_minions", 0)) + 1
		killer.mayhem_state.feast_minions = count % 5
		if count >= 5:
			_feast(main, killer, 1.5, 2.5, 12.0, "")
	if killer.mayhem.has("necro") and victim.subkind in ["melee", "caster"] and randf() < NECRO_CHANCE:
		_raise(main, killer, victim)


static func on_cast(c, idx: int) -> void:
	if c.mayhem.is_empty():
		return
	var main = c.get_tree().get_first_node_in_group("game_main")
	if c.mayhem.has("echo"):
		var count := int(c.mayhem_state.get("echo", 0)) + 1
		c.mayhem_state.echo = count % 4
		if count >= 4:
			c.skill_cds[idx] = 0.0
			_say(main, c, c.world_pos(), "ECHO", Color("f0c75e"), true)
	if c.mayhem.has("ward"):
		CombatEffects.shield(c, "mayhem_ward", c.hp_max * 0.05, 3.0, null, false)
	if c.mayhem.has("trance"):
		c.mayhem_state.trance = true
	if idx == 3 and c.mayhem.has("ult"):
		c.skill_cds[3] *= 0.6
	if c.mayhem.has("flow") and GameState.time < float(c.mayhem_state.get("flow_until", 0.0)):
		c.mp = minf(c.mp_max, c.mp + float(c.hero.skills[idx].cost))


static func tick(c, delta: float) -> void:
	if c.mayhem.is_empty():
		return
	var state: Dictionary = c.mayhem_state
	var main = null
	if c.mayhem.has("burn"):
		state.burn_t = float(state.get("burn_t", 0.0)) + delta
		if state.burn_t >= 0.5:
			state.burn_t = 0.0
			main = c.get_tree().get_first_node_in_group("game_main")
			var amount: float = 7.0 + c.level * 1.6 + c.hp_max * 0.006
			var enemies := _enemies_near(c, c.world_pos(), BURN_RADIUS)
			_proc_depth += 1
			for enemy in enemies:
				main.deal_damage(c, enemy, amount, "burn")
			_proc_depth -= 1
			if not enemies.is_empty():
				main.spawn_impact(c.world_pos(), Color(1.0, 0.5, 0.15), 40.0)
	if c.mayhem.has("landing"):
		var pos: Vector2 = c.world_pos()
		var last: Vector2 = state.get("last_pos", pos)
		var jumped := pos.distance_to(last) > BLINK_DISTANCE and delta < 0.2
		if (state.get("dashing", false) and not c.is_dashing) or jumped:
			if main == null:
				main = c.get_tree().get_first_node_in_group("game_main")
			var enemies := _enemies_near(c, pos, LANDING_RADIUS)
			for enemy in enemies:
				if "buffs" in enemy and enemy.kind == "champion":
					enemy.buffs["slow"] = {"time": 1.2, "pct": 0.35}
			_blast(main, c, pos, LANDING_RADIUS, 45.0 + c.level * 5.0 + c.ad * 0.3 + c.bonus_ap * 0.3, Color(0.75, 0.9, 1.0))
		state.dashing = c.is_dashing
		state.last_pos = pos


static func _is_spell(dmg_type: String) -> bool:
	return dmg_type in ["skill", "magic", "physical"]


static func _heal(c, amount: float) -> void:
	c.hp = minf(c.hp_max, c.hp + amount)


static func _enemies_near(src, center: Vector2, radius: float) -> Array:
	var found := []
	for list in [GameState.champions, GameState.minions]:
		for u in list:
			if is_instance_valid(u) and not u.dead and u.is_targetable and u.team != src.team and u.world_pos().distance_to(center) <= radius:
				if u.kind != "champion" or u.roster_active:
					found.append(u)
	found.sort_custom(func(a, b): return a.world_pos().distance_squared_to(center) < b.world_pos().distance_squared_to(center))
	return found


static func _blast(main, src, center: Vector2, radius: float, damage: float, color: Color) -> void:
	_proc_depth += 1
	for enemy in _enemies_near(src, center, radius):
		main.deal_damage(src, enemy, damage, "item_magic")
	_proc_depth -= 1
	main.spawn_impact(center, color, radius * 0.55)
	main.camera_shake(0.12, 2.5, center)


static func _feast(main, c, ad: float, ap: float, health: float, label: String) -> void:
	var stacks: float = c.mayhem_state.get("feast_stacks", 0.0)
	if stacks >= FEAST_MAX:
		return
	c.mayhem_state.feast_stacks = stacks + ad / 6.0
	c.run_bonus["bonus_ad"] = c.run_bonus.get("bonus_ad", 0.0) + ad
	c.run_bonus["bonus_ap"] = c.run_bonus.get("bonus_ap", 0.0) + ap
	c.run_bonus["bonus_hp"] = c.run_bonus.get("bonus_hp", 0.0) + health
	var before: float = c.hp_max
	c._apply_items()
	c.hp += maxf(0.0, c.hp_max - before)
	if not label.is_empty():
		_say(main, c, c.world_pos(), label, Color("7dffa0"))


static func _raise(main, killer, victim) -> void:
	var raised: Array = killer.mayhem_state.get("raised", [])
	raised = raised.filter(func(m): return is_instance_valid(m) and not m.dead)
	if raised.size() >= NECRO_MAX:
		killer.mayhem_state.raised = raised
		return
	var risen = main.MinionS.new()
	main.world_root.add_child(risen)
	risen.setup(killer.team, victim.subkind, victim.world_pos(), 1.0 + GameState.time / 60.0 * 0.08)
	risen.lifetime = NECRO_LIFE
	risen.xp_val = 0
	risen.gold_val = 0
	GameState.minions.append(risen)
	raised.append(risen)
	killer.mayhem_state.raised = raised
	main.spawn_impact(victim.world_pos(), Color("b48cff"), 30.0)


static func _say(main, c, at: Vector2, text: String, color: Color, big: bool = false) -> void:
	if c.owner_peer > 0 and main != null:
		main.floating_text(at, text, color, big, [c.owner_peer])
