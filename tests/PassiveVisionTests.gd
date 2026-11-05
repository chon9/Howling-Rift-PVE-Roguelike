extends Node
var game
var hero
var enemy
var failures=0
var checks=0
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL PASSIVES: "+text)
func reset(key: String) -> void:
 for p in GameState.projectiles.duplicate():if is_instance_valid(p):p._destroy()
 for a in GameState.aoes.duplicate():if is_instance_valid(a):GameState.aoes.erase(a);a.queue_free()
 var old=GameState.champions[0];hero=game.ChampionS.new();game.world_root.add_child(hero);hero.setup(0,key,false,"Test");GameState.champions[0]=hero;GameState.player=hero;old.queue_free()
 hero.inventory=[];hero._apply_items();hero.skill_ranks=[1,1,1,1];hero.global_position=Vector2(1320,270);hero.hp=hero.hp_max*.5;hero.mp=hero.mp_max;hero.stop_actions();hero.is_bot=false
 enemy=GameState.champions[3];enemy.dead=false;enemy.is_targetable=true;enemy.buffs.clear();enemy.stun=0.;enemy.shield=0.;enemy.global_position=Vector2(1430,270);enemy.hp_max=10000.;enemy.hp=10000.;enemy.bonus_armor=0.;enemy.base_mr=0.;enemy.bonus_mr=0.;enemy.hero_key="garen";enemy.stop_actions()
 for c in GameState.champions:
  if c!=hero and c!=enemy:c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R;c.stop_actions();c.is_bot=false
func hit(kind: String="auto",id: String="",value: float=100.) -> void:game.deal_damage(hero,enemy,value,kind,id)
func step(seconds: float) -> void:
 for i in range(int(ceil(seconds/.02))):
  GameState.time+=.02;hero.update_frame(.02)
  for p in GameState.projectiles.duplicate():if is_instance_valid(p) and not p.is_queued_for_deletion():p.update_frame(.02)
  for a in GameState.aoes.duplicate():if is_instance_valid(a) and not a.is_queued_for_deletion():a.update_frame(.02)
