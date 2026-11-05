extends Node
var checks=0
var failures=0
var game
var hero
var enemy
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL DEADEYE: "+message)
func cast() -> void:
 hero.buffs.clear();hero.stun=0;hero.stop_actions();hero.skill_cds[3]=0.;hero.mp=hero.mp_max
 enemy.dead=false;enemy.is_targetable=true;enemy.hp=enemy.hp_max
 check(hero.try_cast_skill(3,enemy.world_pos()),"Deadeye casts on living hero")
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("caitlyn")
 hero=GameState.player;enemy=GameState.champions[3]
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Vector2(2500,270)
 hero.global_position=Vector2(1250,270);enemy.global_position=Vector2(1600,270)
 hero.level=6;hero.skill_ranks=[1,1,1,1];enemy.hp_max=50000.;enemy.hp=50000.
 game.camera.global_position=hero.world_pos()
 cast()
 var cue=DeadeyeCue.channel(hero)
 check(cue.time==1. and cue.progress==0. and cue.target==enemy,"lock starts with full authoritative one-second countdown")
 check(DeadeyeCue.locks_on(enemy).size()==1 and DeadeyeCue.locks_on(GameState.champions[4]).is_empty(),"only marked target receives lock")
 check(hero.animator.pose().action=="r" and hero.animator.pose().frame==0,"charge holds correct ultimate sprite row")
 check(int(game.sound_fx.counts.get("gun_ultimate",0))==0,"no firing sound at cast start")
 game.sound_fx._update_charges();game.sound_fx._update_charges()
 check(int(game.sound_fx.counts.get("deadeye_charge",0))==1,"charge sound starts once per cast")
 var serial=cue.serial
 hero.update_frame(.4)
 cue=DeadeyeCue.channel(hero)
 check(is_equal_approx(cue.time,.6) and is_equal_approx(cue.progress,.4),"timer tracks actual wind-up")
 check(enemy.hp==enemy.hp_max and GameState.projectiles.is_empty(),"charging deals no early damage or shot")
 var packet=LanSnapshot.encode()
 hero.buffs.clear();LanSnapshot.apply(packet,LanSession)
 check(DeadeyeCue.channel(hero).serial==serial and is_equal_approx(DeadeyeCue.channel(hero).time,.6),"snapshot restores same serial, target and remaining time")
 check(DeadeyeCue.locks_on(enemy).size()==1,"snapshot target reference resolves to proper hero")
 if DisplayServer.get_name()!="headless":
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/deadeye-charge.png")
 hero.update_frame(.59)
 check(not DeadeyeCue.channel(hero).is_empty() and GameState.projectiles.is_empty(),"no early release near end of charge")
 hero.update_frame(.02)
 check(DeadeyeCue.channel(hero).is_empty() and DeadeyeCue.locks_on(enemy).is_empty(),"countdown and lock disappear on release")
 check(GameState.projectiles.size()==1 and GameState.projectiles[0].effect_id=="caitlyn_r","charge fires one correct Deadeye missile")
 check(hero.animator.pose().frame>=4 and hero.animator.pose().action=="r","release uses firing frames instead of restarting charge")
 check(int(game.sound_fx.counts.get("gun_ultimate",0))==1,"rifle ultimate sound plays at release")
 game.sound_fx._update_charges()
 check(game.sound_fx.charge_voices.is_empty(),"charge sound stops on release")
 var shot=GameState.projectiles[0]
 check(shot.interceptable and shot.homing==enemy,"shot retains interception and homing")
 check(shot.readable_trail(),"ultimate has compact high contrast trail")
 for frame in range(60):
  if is_instance_valid(shot) and not shot.is_queued_for_deletion():shot.update_frame(.01)
 check(enemy.hp<enemy.hp_max,"released bullet damages its marked target")
 for mode in ["move","stun","displace","target_dead","target_untargetable"]:
  for projectile in GameState.projectiles.duplicate():projectile._destroy()
  cast();game.sound_fx._update_charges()
  if mode=="move":hero.has_move_target=true
  elif mode=="stun":hero.stun=.5
  elif mode=="displace":hero.global_position+=Vector2(20,0)
  elif mode=="target_dead":enemy.dead=true
  else:enemy.is_targetable=false
  hero.update_frame(.05);game.sound_fx._update_charges()
  check(DeadeyeCue.channel(hero).is_empty() and GameState.projectiles.is_empty(),mode+" cancels lock without shooting")
  check(game.sound_fx.charge_voices.is_empty(),mode+" stops charge audio")
 enemy.dead=false;enemy.is_targetable=true
 var area=game.AoES.new();game.world_root.add_child(area)
 area.setup(hero,Vector2(1450,270),{"effect_id":"brand_w","radius":90.,"dmg":100.,"arm_delay":.6,"duration":1.})
 GameState.aoes.append(area)
 check(area.readable_boundary and area.radius==90.,"damaging delayed zone gains exact-size readable boundary")
 packet=LanSnapshot.encode()
 check(packet.aoes[0].readable_boundary,"ground warning presentation replicated")
 area.setup(hero,hero.world_pos(),{"effect_id":"sivir_r","radius":90.,"dmg":0.})
 check(not area.readable_boundary,"utility visuals do not pretend to be damage circles")
 area.setup(hero,hero.world_pos(),{"effect_id":"thresh_e","radius":220.,"dmg":100.})
 check(not area.readable_boundary,"rectangular Flay is not mislabeled with a circular hitbox")
 check(game.sound_fx.clips.deadeye_charge.get_length()>=.99,"original charge clip covers wind-up")
 hero.buffs.clear();game._return_to_main_menu()
 print("DEADEYE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
