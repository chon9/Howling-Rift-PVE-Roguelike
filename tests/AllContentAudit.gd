extends Node
var game
var hero
var enemy
var failures=0
var checks=0
const UTILITY=["ezreal_w","kayle_w","lux_w","ashe_e","annie_e","garen_w","yasuo_w","leesin_w","zed_w","darius_e","malphite_w","veigar_e","morgana_e","thresh_w","blitzcrank_w","riven_e","fiora_r","caitlyn_w","lucian_e","sivir_e","sivir_r","syndra_w","xerath_q","xerath_r"]
const EMPOWER=["ashe_q","garen_q","jinx_q","kayle_e","darius_w","vayne_q","vayne_w","vayne_r","leona_q","blitzcrank_e","renekton_w","xinzhao_q","fiora_e","sivir_w","riven_r"]
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL CONTENT AUDIT: "+label)
func clear_effects() -> void:
 for p in GameState.projectiles.duplicate():if is_instance_valid(p):p._destroy()
 for a in GameState.aoes.duplicate():if is_instance_valid(a):GameState.aoes.erase(a);a.queue_free()
func reset(key: String,rank: int=1) -> void:
 clear_effects()
 for m in GameState.minions:if is_instance_valid(m):m.queue_free()
 GameState.minions.clear()
 var old=GameState.champions[0];hero=game.ChampionS.new();game.world_root.add_child(hero);hero.setup(0,key,false,"Audit");GameState.champions[0]=hero;GameState.player=hero;old.queue_free()
 hero.inventory=[];hero.run_bonus.clear();hero.permanent_bonus.clear();hero.level=18;hero._apply_items();hero.skill_ranks=[rank,rank,rank,mini(3,rank)];hero.mp=hero.mp_max;hero.hp=hero.hp_max*.5;hero.global_position=Vector2(1320,270);hero.stop_actions()
 for c in GameState.champions:
  c.is_bot=false;c.stop_actions();c.stun=0.;c.buffs.clear();c.shield=0.;c.dead=false;c.is_targetable=true
  if c!=hero:c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 enemy=GameState.champions[3];enemy.inventory=[];enemy.hero_key="garen";enemy.hp_max=100000.;enemy.hp=100000.;enemy.hp_regen=0.;enemy.bonus_armor=0.;enemy.base_mr=0.;enemy.bonus_mr=0.;enemy.global_position=Vector2(1430,270)
 GameState.champions[1].global_position=hero.world_pos()+Vector2(30,0);GameState.champions[1].hp=100.
 GameState.running=true;GameState.paused=false
