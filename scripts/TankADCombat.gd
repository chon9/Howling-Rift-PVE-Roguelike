class_name TankADCombat
extends RefCounted
static func spellblade_damage(c) -> float:
 var amount=c.ad*.75 if c.inventory.has("sheen") else 0.
 if c.inventory.has("trinity"):amount=maxf(amount,c.ad*1.5)
 if c.inventory.has("essence_reaver"):amount=maxf(amount,c.ad*.8+c.bonus_ad*.2)
 return amount
static func damage_multiplier(src,target,kind: String) -> float:
 var mult=1.
 if is_instance_valid(src) and src.kind=="champion" and src.inventory.has("shojin") and kind in ["skill","magic","physical"]:
  mult*=1.+.03*src.buffs.get("shojin",{}).get("stacks",0)
 if target.kind!="champion" or kind=="exec":return mult
 var magic=ExpansionCombat.is_magic(src,kind)
 if not magic and target.inventory.has("deaths_dance"):mult*=.85
 if magic and target.inventory.has("force_nature") and target.buffs.has("nature_guard"):mult*=.85
 if kind in ["auto","secondary_auto","attack_fragment"]:
  if target.inventory.has("plated_steelcaps"):mult*=.9
  if target.inventory.has("randuin"):mult*=.85
 return mult
static func on_damage(src,target,kind: String,damage: float) -> void:
 if damage<=0:return
 if is_instance_valid(src) and src.kind=="champion" and target.kind=="champion":
  for c in [src,target]:
   var since=c.buffs.get("item_combat",{}).get("since",GameState.time)
   c.buffs.item_combat={"time":4.,"since":since}
 if target.kind!="champion":return
 if target.inventory.has("force_nature") and ExpansionCombat.is_magic(src,kind):
  var stacks=mini(3,int(target.buffs.get("nature_stacks",{}).get("stacks",0))+1)
  target.buffs.nature_stacks={"time":8.,"stacks":stacks}
  if stacks==3:target.buffs.nature_guard={"time":5.}
 if kind in ["auto","secondary_auto"] and is_instance_valid(src) and src.kind in ["champion","minion"]:
  if target.inventory.has("bramble") or target.inventory.has("thornmail"):src.buffs.grievous={"time":3.}
  if target.inventory.has("randuin") and src.kind=="champion" and not src.buffs.has("cc_guard"):src.buffs.slow={"time":maxf(1.,src.buffs.get("slow",{}).get("time",0.)),"pct":maxf(.2,src.buffs.get("slow",{}).get("pct",0.))}
static func on_spell(src,target,kind: String) -> void:
 if not is_instance_valid(src) or src.kind!="champion" or target.kind=="structure":return
 if src.inventory.has("shojin") and kind in ["skill","magic","physical"]:
  src.buffs.shojin={"time":4.,"stacks":mini(3,int(src.buffs.get("shojin",{}).get("stacks",0))+1)}
 if src.inventory.has("mortal_reminder") and (kind=="auto" or kind=="physical" or (kind=="skill" and not ExpansionCombat.is_magic(src,kind))):target.buffs.grievous={"time":3.}
static func lifeline(c,kind: String,projected_hp: float=-1.) -> void:
 if c.kind!="champion" or c.hp<=0:return
 var health=c.hp if projected_hp<0. else projected_hp
 var magic=kind=="magic" or kind in ["item_magic","burn","passive_magic"] or kind=="legacy_magic"
 var shield_ratio=.25 if c.inventory.has("sterak") else .25 if magic and c.inventory.has("maw") else .15 if magic and c.inventory.has("hexdrinker") else 0.
 var ready=true
 for item in ["sterak","maw","hexdrinker"]:
  if c.item_cds.get(item,0.)>0:ready=false
 if shield_ratio>0 and ready and health<c.hp_max*.3:
  for item in ["sterak","maw","hexdrinker"]:c.item_cds[item]=60.
  var grant=c.hp_max*shield_ratio
  c.shield+=grant;c.buffs.lifeline={"time":3.,"shield":grant}
 if c.inventory.has("locket") and health<c.hp_max*.35 and c.item_cds.get("locket",0.)<=0:
  c.item_cds.locket=60.
  for ally in GameState.champions:
   if ally.team!=c.team or ally.dead or ally.world_pos().distance_to(c.world_pos())>250:continue
   var grant=120.+c.hp_max*.08
   # One Locket shield per ally; refresh without stacking multiple owners.
   var previous=ally.buffs.get("locket_shield",{}).get("shield",0.)
   grant=maxf(grant,previous)
   ally.shield=maxf(0.,ally.shield-previous)+grant;HeroPassives.support(c,ally)
   ally.buffs.locket_shield={"time":3.,"shield":grant}
