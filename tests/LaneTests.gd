extends Node

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	check(not GameState.started, "ARAM begins on hero select")
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe")
	var p = GameState.player
	var draft = game.lane_augments
	check(GameState.champions.size() == 6 and GameState.structures.size() == 12, "teams and bases exist")
	check(p.level == 3 and p.skill_ranks == [1, 1, 1, 0], "basic kit learned, ultimate earned at 6")
	check(draft.pending.is_empty(), "starting level grants no free build")
	p.grant_xp(Constants.xp_to_level(3))
	draft.toggle_panel()
	var clock = GameState.time
	game._process(0.05)
	check(GameState.time > clock and not GameState.paused, "augments do not pause the lane")
	check(draft.choices.size() == 3, "draft has three choices")
	var choices = draft.choices.duplicate()
	draft.toggle_panel()
	draft.toggle_panel()
	check(draft.choices == choices, "reopening cannot reroll choices")
	draft.choose(draft.choices[0])
	var bonus = p.run_bonus.duplicate(true)
	check(p.try_buy_item("long_sword"), "purchase works")
	check(p.run_bonus == bonus and not bonus.is_empty(), "items retain drafted stats")
	p.grant_xp(Constants.xp_to_level(4) + Constants.xp_to_level(5))
	draft.refresh_milestones()
	check(p.level == 6 and draft.pending == [6], "level 6 unlocks next draft")
	check(p.try_level_skill(3), "ultimate unlocks at level 6")
	draft.refresh_milestones()
	check(draft.pending == [6], "draft milestone is awarded once")
	# Wave tanking, naked dives, and champion aggression under a tower.
	var tower = null
	for structure in GameState.structures:
		if structure.team == 1 and structure.variant == "outer": tower = structure
	for champion in GameState.champions:
		champion.global_position = Constants.FOUNT_B if champion.team == 0 else Constants.FOUNT_R
	p.global_position = tower.world_pos() + Vector2(-100, 70)
	tower.update_frame(0.05)
	check(tower.target == p, "tower attacks a champion diving without minions")
	var tank = game.MinionS.new()
	game.world_root.add_child(tank)
	tank.setup(0, "melee", tower.world_pos() + Vector2(-40, 0))
	GameState.minions.append(tank)
	tower.update_frame(0.05)
	check(tower.target == tank, "minion wave draws tower fire")
	var defender = GameState.champions[3]
	defender.global_position = tower.world_pos() + Vector2(0, 60)
	game.deal_damage(p, defender, 1, "skill")
	tower.update_frame(0.05)
	check(tower.target == p, "hitting a defender draws aggro through the minion wave")
	p.global_position = tower.world_pos() + Vector2(-500, 0)
	tower.update_frame(0.05)
	check(tower.target == tank, "leaving tower range drops champion aggro")
	tank.dead = true
	# Dying costs lane presence, rather than ending the match or resetting a build.
	game._handle_death(defender, p)
	check(p.dead and GameState.running, "death keeps the match running")
	GameState.time = p.respawn_at
	game._process(0.05)
	check(not p.dead and p.run_bonus == bonus, "respawn keeps the build")
	for projectile in GameState.projectiles: projectile.queue_free()
	GameState.projectiles.clear()
	# Attack-move resumes its destination after a target dies.
	var dummy = game.MinionS.new()
	game.world_root.add_child(dummy)
	dummy.setup(1, "melee", p.global_position + Vector2(50, 0))
	dummy.dead = true
	p.attack_target = dummy
	p.attack_move = true
	p.attack_move_destination = p.global_position + Vector2(200, 0)
	p.has_move_target = false
	p.update_frame(0.01)
	check(p.move_target == p.attack_move_destination and p.has_move_target, "attack-move resumes after a kill")
	dummy.queue_free()
	# Let both teams play the lane with their normal AI, skills, economy and waves.
	for champion in GameState.champions:
		champion.global_position = Constants.FOUNT_B if champion.team == 0 else Constants.FOUNT_R
		champion.hp = champion.hp_max
		champion.mp = champion.mp_max
		champion.stop_actions()
	p.is_bot = true
	var start = GameState.time
	var score = 0
	while GameState.running and GameState.time - start < 600:
		game._process(1.0 / 60.0)
		score += 1
		if score % 30 == 0: await get_tree().process_frame
	var damaged = false
	for structure in GameState.structures:
		if structure.dead or structure.hp < structure.hp_max: damaged = true
	check(damaged, "waves and teams make progress against structures")
	print("MOBA PLAYTEST: %.1fs, kills %s, waves %d, running %s" % [GameState.time - start, GameState.score, GameState.wave_num, GameState.running])
	print("LANE TESTS: %d failures" % failures)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
