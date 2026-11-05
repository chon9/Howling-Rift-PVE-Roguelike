class_name NewHeroKits
extends RefCounted
static func target(c, point: Vector2, reach: float, allies: bool = false, allied_minions: bool = false):
 var best = null
 var gap = 100.0
 for unit in GameState.champions + (GameState.minions if not allies or allied_minions else []):
  if unit == c or unit.dead or not unit.is_targetable: continue
  if (unit.team == c.team) != allies or not BrushVision.visible_to(unit,c.team): continue
  if c.world_pos().distance_to(unit.world_pos()) > reach: continue
  var distance = point.distance_to(unit.world_pos())
  if distance < gap: gap = distance; best = unit
 return best
static func hit(c, victim, amount: float, type: String = "skill") -> void:
 c.get_tree().call_group("game_main","deal_damage",c,victim,amount,type)
static func projectile(c, origin: Vector2, direction: Vector2, damage: float, opts: Dictionary = {}) -> void:
 var settings = {"dmg":damage,"speed":750,"size":10,"life":1.3,"color":c.hero.accent,"trail":true,"shape":"bolt","damage_type":"skill"}
 settings.merge(opts,true)
 c.get_tree().call_group("game_main","spawn_projectile",c,origin,direction,settings)
static func area(c, point: Vector2, radius: float, damage: float, opts: Dictionary = {}) -> void:
 var settings = {"radius":radius,"dmg":damage,"color":c.hero.accent,"duration":0.4}
 settings.merge(opts,true)
 c.get_tree().call_group("game_main","spawn_aoe",c,point,settings)
static func sonic_mark_target(c):
 if is_instance_valid(c.sonic_target) and not c.sonic_target.dead:
  var mark = c.sonic_target.buffs.get("sonic_mark",{})
  if mark.get("src") == c and mark.get("time",0)>0: return c.sonic_target
 # Guests reconstruct marks from replicated buffs; this also handles marks on minions.
 for unit in GameState.champions+GameState.minions:
  if not is_instance_valid(unit) or unit.dead: continue
  var mark = unit.buffs.get("sonic_mark",{})
  if mark.get("src") == c and mark.get("time",0)>0: return unit
 return null
static func recast_info(c, index: int) -> Dictionary:
 if c.dead: return {}
 if c.hero_key in SupportRoster.KEYS:return SupportKits.recast_info(c,index)
 if c.hero_key in RosterExpansion12.KEYS:return Roster12Kits.recast_info(c,index)
 if c.hero_key=="thresh" and index==0:
  for unit in GameState.champions+GameState.minions:
   if not is_instance_valid(unit) or unit.dead:continue
   var mark=unit.buffs.get("chain_mark",{})
   if mark.get("src")==c and mark.get("time",0)>0:
    return {"time":float(mark.time),"duration":1.5,"label":"Q2 HOOK","available":c.world_pos().distance_to(unit.world_pos())<=650,"target":unit}
 if c.hero_key == "leesin" and index == 0:
  var victim = sonic_mark_target(c)
  if victim != null:
   return {"time":float(victim.buffs.sonic_mark.time),"duration":4.0,"label":"Q2 DASH","available":c.world_pos().distance_to(victim.world_pos())<=650,"target":victim}
 if c.hero_key == "zed" and index == 1 and c.buffs.has("shadow") and c.buffs.shadow.time > 0 and not c.buffs.shadow.swapped:
  return {"time":float(c.buffs.shadow.time),"duration":4.0,"label":"W2 SWAP","available":true}
 return {}
