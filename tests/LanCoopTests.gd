extends Node
var failures = 0
var role: String = "host"
var game
var observed_w: Dictionary = {}
# Rift3D invariants (W4): replica projectiles sampled every frame on clients while the shared match runs.
var v3d_projectiles: int = 0
var v3d_missing_projectiles: int = 0
func _process(_delta: float) -> void:
 if not GameState.started: return
 for c in GameState.champions:
  if c.anim_action == "w": observed_w[c.owner_peer] = true
 if role != "host" and GameState.running and view3d_active():
  sample_projectile_views()
func view3d_active() -> bool:
 return game != null and is_instance_valid(game) and game.view3d != null and game.view3d.is_active()
func sample_projectile_views() -> void:
 for node in LanSession.replica_projectiles.values():
  if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion(): continue
  if game.view3d.view_for(node) == null: game.view3d.sync_now() # a replica made this frame registers on the next view step
  v3d_projectiles += 1
  if game.view3d.view_for(node) == null: v3d_missing_projectiles += 1
func check_unit_views(label: String) -> void:
 if not view3d_active(): return
 game.view3d.sync_now()
 var units = []
 units.append_array(GameState.champions); units.append_array(GameState.minions); units.append_array(GameState.structures)
 var missing = 0; var off = 0; var worst = 0.0; var count = 0
 for u in units:
  if not is_instance_valid(u) or not u.is_inside_tree() or u.is_queued_for_deletion(): continue
  count += 1
  var view = game.view3d.view_for(u)
  if view == null: missing += 1; continue
  if u.get("buffs") is Dictionary and u.buffs.has("airborne"): continue # knock-ups lift the card along camera-up
  var d = view.global_position.distance_to(ViewMath.to3(u.global_position))
  worst = maxf(worst,d)
  if d > 0.001: off += 1
 check(count > 0 and missing == 0,"3D %s: every replicated unit has a view (%d of %d missing)" % [label,missing,count])
 check(off == 0,"3D %s: unit views sit on to3(sim position) within 1e-3 m (%d off, worst %.5f m)" % [label,off,worst])
func check_corpse_views() -> void:
 if not view3d_active(): return
 game.view3d.sync_now()
 var corpses = game.world_root.get_children().filter(func(n): return n is AnimatedCorpse and not n.is_queued_for_deletion())
 var missing = 0; var off = 0
 for corpse in corpses:
  var view = game.view3d.view_for(corpse)
  if view == null: missing += 1; continue
  if view.global_position.distance_to(ViewMath.to3(corpse.global_position)) > 0.001: off += 1
 check(not corpses.is_empty() and missing == 0,"3D: replicated deaths get corpse views (%d of %d missing)" % [missing,corpses.size()])
 check(off == 0,"3D: corpse views sit on their corpse within 1e-3 m (%d off)" % off)
func check(value: bool,text: String) -> void:
 if not value: failures += 1; push_error("FAIL "+role+": "+text)
func until(predicate: Callable,seconds: float = 12) -> bool:
 var deadline = Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec() < deadline:
  await get_tree().create_timer(0.05).timeout
 return predicate.call()
