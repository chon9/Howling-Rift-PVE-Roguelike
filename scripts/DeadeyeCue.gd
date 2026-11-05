class_name DeadeyeCue
extends RefCounted
# Presentation derives from the same remaining time and target reference as the host.
static func channel(c) -> Dictionary:
 if not is_instance_valid(c) or c.dead or not c.buffs.has("deadeye"):return {}
 var b=c.buffs.deadeye
 var target=Roster12Kits.resolve(b.target)
 if not is_instance_valid(target) or target.dead or not target.is_targetable:return {}
 var duration=maxf(.01,float(b.get("duration",1.)))
 var remaining=clampf(float(b.time),0.,duration)
 if remaining<=0:return {}
 return {"target":target,"time":remaining,"duration":duration,"progress":1.-remaining/duration,"serial":int(b.get("serial",c.anim_serial))}
static func visible(c) -> bool:
 return is_instance_valid(c) and (not is_instance_valid(GameState.player) or BrushVision.visible_to(c,GameState.player.team))
static func locks_on(target) -> Array:
 var locks=[]
 if not is_instance_valid(target) or target.kind!="champion" or not visible(target):return locks
 for c in GameState.champions:
  if not visible(c):continue
  var b=channel(c)
  if not b.is_empty() and b.target==target:locks.append(b)
 return locks