static func recast(c, index: int, point: Vector2) -> bool:
 if c.hero_key in SupportRoster.KEYS:return SupportKits.recast(c,index)
 if c.hero_key in RosterExpansion12.KEYS:return Roster12Kits.recast(c,index,point)
 if c.hero_key=="thresh" and index==0:
  var info=recast_info(c,index)
  if info.is_empty() or not info.available:return false
  var victim=info.target
  if c.is_bot and not BotSafety.can_enter(c,victim.world_pos(),victim.kind=="champion"):return false
  c.dash_target=GameState.clamp_walkable(victim.world_pos());c.is_dashing=true
  victim.buffs.erase("chain_mark")
  return true
 if c.hero_key == "leesin" and index == 0:
  c.sonic_target = sonic_mark_target(c)
 if c.hero_key == "leesin" and index == 0 and is_instance_valid(c.sonic_target) and not c.sonic_target.dead:
  var mark = c.sonic_target.buffs.get("sonic_mark",{})
  if mark.get("src") == c and mark.get("time",0) > 0 and c.world_pos().distance_to(c.sonic_target.world_pos()) <= 650:
   var victim = c.sonic_target
   if c.is_bot and not BotSafety.can_enter(c,victim.world_pos(),victim.kind == "champion"): return false
   c.dash_target = GameState.clamp_walkable(victim.world_pos())
   c.is_dashing = true
   hit(c,victim,70+35*c.rank(0)+minf(150,(victim.hp_max-victim.hp)*0.1))
   victim.buffs.erase("sonic_mark")
   c.sonic_target = null
   return true
 if c.hero_key == "zed" and index == 1 and c.buffs.has("shadow") and c.buffs.shadow.time > 0 and not c.buffs.shadow.swapped:
  if c.is_bot and not BotSafety.can_enter(c,c.buffs.shadow.point,true): return false
  var previous = c.world_pos()
  c.global_position = GameState.clamp_walkable(c.buffs.shadow.point)
  c.buffs.shadow.point = previous
  c.buffs.shadow.swapped = true
  return true
 return false
