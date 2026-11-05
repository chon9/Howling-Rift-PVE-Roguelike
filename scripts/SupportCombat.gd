class_name SupportCombat
extends RefCounted
static func power(c) -> float:
 return 1.+c.bonus_heal_power
static func heal(src,ally,amount: float,procs: bool=true) -> float:
 if not is_instance_valid(ally) or ally.dead or ally.team!=src.team:return 0.
 var actual=minf(ally.hp_max-ally.hp,maxf(0.,amount)*power(src)*ExpansionCombat.healing_multiplier(ally))
 if actual<=0:return 0.
 ally.hp+=actual;ally.buffs.support_heal={"time":.5}
 HeroPassives.support(src,ally)
 if procs:on_help(src,ally)
 return actual
static func on_help(src,ally) -> void:
 if src==ally or src.dead or ally.dead or src.team!=ally.team:return
 if src.inventory.has("ardent_censer"):
  for unit in [src,ally]:unit.buffs.ardent={"time":4.,"magic":12.+src.bonus_ap*.05}
 if src.inventory.has("flowing_staff"):
  for unit in [src,ally]:
   var active=unit.buffs.has("flowing");unit.buffs.flowing={"time":4.}
   if not active:unit._apply_items()
 if src.inventory.has("dawn_bell"):
  var key="dawn_"+str(GameState.champions.find(ally))
  if src.item_cds.get(key,0.)<=0:
   src.item_cds[key]=8.;ally.buffs.erase("slow");ally.buffs.erase("frost")
   CombatEffects.shield(ally,"dawn_shield",35.+src.bonus_ap*.1,2.,src,false)
 if src.inventory.has("moonstone") and src.item_cds.get("moonstone",0.)<=0:
  var other=most_wounded(src,ally.world_pos(),300.,ally,false)
  if other!=null and other.hp<other.hp_max:
   src.item_cds.moonstone=4.;heal(src,other,45.+src.bonus_ap*.1,false)
static func most_wounded(c,point: Vector2,reach: float,exclude=null,include_self: bool=true):
 var best=null;var fraction=INF
 for ally in GameState.champions:
  if ally.dead or not ally.roster_active or ally.team!=c.team or ally==exclude or (ally==c and not include_self) or point.distance_to(ally.world_pos())>reach:continue
  if ally.hp/ally.hp_max<fraction:fraction=ally.hp/ally.hp_max;best=ally
 return best
static func tick(c,delta: float) -> void:
 if c.buffs.has("rejuvenation"):heal(c,c,(14.+8.*c.rank(0)+c.bonus_ap*.1)*delta,false)
 if c.inventory.has("guardian_oath") and c.item_cds.get("guardian_oath",0.)<=0:
  var ally=most_wounded(c,c.world_pos(),300.,null,false)
  if ally!=null and ally.hp<ally.hp_max*.45 and ally.time_since_damage<3.:
   c.item_cds.guardian_oath=20.;CombatEffects.shield(ally,"oath_shield",120.+c.hp_max*.08,3.,c)
 if c.inventory.has("redemption") and c.item_cds.get("redemption",0.)<=0:
  var ally=most_wounded(c,c.world_pos(),450.)
  if ally!=null and ally.hp<ally.hp_max*.35 and ally.time_since_damage<3.:
   c.item_cds.redemption=45.;c.buffs.redemption_cast={"time":.65,"point":ally.world_pos(),"fired":false}
   SupportKits.visual(c,ally.world_pos(),180.,"soraka_r",.8)
 if c.buffs.has("redemption_cast"):
  var b=c.buffs.redemption_cast
  if b.time<=.05 and not b.fired:
   b.fired=true
   for ally in GameState.champions:
    if ally.team==c.team and not ally.dead and ally.world_pos().distance_to(b.point)<=180.:heal(c,ally,100.+c.bonus_ap*.15+ally.hp_max*.05)
static func move_multiplier(c) -> float:
 var result=1.12 if c.buffs.has("flowing") else 1.
 if c.hero_key=="janna" and c.skill_cds[1]<=0:result*=1.08
 for ally in GameState.champions:
  if ally.dead or not ally.roster_active or ally.team!=c.team:continue
  if ally.hero_key=="janna" and c.world_pos().distance_to(ally.world_pos())<=250.:result*=1.05;break
 if c.hero_key=="soraka":
  for ally in GameState.champions:
   if ally==c or ally.dead or ally.team!=c.team or ally.hp>=ally.hp_max*.4:continue
   var offset=ally.world_pos()-c.world_pos()
   var direction=c.manual_move if c.manual_move.length_squared()>.01 else c.move_target-c.world_pos() if c.has_move_target else Vector2.ZERO
   if offset.length()<=700. and direction.normalized().dot(offset.normalized())>.65:result*=1.35;break
 return result
static func on_damage(src,target,kind: String,damage: float,spell: String) -> void:
 if not is_instance_valid(src) or damage<=0 or target.dead:return
 if spell=="soraka_q" and target.kind=="champion":src.buffs.rejuvenation={"time":3.}
 if spell=="janna_q" and not target.buffs.has("cc_guard") and not target.buffs.has("spell_guard") and not target.buffs.has("parry"):HeroControl.airborne(target,src.passive_state.get("gale_air",.6))
 if kind=="auto" and src.kind=="champion" and src.buffs.has("ardent") and target.kind!="structure":NewHeroKits.hit(src,target,src.buffs.ardent.magic,"item_magic")
