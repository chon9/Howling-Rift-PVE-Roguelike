extends Node
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(message)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 var cursor = game.get_node("MobaCursor")
 check(cursor.state_at(Vector2.ZERO)=="default","menu cursor")
 game._start_game("lux")
 for c in GameState.champions:
  c.is_bot = false
  c.stop_actions()
 var p = GameState.player
 p.global_position = Vector2(1650,270)
 var enemy = GameState.champions[3]
 enemy.global_position = Vector2(1800,270)
 var ally = GameState.champions[1]
 ally.global_position = Vector2(1510,270)
 check(cursor.state_at(Vector2(1650,430))=="default","ground cursor")
 check(cursor.state_at(enemy.world_pos())=="attack","enemy body uses attack cursor")
 check(cursor.state_at(ally.world_pos())=="ally","friendly body uses ally cursor")
 check(cursor.state_at(enemy.world_pos(),true)=="default","UI takes priority over units")
 GameState.attack_move_pending = true
 check(cursor.state_at(enemy.world_pos())=="attack_move","A uses centered attack reticle")
 GameState.attack_move_pending = false
 game.skill_aimer.set_aim(p,0)
 check(cursor.state_at(enemy.world_pos())=="aim","skill preview uses aim reticle")
 game.skill_aimer.clear_aim()
 check(not p.shield_bar.visible,"unshielded hero has no shield meter")
 p.bonus_armor = 0
 p.shield = 200
 p._sync_bars()
 var fx = p.get_node("StatusVisual")
 fx.refresh()
 check(p.shield_bar.visible and fx.shield_amount==200 and fx.visible,"shield enables meter and body barrier")
 check(is_equal_approx(p.shield_bar.size.x,Constants.CHAMP_BAR_WIDTH*200/p.hp_max),"shield meter shares max HP scale")
 var hp = p.hp
 game.deal_damage(enemy,p,50,"auto")
 p._sync_bars()
 fx.refresh()
 check(p.hp==hp and p.shield==150 and fx.shield_amount==150,"absorbed hit updates shield without reducing HP")
 check(is_equal_approx(fx.shield_pulse,0.18),"absorbed hit flashes barrier")
 check(p.shield_bar.position.y+p.shield_bar.size.y<p.hp_bar.position.y,"shield appears above HP")
 var packet = LanSnapshot.encode()
 check(packet.champs[0].shield==150,"LAN carries current shield")
 game._update_camera(1)
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/50-cursor-shield.png")
 p.shield = 0
 p._sync_bars()
 fx.refresh()
 check(not p.shield_bar.visible and not fx.visible,"depleted shield hides meter and barrier")
 p.shield = 200
 p.dead = true
 p._sync_bars()
 fx.refresh()
 check(not p.shield_bar.visible and not fx.visible,"dead hero hides shield")
 check(cursor.state_at(enemy.world_pos())=="blocked","dead cursor")
 p.dead = false
 GameState.paused = true
 check(cursor.state_at(enemy.world_pos())=="default","pause uses menu cursor")
 GameState.paused = false
 game._return_to_main_menu()
 await get_tree().process_frame
 check(game.get_node("MobaCursor").state=="default","return to menu replaces combat cursor")
 print("CURSOR SHIELD: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
