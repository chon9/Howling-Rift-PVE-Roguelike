extends Node

var failures = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	check(ChampionData.CHAMPIONS.size() == 32, "thirty-two selectable champions")
	for key in ["lux", "ahri", "ezreal"]:
		GameState.reset()
		var game = load("res://scripts/Main.gd").new()
		add_child(game)
		game.set_process(false)
		game._start_game(key)
		var p = GameState.player
		check(p.hero_key == key and p.champion_texture != null, key + " is playable and has artwork")
		check(ItemData.BUILD_ORDERS.has(key), key + " has item recommendations")
		p.global_position = Vector2(1300, 270)
		p.level = 6
		p.skill_ranks = [1, 1, 1, 1]
		p._recompute_stats()
		var target = GameState.champions[3]
		target.global_position = Vector2(1420, 270)
		target.hp = 10000
		target.hp_max = 10000
		for i in range(4):
			p.mp = p.mp_max
			p.skill_cds[i] = 0
			check(p.try_cast_skill(i, target.world_pos()), "%s %s casts" % [key, p.hero.skills[i].key])
			check(p.skill_cds[i] > 0, "successful cast starts cooldown")
			for frame in range(100):
				for projectile in GameState.projectiles.duplicate(): projectile.update_frame(1.0 / 60.0)
				for area in GameState.aoes.duplicate(): area.update_frame(1.0 / 60.0)
				if frame % 30 == 0: await get_tree().process_frame
			if key == "ezreal" and i == 1:
				check(target.buffs.has("flux_mark"), "Essence Flux applies mark")
				var previous_hp = target.hp
				game.deal_damage(p, target, 10, "auto")
				check(not target.buffs.has("flux_mark") and target.hp < previous_hp - 10, "Ezreal detonates mark")
		check(target.hp < 10000, key + " deals damage")
		p.is_bot = true
		for champion in GameState.champions:
			champion.global_position = Constants.FOUNT_B if champion.team == 0 else Constants.FOUNT_R
			champion.hp = champion.hp_max
		for frame in range(2400):
			game._process(1.0 / 60.0)
			if frame % 30 == 0: await get_tree().process_frame
		print("HERO TEST: %s skills, artwork, items and 40s bot match passed" % key)
		game.queue_free()
		await get_tree().process_frame
	print("HERO TESTS: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
