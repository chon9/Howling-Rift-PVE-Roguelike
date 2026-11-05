extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL ROSTER12 BATTLE: "+message)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false
 var cast_seen={}
 for batch in range(4):
  GameState.reset();var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game(RosterExpansion12.KEYS[batch*3])
  for i in range(6):
   var old=GameState.champions[i];var c=game.ChampionS.new();game.world_root.add_child(c)
   var key=RosterExpansion12.KEYS[(batch*3+i)%12]
   c.setup(0 if i<3 else 1,key,true,ChampionData.CHAMPIONS[key].name);c.global_position=Vector2(1350+(i%3)*45 if i<3 else 1650+(i%3)*45,270)
   c.skill_ranks=[3,3,3,2];c.inventory=["warmog","black_cleaver"] if RosterExpansion12.role(key) in ["bruiser","tank"] else ["ludens","rabadon"] if RosterExpansion12.role(key)=="caster" else ["infinity_edge","bloodthirster"];c._apply_items();c.hp=c.hp_max;c.mp=c.mp_max;GameState.champions[i]=c;old.queue_free()
  GameState.player=GameState.champions[0]
  for tower in GameState.structures:tower.atk_dmg=0.
  for frame in range(800):
   game._process(.05)
   for c in GameState.champions:
    if c.skill_cds.any(func(cd):return cd>0):cast_seen[c.hero_key]=true
   if frame%100==0:
    for c in GameState.champions:
     check(is_finite(c.hp) and is_finite(c.hp_max) and c.hp_max>0 and c.hp>=0,c.hero_key+" valid health during AI combat")
   if frame%40==0:await get_tree().process_frame
  check(GameState.champions.any(func(c):return c.deaths>0),"batch %d has real AI kills" % batch)
  var saur=GameState.champions.filter(func(c):return c.hero_key=="renekton")
  if not saur.is_empty():
   var c=saur[0];var baseline=c.hp_max
   c.buffs.clear();c._apply_items();baseline=c.hp_max;c.dead=false;c.hp=baseline;c.skill_cds[3]=0.;c.try_cast_skill(3,c.world_pos());check(c.hp_max>baseline,"Saur temporary health applied")
   game._handle_death(GameState.champions[3] if c.team==0 else GameState.champions[0],c);check(is_equal_approx(c.hp_max,baseline),"Saur death removes temporary health")
   game._respawn_champion(c);check(is_equal_approx(c.hp_max,baseline),"Saur respawn does not retain temporary health")
  game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 for key in RosterExpansion12.KEYS:check(cast_seen.has(key),key+" AI casts in live battle")
 print("ROSTER12 BATTLE: %d checks, %d failures" % [checks,failures]);get_tree().quit(0 if failures==0 else 1)
