extends Node
var checks = 0
var failures = 0
var game
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL CAST MODE: "+message)
func key(code: int) -> void:
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 get_viewport().push_input(event,true)
func mouse(point: Vector2, button: int=0) -> void:
 var screen=game.world_to_screen(point)
 var motion=InputEventMouseMotion.new();motion.position=screen;get_viewport().push_input(motion,true)
 if button:
  var event=InputEventMouseButton.new();event.button_index=button;event.position=screen;event.pressed=true
  get_viewport().push_input(event,true);event=event.duplicate();event.pressed=false;get_viewport().push_input(event,true)
func click(control: Control) -> void:
 await get_tree().process_frame
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_rect().get_center();event.pressed=true
 get_viewport().push_input(event,true);event=event.duplicate();event.pressed=false;get_viewport().push_input(event,true)
 await get_tree().process_frame
func arm(p, idx: int=0) -> void:
 p.skill_cds[idx]=0.;p.mp=p.mp_max
 key([KEY_Q,KEY_W,KEY_E,KEY_R][idx])
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.smart_cast=true
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._show_start_upgrades()
 await get_tree().process_frame
 var toggle=game.menu.find_child("SmartCast",true,false)
 check(toggle!=null and toggle.button_pressed,"settings default to existing smart cast")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/normal-cast-options.png")
 await click(toggle)
 check(not Progression.smart_cast,"real settings click enables normal casting")
 var original_path=Progression.save_path
 Progression.save_path="res://tests/cast-options-temp.cfg";Progression.persistent=true
 check(Progression.save_profile(),"control preference can save with profile")
 Progression.smart_cast=true;Progression.load_profile()
 check(not Progression.smart_cast,"normal cast survives reload")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.save_path))
 Progression.save_path=original_path;Progression.persistent=false
 game._show_menu();game._start_game("lux")
 await get_tree().process_frame
 for c in GameState.champions:c.is_bot=false;c.stop_actions()
 var p=GameState.player;p.global_position=Vector2(1300,270);game._update_camera(0)
 var target=GameState.champions[3];target.global_position=Vector2(1500,270)
 mouse(target.world_pos());var mana=p.mp;var count=GameState.projectiles.size()
 key(KEY_Q)
 check(game.pending_skill==0 and game.skill_aimer.aiming_idx==0,"Q enters targeting with indicator")
 check(p.mp==mana and p.skill_cds[0]==0 and GameState.projectiles.size()==count,"aiming costs no mana or cooldown")
 game.set_aiming_skill(2);game.clear_aiming_skill()
 check(game.skill_aimer.aiming_idx==0,"HUD hover cannot overwrite or erase active aim")
 mouse(target.world_pos(),MOUSE_BUTTON_LEFT)
 check(game.pending_skill==-1 and game.skill_aimer.aiming_idx==-1,"left click clears targeting")
 check(p.mp==mana-p.hero.skills[0].cost and p.skill_cds[0]>0 and GameState.projectiles.size()==count+1,"left click actually casts once")
 check(GameState.projectiles.back().dir.dot(Vector2.RIGHT)>.99,"cast uses confirmed click direction")
 arm(p);mouse(Vector2(1450,310),MOUSE_BUTTON_RIGHT)
 check(game.pending_skill==-1 and not p.has_move_target and p.mp==p.mp_max,"right click cancels without accidental movement or mana spend")
 arm(p);key(KEY_ESCAPE)
 check(game.pending_skill==-1 and not GameState.paused and not game.in_game_menu.has_node("MatchPanel"),"first Esc cancels aim without opening pause")
 key(KEY_ESCAPE)
 check(GameState.paused and game.in_game_menu.has_node("MatchPanel"),"next Esc opens normal pause menu")
 game._show_pause_upgrades();await get_tree().process_frame
 toggle=game.in_game_menu.find_child("SmartCast",true,false)
 check(toggle!=null and not toggle.button_pressed,"same casting option available during match")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/normal-cast-pause-options.png")
 await click(toggle)
 check(Progression.smart_cast,"pause settings can restore quick casting")
 key(KEY_ESCAPE);key(KEY_ESCAPE)
 mouse(target.world_pos());p.skill_cds[0]=0.;p.mp=p.mp_max;count=GameState.projectiles.size()
 key(KEY_Q)
 check(game.pending_skill==-1 and GameState.projectiles.size()==count+1,"smart cast still fires immediately")
 Progression.smart_cast=false
 arm(p,1)
 check(game.pending_skill==-1 and p.skill_cds[1]>0,"self shield remains instant without aiming")
 arm(p,2);check(game.pending_skill==2,"E starts area targeting")
 p.skill_cds[0]=0.
 key(KEY_Q);check(game.pending_skill==0 and game.skill_aimer.aiming_idx==0,"ready ability key switches targeting")
 key(KEY_A)
 check(game.pending_skill==-1 and game.attack_move_pending,"attack move replaces spell targeting")
 game.attack_move_pending=false
 arm(p);key(KEY_P)
 check(game.pending_skill==-1 and game.hud.get_node("HudRoot").shop_open,"opening shop cancels aim")
 key(KEY_ESCAPE)
 p.skill_cds[0]=0.;p.mp=p.mp_max
 game.hud.get_node("HudRoot").skill_slots[0].clicked.emit()
 check(game.pending_skill==0,"HUD skill click obeys normal-cast preference")
 p.dead=true;game._process(0)
 check(game.pending_skill==-1,"death clears pending aim")
 p.dead=false
 arm(p);game._return_to_main_menu();await get_tree().process_frame
 check(game.pending_skill==-1 and not Progression.smart_cast,"menu return clears aim and retains preference")
 game._show_menu();game._start_game("leesin");await get_tree().process_frame
 p=GameState.player;target=GameState.champions[3]
 p.global_position=Vector2(1300,270);target.global_position=Vector2(1450,270)
 p.is_bot=false;target.buffs.sonic_mark={"time":4.,"src":p};p.sonic_target=target;p.skill_cds[0]=5.
 key(KEY_Q)
 check(game.pending_skill==-1 and p.is_dashing,"Lee Q2 recasts instantly without retargeting")
 Progression.smart_cast=true
 game._return_to_main_menu();game.queue_free();await get_tree().process_frame
 print("CAST MODE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
