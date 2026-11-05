class_name BotDodge
extends RefCounted
static func update(c, delta: float) -> bool:
 if c.stun>0 or c.is_dashing: return false
 if GameState.time<c.dodge_until:
  c.cancel_auto();c.attack_target=null;c.attack_move=false;c.has_move_target=true;c.move_target=c.dodge_destination
  return true
 var seen={}
 for p in GameState.projectiles:
  if not is_instance_valid(p) or p.team==c.team or p.targeted or p.is_turret or p.damage_type=="auto" or p.hit_set.has(c): continue
  # Bots react to a visible projectile, not the hidden caster or the future cast.
  if p.global_position.distance_to(c.world_pos())>700: continue
  var relative=c.world_pos()-p.global_position
  var along=relative.dot(p.dir)
  if along<=0:continue
  var impact=along/maxf(1,p.speed)
  if impact>1.4 or impact>p.life:continue
  var clearance=p.size+c.size*.7+18
  var lateral=relative.dot(p.dir.orthogonal())
  if absf(lateral)>clearance:continue
  var id=p.get_instance_id();seen[id]=true
  c.dodge_noticed[id]=c.dodge_noticed.get(id,0.)+delta
  if c.dodge_noticed[id]<c.difficulty_stats.get("reaction",.3):continue
  var escape=maxf(12,clearance-absf(lateral)+12)
  if escape/maxf(1,c.effective_move_speed())>impact:continue
  var choices=[p.dir.orthogonal(),-p.dir.orthogonal()]
  if lateral<0:choices.reverse()
  for side in choices:
   var desired=c.world_pos()+side*escape
   var point=GameState.clamp_walkable(desired)
   if point.distance_to(desired)>4 or not BotSafety.can_enter(c,point):continue
   c.dodge_destination=point;c.dodge_until=GameState.time+minf(.5,escape/maxf(1,c.effective_move_speed())+.08)
   c.cancel_auto();c.attack_target=null;c.attack_move=false;c.has_move_target=true;c.move_target=point;c.manual_move=Vector2.ZERO
   return true
 for id in c.dodge_noticed.keys():
  if not seen.has(id):c.dodge_noticed.erase(id)
 return false
