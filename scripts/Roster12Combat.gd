class_name Roster12Combat
extends RefCounted
static func heal(c,value: float) -> void:
 c.hp=minf(c.hp_max,c.hp+value*ExpansionCombat.healing_multiplier(c))
static func fury(c,value: float) -> void:
 c.buffs.fury={"time":9999.,"value":clampf(c.buffs.get("fury",{}).get("value",0.)+value,0.,100.)}
static func spend_fury(c) -> bool:
 if c.buffs.get("fury",{}).get("value",0.)<50:return false
 fury(c,-50.);return true
static func line_hit(c,start: Vector2,end: Vector2,id: String,width: float,slow: float=0.,shred: bool=false,mult: float=1.) -> bool:
 var found=false
 for u in Roster12Kits.enemies(c,start,start.distance_to(end)+width):
  if Geometry2D.get_closest_point_to_segment(u.world_pos(),start,end).distance_to(u.world_pos())>width+u.size*.3:continue
  found=true;Roster12Kits.hit(c,u,id,mult)
  if slow>0:Roster12Kits.control(u,1.5,slow)
  if shred:u.buffs.armor_shred={"time":4.,"stacks":4}
 return found
static func release_beam(c,point: Vector2) -> void:
 var b=c.buffs.arcanopulse;var reach=350.+400.*clampf((1.5-b.time)/1.5,0.,1.);var dir=(point-c.world_pos()).normalized()
 line_hit(c,c.world_pos(),c.world_pos()+dir*reach,"xerath_q",30)
 Roster12Kits.visual(c,c.world_pos()+dir*reach*.5,"xerath_q",reach*.5,.3,{"effect_dir":dir,"footprint_kind":"capsule","footprint_width":30.})
static func blocked(src,target,kind: String) -> bool:
 if target.kind!="champion":return false
 if target.buffs.has("parry"):
  return true
 if target.buffs.has("crescent_guard") and is_instance_valid(src) and src.world_pos().distance_to(target.world_pos())>220:return true
 if target.buffs.has("spell_ward") and kind in ["skill","magic","physical"]:
  target.buffs.erase("spell_ward");target.buffs.spell_guard={"time":.15};target.mp=minf(target.mp_max,target.mp+60.);return true
 return false
static func preview_auto_bonus(c,target) -> float:
 var bonus=c.ad*.2 if c.buffs.has("exile") else 0.
 if c.buffs.has("runes"):bonus+=c.ad*(.3+.3*(mini(c.level,18)-1)/17.)*(1.2 if c.buffs.has("exile") else 1.)
 if c.buffs.has("roster_attack") and c.hero_key!="leona":bonus+=c.buffs.roster_attack.damage
 if c.buffs.has("bladework") and c.buffs.bladework.hits==1:bonus+=c.ad*.6
 if c.hero_key=="caitlyn":
  var n=int(c.passive_state.get("headshot",0))+(2 if BrushVision.patch_at(c.world_pos())>=0 else 1)
  if n>=6 or ("buffs" in target and target.buffs.get("rifle_mark",{}).get("src")==c):bonus+=c.ad*(.65+HeroPassives.critical_chance(c)*.75)
 return bonus
static func before_auto(c,target) -> float:
 var bonus=preview_auto_bonus(c,target)
 if c.buffs.has("runes"):
  c.buffs.runes.stacks-=1
  if c.buffs.runes.stacks<=0:c.buffs.erase("runes")
 if c.buffs.has("roster_attack") and c.buffs.roster_attack.get("break_shield",false) and "shield" in target:target.shield=0.
 if c.hero_key=="caitlyn":
  var n=int(c.passive_state.get("headshot",0))+(2 if BrushVision.patch_at(c.world_pos())>=0 else 1)
  if n>=6:n=0
  if "buffs" in target and target.buffs.get("rifle_mark",{}).get("src")==c:target.buffs.erase("rifle_mark")
  c.passive_state.headshot=n
 return bonus
