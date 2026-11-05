extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL EQUIPMENT: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 var path="res://tests/equipment-isolated-v040.cfg"
 var profile=load("res://scripts/Progression.gd").new();profile.save_path=path;profile.persistent=true;profile.clock_date="2026-10-10";profile.loot_rng.seed=4567
 profile.credits=1000;profile.levels={"might":2};profile.refresh_daily()
 profile.begin_match();profile.complete_match(false,40,12,20,100)
 check(profile.daily.progress.matches==0 and profile.gear_stash.is_empty(),"short defeat cannot farm daily gear")
 profile.begin_match();profile.complete_match(true,400,6,20,40)
 check(profile.daily.claimed.size()==2 and profile.gear_stash.size()==2,"first victory grants exactly two completed quest drops")
 var balance=profile.credits;var first=profile.gear_stash.duplicate(true)
 profile.complete_match(true,400,6,99,100)
 check(profile.credits==balance and profile.gear_stash==first,"duplicate completion cannot reroll or pay again")
 profile.begin_match();profile.complete_match(false,300,6,22,40)
 check(profile.daily.claimed.size()==4 and profile.gear_stash.size()==4,"kills and last hits accumulate across completed runs")
 profile.begin_match();profile.complete_match(false,300,2,24,10)
 check(profile.daily.claimed.size()==5 and profile.gear_stash.size()==5,"third completion finishes fifth daily quest")
 for i in range(8):profile.begin_match();profile.complete_match(true,300,30,99,200)
 check(profile.gear_stash.size()==5 and profile.daily.claimed.size()==5,"unlimited completed runs still grant at most five drops per day")
 for item in profile.gear_stash:check(item.level>=18 and item.level<=24,"quest item levels use the difficulty when completed")
 var first_item=profile.gear_stash[0];var slot="ring_1" if first_item.slot=="ring" else first_item.slot
 check(profile.equip_gear(first_item.id,slot),"valid item equips to compatible slot")
 check(not profile.equip_gear(first_item.id,"ring_2" if first_item.slot!="ring" else "weapon"),"wrong equipment category is rejected")
 var saved=profile.bonuses()
 check(saved.bonus_ad>=6. and profile.gear_equipped.size()==1,"credit upgrades add to equipment bonuses")
 var restored=load("res://scripts/Progression.gd").new();restored.save_path=path;restored.clock_date="2026-10-10";restored.load_profile()
 var rolls_match=restored.gear_stash.size()==profile.gear_stash.size()
 for item in profile.gear_stash:
  var copy=restored.gear_item(item.id)
  check(not copy.is_empty() and copy.name==item.name and copy.level==item.level and copy.rarity==item.rarity,"saved item identity and level are preserved")
  if copy.is_empty():rolls_match=false;continue
  for stat in item.stats:rolls_match=rolls_match and is_equal_approx(copy.stats.get(stat,0.),item.stats[stat])
 for stat in saved:rolls_match=rolls_match and is_equal_approx(restored.bonuses().get(stat,0.),saved[stat])
 check(rolls_match and restored.gear_equipped==profile.gear_equipped,"rolled stats and equipped bonuses survive disk reload at their saved precision")
 check(restored.daily==profile.daily and restored.credits==profile.credits and restored.levels.might==2,"daily limit and old permanent credits survive reload")
 restored.begin_match();restored.complete_match(true,400,30,99,200)
 check(restored.gear_stash.size()==5,"restarting the game does not refresh today's drops")
 restored.clock_date="2026-10-09";restored.refresh_daily()
 check(restored.daily.claimed.size()==5,"moving clock backward cannot reopen completed day")
 restored.clock_date="2026-10-11";restored.refresh_daily()
 check(restored.daily.claimed.is_empty() and restored.daily.progress.matches==0 and restored.gear_stash.size()==5,"next local day resets quests while preserving gear")
 # Legacy save migration keeps existing ranks/settings without inventing drops.
 var legacy_path="res://tests/equipment-legacy-v040.cfg";var legacy=ConfigFile.new()
 legacy.set_value("profile","credits",12345);legacy.set_value("profile","difficulty",32);legacy.set_value("upgrades","vitality",7);legacy.set_value("controls","smart_cast",false);legacy.save(legacy_path)
 var migrated=load("res://scripts/Progression.gd").new();migrated.save_path=legacy_path;migrated.clock_date="2026-10-10";migrated.load_profile()
 check(migrated.credits==12345 and migrated.difficulty==32 and migrated.levels.vitality==7 and not migrated.smart_cast,"legacy profile migration preserves credits, difficulty, ranks and controls")
 check(migrated.gear_stash.is_empty() and migrated.daily.claimed.is_empty(),"legacy saves start a fresh equipment stash and daily board")
 check(migrated.save_profile(),"legacy profile saves atomically with new equipment schema")
 migrated.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
 var rng=RandomNumberGenerator.new();rng.seed=321;var low_power=0.;var high_power=0.;var low_rarity=0.;var high_rarity=0.;var ring_items=[]
 for i in range(500):
  for stage in [1,99]:
   var item=GearLoot.roll(stage,rng,"sample_%d_%d" % [i,stage]);var valid=GearLoot.validate(item)
   check(valid==item and GearArt.icon_for(GearLoot.icon_key(item))!=null,"every generated equipment type has valid saved data and imported art")
   check(item.level<=stage and item.level>=maxi(1,stage-2) and item.affixes.size()==item.rarity+1,"item level range and affix count follow difficulty and rarity")
   var distinct={}
   for affix in item.affixes:distinct[affix.stat]=true
   check(distinct.size()==item.affixes.size(),"random affixes do not repeat on one item")
   if stage==1:low_rarity+=item.rarity
   else:high_rarity+=item.rarity
   for stat in item.stats:
    check(is_finite(item.stats[stat]) and item.stats[stat]>0.,"rolled stat is positive and finite")
    if not GearLoot.CAPS.has(stat):
     if stage==1:low_power+=item.stats[stat]
     else:high_power+=item.stats[stat]
   if item.slot=="ring" and ring_items.size()<2:ring_items.append(item)
 check(high_power>low_power*3. and high_rarity>low_rarity*1.5,"N99 rewards have substantially stronger rolls and rarity odds")
 restored.gear_stash.append_array(ring_items)
 check(restored.equip_gear(ring_items[0].id,"ring_1") and restored.equip_gear(ring_items[1].id,"ring_2"),"two distinct rings occupy both ring slots")
 check(restored.equip_gear(ring_items[0].id,"ring_2") and not restored.gear_equipped.has("ring_1"),"one ring cannot be counted in both slots")
 check(not restored.salvage_gear(ring_items[0].id),"equipped items cannot be salvaged")
 check(restored.unequip_gear("ring_2") and restored.salvage_gear(ring_items[0].id),"unequipped salvage removes item and gives credits")
 restored.save_path="res://tests/nonexistent-folder/blocked.cfg"
 var prior=restored.gear_equipped.duplicate()
 check(not restored.equip_gear(first_item.id,slot) and restored.gear_equipped==prior,"failed save rolls back equipment changes")
 # A full stash defers a quest reward; freeing space grants the original level once.
 var full=load("res://scripts/Progression.gd").new();full.clock_date="2026-10-10";full.refresh_daily(false)
 for i in range(full.STASH_LIMIT):full.gear_stash.append(GearLoot.roll(1,rng,"full_%d" % i))
 full.begin_match();full.complete_match(false,240,0,35,0)
 check(full.daily.ready.first_run==35 and full.daily.claimed.is_empty(),"full stash retains a pending daily reward and its earned difficulty")
 var scrap=full.gear_stash[0].id;check(full.salvage_gear(scrap) and full.claim_pending(),"salvage frees space for a waiting reward")
 check(full.gear_stash.size()==full.STASH_LIMIT and full.daily.claimed.size()==1 and full.last_drops[0].level>=33,"waiting reward is delivered at original item level")
 full.claim_pending();check(full.daily.claimed.size()==1,"claim button cannot duplicate a quest reward")
 full.free()
 GameState.started=true
 check(not profile.equip_gear(first_item.id,slot) and not profile.unequip_gear(slot) and not profile.salvage_gear(first_item.id),"equipment is locked during matches")
 GameState.reset()
 # Actual champion uses the same captured bonuses through shopping and respawn.
 Progression.persistent=false;Progression.gear_stash=profile.gear_stash.duplicate(true);Progression.gear_equipped=profile.gear_equipped.duplicate();Progression.levels={"might":2};Progression.difficulty=20;Progression.daily=profile.daily.duplicate(true);Progression.clock_date="2026-10-10"
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._show_equipment();await get_tree().process_frame;await get_tree().process_frame
 var screen=game.menu.find_child("EquipmentScreen",true,false)
 check(screen!=null and screen.find_child("GearStashScroll",true,false)!=null,"equipment and daily quests are accessible from main menu")
 screen.selected_id=first_item.id;screen.selected_slot=slot;screen.refresh_detail()
 await get_tree().process_frame;await get_tree().process_frame
 var quest_list=screen.find_child("DailyQuestScroll",true,false).get_child(0)
 var bottom=-1.
 for card in quest_list.get_children():
  check(card.position.y>=bottom,"quest cards never overlap wrapped text")
  bottom=card.position.y+card.size.y
 check(screen.get_global_rect().encloses(screen.find_child("GearStashScroll",true,false).get_global_rect()),"stash scroll remains within screen")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/equipment-menu-v040.png")
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;game._input(escape)
 check(game.menu_page=="main","Esc returns from equipment to main menu")
 var all_fields={}
 for stat in GearLoot.STAT_NAMES:all_fields[stat]=.05 if GearLoot.CAPS.has(stat) else 15.
 var sanitized=LanSession.sanitize_bonuses(all_fields)
 for stat in all_fields:check(is_equal_approx(sanitized[stat],all_fields[stat]),"co-op accepts every supported equipment stat: "+stat)
 game._show_menu();game._start_game("malphite");game.set_process(false)
 var hero=GameState.player;var expected=Progression.bonuses()
 for stat in expected:check(is_equal_approx(hero.permanent_bonus[stat],expected[stat]),"champion captures permanent gear: "+stat)
 var snapshot=hero.permanent_bonus.duplicate();hero.gold=10000;hero.try_buy_item("long_sword")
 check(hero.permanent_bonus==snapshot and hero.inventory.has("long_sword"),"match shop items remain separate from saved equipment")
 hero.dead=true;hero.hp=0;hero._apply_items();game._respawn_champion(hero)
 check(hero.permanent_bonus==snapshot and hero.hp>0,"death and respawn preserve equipped stats")
 var lan=LanSession.sanitize_bonuses(expected)
 for stat in expected:check(is_equal_approx(lan[stat],expected[stat]),"co-op preserves equipment stat: "+stat)
 for stage in range(2,100):
  var stats=Progression.scaling(stage);var previous=Progression.scaling(stage-1)
  check(stats.health>previous.health and stats.damage>previous.damage and stats.magic_resist>previous.magic_resist,"higher N raises enemy strength")
 GameState.time=400;hero.kills=12;hero.cs=80;Progression.clock_date="2026-10-11"
 game._end_game(Constants.BLUE)
 await get_tree().process_frame;await get_tree().process_frame
 check(Progression.last_drops.size()==4,"real result grants first-run, victory, kill and last-hit quest drops")
 check(game.hud.get_node("HudRoot").end_stats.text.contains("Gear drops:"),"result lists newly earned persistent relics")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/equipment-result-v040.png")
 game._return_to_main_menu();Progression.clock_date=""
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path));profile.free();restored.free()
 print("EQUIPMENT PROGRESSION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
