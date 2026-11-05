extends Node
var checks = 0
var failures = 0
var game
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL CORE PVE: "+message)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("garen")
 var p=GameState.player
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 check(ItemData.matches_category("sterak","ad") and ItemData.matches_category("sterak","hp"),"old hybrid item appears under attack and health")
 check(ItemData.matches_category("maw","ad") and ItemData.matches_category("maw","def"),"new hybrid appears under attack and defense")
 check(ItemData.matches_category("banshee","ap") and ItemData.matches_category("banshee","def"),"magic defense hybrid uses both filters")
 check(ItemData.matches_category("sunfire","hp") and ItemData.matches_category("sunfire","def"),"tank health and armor categories agree")
 var credits=Progression.credits
 p.gold=1000000;p.inventory=["warmog","thornmail","infinity_edge","bloodthirster","berserker_greaves","spirit_visage"];p._apply_items()
 var inventory=p.inventory.duplicate()
 for id in MatchTraining.KEYS:
  var stats=ItemData.ITEMS[id].stats
  var stat=stats.keys()[0];var old=float(p.get(stat));var cost=MatchTraining.price(id,p.consumable_counts)
  check(cost==8000 and ItemData.purchase_plan(id,p.inventory,p.consumable_counts).valid,"full inventory accepts first elixir: "+id)
  var before=p.gold
  check(p.try_buy_item(id) and p.gold==before-cost and p.inventory==inventory,"consumption charges gold without using slots: "+id)
  check(is_equal_approx(float(p.get(stat)),old+stats[stat]),"elixir modifies actual combat stats: "+id)
  check(MatchTraining.price(id,p.consumable_counts)==10800,"repeat cost rises by thirty-five percent: "+id)
  before=p.gold
  check(p.try_buy_item(id) and p.gold==before-10800 and p.consumable_counts[id]==2,"second purchase stacks and uses current price: "+id)
  check(ShopArt.item_icon(id)!=null,"consumable icon loads: "+id)
 check(Progression.credits==credits,"match training never spends profile credits")
 p.gold=0;check(not p.try_buy_item("training_ad") and p.consumable_counts.training_ad==2,"insufficient gold cannot add stats")
 p.global_position=Vector2(1300,270);p.gold=100000
 check(not p.try_buy_item("training_ad"),"consumables require shop access")
 p.dead=true;p.hp=0;var bonus=p.consumable_bonus.duplicate();p._apply_items()
 check(p.hp==0 and p.consumable_bonus==bonus,"death does not clear match training or revive player")
 p.dead=false;p.global_position=Constants.FOUNT_B
 var packet=LanSnapshot.encode()
 check(packet.champs[0].consumable_counts==p.consumable_counts and packet.champs[0].consumable_bonus==bonus,"network state includes training counts and bonuses")
 p.mp_max=100;p.hp=10;p.mp=0;p._fountain_recovery(.01)
 check(p.hp==p.hp_max and p.mp==p.mp_max,"safe fountain refills health and mana immediately")
 var enemy=GameState.champions[3];enemy.global_position=Constants.FOUNT_B+Vector2(300,0)
 p.hp=10;p.mp=0;p._fountain_recovery(.1)
 check(is_equal_approx(p.hp,22) and is_equal_approx(p.mp,8),"contested fountain retains existing gradual recovery")
 enemy.dead=true;p._fountain_recovery(.01);check(p.hp==p.hp_max,"dead enemy does not contest fountain")
 enemy.dead=false;enemy.global_position=Constants.FOUNT_R
 var m=game.MinionS.new();game.world_root.add_child(m);m.setup(1,"melee",Constants.FOUNT_B+Vector2(400,0));GameState.minions.append(m)
 p.hp=10;p._fountain_recovery(.1);check(is_equal_approx(p.hp,22),"hostile minion also contests fountain")
 m.dead=true;p.global_position=Vector2(1000,270);p.hp=10;p.mp=0;p.start_recall();p.update_frame(.9)
 check(p.recall_time>=0 and p.world_pos().x>900,"one-second recall does not finish early")
 p.update_frame(.11);check(p.recall_time<0 and p.world_pos()==Constants.FOUNT_B and p.hp==p.hp_max and p.mp==p.mp_max,"recall arrival immediately refills a clear fountain")
 p.global_position=Vector2(1000,270);p.start_recall();game.deal_damage(enemy,p,10,"auto")
 check(p.recall_time<0,"incoming damage still cancels short recall")
 for stage in [1,10,50,99]:
  GameState.difficulty=stage
  var tower=game.StructureS.new();game.world_root.add_child(tower);tower.setup(1,"turret",Vector2(1800,270))
  var scale=Progression.scaling(stage)
  check(is_equal_approx(tower.hp_max,3000*scale.structure_health) and is_equal_approx(tower.atk_dmg,160*scale.structure_damage),"actual tower applies N scaling: "+str(stage))
  if stage==99:check(tower.hp_max>160000 and tower.atk_dmg>2400,"highest difficulty towers are substantially stronger")
  tower.queue_free()
 GameState.difficulty=1
 var tower
 for s in GameState.structures:
  if s.team==1 and s.variant=="outer":tower=s
 p.consumable_bonus.clear();p.consumable_counts.clear();p.inventory=["","","","","",""];p._apply_items();p.hp=p.hp_max;p.is_bot=true
 p.global_position=tower.world_pos()-Vector2(360,0);enemy.global_position=tower.world_pos()-Vector2(100,0);enemy.hp=50
 check(not BotSafety.dive_viable(p,enemy),"weak bot refuses a suicidal tower dive")
 p.hp_max=6500;p.hp=6500;p.bonus_armor=180;p.ad=350
 check(BotSafety.dive_viable(p,enemy) and p._safe_pursuit(enemy),"durable strong bot accepts a survivable finishing dive")
 BotSafety.commit_dive(p,enemy);var deadline=p.dive_until
 check(BotSafety.retreat_from(p)==null and p.dive_until==deadline,"approaching tower does not reset the fixed dive deadline")
 p.global_position=tower.world_pos()-Vector2(120,0);tower.provoke(p)
 check(BotSafety.retreat_from(p)==null,"committed safe dive continues despite tower aggro")
 BotSafety.commit_dive(p,enemy);check(p.dive_until==deadline,"dive deadline cannot be renewed each decision")
 enemy.dead=true;check(BotSafety.retreat_from(p)==tower,"bot retreats immediately after the kill")
 enemy.dead=false;GameState.time=deadline+.1
 check(BotSafety.retreat_from(p)==tower,"failed dive times out and retreats")
 p.global_position=BotSafety.waiting_point(p,tower)
 check(BotSafety.retreat_from(p)==null and p.dive_until<0,"exit clears dive state outside tower range")
 GameState.time=0;p.hp=6500;p.global_position=tower.world_pos()-Vector2(360,0);tower.atk_dmg=2400
 check(not BotSafety.dive_viable(p,enemy),"even durable bot refuses overwhelming high-N tower damage")
 game._start_game("garen")
 check(GameState.player.consumable_counts.is_empty() and GameState.player.consumable_bonus.is_empty(),"next match resets all purchased match stats")
 game.set_fullscreen(false)
 var shop=game.hud.get_node("HudRoot").shop_panel
 shop.player=GameState.player;shop.category="consumable";shop.selected="training_hp";shop.rebuild_catalog();shop.show()
 check(shop.grid.get_child_count()==6 and shop.detail.text.contains("Next cost: 8000g"),"shop shows six consumables and real next price")
 shop.category="mage";shop.selected="liandry";shop.rebuild_catalog()
 var expected=ItemData.ORDER.filter(func(id):return ItemData.matches_mage_build(id)).size()
 check(shop.category_buttons.any(func(b):return b.get_meta("category")=="mage"),"Mage builds has its own visible filter")
 check(shop.grid.get_child_count()==expected and expected>=20,"Mage builds contains finished items and useful components")
 for id in ["ludens","rabadon","archangel","liandry","morello","void_staff","banshee","nashor","sorcerer_shoes","null_mantle"]:
  check(ItemData.matches_mage_build(id),"old and expanded mage build option included: "+id)
 check(not ItemData.matches_mage_build("infinity_edge") and not ItemData.matches_mage_build("training_ap"),"mage gear excludes unrelated AD items and separate consumables")
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/mage-shop-v026.png")
 print("CORE PVE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
