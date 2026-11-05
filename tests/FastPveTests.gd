extends Node
var failures = 0
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	GameState.reset()
	var game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe")
	var p = GameState.player
	check(Constants.FIRST_WAVE_AT == 3 and Constants.WAVE_INTERVAL == 16, "fast wave pacing")
	check(p.recall_duration == 4 and p.effective_cd(10) == 8, "faster recall and spells")
	GameState.time = 1200
	p.skill_cds = [4.0, 12.0, 20.0, 45.0]
	p.summoner_cds = [45.0, 35.0]
	p.atk_cd = 3
	game._handle_death(GameState.champions[3], p)
	var wait = p.respawn_at - GameState.time
	check(wait >= 4 and wait <= 7, "late-match respawn remains short")
	for i in range(60): game._process(0.05)
	check(p.dead and is_equal_approx(p.skill_cds[1], 9.0) and is_equal_approx(p.summoner_cds[0], 42.0) and p.atk_cd < 0.01, "skills, summoners and attacks cool down during death")
	var frozen = p.skill_cds.duplicate()
	GameState.paused = true
	game._process(0.05)
	check(p.skill_cds == frozen, "pause freezes dead cooldowns")
	GameState.paused = false
	for i in range(100):
		if not p.dead: break
		game._process(0.05)
	check(not p.dead and p.skill_cds[3] > 35 and p.skill_cds[3] < 45, "respawn retains remaining cooldown instead of resetting it")
	check(p.buffs.has("haste") and p.effective_move_speed() > p.move_speed * 1.4, "respawn grants return-to-lane sprint")
	for hero in GameState.champions:
		if hero != p: hero.dead = true
	for tower in GameState.structures: tower.dead = true
	var bot = game.ChampionS.new()
	game.world_root.add_child(bot)
	bot.setup(1, "garen", true, "Combo bot")
	bot.skill_ranks = [1, 1, 1, 1]
	bot.global_position = Vector2(1300, 270)
	p.global_position = Vector2(1380, 270)
	p.hp = p.hp_max
	bot._try_bot_cast(p)
	check(bot.buffs.has("decisive") and bot.buffs.has("spin"), "melee AI chains useful skills instead of waiting one spell per tick")
	var archer = game.ChampionS.new()
	game.world_root.add_child(archer)
	archer.setup(1, "ashe", true, "Kiting bot")
	GameState.champions.append(archer)
	archer.global_position = Vector2(1300, 270)
	p.hp = 10
	archer._run_bot_ai(0.1)
	check(archer.attack_target == p and archer.manual_move.x < 0, "ranged AI attacks while kiting melee pressure")
	check(SpellArt.missiles.get_width() > 1000 and SpellArt.impacts.get_height() > 1000, "high resolution sprite sheets loaded")
	check(SpellArt.frame(SpellArt.impacts, 5, 7).end.x <= SpellArt.impacts.get_width(), "sprite sheet frames stay within texture bounds")
	check(game.sound_fx.clips.frost_ultimate.stereo and game.sound_fx.clips.frost.mix_rate >= 48000, "full stereo high-quality effects")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Fast PvE, AI, cooldown and visual tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
