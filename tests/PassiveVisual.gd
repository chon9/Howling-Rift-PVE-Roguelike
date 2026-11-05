extends Node
func capture(path: String) -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 Progression.persistent=false;GameState.reset()
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._show_menu()
 await capture("res://tests/v051-portraits-old.png")
 game.menu.find_children("*","ScrollContainer",true,false)[0].scroll_vertical=10000
 await capture("res://tests/v051-portraits-new.png")
 game._start_game("xinzhao")
 var p=GameState.player;var enemy=GameState.champions[3]
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 p.global_position=Vector2(1330,270);enemy.global_position=Vector2(1430,270);enemy.hp_max=10000.;enemy.hp=10000.
 p.skill_ranks=[1,1,1,1];p.try_cast_skill(0,p.world_pos());p._perform_auto(enemy);p._perform_auto(enemy);p._perform_auto(enemy)
 enemy.buffs.airborne.time=.5;enemy.stun=.5;enemy.queue_redraw();game.camera.position=Vector2(1410,270)
 game.hud.get_node("HudRoot").refresh(0.);game.hud.get_node("HudRoot").show_passive_description()
 await capture("res://tests/v051-lancer-airborne.png")
 game.hud.get_node("HudRoot").hide_skill_description();p.skill_cds[2]=0.;enemy.global_position=p.world_pos()+Vector2(300,0);p.try_cast_skill(2,enemy.world_pos())
 for i in range(5):p.update_frame(.02)
 game.camera.position=Vector2(1510,270)
 await capture("res://tests/v051-lancer-charge.png")
 print("PASSIVE VISUAL: portraits, airborne, charge captured")
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit()
