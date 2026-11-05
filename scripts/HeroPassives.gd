class_name HeroPassives
extends RefCounted
# Host-only gameplay. Permanent match counters live separately from expiring buffs.
const DATA={
 "soraka":SupportRoster.PASSIVES.soraka,"janna":SupportRoster.PASSIVES.janna,
 "lux":["Illumination","Damaging spells mark for 6s. Your next attack or R consumes the mark for level-scaled magic damage, then R refreshes it."],
 "ahri":["Essence Theft","Every 9 minion kills restores health. A champion takedown you contributed to restores more health."],
 "ezreal":["Rising Spell Force","Spell hits grant 10% attack speed for 6s, up to 5 stacks. Q also refunds 1.5s from all skill cooldowns."],
 "ashe":["Frost Shot","Attacks slow for 2s and deal increased damage to your frosted targets. Critical chance increases this bonus; critical attacks strengthen the slow instead of multiplying damage."],
 "annie":["Pyromania","After 4 casts, the next offensive spell stuns for 1.25s. Begin the match and respawn ready. Shield casts build stacks without consuming readiness."],
 "garen":["Perseverance","After 8s without champion or tower damage, regenerate 1.5–3.5% maximum health per second. Minion damage does not interrupt it."],
 "yasuo":["Way of the Wanderer","Moving builds Flow. At 100 Flow, champion damage triggers a 1s shield. Critical chance is multiplied by 2.5, with reduced critical damage."],
 "leesin":["Flurry","Each successful cast or recast primes two attacks with 40% attack speed; they restore 20/10 energy. Energy is capped at 200 and regenerates 10 per second."],
 "zed":["Contempt for the Weak","Attack targets below 50% health for 6–10% maximum-health bonus magic damage. Ten-second cooldown per champion target."],
 "jinx":["Get Excited!","A champion or structure takedown you contributed to grants 60% movement speed and 25% attack speed for 6s."],
 "katarina":["Voracity","Champion takedowns you damaged within 3s refund 15s of all cooldowns. Pick up Q/W daggers to spin for magic damage and refund most of E's cooldown."],
 "kayle":["Divine Ascent","Attacks stack attack speed (five stacks). Level 6 grants ranged attacks, level 11 adds fire waves while exalted, and level 16 grants permanent exaltation and more range. Exalted grants 8% movement speed."],
 "darius":["Hemorrhage","Attacks and damaging physical abilities apply a 5s bleed, up to five stacks. Five stacks on a hero grant Noxian Might: bonus AD and instant five-stack application. R scales with bleed and a killing R resets its cooldown."],
 "malphite":["Granite Shield","Recharge a shield worth 10% maximum health after 8s without taking damage. Shield capacity follows your health upgrades."],
 "veigar":["Phenomenal Evil","Spell hits on champions grant 1 AP. Q last hits grant 1 AP (2 for siege/super minions). Champion takedowns grant 5 AP. Stacks persist through respawns for this match."],
 "morgana":["Soul Siphon","Heal for 20% of actual spell damage to heroes and siege/super minions. Ordinary minions, item damage and blocked hits do not heal."],
 "vayne":["Night Hunter","Gain 12% movement speed when moving toward a visible enemy hero within 600. Triple this bonus during R. Learned W is always active on attacks and Condemn."],
 "thresh":["Damnation","Nearby enemy deaths drop souls (heroes and large minions always; every third ordinary minion). Walk within 65 or place W lantern to collect. Each soul grants 0.75 armor and AP this match."],
 "leona":["Sunlight","Spells mark for 1.5s. Only allied champions consume your marks for bonus magic damage; your own damage refreshes them."],
 "blitzcrank":["Mana Barrier","Damage taking you below 30% health triggers a 10s shield worth 30% current mana, before the hit lands. 45s cooldown."],
 "renekton":["Reign of Anger","Attacks generate 5 Fury (7.5 below half health). Unempowered Q/E hits also generate Fury. Out of combat Fury decays; 50 Fury empowers the next applicable skill."],
 "xinzhao":["Determination","Every third successful attack deals bonus physical damage and heals, independently of Q. Q empowers three attacks; only the third becomes airborne."],
 "riven":["Runic Blade","Every cast and recast grants a rune, up to 3 for 6s. Attacks consume one for level-scaled bonus physical damage."],
 "fiora":["Duelist's Dance","Strike a hero from the indicated vital side for maximum-health true damage, healing and movement speed. Each Duelia owns separate directional marks."],
 "caitlyn":["Headshot","Every sixth attack becomes a crit-scaling Headshot. Bush attacks build two stacks. Trap/net marks grant an independent Headshot with double attack range against that target."],
 "lucian":["Lightslinger / Vigilance","Casts prime a second shot. Allied healing/shielding or nearby enemy immobilization primes two bonus-magic attacks. Second shots reduce E cooldown."],
 "sivir":["Fleet of Foot","Damaging a champion with an attack or ability grants 20% movement speed for 2s."],
 "brand":["Blaze","Spells apply a 4s stacking burn. Three stacks on heroes cause a delayed explosion. Killing a burning unit restores mana."],
 "syndra":["Transcendent","Gain 5 splinters per level, 1 per siege last hit, and 2 after two spells hit the same hero within 4s (8s per-target cooldown). At 40/60/80/100 splinters upgrade Q/W/E/R; at 120 gain 15% AP."],
 "xerath":["Mana Surge","An attack restores mana every 8s, doubled against heroes. Last hits reduce the remaining cooldown by 1s."]}
