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
	var visual = "--visual" in OS.get_cmdline_user_args()
	if visual:
		game.set_fullscreen(true)
		await get_tree().create_timer(0.3).timeout
	game._start_game("ashe")
	var p = GameState.player
	var ui = game.hud.get_node("HudRoot")
	p.global_position = Vector2(1320, 270)
	game._update_camera(1)
	p.is_dashing = true
	p.manual_move = Vector2.RIGHT
	p.start_recall()
	check(p.recall_time == 0 and not p.is_dashing and p.manual_move == Vector2.ZERO, "recall clears lingering movement and dash")
	p.update_frame(1.25)
	ui.refresh(0)
	check(ui.recall_bar.visible and is_equal_approx(ui.recall_fill.value, 1.25) and ui.recall_label.text.contains("2.8s"), "recall shows actual progress and remaining seconds")
	check(p.world_pos() == Vector2(1320, 270), "recall holds position while channeling")
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/18-recall-and-icons.png")
	p.update_frame(2.8)
	ui.refresh(0)
	check(p.world_pos() == Constants.FOUNT_B and p.recall_time == -1 and not ui.recall_bar.visible, "recall completes at four seconds and hides timer")
	p.start_recall()
	p.start_recall()
	check(p.recall_time == -1, "B toggles recall off")
	p.start_recall()
	p.stop_actions()
	check(p.recall_time == -1, "S cancels recall")
	p.start_recall()
	game._issue_player_order({"type":"smart", "point":Vector2(1300, 270)})
	check(p.recall_time == -1, "movement cancels recall")
	p.start_recall()
	p.shield = 1000
	var enemy = GameState.champions[3]
	game.deal_damage(enemy, p, 10, "auto")
	check(p.recall_time == -1, "enemy damage interrupts recall even when shield absorbs it")
	p.shield = 0
	p.start_recall()
	game._handle_death(enemy, p)
	ui.refresh(0)
	check(p.recall_time == -1 and not ui.recall_bar.visible, "death clears recall")
	game._respawn_champion(p)
	check(p.recall_time == -1, "respawn cannot resume stale recall")
	p.stun = 1
	p.start_recall()
	check(p.recall_time == -1, "stunned heroes cannot start recall")
	p.stun = 0
	p.level = 4
	p.skill_points = 3
	p.skill_ranks = [1, 1, 1, 0]
	check(not p.can_level_skill(-1) and not p.can_level_skill(4), "invalid rank choices are rejected")
	check(p.try_level_skill(0) and not p.try_level_skill(0) and not p.try_level_skill(3), "basic rank three requires level five; R requires six")
	check(p.skill_points == 2 and p.skill_ranks[0] == 2, "failed choices preserve points")
	p.skill_cds[1] = 0
	p.mp = p.mp_max
	ui.refresh(0)
	ui.skill_slots[1].clicked.emit()
	check(p.skill_cds[1] > 0 and p.skill_points == 2 and p.skill_ranks[1] == 1, "skill icon casts without spending upgrade points")
	await get_tree().process_frame
	await get_tree().process_frame
	# Real GUI event dispatch verifies that the child + button consumes its click.
	var old_cd = p.skill_cds[1]
	var button = ui.skill_slots[1].upgrade_button
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = button.get_global_rect().get_center()
	mouse.pressed = true
	get_viewport().push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	get_viewport().push_input(mouse, true)
	await get_tree().process_frame
	check(p.skill_ranks[1] == 2 and p.skill_points == 1 and p.skill_cds[1] == old_cd, "+ button spends exactly one point and does not cast")
	for key in ChampionData.CHAMPIONS:
		for index in range(4):
			var art = AbilityArt.icon_for(key, index)
			check(art != null and art.region.end.x <= art.atlas.get_width() and art.region.end.y <= art.atlas.get_height(), key + " painted skill icon crop")
	p.level = 6
	check(p.try_level_skill(3), "R unlocks at level six")
	p.global_position = Vector2(1320, 270)
	p.attack_target = null
	p.buffs.clear()
	enemy.global_position = Vector2(1345, 270)
	var creep = game.MinionS.new()
	game.world_root.add_child(creep)
	creep.setup(1, "melee", Vector2(1450, 270))
	creep.hp = 1
	GameState.minions.append(creep)
	var healthy = game.MinionS.new()
	game.world_root.add_child(healthy)
	healthy.setup(1, "caster", Vector2(1460, 320))
	GameState.minions.append(healthy)
	game._issue_player_order({"type":"amove", "point":creep.world_pos()})
	check(p.attack_target == creep and p.attack_move, "A click locks the clicked creep despite a closer enemy champion")
	check(GameState.find_attack_move_target(p, healthy.world_pos(), true) == healthy, "exact clicks respect player target choice even on healthy creeps")
	check(GameState.find_attack_move_target(p, creep.world_pos() + Vector2(10, 0)) == creep, "ground attack move selects nearest cursor target")
	check(GameState.last_hit_damage(p, creep) >= creep.hp, "last-hit highlight uses actual attack damage")
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_A
	key_event.pressed = true
	game._unhandled_input(key_event)
	check(game.attack_move_pending and GameState.attack_move_pending, "A activates targeting preview")
	if visual:
		p.skill_points = 1
		ui.refresh(0)
		ui.flash_rect.color = Color(0, 0, 0, 0)
		creep.update_frame(0)
		game.get_viewport().warp_mouse(Vector2(1120, 550))
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/19-last-hit-and-upgrades.png")
	key_event.keycode = KEY_S
	game._unhandled_input(key_event)
	check(not game.attack_move_pending and not p.attack_move, "S cancels attack targeting")
	key_event.keycode = KEY_A
	key_event.shift_pressed = true
	game._unhandled_input(key_event)
	check(p.attack_move and not game.attack_move_pending, "Shift+A issues attack move immediately")
	var old_cs = p.cs
	var old_gold = p.gold
	game._issue_player_order({"type":"amove", "point":creep.world_pos()})
	p.atk_cd = 0
	p.update_frame(0.01)
	for frame in range(30):
		p.update_frame(0.02)
		for projectile in GameState.projectiles.duplicate():
			if is_instance_valid(projectile): projectile.update_frame(0.02)
	check(creep.dead and p.cs == old_cs + 1 and p.gold == old_gold + creep.gold_val, "ranged last hit awards CS and creep gold")
	GameState.minions.erase(creep)
	creep.queue_free()
	await get_tree().process_frame
	p.update_frame(0.01)
	check(p.attack_target != creep, "attack move survives target removal")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Recall, upgrade GUI, ability art and last-hit tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
