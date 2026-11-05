class_name ExpansionKits
extends RefCounted
const FORMULAS={
 "darius_q":[50,25,.7,0,"Physical damage"],"darius_w":[25,15,.45,0,"Bonus attack damage"],"darius_r":[110,90,.65,0,"True damage before bleed-stack bonus"],
 "malphite_q":[45,25,0,.65,"Magic damage"],"malphite_w":[70,30,0,.4,"Shield"],"malphite_e":[55,25,0,.6,"Magic damage"],"malphite_r":[100,80,0,.8,"Magic damage"],
 "veigar_q":[40,25,0,.65,"Magic damage"],"veigar_w":[60,35,0,.9,"Meteor damage"],"veigar_r":[100,90,0,.8,"Magic damage before execute multiplier"],
 "morgana_q":[50,25,0,.7,"Magic damage"],"morgana_w":[18,9,0,.2,"Magic damage per second"],"morgana_e":[65,30,0,.6,"Shield"],"morgana_r":[65,50,0,.5,"Magic damage per pulse (two pulses)"],
 "vayne_q":[10,10,.35,0,"Bonus attack damage"],"vayne_e":[40,25,.5,0,"Physical damage"],"vayne_r":[15,15,0,0,"Bonus AD"],
 "thresh_q":[40,25,0,.65,"Magic damage"],"thresh_w":[55,25,0,.45,"Shield per ally"],"thresh_e":[35,25,.3,.4,"Magic damage"],"thresh_r":[90,70,0,.8,"Magic damage"]}
static func amount(c,id: String) -> float:
 var f=FORMULAS[id];var index=["q","w","e","r"].find(id.get_slice("_",1))
 return f[0]+f[1]*c.rank(index)+f[2]*(c.ad+c.buffs.get("noxian_might",{}).get("ad",0.))+f[3]*c.bonus_ap
static func description(id: String,c=null,rank: int=1) -> String:
 if not FORMULAS.has(id):
  if id=="vayne_w":return "True damage every third attack: %d%% of target max HP (80 cap against minions).\nNo AD/AP scaling." % (4+maxi(rank,1))
  return "Utility ability • no direct AD/AP damage scaling."
 var f=FORMULAS[id];var ad=c.ad+c.buffs.get("noxian_might",{}).get("ad",0.) if c!=null else 0.;var ap=c.bonus_ap if c!=null else 0.;var base=f[0]+f[1]*maxi(rank,1)
 var text="%s: %.1f\n%.0f base + %.0f%% AD (%.1f) + %.0f%% AP (%.1f)" % [f[4],base+f[2]*ad+f[3]*ap,base,f[2]*100,f[2]*ad,f[3]*100,f[3]*ap]
 if id=="thresh_e":text+="\nCharged attack: up to %.0f%% AD (%.1f magic); charges over 3 seconds." % [(.2+.2*maxi(rank,1))*100,ad*(.2+.2*maxi(rank,1))]
 if id=="darius_r":text+="\n20% more damage per owned bleed stack (up to 2x). Killing blow resets R."
 if id=="veigar_r":text+="\nUp to 2x damage at or below 33%% target HP."
 return text
static func area(c,point: Vector2,radius: float,id: String,opts: Dictionary={}) -> void:
 opts=opts.duplicate();opts.merge({"damage_type":"physical" if c.hero_key=="darius" else "magic","effect_id":id},false)
 NewHeroKits.area(c,point,radius,amount(c,id),opts)
static func bolt(c,point: Vector2,id: String,opts: Dictionary={}) -> void:
 opts=opts.duplicate();opts.merge({"damage_type":"magic","effect_id":id},false)
 NewHeroKits.projectile(c,c.world_pos(),(point-c.world_pos()).normalized(),amount(c,id),opts)
