class_name Roster12Kits
extends RefCounted
const DAMAGE={
 "leona":[[20,15,0,.3],[35,25,0,.5],[25,20,0,.4],[80,65,0,.7]],
 "blitzcrank":[[40,30,0,.8],[0,0,0,0],[0,0,1,0],[90,65,0,.8]],
 "renekton":[[25,20,.65,0],[10,10,.6,0],[20,15,.5,0],[10,7,0,.1]],
 "xinzhao":[[5,5,.2,0],[30,20,.8,0],[30,25,0,.5],[70,60,1,0]],
 "riven":[[10,10,.55,0],[25,20,.5,0],[40,20,.5,0],[50,45,.6,0]],
 "fiora":[[10,15,.55,0],[40,25,0,.7],[0,0,.6,0],[0,0,0,0]],
 "caitlyn":[[30,25,1.1,0],[0,0,0,0],[30,20,0,.6],[100,90,1.1,0]],
 "lucian":[[20,20,.9,0],[30,25,0,.7],[0,0,0,0],[5,4,.2,.05]],
 "sivir":[[20,15,.65,0],[0,0,.45,0],[0,0,0,0],[0,0,0,0]],
 "brand":[[35,25,0,.55],[45,25,0,.65],[30,20,0,.45],[45,35,0,.25]],
 "syndra":[[40,25,0,.65],[35,25,0,.6],[35,20,0,.45],[30,25,0,.18]],
 "xerath":[[40,25,0,.7],[35,25,0,.55],[30,20,0,.4],[65,50,0,.4]]}
static func amount(c,id: String) -> float:
 var i=["q","w","e","r"].find(id.get_slice("_",1));var f=DAMAGE[id.get_slice("_",0)][i]
 return f[0]+f[1]*maxi(1,c.rank(i))+f[2]*c.ad*(1.2 if c.buffs.has("exile") else 1.)+f[3]*c.bonus_ap
static func description(id: String,c=null,rank: int=1) -> String:
 var f=DAMAGE[id.get_slice("_",0)][["q","w","e","r"].find(id.get_slice("_",1))]
 if f==[0,0,0,0]:return "Utility skill: see effects above."
 var ad=c.ad*(1.2 if c.buffs.has("exile") else 1.) if c!=null else 0.;var ap=c.bonus_ap if c!=null else 0.;var base=f[0]+f[1]*maxi(1,rank)
 return "%s: %.1f\n%.0f base + %.0f%% AD (%.1f) + %.0f%% AP (%.1f)" % ["Shield" if id=="riven_e" else "Damage per hit / bonus attack",base+f[2]*ad+f[3]*ap,base,f[2]*100,f[2]*ad,f[3]*100,f[3]*ap]
static func enemies(c,point: Vector2,radius: float) -> Array:
 return (GameState.champions+GameState.minions).filter(func(u):return is_instance_valid(u) and not u.dead and u.team!=c.team and u.is_targetable and u.world_pos().distance_to(point)<=radius+u.size*.3)
static func control(u,seconds: float,slow: float=0.) -> void:
 if not "buffs" in u:return
 if u.buffs.has("parry"):
  if slow==0.:u.buffs.parry.blocked_cc=true
  return
 if u.dead or u.buffs.has("cc_guard") or u.buffs.has("spell_guard") or u.buffs.has("spell_ward"):return
 if u.kind=="champion" and u.inventory.has("banshee") and u.item_cds.get("banshee",0.)<=0:return
 if slow>0:u.buffs.slow={"time":seconds,"pct":slow}
 else:u.stun=maxf(u.stun,seconds)
static func physical(c,id: String="") -> bool:
 if id in ["xinzhao_e","fiora_w","caitlyn_e","lucian_w"]:return false
 return c.hero_key in ["renekton","xinzhao","riven","fiora","caitlyn","lucian","sivir"]
static func hit(c,u,id: String,mult: float=1.) -> void:
 c.get_tree().call_group("game_main","deal_damage",c,u,amount(c,id)*mult,"magic" if not physical(c,id) else "physical",id)
static func visual(c,point: Vector2,id: String,radius: float=90.,duration: float=.4,opts: Dictionary={}) -> void:
 opts=opts.duplicate();opts.merge({"effect_id":id,"duration":duration},false);NewHeroKits.area(c,point,radius,0,opts)
