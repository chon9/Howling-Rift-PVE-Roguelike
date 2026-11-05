class_name ClientMovement
extends RefCounted
# Predict locomotion only; hits, skills, resources and all combat stay authoritative.
static var sequence=0
static var commands: Array=[]
static func clear() -> void:sequence=0;commands.clear()
static func order(c,data: Dictionary) -> Dictionary:
 sequence=maxi(sequence,c.last_order_sequence)+1
 var result=data.duplicate();result.sequence=sequence
 var target=GameState.find_target_at(data.point,c.team,8) if data.type=="smart" else GameState.find_attack_move_target(c,data.point,true)
 commands.append({"sequence":sequence,"point":GameState.clamp_walkable(data.point),"target":target})
 if commands.size()>64:commands.pop_front()
 if target!=c.attack_target:c.cancel_auto()
 c.recall_time=-1.
 return result
static func cancel() -> void:commands.clear()
static func tick(c,delta: float,server_target: Vector2) -> bool:
 while not commands.is_empty() and commands[0].sequence<=c.last_order_sequence:commands.pop_front()
 if c.dead or c.stun>0 or c.buffs.has("monsoon") or c.is_dashing or c.buffs.has("forced_motion") or c.buffs.has("root"):commands.clear();return false
 var point=Vector2.ZERO
 if not commands.is_empty():
  var order=commands.back();point=order.point
  if is_instance_valid(order.target) and not order.target.dead:
   var reach=c.auto_attack_reach(order.target)
   point=c.world_pos() if c.world_pos().distance_to(order.target.world_pos())<=reach else order.target.world_pos()+(c.world_pos()-order.target.world_pos()).normalized()*maxf(0.,reach-6.)
 elif c.has_move_target:point=c.move_target
 else:return false
 if c.queued_auto_target!=null or (c.anim_action=="attack" and not c.anim_released and commands.is_empty()):return false
 var offset=point-c.world_pos()
 if offset.length()>2.:
  offset=UnitCollision.steer(c,point,UnitCollision.HERO_RADIUS,c.attack_target)-c.world_pos()
  c.facing=offset.normalized();c.global_position=GameState.clamp_walkable(c.world_pos()+offset.limit_length(c.effective_move_speed()*minf(delta,.1)))
  UnitCollision.resolve_champion(c)
 # Don't pull against a newer local order before the host acknowledges it.
 if commands.is_empty():
  var error=server_target-c.world_pos()
  if error.length()>140.:c.global_position=server_target
  else:c.global_position+=error*(1.-exp(-delta*6.))
 return true
