extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL VESPER: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("vayne")
 var player=GameState.player;var enemy=GameState.champions[3]
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 player.global_position=Vector2(1400,270);enemy.global_position=Vector2(1640,270);enemy.buffs.clear()
 player._perform_auto(enemy)
 check(GameState.projectiles.size()==1,"real Vesper attack creates a bolt")
 var bolt=GameState.projectiles.back()
 check(bolt.effect_id=="vayne_auto" and bolt.is_vesper_bolt(),"attack selects dedicated bright presentation")
 check(bolt.size==7 and bolt.speed==700 and is_equal_approx(bolt.dmg,player.ad),"visual change preserves attack hitbox, speed and damage")
 check(bolt.visual_dimensions==Vector2(28,9),"silver bolt is readable without oversized thickness")
 for angle in [0.,PI/2,PI,-PI/2]:
  bolt.rotation=angle
  check(bolt.visual_origin().rotated(angle).is_equal_approx(Vector2(0,-bolt.visual_height)),"flight altitude is stable in every direction")
 bolt.rotation=0
 var hp=enemy.hp
 for i in range(25):if is_instance_valid(bolt):bolt.update_frame(.02)
 check(enemy.hp<hp,"basic attack still lands normally")
 check(ExpansionKits.cast(player,"vayne_e",enemy.world_pos()),"Condemn casts normally")
 var condemn=GameState.projectiles.back()
 check(condemn.is_vesper_bolt() and condemn.visual_dimensions==Vector2(34,12) and condemn.knockback_distance==170.,"Condemn is visibly distinct and keeps knockback")
 var packet=LanSnapshot.encode().projectiles.back()
 var replica=game.ProjectileS.new();game.world_root.add_child(replica)
 for field in packet:
  if field not in ["id","position","source"]:replica.set(field,packet[field])
 check(replica.src==null and replica.is_vesper_bolt() and replica.visual_dimensions==condemn.visual_dimensions,"source-free co-op replica has identical bolt presentation")
 replica.queue_free()
 for p in GameState.projectiles.duplicate():p._destroy()
 # Freeze an actual in-game view with each visible bolt at normal camera scale.
 for data in [["vayne_auto",Vector2(1510,235)],["vayne_e",Vector2(1540,310)]]:
  game.spawn_projectile(player,data[1],Vector2.RIGHT,{"effect_id":data[0],"damage_type":"auto" if data[0]=="vayne_auto" else "physical","size":7,"speed":700})
  GameState.projectiles.back().queue_redraw()
 game.camera.position=Vector2(1500,270)
 await get_tree().process_frame;await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/vesper-projectiles-v043.png")
 print("VESPER PROJECTILES: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
