extends Node
var checks=0
var failures=0
var game
var p
var enemy
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL ITEM BUILDS: "+message)
func equip(c,ids: Array) -> void:
 c.inventory=ids.duplicate()
 while c.inventory.size()<6:c.inventory.append("")
 c.buffs.clear();c.item_cds.clear();c.run_bonus.clear();c.permanent_bonus.clear();c._apply_items()
func prepare(ours: Array=[],theirs: Array=[]) -> void:
 GameState.time=0.;GameState.paused=false;GameState.running=true
 for c in GameState.champions:c.dead=false;c.is_bot=false;c.stop_actions();c.global_position=Vector2(2400,270)
 equip(p,ours);equip(enemy,theirs)
 p.global_position=Vector2(1100,270);enemy.global_position=Vector2(1220,270)
 p.hp_max=2000.;p.hp=1000.;p.ad=100.;p.bonus_ad=50.;p.bonus_crit=0.;p.mp_max=500.;p.mp=100.
 enemy.hp_max=10000.;enemy.hp=10000.;enemy.shield=0.;enemy.bonus_armor=0.;enemy.base_mr=0.;enemy.bonus_mr=0.;enemy.difficulty_stats=Progression.scaling(1)
 p.shield=0.;p.base_mr=0.;p.bonus_mr=0.;p.bonus_armor=0.
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.difficulty=1;Progression.levels.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game.network_config={"blue":["garen","ashe","lux"],"red":["garen","ashe","lux"],"players":[{"peer":1,"slot":0,"name":"Test","spells":["flash","ignite"],"bonuses":{}}]};game._start_game("garen")
 p=GameState.player;enemy=GameState.champions[3]
 check(ItemData.ORDER.size()==84 and ItemData.ITEMS.size()==84,"shop contains eighty-four unique items")
 for id in TankADItems.KEYS:
  var item=ItemData.ITEMS[id]
  check(ShopArt.item_icon(id)!=null,"painted icon loads: "+id)
  var components=item.recipe.duplicate()
  while components.size()<6:components.append("")
  var sum=0
  for part in item.recipe:sum+=ItemData.ITEMS[part].cost
  var plan=ItemData.purchase_plan(id,components)
  check(plan.valid and plan.cost==item.cost-sum,"component prices credited: "+id)
  prepare();p.global_position=Constants.FOUNT_B;p.gold=50000;p.inventory=components
  check(p.try_buy_item(id) and p.inventory.has(id),"real purchase combines components: "+id)
  var slot=p.inventory.find(id);var gold=p.gold
  check(p.try_sell_item(slot) and p.gold==gold+ItemData.sell_value(id),"new item sells at seventy percent: "+id)
 for hero in TankADItems.BUILDS:
  prepare();p.is_bot=true;p.gold=100000
  for id in ItemData.BUILD_ORDERS[hero]:check(p.try_buy_item(id),"full six-slot build completes: "+hero+" "+id)
  check(p.inventory.filter(func(id):return id!="").size()==6,"finished build has six slots: "+hero)
 prepare([], ["plated_steelcaps","randuin","deaths_dance"])
 game.deal_damage(p,enemy,100,"auto")
 check(is_equal_approx(10000-enemy.hp,65.),"boots Randuin and Dance apply bounded multiplicative attack defense")
 prepare([], ["bramble"]);game.deal_damage(p,enemy,100,"auto")
 check(p.buffs.has("grievous") and p.hp<1000.,"Bramble inflicts antiheal and reflects real damage")
 prepare([], ["force_nature"])
 for i in range(3):game.deal_damage(p,enemy,100,"magic")
 check(enemy.buffs.has("nature_guard"),"three magic hits enable adaptive defense")
 var hp=enemy.hp;var speed=enemy.effective_move_speed();game.deal_damage(p,enemy,100,"magic")
 check(hp-enemy.hp==85 and speed>enemy.move_speed*(1.+enemy.bonus_ms),"Nature guard reduces magic damage and increases speed")
 prepare([], ["jaksho"]);game.deal_damage(p,enemy,10,"auto");GameState.time=3.1
 check(ExpansionCombat.resist(enemy,p,"auto")==20 and ExpansionCombat.resist(enemy,p,"magic")==20,"Jak'Sho gains both resistances after sustained combat")
 enemy.buffs.clear();check(ExpansionCombat.resist(enemy,p,"auto")==0,"Jak'Sho resistance ends with combat state")
 for id in ["bami","sunfire","hollow_radiance"]:
  prepare([id]);TankADCombat.tick(p,.01)
  check(enemy.hp<10000.,"tank aura damages nearby enemy: "+id)
  hp=enemy.hp;TankADCombat.tick(p,.01);check(enemy.hp==hp,"burn aura respects one-second interval")
 prepare(["sunfire","hollow_radiance","bami"]);TankADCombat.tick(p,.01)
 check(10000-enemy.hp==34.,"burn items use only strongest aura")
 prepare(["unending_despair"]);TankADCombat.tick(p,.01)
 check(10000-enemy.hp==44 and p.hp==1022.,"drain heals from actual damage")
 hp=enemy.hp;TankADCombat.tick(p,.01);check(enemy.hp==hp,"drain respects five-second cooldown")
 prepare(["unending_despair"]);enemy.shield=1000.;TankADCombat.tick(p,.01)
 check(p.hp==1000.,"shield absorption grants no drain healing")
 prepare([], ["maw","sterak"]);enemy.hp=enemy.hp_max*.25
 ExpansionCombat.lifeline(enemy,"magic",p)
 check(enemy.shield==2500. and enemy.item_cds.maw==60. and enemy.item_cds.sterak==60.,"lifeline shields share a single trigger and cooldown")
 ExpansionCombat.lifeline(enemy,"magic",p);check(enemy.shield==2500.,"lifeline cannot stack repeatedly")
 prepare([], ["hexdrinker"]);enemy.hp=enemy.hp_max*.25
 ExpansionCombat.lifeline(enemy,"auto",p);check(enemy.shield==0.,"Hexdrinker ignores physical damage")
 ExpansionCombat.lifeline(enemy,"skill",p);check(enemy.shield==0.,"physical legacy skill does not trigger anti-mage shield")
 ExpansionCombat.lifeline(enemy,"magic",p);check(enemy.shield==1500.,"Hexdrinker shields against magic damage")
 prepare([], ["maw"]);enemy.hp=2200.
 game.deal_damage(p,enemy,2400.,"magic")
 check(not enemy.dead and enemy.hp==2200. and enemy.shield==100.,"Maw shields before an otherwise lethal magic burst")
 prepare(["locket"]);p.hp=500.;var ally=GameState.champions[1];ally.global_position=p.world_pos()+Vector2(80,0);ally.shield=0;ally.buffs.clear()
 ExpansionCombat.lifeline(p)
 check(p.shield==280. and ally.shield==280. and ally.buffs.has("locket_shield"),"Locket shields owner and nearby ally")
 p.shield+=100.;game.deal_damage(enemy,p,50.,"auto")
 check(p.buffs.locket_shield.shield==230.,"shield consumption tracks remaining item shield")
 ExpansionCombat.expire(p,"locket_shield")
 check(p.shield==100.,"item shield expiry preserves unrelated shields")
 prepare(["kraken"])
 for i in range(3):game.deal_damage(p,enemy,100.,"auto")
 check(10000-enemy.hp==375. and p.buffs.kraken.stacks==0,"Kraken deals bonus damage exactly every third attack")
 prepare(["mortal_reminder"]);game.deal_damage(p,enemy,100.,"auto")
 check(enemy.buffs.has("grievous"),"Mortal Reminder attacks reduce healing")
 enemy.buffs.clear();game.deal_damage(p,enemy,10.,"physical")
 check(enemy.buffs.has("grievous"),"Mortal Reminder physical spells reduce healing")
 prepare(["sundered_sky"]);game.deal_damage(p,enemy,100.,"auto")
 check(p.hp==1080. and enemy.hp==9870.,"Sundered Sky adds damage and heals on first champion hit")
 game.deal_damage(p,enemy,100.,"auto")
 check(p.hp==1080. and enemy.hp==9770.,"Sundered respects its target cooldown")
 prepare(["dead_mans"]);p.buffs.momentum={"time":60.,"stacks":100.,"x":p.world_pos().x,"y":p.world_pos().y}
 game.deal_damage(p,enemy,100.,"auto")
 check(enemy.hp==9850. and enemy.buffs.has("slow") and p.buffs.momentum.stacks==0.,"Momentum adds damage slows and spends its charge")
 prepare(["dead_mans"]);TankADCombat.tick(p,.05);p.global_position+=Vector2(20,0);TankADCombat.tick(p,.05)
 check(p.buffs.momentum.stacks>0,"movement builds Momentum")
 prepare(["shojin"])
 for i in range(4):game.deal_damage(p,enemy,100.,"physical")
 check(10000-enemy.hp==418. and p.buffs.shojin.stacks==3,"Shojin builds three stacks and boosts subsequent spells")
 hp=enemy.hp;game.deal_damage(p,enemy,100.,"item_physical")
 check(hp-enemy.hp==100.,"Shojin cannot amplify recursive item procs")
 prepare(["essence_reaver","trinity","sheen"])
 check(TankADCombat.spellblade_damage(p)==150.,"only strongest Spellblade applies")
 p.buffs.spellblade={"time":5.};p._perform_auto(enemy)
 check(enemy.hp==9750. and p.mp==140. and not p.buffs.has("spellblade"),"Essence mana restore and strongest Spellblade are consumed once")
 prepare(["titanic_hydra"]);var neighbor=GameState.champions[4];neighbor.global_position=enemy.world_pos()+Vector2(50,0);neighbor.hp_max=10000.;neighbor.hp=10000.;neighbor.bonus_armor=0.;neighbor.buffs.clear()
 game.deal_damage(p,enemy,100.,"auto")
 check(enemy.hp==9880. and neighbor.hp==9960.,"Titanic adds primary damage and max-HP cleave")
 prepare(["ravenous_hydra","tiamat"]);neighbor.global_position=enemy.world_pos()+Vector2(50,0);neighbor.hp=10000.;neighbor.bonus_armor=0.
 game.deal_damage(p,enemy,100.,"auto")
 check(neighbor.hp==9965.,"Hydra cleave does not stack with Tiamat")
 prepare(["deaths_dance","collector"]);enemy.hp=450.;var gold=p.gold
 game.deal_damage(p,enemy,100.,"auto")
 check(enemy.dead and p.hp==p.hp_max*.6,"Collector executes low HP and Dance heals champion kill")
 check(p.gold>=gold+325,"Collector adds twenty-five champion kill gold")
 prepare(["mercury_treads"]);p.stun=1.;p.buffs.silence={"time":1.};p.update_frame(.75)
 check(p.stun==0. and not p.buffs.has("silence"),"Mercury boots shorten stun and silence by twenty-five percent")
 prepare(["titanic_hydra","kraken","dead_mans","nashor"])
 var creep=game.MinionS.new();game.world_root.add_child(creep);creep.setup(1,"melee",Vector2(1180,270));GameState.minions.append(creep)
 creep.hp_max=1000.;creep.hp=1000.;p.bonus_ap=20.
 p.buffs.kraken={"time":5.,"target_id":creep.get_instance_id(),"stacks":2}
 p.buffs.momentum={"time":60.,"stacks":100.}
 var predicted=GameState.last_hit_damage(p,creep);p._perform_auto(creep)
 check(is_equal_approx(1000.-creep.hp,predicted),"farming indicator includes Titanic third-hit Momentum and Nashor damage")
 GameState.minions.erase(creep);creep.queue_free()
 var ui=game.hud.get_node("HudRoot");ui.toggle_shop();var shop=ui.shop_panel
 for category in ["tank","bruiser","marksman"]:
  shop.category=category;shop.rebuild_catalog()
  var expected=ItemData.ORDER.filter(func(id):return TankADItems.matches(id,category)).size()
  check(shop.grid.get_child_count()==expected and expected>=17,"shop path filter lists useful options: "+category)
 shop.category="tank";shop.selected="sunfire";shop.rebuild_catalog();await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/tank-ad-shop-v024.png")
 game._return_to_main_menu();game.queue_free();await get_tree().process_frame
 print("ITEM BUILDS: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
