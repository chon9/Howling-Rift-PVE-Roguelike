extends Node
var failures = 0

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	for key in ChampionData.CHAMPIONS:
		GameState.reset()
		var game = load("res://scripts/Main.gd").new()
		add_child(game)
		game.set_process(false)
		game._start_game(key)
		var p = GameState.player
		check(p.champion_texture != null, "painted gameplay sprite for " + key)
		# Gameplay uses the articulated action sheet; champion_texture is a UI portrait.
		var image = p.animator.texture().get_image()
		check(image != null and image.detect_alpha() != Image.ALPHA_NONE, "hero sprite retains transparency")
		var ui = game.hud.get_node("HudRoot")
		ui.skill_slots[0].hover_entered.emit()
		check(ui.tooltip_panel.visible and ui.tooltip_label.text.contains(p.hero.skills[0].desc) and ui.tooltip_label.text.contains("Mana:") and ui.tooltip_label.text.contains("Cooldown:") and ui.tooltip_label.text.contains("Range:"), "hover shows full skill description")
		ui.skill_slots[0].hover_exited.emit()
		check(not ui.tooltip_panel.visible, "hover exit hides description")
		check(game.sound_fx.clips.size() == game.sound_fx.NAMES.size() and game.sound_fx.announcer_clips.size() == game.sound_fx.ANNOUNCER_NAMES.size() and game.sound_fx.voices.size() == 12, "bounded sound pool and full sound bank")
		for sound in game.sound_fx.clips.values(): check(sound is AudioStreamWAV and sound.data.size() > 0 and sound.get_length() >= 0.05, "valid effect waveform")
		var target = GameState.champions[3]
		p.global_position = Vector2(1300, 270)
		target.global_position = Vector2(1400, 270)
		p._perform_auto(target)
		check(not game.sound_fx.counts.is_empty(), "autoattack plays sound")
		game.sound_fx.last_played.clear()
		game.sound_fx.counts.clear()
		p.mp = 0
		if p.hero.skills[0].cost > 0:
			check(not p.try_cast_skill(0, target.world_pos()) and game.sound_fx.counts.is_empty(), "failed cast does not play spell sound")
		p.mp = p.mp_max
		check(p.try_cast_skill(0, target.world_pos()) and not game.sound_fx.counts.is_empty(), "successful cast plays themed sound")
		var total = 0
		for count in game.sound_fx.counts.values(): total += count
		game.sound_fx.enabled = false
		game.play_sfx("coin")
		var after = 0
		for count in game.sound_fx.counts.values(): after += count
		check(total == after, "muted sound emits no effect")
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("Audio, painted heroes and hover tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
