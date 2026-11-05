class_name SupportKits
extends RefCounted
static func ap(c) -> float:return c.bonus_ap
static func amount(c,index: int) -> float:
 var r=c.rank(index);var a=ap(c)
 if c.hero_key=="soraka":return [40.+35.*r+a*.45,45.+40.*r+a*.65,40.+30.*r+a*.4,90.+85.*r+a*.65][index]
 return [35.+30.*r+a*.4,35.+30.*r+a*.5,45.+35.*r+a*.6,20.+10.*r+a*.12][index]
static func visual(c,point: Vector2,radius: float,id: String,seconds: float=.45) -> void:
 NewHeroKits.area(c,point,radius,0.,{"effect_id":id,"duration":seconds})
static func ally_target(c,point: Vector2,reach: float,allow_self: bool):
 var best=null;var gap=70.
 for ally in GameState.champions:
  if ally.dead or not ally.roster_active or ally.team!=c.team or c.world_pos().distance_to(ally.world_pos())>reach:continue
  var distance=point.distance_to(ally.world_pos())
  if distance<gap:best=ally;gap=distance
 return null if best==c and not allow_self else best
static func cast(c,id: String,point: Vector2) -> bool:
 var index=["q","w","e","r"].find(id.get_slice("_",1));var value=amount(c,index)
 match id:
  "soraka_q":NewHeroKits.area(c,point,105.,value,{"effect_id":id,"arm_delay":.4,"duration":.75,"slow":.3,"slow_dur":2.,"damage_type":"magic"})
  "soraka_w":
   var ally=ally_target(c,point,370.,false);var cost=c.hp_max*.08*(.5 if c.buffs.has("rejuvenation") else 1.)
   if ally==null or ally.hp>=ally.hp_max or c.hp<=cost:return false
   c.hp-=cost;SupportCombat.heal(c,ally,value);visual(c,ally.world_pos(),28.,id)
   if c.buffs.has("rejuvenation"):ally.buffs.rejuvenation_shared={"time":3.,"heal":(14.+8.*c.rank(0)+ap(c)*.1)*SupportCombat.power(c),"src":c}
  "soraka_e":NewHeroKits.area(c,point,120.,value,{"effect_id":id,"zone_kind":"silence_field","duration":1.5,"damage_type":"magic"})
  "soraka_r":
   for ally in GameState.champions:
    if ally.team!=c.team or ally.dead or not ally.roster_active:continue
    SupportCombat.heal(c,ally,value*(1.35 if ally.hp<ally.hp_max*.4 else 1.));visual(c,ally.world_pos(),35.,id,.6)
  "janna_q":c.buffs.gale_charge={"time":3.,"origin":c.world_pos(),"direction":(point-c.world_pos()).normalized(),"elapsed":0.};visual(c,c.world_pos(),30.,id,.35)
  "janna_w":
   var target=NewHeroKits.target(c,point,390.)
   if target==null:return false
   NewHeroKits.projectile(c,c.world_pos(),(target.world_pos()-c.world_pos()).normalized(),value,{"effect_id":id,"homing":target,"targeted":true,"speed":800.,"life":1.,"slow":.3+.04*c.rank(1),"slow_dur":2.,"damage_type":"magic","no_structures":true})
  "janna_e":
   var ally=ally_target(c,point,400.,true)
   if ally==null:return false
   CombatEffects.shield(ally,"storm_shield",value,4.,c);ally.buffs.storm_shield.ad=5.+5.*c.rank(2)+ap(c)*.08;ally._apply_items();visual(c,ally.world_pos(),32.,id)
  "janna_r":
   c.cancel_auto();c.attack_target=null;c.attack_move=false;c.has_move_target=false;c.manual_move=Vector2.ZERO
   c.buffs.monsoon={"time":3.,"origin":c.world_pos(),"tick":0.}
   visual(c,c.world_pos(),240.,id,3.)
   for enemy in GameState.champions+GameState.minions:
    if enemy.dead or enemy.team==c.team or c.world_pos().distance_to(enemy.world_pos())>240. or enemy.buffs.has("cc_guard") or enemy.buffs.has("spell_guard") or enemy.buffs.has("parry"):continue
    ForcedMotion.apply(enemy,enemy.world_pos()-c.world_pos(),150.)
  _:return false
 return true
static func recast_info(c,index: int) -> Dictionary:
 if c.hero_key=="janna" and index==0 and c.buffs.has("gale_charge"):return {"time":c.buffs.gale_charge.time,"duration":3.,"label":"Q RELEASE","available":true}
 if c.hero_key=="janna" and index==3 and c.buffs.has("monsoon"):return {"time":c.buffs.monsoon.time,"duration":3.,"label":"R CANCEL","available":true}
 return {}