static func description(key: String,c=null) -> String:
 var d=DATA[key];var status=state_text(c) if c!=null else ""
 return d[0]+" • PASSIVE\n\n"+d[1]+("\n\nCurrent: "+status if not status.is_empty() else "")
static func state_text(c) -> String:
 var p=c.passive_state
 match c.hero_key:
  "annie":return "STUN READY" if p.get("pyromania",4)>=4 else "%d / 4 casts" % p.get("pyromania",0)
  "yasuo":return "Flow %d / 100" % p.get("flow",0.)
  "xinzhao":return "Determination %d / 3 • Q %d attacks left" % [p.get("determination",0),c.buffs.get("roster_attack",{}).get("hits",0)]
  "syndra":return "%d / 120 splinters" % p.get("splinters",0)
  "thresh":return "%d souls" % p.get("souls",0)
  "veigar":return "%d earned AP" % p.get("evil",0)
  "ezreal":return "%d / 5 spell stacks" % c.buffs.get("spell_force",{}).get("stacks",0)
  "caitlyn":return "%d / 6 headshot stacks" % p.get("headshot",0)
  "leesin":return "%d Flurry attacks" % c.buffs.get("flurry",{}).get("hits",0)
  "riven":return "%d rune charges" % c.buffs.get("runes",{}).get("stacks",0)
  "ahri":return "%d / 9 essences" % p.get("essence",0)
 return "Active from level 1"
static func initialize(c) -> void:
 c.passive_state={"last_position":c.world_pos(),"last_damage":-10.,"last_combat":-10.,"flow":0.,"pyromania":4,"splinters":0,"evil":0,"souls":0}
 if c.hero_key in ["leesin","zed"]:c.mp_max=200.;c.mp=200.;c.mp_regen=10.
 if c.hero_key=="kayle":c.auto_type="melee";c.atk_range=100.
static func respawn(c) -> void:
 c.passive_state.last_position=c.world_pos();c.passive_state.flow=0.;c.passive_state.pyromania=4;c.passive_state.last_damage=GameState.time-10.
 c.passive_state.determination=0;c.passive_state.headshot=0
 if c.hero_key=="malphite":c.passive_state.granite=0.
static func is_spell(kind: String) -> bool:return kind in ["skill","physical","magic"]
static func proc(c,u,value: float,kind: String="passive_magic") -> void:
 if not u.dead and u.hp>0:NewHeroKits.hit(c,u,value,kind)
static func add_stats(c,ap: float,armor: float=0.) -> void:
 c.run_bonus.bonus_ap=c.run_bonus.get("bonus_ap",0.)+ap;c.run_bonus.bonus_armor=c.run_bonus.get("bonus_armor",0.)+armor;c._apply_items()
