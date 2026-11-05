extends Node
var role="host"
var game
var checks=0
var failures=0
var seen={}
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL PASSIVE COOP "+role+": "+text)
func until(predicate: Callable,seconds: float=10.) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.025).timeout
 return predicate.call()
func _process(_delta: float) -> void:
 if not LanSession.is_client() or not GameState.started:return
 var target=GameState.champions[3]
 var phase=int(GameState.champions[0].passive_state.get("vision_phase",0))
 if phase==0 or seen.has(phase):return
 seen[phase]=true
 check(target.visible==BrushVision.visible_to(target,GameState.player.team),"snapshot presentation matches authoritative visibility "+str(phase))
 if phase in [1,3]:check(not target.visible and not BrushVision.visible_to(target,0),"hidden phase "+str(phase))
 else:check(target.visible,"revealed phase "+str(phase))
 if phase==5:
  check(target.buffs.has("airborne") and target.stun>0,"third attack airborne replicated")
  check(GameState.champions[0].passive_state.determination==0,"third attack passive counter replicated")
 if phase==6:
  check(GameState.champions.filter(func(c):return c.hero_key=="veigar")[0].passive_state.evil>=1,"permanent match AP counter replicated")
  check(GameState.champions.filter(func(c):return c.hero_key=="ezreal")[0].buffs.has("spell_force"),"temporary passive stacks replicated")
 if phase in [7,8,9]:
  var caster=GameState.champions[0]
  check(is_equal_approx(caster.shield,300. if phase==7 else 250. if phase==8 else 100.),"overlapping shield total replicated "+str(phase))
  if phase<9:check(is_equal_approx(caster.buffs.audit_shield.shield,200. if phase==7 else 150.),"remaining timed shield replicated "+str(phase))
  else:check(not caster.buffs.has("audit_shield"),"expired shield removed while unrelated shield stays")
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0];Progression.persistent=false;GameState.reset();game=load("res://scripts/Main.gd").new();add_child(game)
 var key="xinzhao" if role=="host" else "veigar" if role=="client1" else "ezreal"
 if role=="host":
  check(LanSession.host_game()==OK,"host starts");LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"two guests ready");LanSession.start_match();game.set_process(false)
  for i in range(GameState.champions.size()):
   var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.skill_ranks=[1,1,1,1];c.global_position=Vector2(1300+i*20,270) if c.team==0 else Vector2(2200,270);c.hp_max=50000.;c.hp=50000.;c.brush_revealed_until=-1.
  # Snapshots only flow once every peer has finished match loading; phases sent before that never reach the guests.
  check(await until(func():return GameState.running),"every peer finished match loading")
  var p=GameState.champions[0];var enemy=GameState.champions[3];var bush=BrushVision.PATCHES[2].get_center();enemy.global_position=bush
  for phase in range(1,10):
   p.passive_state.vision_phase=phase
   match phase:
    2:BrushVision.reveal(enemy,.5)
    3:GameState.time+=.6
    4:GameState.champions[1].global_position=bush+Vector2(30,0)
    5:
     p.global_position=bush-Vector2(70,0);p.try_cast_skill(0,p.world_pos());p._perform_auto(enemy);p._perform_auto(enemy);p._perform_auto(enemy)
     check(enemy.buffs.has("airborne"),"host third attack airborne")
    6:
     game.deal_damage(GameState.champions.filter(func(c):return c.hero_key=="veigar")[0],enemy,10,"magic","veigar_q");game.deal_damage(GameState.champions.filter(func(c):return c.hero_key=="ezreal")[0],enemy,10,"skill","ezreal_q")
    7:p.shield=100.;CombatEffects.shield(p,"audit_shield",200.,3.)
    8:enemy.difficulty_stats=Progression.scaling(1);game.deal_damage(enemy,p,50.,"auto")
    9:ExpansionCombat.expire(p,"audit_shield");p.buffs.erase("audit_shield")
   for frame in range(12):GameState.time+=.05;LanSession.replicate(.05);await get_tree().create_timer(.05).timeout
  game._end_game(Constants.BLUE);await get_tree().create_timer(.6).timeout
  await until(func():return LanSession.players.size()==1,3.)
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives");LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return GameState.started),"match arrives");game.set_process(false)
  # started is set before the host releases the loading barrier; "not running" must mean the match ended, not that it is still loading.
  check(await until(func():return GameState.running),"match loading released")
  check(await until(func():return not GameState.running,12.),"result arrives")
  check(seen.size()==9,"all visibility/passive phases arrived")
  await get_tree().create_timer(.3 if role=="client1" else .6).timeout
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 print("PASSIVE COOP %s: %d checks, %d failures" % [role,checks,failures]);get_tree().quit(0 if failures==0 else 1)