static func area(c,point: Vector2,id: String,radius: float,opts: Dictionary={}) -> void:
 opts=opts.duplicate();opts.merge({"effect_id":id,"damage_type":"magic" if not physical(c,id) else "physical"},false);NewHeroKits.area(c,point,radius,amount(c,id),opts)
static func bolt(c,point: Vector2,id: String,opts: Dictionary={}) -> void:
 opts=opts.duplicate();opts.merge({"effect_id":id,"damage_type":"magic" if not physical(c,id) else "physical","size":10.,"life":c.hero.skills[["q","w","e","r"].find(id.get_slice("_",1))].range/750.},false)
 NewHeroKits.projectile(c,c.world_pos(),(point-c.world_pos()).normalized(),amount(c,id),opts)
static func dash(c,point: Vector2) -> bool:
 point=GameState.clamp_walkable(point)
 if c.is_bot and not BotSafety.can_enter(c,point):return false
 c.dash_target=point;c.is_dashing=true;return true
static func ref(u) -> Dictionary:
 return LanSnapshot.target_ref(u)
static func resolve(r: Dictionary):
 if r.is_empty():return null
 if r.kind=="champion":return GameState.champions[r.id] if r.id>=0 and r.id<GameState.champions.size() else null
 for u in GameState.minions:
  if is_instance_valid(u) and u.get_instance_id()==r.id:return u
 return null
static func spheres(c) -> Array:
 return GameState.aoes.filter(func(a):return is_instance_valid(a) and a.src==c and a.zone_kind=="sphere" and a.elapsed<a.duration)
static func remove_sphere(a) -> void:
 GameState.aoes.erase(a);a.queue_free()
static func empowerment(c,damage: float,stun: float=0.,slow: float=0.) -> void:
 c.buffs.roster_attack={"time":5.,"damage":damage,"stun":stun,"slow":slow,"hits":1};c.atk_cd=0.
static func prepare(c,id: String) -> void:
 if c.hero_key=="lucian":c.buffs.lightslinger={"time":5.}
 if c.hero_key=="riven":c.buffs.runes={"time":6.,"stacks":mini(3,int(c.buffs.get("runes",{}).get("stacks",0))+1)}
