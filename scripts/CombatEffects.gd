class_name CombatEffects
extends RefCounted
static func shield(c,key: String,amount: float,seconds: float,source=null,procs: bool=true) -> void:
 if is_instance_valid(source):amount*=SupportCombat.power(source)
 var previous=float(c.buffs.get(key,{}).get("shield",0.))
 var grant=maxf(previous,amount)
 c.shield=maxf(0.,c.shield-previous)+grant
 c.buffs[key]={"time":seconds,"shield":grant}
 if is_instance_valid(source):
  HeroPassives.support(source,c)
  if procs:SupportCombat.on_help(source,c)
static func overheal(c,amount: float) -> void:
 var previous=float(c.buffs.get("bloodthirster_shield",{}).get("shield",0.))
 shield(c,"bloodthirster_shield",minf(c.hp_max*.15,previous+maxf(0.,amount)),9999.)
