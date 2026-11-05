extends Node
var failures = 0
var checks = 0
var game
func check(value: bool,message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+message)
func spawn_game(bots: bool) -> void:
 Progression.allied_bots = bots
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("lux")
func cleanup() -> void:
 game.queue_free()
 GameState.reset()
 await get_tree().process_frame
func _ready() -> void:
 Progression.persistent = false
 Progression.levels.clear();Progression.gear_equipped.clear();Progression.gear_stash.clear()
 spawn_game(false)
 check(GameState.champions.size()==6,"stable slots retained for network references")
 check(GameState.player.roster_active and not GameState.player.is_bot,"solo player active")
 for c in GameState.champions.slice(1,3):
  check(not c.roster_active and c.dead and not c.visible and not c.is_targetable,"vacant ally disabled")
  game._respawn_champion(c)
  check(c.dead and not c.visible,"disabled slot never respawns")
 for c in GameState.champions.slice(3):check(c.roster_active and c.is_bot and not c.dead,"enemy AI unaffected")
 game._tick_waves()
 GameState.time=Constants.FIRST_WAVE_AT+1.;game._tick_waves()
 check(GameState.minions.any(func(m):return m.team==Constants.BLUE),"allied minions still spawn")
 var snapshot=LanSnapshot.encode()
 check(not snapshot.allied_bots and not snapshot.champs[1].roster_active,"host encodes match rule and inactive slots")
 var board=game.hud.get_node("HudRoot").scoreboard
 board.refresh()
 check(not board.rows[GameState.champions[1]].panel.visible,"inactive ally hidden from scoreboard")
 check(not game.hud.get_node("HudRoot").team_rows[GameState.champions[1]].visible,"inactive ally hidden from team HUD")
 await cleanup()
 spawn_game(true)
 for c in GameState.champions:check(c.roster_active and not c.dead,"default fills all slots")
 var killer=GameState.player
 var helper=GameState.champions[1]
 var bystander=GameState.champions[2]
 var victim=GameState.champions[3]
 var enemy=GameState.champions[4]
 # Hold AI/regen/animations while invoking authoritative combat paths.
 for c in GameState.champions:c.is_bot=false;c.hp=10000.;c.hp_max=10000.;c.shield=0.;c.buffs.clear()
 GameState.time=20.
 var gold=helper.gold;var by_gold=bystander.gold;var count=helper.assists
 game.deal_damage(helper,victim,10.,"auto")
 helper.position=Vector2(0,0)
 victim.position=Vector2(1500,270);bystander.position=victim.position
 game._handle_death(killer,victim)
 check(helper.gold==gold+CombatParticipation.ASSIST_GOLD and helper.assists==count+1,"recent distant contributor earns small gold and assist")
 check(bystander.gold==by_gold and bystander.assists==0,"nearby bystander earns no assist")
 check(killer.assists==0,"killer never gets own assist")
 game._handle_death(killer,victim)
 check(helper.gold==gold+CombatParticipation.ASSIST_GOLD,"duplicate death cannot duplicate rewards")
 game._respawn_champion(victim);victim.hp=10000.
 GameState.time=30.;game.deal_damage(helper,victim,10.,"magic")
 GameState.time=40.01;gold=helper.gold;game._handle_death(killer,victim)
 check(helper.gold==gold,"expired ten-second participation receives no gold")
 game._respawn_champion(victim);victim.hp=10000.;GameState.time=50.
 victim.shield=100.;game.deal_damage(helper,victim,10.,"auto")
 check(victim.assist_hits.has(1),"shield-absorbed attack still contributes")
 helper.dead=true;gold=helper.gold;game._handle_death(killer,victim)
 check(helper.gold==gold+CombatParticipation.ASSIST_GOLD,"dead contributor still earns assist gold")
 helper.dead=false;game._respawn_champion(victim);victim.hp=10000.;GameState.time=60.
 CombatEffects.shield(helper,"test_support",100.,3.,bystander)
 game.deal_damage(helper,victim,10.,"auto")
 gold=bystander.gold;game._handle_death(killer,victim)
 check(bystander.gold==gold+CombatParticipation.ASSIST_GOLD and bystander.assists==1,"shield support before damage earns assist")
 game._respawn_champion(victim);victim.hp=10000.;helper.assist_support.clear();GameState.time=80.
 game.deal_damage(helper,victim,10.,"auto");HeroPassives.support(bystander,helper)
 gold=bystander.gold;game._handle_death(killer,victim)
 check(bystander.gold==gold+CombatParticipation.ASSIST_GOLD,"support after recent damage earns assist")
 game._respawn_champion(victim);victim.hp=10000.;helper.assist_support.clear();victim.buffs.divine={"time":2.};GameState.time=100.
 game.deal_damage(helper,victim,10.,"magic");check(victim.assist_hits.is_empty(),"invulnerable target gives no contribution")
 victim.buffs.clear();game.deal_damage(helper,victim,0.,"magic");check(victim.assist_hits.is_empty(),"zero damage gives no contribution")
 CombatParticipation.hit(enemy,victim);check(victim.assist_hits.is_empty(),"friendly damage rejected")
 # Co-op host rule overrides the guest's saved solo preference.
 await cleanup()
 Progression.allied_bots=true
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game.network_config={"stage":1,"allied_bots":false,"blue":["lux","leesin","garen"],"red":["ahri","ashe","darius"],"players":[{"peer":1,"hero":"lux","name":"Host","bonuses":{},"spells":["flash","ignite"]},{"peer":2,"hero":"leesin","name":"Guest","bonuses":{},"spells":["heal","ghost"]}]}
 game._start_game("lux")
 check(not GameState.allied_bots and GameState.champions[1].roster_active and not GameState.champions[2].roster_active,"two humans active, empty third slot disabled by host")
 LanSession._peer_left(2)
 # _peer_left only acts on a real host; disable helper has the same exercised contract.
 GameState.champions[1].disable_roster_slot()
 check(not GameState.champions[1].roster_active and GameState.champions[1].dead,"disconnect leaves inactive hero with bots off")
 # Round-trip preferences without touching the user's account.
 var original_path=Progression.save_path
 Progression.save_path="res://tests/.assist-bots-settings.cfg";Progression.persistent=true
 Progression.allied_bots=false;Progression.edge_smoothing=false;Progression.frame_limit=144;Progression.vsync_enabled=false
 check(Progression.save_profile(),"preferences persist")
 Progression.allied_bots=true;Progression.edge_smoothing=true;Progression.frame_limit=60;Progression.vsync_enabled=true
 Progression.load_profile()
 check(not Progression.allied_bots and not Progression.edge_smoothing and Progression.frame_limit==144 and not Progression.vsync_enabled,"preferences reload correctly")
 DirAccess.remove_absolute(Progression.save_path);Progression.save_path=original_path;Progression.persistent=false
 Progression.allied_bots=true;Progression.edge_smoothing=true;Progression.frame_limit=120
 check(game.graphics_quality.layer==1 and game.hud.layer==10,"AA pass renders below HUD")
 check(game.graphics_quality.screen.mouse_filter==Control.MOUSE_FILTER_IGNORE,"graphics never captures movement clicks")
 game.graphics_quality.apply()
 check(game.graphics_quality.screen.visible,"smoothing enabled for battle")
 Progression.edge_smoothing=false;Progression.world_sharpness=0.;game.graphics_quality.apply()
 check(not game.graphics_quality.screen.visible,"performance option removes shader pass")
 if DisplayServer.get_name()!="headless":
  await visual_check()
  await benchmark()
  await menu_check()
 await cleanup()
 print("Assist/bots/graphics: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
func visual_check() -> void:
 # Compare a fixed diagonal world edge and fixed HUD plaque in actual GPU output.
 var world_layer=CanvasLayer.new();world_layer.layer=0;game.add_child(world_layer)
 var base=ColorRect.new();base.position=Vector2(90,90);base.size=Vector2(240,240);base.color=Color.BLACK;world_layer.add_child(base)
 var shape=Polygon2D.new();shape.polygon=PackedVector2Array([Vector2(100,100),Vector2(318,146),Vector2(121,318)]);shape.color=Color.WHITE;world_layer.add_child(shape)
 var ui_layer=CanvasLayer.new();ui_layer.layer=11;game.add_child(ui_layer)
 var plaque=ColorRect.new();plaque.position=Vector2(600,90);plaque.size=Vector2(240,240);plaque.color=Color("bf903a");ui_layer.add_child(plaque)
 var caption=Label.new();caption.text="SHARP HUD 123";caption.position=Vector2(610,120);caption.add_theme_font_size_override("font_size",24);ui_layer.add_child(caption)
 Progression.edge_smoothing=false;Progression.world_sharpness=0.;game.graphics_quality.apply()
 await RenderingServer.frame_post_draw
 var before=get_viewport().get_texture().get_image()
 Progression.vsync_enabled=true;Progression.edge_smoothing=true;game.graphics_quality.apply()
 await RenderingServer.frame_post_draw
 var after=get_viewport().get_texture().get_image()
 var scale=Vector2(before.get_size())/get_viewport().get_visible_rect().size
 var world_region=Rect2i(Vector2(90,90)*scale,Vector2(240,240)*scale)
 var ui_region=Rect2i(Vector2(600,90)*scale,Vector2(240,240)*scale)
 check(before.get_region(world_region).get_data()!=after.get_region(world_region).get_data(),"GPU smoothing changes world edges")
 check(before.get_region(ui_region).get_data()==after.get_region(ui_region).get_data(),"GPU smoothing preserves HUD pixels exactly")
 world_layer.queue_free();ui_layer.queue_free()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/assist-graphics-native.png")

func benchmark() -> void:
 Progression.vsync_enabled=false
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 for enabled in [false,true,true,false]:
  Progression.edge_smoothing=enabled;game.graphics_quality.apply();Engine.max_fps=0
  for warmup in range(15):await RenderingServer.frame_post_draw
  var start=Time.get_ticks_usec()
  for frame in range(120):await RenderingServer.frame_post_draw
  var ms=float(Time.get_ticks_usec()-start)/120000.
  print("Native render benchmark: FXAA %s, %.3f ms/frame, %.1f FPS" % ["ON" if enabled else "OFF",ms,1000./ms])
 Progression.vsync_enabled=true;Progression.edge_smoothing=true;game.graphics_quality.apply()

func menu_check() -> void:
 game._return_to_main_menu();game.set_process(false)
 await get_tree().process_frame
 var bots=game.menu.find_child("AlliedBots",true,false)
 check(bots!=null,"bot rule visible on start screen")
 bots.button_pressed=false
 check(not Progression.allied_bots,"start screen bot switch updates match preference")
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/assist-start-menu.png")
 game._show_start_upgrades()
 await get_tree().process_frame
 var scroll=game.menu.find_child("SettingsScroll",true,false)
 check(scroll!=null and scroll.get_v_scroll_bar().max_value>scroll.size.y,"settings overflow scrolls rather than clipping")
 var smoothing=game.menu.find_child("EdgeSmoothing",true,false)
 check(smoothing!=null and game.menu.find_child("FrameLimit",true,false)!=null and game.menu.find_child("VSync",true,false)!=null,"graphics controls reachable in settings")
 scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/assist-graphics-settings.png")
 Progression.allied_bots=true
