extends Node
var game
var samples=[]
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL MEMORY STABILITY: "+message)
func settled() -> void:
 for frame in range(4):await get_tree().process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func sample(round: int,label: String,start_ms: float=0.) -> void:
 var s={"round":round,"phase":label,"static_mb":OS.get_static_memory_usage()/1048576.,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"textures_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.,"sprite_pages":ActionSpriteArt.textures.size(),"start_ms":start_ms,"version_signals":GameUpdates.changed.get_connections().size()}
 samples.append(s);print("MEMORY "+JSON.stringify(s))
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.frame_limit=120;Progression.vsync_enabled=false
 GameState.reset();game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 await settled();sample(-1,"menu")
 var keys=ChampionData.CHAMPIONS.keys()
 for round in range(20):
  var blue=[];var red=[]
  for i in range(3):blue.append(keys[(round*6+i)%keys.size()]);red.append(keys[(round*6+i+3)%keys.size()])
  game.network_config={"blue":blue,"red":red,"players":[{"peer":1,"name":"Test","bonuses":{},"spells":["flash","ignite"]}],"stage":1}
  var start=Time.get_ticks_usec()
  if OS.get_cmdline_user_args().has("--warm-start"):
   game.force_match_loading=true;await game._launch_game(blue[0])
  else:game._start_game(blue[0])
  await settled()
  for c in GameState.champions:
   c.is_bot=false
   for action in ActionSpriteArt.entry(c.animator.key).actions:
    for f in range(6):ActionSpriteArt.texture_for_frame(c.animator.key,action,f)
  game._spawn_wave(0);game._spawn_wave(1)
  for m in GameState.minions:game.play_sfx("hurt",m);game.spawn_spell_burst(GameState.player,m.world_pos())
  await settled();sample(round,"match",(Time.get_ticks_usec()-start)/1000.)
  check(GameState.started and is_instance_valid(GameState.player),"match starts with a valid player")
  check(game.spell_hit_times.size()<=6,"spell timing keys belong to this match")
  for path in ActionSpriteArt.textures:
   if ActionSpriteArt.cached_bytes>ActionSpriteArt.CACHE_BUDGET_BYTES:check(ActionSpriteArt.pinned_paths.has(path),"over-budget pages must belong to the current roster")
  var unit=GameState.player;var material=unit.material
  ActionSpriteArt.apply_frame_mask(material,unit.animator.key,"idle",0)
  var stamp=material.get_meta("action_frame_mask","")
  ActionSpriteArt.apply_frame_mask(material,unit.animator.key,"idle",0)
  check(material.get_meta("action_frame_mask")==stamp,"same-frame shader mask reused")
  ActionSpriteArt.apply_frame_mask(material,unit.animator.key,"attack",3)
  check(material.get_meta("action_frame_mask")!=stamp,"animation changes update the shader mask")
  game.sound_fx.last_played["stale_unit"]=-10000;game.sound_fx.next_gate_cleanup=0;game.sound_fx._prune_gates()
  check(not game.sound_fx.last_played.has("stale_unit"),"expired sound gates released")
  game._return_to_main_menu();game.set_process(false);await settled();sample(round,"menu")
  check(samples[-1].nodes==samples[0].nodes,"menu node count does not accumulate")
  check(samples[-1].orphans==samples[0].orphans,"no orphan nodes accumulate")
  check(samples[-1].version_signals==samples[0].version_signals,"menu/version connections do not accumulate")
  check(game.spell_hit_times.is_empty() and GameState.champions.is_empty() and LanSession.positions.is_empty(),"old match references cleared")
 var args=OS.get_cmdline_user_args();var pos=args.find("--memory-output")
 var output=args[pos+1] if pos>=0 else "res://tests/memory-stability.json"
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(samples," "))
 game.queue_free();GameState.reset();await settled()
 print("MEMORY STABILITY: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