func _ready() -> void:
 role = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "host"
 GameState.reset()
 Progression.persistent = false
 Progression.levels.clear();Progression.gear_stash.clear();Progression.gear_equipped.clear();Progression.daily.clear()
 var gear_rng=RandomNumberGenerator.new();gear_rng.seed=17 if role=="host" else 28 if role=="client1" else 39
 for index in range(3):
  var relic=GearLoot.roll(5,gear_rng,role+"_relic_%d" % index);Progression.gear_stash.append(relic)
  Progression.equip_gear(relic.id,"ring_1" if relic.slot=="ring" else relic.slot)
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 if role == "host":
  check(LanSession.host_game() == OK,"server starts")
  LanSession.ready_player("yasuo",["flash","ignite"],Progression.bonuses())
  if not await until(func(): return LanSession.players.size() == 3 and LanSession.can_start()):
   check(false,"three ready peers join"); get_tree().quit(1); return
  LanSession.start_match()
  check(await until(func():return GameState.running),"all peers finish asset loading before scenario")
  check(GameState.champions.size() == 6 and GameState.player.hero_key == "yasuo","host starts shared ARAM")
  check(GameState.champions[1].owner_peer != 0 and not GameState.champions[1].is_bot and not GameState.champions[2].is_bot,"three humans own separate blue heroes")
  await until(func(): return GameState.time >= 3)
  # Rift3D: an inert probe missile parked over the north abyss (no unit can stand there) so every client sees a replica projectile.
  game.spawn_projectile(GameState.player,Vector2(Constants.WORLD_W*0.5,12),Vector2.RIGHT,{"speed":0.,"dmg":0.,"life":8.,"no_structures":true})
  for c in GameState.champions.slice(1,3): c.grant_xp(Constants.xp_to_level(3)); c.gold = 20000
  var lee = GameState.champions.filter(func(c): return c.hero_key == "leesin" and c.team == Constants.BLUE)[0]
  var marked = GameState.champions.filter(func(c): return c.hero_key == "zed" and c.team == Constants.BLUE)[0]
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://tests/34-lan-host.png")
  check(await until(func(): return GameState.champions.slice(1,3).all(func(c): return observed_w.has(c.owner_peer) and c.summoner_cds[1]>0),12),"guests finish casts before scripted deaths")
  marked.buffs.sonic_mark = {"time":4.0,"src":lee}
  check(await until(func(): return GameState.champions.slice(1,3).all(func(c): return c.skill_ranks[0]==2 and LanSession.draft_states.get(c.owner_peer,{}).get("picked",[]).size()==1),10),"guests finish recast and draft checks before deaths")
  for c in GameState.champions.slice(1,3): game._handle_death(GameState.champions[3],c)
  # Guests shop once they see their death. A loaded guest can need more than the usual 3 s, so wait for both
  # purchases to reach the host (up to 12 s), keeping at least the old 3 s and 1.5 s after the purchases land.
  var deaths_at = Time.get_ticks_msec()
  await until(func(): return GameState.champions.slice(1,3).all(func(c): return c.inventory.has("dagger") and c.consumable_counts.get("training_ad",0)==2),12)
  await get_tree().create_timer(maxf(1.5,3.0-(Time.get_ticks_msec()-deaths_at)/1000.0)).timeout
  for c in GameState.champions.slice(1,3):
   check(c.inventory.has("dagger"),"guest purchase reached host")
   check(c.consumable_counts.get("training_ad",0)==2 and c.consumable_bonus.get("bonus_ad",0)==50,"guest stacked consumables reached host")
   check(c.skill_ranks[0] == 2,"guest skill upgrade reached host")
   check(not c.run_bonus.is_empty(),"guest draft applied only to owned hero")
  game._end_game(Constants.BLUE)
  await get_tree().create_timer(1.5).timeout
  check(Progression.last_reward > 0,"host earns match credits")
  check(Progression.daily.claimed.size()>=2 and Progression.gear_stash.size()>=5,"host saves daily quest gear drops")
  check(GameState.champions[1].is_bot and GameState.champions[2].is_bot,"disconnected guests hand control to AI")
 else:
  check(LanSession.join_game("127.0.0.1") == OK,"guest connects")
  if not await until(func(): return LanSession.players.has(multiplayer.get_unique_id())):
   check(false,"lobby sync arrives"); get_tree().quit(1); return
  LanSession.ready_player("leesin" if role == "client1" else "zed",["heal","ghost"],Progression.bonuses())
  if not await until(func(): return GameState.running):
   check(false,"shared match begins"); get_tree().quit(1); return
  var p = GameState.player
  for stat in Progression.bonuses():check(is_equal_approx(p.permanent_bonus.get(stat,0.),Progression.bonuses()[stat]),"guest equipment stat replicated: "+stat)
  check(p.owner_peer == multiplayer.get_unique_id() and p.hero_key == ("leesin" if role == "client1" else "zed"),"guest controls chosen hero")
  game._issue_player_order({"type":"smart","point":Vector2(600,270)})
  check(await until(func(): return p.animator.pose().action == "run",2),"guest sees the replicated articulated run cycle")
  check(await until(func(): return p.world_pos().x >= 540,5),"movement replicated from server")
  check_unit_views("after replicated movement")
  p.try_cast_skill(1,p.world_pos()+Vector2(60,0))
  check(await until(func(): return p.skill_cds[1] > 0,2),"skill executes on host")
  check(p.anim_action == "w" or observed_w.has(p.owner_peer),"guest receives the authoritative W cast animation")
  game.cast_summoner(p,1)
  check(await until(func(): return p.summoner_cds[1] > 0,2),"chosen summoner executes on host")
  check(await until(func(): return game.lane_augments.pending == [4],4),"own level-up draft replicated")
  check(game.lane_augments.choices.size() == 3,"guest receives three stable draft options")
  if role == "client1":
   check(await until(func(): return not NewHeroKits.recast_info(p,0).is_empty(),1),"Q marked-target countdown replicated to guest")
   var mark = NewHeroKits.recast_info(p,0)
   check(not mark.is_empty() and mark.time>0 and mark.time<=4.0,"guest Q recast carries the authoritative remaining time")
  var rolled={}
  if not game.lane_augments.choices.is_empty():
   var index=game.lane_augments.choices[0]
   rolled=game.lane_augments.offers.get(index,{}).get("stats",{}).duplicate()
   check(not rolled.is_empty(),"host rolls exact stat values for guest choices")
   game.lane_augments.choose(index)
  p.try_level_skill(0)
  check(await until(func(): return p.skill_ranks[0] == 2 and game.lane_augments.picked.size() == 1,2),"rank and draft confirmed by server")
  for stat in rolled:check(is_equal_approx(p.run_bonus.get(stat,0.),rolled[stat]),"guest receives the exact offered stat magnitude: "+stat)
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://tests/35-lan-"+role+".png")
  check(await until(func(): return p.dead,10),"death replicated")
  check(game.world_root.get_children().any(func(n):return n is AnimatedCorpse),"guest renders animated corpses when death is replicated")
  check_corpse_views()
  check_unit_views("after replicated death")
  check(await until(func(): return game.sound_fx.announcement_counts.get("double_kill",0)>0,3),"double-kill voice announcement replicated")
  p.try_buy_item("dagger")
  check(await until(func(): return p.inventory.has("dagger"),2),"guest shops while dead")
  p.try_buy_item("training_ad")
  check(await until(func():return p.consumable_counts.get("training_ad",0)==1,3),"guest receives first consumed stat bonus")
  p.try_buy_item("training_ad")
  check(await until(func():return p.consumable_counts.get("training_ad",0)==2 and p.consumable_bonus.get("bonus_ad",0)==50,3),"guest repeat purchase uses increasing price and replicated stats")
  check(p.gold<1500 and not p.inventory.has("training_ad"),"guest consumables spend gold without a slot")
  var cooldown = p.summoner_cds[1]
  await get_tree().create_timer(0.4).timeout
  check(p.summoner_cds[1] < cooldown,"cooldown continues while dead")
  if view3d_active():
   check(v3d_projectiles > 0 and v3d_missing_projectiles == 0,"3D: replica projectiles have views (%d samples, %d missing)" % [v3d_projectiles,v3d_missing_projectiles])
   print("LAN %s: 3D invariants checked (%d replica projectile samples)" % [role,v3d_projectiles])
  else: print("LAN %s: classic 2D, 3D invariants skipped" % role)
  # The host waits up to 12 s for both guests' purchases before ending the match, so allow for that here.
  check(await until(func(): return not GameState.running,16),"shared match result arrives")
  check(Progression.last_reward > 0,"guest earns permanent completion credits")
  check(Progression.daily.claimed.size()>=2 and Progression.gear_stash.size()>=5,"guest receives daily quest drops after authoritative result")
 print("LAN "+role+": "+str(failures)+" failures")
 await get_tree().create_timer(.2).timeout
 LanSession.leave()
 game.queue_free()
 GameState.reset()
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
