extends Node
const Scaling = preload("res://scripts/SkillScaling.gd")
var checks = 0
var failures = 0
var game
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL BALANCE: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._show_menu();game._start_game("darius")
 check(is_equal_approx(game.camera.zoom.x/1.3,1.7/1.3),"world grows 31 percent with proportions preserved")
 for key in ExpansionRoster.KEYS:
  var c=game.ChampionS.new();game.world_root.add_child(c);c.setup(0,key,false,key)
  GameState.champions.append(c);c.global_position=Vector2(1150,270);c.level=3;c.skill_ranks=[1,1,1,1];c._recompute_stats();c.mp=c.mp_max
  check(c.mp_max>=350 and c.mp_regen>0,"real starting mana and regeneration: "+key)
  var before=c.mp
  check(c.try_cast_skill(0,c.world_pos()+Vector2(40,0)) if key=="vayne" else c.try_cast_skill(1,c.world_pos()),"cast W with actual starting resource: "+key)
  check(is_equal_approx(before-c.mp,c.hero.skills[0 if key=="vayne" else 1].cost),"casts spend advertised mana: "+key)
  c.mp=0;c.skill_cds=[0.,0.,0.,0.]
  check(not c.try_cast_skill(1,c.world_pos()),"empty mana blocks casting: "+key)
  c.update_frame(.1);check(c.mp>0,"resource regenerates: "+key)
  for a in GameState.aoes:a.queue_free()
  GameState.aoes.clear()
 var enemy=GameState.champions[3]
 for c in GameState.champions:c.is_bot=false;c.stop_actions()
 enemy.global_position=Vector2(1500,270);enemy.hp_max=100000;enemy.hp=100000;enemy.shield=0;enemy.bonus_mr=0;enemy.bonus_armor=0;enemy.base_mr=30;enemy.difficulty_stats=Progression.scaling(1)
 for key in ["lux","ahri","katarina","garen"]:
  var c=game.ChampionS.new();game.world_root.add_child(c);c.setup(0,key,false,key);GameState.champions.append(c)
  c.bonus_ap=400;var hp=enemy.hp
  game.deal_damage(c,enemy,100,"skill")
  var expected=(100+400*Scaling.legacy_ap_ratio(key))*100/(130. if ExpansionCombat.is_magic(c,"skill") else 100.)
  check(is_equal_approx(hp-enemy.hp,floor(expected)),"actual AP hit honors coefficient and innate MR: "+key)
  check(is_equal_approx(Scaling.value(key+"_q",1,c.ad,400)-Scaling.value(key+"_q",1,c.ad,0),400*Scaling.legacy_ap_ratio(key)) if key!="garen" else true,"tooltip coefficient matches combat: "+key)
 check(is_equal_approx(Scaling.legacy_ap_ratio("katarina")*10,1.5),"ten channel ticks scale with 150 percent total AP, not 1000 percent")
 for stage in range(1,100):
  var scaling=Progression.scaling(stage)
  if stage>1:
   var previous=Progression.scaling(stage-1)
   for stat in ["health","damage","armor","magic_resist","structure_health","structure_damage"]:
    check(scaling[stat]>previous[stat],"N%d increases %s" % [stage,stat])
   check(scaling.reaction<previous.reaction,"N%d reacts faster" % stage)
 for stage in [1,10,50,99]:
  GameState.difficulty=stage
  for type in game.StructureS.SPECS:
   var red=game.StructureS.new();game.world_root.add_child(red);red.setup(1,type,Vector2(2300,270))
   var blue=game.StructureS.new();game.world_root.add_child(blue);blue.setup(0,type,Vector2(400,270))
   check(is_equal_approx(red.hp_max,game.StructureS.SPECS[type].hp*Progression.scaling(stage).structure_health) and red.hp==red.hp_max,"enemy structure HP uses N%d: %s" % [stage,type])
   check(blue.hp_max==game.StructureS.SPECS[type].hp,"allied structures retain base HP")
   check(is_equal_approx(red.atk_dmg,game.StructureS.SPECS[type].dmg*Progression.scaling(stage).structure_damage),"tower damage uses N%d" % stage)
   red.queue_free();blue.queue_free()
  var c=game.ChampionS.new();game.world_root.add_child(c);c.setup(1,"malphite",true,"Tank")
  check(is_equal_approx(c.hp_max,c.hero.hp*Progression.scaling(stage).health),"enemy HP scales at spawn")
  check(ExpansionCombat.resist(c,null,"magic")>=42.+Progression.scaling(stage).magic_resist,"enemy MR scales at spawn")
  c.queue_free()
 GameState.difficulty=1
 var texture=SpellArt.missile_sheet(true)
 check(texture!=null and texture!=SpellArt.missiles,"new roster has dedicated painted projectiles")
 var image=texture.get_image()
 check(image.get_pixel(0,0).a==0.,"projectile sheet preserves generated transparency")
 for key in ExpansionRoster.KEYS:
  var source=GameState.champions.filter(func(c):return c.hero_key==key and c.team==0).back()
  var p=game.ProjectileS.new();game.world_root.add_child(p);p.setup(source,Vector2(1300,270),Vector2.RIGHT,{"damage_type":"magic","life":2.})
  GameState.projectiles.append(p)
  check(p.expansion_art and p.art_row==ExpansionRoster.KEYS.find(key),"projectile selects correct identity row: "+key)
  var frame=SpellArt.frame(texture,p.art_row,0)
  p.update_frame(.07)
  check(SpellArt.frame(texture,p.art_row,int(p.animation_time*18)%8)!=frame,"flight animation advances: "+key)
 var packet=LanSnapshot.encode()
 check(packet.champs[0].has("base_mr") and packet.projectiles.back().expansion_art,"co-op replicates innate MR and new projectile identity")
 for p in GameState.projectiles:p.queue_free()
 GameState.projectiles.clear()
 var vayne=GameState.champions.filter(func(c):return c.hero_key=="vayne" and c.team==0).back()
 vayne.global_position=Vector2(1350,270);enemy.global_position=Vector2(1500,270);enemy.buffs.clear();enemy.stun=0
 var hp=enemy.hp;var point=enemy.world_pos()
 check(ExpansionKits.cast(vayne,"vayne_e",point),"Condemn casts homing bolt")
 check(enemy.hp==hp and enemy.world_pos()==point,"Condemn waits for projectile contact")
 for i in range(30):
  for p in GameState.projectiles.duplicate():if is_instance_valid(p):p.update_frame(.02)
 check(enemy.hp<hp and enemy.world_pos().distance_to(point)>100,"Condemn deals damage and knockback on impact")
 game._return_to_main_menu();game.queue_free();await get_tree().process_frame
 print("BALANCE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
