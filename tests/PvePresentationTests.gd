extends Node
var failures = 0
var checks = 0
var game
func check(value: bool,message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+message)
func reset(hero: String):
 if is_instance_valid(game):
  remove_child(game); game.queue_free()
 GameState.reset()
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game(hero)
 for champion in GameState.champions:
  champion.is_bot = false
  champion.stop_actions()
  champion.global_position = Constants.FOUNT_B if champion.team == 0 else Constants.FOUNT_R
 return GameState.player
func capture(path: String) -> void:
 await get_tree().process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 await get_tree().process_frame
 for hero in ["leesin","yasuo"]:
  var p = reset(hero)
  p.is_bot = true
  var tower
  for structure in GameState.structures:
   if structure.team == 1 and structure.variant == "outer": tower = structure
  p.global_position = tower.world_pos()-Vector2(360,0)
  var defender = GameState.champions[3]
  defender.global_position = tower.world_pos()-Vector2(100,0)
  defender.hp = 50
  check(not p._safe_pursuit(defender),hero+" refuses a tempting low-HP defender under tower")
  var mana = p.mp
  if hero == "leesin":
   defender.buffs.sonic_mark = {"time":4.0,"src":p}
   p.sonic_target = defender
   p.skill_cds[0] = 5
   check(not p.try_cast_skill(0,defender.world_pos()) and not p.is_dashing and p.mp == mana,"Lee Q recast does not dive through tower safety")
  else:
   check(not p.try_cast_skill(2,defender.world_pos()) and not p.is_dashing and p.mp == mana,"Yasuo dash landing respects tower safety")
  p.ai_tick = 0
  p._run_bot_ai(0.05)
  check(p.attack_target == null and p.move_target.distance_to(tower.world_pos())>tower.atk_range,"uncovered bot waits outside tower")
  var cover = []
  for i in range(2):
   var minion = game.MinionS.new()
   game.world_root.add_child(minion)
   minion.setup(0,"melee",tower.world_pos()+Vector2(-40,i*30))
   GameState.minions.append(minion)
   cover.append(minion)
   if i == 0: check(not BotSafety.wave_covers(p,tower),"one minion is not enough cover")
  check(BotSafety.wave_covers(p,tower) and BotSafety.can_enter(p,BotSafety.approach(p,tower)),"healthy wave allows a coordinated tower siege")
  check(not BotSafety.can_enter(p,defender.world_pos(),true),"minion cover does not authorize hitting a defender under tower")
  p.ai_tick = 0
  p._run_bot_ai(0.05)
  check(p.attack_target == tower,"bot attacks tower with healthy wave cover")
  p.global_position = tower.world_pos()-Vector2(120,0)
  tower.provoke(p)
  p.is_dashing = true
  p.ai_tick = 0
  p._run_bot_ai(0.05)
  check(p.attack_target == null and not p.is_dashing and p.has_move_target and p.move_target.distance_to(tower.world_pos())>tower.atk_range,"tower aggro causes retreat and cancels a committed dive")
  tower.aggro_target = null; tower.target = null
  for minion in cover: minion.dead = true
  p.ai_tick = 0
  p._run_bot_ai(0.05)
  check(p.move_target.distance_to(tower.world_pos())>tower.atk_range,"loss of wave cover triggers retreat")
  p.global_position = tower.world_pos()-Vector2(620,0)
  defender.global_position = tower.world_pos()-Vector2(480,0)
  p.skill_cds = [99,99,99,99]
  p.ai_tick = 0
  p._run_bot_ai(0.05)
  check(p.attack_target == defender,"melee bot still pursues a vulnerable enemy outside tower")
 var p = reset("leesin")
 p.global_position = Vector2(1300,270)
 var marked = game.MinionS.new()
 game.world_root.add_child(marked)
 marked.setup(1,"melee",Vector2(1480,270))
 GameState.minions.append(marked)
 p.try_cast_skill(0,marked.world_pos())
 for frame in range(20):
  for projectile in GameState.projectiles.duplicate(): projectile.update_frame(0.02)
 var ui = game.hud.get_node("HudRoot")
 ui.refresh(0)
 var slot = ui.skill_slots[0]
 check(not slot.recast_state.is_empty() and slot.recast_state.label == "Q2 DASH" and slot.recast_state.time == 4,"Q2 shows its actual four-second window after a hit")
 check(slot.cd_remaining == 0 and slot.ready_to_cast,"available Q2 replaces the first-cast cooldown display")
 marked.buffs.sonic_mark.time = 2.6
 p.sonic_target = null
 ui.refresh(0)
 check(is_equal_approx(slot.recast_state.time,2.6),"recast UI reconstructs a minion mark without local pointer, as on LAN")
 check(ChampionData.skill_description("leesin",0,p).contains("2.6s remaining"),"hover includes the live recast deadline")
 game._update_camera(1)
 game.set_fullscreen(true)
 await get_tree().create_timer(0.2).timeout
 await capture("res://tests/43-lee-q-recast-timer.png")
 marked.global_position = Vector2(2200,270)
 ui.refresh(0)
 check(not slot.recast_state.available and not slot.ready_to_cast,"out-of-range Q2 is labelled unavailable without losing the timer")
 marked.global_position = Vector2(1480,270)
 p.mp = 0
 check(p.try_cast_skill(0,marked.world_pos()) and p.is_dashing,"Q2 uses the remaining mark without another mana charge")
 ui.refresh(0)
 check(slot.recast_state.is_empty() and slot.cd_remaining > 0,"using Q2 returns to ordinary cooldown")
 marked.buffs.sonic_mark = {"time":0.0,"src":p}
 p.sonic_target = marked
 check(NewHeroKits.recast_info(p,0).is_empty(),"expired mark has no recast prompt")
 p = reset("zed")
 p.try_cast_skill(1,p.world_pos()+Vector2(160,0))
 check(NewHeroKits.recast_info(p,1).label == "W2 SWAP","shadow swap also exposes a recast window")
 p = reset("yasuo")
 p.global_position = Vector2(1300,270)
 for i in range(3):
  p.skill_cds[0] = 0
  p.try_cast_skill(0,Vector2(1700,270))
 var tornado = GameState.projectiles.back()
 check(tornado.wind_kind == 1 and tornado.stun_time > 0,"third Q has a distinct tornado sprite and knockup")
 check(GameState.projectiles[0].wind_kind == 0,"first Q has its own steel wind thrust sprite")
 for projectile in GameState.projectiles.duplicate():
  if projectile != tornado: projectile._destroy()
 tornado.update_frame(0.18)
 p.try_cast_skill(1,Vector2(1700,270))
 var enemy = GameState.champions[3]
 enemy.global_position = Vector2(1600,270)
 enemy.hp = enemy.hp_max
 enemy.stun = 1.0
 p.skill_ranks[3] = 1
 p.try_cast_skill(3,enemy.world_pos())
 check(GameState.aoes.back().wind_kind == 3,"aerial finisher uses a dedicated wind slash atlas")
 game._update_camera(1)
 ui = game.hud.get_node("HudRoot")
 ui.refresh(0)
 await capture("res://tests/44-wind-samurai-effects.png")
 var packet = LanSnapshot.encode()
 check(packet.projectiles.any(func(state): return state.wind_kind == 1),"LAN snapshot retains the tornado animation kind")
 check(packet.aoes.any(func(state): return state.wind_kind == 3),"LAN snapshot retains the aerial finisher animation kind")
 check(WindArt.texture.get_image().detect_alpha() != Image.ALPHA_NONE,"generated wind atlas preserves transparency")
 p = reset("garen")
 var enemies = GameState.champions.filter(func(c): return c.team != p.team)
 for i in range(3):
  GameState.time = i*2
  game._handle_death(p,enemies[i])
 check(game.kill_announcer.events == ["first_blood","double_kill","triple_kill"],"three champion kills in the window announce first, double and triple")
 check(game.sound_fx.announcement_counts.get("double_kill",0) == 1 and game.sound_fx.announcement_counts.get("triple_kill",0) == 1,"multikill announcements dispatch spoken audio")
 ui = game.hud.get_node("HudRoot")
 check(ui.announcement.visible and ui.announcement_title.text == "TRIPLE KILL","multikill banner names the event")
 ui.refresh(0)
 await capture("res://tests/45-triple-kill-announcer.png")
 enemies[0].dead = false
 GameState.time = 20
 game._handle_death(p,enemies[0])
 check(game.kill_announcer.streaks[p.get_instance_id()].count == 1,"long gaps reset the multikill chain")
 game._handle_death(enemies[1],p)
 check(game.kill_announcer.events.back() == "shutdown" and game.kill_announcer.streaks[p.get_instance_id()].streak == 0,"death resets streak and announces a shutdown")
 var count = game.sound_fx.announcement_counts.size()
 game.sound_fx.set_enabled(false)
 game.sound_fx.announce("double_kill")
 check(game.sound_fx.announcement_counts.size() == count,"mute includes announcer")
 for clip in game.sound_fx.announcer_clips.values():
  check(clip is AudioStreamWAV and clip.get_length()>0.5 and clip.data.size()>0,"valid voiced announcement")
 print("PVE PRESENTATION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
