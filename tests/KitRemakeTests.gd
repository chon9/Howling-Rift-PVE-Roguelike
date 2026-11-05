extends Node
var game
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL KIT REMAKE: "+message)
func clear_effects() -> void:
 for node in GameState.aoes+GameState.projectiles:node.queue_free()
 GameState.aoes.clear();GameState.projectiles.clear()
func arrange(hero: String):
 if GameState.running:
  game._return_to_main_menu()
  await get_tree().process_frame
 game._start_game(hero);game.set_process(false)
 for c in GameState.champions:
  c.is_bot=false;c.stop_actions();c.buffs.clear();c.global_position=Vector2(2000,270)
 var p=GameState.player
 p.global_position=Vector2(1300,270);p.skill_ranks=[5,5,5,3];p.mp=10000.;p.skill_cds=[0.,0.,0.,0.]
 var enemy=GameState.champions[3]
 enemy.global_position=Vector2(1400,270);enemy.hp_max=100000.;enemy.hp=100000.;enemy.shield=0
 return p
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 game.camera.position=Vector2(1350,270);game.camera.reset_smoothing()
 for node in GameState.aoes+GameState.projectiles:node.queue_redraw()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/kit-remake-"+name+"-v033.png")
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 for hero in ExpansionRoster.KEYS:
  for key in ["q","w","e","r"]:
   var id=hero+"_"+key
   check(KitEffectArt.has_effect(id),"dedicated effect "+id)
   var tex=KitEffectArt.sheet(id)
   for frame in range(4):
    var region=KitEffectArt.region(id,frame)
    check(region.has_area() and Rect2(Vector2.ZERO,tex.get_size()).encloses(region),"valid atlas frame "+id+str(frame))
 var p=await arrange("thresh");var enemy=GameState.champions[3]
 ExpansionKits.cast(p,"thresh_e",p.world_pos()+Vector2.RIGHT*200)
 check(enemy.hp<100000. and enemy.buffs.has("forced_motion"),"Flay damages and starts displacement")
 check(enemy.world_pos().x==1400,"Flay displacement animates rather than teleports")
 ForcedMotion.tick(enemy,.25)
 check(enemy.world_pos().x>1400,"forward aim pushes enemy")
 clear_effects();enemy.global_position=Vector2(1400,270);enemy.buffs.clear()
 ExpansionKits.cast(p,"thresh_e",p.world_pos()-Vector2.RIGHT*200)
 ForcedMotion.tick(enemy,.25)
 check(enemy.world_pos().x<1400,"backward aim pulls enemy on opposite side")
 clear_effects();enemy.global_position=Vector2(1400,390);enemy.buffs.clear();var hp=enemy.hp
 ExpansionKits.cast(p,"thresh_e",p.world_pos()+Vector2.RIGHT*200)
 check(enemy.hp==hp and not enemy.buffs.has("forced_motion"),"Flay uses rectangular sweep width")
 clear_effects();enemy.global_position=Vector2(1400,270);enemy.buffs.cc_guard={"time":2.}
 ExpansionKits.cast(p,"thresh_e",p.world_pos()+Vector2.RIGHT*200)
 check(not enemy.buffs.has("forced_motion"),"CC shield blocks Flay movement")
 clear_effects();enemy.buffs.clear();enemy.global_position=p.world_pos()
 ExpansionKits.cast(p,"thresh_r",p.world_pos());var box=GameState.aoes.back();hp=enemy.hp
 box.update_frame(.6)
 check(enemy.hp==hp and not enemy.buffs.has("slow"),"prison center has no damage or slow")
 var wall0=(Vector2.from_angle(-PI/2)+Vector2.from_angle(-PI/2+TAU/5))*90
 enemy.global_position=p.world_pos()+wall0;box.update_frame(.02)
 check(enemy.hp<hp and box.broken_walls[0],"first prison wall damages and breaks")
 check(enemy.buffs.slow.pct==.99 and enemy.buffs.slow.time==2.,"first wall has 99 percent two-second slow")
 hp=enemy.hp
 enemy.global_position=p.world_pos()+(Vector2.from_angle(-PI/2+TAU/5)+Vector2.from_angle(-PI/2+2*TAU/5))*90
 box.update_frame(.02)
 check(enemy.hp==hp and box.broken_walls[1] and enemy.buffs.slow.time==1.,"later wall only slows for one second")
 await capture("prison")
 clear_effects();enemy.buffs.clear();enemy.global_position=Vector2(1410,270)
 ExpansionKits.cast(p,"thresh_q",enemy.world_pos());var hook=GameState.projectiles.back();hook.update_frame(.14)
 var info=NewHeroKits.recast_info(p,0)
 check(not info.is_empty() and info.duration==1.5,"hook shows timed second cast")
 check(NewHeroKits.recast(p,0,enemy.world_pos()) and p.is_dashing and not enemy.buffs.has("chain_mark"),"hook second cast dashes and consumes mark")
 clear_effects();p.stop_actions();var ally=GameState.champions[1];ally.global_position=Vector2(1420,270)
 ExpansionKits.cast(p,"thresh_w",ally.world_pos());var lantern=GameState.aoes.back();lantern.update_frame(.02)
 check(ally.shield>0,"lantern shields nearby allies")
 game._issue_champion_order(ally,{"type":"smart","point":lantern.global_position})
 check(ally.is_dashing and ally.dash_target==p.world_pos(),"right-click lantern dashes ally to caster")
 p=await arrange("veigar");enemy=GameState.champions[3]
 var center=enemy.world_pos();hp=enemy.hp
 ExpansionKits.cast(p,"veigar_w",center);var meteor=GameState.aoes.back()
 meteor.update_frame(.8);check(enemy.hp==hp,"meteor warning does not damage before delay")
 await capture("meteor-warning")
 enemy.global_position=center+Vector2(220,0);meteor.update_frame(.25)
 check(enemy.hp==hp,"moving out dodges meteor")
 clear_effects();enemy.global_position=center
 ExpansionKits.cast(p,"veigar_w",center);meteor=GameState.aoes.back();meteor.update_frame(1.01)
 check(enemy.hp<hp,"meteor deals damage after delay")
 await capture("meteor-impact")
 clear_effects();enemy.buffs.clear();enemy.global_position=center
 ExpansionKits.cast(p,"veigar_e",center);var cage=GameState.aoes.back();hp=enemy.hp
 cage.update_frame(.3);check(enemy.stun==0,"cage has activation delay")
 cage.update_frame(.3);check(enemy.stun==0 and enemy.hp==hp,"cage interior neither damages nor stuns")
 enemy.global_position=center+Vector2(150,0);enemy.is_dashing=true;cage.update_frame(.02)
 check(enemy.stun>0 and not enemy.is_dashing,"cage rim stuns and stops dash")
 await capture("cage")
 clear_effects();enemy.hp=enemy.hp_max;ExpansionKits.cast(p,"veigar_r",enemy.world_pos());var full_damage=GameState.projectiles.back().dmg
 clear_effects();enemy.hp=enemy.hp_max/3.;ExpansionKits.cast(p,"veigar_r",enemy.world_pos())
 check(is_equal_approx(GameState.projectiles.back().dmg,full_damage*2.),"execute reaches double damage at one-third HP")
 var packet=LanSnapshot.encode()
 check(packet.projectiles.back().effect_id=="veigar_r","co-op packet includes projectile atlas ID")
 clear_effects();ExpansionKits.cast(p,"veigar_e",center);packet=LanSnapshot.encode()
 check(packet.aoes.back().zone_kind=="cage" and packet.aoes.back().arm_delay==.5 and packet.aoes.back().effect_id=="veigar_e","co-op packet includes zone visuals and arming")
 var registry={};LanSession.main=game
 LanSnapshot.reconcile(packet.aoes,registry,LanSession,"aoe")
 var replica=registry.values()[0]
 check(replica.effect_id=="veigar_e" and replica.team==p.team and replica.arm_delay==.5,"guest reconstruction preserves spell art and team")
 LanSnapshot.reconcile([],registry,LanSession,"aoe")
 for hero in ExpansionRoster.KEYS:
  p=await arrange(hero);enemy=GameState.champions[3]
  for key in ["q","w","e","r"]:
   clear_effects();p.buffs.clear();p.is_dashing=false
   var id=hero+"_"+key
   if id=="vayne_w":
    check(not ExpansionKits.cast(p,id,enemy.world_pos()),"passive W not castable");ExpansionKits.tick(p,0.);check(p.buffs.has("silver"),"learned W stays active");continue
   check(ExpansionKits.cast(p,id,enemy.world_pos()),"real kit dispatch "+id)
   check((GameState.aoes+GameState.projectiles).any(func(n):return n.effect_id==id),"real cast selects dedicated sprite row "+id)
 print("KIT REMAKE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
