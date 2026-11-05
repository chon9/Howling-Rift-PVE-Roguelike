extends "res://tests/AllContentAudit.gd"
func near(value: float,expected: float,label: String) -> void:check(absf(value-expected)<.05,label+" actual %.2f expected %.2f" % [value,expected])
func equip(ids: Array) -> void:
 hero.inventory=ids;hero._apply_items();hero.hp=hero.hp_max;hero.shield=0.;hero.buffs.clear();hero.item_cds.clear();enemy.buffs.clear();enemy.shield=0.
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("lux")
 reset("lux");equip(["ludens"]);enemy.bonus_armor=900.;var hp=enemy.hp
 game.deal_damage(hero,enemy,100.,"physical");near(hp-enemy.hp,88.,"Luden proc remains magic on a physical spell")
 hp=enemy.hp;game.deal_damage(hero,enemy,100.,"physical");near(hp-enemy.hp,10.,"Luden shared cooldown")
 reset("lux");equip(["ludens"]);game.deal_damage(hero,enemy,0.,"magic");check(not hero.item_cds.has("ludens") and enemy.hp==100000.,"zero damage does not proc items")
 enemy.inventory=["banshee"];enemy.item_cds.clear();game.deal_damage(hero,enemy,100.,"magic");check(not hero.item_cds.has("ludens") and enemy.hp==100000.,"blocked spell does not consume attacker proc")
 reset("morgana");equip(["ludens"]);hero.hp=100.;game.deal_damage(hero,enemy,100.,"magic","morgana_q");near(hero.hp,120.,"Siphon excludes Luden item damage")
 reset("garen");equip(["bloodthirster"]);hero.hp=100.;enemy.hp=5.;game.deal_damage(hero,enemy,100.,"auto");near(hero.hp,101.,"lifesteal uses actual health damage, excluding overkill")
 reset("garen");equip(["bloodthirster"]);hero.shield=400.;game.deal_damage(hero,enemy,100.,"auto");near(hero.shield,420.,"Bloodthirster preserves an unrelated shield")
 for i in range(30):game.deal_damage(hero,enemy,100.,"auto")
 near(hero.buffs.bloodthirster_shield.shield,hero.hp_max*.15,"overheal cap applies only to own shield")
 near(hero.shield,400.+hero.hp_max*.15,"overheal cap preserves other shields")
 for spec in [["lux",1,"prismatic_shield",3.],["annie",2,"molten_shield",3.],["garen",1,"courage_shield",3.],["leesin",1,"safeguard_shield",4.],["malphite",1,"granite_w_shield",3.],["morgana",2,"black_ward_shield",2.5],["riven",2,"valor",2.]]:
  reset(spec[0]);hero.shield=400.;var point=hero.world_pos()
  check(hero.try_cast_skill(spec[1],point),spec[0]+" shield casts")
  check(hero.buffs.has(spec[2]) and hero.shield>400.,spec[0]+" shield adds independently")
  game.deal_damage(enemy,hero,20.,"exec")
  # Expire just the named shield; other champion mechanics cannot contaminate this assertion.
  var remaining=hero.buffs[spec[2]].shield;ExpansionCombat.expire(hero,spec[2]);hero.buffs.erase(spec[2])
  near(hero.shield,400.,spec[0]+" partial absorption and expiry preserve unrelated shield")
 reset("yasuo");hero.shield=400.;hero.passive_state.flow=100.;game.deal_damage(enemy,hero,20.,"auto");advance(1.1);near(hero.shield,400.,"Flow shield expires once without removing another shield")
 reset("malphite");HeroPassives.tick(hero,.01);var granite=hero.passive_state.granite;CombatEffects.shield(hero,"locket_shield",100.,3.);game.deal_damage(enemy,hero,50.,"auto");near(hero.passive_state.granite,granite,"item shield absorption does not drain Granite passive")
 reset("garen");hero.buffs.courage={"time":3.,"dr":.9};var before=hero.hp;game.deal_damage(enemy,hero,100.,"exec");near(before-hero.hp,100.,"true damage ignores percent reduction")
 reset("garen");equip(["warmog"]);hero.hp=100.;hero.time_since_damage=7.;hero.passive_state.perseverance_hit=GameState.time;hero.buffs.grievous={"time":3.};before=hero.hp;hero.update_frame(1.);near(hero.hp-before,(hero.hp_regen+hero.hp_max*.02)*.6,"antiheal applies to Warmog recovery")
 reset("garen");hero.buffs.cc_guard={"time":3.};enemy.hero_key="garen";enemy.buffs.decisive={"time":3.,"used":false,"bonus":10.};enemy._perform_auto(hero);check(not hero.buffs.has("silence"),"CC immunity blocks empowered silence")
 reset("garen");enemy.passive_state.perseverance_hit=GameState.time+100.;enemy.buffs.ignite={"time":5.,"tick":0.,"total":300.,"src":hero};hp=enemy.hp
 for n in range(10):enemy.update_frame(.5)
 near(hp-enemy.hp,300.,"Ignite deals all ten ticks including the last")
 reset("garen");enemy.passive_state.perseverance_hit=GameState.time+100.;enemy.buffs.ignite={"time":5.,"tick":0.,"total":300.,"src":hero};hp=enemy.hp;enemy.update_frame(5.);near(hp-enemy.hp,300.,"Ignite catches up after a long frame")
 for id in ["fiora_w","caitlyn_e","lucian_w","xinzhao_e"]:
  reset(id.get_slice("_",0));enemy.bonus_armor=900.;hp=enemy.hp
  Roster12Kits.hit(hero,enemy,id);near(hp-enemy.hp,floor(Roster12Kits.amount(hero,id)),id+" uses magic resistance")
 for id in ["ashe_r","ezreal_e","leesin_e","jinx_e","yasuo_e"]:
  reset(id.get_slice("_",0));enemy.bonus_armor=900.;hp=enemy.hp
  game.deal_damage(hero,enemy,100.,"skill",id);near(hp-enemy.hp,100.,id+" legacy magic classification")
 reset("lux");hero.skill_ranks[0]=0.;hero.mp=hero.mp_max;check(not hero.try_cast_skill(0,enemy.world_pos()),"unlearned skill rejected")
 hero.skill_ranks[0]=1;hero.skill_cds[0]=5.;check(not hero.try_cast_skill(0,enemy.world_pos()),"cooldown rejected");hero.skill_cds[0]=0.;hero.mp=0.;check(not hero.try_cast_skill(0,enemy.world_pos()),"insufficient mana rejected")
 hero.mp=hero.mp_max;hero.buffs.silence={"time":2.};check(not hero.try_cast_skill(0,enemy.world_pos()),"silence rejected");hero.buffs.clear();hero.stun=1.;check(not hero.try_cast_skill(0,enemy.world_pos()),"stun rejected");hero.stun=0.;hero.dead=true;check(not hero.try_cast_skill(0,enemy.world_pos()),"dead cast rejected")
 reset("ashe");equip(["nashor","kraken"]);hero.bonus_crit=0.;hero.try_cast_skill(0,hero.world_pos());hero._perform_auto(enemy)
 check(GameState.projectiles.filter(func(p):return p.damage_type=="auto").size()==1 and GameState.projectiles.filter(func(p):return p.damage_type=="attack_fragment").size()==2,"Skadi Q has one on-hit application per attack")
 advance(.4);check(hero.buffs.kraken.stacks==1,"Skadi Q does not instantly trigger third-hit item")
 reset("lucian");equip(["nashor","kraken"]);hero.buffs.lightslinger={"time":3.};game.deal_damage(hero,enemy,100.,"auto");advance(.3);check(hero.buffs.kraken.stacks==2,"Lightslinger second shot applies attack item procs")
 reset("riven");equip([]);hero.try_cast_skill(0,enemy.world_pos());clear_effects();var m=creep_for_last_hit();var prediction=GameState.last_hit_damage(hero,m);hp=m.hp;hero._perform_auto(m);near(hp-m.hp,prediction,"last-hit cue includes rune charge")
 reset("xinzhao");equip([]);hero.passive_state.determination=2;var m2=creep_for_last_hit();prediction=GameState.last_hit_damage(hero,m2);hp=m2.hp;hero._perform_auto(m2);near(hp-m2.hp,prediction,"last-hit cue includes third attack passive")
 reset("garen");equip(["sheen"]);hero.ad=100.;hero.bonus_crit=1.;hero.buffs.spellblade={"time":5.};hp=enemy.hp;hero._perform_auto(enemy);near(hp-enemy.hp,250.,"critical strike does not multiply Spellblade proc")
 reset("annie");hero.mp=hero.mp_max;var mana=hero.mp;check(not hero.try_cast_skill(0,Vector2(2000,270)) and hero.mp==mana and hero.skill_cds[0]==0.,"targeted fireball rejects empty ground without spending resources")
 reset("ezreal");enemy.inventory=["banshee"];enemy.item_cds.clear();hero.try_cast_skill(1,enemy.world_pos());advance(.3);check(enemy.item_cds.get("banshee",0.)>0 and not enemy.buffs.has("flux_mark"),"Banshee blocks zero-damage Flux mark")
 reset("garen");equip(["frozen_heart"]);var chilled=creep_for_last_hit();ExpansionCombat.tick(hero,.01);near(chilled.effective_atk_spd(),chilled.atk_spd*.8,"Frozen Heart slows nearby minion attacks")
 reset("zed");enemy.inventory=["banshee"];enemy.item_cds.clear();hero.try_cast_skill(3,enemy.world_pos());check(not enemy.buffs.has("death_mark") and enemy.item_cds.get("banshee",0.)>0,"Banshee blocks death mark application")
 print("COMBAT INTERACTION AUDIT: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)

func creep_for_last_hit():
 var m=game.MinionS.new();game.world_root.add_child(m);m.setup(1,"melee",hero.world_pos()+Vector2(40,0));m.hp_max=10000.;m.hp=10000.;GameState.minions.append(m);return m