static func prepare_cast(c,index: int) -> float:
 return 1.25 if c.hero_key=="annie" and index!=2 and c.passive_state.get("pyromania",4)>=4 else 0.
static func on_cast(c,index: int) -> void:
 c.passive_state.last_cast_time=GameState.time
 if c.hero_key=="annie":
  var n=int(c.passive_state.get("pyromania",4));c.passive_state.pyromania=0 if n>=4 and index!=2 else mini(4,n+1)
 if c.hero_key=="syndra" and index==0 and c.passive_state.get("splinters",0)>=40:
  c.passive_state.q_charges=maxi(0,int(c.passive_state.get("q_charges",2))-1)
  if c.passive_state.get("q_recharge",0.)<=0:c.passive_state.q_recharge=c.effective_cd(c.hero.skills[0].cd)
 if c.hero_key=="leesin":c.buffs.flurry={"time":3.,"hits":2}
 if c.hero_key=="katarina" and index in [0,1]:
  var point=c.last_cast_point if index==0 else c.world_pos()
  NewHeroKits.area(c,point,40,0,{"zone_kind":"dagger","duration":5.,"arm_delay":.8 if index==0 else .6,"effect_id":"katarina_dagger"})
static func critical_chance(c) -> float:return clampf(c.bonus_crit*(2.5 if c.hero_key=="yasuo" else 1.),0.,1.)
static func attack_range(c,target) -> float:
 if c.hero_key=="caitlyn" and is_instance_valid(target) and "buffs" in target and target.buffs.get("rifle_mark",{}).get("src")==c:return c.atk_range*2.
 return c.atk_range+(60 if c.hero_key=="kayle" and c.level>=16 else 0)
static func attack_speed(c) -> float:
 var m=1.+c.buffs.get("spell_force",{}).get("stacks",0)*.1
 if c.buffs.has("flurry"):m*=1.4
 if c.buffs.has("excited"):m*=1.25
 if c.hero_key=="kayle":m*=1.+(.3 if c.level>=16 else c.buffs.get("ascent",{}).get("stacks",0)*.06)
 return m
static func move_speed(c) -> float:
 var m=1.
 if c.buffs.has("excited"):m*=1.6
 if c.buffs.has("fleet_foot"):m*=1.2
 if c.hero_key=="kayle" and (c.level>=16 or c.buffs.get("ascent",{}).get("stacks",0)>=5):m*=1.08
 if c.hero_key=="vayne":
  var direction=(c.move_target-c.world_pos()).normalized() if c.has_move_target else c.manual_move.normalized()
  for u in GameState.champions:
   if u.dead or u.team==c.team or not BrushVision.visible_to(u,c.team):continue
   var offset=u.world_pos()-c.world_pos()
   if offset.length()<600 and direction.dot(offset.normalized())>.6:return m*(1.36 if c.buffs.has("hunt") else 1.12)
 return m
static func auto_bonus(c,target) -> float:
 var bonus=0.
 if c.hero_key=="xinzhao" and int(c.passive_state.get("determination",0))==2:bonus+=c.ad*(.15+.3*(mini(c.level,18)-1)/17.)
 if c.hero_key=="darius" and c.buffs.has("noxian_might"):bonus+=c.buffs.noxian_might.ad
 if c.hero_key=="ashe" and "buffs" in target and target.buffs.get("frost",{}).get("src")==c:bonus+=c.ad*(.1+critical_chance(c)*(.75+c.bonus_crit_damage))
 return bonus
static func before_damage(src,target,kind: String,value: float) -> void:
 if target.kind!="champion" or value<=0:return
 var p=target.passive_state
 if target.hero_key=="blitzcrank" and target.hp-maxf(0.,value-target.shield)<target.hp_max*.3 and target.item_cds.get("mana_barrier",0.)<=0:
  var amount=target.mp*.3;target.shield+=amount;target.buffs.mana_barrier={"time":10.,"shield":amount};target.item_cds.mana_barrier=45.
 if target.hero_key=="yasuo" and p.get("flow",0.)>=100. and is_instance_valid(src) and src.kind=="champion":
  var amount=80.+mini(target.level,18)*20.;target.shield+=amount;target.buffs.flow_shield={"time":1.,"shield":amount};p.flow=0.