static func after_hit(src,target,kind: String) -> void:
 var secondary=kind=="secondary_auto"
 if secondary:kind="auto"
 if not is_instance_valid(src) or src.kind!="champion" or target.kind=="structure":return
 if target.buffs.has("sunlight") and target.buffs.sunlight.src!=src and is_instance_valid(target.buffs.sunlight.src) and target.buffs.sunlight.src.team==src.team and kind in ["auto","magic","physical","skill"]:
  var mark=target.buffs.sunlight;target.buffs.erase("sunlight")
  if is_instance_valid(mark.src):NewHeroKits.hit(mark.src,target,20.+mark.src.level*3.,"item_magic")
 if src.hero_key=="xinzhao" and kind=="physical" and target.kind=="champion":src.buffs.challenge={"time":5.,"target":Roster12Kits.ref(target)}
 if src.hero_key=="leona" and kind=="magic":target.buffs.sunlight={"time":1.5,"src":src}
 if src.hero_key=="brand" and kind=="magic" and target.hp>0:
  var b=target.buffs.get("blaze",{"stacks":0,"tick":0.});b.stacks=mini(3,int(b.stacks)+1);b.time=4.;b.src=src;target.buffs.blaze=b
  if b.stacks>=3 and target.kind=="champion" and not target.buffs.has("blaze_lock"):
   target.buffs.blaze_detonate={"time":1.,"src":src};target.buffs.blaze_lock={"time":5.}
 if kind!="auto":return
 if src.hero_key=="renekton":fury(src,7.5 if src.hp<src.hp_max*.5 else 5.)
 if src.buffs.has("roster_attack"):
  var b=src.buffs.roster_attack;var stun=b.stun
  if src.hero_key=="leona":
   NewHeroKits.hit(src,target,b.damage,"item_magic");target.buffs.sunlight={"time":1.5,"src":src}
  if src.hero_key=="xinzhao":
   stun=0.
   if b.hits==1:HeroControl.airborne(target,1.)
   Roster12Kits.visual(src,target.world_pos(),"xinzhao_q",48,.22,{"effect_dir":Vector2.UP if b.hits==1 else (target.world_pos()-src.world_pos()).normalized()})
   for i in range(3):src.skill_cds[i]=maxf(0.,src.skill_cds[i]-1.)
  if src.hero_key=="blitzcrank":HeroControl.airborne(target,1.)
  elif stun>0:Roster12Kits.control(target,stun)
  if b.slow>0:Roster12Kits.control(target,1.5,b.slow)
  b.hits-=1
  if b.hits<=0:src.buffs.erase("roster_attack")
 if src.buffs.has("bladework"):
  if src.buffs.bladework.hits==2:Roster12Kits.control(target,1.,.3)
  src.buffs.bladework.hits-=1
  if src.buffs.bladework.hits<=0:src.buffs.erase("bladework");src.buffs.erase("roster_as")
 if src.hero_key=="xinzhao":
  src.buffs.challenge={"time":5.,"target":Roster12Kits.ref(target)}
 if src.hero_key=="blitzcrank" and src.rank(3)>0:target.buffs.static_mark={"time":1.,"src":src}
 if src.hero_key=="xerath" and src.item_cds.get("arcane_mana",0.)<=0:
  src.mp=minf(src.mp_max,src.mp+(25.+mini(src.level,18)*2.)*(2. if target.kind=="champion" else 1.));src.item_cds.arcane_mana=8.
 if not secondary and src.buffs.has("lightslinger"):
  src.buffs.erase("lightslinger");NewHeroKits.projectile(src,src.world_pos(),(target.world_pos()-src.world_pos()).normalized(),src.ad*.5,{"homing":target,"damage_type":"secondary_auto","effect_id":"lucian_auto","speed":950.,"size":7.});src.skill_cds[2]=maxf(0.,src.skill_cds[2]-1.)
 if target.buffs.get("radiant_mark",{}).get("src")==src:src.buffs.haste={"time":1.5,"mult":1.2}
 if src.buffs.has("ricochet"):
  src.buffs.ricochet.hits-=1
  var candidates=Roster12Kits.enemies(src,target.world_pos(),230);candidates.erase(target)
  candidates.sort_custom(func(a,b):return a.world_pos().distance_squared_to(target.world_pos())<b.world_pos().distance_squared_to(target.world_pos()))
  for u in candidates.slice(0,3):NewHeroKits.projectile(src,target.world_pos(),(u.world_pos()-target.world_pos()).normalized(),src.ad*.45,{"homing":u,"damage_type":"item_physical","effect_id":"sivir_w","speed":850.,"size":8.})
  if src.buffs.ricochet.hits<=0:src.buffs.erase("ricochet")
static func vital(c,target,origin: Vector2) -> void:
 if target.kind!="champion" or target.dead:return
 var side=posmod(int(round((origin-target.world_pos()).angle()/(PI/2))),4)
 if target.buffs.has("grand_challenge") and target.buffs.grand_challenge.src==c:
  var b=target.buffs.grand_challenge
  if int(b.mask)&(1<<side):return
  b.mask=int(b.mask)|(1<<side)
  NewHeroKits.hit(c,target,target.hp_max*(.025+c.bonus_ad*.0002),"exec");heal(c,20.+c.level*2.);c.buffs.haste={"time":1.5,"mult":1.2}
  if b.mask==15 or target.hp<=0:healing_field(c,target.world_pos());target.buffs.erase("grand_challenge")
 else:
  var key="vital_"+str(GameState.champions.find(c));var exposed=int(target.buffs.get(key,{}).get("side",posmod(GameState.champions.find(target),4)))
  if side!=exposed:return
  target.buffs[key]={"time":8.,"side":(exposed+1)%4,"src":c}
  NewHeroKits.hit(c,target,target.hp_max*(.025+c.bonus_ad*.0002),"exec");heal(c,15.+c.level*2.);c.buffs.haste={"time":1.5,"mult":1.2}