static func recast(c,index: int) -> bool:
 if c.hero_key!="janna":return false
 if index==0 and c.buffs.has("gale_charge"):release_gale(c);return true
 if index==3 and c.buffs.has("monsoon"):cancel_channel(c);return true
 return false
static func release_gale(c) -> void:
 var b=c.buffs.gale_charge;var charge=clampf(b.elapsed/3.,0.,1.);c.buffs.erase("gale_charge")
 c.passive_state.gale_air=.6+charge*.9
 var distance=430.+270.*charge
 NewHeroKits.projectile(c,b.origin,b.direction,amount(c,0)*(1.+charge*.6),{"effect_id":"janna_q","speed":600.,"size":17.,"life":distance/600.,"pierce":99,"no_structures":true,"damage_type":"magic"})
static func cancel_channel(c) -> void:
 c.buffs.erase("monsoon")
 for area in GameState.aoes:
  if area.src==c and area.effect_id=="janna_r":area.elapsed=area.duration
static func tick(c,delta: float) -> void:
 if c.buffs.has("rejuvenation_shared"):
  var b=c.buffs.rejuvenation_shared
  if is_instance_valid(b.src):c.hp=minf(c.hp_max,c.hp+b.heal*ExpansionCombat.healing_multiplier(c)*delta)
 if c.buffs.has("gale_charge"):
  var b=c.buffs.gale_charge;b.elapsed+=delta
  if b.time<=delta:release_gale(c)
 if c.buffs.has("monsoon"):
  var b=c.buffs.monsoon
  if c.stun>0 or c.buffs.has("silence") or c.world_pos().distance_to(b.origin)>8. or c.has_move_target or c.manual_move.length_squared()>.01:cancel_channel(c);return
  b.tick+=minf(delta,b.time)
  while b.tick>=.25:
   b.tick-=.25
   for ally in GameState.champions:
    if ally.team==c.team and not ally.dead and ally.world_pos().distance_to(c.world_pos())<=240.:SupportCombat.heal(c,ally,amount(c,3)*.25)
static func description(id: String,c,rank: int) -> String:
 if c==null:return "Scales with AP. Healing and shields also scale with heal/shield power."
 var index=["q","w","e","r"].find(id.get_slice("_",1));var value=amount(c,index)
 var ratios=[.45,.65,.4,.65] if c.hero_key=="soraka" else [.4,.5,.6,.12]
 var label="Healing" if id in ["soraka_w","soraka_r","janna_r"] else "Shield" if id=="janna_e" else "Magic damage"
 var power=SupportCombat.power(c) if label in ["Healing","Shield"] else 1.
 return "%s: %.0f (+%.0f%% AP). Current heal/shield bonus: +%.0f%%%s" % [label,value*power,ratios[index]*100.,c.bonus_heal_power*100.," per second, 3s channel" if id=="janna_r" else " before target mitigation" if label=="Magic damage" else " before healing reduction"]
static func bot_support(c) -> bool:
 if c.buffs.has("monsoon"):return true
 if c.hero_key=="janna" and c.buffs.has("gale_charge") and c.buffs.gale_charge.elapsed>=.65:return c.try_cast_skill(0,c.world_pos())
 var ally=SupportCombat.most_wounded(c,c.world_pos(),400.,null,c.hero_key!="soraka")
 if c.hero_key=="soraka":
  for unit in GameState.champions:
   if unit.team==c.team and not unit.dead and unit.hp<unit.hp_max*.3 and unit.time_since_damage<3. and c.try_cast_skill(3,c.world_pos()):return true
  if ally!=null and ally.hp<ally.hp_max*.8 and c.try_cast_skill(1,ally.world_pos()):return true
 if c.hero_key=="janna" and ally!=null:
  if ally.hp<ally.hp_max*.45 and ally.time_since_damage<3. and c.try_cast_skill(3,c.world_pos()):return true
  if ally.time_since_damage<2.5 and ally.shield<30. and c.try_cast_skill(2,ally.world_pos()):return true
 # Existing supports use targeted shields on an endangered ally, rather than enemies.
 if ally!=null and ally!=c and ally.time_since_damage<2. and ally.shield<30.:
  var index={"morgana":2,"thresh":1,"lux":1,"kayle":1,"leesin":1}.get(c.hero_key,-1)
  if index>=0 and c.try_cast_skill(index,ally.world_pos()):return true
 return false