static func on_damage(src,target,kind: String,value: float,id: String,health_damage: float=-1.) -> void:
 if value<=0:return
 if health_damage<0:health_damage=value
 if target.kind=="champion":
  target.passive_state.last_damage=GameState.time
  if is_instance_valid(src) and src.kind in ["champion","structure"]:target.passive_state.perseverance_hit=GameState.time
 if not is_instance_valid(src) or src.kind!="champion" or src.team==target.team:return
 src.passive_state.last_combat=GameState.time
 if target.kind=="champion" and kind not in ["burn","bleed","reflect"]:target.buffs["contribution_"+str(GameState.champions.find(src))]={"time":5.,"src":src}
 if target.kind=="structure":return
 var spell=is_spell(kind)
 match src.hero_key:
  "lux":
   if (kind=="auto" or id=="lux_r") and target.buffs.get("illumination",{}).get("src")==src:
    target.buffs.erase("illumination");proc(src,target,20.+mini(src.level,18)*10.+src.bonus_ap*.2)
   if spell:target.buffs.illumination={"time":6.,"src":src}
  "ezreal":
   if spell:
    src.buffs.spell_force={"time":6.,"stacks":mini(5,int(src.buffs.get("spell_force",{}).get("stacks",0))+1)}
    if id=="ezreal_q":
     for i in range(4):src.skill_cds[i]=maxf(0.,src.skill_cds[i]-1.5)
  "ashe":
   if kind=="auto" or id=="ashe_w":
    target.buffs.frost={"time":2.,"src":src};Roster12Kits.control(target,2.,.2+.01*mini(src.level,18))
  "zed":
   if kind=="auto" and target.hp<target.hp_max*.5:
    var key="contempt_"+str(GameState.champions.find(src))
    if not target.buffs.has(key):
     if target.kind=="champion":target.buffs[key]={"time":10.}
     proc(src,target,minf(100.,target.hp_max*.08) if target.kind=="minion" else target.hp_max*(.06+.002*mini(src.level,18)))
  "darius":
   if kind=="auto" or kind=="physical":
    var key="hemorrhage_"+str(GameState.champions.find(src));var b=target.buffs.get(key,{"stacks":0,"tick":0.})
    b.stacks=5 if src.buffs.has("noxian_might") else mini(5,int(b.stacks)+1);b.time=5.;b.src=src;target.buffs[key]=b
    if b.stacks==5 and target.kind=="champion":src.buffs.noxian_might={"time":5.,"ad":15.+mini(src.level,18)*5.}
  "veigar":
   if spell and target.kind=="champion":evil(src,1)
   if id=="veigar_q" and target.hp<=0:evil(src,2 if target.kind=="minion" and target.subkind in ["siege","super"] else 1)
  "morgana":
   if spell and (target.kind=="champion" or target.kind=="minion" and target.subkind in ["siege","super"]):Roster12Combat.heal(src,health_damage*.2)
  "fiora":
   if kind=="auto" or spell:Roster12Combat.vital(src,target,src.last_cast_point if id=="fiora_q" else src.world_pos())
  "sivir":if target.kind=="champion" and (spell or kind=="auto"):src.buffs.fleet_foot={"time":2.}
  "syndra":
   if id=="syndra_w" and src.passive_state.get("splinters",0)>=60:proc(src,target,value*(.12+src.bonus_ap*.0002),"exec")
   if id=="syndra_r" and src.passive_state.get("splinters",0)>=100 and target.hp>0 and target.hp<target.hp_max*.15:proc(src,target,target.hp,"exec")
   if spell and target.kind=="champion":
    var key="splinter_combo_"+str(GameState.champions.find(src));var lock=key+"_lock"
    if not target.buffs.has(lock):
     if target.buffs.has(key):splinters(src,2);target.buffs.erase(key);target.buffs[lock]={"time":8.}
     else:target.buffs[key]={"time":4.}
 if src.hero_key=="vayne" and (kind=="auto" or id=="vayne_e"):ExpansionCombat.silver_hit(src,target)
 if kind=="auto":
  if src.hero_key=="xinzhao":
   var n=int(src.passive_state.get("determination",0))+1;src.passive_state.determination=n%3
   if n==3:Roster12Combat.heal(src,12.+src.hp_max*.03+src.bonus_ap*.15)
  if src.hero_key=="leesin" and src.buffs.has("flurry"):
   src.mp=minf(src.mp_max,src.mp+(20. if src.buffs.flurry.hits==2 else 10.));src.buffs.flurry.hits-=1
   if src.buffs.flurry.hits<=0:src.buffs.erase("flurry")
  if src.hero_key=="kayle":
   var stacks=mini(5,int(src.buffs.get("ascent",{}).get("stacks",0))+1);src.buffs.ascent={"time":5.,"stacks":stacks}
   if src.rank(2)>0:proc(src,target,5.+src.rank(2)*5.+src.bonus_ap*.2)
   if src.level>=11 and (stacks>=5 or src.level>=16):
    NewHeroKits.projectile(src,src.world_pos(),(target.world_pos()-src.world_pos()).normalized(),10.+src.bonus_ad*.1+src.bonus_ap*.2,{"damage_type":"passive_magic","effect_id":"kayle_wave","shape":"wave","pierce":99,"size":16.,"speed":750.,"life":.65,"no_structures":true})
  if src.hero_key=="lucian" and src.buffs.has("vigilance"):
   src.buffs.vigilance.hits-=1;proc(src,target,10.+src.ad*.15)
   if src.buffs.vigilance.hits<=0:src.buffs.erase("vigilance")
