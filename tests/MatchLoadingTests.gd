extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("MATCH LOADING: "+message)
func frames(count: int=4) -> void:
 for i in range(count):await get_tree().process_frame
func _ready() -> void:
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.frame_limit=120;Progression.vsync_enabled=false
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game.force_match_loading=true
 var baseline_orphans=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
 for key in ChampionData.CHAMPIONS:
  var plan=MatchLoading.resource_plan([key])
  check(plan.actions.size()>=6,"all minions and selected hero included: "+key)
  for path in plan.paths:check(ResourceLoader.exists(path),"planned resource exists: "+path)
  check(not plan.actions.keys().any(func(path):return path.contains("heroes/") and not ActionSpriteArt.pinned_paths.has(path) and not path in _hero_paths(key)),"plan has no unrelated hero action pages")
 var lineups=[["thresh","yasuo","soraka","veigar","caitlyn","janna"],["leona","brand","renekton","riven","syndra","lucian"]]
 for heroes in lineups:
  game.network_config={"blue":heroes.slice(0,3),"red":heroes.slice(3),"players":[{"peer":1,"name":"Test","bonuses":{},"spells":["flash","heal"]}],"stage":1}
  game._launch_game(heroes[0])
  check(not GameState.running and not GameState.started,"simulation waits while assets load")
  var waiting_frames=0;var deadline=Time.get_ticks_msec()+20000
  while not GameState.running and Time.get_ticks_msec()<deadline:
   check(GameState.time==0.,"no XP, waves or combat time consumed during warmup")
   await get_tree().process_frame;waiting_frames+=1
  check(GameState.running and GameState.started,"launch completes")
  if not GameState.running:get_tree().quit(1);return
  var loader=game.match_loader
  check(loader!=null and not loader.pending and loader.errors.is_empty(),"all loading requests completed")
  check(not is_instance_valid(loader.overlay),"loading UI dismissed")
  check(GameState.champions.map(func(c):return c.hero_key)==heroes,"warmed and spawned rosters match")
  check(GameState.time==0. and GameState.minions.is_empty(),"match begins at time zero")
  var pages=ActionSpriteArt.textures.size();var delays=[]
  for key in ActionSpriteArt.manifest:
   if not key.begins_with("minion_") and key.trim_prefix("hero_") not in heroes:continue
   var data=ActionSpriteArt.entry(key)
   for action in data.actions:
    var start=Time.get_ticks_usec()
    for frame in range(6):
     var path=str(ActionSpriteArt.frame(key,action,frame).get("path",data.path))
     check(loader.resources.has(path) and ResourceLoader.has_cached(path),"all action variants resident before first cast")
     ActionSpriteArt.texture_for_frame(key,action,frame)
    await get_tree().process_frame;delays.append((Time.get_ticks_usec()-start)/1000.)
  check(ActionSpriteArt.textures.size()==pages,"first actions never populate new sprite pages")
  for hero in heroes:
   for skill in ["q","w","e","r","auto"]:
    var id=hero+"_"+skill
    if KitEffectArt.has_effect(id):
     var texture=KitEffectArt.sheet(id)
     check(loader.resources.has(texture.resource_path),"skill sheet retained before first use: "+id)
     for frame in range(4):KitEffectArt.region(id,frame)
  for id in StatusArt.TYPES:check(loader.resources.has(StatusArt.texture(id).resource_path),"all buff/debuff atlases warm")
  for row in range(6):check(loader.resources.has(CombatFeedbackArt.banner_texture(row).resource_path),"every kill crest warm")
  delays.sort();print("WARM START "+JSON.stringify(loader.stats)+" FIRST ACTION MAX MS "+str(delays[-1])+" P95 "+str(delays[int(delays.size()*.95)]))
  game._return_to_main_menu();game.set_process(false);await frames()
  check(not is_instance_valid(loader),"match resource owner released at menu")
  check(get_tree().root.get_children().filter(func(n):return n is MatchLoading).is_empty(),"no stale root loader")
 # Cancel with actual in-flight requests, then immediately relaunch to exercise request cleanup.
 game._launch_game("annie");await frames(2)
 var abandoned=game.match_loader
 game._return_to_main_menu();game.set_process(false)
 game._launch_game("lux")
 var deadline=Time.get_ticks_msec()+20000
 while not GameState.running and Time.get_ticks_msec()<deadline:await get_tree().process_frame
 check(GameState.running and GameState.player.hero_key=="lux","cancelled launch cannot resurrect old match")
 await frames();check(not is_instance_valid(abandoned),"cancelled background tasks drain and owner is released")
 check(get_tree().root.get_children().filter(func(n):return n is MatchLoading).size()==1,"exactly one current loader after cancellation")
 game._return_to_main_menu();game.set_process(false);await frames()
 check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==baseline_orphans,"no orphan warmup nodes")
 game.queue_free();GameState.reset();await frames()
 print("MATCH LOADING: %d checks, %d failures" % [checks,failures]);get_tree().quit(0 if failures==0 else 1)
func _hero_paths(key: String) -> Array:
 var data=ActionSpriteArt.entry("hero_"+key);var paths=[data.path]
 for cell in data.frames:
  var path=str(cell.get("path",data.path))
  if path not in paths:paths.append(path)
 return paths