static func healing_field(c,point: Vector2) -> void:
 Roster12Kits.visual(c,point,"fiora_r",170,4.,{"zone_kind":"heal_field"})
static func projectile_hit(p,u) -> void:
 if not is_instance_valid(p.src) or u.kind=="structure":return
 var c=p.src
 if u.buffs.has("spell_guard") or u.buffs.has("parry"):return
 match p.effect_id:
  "leona_e":if u.kind=="champion":c.buffs.zenith={"time":.05,"target":Roster12Kits.ref(u)};Roster12Kits.control(u,.5)
  "caitlyn_e":u.buffs.rifle_mark={"time":4.,"src":c}
  "lucian_w":
   for v in Roster12Kits.enemies(c,u.world_pos(),90):
    v.buffs.radiant_mark={"time":4.,"src":c}
    if v!=u:Roster12Kits.hit(c,v,"lucian_w")
   Roster12Kits.visual(c,u.world_pos(),"lucian_w",90)
  "brand_r":
   if p.bounces<=0:return
   var pool=Roster12Kits.enemies(c,u.world_pos(),280);pool.erase(u)
   pool.sort_custom(func(a,b):return a.kind=="champion" and b.kind!="champion")
   if not pool.is_empty():NewHeroKits.projectile(c,u.world_pos(),(pool[0].world_pos()-u.world_pos()).normalized(),p.dmg,{"effect_id":p.effect_id,"homing":pool[0],"damage_type":"magic","bounces":p.bounces-1,"special_hit":true,"life":2.,"size":12.})
static func tick(c,delta: float) -> void:
 if c.kind=="champion" and c.buffs.has("audacious_charge") and c.is_dashing:
  var chased=Roster12Kits.resolve(c.buffs.audacious_charge.target)
  if is_instance_valid(chased) and not chased.dead:c.dash_target=GameState.clamp_walkable(chased.world_pos())
 if c.kind=="champion" and c.buffs.has("audacious_charge") and not c.is_dashing:
  var charge=c.buffs.audacious_charge;c.buffs.erase("audacious_charge")
  Roster12Kits.area(c,c.world_pos(),"xinzhao_e",110,{"slow":.3,"slow_dur":.5,"duration":.35,"effect_dir":charge.direction})
 if c.kind=="champion" and c.hero_key=="fiora":
  for u in Roster12Kits.enemies(c,c.world_pos(),600):
   if u.kind=="champion" and (not u.buffs.has("grand_challenge") or u.buffs.grand_challenge.src!=c) and not u.buffs.has("vital_"+str(GameState.champions.find(c))):u.buffs["vital_"+str(GameState.champions.find(c))]={"time":8.,"side":posmod(GameState.champions.find(u),4),"src":c}
 if c.buffs.has("arcanopulse") and c.stun>0:c.buffs.erase("arcanopulse");c.buffs.erase("slow")
 for key in ["culling","sphere_barrage","dominion","blaze"]:
  if not c.buffs.has(key):continue
  var b=c.buffs[key];b.tick=b.get("tick",0.)+delta
  match key:
   "culling":
    if c.stun>0:c.buffs.erase(key);continue
    if b.tick>=2.4/18. and b.shots<18:
     b.tick-=2.4/18.;b.shots+=1;Roster12Kits.bolt(c,c.world_pos()+b.direction*720,"lucian_r",{"pierce":99,"speed":1050.,"size":7.,"life":.7})
   "sphere_barrage":
    var u=Roster12Kits.resolve(b.target)
    if not is_instance_valid(u) or u.dead:c.buffs.erase(key);continue
    if b.tick>=.12 and b.shots>0:
     b.tick-=.12;b.shots-=1;Roster12Kits.bolt(c,u.world_pos(),"syndra_r",{"homing":u,"life":2.})
   "dominion":
    if b.tick>=.5:b.tick-=.5;fury(c,5.);Roster12Kits.area(c,c.world_pos(),"renekton_r",140,{"duration":.2})
   "blaze":
    if b.tick>=1.:
     b.tick-=1.
     if is_instance_valid(b.src):NewHeroKits.hit(b.src,c,c.hp_max*.005*b.stacks,"burn")
 if c.buffs.has("artillery"):
  c.buffs.artillery.ready=maxf(0.,c.buffs.artillery.ready-delta);c.stop_actions()
  if c.is_bot and c.stun<=0:
   var artillery_target=GameState.find_nearest_enemy(c,c.world_pos(),1000)
   if artillery_target!=null:Roster12Kits.recast(c,3,artillery_target.world_pos())
  if c.stun>0:c.buffs.erase("artillery")
 if c.buffs.has("deadeye") and (c.stun>0 or c.has_move_target or c.world_pos().distance_to(c.buffs.deadeye.origin)>10 or DeadeyeCue.channel(c).is_empty()):c.buffs.erase("deadeye")
 if c.buffs.has("parry"):c.stop_actions();c.stun=0.
 if c.buffs.has("grand_challenge") and c.hp<=0 and c.buffs.grand_challenge.mask>0:
  var src=c.buffs.grand_challenge.src
  if is_instance_valid(src):healing_field(src,c.world_pos())
  c.buffs.erase("grand_challenge")
