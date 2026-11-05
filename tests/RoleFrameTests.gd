extends Node
# What makes each role worth picking.
var failures = 0
var checks = 0
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL ROLES: " + message)

func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._show_menu()
	game._start_game("garen")
	await get_tree().process_frame
	var tank = _hero(0, "malphite")
	var fighter = _hero(0, "darius")
	var shooter = _hero(1, "jinx")
	var mage = _hero(1, "lux")
	for lv in [3, 10, 18]:
		for c in [tank, fighter, shooter, mage]:
			c.level = lv
			c._recompute_stats()
		check(tank.base_armor > fighter.base_armor and fighter.base_armor > shooter.base_armor, "toughness follows the role at level %d" % lv)
		check(shooter.base_armor > 0.0, "every hero has some armor at level %d" % lv)
		check(tank.hp_max > shooter.hp_max * 1.3, "a tank has far more health than a marksman at level %d" % lv)
		check(tank.base_mr > shooter.base_mr, "a tank resists magic better at level %d" % lv)
	check(ExpansionCombat.resist(tank, shooter, "auto") == tank.base_armor, "armor counts against attacks")
	check(ExpansionCombat.resist(tank, mage, "magic") == tank.base_mr, "armor does not count against magic")
	check(tank.effective_move_speed() > tank.move_speed, "melee heroes are faster than their base speed")
	check(fighter.effective_move_speed() > shooter.effective_move_speed() - 10.0, "a bruiser can keep up with a marksman")
	# A tank's health is its damage.
	var with_hp: float = RoleFrames.dealt(tank, shooter, 100.0, "auto")
	check(is_equal_approx(with_hp, 100.0 + tank.hp_max * RoleFrames.TANK_HIT_HP), "tank hits add a share of max health")
	check(is_equal_approx(RoleFrames.dealt(mage, fighter, 100.0, "auto"), 100.0), "only tanks scale off health")
	check(RoleFrames.dealt(fighter, shooter, 100.0, "auto") > 100.0, "bruisers hit heroes harder")
	check(RoleFrames.dealt(shooter, fighter, 100.0, "auto") < 100.0, "marksmen pay for their range")
	check(RoleFrames.dealt(tank, shooter, 100.0, "burn") == 100.0, "burns do not repeat the bonus")
	# A tank protects whoever stands near it.
	GameState.champions.append(tank)
	GameState.champions.append(fighter)
	tank.roster_active = true
	fighter.roster_active = true
	tank.global_position = Vector2(1300, 270)
	fighter.global_position = Vector2(1400, 270)
	check(is_equal_approx(RoleFrames.taken(fighter), RoleFrames.GUARD_TAKEN), "an ally near a tank takes less damage")
	fighter.global_position = Vector2(1300 + RoleFrames.GUARD_RANGE + 50.0, 270)
	check(RoleFrames.taken(fighter) >= 1.0, "an ally far from the tank does not")
	# Melee attacks stick to their target; ranged attacks do not.
	shooter.buffs.clear()
	RoleFrames.on_hit(mage, fighter, "auto")
	check(not fighter.buffs.has("slow"), "ranged attacks do not slow")
	RoleFrames.on_hit(fighter, shooter, "auto")
	check(shooter.buffs.has("slow"), "melee attacks slow an enemy hero")
	var speed: float = shooter.effective_move_speed()
	shooter.buffs.clear()
	check(shooter.effective_move_speed() > speed, "the slow actually slows")
	shooter.buffs["slow"] = {"time": 2.0, "pct": 0.5}
	RoleFrames.on_hit(fighter, shooter, "auto")
	check(shooter.buffs.slow.pct == 0.5, "a stronger slow is not replaced")
	# Every hero has a frame, and tests can pin the old formula.
	for key in ChampionData.CHAMPIONS:
		check(RoleFrames.FRAMES.has(RoleFrames.role_of(key)), "%s has a role frame" % key)
		check(RoleFrames.role_of(key) == game.lane_augments.role_for({"hero_key": key}), "%s has one role everywhere" % key)
	RoleFrames.enabled = false
	tank._recompute_stats()
	check(tank.base_armor == 0.0, "frames can be switched off for formula tests")
	RoleFrames.enabled = true
	game.queue_free()
	await get_tree().process_frame
	print("ROLE FRAMES: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _hero(team: int, key: String):
	var c = game.ChampionS.new()
	game.world_root.add_child(c)
	c.setup(team, key, true, key)
	return c
