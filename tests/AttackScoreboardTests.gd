extends Node
var failures = 0
var checks = 0
var game
var p
func check(value: bool,message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+message)
func reset_attack() -> void:
 p.stop_actions()
 p.global_position = Vector2(1300,270)
 p.atk_cd = 0
 p.stun = 0
func key(code: Key, pressed: bool) -> void:
 var event = InputEventKey.new()
 event.keycode = code
 event.pressed = pressed
 get_viewport().push_input(event,true)
func click(at: Vector2) -> void:
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = at
 event.pressed = true
 get_viewport().push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 get_viewport().push_input(event,true)
func capture(path: String) -> void:
 await get_tree().process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("garen")
 p = GameState.player
 for c in GameState.champions:
  c.is_bot = false
  c.stop_actions()
  c.global_position = Constants.FOUNT_B if c.team == p.team else Constants.FOUNT_R
 for s in GameState.structures: s.is_targetable = false
 var enemy = GameState.champions[3]
 enemy.global_position = Vector2(1700,270)
 reset_attack()
 game._issue_player_order({"type":"smart","point":enemy.world_pos()+enemy.art_rect().get_center()})
 check(p.attack_target == enemy,"right-clicking the visible hero body targets it")
 check(game.reticle_node._find_hover(enemy.world_pos()+enemy.art_rect().get_center()) == enemy,"hover reticle agrees with body click")
 var creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",Vector2(1380,270))
 GameState.minions.append(creep)
 reset_attack()
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 p.update_frame(0.01)
 var initial_hp = creep.hp
 var previous_windup = p.auto_windup
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 check(p.auto_windup == previous_windup and p.queued_auto_target == creep,"repeated target clicks preserve windup")
 for frame in range(25):
  game._issue_player_order({"type":"amove" if frame%2 else "smart","point":creep.world_pos()})
  p.update_frame(0.02)
 check(creep.hp < initial_hp,"spam-clicking the same creep still lands an attack")
 var recovery = p.atk_cd
 game._issue_player_order({"type":"smart","point":Vector2(1200,350)})
 check(p.attack_target == null and p.has_move_target and p.atk_cd == recovery,"move after contact cancels backswing without resetting attack cooldown")
 reset_attack()
 creep.global_position = Vector2(1680,270)
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 var reached = false
 for frame in range(300):
  p.update_frame(0.01)
  if p.queued_auto_target != null:
   reached = true
   var distance = p.world_pos().distance_to(creep.world_pos())
   check(distance <= p.auto_attack_reach(creep) and distance >= p.auto_attack_reach(creep)-8,"melee approach stops at attack range instead of walking through the target")
   break
 check(reached,"out-of-range click approaches and starts an attack")
 var contact_hp = creep.hp
 for frame in range(40): p.update_frame(0.01)
 check(creep.hp < contact_hp,"melee hit lands after approaching")
 reset_attack()
 creep.global_position = p.world_pos()+Vector2(80,0)
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 p.update_frame(0.01)
 contact_hp = creep.hp
 game._issue_player_order({"type":"smart","point":Vector2(1200,350)})
 for frame in range(35): p.update_frame(0.01)
 check(creep.hp == contact_hp and p.queued_auto_target == null,"ground movement cancels an unfinished melee swing")
 reset_attack()
 creep.global_position = p.world_pos()+Vector2(80,0)
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 p.update_frame(0.01)
 p.stun = 1
 p.update_frame(0.01)
 check(p.queued_auto_target == null,"stun interrupts windup")
 reset_attack()
 creep.global_position = p.world_pos()+Vector2(80,0)
 game._issue_player_order({"type":"smart","point":creep.world_pos()})
 p.update_frame(0.01)
 creep.global_position += Vector2(220,0)
 for frame in range(30): p.update_frame(0.01)
 check(p.atk_cd == 0 and p.queued_auto_target == null and p.has_move_target,"escaping before contact retries without wasting a full cooldown")
 reset_attack()
 creep.global_position = p.world_pos()+Vector2(180,0)
 game._issue_player_order({"type":"amove","point":Vector2(1480,300)})
 check(p.attack_target == creep,"ground attack move acquires a nearby cursor creep outside melee range")
 for frame in range(100): p.update_frame(0.01)
 check(p.attack_target == creep,"attack move acquires nearby creeps while approaching")
 reset_attack()
 creep.dead = true
 p.attack_target = creep
 p.has_move_target = true
 p.update_frame(0.01)
 check(p.attack_target == null and not p.has_move_target,"dead direct target clears stale chase movement")
 var ui = game.hud.get_node("HudRoot")
 p.kills = 7; p.deaths = 2; p.assists = 4; p.cs = 65; p.gold = 2450
 p.inventory[0] = "long_sword"
 enemy.kills = 2; enemy.deaths = 7; enemy.assists = 1
 enemy.dead = true; enemy.respawn_at = GameState.time+5
 GameState.score = [7,2]
 game._update_camera(1)
 ui.refresh(0)
 game.set_fullscreen(true)
 await get_tree().create_timer(0.25).timeout
 key(KEY_TAB,true)
 check(ui.scoreboard.visible and not GameState.paused,"Tab shows scoreboard without pausing")
 check(ui.scoreboard.rows.size() == 6,"scoreboard includes both three-player teams")
 check(ui.scoreboard.rows[p].kda.text == "7 / 2 / 4" and ui.scoreboard.rows[p].cs.text == "65","scoreboard shows individual K/D/A and CS")
 check(ui.scoreboard.rows[p].icons[0].texture != null and ui.scoreboard.rows[p].gold.text == "2450g","scoreboard includes items and gold")
 check(ui.scoreboard.rows[enemy].hero.text.contains("Respawn 5s"),"scoreboard shows death/respawn status")
 check(ui.scoreboard.get_global_rect().position.x >= 0 and ui.scoreboard.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x,"scoreboard fits viewport")
 await capture("res://tests/41-kda-scoreboard-fullscreen.png")
 key(KEY_TAB,false)
 check(not ui.scoreboard.visible,"releasing Tab hides scoreboard")
 click(ui.score_label.get_global_rect().get_center())
 check(ui.scoreboard.visible,"clicking team kills toggles scoreboard")
 p.kills = 8
 ui.refresh(0)
 check(ui.scoreboard.rows[p].kda.text == "8 / 2 / 4","scoreboard stats update while open")
 key(KEY_ESCAPE,true)
 check(not ui.scoreboard.visible and not GameState.paused,"Esc closes scoreboard before pause menu")
 game.set_fullscreen(false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 await get_tree().create_timer(0.25).timeout
 key(KEY_TAB,true)
 await capture("res://tests/42-kda-scoreboard-windowed.png")
 key(KEY_TAB,false)
 ui.set_scoreboard_visible(true)
 ui.show_end_screen(true)
 check(not ui.scoreboard.visible,"match result closes the scoreboard")
 GameState.running = false
 ui.set_scoreboard_visible(true)
 check(not ui.scoreboard.visible,"scoreboard cannot obscure finished-match actions")
 print("ATTACK / SCOREBOARD: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
