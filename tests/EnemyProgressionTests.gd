extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL ENEMY PROGRESSION: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear();Progression.gear_stash.clear();Progression.gear_equipped.clear();Progression.difficulty=1
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("ashe");game.set_process(false)
 var player=GameState.player;var enemy=GameState.champions[3];var ally=GameState.champions[1]
 for champion in GameState.champions:champion.is_bot=false;champion.stop_actions()
 enemy.is_bot=true;ally.is_bot=true
 for death in range(1,15):
  game._respawn_champion(enemy);var before=enemy.gold;var cumulative=enemy.comeback_gold_awarded
  game._handle_death(player,enemy)
  var reward=0 if death<=10 else 600+(death-11)*250
  check(enemy.deaths==death and enemy.gold==before+reward,"enemy death %d grants expected comeback gold" % death)
  check(enemy.comeback_gold_awarded==cumulative+reward,"comeback total tracks awarded gold")
  game._handle_death(player,enemy)
  check(enemy.gold==before+reward and enemy.deaths==death,"duplicate death callback cannot grant additional gold")
 check(enemy.last_comeback_gold==1350,"each post-threshold defeat increases next grant")
 var balance=player.gold;player.deaths=20
 check(player.grant_comeback_gold()==0 and player.gold==balance,"human player receives no enemy bonus")
 ally.deaths=20;balance=ally.gold
 check(ally.grant_comeback_gold()==0 and ally.gold==balance,"allied AI receives no enemy bonus")
 game._respawn_champion(enemy);enemy.gold=6000;enemy.bot_buy_t=0.;enemy.bot_build_idx=0;enemy.inventory=["","","","","",""]
 enemy._bot_auto_buy(.01)
 check(enemy.bot_build_idx>=2 and enemy.inventory.any(func(item):return not item.is_empty()),"enemy spends comeback gold on multiple normal recipe items")
 check(enemy.gold<6000 and enemy.gold>=0,"AI purchases spend actual gold")
 var previous=0.
 for stage in range(1,100):
  var scale=Progression.scaling(stage)
  check(scale.experience>previous and scale.experience>=1.,"enemy XP multiplier increases at N%d" % stage);previous=scale.experience
 player.dead=false;enemy.dead=false;ally.dead=false
 player.level=3;player.xp=0.;enemy.level=3;enemy.xp=0.;ally.level=3;ally.xp=0.
 player.difficulty_stats=Progression.scaling(99);enemy.difficulty_stats=Progression.scaling(99);ally.difficulty_stats=Progression.scaling(99)
 player.grant_xp(30.);enemy.grant_xp(30.);ally.grant_xp(30.)
 check(is_equal_approx(player.xp,30.) and is_equal_approx(ally.xp,30.),"high-N XP bonus excludes players and friendly bots")
 check(is_equal_approx(enemy.xp,30.*Progression.scaling(99).experience),"enemy receives scaled XP from the shared grant path")
 enemy.dead=true;var xp=enemy.xp;enemy.grant_xp(100.)
 check(enemy.xp==xp,"dead enemy cannot gain XP")
 # Check every hero's skill cap, including unspent points, and actual stat recomputation.
 for key in ChampionData.CHAMPIONS:
  var champion=load("res://scripts/Champion.gd").new();game.world_root.add_child(champion);champion.setup(Constants.BLUE,key,false,"Level test")
  champion.level=18;champion.skill_points=15;champion.skill_ranks=[1,1,1,0];champion._apply_items();champion.hp=champion.hp_max;champion.mp=champion.mp_max
  var hp=champion.hp_max;var mp=champion.mp_max;var ad=champion.ad;var ap=champion.bonus_ap
  champion.grant_xp(Constants.xp_to_level(18))
  check(champion.level==19 and champion.skill_points==15,"level 19 preserves earlier unspent skill points for "+key)
  check(champion.level_bonus==Constants.VETERAN_STATS,"first post-skill level grants all four stats for "+key)
  check(champion.ad>ad+2.9 and champion.bonus_ap>=ap+5. and champion.hp_max>hp+44.9 and (champion.mp_max==200. if key in ["leesin","zed"] else champion.mp_max==0. if champion.hero.mp==0. else champion.mp_max>=mp+24.9),"veteran stats affect actual hero stats for "+key)
  for index in range(4):champion.skill_ranks[index]=champion.hero.skills[index].max
  champion.skill_points=0
  var needed=0.
  for lv in range(19,100):needed+=Constants.xp_to_level(lv)
  champion.grant_xp(needed+100000.)
  check(champion.level==100 and champion.xp==0 and champion.skill_points==0,"hero reaches level 100 without excess XP or skill points: "+key)
  for stat in Constants.VETERAN_STATS:check(is_equal_approx(champion.level_bonus[stat],Constants.VETERAN_STATS[stat]*82.),"all 82 veteran stat rewards persist: "+key+" / "+stat)
  var saved=champion.level_bonus.duplicate();champion.grant_xp(100000.)
  check(champion.level==100 and champion.level_bonus==saved,"level cap cannot grant more stat bonuses: "+key)
  champion._apply_items();champion.dead=true;champion.hp=0.;game._respawn_champion(champion)
  check(champion.level_bonus==saved and champion.hp>0,"respawn preserves level-100 stats: "+key)
  champion.queue_free()
 # Actual XP from a minion last hit follows the same multiplier.
 game._respawn_champion(enemy);enemy.level=3;enemy.xp=0.;enemy.difficulty_stats=Progression.scaling(50);enemy.global_position=Vector2(1400,270)
 var minion=load("res://scripts/Minion.gd").new();game.world_root.add_child(minion);minion.setup(Constants.BLUE,"melee",Vector2(1400,270),1.)
 game._handle_death(enemy,minion)
 var gained=enemy.xp
 for lv in range(3,enemy.level):gained+=Constants.xp_to_level(lv)
 check(is_equal_approx(gained,minion.xp_val*Constants.MINION_SOAK_XP_MULTIPLIER*Constants.LAST_HIT_XP_MULTIPLIER*Progression.scaling(50).experience),"real minion last-hit XP includes enemy difficulty multiplier across level-ups")
 player.level=100;player.xp=0.;game.hud.get_node("HudRoot").refresh(0.)
 check(game.hud.get_node("HudRoot").xp_bar.value==game.hud.get_node("HudRoot").xp_bar.max_value,"level-100 HUD XP bar is full")
 check(game.hud.get_node("HudRoot").xp_bar.tooltip_text.contains("MAX LEVEL"),"level cap replaces the next-level XP tooltip")
 if DisplayServer.get_name()!="headless":
  var ui=game.hud.get_node("HudRoot");player.skill_points=0
  player.difficulty_stats=Progression.scaling(1)
  for stat in Constants.VETERAN_STATS:player.level_bonus[stat]=Constants.VETERAN_STATS[stat]*82.
  for index in range(4):player.skill_ranks[index]=player.hero.skills[index].max
  player._apply_items();player.hp=player.hp_max;player.mp=player.mp_max
  ui.refresh(0.);ui.set_scoreboard_visible(true)
  await get_tree().process_frame;await get_tree().process_frame
  check(ui.player_level.position.x+ui.player_level.size.x<230.,"three-digit hero level fits before skill icons")
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/level-100-scoreboard-v041.png")
 var packet=LanSnapshot.encode();check(packet.champs[3].has("comeback_gold_awarded") and packet.champs[0].has("level_bonus"),"co-op snapshots include comeback and veteran progression")
 game._return_to_main_menu();game._start_game("ashe");game.set_process(false)
 check(GameState.player.level_bonus.is_empty() and GameState.champions[3].comeback_gold_awarded==0 and GameState.champions[3].deaths==0,"second match resets temporary bonuses and enemy comeback counters")
 print("ENEMY PROGRESSION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
