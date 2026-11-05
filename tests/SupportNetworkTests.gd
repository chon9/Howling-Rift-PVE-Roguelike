extends Node
var game
var role="host"
var checks=0
var failures=0
var completed={}
var ready_clients={}
var armed=false
var released=false
@rpc("any_peer","call_remote","reliable")
func client_ready() -> void:ready_clients[multiplayer.get_remote_sender_id()]=true
@rpc("authority","call_remote","reliable")
func arm() -> void:armed=true
@rpc("authority","call_remote","reliable")
func release() -> void:released=true
@rpc("any_peer","call_remote","reliable")
func complete() -> void:completed[multiplayer.get_remote_sender_id()]=true
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("SUPPORT NETWORK "+role+": "+label)
func until(predicate: Callable,seconds: float=12.) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000.)
 while not predicate.call() and Time.get_ticks_msec()<end:await get_tree().create_timer(.02).timeout
 return predicate.call()
func _ready() -> void:
 role=OS.get_cmdline_user_args()[0]
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.levels.clear();Progression.difficulty=1
 game=load("res://scripts/Main.gd").new();add_child(game)
 if role=="host":
  check(LanSession.host_game()==OK,"host starts")
  LanSession.ready_player("ashe",["heal","ghost"],{})
  if not await until(func():return LanSession.players.size()==3 and LanSession.can_start()):check(false,"three peers ready");get_tree().quit(1);return
  LanSession.start_match()
  check(await until(func():return GameState.running),"all peers finish asset loading before scenario")
  for c in GameState.champions:
   c.is_bot=false;c.stop_actions()
   if c.team==1:c.dead=true;c.respawn_at=INF;c.is_targetable=false
   else:
    c.global_position=Vector2(1100+GameState.champions.find(c)*30,270);c.skill_ranks=[5,5,5,3];c.mp=c.mp_max;c.hp=c.hp_max
  var recipient=GameState.player;recipient.hp=recipient.hp_max*.3
  var healer=GameState.champions.filter(func(c):return c.hero_key=="soraka")[0]
  var guardian=GameState.champions.filter(func(c):return c.hero_key=="janna")[0]
  healer.inventory=["ardent_censer","","","","",""];healer._apply_items();guardian.inventory=["flowing_staff","","","","",""];guardian._apply_items()
  check(await until(func():return ready_clients.size()==2),"both clients finished loading")
  arm.rpc()
  check(await until(func():return healer.skill_cds[1]>0 and guardian.skill_cds[2]>0),"both guests cast support skills on host")
  check(recipient.hp>recipient.hp_max*.3 and recipient.shield>0,"host applies guest healing and shielding")
  check(recipient.buffs.has("ardent") and recipient.buffs.has("flowing"),"both support item effects are real")
  check(recipient.assist_support.size()==2,"both helpers receive support participation")
  await get_tree().create_timer(.6).timeout
  check(healer.last_order_sequence>0 and guardian.last_order_sequence>0,"movement commands acknowledged on host")
  var enemy=GameState.champions[3];enemy.dead=false;enemy.is_targetable=true;enemy.hp=enemy.hp_max;enemy.global_position=Vector2(1340,270)
  healer.try_cast_skill(2,enemy.world_pos())
  await get_tree().create_timer(.3).timeout
  check(enemy.buffs.has("silence"),"host applies support silence")
  check(await until(func():return completed.size()==2,35.),"both guests finished replication checks")
  release.rpc()
  await get_tree().create_timer(.5).timeout
 else:
  check(LanSession.join_game("127.0.0.1")==OK,"guest connects")
  if not await until(func():return LanSession.players.has(multiplayer.get_unique_id())):check(false,"lobby sync");get_tree().quit(1);return
  var key="soraka" if role=="healer" else "janna"
  LanSession.ready_player(key,["heal","ghost"],{})
  if not await until(func():return GameState.started and GameState.player.world_pos().x>1000.):check(false,"match initialized");get_tree().quit(1);return
  client_ready.rpc_id(1)
  if not await until(func():return armed):check(false,"host arms support stage");get_tree().quit(1);return
  var p=GameState.player;var recipient=GameState.champions[0];var before=p.world_pos()
  game._issue_player_order({"type":"smart","point":before+Vector2(0,35)})
  ClientMovement.tick(p,.016,before)
  check(p.world_pos().distance_to(before)>.1,"movement begins before host acknowledgement")
  check(await until(func():return p.last_order_sequence>0 and ClientMovement.commands.is_empty()),"prediction reconciles with host")
  var skill=1 if role=="healer" else 2
  p.try_cast_skill(skill,recipient.world_pos())
  check(await until(func():return p.skill_cds[skill]>0),"host authorizes targeted support cast")
  check(await until(func():return recipient.hp>recipient.hp_max*.3 and recipient.shield>0),"ally healing and shield replicated")
  check(await until(func():return recipient.buffs.has("ardent") and recipient.buffs.has("flowing")),"support boons replicated")
  check(await until(func():return GameState.aoes.any(func(a):return a.effect_id=="soraka_e") and GameState.champions[3].buffs.has("silence")),"silence effect and debuff synchronized")
  check(KitEffectArt.sheet("soraka_e")!=null,"guest has current support VFX atlas")
  complete.rpc_id(1)
  await until(func():return released,40.)
 print("SUPPORT NETWORK %s: %d checks, %d failures" % [role,checks,failures])
 LanSession.leave();game.queue_free();GameState.reset();await get_tree().process_frame;await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