static func cast(c,id: String,point: Vector2) -> bool:
 var dir=(point-c.world_pos()).normalized();var victim=null
 if dir.length_squared()<.01:dir=c.facing
 match id:
  "leona_q":empowerment(c,amount(c,id),1.);visual(c,c.world_pos(),id,55)
  "leona_w":c.buffs.courage={"time":3.,"dr":.3};c.buffs.eclipse={"time":3.};visual(c,c.world_pos(),id,65,3.,{"follows_src":true})
  "leona_e":bolt(c,point,id,{"pierce":99,"champion_dash":true})
  "leona_r","xerath_w":area(c,point,id,145,{"arm_delay":.65,"duration":1.1,"special_hit":true})
  "blitzcrank_q":bolt(c,point,id,{"hook_chain":true,"pull_distance":560.,"stun":.6,"no_structures":true})
  "blitzcrank_w":c.buffs.haste={"time":4.,"mult":1.4};c.buffs.roster_as={"time":4.,"mult":1.4};c.buffs.overdrive={"time":4.};visual(c,c.world_pos(),id,55,.5)
  "blitzcrank_e":empowerment(c,amount(c,id),1.);visual(c,c.world_pos(),id,55)
  "blitzcrank_r":
   for u in enemies(c,c.world_pos(),230):
    if "shield" in u:u.shield=0.
    if not u.buffs.has("cc_guard"):u.buffs.silence={"time":1.2}
   area(c,c.world_pos(),id,230)
  "renekton_q":
   var fury=Roster12Combat.spend_fury(c);var heal=0.;var fury_gain=0.
   for u in enemies(c,c.world_pos(),160):
    hit(c,u,id,1.5 if fury else 1.);fury_gain+=10. if u.kind=="champion" else 2.5;heal+=(15.+c.ad*.08)*(3. if u.kind=="champion" else 1.)*(2. if fury else 1.)
   if not fury:Roster12Combat.fury(c,minf(30.,fury_gain)*(1.5 if c.hp<c.hp_max*.5 else 1.))
   Roster12Combat.heal(c,minf(c.hp_max*.25,heal));visual(c,c.world_pos(),id,160)
  "renekton_w":
   var fury=Roster12Combat.spend_fury(c);empowerment(c,amount(c,id)*(1.5 if fury else 1.),1.5 if fury else .75);c.buffs.roster_attack.break_shield=fury;visual(c,c.world_pos(),id,60)
  "renekton_e":
   if not dash(c,point):return false
   var touched=Roster12Combat.line_hit(c,c.world_pos(),point,id,38)
   if touched:c.buffs.dice={"time":4.};Roster12Combat.fury(c,10.)
   visual(c,c.world_pos(),id,75)
  "renekton_r":
   var health=100.+80*c.rank(3);c.hp_max+=health;c.hp+=health;c.buffs.dominion={"time":8.,"health":health,"tick":0.};Roster12Combat.fury(c,20.);visual(c,c.world_pos(),id,90,8.,{"follows_src":true})
  "xinzhao_q":empowerment(c,amount(c,id));c.buffs.roster_attack.hits=3;c.buffs.roster_attack.time=6.
  "xinzhao_w":
   NewHeroKits.area(c,c.world_pos(),125,amount(c,id)*.35,{"effect_id":id,"damage_type":"physical","cone_ang":dir.angle(),"arc":PI*.65,"duration":.3})
   c.buffs.wind_thunder={"time":.3,"direction":dir};visual(c,c.world_pos()+dir*235,id,235,.45,{"effect_dir":dir,"footprint_kind":"capsule","footprint_width":42.,"arm_delay":.3})
  "xinzhao_e":
   victim=NewHeroKits.target(c,point,360)
   if victim==null or not dash(c,victim.world_pos()):return false
   c.buffs.challenge={"time":5.,"target":ref(victim)};c.buffs.audacious_charge={"time":1.5,"target":ref(victim),"point":victim.world_pos(),"direction":dir};c.buffs.roster_as={"time":4.,"mult":1.4}
   visual(c,c.world_pos(),id,65,.35,{"follows_src":true,"effect_dir":dir})
  "xinzhao_r":
   var challenged=resolve(c.buffs.get("challenge",{}).get("target",{}))
   for u in enemies(c,c.world_pos(),220):
    hit(c,u,id)
    if u!=challenged:ForcedMotion.apply(u,u.world_pos()-c.world_pos(),180,.25);HeroControl.airborne(u,.25)
   c.buffs.crescent_guard={"time":3.};visual(c,c.world_pos(),id,220)
  "riven_q":
   if not dash(c,point):return false
   area(c,point,id,110);c.buffs.broken_arc={"time":4.,"cast":1};visual(c,point,id,110)
  "riven_w":area(c,c.world_pos(),id,125,{"stun":.75})
  "riven_e":
   if not dash(c,point):return false
   c.shield+=amount(c,id);c.buffs.valor={"time":2.,"shield":amount(c,id)};visual(c,c.world_pos(),id,60,.4)
  "riven_r":c.buffs.exile={"time":8.,"recast":true};visual(c,c.world_pos(),id,70,.6)
  "fiora_q":
   if not dash(c,point):return false
   victim=NewHeroKits.target(c,point,290)
   if victim!=null and victim.world_pos().distance_to(point)<140:
    hit(c,victim,id);c.buffs.lunge_refund={"time":.01}
   visual(c,point,id,75)
  "fiora_w":c.buffs.parry={"time":.75,"point":c.world_pos()+dir*360,"blocked_cc":false};c.stop_actions();visual(c,c.world_pos(),id,65,.75)
  "fiora_e":c.buffs.bladework={"time":5.,"hits":2};c.buffs.roster_as={"time":5.,"mult":1.5};c.atk_cd=0.;visual(c,c.world_pos(),id,60)
  "fiora_r":
   victim=NewHeroKits.target(c,point,410)
   if victim==null or victim.kind!="champion":return false
   victim.buffs.grand_challenge={"time":8.,"src":c,"mask":0};c.buffs.haste={"time":8.,"mult":1.15};visual(c,victim.world_pos(),id,70,8.)
  "caitlyn_q":bolt(c,point,id,{"pierce":99,"falloff":.65,"size":12.})
  "caitlyn_w":
   var traps=GameState.aoes.filter(func(a):return is_instance_valid(a) and a.src==c and a.zone_kind=="trap")
   if traps.size()>=3:remove_sphere(traps[0])
   visual(c,point,id,35,12.,{"zone_kind":"trap","arm_delay":.6,"special_hit":true})
  "caitlyn_e":
   if not dash(c,c.world_pos()-dir*150):return false
   bolt(c,point,id,{"slow":.5,"slow_dur":1.5,"special_hit":true})
  "caitlyn_r":
   victim=NewHeroKits.target(c,point,900)
   if victim==null or victim.kind!="champion":return false
   c.stop_actions();c.buffs.deadeye={"time":1.,"duration":1.,"serial":c.anim_serial+1,"target":ref(victim),"origin":c.world_pos()}
   c.facing=(victim.world_pos()-c.world_pos()).normalized()
   BrushVision.reveal(c,1.25);BrushVision.reveal(victim,1.25)
  "lucian_q":
   victim=NewHeroKits.target(c,point,440)
   if victim==null:return false
   dir=(victim.world_pos()-c.world_pos()).normalized()
   Roster12Combat.line_hit(c,c.world_pos(),c.world_pos()+dir*620,id,26);visual(c,c.world_pos()+dir*310,id,310,.25,{"effect_dir":dir,"footprint_kind":"capsule","footprint_width":26.})
  "lucian_w":bolt(c,point,id,{"special_hit":true})
  "lucian_e":
   if not dash(c,point):return false
   visual(c,c.world_pos(),id,65)
  "lucian_r":c.buffs.culling={"time":2.4,"tick":0.,"shots":0,"direction":dir};visual(c,c.world_pos(),id,65,.3)
  "sivir_q":bolt(c,point,id,{"pierce":99,"boomerang":true,"life":1.8,"speed":720.})
  "sivir_w":c.buffs.ricochet={"time":6.,"hits":3};c.atk_cd=0.;visual(c,c.world_pos(),id,60)
  "sivir_e":c.buffs.spell_ward={"time":2.};visual(c,c.world_pos(),id,65,2.,{"follows_src":true})
  "sivir_r":
   for ally in GameState.champions:
    if ally.team==c.team and not ally.dead and ally.world_pos().distance_to(c.world_pos())<450:ally.buffs.haste={"time":6.,"mult":1.3};visual(ally,ally.world_pos(),id,60,.6)
  "brand_q":bolt(c,point,id,{"special_hit":true})
  "brand_w":area(c,point,id,140,{"arm_delay":.7,"duration":1.1,"special_hit":true})
  "brand_e":
   victim=NewHeroKits.target(c,point,400)
   if victim==null:return false
   var spread=190. if victim.buffs.has("blaze") else 95.
   for u in enemies(c,victim.world_pos(),spread):hit(c,u,id)
   visual(c,victim.world_pos(),id,spread)
  "brand_r":
   victim=NewHeroKits.target(c,point,500)
   if victim==null:return false
   bolt(c,point,id,{"homing":victim,"special_hit":true,"bounces":4,"life":3.})
  "syndra_q":area(c,point,id,110);visual(c,point,id,38,6.,{"zone_kind":"sphere"})
  "syndra_w":
   var found=null;var gap=300.
   for s in spheres(c):
    if s.global_position.distance_to(point)<gap:gap=s.global_position.distance_to(point);found=s
   var held={}
   if found!=null:remove_sphere(found)
   else:
    victim=NewHeroKits.target(c,point,490)
    if victim==null or victim.kind!="minion":return false
    held=ref(victim);victim.buffs.held_sphere={"time":4.,"src":c};victim.is_targetable=false;victim.stun=maxf(victim.stun,4.)
   c.buffs.force_of_will={"time":4.,"held":held};visual(c,c.world_pos(),id,50,.4)
  "syndra_e":
   for u in enemies(c,c.world_pos(),210):
    if dir.dot((u.world_pos()-c.world_pos()).normalized())>(.2 if c.passive_state.get("splinters",0)>=80 else .5):
     hit(c,u,id);ForcedMotion.apply(u,dir,130,.25)
     if c.passive_state.get("splinters",0)>=80:control(u,1.25,.7)
   for s in spheres(c):
    if c.world_pos().distance_to(s.global_position)<360 and dir.dot((s.global_position-c.world_pos()).normalized())>.35:
     NewHeroKits.projectile(c,s.global_position,dir,amount(c,id),{"effect_id":id,"damage_type":"magic","speed":850.,"life":.7,"stun":1.5,"pierce":99,"size":16.});remove_sphere(s)
   visual(c,c.world_pos(),id,210,.4,{"cone_ang":dir.angle(),"arc":acos(.2 if c.passive_state.get("splinters",0)>=80 else .5)*2.})
  "syndra_r":
   victim=NewHeroKits.target(c,point,500)
   if victim==null or victim.kind!="champion":return false
   var count=3
   for s in spheres(c):
    if count>=7:break
    if c.world_pos().distance_to(s.global_position)<550:count+=1;remove_sphere(s)
   c.buffs.sphere_barrage={"time":2.,"target":ref(victim),"shots":count,"tick":0.}
  "xerath_q":c.buffs.arcanopulse={"time":1.5,"duration":1.5,"point":point};c.buffs.slow={"time":1.5,"pct":.35};visual(c,c.world_pos(),id,60,.3)
  "xerath_e":bolt(c,point,id,{"special_hit":true,"origin":c.world_pos()})
  "xerath_r":c.stop_actions();c.buffs.artillery={"time":8.,"shots":3,"ready":0.};visual(c,c.world_pos(),id,80,8.,{"follows_src":true})
  _:return false
 prepare(c,id);return true
