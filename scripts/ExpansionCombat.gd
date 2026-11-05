class_name ExpansionCombat
extends RefCounted
static func healing_multiplier(c) -> float:
 return (1.25 if c.inventory.has("spirit_visage") else 1.)*(.6 if c.buffs.has("grievous") else 1.)
static func is_magic(src,kind: String) -> bool:
 return kind in ["magic","item_magic","burn","passive_magic"] or (kind=="skill" and is_instance_valid(src) and src.kind=="champion" and src.hero_key in ["lux","ahri","annie","katarina","kayle"])
static func resist(target,src,kind: String) -> float:
 var magic=is_magic(src,kind)
 var armor=target.bonus_mr+target.base_mr if magic and target.kind=="champion" else target.bonus_armor if "bonus_armor" in target else 0.
 if target.kind=="champion":armor+=target.difficulty_stats.get("magic_resist" if magic else "armor",0.)
 if target.kind=="champion" and target.inventory.has("jaksho") and target.buffs.has("item_combat") and GameState.time-target.buffs.item_combat.since>=3.:armor+=20.
 if not magic and "buffs" in target and target.buffs.has("armor_shred"):armor*=1.-target.buffs.armor_shred.stacks*.05
 if is_instance_valid(src) and src.kind=="champion":
  armor*=1.-(src.bonus_magic_pen if magic else src.bonus_armor_pen)
  if not magic:armor-=src.bonus_lethality
 return maxf(0,armor)
static func spell_block(target,kind: String) -> bool:
 if target.kind!="champion" or kind not in ["skill","magic","physical"]:return false
 if target.inventory.has("banshee") and target.item_cds.get("banshee",0.)<=0:
  target.item_cds.banshee=35.;target.buffs.spell_guard={"time":.12};return true
 return false
static func on_spell(src,target,kind: String) -> void:
 TankADCombat.on_spell(src,target,kind)
 if not is_instance_valid(src) or src.kind!="champion" or target.kind=="structure" or kind not in ["skill","magic","physical"]:return
 if src.inventory.has("liandry"):
  var next_tick=target.buffs.get("item_burn",{}).get("tick",1.)
  target.buffs.item_burn={"time":3.,"tick":next_tick,"src":src}
 if src.inventory.has("morello"):target.buffs.grievous={"time":3.}
static func after_hit(src,target,kind: String) -> void:
 Roster12Combat.after_hit(src,target,kind)
 if kind=="secondary_auto":kind="auto"
 TankADCombat.after_hit(src,target,kind)
 if kind!="auto" or not is_instance_valid(src) or src.kind!="champion" or target.dead or target.kind=="structure":return
 if src.hero_key=="thresh" and src.rank(2)>0:
  var charge=src.flay_charge;src.flay_charge=0.
  NewHeroKits.hit(src,target,src.ad*(.2+.2*src.rank(2))*charge,"item_magic")
 if src.inventory.has("black_cleaver"):
  target.buffs.armor_shred={"time":4.,"stacks":mini(4,int(target.buffs.get("armor_shred",{}).get("stacks",0))+1)}
 if src.inventory.has("nashor"):NewHeroKits.hit(src,target,15.+src.bonus_ap*.15,"item_magic")
static func silver_hit(src,target) -> void:
 if src.rank(1)<=0 or target.kind=="structure":return
 ExpansionKits.tick(src,0.)
 if src.buffs.has("silver") and not target.dead:
  var buff=src.buffs.silver
  if buff.target_id!=target.get_instance_id():buff.target_id=target.get_instance_id();buff.stacks=0
  buff.stacks+=1
  if buff.stacks>=3:
   buff.stacks=0
   NewHeroKits.hit(src,target,minf(80,target.hp_max*buff.ratio) if target.kind=="minion" else target.hp_max*buff.ratio,"exec")
static func lifeline(target,kind: String="auto",src=null) -> void:
 TankADCombat.lifeline(target,"legacy_magic" if is_magic(src,kind) else kind)
static func tick(c,delta: float) -> void:
 TankADCombat.tick(c,delta)
 if c.kind=="champion" and c.inventory.has("frozen_heart"):
  for enemy in GameState.champions+GameState.minions:
   if enemy.team!=c.team and not enemy.dead and enemy.world_pos().distance_to(c.world_pos())<300:enemy.buffs.cripple={"time":.2}
 if c.buffs.has("item_burn"):
  var burn=c.buffs.item_burn;burn.tick-=delta
  if burn.tick<=0:
   burn.tick=1.
   if is_instance_valid(burn.src):NewHeroKits.hit(burn.src,c,minf(30,c.hp_max*.01) if c.kind=="minion" else c.hp_max*.01,"burn")
static func expire(c,key: String) -> void:
 if c.buffs[key].has("shield"):c.shield=maxf(0,c.shield-c.buffs[key].shield)