static func consume_shield(c,amount: float) -> float:
 if not "buffs" in c:return amount
 for key in c.buffs:
  if c.buffs[key].has("shield"):
   var used=minf(amount,c.buffs[key].shield)
   c.buffs[key].shield-=used;amount-=used
 return amount
static func after_hit(src,target,kind: String) -> void:
 if kind!="auto" or not is_instance_valid(src) or src.kind!="champion" or src.dead or target.kind=="structure":return
 if src.inventory.has("sundered_sky") and target.kind=="champion":
  var key="sundered_"+str(target.get_instance_id())
  if src.item_cds.get(key,0.)<=0:
   src.item_cds[key]=6.;src.hp=minf(src.hp_max,src.hp+src.hp_max*.04*ExpansionCombat.healing_multiplier(src))
   if not target.dead and target.hp>0:NewHeroKits.hit(src,target,src.ad*.3,"item_physical")
 if src.inventory.has("titanic_hydra") and not target.dead and target.hp>0:NewHeroKits.hit(src,target,src.hp_max*.01,"item_physical")
 if src.inventory.has("kraken") and not target.dead and target.hp>0:
  var previous=src.buffs.get("kraken",{})
  var stacks=int(previous.get("stacks",0))+1 if previous.get("target_id",0)==target.get_instance_id() else 1
  src.buffs.kraken={"time":5.,"target_id":target.get_instance_id(),"stacks":stacks%3}
  if stacks==3:NewHeroKits.hit(src,target,30.+src.ad*.45,"item_physical")
 if src.inventory.has("dead_mans") and src.buffs.get("momentum",{}).get("stacks",0.)>=100.:
  src.buffs.momentum.stacks=0.
  if not target.dead and target.hp>0:
   if not target.buffs.has("cc_guard") and not target.buffs.has("spell_guard"):target.buffs.slow={"time":1.5,"pct":.3}
   NewHeroKits.hit(src,target,50.,"item_physical")
 var cleave=src.ad*.2 if src.inventory.has("tiamat") else 0.
 if src.inventory.has("ravenous_hydra"):cleave=maxf(cleave,src.ad*.35)
 if src.inventory.has("titanic_hydra"):cleave=maxf(cleave,10.+src.hp_max*.015)
 if cleave>0:
  for other in (GameState.champions+GameState.minions).duplicate():
   if other==target or other.dead or other.team==src.team or not other.is_targetable or other.world_pos().distance_to(target.world_pos())>100:continue
   NewHeroKits.hit(src,other,cleave,"item_physical")
static func tick(c,delta: float) -> void:
 if c.kind!="champion" or c.dead:return
 if c.inventory.has("dead_mans"):
  var old=c.buffs.get("momentum",{})
  var movement=c.world_pos().distance_to(Vector2(old.get("x",c.world_pos().x),old.get("y",c.world_pos().y)))
  var stacks=clampf(old.get("stacks",0.)+minf(movement,30.)*.2 if movement>0.1 else old.get("stacks",0.)-delta*20.,0.,100.)
  c.buffs.momentum={"time":60.,"stacks":stacks,"x":c.world_pos().x,"y":c.world_pos().y}
 var burn=14.+c.hp_max*.01 if c.inventory.has("sunfire") or c.inventory.has("hollow_radiance") else 8.+c.hp_max*.005 if c.inventory.has("bami") else 0.
 if burn>0 and c.item_cds.get("immolate",0.)<=0:
  c.item_cds.immolate=1.
  for enemy in (GameState.champions+GameState.minions).duplicate():
   if enemy.team!=c.team and not enemy.dead and enemy.is_targetable and c.world_pos().distance_to(enemy.world_pos())<=170:NewHeroKits.hit(c,enemy,minf(40.,burn) if enemy.kind=="minion" else burn,"item_magic")
 if c.inventory.has("unending_despair") and c.item_cds.get("despair",0.)<=0:
  c.item_cds.despair=5.
  for enemy in GameState.champions.duplicate():
   if enemy.team==c.team or enemy.dead or c.world_pos().distance_to(enemy.world_pos())>180:continue
   var before=maxf(0.,enemy.hp)
   NewHeroKits.hit(c,enemy,20.+c.hp_max*.012,"item_magic")
   c.hp=minf(c.hp_max,c.hp+maxf(0.,before-maxf(0.,enemy.hp))*.5*ExpansionCombat.healing_multiplier(c))
static func champion_kill(c) -> void:
 if not is_instance_valid(c) or c.kind!="champion" or c.dead:return
 if c.inventory.has("deaths_dance"):c.hp=minf(c.hp_max,c.hp+c.hp_max*.1*ExpansionCombat.healing_multiplier(c))
 if c.inventory.has("collector"):c.gold+=25
