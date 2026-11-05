extends Node
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._start_game("yasuo")
 for c in GameState.champions:c.visible=false;c.is_bot=false;c.stop_actions()
 var heroes=["yasuo","leesin","garen","katarina","lux","ezreal"]
 for i in range(heroes.size()):
  var c=game.ChampionS.new();game.world_root.add_child(c)
  c.setup(Constants.BLUE,heroes[i],true,heroes[i].capitalize())
  c.global_position=Vector2(1280+i*125,230)
  for row in range(2):
   var m=game.MinionS.new();game.world_root.add_child(m)
   m.setup(Constants.BLUE,"melee" if row==0 else "caster",Vector2(1280+i*125,335+row*80))
   GameState.minions.append(m)
 var p=GameState.player;p.global_position=Vector2(1550,270)
 game.camera.position=Vector2(1570,290);game.camera.zoom=Vector2(1.6,1.6)
 game.hud.get_node("HudRoot").refresh(0)
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/hero-minion-scale.png")
 print("SCALE VISUAL: heroes 56px / melee 43.2px / caster 40.5px at identical zoom")
 get_tree().quit()