static func evil(c,n: int) -> void:c.passive_state.evil=int(c.passive_state.get("evil",0))+n;add_stats(c,float(n))
static func splinters(c,n: int) -> void:
 var old=int(c.passive_state.get("splinters",0));c.passive_state.splinters=mini(120,old+n);c.mp=minf(c.mp_max,c.mp+c.mp_max*.03*n)
 if old<40 and c.passive_state.splinters>=40:
  c.passive_state.q_charges=1 if c.skill_cds[0]>0 else 2;c.passive_state.q_recharge=c.skill_cds[0];c.skill_cds[0]=0.
 if old<120 and c.passive_state.splinters>=120:c.passive_state.transcendent_ap=true;c._apply_items()
static func on_level(c) -> void:
 if c.hero_key=="syndra":splinters(c,5)
static func on_death(killer,victim) -> void:
 # Called once before death buffs are cleared; participation requires a recent hit.
 for c in GameState.champions:
  if c.dead or c.team==victim.team:continue
  var contributed=c==killer or victim.kind=="champion" and victim.buffs.has("contribution_"+str(GameState.champions.find(c)))
  if victim.kind=="champion" and contributed:
   match c.hero_key:
    "ahri":Roster12Combat.heal(c,80.+mini(c.level,18)*8.+c.bonus_ap*.35)
    "jinx":c.buffs.excited={"time":6.}
    "katarina":
     var recent=victim.buffs.get("contribution_"+str(GameState.champions.find(c)),{}).get("time",0.)>2.
     if c==killer or recent:
      for i in range(4):c.skill_cds[i]=maxf(0.,c.skill_cds[i]-15.)
    "veigar":evil(c,5)
  if victim.kind=="structure" and c.hero_key=="jinx" and (c==killer or c.world_pos().distance_to(victim.world_pos())<500):c.buffs.excited={"time":6.}
  if c==killer:
   if c.hero_key=="ahri" and victim.kind=="minion":
    var n=int(c.passive_state.get("essence",0))+1;c.passive_state.essence=n%9
    if n==9:Roster12Combat.heal(c,35.+mini(c.level,18)*5.+c.bonus_ap*.2)
   if c.hero_key=="syndra" and victim.kind=="minion" and victim.subkind in ["siege","super"]:splinters(c,1)
   if c.hero_key=="xerath":c.item_cds.arcane_mana=maxf(0.,c.item_cds.get("arcane_mana",0.)-1.)
   if c.hero_key=="darius" and c.active_cast_id=="darius_r":c.skill_cds[3]=0.;c.passive_state.reset_r=true;c.buffs.noxian_might={"time":5.,"ad":15.+mini(c.level,18)*5.}
  if c==killer and c.hero_key=="brand" and victim.kind!="structure" and victim.buffs.get("blaze",{}).get("src")==c:c.mp=minf(c.mp_max,c.mp+20.+c.level)
  if c.hero_key=="thresh" and victim.kind in ["champion","minion"] and c.world_pos().distance_to(victim.world_pos())<600:
   c.passive_state.soul_deaths=int(c.passive_state.get("soul_deaths",0))+1
   if victim.kind=="champion" or victim.subkind in ["siege","super"] or c.passive_state.soul_deaths%3==0:
    NewHeroKits.area(c,victim.world_pos(),18,0,{"zone_kind":"soul","duration":12.,"effect_id":"thresh_soul"})