func creep(subkind: String="melee"):
 var m=game.MinionS.new();game.world_root.add_child(m);m.setup(1,subkind,hero.world_pos()+Vector2(30,0));GameState.minions.append(m);return m
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;GameState.reset();game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("xinzhao")
 for key in ChampionData.CHAMPIONS:
  reset(key)
  check(ChampionData.CHAMPIONS[key].has("passive") and HeroPassives.DATA.has(key),key+" passive metadata")
  check(not HeroPassives.description(key,hero).is_empty(),key+" live tooltip")
  var portrait=HeroArt.texture_for(key)
  check(is_equal_approx(portrait.get_width(),portrait.get_height()) and portrait.filter_clip,key+" square clipped portrait")
  test_passive(key)
 reset("xinzhao")
 hero.try_cast_skill(0,hero.world_pos())
 for n in range(3):
  hero._perform_auto(enemy)
  check(enemy.buffs.has("airborne")== (n==2),"Lancer Q hit "+str(n+1)+" airborne only third")
 check(hero.skill_cds[1]==0. and hero.passive_state.determination==0,"Q refunds and passive independent cycles")
 enemy.buffs.clear();enemy.stun=0.;enemy.global_position=hero.world_pos()+Vector2(300,0)
 var hp=enemy.hp;check(hero.try_cast_skill(2,enemy.world_pos()),"Lancer E casts")
 check(enemy.hp==hp and hero.is_dashing,"E damage waits for arrival")
 step(.35)
 check(enemy.hp<hp and enemy.buffs.has("slow"),"E arrival damages and slows")
 check(GameState.aoes.any(func(a):return a.effect_id=="xinzhao_e" and a.damage_type=="magic"),"E impact magic damage and directional sheet")
 # Repeat attack cycles after Q expires: passive never knocks up independently.
 hero.buffs.clear();enemy.buffs.clear();enemy.stun=0.
 for n in range(6):hero._perform_auto(enemy)
 check(not enemy.buffs.has("airborne") and enemy.stun==0.,"Determination alone does not knock up")
 reset("lux");enemy.global_position=BrushVision.PATCHES[2].get_center()
 hero.global_position=Vector2(1300,270);enemy.brush_revealed_until=-1.;GameState.time+=3.
 for c in GameState.champions:
  if c.team==hero.team and c!=hero:c.global_position=Constants.FOUNT_B
 check(not BrushVision.visible_to(enemy,0),"enemy hidden in distant brush")
 var packet=LanSnapshot.encode();check(not packet.champs[3].vision_teams[0] and packet.champs[3].vision_teams[1],"host encodes team visibility")
 hero.global_position=enemy.world_pos()+Vector2(30,0)
 check(BrushVision.visible_to(enemy,0),"enter brush reveals enemy")
 hero.global_position=Vector2(1300,270);BrushVision.reveal(enemy,.5)
 check(BrushVision.visible_to(enemy,0),"attack reveals briefly");GameState.time+=.6
 check(not BrushVision.visible_to(enemy,0),"reveal expires")
 packet=LanSnapshot.encode();check(packet.champs[0].passive_state==hero.passive_state,"passive counters serialize")
 HeroControl.airborne(enemy,1.);check(packet.champs[3].buffs!=LanSnapshot.encode().champs[3].buffs,"airborne replicates in buffs")
 print("PASSIVES/VISION: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
func test_passive(key: String) -> void:
 match key:
  "lux":
   hit("skill","lux_q");check(enemy.buffs.has("illumination"),"Solara marks spell")
   var hp=enemy.hp;hit();check(hp-enemy.hp>100. and not enemy.buffs.has("illumination"),"Solara auto consumes mark")
   hit("skill","lux_e");hp=enemy.hp;hit("skill","lux_r");check(hp-enemy.hp>100. and enemy.buffs.has("illumination"),"R triggers and refreshes")
  "ahri":
   var hp=hero.hp
   for i in range(9):game._handle_death(hero,creep())
   check(hero.hp>hp and hero.passive_state.essence==0,"Nyra nine kills heal")
  "ezreal":
   hero.skill_cds=[10.,10.,10.,10.]
   for i in range(7):hit("skill","ezreal_q")
   check(hero.buffs.spell_force.stacks==5 and hero.effective_atk_spd()>hero.atk_spd*1.4,"Kael capped five AS stacks")
   check(hero.skill_cds[3]==0.,"Mystic hits refund CDs")
  "ashe":
   hit();check(enemy.buffs.has("frost") and enemy.buffs.has("slow"),"Skadi frosts auto")
   check(HeroPassives.auto_bonus(hero,enemy)>0.,"frosted target bonus")
  "annie":
   check(hero.try_cast_skill(0,enemy.world_pos()),"Ember offensive ready cast");check(GameState.projectiles.back().stun_time>=1.25 and hero.passive_state.pyromania==0,"initial pyromania consumed into projectile")
   for i in range(4):hero.skill_cds[2]=0.;hero.try_cast_skill(2,hero.world_pos())
   check(hero.passive_state.pyromania==4,"four shields prime next offensive spell")
   hero.skill_cds[2]=0.;hero.try_cast_skill(2,hero.world_pos());check(hero.passive_state.pyromania==4,"shield preserves stun readiness")
   hero.mp=0.;hero.skill_cds[0]=0.;check(not hero.try_cast_skill(0,enemy.world_pos()) and hero.passive_state.pyromania==4,"failed cast preserves Pyromania readiness")
  "garen":
   var hp=hero.hp;HeroPassives.tick(hero,1.);check(hero.hp>hp,"Bastion out-of-combat regen")
   hero.passive_state.perseverance_hit=GameState.time;hp=hero.hp;HeroPassives.tick(hero,1.);check(hero.hp==hp,"combat stops perseverance")
  "yasuo":
   hero.passive_state.flow=100.;var hp=hero.hp;game.deal_damage(enemy,hero,100,"auto");check(hero.hp==hp and hero.passive_state.flow==0.,"Kaze flow shield absorbs triggering hit")
   hero.bonus_crit=.4;check(HeroPassives.critical_chance(hero)==1.,"Kaze amplified crit")
  "leesin":
   hero.mp=50.;hero.try_cast_skill(2,enemy.world_pos());check(hero.buffs.flurry.hits==2 and hero.mp_max==200.,"Rensa two flurry and energy pool")
   var mp=hero.mp;hit();hit();check(hero.mp>=mp+30. and not hero.buffs.has("flurry"),"Flurry restores 20 then 10")
  "zed":
   enemy.hp=4500.;var hp=enemy.hp;hit();check(hp-enemy.hp>600.,"Shade weak-target bonus")
   hp=enemy.hp;hit();check(hp-enemy.hp==100.,"per-target contempt lock")
  "jinx":
   hit();game._handle_death(hero,enemy);check(hero.buffs.has("excited") and hero.effective_atk_spd()>hero.atk_spd,"Rixa takedown excitement")
  "katarina":
   hero.skill_cds=[20.,20.,20.,20.];hit();game._handle_death(hero,enemy);check(hero.skill_cds[0]==5. and hero.skill_cds[3]==5.,"Vespera cooldown reset")
   enemy.dead=false;enemy.is_targetable=true;enemy.hp=10000.;HeroPassives.on_cast(hero,1);var hp=enemy.hp;step(.65);check(enemy.hp<hp and hero.skill_cds[2]<5.,"dagger pickup slash and E refund")
  "kayle":
   check(hero.auto_type=="melee","Seraph melee initially")
   for i in range(5):hit()
   check(hero.effective_atk_spd()>hero.atk_spd*1.2,"Ascent attack speed stacks")
   hero.level=16;check(HeroPassives.attack_range(hero,enemy)>hero.atk_range and HeroPassives.move_speed(hero)>1.,"final exaltation range and speed")
   hit();check(GameState.projectiles.any(func(p):return p.effect_id=="kayle_wave" and p.damage_type=="passive_magic"),"exalted auto launches traveling fire wave")
  "darius":
   for i in range(5):hit()
   var b=enemy.buffs["hemorrhage_0"];check(b.stacks==5 and hero.buffs.has("noxian_might"),"Rook five stacks rage")
   var hp=enemy.hp;HeroPassives.tick(enemy,1.);check(enemy.hp<hp and b.stacks==5,"bleed ticks without restacking")
   enemy.hp=1.;hero.skill_cds[3]=0.;hero.mp=hero.mp_max
   check(hero.try_cast_skill(3,enemy.world_pos()) and enemy.dead and hero.skill_cds[3]==0.,"killing R refunds its actual cast cooldown")
  "malphite":
   HeroPassives.tick(hero,.02);check(hero.shield==hero.hp_max*.1,"Granite ten-percent shield")
   game.deal_damage(enemy,hero,hero.shield*.5,"auto");var shield=hero.shield;HeroPassives.tick(hero,1.);check(hero.shield==shield,"shield recharge delayed after absorbed damage")
  "veigar":
   var ap=hero.bonus_ap;hit("magic","veigar_q");check(hero.bonus_ap==ap+1.,"Vexel hero spell hit stacks AP")
   game._handle_death(hero,enemy);check(hero.bonus_ap==ap+6.,"Vexel takedown five AP")
   var m=creep("siege");m.hp=1.;ap=hero.bonus_ap;game.deal_damage(hero,m,50,"magic","veigar_q");check(hero.bonus_ap==ap+2.,"Q siege last hit earns two AP")
  "morgana":
   var hp=hero.hp;hit("magic","morgana_q");check(is_equal_approx(hero.hp-hp,20.),"Noctra heals actual spell damage")
   enemy.shield=1000.;hp=hero.hp;hit("magic","morgana_q");check(hero.hp==hp,"no siphon from shield-only damage")
  "vayne":
   hero.has_move_target=true;hero.move_target=enemy.world_pos();check(HeroPassives.move_speed(hero)>1.,"Vesper hunts toward visible champion")
   hero.move_target=hero.world_pos()-Vector2(200,0);check(HeroPassives.move_speed(hero)==1.,"no chase speed running away")
   ExpansionKits.tick(hero,.02);check(hero.buffs.silver.time>9000.,"W learned always active")
  "thresh":
   game._handle_death(hero,creep("siege"));check(GameState.aoes.any(func(a):return a.zone_kind=="soul"),"Warden souls drop")
   step(.04);check(hero.passive_state.souls==1 and hero.bonus_ap==.75 and hero.bonus_armor==.75,"collect soul grants AP and armor")
  "leona":
   hit("magic","leona_e");var hp=enemy.hp;hit();check(enemy.buffs.has("sunlight"),"Aegis own hit does not consume sunlight")
   game.deal_damage(GameState.champions[1],enemy,10,"auto");check(not enemy.buffs.has("sunlight") and enemy.hp<hp-110.,"ally champion consumes sunlight")
  "blitzcrank":
   hero.hp=hero.hp_max*.35;var hp=hero.hp;game.deal_damage(enemy,hero,hero.hp_max*.1,"exec");check(hero.hp==hp and hero.item_cds.mana_barrier>0.,"Bolt barrier protects threshold-crossing hit")
  "renekton":
   hero.hp=hero.hp_max*.4;hit();check(hero.buffs.fury.value==7.5,"Saur low-health increased Fury")
  "xinzhao":
   var hp=hero.hp;hit();hit();hit();check(hero.hp>hp and hero.passive_state.determination==0,"Lancer third-attack passive heal")
   hero.passive_state.determination=2;check(HeroPassives.auto_bonus(hero,enemy)>0.,"Determination third bonus damage")
  "riven":
   hero.try_cast_skill(0,enemy.world_pos());hero.try_cast_skill(0,enemy.world_pos());check(hero.buffs.runes.stacks==2,"each Riftblade Q cast primes rune")
   hero._perform_auto(enemy);check(hero.buffs.runes.stacks==1,"auto consumes one rune")
  "fiora":
   var hp=hero.hp;enemy.buffs.vital_0={"time":8.,"side":2,"src":hero};hit();check(hero.hp>hp and enemy.buffs.vital_0.side==3,"Duelia matching side heals and rotates owned vital")
  "caitlyn":
   hero.passive_state.headshot=5;check(Roster12Combat.before_auto(hero,enemy)>0. and hero.passive_state.headshot==0,"Caliber sixth headshot")
   hero.passive_state.headshot=2;enemy.buffs.rifle_mark={"time":4.,"src":hero};check(HeroPassives.attack_range(hero,enemy)==hero.atk_range*2.,"marked target doubled range")
   Roster12Combat.before_auto(hero,enemy);check(hero.passive_state.headshot==3,"marked headshot preserves ordinary counter")
  "lucian":
   hero.try_cast_skill(2,enemy.world_pos());check(hero.buffs.has("lightslinger"),"Solstice primes second shot")
   hit()
   check(GameState.projectiles.any(func(p):return p.damage_type=="secondary_auto"),"Lightslinger creates visible second projectile")
   HeroPassives.support(GameState.champions[1],hero);check(hero.buffs.has("vigilance"),"allied support grants Vigilance")
   hero.buffs.vigilance={"time":6.,"hits":2};var hp=enemy.hp;hit();check(enemy.hp<hp-100. and hero.buffs.vigilance.hits==1,"Vigilance magic damage charges")
  "sivir":hit();check(hero.buffs.has("fleet_foot") and HeroPassives.move_speed(hero)>1.,"Zephyr fleet of foot")
  "brand":
   hit("magic","brand_q");check(enemy.buffs.blaze.stacks==1,"Pyre spell Blaze")
   hero.mp=0.;game._handle_death(hero,enemy);check(hero.mp>0.,"burned-unit mana refund")
  "syndra":
   HeroPassives.splinters(hero,40);check(hero.passive_state.q_charges==2,"Umbra forty unlocks two Q charges")
   check(hero.try_cast_skill(0,enemy.world_pos()) and hero.skill_cds[0]==0.,"first charge leaves Q available")
   check(hero.try_cast_skill(0,enemy.world_pos()) and hero.skill_cds[0]>0.,"second charge starts recharge")
   hero.dead=true;var cd=hero.skill_cds[0];hero.tick_cooldowns(.1)
   check(is_equal_approx(hero.skill_cds[0],cd-.1) and is_equal_approx(hero.skill_cds[0],hero.passive_state.q_recharge),"dead Q recharge decrements exactly once")
   hero.tick_cooldowns(cd);check(hero.passive_state.q_charges==1 and hero.skill_cds[0]==0.,"Q recovers charge while dead")
   hero.dead=false
   HeroPassives.splinters(hero,80);var ap=hero.bonus_ap;hero.run_bonus.bonus_ap=100.;hero._apply_items();check(is_equal_approx(hero.bonus_ap,115.) and hero.passive_state.splinters==120,"120 grants multiplicative AP")
  "xerath":
   hero.mp=0.;hit();var mana=hero.mp;hit();check(mana>0. and hero.mp==mana,"Arclight mana surge respects cooldown")
   var cd=hero.item_cds.arcane_mana;game._handle_death(hero,creep());check(hero.item_cds.arcane_mana==cd-1.,"last hit reduces Mana Surge CD")
