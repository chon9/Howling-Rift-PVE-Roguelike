extends "res://tests/AllContentAudit.gd"
func near(value: float,wanted: float,label: String) -> void:check(absf(value-wanted)<.1,label+" got %.2f expected %.2f" % [value,wanted])
func fresh(key: String) -> void:
 reset(key,1)
 for c in GameState.champions:
  c.time_since_damage=10.;c.item_cds.clear();c.is_bot=false;c.buffs.clear();c.shield=0.
 hero.hp=hero.hp_max;hero.mp=hero.mp_max
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1;GameState.reset()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game.network_config={"blue":["soraka","ashe","garen"],"red":["garen","lux","darius"],"players":[{"peer":1,"slot":0,"name":"Test","spells":["flash","ignite"],"bonuses":{}}]};game._start_game("soraka")
 check(not Input.use_accumulated_input,"raw input is dispatched without frame accumulation")
 fresh("soraka");var ally=GameState.champions[1];var hp=hero.hp
 check(hero.try_cast_skill(1,ally.world_pos()),"Seren heals selected ally")
 near(ally.hp,185.,"W rank one heal");near(hp-hero.hp,hero.hp_max*.08,"W health cost")
 check(ally.assist_support.has(0),"healing gives support participation")
 hero.skill_cds[1]=0.;check(not hero.try_cast_skill(1,hero.world_pos()),"Seren W cannot self target")
 hero.hp=hero.hp_max*.02;check(not hero.try_cast_skill(1,ally.world_pos()),"cannot pay lethal health cost")
 fresh("soraka");enemy.global_position=hero.world_pos()+Vector2(130,0)
 check(hero.try_cast_skill(0,enemy.world_pos()),"Starfall casts");advance(.45);check(hero.buffs.has("rejuvenation"),"Starfall champion hit activates passive")
 hero.skill_cds[1]=0.;hp=hero.hp;hero.try_cast_skill(1,ally.world_pos());near(hp-hero.hp,hero.hp_max*.04,"Rejuvenation halves health cost")
 fresh("soraka");hero.try_cast_skill(2,enemy.world_pos());advance(.1);check(enemy.buffs.has("silence"),"Equinox silences occupants")
 advance(1.42);check(enemy.buffs.has("root"),"Equinox roots heroes who stayed")
 fresh("soraka");hero.try_cast_skill(2,enemy.world_pos());advance(.1);enemy.global_position+=Vector2(260,0);advance(1.5);check(not enemy.buffs.has("root"),"leaving Equinox avoids root")
 fresh("soraka");ally.global_position=Constants.FOUNT_B;hp=ally.hp;hero.try_cast_skill(3,hero.world_pos());near(ally.hp-hp,175.*1.35,"Wish reaches distant wounded ally")
 fresh("janna");var ally_ad=ally.ad;check(hero.try_cast_skill(2,ally.world_pos()),"Galea shields selected ally");near(ally.shield,80.,"rank one shield")
 var shield=ally.shield;hero.skill_cds[2]=0.;hero.try_cast_skill(2,ally.world_pos());near(ally.shield,shield,"refresh does not stack")
 check(ally.buffs.storm_shield.ad==10.,"Storm shield grants attack damage");near(ally.ad,ally_ad+10.,"shield improves actual AD for attacks and skills")
 game.deal_damage(enemy,ally,30.,"exec");advance(4.1);near(ally.shield,0.,"shield absorption and expiry remove remaining grant");near(ally.ad,ally_ad,"shield AD expires with shield")
 fresh("janna");hero.try_cast_skill(0,hero.world_pos()+Vector2.RIGHT*600);check(not NewHeroKits.recast_info(hero,0).is_empty(),"tornado has charge timer")
 advance(1.);hero.try_cast_skill(0,enemy.world_pos());check(not hero.buffs.has("gale_charge") and not GameState.projectiles.is_empty(),"Q second cast releases tornado")
 advance(.3);check(enemy.buffs.has("airborne"),"charged tornado knocks up")
 fresh("janna");hp=ally.hp;hero.try_cast_skill(3,hero.world_pos());advance(.55);check(ally.hp>hp and enemy.buffs.has("forced_motion")==false,"Monsoon heals after knockback")
 game._issue_champion_order(hero,{"type":"smart","point":hero.world_pos()+Vector2(0,120)});check(not hero.buffs.has("monsoon"),"movement cancels healing channel immediately")
 for id in SupportItems.KEYS:
  fresh("soraka");hero.inventory=[id];hero._apply_items();check(ShopArt.item_icon(id)!=null and ItemData.matches_category(id,"support"),id+" appears in support category")
  for stat in ItemData.ITEMS[id].stats:near(hero.get(stat),ItemData.ITEMS[id].stats[stat],id+" applies "+stat)
 fresh("soraka");hero.inventory=["forbidden_idol"];hero._apply_items();hp=ally.hp;SupportCombat.heal(hero,ally,100.);near(ally.hp-hp,108.,"heal power changes real healing")
 ally.buffs.grievous={"time":3.};hp=ally.hp;SupportCombat.heal(hero,ally,100.);near(ally.hp-hp,64.8,"grievous wounds reduces amplified healing")
 fresh("janna");hero.inventory=["forbidden_idol"];hero._apply_items();CombatEffects.shield(ally,"test_shield",100.,3.,hero);near(ally.shield,108.,"heal power changes real shields")
 fresh("soraka");hero.inventory=["ardent_censer","flowing_staff","dawn_bell","moonstone"];hero._apply_items();var ap=hero.bonus_ap
 var other=GameState.champions[2];other.global_position=ally.world_pos()+Vector2(20,0);other.hp=100.
 SupportCombat.heal(hero,ally,100.);check(ally.buffs.has("ardent") and ally.buffs.has("flowing") and ally.shield>0,"support items apply distinct boons")
 near(hero.bonus_ap,ap+20.,"Flowing staff adds actual AP");check(other.hp>100.,"Moonstone heals another ally")
 var again=other.hp;SupportCombat.heal(hero,ally,100.);near(other.hp,again,"Moonstone cooldown prevents proc loop");near(hero.bonus_ap,ap+20.,"Flowing refresh never stacks AP")
 advance(4.2);near(hero.bonus_ap,ap,"Flowing AP expires")
 SupportCombat.heal(hero,ally,100.);game._handle_death(enemy,hero);game._respawn_champion(hero);near(hero.bonus_ap,ap,"respawn removes temporary support AP")
 fresh("soraka");hero.inventory=["redemption"];hero._apply_items();ally.time_since_damage=0.;hp=ally.hp;advance(.8);check(ally.hp>hp and hero.item_cds.redemption>40.,"Redemption delayed rescue heals and uses cooldown")
 fresh("garen");hero.global_position=Vector2(1100,270);hero.is_bot=true;enemy.hp_max=1000.;enemy.hp=1000.;enemy.global_position=hero.world_pos()+Vector2(240,0)
 GameState.champions[1].global_position=hero.world_pos()+Vector2(0,80);GameState.champions[1].hp=GameState.champions[1].hp_max
 check(BotTactics.select_target(hero)==enemy,"healthy melee initiates before kill is guaranteed")
 var wounded=GameState.champions[4];wounded.global_position=hero.world_pos()+Vector2(280,70);wounded.hp=50.;wounded.hp_max=1000.
 check(BotTactics.select_target(hero)==wounded,"bot prioritizes wounded enemy over closer healthy hero")
 wounded.global_position=Constants.FOUNT_R;check(BotTactics.select_target(hero)!=wounded,"never chase into enemy fountain")
 fresh("ashe");hero.is_bot=true;hero.manual_move=Vector2.LEFT;hero.attack_target=enemy;enemy.global_position=hero.world_pos()+Vector2(100,0);hero.ai_tick=2.;var pos=hero.world_pos();hero.update_frame(.02);check(hero.queued_auto_target==enemy,"ranged attack begins during kite");near(hero.world_pos().distance_to(pos),0.,"windup anchors feet instead of sliding")
 fresh("garen");pos=hero.world_pos();game._issue_champion_order(hero,{"type":"smart","point":pos+Vector2(0,100)});var speed=hero.effective_move_speed();game._process(.1);near(hero.world_pos().distance_to(pos),speed*.1,"100ms frame keeps elapsed movement time")
 fresh("garen");ClientMovement.clear();pos=hero.world_pos();var order=ClientMovement.order(hero,{"type":"smart","point":pos+Vector2(0,100)})
 check(ClientMovement.tick(hero,.02,pos),"unacknowledged multiplayer order predicts immediately");check(hero.world_pos().distance_to(pos)>0,"prediction moves before any host packet")
 hero.last_order_sequence=order.sequence;hero.has_move_target=true;hero.move_target=order.point;ClientMovement.tick(hero,.02,hero.world_pos());check(ClientMovement.commands.is_empty(),"host acknowledgement retires predicted order")
 hero.stun=1.;check(not ClientMovement.tick(hero,.02,pos),"authoritative stun stops prediction")
 fresh("ashe");enemy.global_position=hero.world_pos()+Vector2(100,0);ClientMovement.clear();pos=hero.world_pos();ClientMovement.order(hero,{"type":"smart","point":enemy.world_pos()});ClientMovement.tick(hero,.02,pos);near(hero.world_pos().distance_to(pos),0.,"in-range attack prediction never walks backward")
 fresh("janna");ally.buffs.storm_shield={"time":4.,"shield":0.,"ad":100.};var raw=ally.ad;hp=enemy.hp;ally._perform_auto(enemy)
 for projectile in GameState.projectiles.duplicate():projectile.update_frame(.3)
 check(enemy.hp>=hp-raw*2.,"depleted shield cannot retain its attack bonus")
 fresh("lux");enemy.global_position=hero.world_pos()+Vector2(100,0);hp=enemy.hp
 game.spawn_projectile(hero,hero.world_pos(),Vector2.RIGHT,{"dmg":30.,"speed":6000.,"life":1.,"size":3.,"damage_type":"magic"});GameState.projectiles.back().update_frame(.03);check(enemy.hp<hp,"fast projectile hits swept path between frames")
 for key in SupportRoster.KEYS:
  fresh(key)
  for i in range(4):check(AbilityArt.icon_for(key,i)!=null and ChampionData.skill_description(key,i,hero).contains("AP"),key+" skill art and scaling")
  for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
   for frame in range(6):check(ActionSpriteArt.region("hero_"+key,action,frame).has_area(),key+" "+action+str(frame))
 print("SUPPORT / TACTICS: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