static func tick(c,delta: float) -> void:
 # Bleeds also tick on minions; secondary damage never reapplies itself.
 for key in c.buffs.keys():
  if not key.begins_with("hemorrhage_"):continue
  var b=c.buffs[key];b.tick+=delta
  if b.tick>=1.:
   b.tick-=1.
   if is_instance_valid(b.src):proc(b.src,c,(3.+mini(b.src.level,18)*.8+b.src.bonus_ad*.06)*b.stacks,"bleed")
 if c.kind!="champion" or c.dead:return
 var p=c.passive_state
 match c.hero_key:
  "garen":
   if GameState.time-p.get("perseverance_hit",-10.)>=8.:Roster12Combat.heal(c,c.hp_max*(.015+.02*minf(c.level/18.,1.))*delta)
  "malphite":
   if GameState.time-p.get("last_damage",-10.)>=8.:
    var old=minf(c.shield,p.get("granite",0.));var capacity=c.hp_max*.1;c.shield+=maxf(0.,capacity-old);p.granite=capacity
  "yasuo":
   var distance=c.world_pos().distance_to(p.get("last_position",c.world_pos()))
   if distance<150:p.flow=minf(100.,p.get("flow",0.)+distance*.12)
  "renekton":
   if GameState.time-p.get("last_combat",-10.)>12. and not c.buffs.has("dominion"):Roster12Combat.fury(c,-5.*delta)
  "lucian":
   var seen=p.get("cc_seen",{})
   for enemy in GameState.champions:
    if enemy.team==c.team or enemy.dead:continue
    var id=str(GameState.champions.find(enemy));var previous=float(seen.get(id,0.));seen[id]=enemy.stun
    if enemy.stun>previous+.03 and c.world_pos().distance_to(enemy.world_pos())<400:c.buffs.vigilance={"time":6.,"hits":2}
   p.cc_seen=seen
 p.last_position=c.world_pos()
static func support(src,ally) -> void:
 CombatParticipation.support(src,ally)
 if not is_instance_valid(src) or not is_instance_valid(ally) or src==ally or ally.kind!="champion" or ally.hero_key!="lucian" or src.team!=ally.team:return
 ally.buffs.vigilance={"time":6.,"hits":2}
static func cooldowns(c,delta: float) -> void:
 if c.hero_key!="syndra" or c.passive_state.get("splinters",0)<40:return
 var p=c.passive_state
 if p.get("q_charges",2)<2:
  p.q_recharge=maxf(0.,p.get("q_recharge",c.effective_cd(c.hero.skills[0].cd))-delta)
  if p.q_recharge<=0:p.q_charges=int(p.get("q_charges",0))+1;p.q_recharge=c.effective_cd(c.hero.skills[0].cd) if p.q_charges<2 else 0.
 c.skill_cds[0]=0. if p.get("q_charges",2)>0 else p.q_recharge
