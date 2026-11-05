extends Node
var failures = 0
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	# An isolated profile proves disk persistence without modifying the player's save.
	var profile = load("res://scripts/Progression.gd").new()
	profile.save_path = "res://tests/progression-test.cfg"
	profile.persistent = true
	profile.credits = 1000
	profile.difficulty = 42
	profile.levels.stride = 2
	var first_cost = profile.cost("vitality")
	check(profile.buy("vitality"), "purchase succeeds")
	check(profile.cost("vitality") > first_cost, "higher levels cost more")
	var last_price = profile.cost("vitality")
	for lv in range(2, 100):
		profile.levels.vitality = lv
		check(profile.cost("vitality") > last_price and profile.cost("vitality") < 2000000, "upgrade cost increases across the long-term grind at level %d" % lv)
		last_price = profile.cost("vitality")
	profile.levels.vitality = 1
	var restored = load("res://scripts/Progression.gd").new()
	restored.save_path = profile.save_path
	restored.load_profile()
	check(restored.credits == 1000-first_cost and restored.difficulty == 42 and restored.levels.vitality == 1, "credits, difficulty and upgrades survive disk reload")
	check(restored.bonuses().bonus_hp == 35, "permanent value increments")
	check(restored.levels.stride == 2 and is_equal_approx(restored.bonuses().bonus_ms,0.01), "movement ranks survive disk reload")
	restored.credits = 0
	check(not restored.buy("vitality") and restored.levels.vitality == 1, "cannot buy without credits")
	restored.persistent = false
	restored.begin_match()
	var reward = restored.complete_match(false, 120, 2, 1)
	check(reward > 0, "defeat pays credits")
	var before = restored.credits
	restored.complete_match(false, 120, 2, 1)
	check(restored.credits == before, "match awards only once")
	restored.begin_match()
	check(restored.complete_match(true, 120, 2, 1) > reward, "victory pays extra")
	restored.begin_match()
	check(restored.complete_match(false, 120, 2, 99) > reward, "difficulty improves rewards")
	var previous = Progression.scaling(1)
	for stage in range(2, 100):
		var scale = Progression.scaling(stage)
		check(scale.health > previous.health and scale.damage > previous.damage and scale.reaction < previous.reaction and scale.vision > previous.vision and scale.chase > previous.chase, "difficulty grows monotonically at N%d" % stage)
		previous = scale
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.save_path))
	profile.free()
	restored.free()
	Progression.levels = {"vitality": 2, "might": 1}
	Progression.difficulty = 99
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe")
	var p = GameState.player
	check(p.bonus_hp == 70 and p.bonus_ad == 3, "player starts with permanent bonuses")
	p.gold = 10000
	p.try_buy_item(ItemData.BUILD_ORDERS.ashe[0])
	check(p.bonus_hp >= 70 and p.bonus_ad >= 3, "items retain permanent bonuses")
	var enemy = GameState.champions[3]
	check(enemy.hp_max > p.hp_max * 5 and enemy.difficulty_stats.damage > 6, "N99 enemy scaling applies")
	var hp_before = p.hp
	game.deal_damage(enemy, p, 10, "auto")
	check(hp_before - p.hp >= 60, "enemy damage uses difficulty scaling")
	p.global_position = Vector2(1800, 360)
	GameState.cam_target = Vector2(300, 200)
	get_viewport().warp_mouse(Vector2(1, 1))
	game._update_camera(0.05)
	check(GameState.cam_locked and game.camera.position.distance_to(p.global_position) < 1, "camera follows hero even at screen edge and after teleport")
	p.global_position += Vector2(100, -50)
	for frame in range(60): game._update_camera(1.0 / 60.0)
	check(game.camera.position.distance_to(p.global_position) < 1, "camera follows both axes smoothly")
	# Isolate a pursuit from unrelated champions and towers.
	enemy = game.ChampionS.new()
	game.world_root.add_child(enemy)
	enemy.setup(Constants.RED, "garen", true, "Pursuit test")
	enemy.skill_ranks = [1, 1, 1, 0]
	GameState.champions.append(enemy)
	for c in GameState.champions:
		if c != p and c != enemy: c.dead = true
	for tower in GameState.structures: tower.dead = true
	enemy.difficulty_stats = Progression.scaling(1)
	enemy.global_position = Vector2(1100, 270)
	enemy.hp = enemy.hp_max
	p.global_position = Vector2(1450, 270)
	p.hp = 10
	p.shield = 0
	check(enemy.can_secure_kill(p), "AI identifies a finishable hero")
	enemy.ai_tick = 0
	enemy._run_bot_ai(0.05)
	check(enemy.attack_target == p and enemy.chase_target == p, "AI pursues vulnerable hero beyond attack range")
	GameState.time = enemy.chase_until + 0.1
	enemy.ai_tick = 0
	enemy._run_bot_ai(0.05)
	check(enemy.chase_target == null and enemy.attack_target != p, "pursuit deadline releases attack target and prevents endless chasing")
	p.hp = p.hp_max * 10
	check(not enemy.can_secure_kill(p), "AI rejects an unfinishable target")
	Progression.levels.clear()
	Progression.difficulty = 1
	print("Progression/camera/difficulty/AI failures: ", failures)
	get_tree().quit(1 if failures else 0)
