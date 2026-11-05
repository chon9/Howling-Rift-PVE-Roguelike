class_name BotSafety
extends RefCounted
static func approach(c, target) -> Vector2:
 var offset = target.world_pos()-c.world_pos()
 if offset.length() <= c.auto_attack_reach(target): return c.world_pos()
 return GameState.clamp_walkable(target.world_pos()-offset.normalized()*maxf(0,c.auto_attack_reach(target)-6))
static func wave_covers(c, tower) -> bool:
 var count = 0
 var health = 0.0
 for minion in GameState.minions:
  if not is_instance_valid(minion) or minion.dead or minion.team != c.team: continue
  if tower.world_pos().distance_to(minion.world_pos()) <= tower.atk_range:
   count += 1
   health += minion.hp
 return count >= 2 and health >= tower.atk_dmg*2.5
static func can_enter(c, point: Vector2, attacks_champion: bool = false, victim = null) -> bool:
 var fountain = Constants.FOUNT_R if c.team == Constants.BLUE else Constants.FOUNT_B
 if point.distance_to(fountain)<160: return false
 for tower in GameState.structures:
  if tower.dead or tower.team == c.team or tower.atk_dmg <= 0: continue
  if point.distance_to(tower.world_pos()) > tower.atk_range+25: continue
  # Damaging a defender provokes the tower regardless of minion cover.
  if attacks_champion or (tower.aggro_target == c and GameState.time<tower.aggro_until):
   if victim == null:
    victim = c.dive_target if is_instance_valid(c.dive_target) else c.chase_target
   if victim == null:
    for enemy in GameState.champions:
     if not enemy.dead and enemy.team != c.team and enemy.world_pos().distance_to(point)<160: victim = enemy; break
   if not dive_viable(c,victim,point): return false
   continue
  if c.hp < c.hp_max*0.45 or not wave_covers(c,tower): return false
 return true
static func retreat_from(c):
 var committed = c.dive_until >= 0
 var viable = committed and GameState.time<c.dive_until and dive_viable(c,c.dive_target)

 for tower in GameState.structures:
  if tower.dead or tower.team == c.team or tower.atk_dmg <= 0: continue
  if c.world_pos().distance_to(tower.world_pos()) > tower.atk_range+35: continue
  if committed: c.dive_entered = true
  if viable: continue
  if committed or tower.target == c or (tower.aggro_target == c and GameState.time<tower.aggro_until) or c.hp<c.hp_max*0.45 or not wave_covers(c,tower):
   return tower
 if committed and (c.dive_entered or GameState.time>=c.dive_until or not is_instance_valid(c.dive_target) or c.dive_target.dead):
  c.dive_entered = false
  c.dive_target = null
  c.dive_until = -1.0
 return null
static func waiting_point(c, tower) -> Vector2:
 var home = Constants.FOUNT_B if c.team == Constants.BLUE else Constants.FOUNT_R
 var outward = (home-tower.world_pos()).normalized()
 return GameState.clamp_walkable(tower.world_pos()+outward*(tower.atk_range+85))

static func dive_viable(c, victim, point: Vector2 = Vector2.INF) -> bool:
 if not is_instance_valid(victim) or victim.dead or victim.team == c.team or not c.can_secure_kill(victim): return false
 if c.stun>0 or c.hp<c.hp_max*.55: return false
 var damage = c.estimate_kill_damage(victim)
 var kill_time = clampf(3.0*(victim.hp+victim.shield)/maxf(1,damage),0.35,1.5)
 var landing = approach(c,victim) if point == Vector2.INF else point
 var incoming = 0.0
 var towers = 0
 for tower in GameState.structures:
  if tower.dead or tower.team==c.team or tower.atk_dmg<=0: continue
  if landing.distance_to(tower.world_pos())>tower.atk_range+25: continue
  towers += 1
  var escape = landing.distance_to(waiting_point(c,tower))/maxf(1,c.effective_move_speed())
  var exposure = kill_time+escape+0.5
  # Includes a missile already in flight and ramped shots, even with wave cover.
  var shots = maxi(4,int(ceil(exposure*tower.atk_spd))+1)
  incoming += shots*tower.atk_dmg*1.5*100.0/(100.0+ExpansionCombat.resist(c,null,"auto"))
 if towers==0: return true
 for enemy in GameState.champions:
  if enemy.dead or enemy.team==c.team or enemy.world_pos().distance_to(landing)>450: continue
  incoming += enemy.estimate_kill_damage(c)*0.65
 return c.hp+c.shield>incoming+c.hp_max*.30
static func commit_dive(c,victim) -> void:
 if c.dive_until>=0 or not dive_viable(c,victim): return
 var point = approach(c,victim)
 for tower in GameState.structures:
  if not tower.dead and tower.team!=c.team and tower.atk_dmg>0 and point.distance_to(tower.world_pos())<=tower.atk_range+25:
   c.dive_entered = false
   c.dive_target = victim
   c.dive_until = GameState.time+2.0
   return
