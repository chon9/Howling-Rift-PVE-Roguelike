extends Node
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.difficulty=1
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._show_menu();game._start_game("malphite")
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_R
 var player=GameState.player;player.global_position=Vector2(1350,270)
 for i in range(ExpansionRoster.KEYS.size()):
  var c=game.ChampionS.new();game.world_root.add_child(c);c.setup(i%2,ExpansionRoster.KEYS[i],false,ChampionData.CHAMPIONS[ExpansionRoster.KEYS[i]].name)
  c.global_position=Vector2(1050+i*130,240 if i%2==0 else 330);GameState.champions.append(c)
  var p=game.ProjectileS.new();game.world_root.add_child(p);p.setup(c,c.world_pos()+Vector2(55,0),Vector2.RIGHT,{"damage_type":"magic","size":12})
  p.animation_time=.2;GameState.projectiles.append(p)
 for i in range(6):
  var m=game.MinionS.new();game.world_root.add_child(m);m.setup(i%2,"melee" if i<3 else "caster",Vector2(1230+i*65,190 if i%2==0 else 390));GameState.minions.append(m)
 GameState.cam_target=player.world_pos();game._update_camera(0);game.hud.get_node("HudRoot").refresh(0)
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/balance-v022-battlefield.png")
 game._return_to_main_menu();game.queue_free();await get_tree().process_frame
 print("BALANCE VISUAL: larger battlefield and new projectile rows captured")
 get_tree().quit()
