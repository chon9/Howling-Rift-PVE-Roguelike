extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL SILVER BOLTS: "+message)
func land(hero,target) -> void:
 hero._perform_auto(target)
 for frame in range(40):
  for projectile in GameState.projectiles.duplicate():
   if is_instance_valid(projectile):projectile.update_frame(.01)
func prepare(target,hp: float=10000.) -> void:
 target.dead=false;target.hp_max=hp;target.hp=hp;target.shield=0.;target.buffs.clear();target.inventory=["","","","","",""];target.bonus_armor=500.;target.difficulty_stats={};target.global_position=Vector2(1500,270)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("vayne")
 var hero=GameState.player;var target=GameState.champions[3];var other=GameState.champions[4]
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 hero.global_position=Vector2(1350,270);hero.inventory=["","","","","",""];hero.buffs.clear();hero.bonus_crit=0.;hero.bonus_armor_pen=0.;hero.bonus_lethality=0.;hero.difficulty_stats={};hero.bonus_ap=500.
 var auto_damage=floor(hero.ad/6.)
 prepare(target)
 ExpansionKits.tick(hero,0.)
 check(not hero.try_cast_skill(1,hero.world_pos()),"W is a learned passive, not an active cast")
 check(hero.buffs.has("silver") and hero.buffs.silver.time>9000.,"W stays active once learned")
 for hit in range(1,4):
  var hp=target.hp;land(hero,target)
  var expected=auto_damage+(500. if hit==3 else 0.)
  check(is_equal_approx(hp-target.hp,expected),"real projectile hit %d deals expected damage" % hit)
  check(hero.buffs.silver.stacks==hit%3,"hit counter advances/reset correctly")
 print("SILVER BOLTS rank 1: normal hit %.0f, third hit %.0f (500 true damage against 10000 HP / 500 armor)" % [auto_damage,auto_damage+500.])
 for hit in range(3):land(hero,target)
 check(is_equal_approx(target.hp,10000.-auto_damage*6.-1000.),"six hits trigger twice")
 prepare(target);prepare(other);other.global_position=Vector2(1500,330)
 land(hero,target);land(hero,other);land(hero,target)
 check(hero.buffs.silver.stacks==1 and hero.buffs.silver.target_id==target.get_instance_id(),"switching target resets stacks")
 var minion=game.MinionS.new();game.world_root.add_child(minion);minion.setup(1,"melee",Vector2(1500,270));GameState.minions.append(minion)
 minion.hp_max=10000.;minion.hp=10000.;minion.buffs.clear();target.global_position=Constants.FOUNT_R;other.global_position=Constants.FOUNT_R
 for hit in range(3):land(hero,minion)
 check(is_equal_approx(10000.-minion.hp,floor(hero.ad)*3.+80.),"minion bonus is capped at 80 true damage")
 hero.update_frame(5.1)
 check(hero.buffs.has("silver"),"W remains active after five seconds")
 prepare(target);var before=target.hp;land(hero,target)
 check(is_equal_approx(before-target.hp,auto_damage),"new target starts at one stack")
 hero.skill_ranks[1]=5;hero.skill_cds[1]=0.;hero.mp=hero.mp_max;hero.global_position=Vector2(1350,270)
 hero.buffs.erase("silver");ExpansionKits.tick(hero,0.)
 check(hero.buffs.silver.ratio==.09,"rank-five W updates its permanent ratio")
 before=target.hp
 for hit in range(3):land(hero,target)
 check(is_equal_approx(before-target.hp,auto_damage*3.+900.),"rank-five third hit deals nine percent max HP")
 var encoded=LanSnapshot.encode().champs[0].buffs.silver
 check(encoded.stacks==hero.buffs.silver.stacks and encoded.ratio==hero.buffs.silver.ratio,"co-op receives W stacks and ratio")
 print("VESPER SILVER BOLTS: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