static func cast(c, id: String, point: Vector2) -> bool:
 var direction = (point-c.world_pos()).normalized()
 if direction.length_squared() < 0.01: direction = c.facing
 match id:
  "yasuo_q":
   var stacks = int(c.buffs.get("tempest",{}).get("stacks",0))+1
   c.buffs.tempest = {"time":6.0,"stacks":stacks%3}
   projectile(c,c.world_pos(),direction,45+25*c.rank(0)+c.ad*0.6,{"pierce":99,"life":0.65,"stun":1.25 if stacks==3 else 0.0,"size":20 if stacks==3 else 9,"shape":"wave","wind_kind":1 if stacks==3 else 0})
  "yasuo_w": c.buffs.wind_wall = {"time":2.5,"direction":direction}
  "yasuo_e":
   var victim = target(c,point,280)
   if victim == null: return false
   var destination = GameState.clamp_walkable(victim.world_pos()+direction*65)
   if c.is_bot and not BotSafety.can_enter(c,destination,victim.kind == "champion"): return false
   c.dash_target = destination
   c.is_dashing = true
   hit(c,victim,45+25*c.rank(2)+c.ad*0.4)
  "yasuo_r":
   var victim = target(c,point,500)
   if victim == null or not victim.buffs.has("airborne"): return false
   var destination = GameState.clamp_walkable(victim.world_pos()-direction*40)
   if c.is_bot and not BotSafety.can_enter(c,destination,true): return false
   c.global_position = destination
   area(c,victim.world_pos(),140,150+100*c.rank(3),{"stun":0.8,"wind_kind":3})
  "leesin_q":
   c.sonic_target = null
   projectile(c,c.world_pos(),direction,55+30*c.rank(0)+c.ad*0.6,{"sonic_mark":true,"life":0.95})
  "leesin_w":
   var ally = target(c,point,400,true,true)
   if ally != null and (not c.is_bot or BotSafety.can_enter(c,ally.world_pos())):
    c.dash_target = GameState.clamp_walkable(ally.world_pos())
    c.is_dashing = true
    if ally.kind == "champion":CombatEffects.shield(ally,"safeguard_shield",70+35*c.rank(1),4.,c)
   CombatEffects.shield(c,"safeguard_shield",70+35*c.rank(1),4.)
   c.buffs.iron_will = {"time":4.0,"lifesteal":0.2}
  "leesin_e": area(c,c.world_pos(),170,50+30*c.rank(2),{"slow":0.35,"slow_dur":2.0})
  "leesin_r":
   var victim = target(c,point,210)
   if victim == null: return false
   hit(c,victim,150+100*c.rank(3)+c.ad*0.8)
   HeroControl.airborne(victim,1.0)
   projectile(c,victim.world_pos(),direction,80+60*c.rank(3),{"pierce":99,"life":0.5,"size":22})
   victim.global_position = GameState.clamp_walkable(victim.world_pos()+direction*260)
  "zed_q":
   projectile(c,c.world_pos(),direction,40+25*c.rank(0)+c.ad*0.65,{"pierce":99,"shape":"arrow"})
   if c.buffs.has("shadow"):
    projectile(c,c.buffs.shadow.point,(point-c.buffs.shadow.point).normalized(),40+25*c.rank(0)+c.ad*0.65,{"pierce":99,"shape":"arrow"})
  "zed_w": c.buffs.shadow = {"time":4.0,"point":GameState.clamp_walkable(point),"swapped":false}
  "zed_e":
   area(c,c.world_pos(),135,40+30*c.rank(2),{"slow":0.3,"slow_dur":1.5})
   if c.buffs.has("shadow"): area(c,c.buffs.shadow.point,135,40+30*c.rank(2),{"slow":0.3,"slow_dur":1.5})
  "zed_r":
   var victim = target(c,point,400)
   if victim == null: return false
   if c.is_bot and not BotSafety.can_enter(c,victim.world_pos(),true): return false
   c.global_position = GameState.clamp_walkable(victim.world_pos()+direction*45)
   if ExpansionCombat.spell_block(victim,"physical") or Roster12Combat.blocked(c,victim,"physical"):return true
   victim.buffs.death_mark = {"time":3.0,"src":c,"stored":0.0,"base":90+80*c.rank(3)}
  "jinx_q": c.buffs.rockets = {"time":6.0}
  "jinx_w": projectile(c,c.world_pos(),direction,40+30*c.rank(1)+c.ad*0.8,{"slow":0.5,"slow_dur":2.0,"life":1.05})
  "jinx_e":
   var trap_hits: Array = []
   for offset in [-50,0,50]: area(c,point+Vector2(offset,0),32,35+25*c.rank(2),{"duration":3.0,"stun":1.2,"hit_set":trap_hits})
  "jinx_r": projectile(c,c.world_pos(),direction,150+100*c.rank(3)+c.ad*0.6,{"life":2.0,"size":24,"speed":900,"is_ult":true,"shape":"fireball","explosion":145})
  "katarina_q":
   var victim = target(c,point,500)
   if victim == null: return false
   var targets = [victim]
   for other in GameState.champions+GameState.minions:
    if other == victim or other.dead or other.team == c.team or other.world_pos().distance_to(victim.world_pos()) > 220: continue
    targets.append(other)
    if targets.size() >= 3: break
   for other in targets: projectile(c,c.world_pos(),(other.world_pos()-c.world_pos()).normalized(),40+25*c.rank(0),{"homing":other,"shape":"arrow"})
  "katarina_w":
   area(c,c.world_pos(),140,35+25*c.rank(1))
   c.buffs.haste = {"time":2.0,"mult":1.3}
  "katarina_e":
   var victim = target(c,point,380)
   if victim == null: victim = target(c,point,380,true)
   if victim == null: return false
   if c.is_bot and not BotSafety.can_enter(c,victim.world_pos(),victim.team != c.team): return false
   c.global_position = GameState.clamp_walkable(victim.world_pos()-direction*35)
   if victim.team != c.team: hit(c,victim,45+30*c.rank(2))
  "katarina_r": c.buffs.spin = {"time":2.5,"tick":0.0,"dmg":30+20*c.rank(3),"radius":140}
  "kayle_q": projectile(c,c.world_pos(),direction,45+30*c.rank(0),{"pierce":99,"slow":0.3,"slow_dur":2.0,"shape":"wave"})
  "kayle_w":
   c.hp = minf(c.hp_max,c.hp+(90+45*c.rank(1))*ExpansionCombat.healing_multiplier(c))
   c.buffs.haste = {"time":2.0,"mult":1.3}
   var ally = target(c,point,400,true)
   if ally != null:
    ally.hp = minf(ally.hp_max,ally.hp+(90+45*c.rank(1))*ExpansionCombat.healing_multiplier(ally));HeroPassives.support(c,ally)
    ally.buffs.haste = {"time":2.0,"mult":1.3}
  "kayle_e": c.buffs.righteous = {"time":5.0,"bonus":25+15*c.rank(2)}
  "kayle_r":
   var ally = c if point.distance_to(c.world_pos())<25 else target(c,point,400,true)
   if ally == null: ally = c
   ally.buffs.divine = {"time":2.0,"src":c,"dmg":120+80*c.rank(3)}
  _: return false
 return true
static func expire(c, key: String, value: Dictionary) -> void:
 Roster12Combat.expire(c,key,value)
 if key == "death_mark" and is_instance_valid(value.src): hit(value.src,c,value.base+value.stored*0.3,"mark")
 if key == "divine" and is_instance_valid(value.src): area(value.src,c.world_pos(),170,value.dmg)