func advance(seconds: float) -> void:
 for n in range(int(ceil(seconds/.02))):
  GameState.time+=.02
  for c in GameState.champions:c.update_frame(.02)
  for p in GameState.projectiles.duplicate():if is_instance_valid(p) and not p.is_queued_for_deletion():p.update_frame(.02)
  for a in GameState.aoes.duplicate():if is_instance_valid(a) and not a.is_queued_for_deletion():a.update_frame(.02)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("lux")
 check(ChampionData.CHAMPIONS.size()==32 and ItemData.ITEMS.size()==84,"complete roster and catalog")
 for key in ChampionData.CHAMPIONS:
  for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
   for frame in range(6):
    var tex=ActionSpriteArt.texture_for_frame("hero_"+key,action,frame);var region=ActionSpriteArt.region("hero_"+key,action,frame)
    check(tex!=null and region.has_area() and Rect2(Vector2.ZERO,tex.get_size()).encloses(region),key+" action frame "+action+str(frame))
  for index in range(4):
   for rank in [1,5]:
    reset(key,rank);var skill=hero.hero.skills[index];var id=skill.cast_id
    check(AbilityArt.icon_for(key,index)!=null,id+" icon")
    check(not ChampionData.skill_description(key,index,hero).is_empty(),id+" description")
    var point=GameState.champions[1].world_pos() if id in ["soraka_w","janna_e"] else enemy.world_pos()
    if id=="yasuo_r":HeroControl.airborne(enemy,2.)
    if id=="syndra_w":Roster12Kits.visual(hero,point,"syndra_q",38,6.,{"zone_kind":"sphere"})
    if skill.kind=="passive":
     check(not hero.try_cast_skill(index,point),id+" passive not castable");ExpansionKits.tick(hero,0.);check(hero.buffs.has("silver"),id+" passive active");continue
    if id=="garen_e":enemy.global_position=hero.world_pos()+Vector2(60,0)
    if id=="thresh_r":enemy.global_position=hero.world_pos()+Vector2(0,-180)
    var mana=hero.mp
    check(hero.try_cast_skill(index,point),id+" rank "+str(rank)+" valid cast")
    check(is_equal_approx(hero.mp,mana-skill.cost),id+" exact resource cost")
    var observed=hero.shield>0 or hero.is_dashing or not hero.buffs.is_empty() or not GameState.aoes.is_empty() or not GameState.projectiles.is_empty()
    if id in ["lux_w","kayle_w","sivir_r","morgana_e"]:observed=observed or GameState.champions[1].shield>0 or GameState.champions[1].hp>100.
    if id=="darius_e":observed=enemy.buffs.has("forced_motion")
    var recast=NewHeroKits.recast_info(hero,index)
    if not recast.is_empty() and recast.available:hero.try_cast_skill(index,point)
    if id in ["soraka_w","soraka_r","janna_e","janna_r"]:observed=observed or GameState.champions[1].shield>0 or GameState.champions[1].hp>100.
    if id in EMPOWER:
     for n in range(3):hero._perform_auto(enemy)
    advance(3.3)
    if id not in UTILITY and id not in ["soraka_w","soraka_r","janna_e","janna_r"]:check(enemy.hp<100000.,id+" produces real combat damage")
    else:check(observed,id+" creates its utility effect")
    await get_tree().process_frame
  reset(key)
  for item_id in ItemData.ORDER:
   var item=ItemData.ITEMS[item_id]
   if item.get("consumable",false):continue
   hero.inventory=[item_id,"","","","",""];hero._apply_items()
   for stat in item.stats:
    var expected=float(item.stats[stat])
    if stat=="bonus_cdr":expected=minf(.4,expected)
    if stat=="bonus_ap":
     if item_id=="archangel" and hero.hero.mp>0 and key not in ["leesin","zed"]:expected+=hero.mp_max*.025
     if item_id=="rabadon":expected*=1.3
    check(is_equal_approx(hero.get(stat),expected),key+" "+item_id+" actual stat "+stat)
   check(is_finite(hero.hp_max) and hero.hp_max>0 and is_finite(hero.effective_atk_spd()) and hero.effective_atk_spd()>0,key+" "+item_id+" valid derived stats")
   if key in ["leesin","zed"]:check(hero.mp_max==200.,key+" item cannot increase energy cap")
   if hero.hero.mp==0:check(hero.mp_max==0.,key+" item cannot create fake mana")
 for id in ItemData.ORDER:
  var item=ItemData.ITEMS[id]
  check(ShopArt.item_icon(id)!=null,id+" shop art")
  check(not ItemData.item_tooltip(id).is_empty(),id+" tooltip")
  reset("lux");hero.global_position=Constants.FOUNT_B;hero.gold=1000000;hero.inventory=["","","","","",""]
  var before=hero.gold;check(hero.try_buy_item(id),id+" real purchase")
  check(hero.gold==before-item.cost,id+" gold charged")
  if item.get("consumable",false):check(hero.consumable_counts.get(id,0)==1,id+" permanent match stats apply")
  else:
   check(hero.inventory.has(id),id+" inventory slot")
   var slot=hero.inventory.find(id);before=hero.gold;check(hero.try_sell_item(slot) and hero.gold==before+ItemData.sell_value(id),id+" real sale")
   for stat in item.stats:check(is_zero_approx(hero.get(stat)),id+" stat removed on sell "+stat)
 print("ALL CONTENT AUDIT: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
