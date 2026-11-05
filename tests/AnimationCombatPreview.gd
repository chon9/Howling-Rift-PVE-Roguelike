extends Node
var game
var order_time = 0.0
func _ready() -> void:
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 game=load("res://scripts/Main.gd").new();add_child(game);game._start_game("ezreal")
 for i in range(GameState.champions.size()):
  var c=GameState.champions[i]
  c.global_position=Vector2(1460 if c.team==Constants.BLUE else 1790,250+(i%3)*35)
  c.animator.previous_position=c.world_pos()
 for i in range(3):
  for team in [Constants.BLUE,Constants.RED]:
   var m=game.MinionS.new();game.world_root.add_child(m)
   m.setup(team,"melee" if i<2 else "caster",Vector2(1550 if team==Constants.BLUE else 1720,245+i*25))
   GameState.minions.append(m)
 var folder="res://tests/combat-animation-frames"
 DirAccess.make_dir_recursive_absolute(folder)
 for frame in range(240):
  await get_tree().create_timer(.05).timeout
  var p=GameState.player
  if not p.dead and GameState.running and frame%14==0:
   var target=GameState.find_nearest_enemy(p,p.world_pos(),650)
   if target!=null:
    game._issue_player_order({"type":"amove","point":target.world_pos()})
    p.try_cast_skill(0,target.world_pos())
    if frame%28==0:p.try_cast_skill(1,target.world_pos())
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(folder+"/frame-%04d.png" % frame)
 print("NATIVE COMBAT PREVIEW: 240 frames; live ARAM AI, movement, projectiles and HUD")
 get_tree().quit()
