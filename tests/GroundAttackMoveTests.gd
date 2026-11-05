extends Node
var failures = 0
var checks = 0
var game
var p
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+message)
func order(point: Vector2) -> void:
 var key = InputEventKey.new()
 key.keycode = KEY_A
 key.pressed = true
 get_viewport().push_input(key,true)
 key = key.duplicate()
 key.pressed = false
 get_viewport().push_input(key,true)
 var click = InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 click.position = game.world_to_screen(point)
 get_viewport().push_input(click,true)
 click = click.duplicate()
 click.pressed = false
 get_viewport().push_input(click,true)
func reset() -> void:
 p.stop_actions()
 p.global_position = Vector2(1300,270)
 p.atk_cd = 0
func creep_at(point: Vector2):
 var creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",point)
 GameState.minions.append(creep)
 return creep
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("garen")
 p = GameState.player
 for champion in GameState.champions:
  champion.is_bot = false
  champion.stop_actions()
  champion.global_position = Constants.FOUNT_B if champion.team == 0 else Constants.FOUNT_R
 for structure in GameState.structures: structure.is_targetable = false
 reset()
 game._update_camera(1)
 await get_tree().process_frame
 await get_tree().process_frame
 var close = creep_at(Vector2(1360,270))
 var cursor_creep = creep_at(Vector2(1480,270))
 order(Vector2(1480,320))
 check(p.attack_target == cursor_creep,"A-click on floor prioritizes cursor creep over enemy nearest the hero")
 check(p.attack_move and not GameState.attack_move_pending,"A-click confirms the order and closes its preview")
 var hp = cursor_creep.hp
 for frame in range(110): p.update_frame(0.01)
 check(cursor_creep.hp < hp,"melee hero approaches and hits the ground-selected creep")
 reset()
 close.global_position = Vector2(1360,270)
 cursor_creep.global_position = Vector2(1380,270)
 order(Vector2(1800,370))
 check(p.attack_target == close,"distant ground click falls back to enemy nearest the hero, not nearest distant cursor")
 reset()
 close.dead = true
 cursor_creep.dead = true
 order(Vector2(1500,350))
 check(p.attack_target == null and p.has_move_target,"empty floor starts attack-move movement")
 var old_position = p.world_pos()
 p.update_frame(0.1)
 check(p.world_pos().distance_to(old_position)>10,"empty-floor attack move actually moves")
 for frame in range(200): p.update_frame(0.01)
 check(p.world_pos().distance_to(Vector2(1500,350))<3.1,"empty-floor attack move reaches its destination")
 reset()
 cursor_creep.dead = false
 cursor_creep.global_position = Vector2(1640,270)
 order(Vector2(1800,370))
 check(p.attack_target == null,"ground click does not lock onto a distant off-cursor enemy")
 for frame in range(210): p.update_frame(0.01)
 check(p.attack_target == cursor_creep,"attack move acquires an enemy encountered along the route")
 cursor_creep.dead = true
 p.update_frame(0.01)
 check(p.attack_target == null and p.has_move_target and p.move_target.distance_to(Vector2(1800,370))<0.1,"attack move resumes original floor destination after target dies")
 reset()
 cursor_creep.dead = false
 cursor_creep.global_position = Vector2(1900,270)
 order(cursor_creep.world_pos())
 check(p.attack_target == cursor_creep,"explicit A-click on a unit remains a targeted chase")
 reset()
 cursor_creep.global_position = Vector2(1420,270)
 order(Vector2(1420,320))
 p.update_frame(0.01)
 var click = InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_RIGHT
 click.pressed = true
 click.position = game.world_to_screen(Vector2(1200,350))
 get_viewport().push_input(click,true)
 check(p.attack_target == null and not p.attack_move and p.has_move_target,"right-click floor cancels attack move")
 print("GROUND ATTACK MOVE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
