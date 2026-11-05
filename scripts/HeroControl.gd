class_name HeroControl
extends RefCounted
static func airborne(unit,seconds: float) -> void:
 if not is_instance_valid(unit) or unit.dead or not "buffs" in unit:return
 if unit.buffs.has("parry"):unit.buffs.parry.blocked_cc=true;return
 if unit.buffs.has("cc_guard") or unit.buffs.has("spell_guard") or unit.buffs.has("spell_ward"):return
 unit.buffs.airborne={"time":seconds,"duration":seconds}
 unit.stun=maxf(unit.stun,seconds)
 if unit.kind=="champion":unit.stop_actions();unit.is_dashing=false
static func lift(unit) -> float:
 if not unit.buffs.has("airborne"):return 0.
 var b=unit.buffs.airborne
 return sin(PI*clampf(1.-b.time/b.duration,0.,1.))*30.