static func recast_info(c,index: int) -> Dictionary:
 var key=""
 match c.hero_key:
  "renekton":if index==2:key="dice"
  "riven":key="broken_arc" if index==0 else "exile" if index==3 and c.buffs.get("exile",{}).get("recast",false) else ""
  "syndra":if index==1:key="force_of_will"
  "xerath":key="arcanopulse" if index==0 else "artillery" if index==3 else ""
 if key.is_empty() or not c.buffs.has(key):return {}
 var b=c.buffs[key]
 return {"time":b.time,"duration":b.get("duration",8. if key in ["exile","artillery"] else 4.),"label":["Q","W","E","R"][index]+" RECAST"+(" (%d)" % b.shots if key=="artillery" else ""),"available":b.get("ready",0.)<=0.}
static func recast(c,index: int,point: Vector2) -> bool:
 var info=recast_info(c,index)
 if info.is_empty() or not info.available:return false
 var id=c.hero_key+"_"+["q","w","e","r"][index];var dir=(point-c.world_pos()).normalized()
 match id:
  "renekton_e":
   point=c.world_pos()+dir*minf(240,c.world_pos().distance_to(point))
   if not dash(c,point):return false
   var empowered=Roster12Combat.spend_fury(c);Roster12Combat.line_hit(c,c.world_pos(),point,id,38,0.,empowered);c.buffs.erase("dice")
  "riven_q":
   point=c.world_pos()+dir*minf(150,c.world_pos().distance_to(point))
   if not dash(c,point):return false
   var n=int(c.buffs.broken_arc.cast)+1;area(c,point,id,110,{"airborne":.65 if n==3 else 0.})
   if n==3:c.buffs.erase("broken_arc")
   else:c.buffs.broken_arc.cast=n;c.buffs.broken_arc.time=4.
  "riven_r":bolt(c,point,id,{"pierce":99,"special_hit":true,"size":20.});c.buffs.exile.recast=false
  "syndra_w":
   point=c.world_pos()+dir*minf(490,c.world_pos().distance_to(point));var held=resolve(c.buffs.force_of_will.held)
   if is_instance_valid(held):held.global_position=GameState.clamp_walkable(point);held.is_targetable=true;held.stun=0.;held.buffs.erase("held_sphere")
   else:visual(c,point,"syndra_q",38,6.,{"zone_kind":"sphere"})
   area(c,point,id,135,{"slow":.35,"slow_dur":1.5});c.buffs.erase("force_of_will")
  "xerath_q":Roster12Combat.release_beam(c,point);c.buffs.erase("arcanopulse");c.buffs.erase("slow")
  "xerath_r":
   point=c.world_pos()+dir*minf(1000,c.world_pos().distance_to(point));area(c,point,id,130,{"arm_delay":.6,"duration":1.0});c.buffs.artillery.shots-=1;c.buffs.artillery.ready=.65
   if c.buffs.artillery.shots<=0:c.buffs.erase("artillery")
  _:return false
 prepare(c,id);return true
