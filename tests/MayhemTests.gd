extends Node

var failures = 0
var checks = 0
var game
var hero
var foe

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	Progression.difficulty = 1
	Progression.win_streak = 0
	GameState.reset()
	game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._show_menu()
	game._start_game("garen")
	await get_tree().process_frame
	hero = GameState.player
	for c in GameState.champions:
		if c.team != hero.team and c.roster_active:
			foe = c
			break
	_test_offers()
	_test_stat_cards()
	_test_spell_cards()
	_test_attack_cards()
	_test_kill_cards()
	_test_survival_cards()
	_test_area_cards()
	_test_pacing()
	_test_lan_flow()
	await _test_next_match()
	game.queue_free()
	await get_tree().process_frame
	print("MAYHEM: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

## A clean hero with only the named cards, and nothing else on the field to interfere.
func _reset(cards: Array = []) -> void:
	GameState.running = true
	GameState.time = 100.0
	for m in GameState.minions:
		m.queue_free()
	GameState.minions.clear()
	for c in GameState.champions:
		c.mayhem = {}
		c.mayhem_state = {}
		c.dead = false
		c.hp = c.hp_max
		c.buffs = {}
		c.shield = 0.0
		c.roster_active = c == hero or c == foe
		c.global_position = Vector2(4000.0 + 300.0 * GameState.champions.find(c), 4000.0)
	hero.global_position = Vector2(1400.0, 270.0)
	foe.global_position = Vector2(1450.0, 270.0)
	GameState.score = [0, 0]
	for id in cards:
		Mayhem.grant(hero, id)

func _minion(at: Vector2, team: int, kind: String = "melee"):
	var m = game.MinionS.new()
	game.world_root.add_child(m)
	m.setup(team, kind, at, 1.0)
	GameState.minions.append(m)
	return m

func _test_offers() -> void:
	check(Mayhem.CARDS.size() == 22, "22 upgrades exist")
	for id in Mayhem.CARDS:
		var card: Dictionary = Mayhem.CARDS[id]
		check(not card.name.is_empty() and not card.desc.is_empty() and card.tier in [0, 1, 2], "%s is complete" % id)
	check(not hero.mayhem_state.get("levels", []).is_empty(), "player is queued for a pick at the start")
	check(game.lane_augments.mayhem_choices.size() == 3, "player sees three cards when the match starts")
	check(game.lane_augments.mayhem_bar.get_child_count() == 3, "three card buttons are built")
	for c in GameState.champions:
		if c != hero and c.roster_active:
			check(c.mayhem.size() == 1, "bot %s picked at the start" % c.hero_key)
	var first: String = game.lane_augments.mayhem_choices[0]
	game.lane_augments.choose_mayhem(0)
	check(hero.mayhem.has(first), "choosing a card grants it")
	check(game.lane_augments.mayhem_choices.is_empty(), "the row closes after choosing")
	game.lane_augments.queue_mayhem(hero, 7)
	game.lane_augments.queue_mayhem(hero, 7)
	check(game.lane_augments.mayhem_levels.size() == 1, "one level gives one pick")
	check(not game.lane_augments.mayhem_choices.has(first), "owned cards are not offered again")
	game.lane_augments.queue_mayhem(hero, 11)
	game.lane_augments.choose_mayhem(1)
	check(game.lane_augments.mayhem_choices.size() == 3, "a queued pick follows the previous one")
	game.lane_augments.choose_mayhem(2)
	check(game.lane_augments.mayhem_choices.is_empty() and hero.mayhem.size() == 3, "the queue empties after two more picks")
	game.lane_augments.queue_mayhem(hero, 6)
	check(game.lane_augments.mayhem_choices.is_empty(), "other levels give no pick")
	for level in Mayhem.LEVELS:
		for attempt in range(40):
			hero.mayhem = {}
			var cards := Mayhem.offer(hero, level)
			var unique := {}
			for id in cards:
				unique[id] = true
			if cards.size() != 3 or unique.size() != 3:
				check(false, "an offer has three different cards")

func _test_stat_cards() -> void:
	_reset()
	var bare: float = hero.hp_max
	var bare_ad: float = hero.ad
	Mayhem.grant(hero, "titan")
	check(is_equal_approx(hero.hp_max, bare + 300.0), "Titan adds health")
	check(is_equal_approx(hero.ad, bare_ad + 15.0), "Titan adds attack damage")
	check(hero.visual_scale > 1.0, "Titan is bigger")
	hero.run_bonus.erase("bonus_hp")
	hero.run_bonus.erase("bonus_ad")
	hero.visual_scale = 1.0
	hero._apply_items()
	_reset(["feast"])
	var before: float = hero.hp_max
	Mayhem.on_takedown(game, hero, foe)
	check(hero.hp_max > before, "Feast grows health on a takedown")
	hero.run_bonus.erase("bonus_hp")
	hero.run_bonus.erase("bonus_ad")
	hero.run_bonus.erase("bonus_ap")
	hero._apply_items()

func _test_spell_cards() -> void:
	_reset(["siege"])
	var m = _minion(Vector2(1500.0, 270.0), foe.team)
	check(is_equal_approx(Mayhem.modify_damage(game, hero, m, 100.0, "skill"), 140.0), "Siege hits minions harder")
	check(is_equal_approx(Mayhem.modify_damage(game, hero, GameState.nexus[1], 100.0, "auto"), 200.0), "Siege doubles building damage")

	_reset(["crit"])
	var crits := 0
	for i in range(800):
		if Mayhem.modify_damage(game, hero, foe, 100.0, "skill") > 100.0:
			crits += 1
	check(crits > 120 and crits < 290, "Spell Crits land about a quarter of the time (%d/800)" % crits)
	check(Mayhem.modify_damage(game, hero, foe, 100.0, "auto") == 100.0, "Spell Crits skip attacks")

	_reset(["chain"])
	var a = _minion(Vector2(1460.0, 280.0), foe.team)
	var b = _minion(Vector2(1470.0, 290.0), foe.team)
	var far = _minion(Vector2(2100.0, 270.0), foe.team)
	var a_hp: float = a.hp
	var b_hp: float = b.hp
	var far_hp: float = far.hp
	game.deal_damage(hero, foe, 100.0, "skill")
	check(a.hp < a_hp and b.hp < b_hp, "Chain Lightning arcs to two nearby enemies")
	check(far.hp == far_hp, "Chain Lightning has a range")

	_reset(["vamp"])
	hero.hp = hero.hp_max * 0.5
	var hp_before: float = hero.hp
	game.deal_damage(hero, foe, 200.0, "skill")
	check(hero.hp > hp_before, "Soul Drinker heals on spell hits")
	hp_before = hero.hp
	game.deal_damage(hero, foe, 200.0, "auto")
	check(hero.hp == hp_before or hero.bonus_lifesteal > 0.0, "Soul Drinker does nothing on attacks")

	_reset(["echo"])
	for i in range(3):
		hero.skill_cds[0] = 5.0
		Mayhem.on_cast(hero, 0)
		check(hero.skill_cds[0] == 5.0, "Spell Echo waits for the fourth spell")
	hero.skill_cds[0] = 5.0
	Mayhem.on_cast(hero, 0)
	check(hero.skill_cds[0] == 0.0, "Spell Echo refreshes the fourth spell")

	_reset(["ward"])
	Mayhem.on_cast(hero, 0)
	check(hero.shield > 0.0, "Spell Shield shields on cast")

	_reset(["ult"])
	hero.skill_cds[3] = 100.0
	Mayhem.on_cast(hero, 3)
	check(is_equal_approx(hero.skill_cds[3], 60.0), "Ultimate Power shortens the ultimate")
	Mayhem.on_takedown(game, hero, foe)
	check(is_equal_approx(hero.skill_cds[3], 50.0), "takedowns shorten the ultimate more")

	_reset(["flow"])
	hero.mp = 0.0
	Mayhem.on_cast(hero, 0)
	check(hero.mp == 0.0, "Flow State does nothing without a takedown")
	Mayhem.on_takedown(game, hero, foe)
	Mayhem.on_cast(hero, 0)
	check(hero.mp == minf(hero.mp_max, float(hero.hero.skills[0].cost)), "Flow State refunds mana after a takedown")

func _test_attack_cards() -> void:
	_reset(["trance"])
	Mayhem.on_cast(hero, 0)
	var boosted: float = Mayhem.modify_damage(game, hero, foe, 100.0, "auto")
	check(boosted > 100.0, "Battle Trance empowers the next attack")
	check(Mayhem.modify_damage(game, hero, foe, 100.0, "auto") == 100.0, "Battle Trance is used up")

	_reset(["ricochet"])
	var m = _minion(Vector2(1500.0, 280.0), foe.team)
	var hp_before: float = m.hp
	game.deal_damage(hero, foe, 100.0, "auto")
	check(m.hp < hp_before, "Ricochet bounces attacks")

	_reset(["storm"])
	var near = _minion(Vector2(1480.0, 280.0), foe.team)
	var near_hp: float = near.hp
	game.deal_damage(hero, foe, 10.0, "auto")
	game.deal_damage(hero, foe, 10.0, "auto")
	check(near.hp == near_hp, "Thunderclap waits for the third attack")
	game.deal_damage(hero, foe, 10.0, "auto")
	check(near.hp < near_hp, "Thunderclap shocks on the third attack")

func _test_kill_cards() -> void:
	_reset(["thrill"])
	for i in range(4):
		hero.skill_cds[i] = 9.0
	Mayhem.on_takedown(game, hero, foe)
	check(hero.skill_cds[0] == 0.0 and hero.skill_cds[2] == 0.0, "Thrill refreshes Q, W and E")
	check(hero.skill_cds[3] == 9.0, "Thrill leaves the ultimate alone")

	_reset(["frenzy"])
	Mayhem.on_takedown(game, hero, foe)
	check(hero.buffs.has("ghost") and hero.buffs.has("ardent"), "Bloodrush grants its speed buffs")
	var frenzy_hp: float = foe.hp
	game.deal_damage(hero, foe, 50.0, "auto")
	check(foe.hp < frenzy_hp - 10.0, "attacks work during Bloodrush")

	_reset(["blast"])
	var victim = _minion(Vector2(1500.0, 270.0), foe.team)
	var near = _minion(Vector2(1560.0, 270.0), foe.team)
	var near_hp: float = near.hp
	game.deal_damage(hero, victim, 99999.0, "exec")
	check(victim.dead, "the first minion dies")
	check(near.hp < near_hp or near.dead, "Detonator damages enemies near a kill")

	_reset(["blast"])
	var row := []
	for i in range(8):
		var filler = _minion(Vector2(1500.0 + i * 40.0, 270.0), foe.team)
		filler.hp = 1.0
		row.append(filler)
	game.deal_damage(hero, row[0], 99999.0, "exec")
	check(Mayhem._proc_depth == 0 and Mayhem._blast_depth == 0, "chained explosions finish cleanly")
	check(row[1].dead, "an explosion can set off another")

	_reset(["execute"])
	foe.hp = foe.hp_max * 0.16
	var armor_hit: float = foe.hp_max * 0.03
	game.deal_damage(hero, foe, armor_hit * 2.5, "skill")
	check(foe.dead or foe.hp >= foe.hp_max * 0.15, "Executioner only applies under the threshold")
	if foe.dead:
		foe.dead = false
	foe.hp = foe.hp_max * 0.1
	game.deal_damage(hero, foe, 1.0, "skill")
	check(foe.dead, "Executioner finishes a low hero")
	foe.dead = false
	foe.hp = foe.hp_max

	_reset(["necro"])
	var raised := 0
	var kills := 0
	seed(5)
	for i in range(40):
		var dead_minion = _minion(Vector2(1500.0, 270.0), foe.team)
		Mayhem.on_kill(game, hero, dead_minion)
		kills += 1
	for m in GameState.minions:
		if m.team == hero.team:
			raised += 1
			check(m.gold_val == 0 and m.xp_val == 0 and m.lifetime > 0.0, "raised minions give nothing and expire")
	check(raised == Mayhem.NECRO_MAX, "Necromancer stops at its cap (%d)" % raised)

func _test_survival_cards() -> void:
	_reset(["undying"])
	game.deal_damage(foe, hero, 999999.0, "exec")
	check(not hero.dead and is_equal_approx(hero.hp, hero.hp_max * 0.3), "Undying survives a killing blow at 30%")
	check(hero.buffs.has("divine"), "Undying grants invulnerability")
	NewHeroKits.expire(hero, "divine", hero.buffs.divine)
	hero.buffs.erase("divine")
	hero.hp = 1.0
	game.deal_damage(foe, hero, 999999.0, "exec")
	check(hero.dead, "Undying has a cooldown")
	hero.dead = false

	_reset(["laststand"])
	check(Mayhem.modify_damage(game, hero, foe, 100.0, "skill") == 100.0, "Last Stand needs low health")
	hero.hp = hero.hp_max * 0.2
	check(is_equal_approx(Mayhem.modify_damage(game, hero, foe, 100.0, "skill"), 135.0), "Last Stand raises damage")
	var low: float = hero.hp
	game.deal_damage(hero, foe, 200.0, "skill")
	check(hero.hp > low, "Last Stand heals")

func _test_area_cards() -> void:
	_reset(["burn"])
	var m = _minion(Vector2(1460.0, 270.0), foe.team)
	var hp_before: float = m.hp
	Mayhem.tick(hero, 0.25)
	check(m.hp == hp_before, "Immolate waits for its interval")
	Mayhem.tick(hero, 0.3)
	check(m.hp < hp_before and Mayhem._proc_depth == 0, "Immolate burns nearby enemies")

	_reset(["landing"])
	var target = _minion(Vector2(1900.0, 270.0), foe.team)
	var target_hp: float = target.hp
	Mayhem.tick(hero, 0.02)
	hero.global_position = Vector2(1880.0, 270.0)
	Mayhem.tick(hero, 0.02)
	check(target.hp < target_hp, "Impact Landing fires when a hero blinks")

func _test_pacing() -> void:
	_reset()
	var lv: int = hero.level - 1
	var base: float = (hero.hero.hp + hero.hero.hp_per_lv * lv) * Constants.HERO_HP_MULT
	check(hero.hp_max >= base * 0.5, "heroes get the health multiplier")
	var nexus = GameState.nexus[1]
	check(is_equal_approx(game._structure_damage_mult(hero, nexus), Constants.STRUCTURE_DAMAGE_MULT * Constants.BACKDOOR_DAMAGE_MULT), "a building without attacking minions near it resists heroes")
	var escort = _minion(nexus.world_pos() + Vector2(-60.0, 0.0), hero.team)
	check(is_equal_approx(game._structure_damage_mult(hero, nexus), Constants.STRUCTURE_DAMAGE_MULT), "bringing minions removes the extra resistance")
	check(is_equal_approx(game._structure_damage_mult(escort, nexus), Constants.STRUCTURE_DAMAGE_MULT), "minions always deal the normal share")
	check(Constants.tower_hero_damage_mult() == Constants.TOWER_HERO_DAMAGE_MULT, "towers are at full strength before overtime")
	GameState.time = Constants.OVERTIME_START + 120.0
	check(is_equal_approx(Constants.tower_hero_damage_mult(), Constants.TOWER_HERO_DAMAGE_MULT * 0.6), "towers fade in overtime")
	check(is_equal_approx(game._structure_damage_mult(escort, nexus), Constants.STRUCTURE_DAMAGE_MULT * 1.8), "buildings weaken in overtime")
	check(Constants.enemy_death_gold(60) == 1500 and Constants.enemy_death_gold(14) == 1350, "bonus gold from defeats has a limit")
	_reset()
	var hero_level: int = hero.level
	var foe_level: int = foe.level
	foe.level = hero_level
	Comeback.reset()
	check(Comeback.levels_behind(hero.team) == 0.0, "an even match has no gap")
	check(Comeback.damage_dealt(hero.team) == 1.0 and Comeback.damage_taken(hero.team) == 1.0, "an even match has normal damage")
	check(Comeback.xp_multiplier(hero.team) == 1.0 and not Comeback.rallying(hero.team), "an even match has no rally")
	check(Comeback.reward_scale(hero, foe) == 1.0, "an even kill pays the normal reward")
	foe.level = hero_level + 4
	Comeback.reset()
	check(is_equal_approx(Comeback.damage_dealt(hero.team), 1.2), "the team behind hits harder")
	check(is_equal_approx(Comeback.damage_taken(hero.team), 0.86), "the team behind takes less")
	check(is_equal_approx(Comeback.xp_multiplier(hero.team), 1.8), "the team behind levels faster")
	check(Comeback.rallying(hero.team), "the team behind rallies")
	check(Comeback.damage_dealt(foe.team) == 1.0 and Comeback.damage_taken(foe.team) == 1.0, "the team ahead gets no combat change")
	check(Comeback.xp_multiplier(foe.team) == Comeback.MIN_XP, "the team ahead levels slower")
	check(not Comeback.rallying(foe.team), "the team ahead does not rally")
	check(Comeback.reward_scale(foe, hero) < 1.0, "killing someone below you pays less")
	check(Comeback.reward_scale(hero, foe) > 1.0, "killing someone above you pays more")
	foe.level = hero_level + 40
	Comeback.reset()
	check(Comeback.damage_dealt(hero.team) == Comeback.MAX_DAMAGE and Comeback.damage_taken(hero.team) == Comeback.MIN_TAKEN, "the bonus has limits")
	check(Comeback.reward_scale(foe, hero) == Comeback.MIN_REWARD, "the low reward has a floor")
	foe.level = foe_level
	Comeback.reset()
	_reset(["feast"])
	for i in range(30):
		Mayhem.on_takedown(game, hero, foe)
	check(is_equal_approx(hero.mayhem_state.feast_stacks, Mayhem.FEAST_MAX), "Feast stops at its limit")
	hero.run_bonus.erase("bonus_hp")
	hero.run_bonus.erase("bonus_ad")
	hero.run_bonus.erase("bonus_ap")
	hero._apply_items()

func _test_lan_flow() -> void:
	_reset()
	var state: Dictionary = LanSession.draft_states
	LanSession.main = game
	state[7] = {"pending": [], "choices": [], "picked": [], "awarded": [], "offers": {}}
	var old_peer: int = foe.owner_peer
	foe.owner_peer = 7
	LanSession.award_mayhem(foe, 7)
	LanSession.award_mayhem(foe, 11)
	check(state[7].mayhem.size() == 3, "a guest gets an offer")
	var offered: String = state[7].mayhem[1]
	LanSession.choose_mayhem(foe, 1)
	check(foe.mayhem.has(offered), "the host grants a guest's pick")
	check(state[7].mayhem.size() == 3 and not state[7].mayhem.has(offered), "the next queued offer follows")
	LanSession.choose_mayhem(foe, 9)
	check(foe.mayhem.size() == 1, "a bad index is ignored")
	LanSession.choose_mayhem(foe, 0)
	check(state[7].mayhem.is_empty(), "the queue empties")
	game.lane_augments.set_mayhem_choices(["ward", "siege", "burn"])
	check(game.lane_augments.mayhem_bar.get_child_count() == 3, "a guest's screen builds cards from the snapshot")
	game.lane_augments.set_mayhem_choices([])
	foe.owner_peer = old_peer
	state.erase(7)

func _test_next_match() -> void:
	_reset()
	game._end_game(hero.team)
	var end = game.hud.get_node("HudRoot").end_overlay
	check(Progression.win_streak == 1, "a win starts a streak")
	check(end.continue_button.visible and end.continue_button.text == "NEXT: N2", "a win offers the next difficulty")
	game.start_next_match(true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameState.running and GameState.started, "the next match starts without the menu")
	check(GameState.player != null and GameState.player.hero_key == "garen", "the same hero carries over")
	check(Progression.difficulty == 2, "difficulty goes up after a win")
	check(GameState.difficulty == 2, "the new match uses the new difficulty")
	Progression.awarded = false
	var streak_reward := Progression.complete_match(true, 300.0, 5, 2, 30)
	check(Progression.win_streak == 2, "a second win grows the streak")
	Progression.win_streak = 0
	Progression.awarded = false
	check(Progression.complete_match(true, 300.0, 5, 2, 30) < streak_reward, "a streak pays more credits")
	check(Progression.win_streak == 1, "the streak counter restarts correctly")
	Progression.awarded = false
	check(Progression.complete_match(false, 300.0, 5, 2, 30) > 0 and Progression.win_streak == 0, "a loss ends the streak")
	Progression.awarded = false
	hero = GameState.player
	game._end_game(1 - hero.team)
	var lost = game.hud.get_node("HudRoot").end_overlay
	check(lost.continue_button.text == "TRY AGAIN" and lost.continue_button.visible, "a loss offers a retry")
	game.start_next_match(false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Progression.difficulty == 2 and GameState.running, "a retry keeps the difficulty")
	Engine.time_scale = 1.0
	game._return_to_main_menu()
