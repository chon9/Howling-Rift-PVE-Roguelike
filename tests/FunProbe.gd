extends Node
# Plays a whole match with the player's hero on bot control and reports how the time was spent.
# Usage: HOWLING_VIEW=2d FUN_HERO=garen FUN_N=1 godot --headless res://tests/FunProbe.tscn
const STEP := 0.02
const SAMPLE := 0.5
const MAX_TIME := 900.0

func _ready() -> void:
	var hero := OS.get_environment("FUN_HERO")
	if hero.is_empty(): hero = "garen"
	if hero == "random": hero = ChampionData.CHAMPIONS.keys().pick_random()
	var difficulty := int(OS.get_environment("FUN_N")) if OS.has_environment("FUN_N") else 1
	Progression.persistent = false
	Progression.difficulty = difficulty
	GameState.reset()
	GameState.difficulty = difficulty
	Progression.allied_bots = OS.get_environment("FUN_ALLIES") != "0"
	ViewConfig.enabled = false
	var game: Node2D = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game(hero)
	GameState.difficulty = difficulty
	var p = GameState.player
	p.is_bot = true
	if OS.has_environment("FUN_MIRROR"):
		# Controlled test: equal bots on both sides, without the player slot.
		p.disable_roster_slot()
		for c in GameState.champions:
			if c.team != p.team and c.roster_active:
				c.disable_roster_slot()
				break
	var time_dead := 0.0
	var time_hero_fight := 0.0
	var time_creeps := 0.0
	var time_idle := 0.0
	var idle_stretch := 0.0
	var longest_idle := 0.0
	var idle_stretches := []
	var team_kills := {0: 0, 1: 0}
	var seen := {}
	var kill_times: Array = []
	var last_total := 0
	var casts := 0
	var last_cds: Array = []
	var level_at := {}
	var tower_falls: Array = []
	var fallen := {}
	var hp_hist: Array = []
	var accumulate := 0.0
	var next_sample := SAMPLE
	while GameState.running and GameState.time < MAX_TIME:
		game._simulate_step(STEP)
		# The player slot is bot-driven here, so it has to make its upgrade picks too.
		if not game.lane_augments.mayhem_choices.is_empty():
			game.lane_augments.choose_mayhem(randi() % game.lane_augments.mayhem_choices.size())
		if not game.lane_augments.pending.is_empty():
			game.lane_augments.choose(0)
		if GameState.time < next_sample:
			continue
		next_sample += SAMPLE
		if OS.has_environment("FUN_TRACE") and int(GameState.time * 2.0) % 60 == 0:
			var down := 0
			for s in GameState.structures:
				if s.dead: down += 1
			print("TRACE t=%d wall=%d score=%s down=%d minions=%d lvl=%d" % [int(GameState.time), Time.get_ticks_msec() / 1000, str(GameState.score), down, GameState.minions.size(), p.level])
		var total := 0
		for c in GameState.champions:
			total += c.kills
		if total > last_total:
			for i in range(total - last_total):
				kill_times.append(GameState.time)
			last_total = total
		for s in GameState.structures:
			if s.dead and not fallen.has(s):
				fallen[s] = true
				tower_falls.append({"t": int(GameState.time), "type": s.type, "team": s.team})
		var minute := int(GameState.time / 60.0)
		if not level_at.has(minute):
			level_at[minute] = p.level
		if last_cds.size() == p.skill_cds.size():
			for i in range(last_cds.size()):
				if p.skill_cds[i] > last_cds[i] + 0.2:
					casts += 1
		last_cds = p.skill_cds.duplicate()
		if p.dead:
			time_dead += SAMPLE
			if idle_stretch > 0.0:
				idle_stretches.append(idle_stretch)
			idle_stretch = 0.0
			continue
		var pos: Vector2 = p.world_pos()
		var hero_near := false
		for c in GameState.champions:
			if c.team != p.team and not c.dead and c.roster_active and pos.distance_to(c.world_pos()) < 450.0:
				hero_near = true
		var creep_near := false
		for m in GameState.minions:
			if m.team != p.team and not m.dead and pos.distance_to(m.world_pos()) < 400.0:
				creep_near = true
				break
		if hero_near:
			time_hero_fight += SAMPLE
		elif creep_near:
			time_creeps += SAMPLE
		else:
			time_idle += SAMPLE
		if hero_near or creep_near:
			if idle_stretch > 0.0:
				idle_stretches.append(idle_stretch)
			idle_stretch = 0.0
		else:
			idle_stretch += SAMPLE
			longest_idle = maxf(longest_idle, idle_stretch)
	var duration := GameState.time
	var gaps: Array = []
	for i in range(1, kill_times.size()):
		gaps.append(kill_times[i] - kill_times[i - 1])
	gaps.sort()
	var result := {
		"hero": hero, "n": difficulty, "allies": GameState.allied_bots, "duration_s": int(duration), "finished": not GameState.running,
		"blue_nexus_dead": GameState.nexus[0].dead, "red_nexus_dead": GameState.nexus[1].dead,
		"kda": "%d/%d/%d" % [p.kills, p.deaths, p.assists], "cs": p.cs, "level": p.level, "gold": int(p.gold),
		"pct_dead": int(100.0 * time_dead / maxf(duration, 1.0)), "pct_hero_fight": int(100.0 * time_hero_fight / maxf(duration, 1.0)),
		"pct_creeps_only": int(100.0 * time_creeps / maxf(duration, 1.0)), "pct_nothing": int(100.0 * time_idle / maxf(duration, 1.0)),
		"longest_nothing_s": int(longest_idle), "casts_per_min": snappedf(casts / maxf(duration / 60.0, 0.1), 0.1),
		"total_kills": last_total, "first_kill_s": int(kill_times[0]) if not kill_times.is_empty() else -1,
		"median_kill_gap_s": int(gaps[gaps.size() / 2]) if not gaps.is_empty() else -1,
		"structures": tower_falls, "levels": level_at,
	}
	var board := []
	for c in GameState.champions:
		board.append({"h": c.hero_key, "t": c.team, "on": c.roster_active, "bot": c.is_bot, "k": c.kills, "d": c.deaths, "a": c.assists, "lv": c.level, "hp": int(c.hp_max), "ad": int(c.ad), "m": c.mayhem.keys(), "stolen": not c.stolen_blueprint.is_empty(), "player": c == p, "role": game.lane_augments.role_for(c), "dmg": int(c.hero_damage_dealt), "taken": int(c.hero_damage_taken), "bonus_gold": c.comeback_gold_awarded, "items": c.inventory.filter(func(i): return i != "").size(), "gold": int(c.gold)})
	result["board"] = board
	result["score"] = GameState.score
	print("FUNPROBE " + JSON.stringify(result))
	get_tree().quit(0)
