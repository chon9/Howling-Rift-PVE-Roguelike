extends Node
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL EXPANSION: "+message)
func clear_combat() -> void:
 for p in GameState.projectiles:p.queue_free()
 for a in GameState.aoes:a.queue_free()
 GameState.projectiles.clear();GameState.aoes.clear()
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 check(ChampionData.CHAMPIONS.size()==32,"thirty-two selectable heroes")
 check(ItemData.ITEMS.size()==84 and ItemData.ORDER.size()==84,"eighty-four unique shop entries")
 var first=MatchRoster.enemy_team(["ashe","garen","lux"])
 var second=MatchRoster.enemy_team(["ashe","garen","lux"])
 for key in second:check(not first.has(key) and not ["ashe","garen","lux"].has(key),"consecutive enemy lineups avoid repeats and allied mirrors")
 for id in ItemData.ORDER:
  check(ShopArt.item_icon(id)!=null,"item has painted icon: "+id)
  var item=ItemData.ITEMS[id];var cost=0
  for part in item.recipe:
   check(ItemData.ITEMS.has(part),"valid component: "+part);cost+=ItemData.ITEMS[part].cost
  check(cost<=item.cost,"component totals do not exceed finished price: "+id)
 for key in ExpansionRoster.KEYS:
  check(HeroArt.texture_for(key)!=null,"new hero portrait loads")
  game._start_game(key)
  var c=GameState.player
  for unit in GameState.champions:unit.is_bot=false;unit.stop_actions();unit.global_position=Vector2(1000,270)
  var enemy=GameState.champions[3];enemy.global_position=Vector2(1120,270);enemy.hp_max=100000.;enemy.hp=100000.
  c.global_position=Vector2(1000,270);c.skill_ranks=[5,5,5,3];c.mp=99999.;c.buffs.clear()
  for i in range(4):
   c.skill_cds=[0.,0.,0.,0.];c.mp=99999.
   if c.hero.skills[i].kind=="passive":
    check(not c.try_cast_skill(i,enemy.world_pos()),"learned W cannot be cast");ExpansionKits.tick(c,0.);check(c.buffs.has("silver"),"learned W active");continue
   check(c.try_cast_skill(i,enemy.world_pos()),"new skill successfully dispatches: "+key+str(i))
   check(c.anim_action==["q","w","e","r"][i],"actual cast uses correct action row")
   check(AbilityArt.icon_for(key,i)!=null,"new ability icon")
   check(not ChampionData.skill_description(key,i,c).is_empty(),"new scaling tooltip")
   for n in range(20):
    c.update_frame(.05)
    for p in GameState.projectiles.duplicate():if is_instance_valid(p):p.update_frame(.05)
    for a in GameState.aoes.duplicate():if is_instance_valid(a):a.update_frame(.05)
   clear_combat()
  game._return_to_main_menu()
  await get_tree().process_frame
 game._start_game("vayne")
 var c=GameState.player;var enemy=GameState.champions[3]
 for hero in GameState.champions:hero.is_bot=false;hero.stop_actions()
 c.global_position=Vector2(1000,270);enemy.global_position=Vector2(1070,270)
 c.inventory=["nashor","void_staff","black_cleaver","morello","liandry",""];c._apply_items()
 enemy.hp_max=10000.;enemy.hp=10000.;enemy.shield=0;enemy.bonus_armor=100.;enemy.bonus_mr=100.
 check(absf(ExpansionCombat.resist(enemy,c,"magic")-(100.+enemy.base_mr)*.65)<.01,"Void Staff penetrates item and innate magic resistance")
 game.deal_damage(c,enemy,100.,"auto")
 check(enemy.buffs.has("armor_shred") and enemy.hp<9950.,"Cleaver shred and Nashor magic on-hit execute")
 game.deal_damage(c,enemy,100.,"magic")
 check(enemy.buffs.has("item_burn") and enemy.buffs.has("grievous"),"Liandry burn and Morello antiheal applied")
 enemy.buffs.item_burn.tick=.75
 game.deal_damage(c,enemy,10.,"magic")
 check(absf(enemy.buffs.item_burn.tick-.75)<.01,"repeated skill hits refresh burn without resetting its tick clock")
 var health=enemy.hp;ExpansionCombat.tick(enemy,1.)
 check(enemy.hp<health,"burn deals real damage")
 check(absf(ExpansionCombat.healing_multiplier(enemy)-.6)<.01,"antiheal reduces healing")
 enemy.inventory=["spirit_visage", "banshee","sterak","frozen_heart","",""];enemy._apply_items();enemy.buffs.clear();enemy.item_cds.clear()
 health=enemy.hp
 game.deal_damage(c,enemy,100.,"magic")
 check(enemy.hp==health and enemy.buffs.has("spell_guard") and enemy.item_cds.banshee>0,"Banshee blocks a spell and protects from its CC")
 check(absf(ExpansionCombat.healing_multiplier(enemy)-1.25)<.01,"Visage increases healing")
 enemy.hp=enemy.hp_max*.25;ExpansionCombat.lifeline(enemy)
 check(enemy.shield>0 and enemy.item_cds.sterak>0,"Sterak lifeline grants actual shield")
 ExpansionCombat.tick(enemy,.02)
 check(c.buffs.has("cripple"),"Frozen Heart reduces nearby enemy attack speed")
 c.inventory=["trinity","","","","",""];c._apply_items();c.skill_ranks=[1,1,1,1];c.skill_cds=[0.,0.,0.,0.];c.mp=99999.
 c.try_cast_skill(0,c.world_pos()+Vector2(40,0))
 check(c.buffs.has("spellblade"),"Trinity primes upgraded Spellblade")
 var slot=["sheen","caulfield","kindlegem","","",""]
 var plan=ItemData.purchase_plan("trinity",slot)
 check(plan.valid and plan.cost==500 and plan.consume.size()==3,"Trinity component upgrade costs only remaining gold")
 clear_combat();enemy.buffs.clear();enemy.item_cds.clear();enemy.inventory=["","","","","",""];enemy._apply_items();enemy.hp=enemy.hp_max;enemy.shield=0
 var center=enemy.world_pos()
 NewHeroKits.area(c,center,155,10.,{"ring":true,"stun":1.,"duration":2.,"damage_type":"magic"})
 var cage=GameState.aoes.back();health=enemy.hp;cage.update_frame(.02)
 check(enemy.hp==health,"cage interior does not hit before touching rim")
 enemy.global_position=center+Vector2(155,0);cage.update_frame(.02)
 check(enemy.hp<health and enemy.stun>0,"cage rim applies damage and stun")
 clear_combat();enemy.stun=0;enemy.buffs.cc_guard={"time":2.}
 NewHeroKits.area(c,enemy.world_pos(),100,10.,{"stun":1.,"damage_type":"magic"})
 GameState.aoes.back().update_frame(.02)
 check(enemy.stun==0,"Black Ward blocks actual area crowd control")
 clear_combat();game._return_to_main_menu();game._start_game("malphite")
 c=GameState.player;enemy=GameState.champions[3]
 for unit in GameState.champions:unit.is_bot=false;unit.stop_actions();unit.global_position=Vector2(1000,270)
 c.global_position=Vector2(1000,270);enemy.global_position=Vector2(1240,270);enemy.hp_max=5000;enemy.hp=5000;enemy.shield=0;c.skill_ranks=[1,1,1,1];c.mp=99999
 health=enemy.hp;c.try_cast_skill(3,enemy.world_pos())
 check(c.is_dashing and enemy.hp==health,"Granite charge starts movement before impact")
 for i in range(35):
  c.update_frame(.02)
  for a in GameState.aoes.duplicate():if is_instance_valid(a):a.update_frame(.02)
 check(enemy.hp<health and enemy.stun>0,"Granite charge damages and stuns on arrival")
 game.queue_free();await get_tree().process_frame
 print("EXPANSION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
