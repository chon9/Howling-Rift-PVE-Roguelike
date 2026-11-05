extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL HOOK REPLICATION: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("thresh")
 var hero=GameState.player
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 hero.global_position=Vector2(1320,270)
 check(ExpansionKits.cast(hero,"thresh_q",Vector2(1700,270)),"actual hook cast creates a chain skillshot")
 var hook=GameState.projectiles.back();hook.global_position=Vector2(1640,270);hook.animation_time=.2
 var packet=LanSnapshot.encode().projectiles
 check(packet.back().source=={"kind":"champion","id":0},"snapshot includes stable hero reference instead of an Object")
 check(packet.back().damage_type==hook.damage_type and packet.back().team==hero.team,"guest receives matching skill glow and team")
 var registry={}
 LanSnapshot.reconcile(packet,registry,LanSession,"projectile")
 var replica=registry[hook.get_instance_id()]
 check(replica.src==hero and replica.hook_chain,"guest resolves the live hook owner")
 check(replica.effect_id=="thresh_q" and KitEffectArt.sheet(replica.effect_id)==KitEffectArt.sheet(hook.effect_id),"single-player and guest use the same modern hook sheet")
 check(replica.texture_filter==hook.texture_filter,"guest sprite filtering matches host")
 check(replica.hook_world_segment()==hook.hook_world_segment(),"guest renders the same chain endpoints")
 hero.global_position+=Vector2(30,25)
 check(replica.hook_world_segment()==hook.hook_world_segment() and replica.hook_world_segment()[0].is_equal_approx(hero.world_pos()-Vector2(0,hook.visual_height)),"chain follows moving caster without waiting for another projectile snapshot")
 for angle in [0.,PI/2,PI,-PI/2]:
  hook.rotation=angle;replica.rotation=angle
  check(replica.hook_world_segment()==hook.hook_world_segment(),"chain anchor remains screen-up in every travel direction")
 var bad=packet.duplicate(true);bad[0].source={"kind":"champion","id":99}
 LanSnapshot.reconcile(bad,registry,LanSession,"projectile")
 check(replica.src==null and replica.hook_world_segment().is_empty(),"invalid owner safely omits line")
 LanSnapshot.reconcile(packet,registry,LanSession,"projectile")
 check(replica.src==hero,"next valid snapshot restores chain")
 hook.hide();replica.queue_redraw();game.camera.position=Vector2(1500,270)
 await get_tree().process_frame;await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/thresh-guest-chain-v045.png")
 LanSnapshot.reconcile([],registry,LanSession,"projectile")
 check(registry.is_empty() and not LanSession.positions.has(replica),"expired guest hook cleans up its position history")
 print("HOOK REPLICATION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
