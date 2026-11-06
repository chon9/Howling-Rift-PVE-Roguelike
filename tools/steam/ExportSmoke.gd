extends SceneTree
var failures=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:failures+=1;push_error("FAIL EXPORTED: "+message)
func run() -> void:
 await process_frame
 var steam=root.get_node("SteamSession")
 var lan=root.get_node("LanSession")
 var state=root.get_node("GameState")
 root.get_node("Progression").persistent=false
 check(steam.available,"exported release DLL initializes Spacewar")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/manifest.json"))
 check(manifest is Dictionary and not manifest.is_empty(),"animation manifest ships in PCK")
 var game=load("res://scripts/Main.gd").new();root.add_child(game)
 check(game.menu_page=="main","export boots to main menu")
 var status_art=load("res://scripts/StatusArt.gd")
 for id in status_art.TYPES:check(status_art.texture(id)!=null and status_art.frame_rect(id,0.).has_area(),"exported status atlas "+id)
 check(game.hud.get_node("HudRoot").status_tray!=null,"export includes active-status hover strip")
 check(load("res://assets/audio/combat-v2/deadeye_charge.wav")!=null,"export contains original Deadeye charge audio")
 check(load("res://scripts/DeadeyeCue.gd")!=null,"export contains synchronized lock presentation")
 check(game.menu.find_child("AlliedBots",true,false)!=null,"export exposes allied-bot rule")
 check(game.graphics_quality.screen.material.shader!=null and game.graphics_quality.layer<game.hud.layer,"export contains world-only FXAA below HUD")
 check(load("res://scripts/WorldTextFont.gd").get_font().multichannel_signed_distance_field,"exported overhead font scales cleanly")
 check(game.graphics_quality.screen.material.get_shader_parameter("sharpness")==root.get_node("Progression").world_sharpness,"exported clarity settings configure world sharpening")
 var economy=load("res://scripts/Constants.gd")
 check(economy.PASSIVE_GOLD==.2 and economy.PASSIVE_XP==.2 and economy.HERO_KILL_GOLD==600 and economy.HERO_KILL_XP==320 and economy.MINION_GOLD_MULTIPLIER==2 and economy.MINION_SOAK_XP_MULTIPLIER==2.4,"export has exact requested passive and kill rates")
 check(load("res://scripts/CombatParticipation.gd").ASSIST_GOLD==75,"export has small assist gold reward")
 var updater=root.get_node("GameUpdates")
 check(FileAccess.file_exists("res://assets/updater/UpdateGame.ps1"),"exported updater helper ships")
 check(game.menu.find_child("PlayPvp",true,false)!=null,"exported main menu offers PvP")
 check(load("res://scripts/MatchRules.gd").capacity({"mode":"pvp","team_size":3})==6,"exported PvP supports six players")
 check(game.menu.find_child("UpdateAction",true,false)!=null,"exported menu shows update action")
 updater.auto_download=false;updater.check_latest()
 var check_deadline=Time.get_ticks_msec()+25000
 while updater.phase=="checking" and Time.get_ticks_msec()<check_deadline:await process_frame
 check(updater.checked and not updater.latest.is_empty(),"export checks real GitHub latest release")
 var profile=root.get_node("Progression");var loot=load("res://scripts/GearLoot.gd")
 var rng=RandomNumberGenerator.new();rng.seed=410
 var relic=loot.roll(25,rng,"export_test_relic")
 profile.gear_stash.append(relic)
 var slot="ring_1" if relic.slot=="ring" else relic.slot
 check(profile.equip_gear(relic.id,slot),"exported permanent relic equips")
 game._show_equipment();await process_frame;await process_frame
 check(game.menu.find_child("EquipmentScreen",true,false)!=null,"exported daily quest and equipment screen opens")
 check(load("res://scripts/GearArt.gd").icon_for(relic.base_id)!=null,"exported permanent gear art loads")
 var gear_art=load("res://scripts/GearArt.gd")
 for key in gear_art.KEYS:check(gear_art.icon_for(key)!=null and gear_art.icon_for(key).atlas.resource_path==gear_art.PATH,"exported dedicated equipment icon: "+key)
 check(relic.name.ends_with(loot.resolve_base(relic)[0]),"exported relic name matches depicted equipment")
 game._show_main_menu()
 check(steam.host_game()==OK,"export can request Steam lobby")
 var deadline=Time.get_ticks_msec()+27000
 while steam.operation=="host" and Time.get_ticks_msec()<deadline:await process_frame
 check(lan.is_host(),"release native Steam peer hosts real lobby")
 if lan.is_host():
  lan.ready_player("malphite",["flash","heal"],profile.bonuses())
  lan.start_match()
  var loaded_deadline=Time.get_ticks_msec()+25000
  while not state.running and Time.get_ticks_msec()<loaded_deadline:await process_frame
  check(state.running and not lan.loading_match,"export waits for asset warmup before simulation")
  check(game.match_loader!=null and not game.match_loader.resources.is_empty(),"export owns warmed match assets")
  check(state.started and state.champions.size()==6,"exported ARAM runs with all six heroes")
  check(state.player.animator.texture()!=null,"exported action sprites load")
  check(state.player.mp_max>0,"exported Granite has a real mana pool")
  var hook_owner=state.player
  var expansion=load("res://scripts/ExpansionKits.gd")
  check(expansion.cast(hook_owner,"thresh_q",hook_owner.world_pos()+Vector2(200,0)),"export can produce a hook")
  var hook_state=load("res://scripts/LanSnapshot.gd").encode().projectiles.back()
  check(hook_state.source.kind=="champion" and hook_state.hook_chain and hook_state.damage_type=="magic","exported hook snapshot carries its caster and skill presentation")
  for stat in profile.bonuses():check(is_equal_approx(state.player.permanent_bonus.get(stat,0.),profile.bonuses()[stat]),"exported co-op starts with equipped stat: "+stat)
  check(load("res://assets/vfx/expansion-projectiles-v1.png")!=null,"exported new projectile sheet loads")
  var kit_art=load("res://scripts/KitEffectArt.gd")
  var roster12=load("res://scripts/RosterExpansion12.gd");var actions12=load("res://scripts/ActionSpriteArt.gd");var icons12=load("res://scripts/AbilityArt.gd")
  check(root.get_node("ChampionData").CHAMPIONS.size()==32,"export has all thirty-two heroes")
  var passives=load("res://scripts/HeroPassives.gd");var portraits=load("res://scripts/HeroArt.gd")
  for hero in root.get_node("ChampionData").CHAMPIONS:
   check(passives.DATA.has(hero),"exported passive metadata "+hero)
   var portrait=portraits.texture_for(hero)
   check(portrait.filter_clip and is_equal_approx(portrait.get_width(),portrait.get_height()),"exported square portrait "+hero)
  check(load("res://scripts/SteamSession.gd").PROTOCOL=="14","export uses current network protocol")
  game.spawn_aoe(state.player,state.player.world_pos(),{"effect_id":"xerath_q","radius":250.,"footprint_kind":"capsule","footprint_width":30.,"effect_dir":Vector2.DOWN})
  var beam_snapshot=load("res://scripts/LanSnapshot.gd").encode().aoes.back()
  check(beam_snapshot.footprint_kind=="capsule" and beam_snapshot.footprint_width==30. and beam_snapshot.effect_dir==Vector2.DOWN,"exported beam snapshot preserves its collision footprint")
  check(load("res://scripts/SkillFootprint.gd").AREA_RADII.brand_w==140.,"exported skill geometry metadata loads")
  var combat_effects=load("res://scripts/CombatEffects.gd");var original_shield=state.player.shield
  combat_effects.shield(state.player,"export_audit_shield",100.,3.)
  check(is_equal_approx(state.player.shield,original_shield+100.),"exported timed shield preserves existing shield")
  load("res://scripts/ExpansionCombat.gd").expire(state.player,"export_audit_shield");state.player.buffs.erase("export_audit_shield")
  check(is_equal_approx(state.player.shield,original_shield),"exported timed shield expiry is independent")
  var passive_snapshot=load("res://scripts/LanSnapshot.gd").encode().champs[0]
  check(passive_snapshot.has("passive_state") and passive_snapshot.vision_teams.size()==2,"export serializes passive counters and team visibility")
  check(root.get_node("ChampionData").CHAMPIONS.vayne.skills[1].kind=="passive","exported Vesper W stays passive")
  for hero in roster12.KEYS:
   for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
    for frame in range(6):check(actions12.texture_for_frame("hero_"+hero,action,frame)!=null and actions12.region("hero_"+hero,action,frame).has_area(),"exported action "+hero+action+str(frame))
   for i in range(4):
    check(icons12.icon_for(hero,i)!=null,"exported new icon "+hero+str(i))
    var id=hero+"_"+["q","w","e","r"][i]
    check(kit_art.sheet(id)!=null and kit_art.region(id,3).has_area(),"exported new skill atlas "+id)
  var feedback_art=load("res://scripts/CombatFeedbackArt.gd")
  check(not game.sound_fx.announcer_clips.has("ally_slain") and not game.sound_fx.announcer_clips.has("victory_voice") and game.sound_fx.announcer_clips.values().all(func(clip):return clip.resource_path.begins_with("res://assets/audio/mobile-announcer-v1/")),"exported voice bank contains no TTS fallbacks")
  check(kit_art.sheet("veigar_e").resource_path.ends_with("vexel-ground-v2.png"),"exported Vexel uses corrected circular ground sheet")
  check(feedback_art.impact_texture()!=null and feedback_art.banner_texture()!=null,"exported impact and complete crest load")
  for tier in range(6):
   check(feedback_art.banner_texture(tier).resource_path.begins_with("res://assets/vfx/crests-v2/"),"exported separate complete crest loads")
  for hero in ["thresh","veigar","darius","malphite","morgana","vayne"]:
   for key in ["q","w","e","r"]:
    var id=hero+"_"+key
    check(kit_art.sheet(id)!=null and kit_art.region(id,3).has_area(),"exported dedicated skill atlas: "+id)
  root.get_node("Progression").smart_cast=false
  state.champions[3].global_position=state.player.world_pos()+Vector2(200,0)
  game._player_cast_skill(0)
  check(game.pending_skill==0,"exported normal cast enters targeting")
  var before=state.projectiles.size()
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  click.position=game.world_to_screen(state.champions[3].world_pos())
  game._unhandled_input(click)
  check(game.pending_skill==-1 and state.projectiles.size()==before+1,"exported normal cast confirms a real spell")
  check(root.get_node("ItemData").ITEMS.size()==84,"exported shop contains expanded tank and AD items")
  state.player.gold=10000
  check(state.player.try_buy_item("sunfire"),"exported tank item can be purchased")
  check(load("res://assets/ui/tank-ad-item-icons-v1.png")!=null,"exported new item art loads")
  state.player.gold=100000
  check(state.player.try_buy_item("training_hp") and state.player.consumable_counts.get("training_hp",0)==1,"exported stat consumable applies real match bonus")
  var gold=state.player.gold
  check(state.player.try_buy_item("training_hp") and state.player.gold==gold-10800,"exported repeat consumable uses increasing price")
  check(state.player.recall_duration==1.0,"exported recall uses one-second timer")
  var shop=game.hud.get_node("HudRoot").shop_panel
  shop.category="mage";shop.rebuild_catalog()
  check(shop.category_buttons.any(func(b):return b.get_meta("category")=="mage") and shop.grid.get_child_count()>=20,"exported Mage build filter lists complete mage options")
  check(load("res://assets/environment/frost-brush-v1.png")!=null,"exported painted brush asset loads")
  var crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/missile-crops-v1.json"))
  check(crops is Dictionary and crops.get("expansion",[]).size()==6,"exported projectile mapping metadata ships")
  check(game.lane_augments.AUGMENTS.size()==33,"exported game has expanded role upgrade pool")
  check(root.get_node("ItemData").upgrades_for("long_sword").has("maw"),"exported upgrade browser includes later recipe descendants")
  state.player.inventory[0]="long_sword"
  var ui=game.hud.get_node("HudRoot");ui.refresh(0)
  check(ui.kill_feed_frame.clip_contents,"exported kill feed clips to its bounds")
  game.announce_kill("penta_kill",state.player.team,state.player.hero.name)
  check(ui.kill_celebration.visible and ui.kill_celebration.row==4 and ui.kill_celebration.headline=="SAVAGE","exported Savage crest plays")
  check(game.sound_fx.announcer_voice.stream.resource_path.ends_with("mobile-announcer-v1/savage.wav"),"exported Savage recording plays")
  check(game.music.players.battle.stream is AudioStreamMP3 and game.music.players.battle.stream.loop,"exported supplied battle theme loops")
  ui.inv_slots[0].panel.mouse_entered.emit()
  check(root.get_node("ItemHover").panel!=null,"exported item hover renders an in-viewport tooltip")
  game.deal_damage(state.champions[3],state.player,state.player.hp+state.player.shield+100000,"exec")
  check(state.player.dead,"exported player death resolves safely")
  ui.inv_slots[0].panel.mouse_entered.emit()
  check(root.get_node("ItemHover").panel!=null,"exported item tooltip stays usable while dead")
  await create_timer(.2).timeout
  game._respawn_champion(state.player)
  check(not state.player.dead and state.player.hp==state.player.hp_max,"exported player respawns safely")
  var opponent=state.champions[3];var opponent_gold=opponent.gold
  opponent.deaths=10;game._respawn_champion(opponent);game._handle_death(state.player,opponent)
  check(opponent.last_comeback_gold==600 and opponent.gold==opponent_gold+600,"exported enemy death 11 grants comeback gold")
  state.player.level=18;state.player.xp=0.;state.player.skill_points=0
  for index in range(4):state.player.skill_ranks[index]=state.player.hero.skills[index].max
  state.player.grant_xp(root.get_node("Constants").xp_to_level(18))
  check(state.player.level==19 and state.player.level_bonus.get("bonus_ap",0.)==5. and state.player.skill_points==0,"exported level 19 grants veteran stats instead of skill points")
  game._end_game(0)
  check(profile.daily.claimed.size()>=2 and profile.last_drops.size()>=2,"exported match completion grants daily equipment rewards")
 game._return_to_main_menu()
 load("res://scripts/RiftMenus.gd").pvp(game)
 check(game.menu.find_child("PvpRoomSize",true,false)!=null,"exported PvP setup opens")
 var pvp_rules=load("res://scripts/MatchRules.gd")
 var people={1:{"peer":1,"name":"Host","hero":"ashe","spells":["heal","ghost"],"team":0,"ready":true,"bonuses":{"bonus_ad":9999}},2:{"peer":2,"name":"Rival","hero":"ashe","spells":["flash","ignite"],"team":1,"ready":true,"bonuses":{"bonus_hp":9999}}}
 var pvp_config=pvp_rules.build_config(people,pvp_rules.settings("pvp",1,false),99,false)
 game._start_network_match(pvp_config)
 var pvp_load_deadline=Time.get_ticks_msec()+20000
 while not state.running and Time.get_ticks_msec()<pvp_load_deadline:await process_frame
 check(state.running,"exported PvP asset warmup completes")
 if not state.running:quit(1);return
 check(state.is_pvp() and state.difficulty==1 and state.champions.filter(func(c):return c.roster_active).size()==2,"exported fair 1v1 roster starts")
 check(state.player.permanent_bonus.is_empty() and is_equal_approx(state.champions[0].ad,state.champions[3].ad) and is_equal_approx(state.champions[0].hp_max,state.champions[3].hp_max),"exported PvP strips permanent gear and submitted bonuses")
 var balance_before=profile.credits;var stash_before=profile.gear_stash.size();var claims_before=profile.daily.claimed.size()
 game._end_game(1)
 check(profile.credits==balance_before and profile.gear_stash.size()==stash_before and profile.daily.claimed.size()==claims_before,"exported PvP does not change PvE credits or loot")
 lan.leave();game._return_to_main_menu()
 game.network_config={"mode":"pve","allied_bots":true,"blue":["soraka","janna","ashe"],"red":["leesin","lux","darius"],"players":[{"peer":1,"slot":0,"name":"You","spells":["heal","ghost"],"bonuses":{}}]}
 await game._launch_game("soraka");game.set_process(false)
 var healer=state.champions[0];var guardian=state.champions[1];var ally=state.champions[2]
 for c in state.champions:c.is_bot=false;c.stop_actions()
 healer.global_position=Vector2(1200,270);guardian.global_position=Vector2(1230,270);ally.global_position=Vector2(1260,270);ally.hp=100.
 healer.inventory=["forbidden_idol","ardent_censer","","","",""];healer._apply_items()
 check(healer.try_cast_skill(1,ally.world_pos()) and ally.hp>100. and ally.buffs.has("ardent"),"exported Seren healing and support item procs work")
 check(guardian.try_cast_skill(2,ally.world_pos()) and ally.shield>0.,"exported Galea shield works")
 var support_art=load("res://scripts/SupportArt.gd");var support_kit_art=load("res://scripts/KitEffectArt.gd")
 for id in support_art.ROWS:check(support_kit_art.has_effect(id) and support_kit_art.region(id,3).has_area() and support_kit_art.sheet(id)!=null,"exported support spell/attack art "+id)
 check(load("res://scripts/LanSnapshot.gd").encode().champs[0].has("last_order_sequence"),"exported snapshots acknowledge predicted movement")
 check(ProjectSettings.get_setting("application/config/version")=="0.7.3","export has correct release version")
 check(load("res://scripts/UnitCollision.gd")!=null and state.clamp_walkable(state.structures[0].world_pos()).distance_to(state.structures[0].world_pos())>=state.structures[0].collision_radius,"export has solid buildings")
 check(load("res://scripts/EndScreen.gd")!=null and load("res://assets/shaders/view3d/hd2d_post.gdshader")!=null and load("res://assets/shaders/view3d/card_shadow.gdshader")!=null,"export ships the result screen and HD-2D shaders")
 check(game.view3d!=null and load("res://scripts/view3d/View3D.gd")!=null,"export builds the Rift3D view by default")
 for shader in ["unit_card","ground_deck","stone","fx_card_add","projectile_shape","glow_add"]:check(load("res://assets/shaders/view3d/"+shader+".gdshader")!=null,"exported 3D shader "+shader)
 check(ResourceLoader.exists("res://assets/shaders/view3d/view3d_common.gdshaderinc"),"export ships the shared 3D shader include")
 var stealer=load("res://scripts/BuildStealer.gd")
 state.match_mode="pve";healer.kills=15;healer.deaths=3;healer.owner_peer=1;healer.is_bot=false
 var blueprint=stealer.capture(healer,9,true)
 check(not blueprint.is_empty() and blueprint.stage==9,"export captures a dominant human build")
 profile.build_records=[blueprint]
 var echo_config={"mode":"pve","blue":["ashe","lux","garen"],"red":["leesin","thresh","vayne"]};stealer.assign(echo_config)
 check(echo_config.stolen_builds.size()==1 and distinct(echo_config.red).size()==3,"export assigns one Echo for one learned hero without duplicate enemies")
 var improved=blueprint.duplicate(true);improved.stage=99
 check(stealer.ranked([blueprint,improved]).size()==1 and stealer.ranked([blueprint,improved])[0].stage==99,"export keeps the better difficulty-weighted score per hero")
 var continuation=state.champions[3];var items=root.get_node("ItemData");var original=items.BUILD_ORDERS[continuation.hero_key]
 var partial=stealer.validate({"hero":continuation.hero_key,"stage":9,"kills":20,"deaths":2,"items":[original[0]],"skill_order":[{"index":0,"rank":2}]})
 continuation.is_bot=true;continuation.inventory=["","","","","",""];continuation.purchase_history.clear();continuation.gold=50000
 stealer.attach(continuation,partial,1)
 check(continuation._bot_buy_next() and continuation.purchase_history==[original[0]],"export follows the saved item first")
 check(continuation._bot_buy_next() and continuation.stolen_items_complete and continuation.purchase_history.size()==2,"export resumes original hero item purchases")
 continuation.skill_ranks=[1,1,1,0];continuation.level=4;continuation.skill_points=1;continuation._bot_spend_points()
 check(continuation.skill_ranks[0]==2,"export follows recorded skill rank first")
 continuation.level=5;continuation.skill_points=1;continuation._bot_spend_points()
 check(continuation.skill_ranks.reduce(func(total,value):return total+value,0)==5 and continuation.skill_points==0,"export keeps spending points after saved skill path ends")
 var library=load("res://scripts/BuildLibraryMenu.gd")
 game._return_to_main_menu();library.show(game)
 check(game.menu.has_node("BuildLibrary"),"exported archive browser is available")
 game.queue_free();await process_frame
 print("STEAM EXPORT SMOKE: ",failures," failures")
 quit(1 if failures else 0)

func distinct(values: Array) -> Dictionary:
 var seen={}
 for value in values:seen[value]=true
 return seen
