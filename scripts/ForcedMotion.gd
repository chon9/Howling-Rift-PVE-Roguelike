class_name ForcedMotion
extends RefCounted
static func apply(unit,direction: Vector2,distance: float,duration: float=.25) -> void:
 if unit.buffs.has("parry"):unit.buffs.parry.blocked_cc=true;return
 if unit.dead or unit.buffs.has("cc_guard") or unit.buffs.has("spell_guard"):return
 unit.buffs.forced_motion={"time":duration,"destination":GameState.clamp_walkable(unit.world_pos()+direction.normalized()*distance)}
 unit.stun=maxf(unit.stun,duration)
 if "is_dashing" in unit:unit.is_dashing=false
static func tick(unit,delta: float) -> void:
 if not unit.buffs.has("forced_motion"):return
 var motion=unit.buffs.forced_motion
 unit.global_position=unit.world_pos().lerp(motion.destination,minf(1.,delta/maxf(.001,motion.time)))
