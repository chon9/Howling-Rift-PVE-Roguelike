extends Node
var checks=0
var failures=0
var game
var hero
var enemy
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL ROSTER12: "+message)
func cleanup_effects() -> void:
 for p in GameState.projectiles.duplicate():if is_instance_valid(p):p._destroy()
 for a in GameState.aoes.duplicate():if is_instance_valid(a):GameState.aoes.erase(a);a.queue_free()
func reset_fight() -> void:
 cleanup_effects();hero.buffs.clear();hero.item_cds.clear();hero.stop_actions();hero.is_dashing=false;hero.stun=0.;hero.global_position=Vector2(1320,270);hero.hp_max=5000.;hero.hp=3500.;hero.shield=0.;hero.mp_max=1000.;hero.mp=1000.;hero.skill_cds=[0.,0.,0.,0.]
 enemy.buffs.clear();enemy.stun=0.;enemy.dead=false;enemy.is_targetable=true;enemy.hp_max=10000.;enemy.hp=10000.;enemy.shield=0.;enemy.bonus_armor=0.;enemy.bonus_mr=0.;enemy.base_mr=0.;enemy.hp_regen=0.;enemy.global_position=Vector2(1440,270)
func simulate(seconds: float) -> void:
 for step in range(int(ceil(seconds/.02))):
  GameState.time+=.02
  hero.update_frame(.02);enemy.update_frame(.02)
  for p in GameState.projectiles.duplicate():if is_instance_valid(p) and not p.is_queued_for_deletion():p.update_frame(.02)
  for a in GameState.aoes.duplicate():if is_instance_valid(a) and not a.is_queued_for_deletion():a.update_frame(.02)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("leona")
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 enemy=GameState.champions[3];enemy.inventory=[];enemy._apply_items()
 check(ChampionData.CHAMPIONS.size()==32,"thirty-two selectable heroes")
 for key in RosterExpansion12.KEYS:
  var old=GameState.champions[0];hero=game.ChampionS.new();game.world_root.add_child(hero);hero.setup(0,key,false,"Test");GameState.champions[0]=hero;GameState.player=hero;old.queue_free();hero.inventory=[];hero._apply_items();hero.skill_ranks=[1,1,1,1]
  check(hero.hero.skills.size()==4,key+" four complete metadata records")
  for id in ItemData.BUILD_ORDERS[key]:check(ItemData.ITEMS.has(id),key+" valid recommended item "+id)
  check(game.lane_augments.role_for(hero)==RosterExpansion12.role(key),key+" correct augment role")
  for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
   for frame in range(6):
    var region=ActionSpriteArt.region("hero_"+key,action,frame);var tex=ActionSpriteArt.texture_for_frame("hero_"+key,action,frame)
    check(tex!=null and Rect2(Vector2.ZERO,tex.get_size()).encloses(region) and region.size.x>0 and region.size.y>0,key+" mapped "+action+str(frame))
  for index in range(4):
   var id=key+"_"+["q","w","e","r"][index]
   check(AbilityArt.icon_for(key,index)!=null,key+" icon "+str(index))
   for frame in range(4):check(Rect2(Vector2.ZERO,KitEffectArt.sheet(id).get_size()).encloses(KitEffectArt.region(id,frame)),id+" FX frame bounds")
   reset_fight()
   if key=="syndra" and index==1:Roster12Kits.visual(hero,enemy.world_pos(),"syndra_q",38,6.,{"zone_kind":"sphere"})
   check(hero.try_cast_skill(index,enemy.world_pos()),id+" valid cast succeeds")
   check(hero.skill_cds[index]>0,id+" first cast starts cooldown")
   check(is_equal_approx(hero.mp,1000.-hero.hero.skills[index].cost),id+" exact resource cost")
   check(not ChampionData.skill_description(key,index,hero).is_empty(),id+" scaling tooltip available")
   if not Roster12Kits.recast_info(hero,index).is_empty():
    if key=="xerath" and index==0:simulate(.8)
    check(hero.try_cast_skill(index,enemy.world_pos()),id+" recast succeeds during cooldown")
   simulate(1.3)
  mechanics(key)
  cleanup_effects()
 print("ROSTER12: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 get_tree().quit(0 if failures==0 else 1)
func mechanics(key: String) -> void:
 reset_fight()
 match key:
  "leona":
   hero.try_cast_skill(0,hero.world_pos());hero._perform_auto(enemy);check(enemy.stun>=1. and enemy.hp<10000.,"Aegis Q landing stuns and damages")
   hero.try_cast_skill(1,hero.world_pos());simulate(3.1);check(enemy.hp<9900. and hero.buffs.has("courage"),"Aegis eclipse explodes and extends defense")
  "blitzcrank":
   hero.try_cast_skill(0,enemy.world_pos());simulate(.4);check(enemy.world_pos().distance_to(hero.world_pos())<70.,"Bolt hook pulls target to caster")
   reset_fight();hero.try_cast_skill(1,hero.world_pos());simulate(4.05);check(hero.buffs.has("slow"),"Bolt overdrive has exhaustion slow")
   reset_fight();enemy.shield=300.;hero.try_cast_skill(3,hero.world_pos());simulate(.05);check(enemy.shield==0. and enemy.buffs.has("silence"),"Bolt ultimate strips shields and silences")
  "renekton":
   Roster12Combat.fury(hero,60.);enemy.shield=500.;hero.try_cast_skill(1,hero.world_pos());hero._perform_auto(enemy);check(enemy.shield==0. and enemy.stun>=1.5 and hero.buffs.fury.value==15.,"Saur empowered attack consumes fifty fury and breaks shield")
   reset_fight();hero.try_cast_skill(2,enemy.world_pos());check(not Roster12Kits.recast_info(hero,2).is_empty(),"Saur hit unlocks second dash")
   var hp=hero.hp_max;hero.try_cast_skill(3,hero.world_pos());simulate(8.1);check(is_equal_approx(hero.hp_max,hp),"Saur temporary ultimate health expires")
  "xinzhao":
   hero.try_cast_skill(0,hero.world_pos());hero._perform_auto(enemy);hero._perform_auto(enemy);check(enemy.stun==0.,"Lancer first two thrusts do not knock up");hero._perform_auto(enemy);check(enemy.stun>=1.,"Lancer third thrust knocks up")
   hero.buffs.crescent_guard={"time":3.};enemy.global_position=Vector2(1800,270);var before=hero.hp;game.deal_damage(enemy,hero,100,"physical");check(hero.hp==before,"Lancer guard blocks distant damage")
  "riven":
   hero.try_cast_skill(0,enemy.world_pos());hero.try_cast_skill(0,enemy.world_pos());hero.try_cast_skill(0,enemy.world_pos());simulate(.04);check(enemy.stun>0. and Roster12Kits.recast_info(hero,0).is_empty(),"Riftblade third Q knocks up and ends recast")
   reset_fight();hero.try_cast_skill(2,enemy.world_pos());check(hero.shield>0.,"Riftblade valor shields");simulate(2.1);check(hero.shield==0.,"Riftblade shield expires")
  "fiora":
   hero.try_cast_skill(1,enemy.world_pos());var before=hero.hp;game.deal_damage(enemy,hero,500,"physical");check(hero.hp==before,"Duelia parry blocks damage");Roster12Kits.control(hero,1.);simulate(1.2);check(enemy.stun>0.,"Duelia successful parry retaliates with stun")
   reset_fight();hero.try_cast_skill(3,enemy.world_pos())
   for side in range(4):Roster12Combat.vital(hero,enemy,enemy.world_pos()+Vector2.from_angle(side*PI/2)*100)
   check(GameState.aoes.any(func(a):return a.zone_kind=="heal_field"),"Duelia four directional vitals create healing field")
  "caitlyn":
   hero.try_cast_skill(1,enemy.world_pos());simulate(.7);check(enemy.stun>0. and enemy.buffs.has("rifle_mark"),"Caliber armed trap roots and marks")
   reset_fight();hero.try_cast_skill(3,enemy.world_pos());hero.has_move_target=true;simulate(1.2);check(enemy.hp==10000.,"Caliber movement cancels deadeye")
   reset_fight();hero.try_cast_skill(3,enemy.world_pos());simulate(1.3);check(enemy.hp<10000.,"Caliber completed aim fires bullet")
  "lucian":
   hero.try_cast_skill(0,enemy.world_pos());check(hero.buffs.has("lightslinger"),"Solstice spell primes second shot");hero._perform_auto(enemy);simulate(.3);check(not hero.buffs.has("lightslinger"),"Solstice impact consumes second shot")
   reset_fight();hero.try_cast_skill(3,enemy.world_pos());simulate(2.5);check(enemy.hp<9700. and not hero.buffs.has("culling"),"Solstice channel fires sustained volley and expires")
  "sivir":
   hero.try_cast_skill(2,hero.world_pos());var before=hero.hp;game.deal_damage(enemy,hero,300,"magic");check(hero.hp==before and not hero.buffs.has("spell_ward") and hero.mp>965.,"Zephyr ward blocks one spell and restores mana")
   reset_fight();hero.try_cast_skill(0,enemy.world_pos());simulate(1.7);check(enemy.hp<10000.-Roster12Kits.amount(hero,"sivir_q")*1.5,"Zephyr blade deals outward and return damage")
  "brand":
   hero.try_cast_skill(2,enemy.world_pos());hero.try_cast_skill(0,enemy.world_pos());simulate(.2);check(enemy.stun>0.,"Pyre Q stuns already burning enemy")
   hero.try_cast_skill(1,enemy.world_pos());simulate(.8);check(enemy.buffs.has("blaze_detonate"),"Pyre third spell schedules detonation");var before=enemy.hp;simulate(1.1);check(before-enemy.hp>500.,"Pyre three-stack detonation deals max-health damage")
  "syndra":
   hero.try_cast_skill(0,enemy.world_pos());check(Roster12Kits.spheres(hero).size()==1,"Umbra Q leaves persistent sphere");hero.try_cast_skill(2,enemy.world_pos());simulate(.3);check(enemy.stun>0. and Roster12Kits.spheres(hero).is_empty(),"Umbra E launches sphere and stuns")
   reset_fight();Roster12Kits.visual(hero,enemy.world_pos(),"syndra_q",38,6.,{"zone_kind":"sphere"});hero.try_cast_skill(3,enemy.world_pos());check(hero.buffs.sphere_barrage.shots==4 and Roster12Kits.spheres(hero).is_empty(),"Umbra ultimate consumes sphere and adds a fourth shot")
  "xerath":
   hero.try_cast_skill(0,enemy.world_pos());simulate(.6);check(not Roster12Kits.recast_info(hero,0).is_empty(),"Arclight charged beam shows recast");hero.try_cast_skill(0,enemy.world_pos());check(enemy.hp<10000.,"Arclight beam hits after release")
   reset_fight();hero.try_cast_skill(3,enemy.world_pos())
   for shot in range(3):check(hero.try_cast_skill(3,enemy.world_pos()),"Arclight artillery shot "+str(shot));simulate(.7)
   check(not hero.buffs.has("artillery") and enemy.hp<9700.,"Arclight three artillery shots end stance")