static func cast(c,id: String,point: Vector2) -> bool:
 var direction=(point-c.world_pos()).normalized()
 if direction.length_squared()<.01:direction=c.facing
 match id:
  "darius_q":
   area(c,c.world_pos(),165,id)
   for enemy in GameState.champions:
    if enemy.team!=c.team and not enemy.dead and c.world_pos().distance_to(enemy.world_pos())<165:
     c.hp=minf(c.hp_max,c.hp+c.hp_max*.08*ExpansionCombat.healing_multiplier(c));break
  "darius_w","vayne_q":
   if id=="vayne_q":
    if c.is_bot and not BotSafety.can_enter(c,point):return false
    c.dash_target=GameState.clamp_walkable(point);c.is_dashing=true
   c.buffs.empowered={"time":5.,"damage":amount(c,id),"slow":.45 if id=="darius_w" else 0.}
   aura(c,id,60,.45 if id=="vayne_q" else 1.)
  "darius_e","thresh_e":
   NewHeroKits.area(c,c.world_pos(),220,0,{"effect_id":id,"effect_dir":direction,"duration":.45,"footprint_kind":"rectangle" if id=="thresh_e" else "","footprint_width":65.,"cone_ang":direction.angle() if id=="darius_e" else -999.,"arc":acos(.35)*2.})
   for enemy in GameState.champions+GameState.minions:
    if enemy.team==c.team or enemy.dead or not enemy.is_targetable:continue
    var offset=enemy.world_pos()-c.world_pos()
    if id=="thresh_e":
     if absf(offset.dot(direction))>220+enemy.size*.3 or absf(offset.dot(direction.orthogonal()))>65+enemy.size*.3:continue
     NewHeroKits.hit(c,enemy,amount(c,id),"magic")
     if not enemy.dead:
      ForcedMotion.apply(enemy,direction,110,.25)
      if not enemy.buffs.has("cc_guard") and not enemy.buffs.has("spell_guard"):enemy.buffs.slow={"pct":.2+.05*c.rank(2),"time":1.5}
    else:
     if offset.length()>220 or direction.dot(offset.normalized())<.35:continue
     ForcedMotion.apply(enemy,-direction,maxf(0,minf(110,offset.length()-55)),.25)
  "darius_r","malphite_q","veigar_r","vayne_e":
   var enemy=NewHeroKits.target(c,point,c.hero.skills[["q","w","e","r"].find(id.get_slice("_",1))].range)
   if enemy==null:return false
   if id=="darius_r":
    if c.is_bot and not BotSafety.can_enter(c,enemy.world_pos(),true):return false
    NewHeroKits.hit(c,enemy,amount(c,id)*(1.+.2*enemy.buffs.get("hemorrhage_"+str(GameState.champions.find(c)),{}).get("stacks",0)),"exec")
    NewHeroKits.area(c,enemy.world_pos(),85,0,{"effect_id":id,"duration":.5})
   elif id=="vayne_e":
    NewHeroKits.projectile(c,c.world_pos(),direction,amount(c,id),{"effect_id":id,"homing":enemy,"damage_type":"physical","speed":900.,"shape":"arrow","knockback_distance":170.,"wall_stun":1.2})
   else:
    var damage=amount(c,id)*(1.+minf(1.,(1.-enemy.hp/enemy.hp_max)*1.5) if id=="veigar_r" else 1.)
    NewHeroKits.projectile(c,c.world_pos(),direction,damage,{"effect_id":id,"homing":enemy,"damage_type":"magic","slow":.35 if id=="malphite_q" else 0.,"slow_dur":2.0,"is_ult":id=="veigar_r"})
  "malphite_w":
   CombatEffects.shield(c,"granite_w_shield",amount(c,id),3.);c.buffs.courage={"time":3.,"dr":.25}
   aura(c,id,65,3.)
  "malphite_e":area(c,c.world_pos(),165,id,{"slow":.3,"slow_dur":2.})
  "malphite_r":
   if c.is_bot and not BotSafety.can_enter(c,point,true):return false
   c.dash_target=GameState.clamp_walkable(point);c.is_dashing=true
   aura(c,id,65,.3)
   c.buffs.charge_impact={"time":1.5,"damage":amount(c,id),"point":c.dash_target,"effect_id":id}
  "veigar_q":bolt(c,point,id,{"pierce":1})
  "veigar_w":area(c,point,150,id,{"arm_delay":1.,"duration":1.45})
  "veigar_e":NewHeroKits.area(c,point,155,0,{"effect_id":id,"zone_kind":"cage","arm_delay":.5,"stun":1.2+.15*c.rank(2),"duration":3.5})
  "morgana_q":bolt(c,point,id,{"stun":1.8,"life":.85})
  "morgana_w":area(c,point,145,id,{"duration":4.,"tick_interval":1.})
  "morgana_e":
   var ally=c if point.distance_to(c.world_pos())<25 else NewHeroKits.target(c,point,400,true)
   if ally==null:ally=c
   CombatEffects.shield(ally,"black_ward_shield",amount(c,id),2.5,c);ally.buffs.cc_guard={"time":2.5}
   aura(ally,id,65,2.5)
  "morgana_r":area(c,c.world_pos(),230,id);c.buffs.soul_chains={"time":1.5,"damage":amount(c,id)}
  "vayne_w":return false
  "vayne_r":
   c.buffs.hunt={"time":6.,"damage":amount(c,id)};c.buffs.haste={"time":6.,"mult":1.2}
   aura(c,id,65,6.)
  "thresh_q":bolt(c,point,id,{"stun":1.5,"pull_distance":110.,"life":1.0,"hook_chain":true,"thresh_mark":true})
  "thresh_w":area(c,point,65,id,{"zone_kind":"lantern","duration":4.})
  "thresh_r":area(c,c.world_pos(),180,id,{"zone_kind":"box","arm_delay":.5,"duration":5.})
  _:return false
 return true
static func tick(c,delta: float) -> void:
 if c.hero_key=="vayne" and c.rank(1)>0:
  var silver=c.buffs.get("silver",{"target_id":0,"stacks":0});silver.time=9999.;silver.ratio=.04+.01*c.rank(1);c.buffs.silver=silver
 if c.hero_key=="thresh":c.flay_charge=minf(1.,c.flay_charge+delta/3.)
 for key in ["meteor","soul_chains","charge_impact"]:
  if not c.buffs.has(key):continue
  var buff=c.buffs[key]
  if buff.time>delta and (key!="charge_impact" or c.is_dashing):continue
  var point=buff.get("point",c.world_pos());var radius=150. if key=="meteor" else 230. if key=="soul_chains" else 160.
  NewHeroKits.area(c,point,radius,buff.damage,{"damage_type":"magic","stun":1.2 if key=="soul_chains" else 0.,"airborne":1.2 if key=="charge_impact" else 0.,"effect_id":buff.get("effect_id","morgana_r" if key=="soul_chains" else "veigar_w")})
  c.buffs.erase(key)
static func aura(c,id: String,radius: float,duration: float) -> void:
 NewHeroKits.area(c,c.world_pos(),radius,0,{"effect_id":id,"duration":duration,"follows_src":true})
