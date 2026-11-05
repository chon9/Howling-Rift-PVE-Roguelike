extends Node
var role="host"
var batch=0
var checks=0
var failures=0
var game
var seen_effects={}
var seen_recasts={}
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL ROSTER12 COOP "+role+": "+message)
func until(predicate: Callable,seconds: float=10.) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.025).timeout
 return predicate.call()
func _process(_delta: float) -> void:
 if not GameState.started:return
 for effect in GameState.projectiles+GameState.aoes:
  if is_instance_valid(effect) and effect.effect_id.get_slice("_",0) in RosterExpansion12.KEYS:
   seen_effects[effect.effect_id]=true
   if LanSession.is_client():
    if not is_instance_valid(effect.src):check(false,"effect lost its owner: "+effect.effect_id)
 for c in GameState.champions:
  for index in range(4):
   if not NewHeroKits.recast_info(c,index).is_empty():seen_recasts[c.hero_key+str(index)]=true
func _ready() -> void:
 var args=OS.get_cmdline_user_args();role=args[0]
 var pos=args.find("--roster-batch")
 if pos>=0:batch=int(args[pos+1])
 Progression.persistent=false;GameState.reset();game=load("res://scripts/Main.gd").new();add_child(game)
 var offset=0 if role=="host" else 1 if role=="client1" else 2
 var key=RosterExpansion12.KEYS[batch*3+offset]
 if role=="host":
  check(LanSession.host_game()==OK,"host starts")
  LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return LanSession.players.size()==3 and LanSession.can_start()),"two guests ready")
  LanSession.start_match();game.set_process(false)
  for i in range(GameState.champions.size()):
   var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.global_position=Vector2(1320+i*20,270) if c.team==0 else Vector2(1480+(i-3)*90,270)
   c.skill_ranks=[1,1,1,1];c.skill_cds=[0.,0.,0.,0.];c.hp_max=50000.;c.hp=50000.;c.mp_max=1000.;c.mp=1000.;c.hp_regen=0.
  var casts={}
  for frame in range(240):
   if frame in [10,40,70,100]:
    var index=[10,40,70,100].find(frame);GameState.player.try_cast_skill(index,GameState.champions[3].world_pos())
   if frame in [20,50,80,110]:
    var index=[20,50,80,110].find(frame)
    if not NewHeroKits.recast_info(GameState.player,index).is_empty():GameState.player.try_cast_skill(index,GameState.champions[3].world_pos())
   for c in GameState.champions:
    c.update_frame(.05)
    for i in range(4):
     if c.skill_cds[i]>0:casts[c.hero_key+str(i)]=true
   for p in GameState.projectiles.duplicate():if is_instance_valid(p) and not p.is_queued_for_deletion():p.update_frame(.05)
   for a in GameState.aoes.duplicate():if is_instance_valid(a) and not a.is_queued_for_deletion():a.update_frame(.05)
   GameState.time+=.05;LanSession.replicate(.05);await get_tree().create_timer(.05).timeout
  for c in GameState.champions.slice(0,3):
   for i in range(4):check(casts.has(c.hero_key+str(i)),c.hero_key+" skill "+str(i)+" ran authoritatively")
  game._end_game(Constants.BLUE);await get_tree().create_timer(.6).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  check(await until(func():return LanSession.players.has(multiplayer.get_unique_id())),"lobby arrives")
  LanSession.ready_player(key,["flash","heal"],{})
  check(await until(func():return GameState.started),"match arrives")
  game.set_process(false)
  var p=GameState.player
  check(p.hero_key==key and p.owner_peer==multiplayer.get_unique_id(),"guest owns selected new hero")
  check(await until(func():return p.skill_ranks[3]>0),"ranks arrive")
  for i in range(4):
   p.try_cast_skill(i,GameState.champions[3].world_pos())
   check(await until(func():return p.skill_cds[i]>0,2.),key+" skill "+str(i)+" confirmed by host")
   check(await until(func():return p.anim_action==["q","w","e","r"][i],.5),key+" matching cast animation")
   if not NewHeroKits.recast_info(p,i).is_empty():
    var mana=p.mp
    await get_tree().create_timer(.2).timeout;p.try_cast_skill(i,GameState.champions[3].world_pos())
    check(await until(func():return p.mp>=mana,1.),key+" recast does not spend mana again")
   await get_tree().create_timer(.95).timeout
  check(await until(func():return not GameState.running,15.),"match result arrives")
  check(seen_effects.keys().any(func(id):return id.begins_with(key+"_")),"guest renders own hero's generated effects")
  for id in seen_effects:
   check(KitEffectArt.has_effect(id) and KitEffectArt.sheet(id)!=null,"guest maps modern effect "+id)
  if key in ["renekton","riven","syndra","xerath"]:check(not seen_recasts.is_empty(),"recast state and timer arrived")
 if role=="host":await until(func():return LanSession.players.size()==1,3.);await get_tree().create_timer(.3).timeout
 else:await get_tree().create_timer(.3 if role=="client1" else .6).timeout
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame
 print("ROSTER12 COOP %s batch %d: %d checks, %d failures" % [role,batch,checks,failures])
 get_tree().quit(0 if failures==0 else 1)