static func expire(c,key: String,b: Dictionary) -> void:
 match key:
  "wind_thunder":
   if not c.dead:line_hit(c,c.world_pos(),c.world_pos()+b.direction*470,"xinzhao_w",42,.3,false,.65)
  "eclipse":
   if not c.dead:
    if not Roster12Kits.enemies(c,c.world_pos(),165).is_empty():c.buffs.courage={"time":2.,"dr":.3}
    Roster12Kits.area(c,c.world_pos(),"leona_w",165)
  "overdrive":c.buffs.slow={"time":1.,"pct":.3}
  "dominion":c.hp_max=maxf(1.,c.hp_max-b.health);c.hp=minf(c.hp,c.hp_max)
  "lunge_refund":c.skill_cds[0]*=.6
  "parry":
   if not c.dead:Roster12Kits.bolt(c,b.point,"fiora_w",{"stun":1.5 if b.blocked_cc else 0.,"slow":0. if b.blocked_cc else .5,"slow_dur":1.5,"pierce":99})
  "zenith":
   var u=Roster12Kits.resolve(b.target)
   if is_instance_valid(u) and not u.dead:Roster12Kits.dash(c,u.world_pos())
  "deadeye":
   var u=Roster12Kits.resolve(b.target)
   if is_instance_valid(u) and not u.dead and u.is_targetable and not c.dead and c.stun<=0:
    Roster12Kits.bolt(c,u.world_pos(),"caitlyn_r",{"homing":u,"interceptable":true,"life":3.,"speed":1100.,"is_ult":true})
    c.animator.start("r",.24);c.anim_from=4;c.anim_to=5
    c.get_tree().call_group("game_main","play_sfx","deadeye_fire",c)
  "arcanopulse":
   if not c.dead and c.stun<=0:c.buffs.arcanopulse=b;release_beam(c,b.point);c.buffs.erase("arcanopulse")
  "force_of_will":
   var u=Roster12Kits.resolve(b.held)
   if is_instance_valid(u):u.is_targetable=true;u.buffs.erase("held_sphere")
  "held_sphere":c.is_targetable=true
  "static_mark":if is_instance_valid(b.src):NewHeroKits.hit(b.src,c,15.+b.src.bonus_ap*.15,"item_magic")
  "blaze_detonate":
   if is_instance_valid(b.src):
    var src=b.src;Roster12Kits.visual(src,c.world_pos(),"brand_r",140)
    for u in Roster12Kits.enemies(src,c.world_pos(),140):NewHeroKits.hit(src,u,u.hp_max*.06+src.bonus_ap*.2,"burn")
static func special_damage(effect: String,src,u,value: float,origin: Vector2) -> float:
 if u.kind=="structure":return value
 match effect:
  "brand_q":if u.buffs.has("blaze"):Roster12Kits.control(u,1.5)
  "brand_w":if u.buffs.has("blaze"):value*=1.25
  "riven_r":value*=1.+minf(2.,(1.-u.hp/u.hp_max)*3.)
  "xerath_e":Roster12Kits.control(u,clampf(origin.distance_to(u.world_pos())/650.*1.8,.5,1.8))
  "xerath_w":if origin.distance_to(u.world_pos())<=65:value*=1.5;Roster12Kits.control(u,1.5,.6)
  "leona_r":Roster12Kits.control(u,1.5,0. if origin.distance_to(u.world_pos())<65 else .7)
 return value

static func on_death(c) -> void:
 if c.buffs.has("grand_challenge"):
  var b=c.buffs.grand_challenge
  if b.mask>0 and is_instance_valid(b.src):healing_field(b.src,c.world_pos())
  c.buffs.erase("grand_challenge")
 if c.buffs.has("force_of_will"):
  var held=Roster12Kits.resolve(c.buffs.force_of_will.held)
  if is_instance_valid(held):held.is_targetable=true;held.stun=0.;held.buffs.erase("held_sphere")
 if c.buffs.has("dominion"):c.hp_max=maxf(1.,c.hp_max-c.buffs.dominion.health)
 for key in ["dominion","force_of_will","artillery","arcanopulse","deadeye","culling","parry","sphere_barrage"]:c.buffs.erase(key)
