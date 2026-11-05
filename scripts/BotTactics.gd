class_name BotTactics
extends RefCounted
# Decisions use visible units, health, allies and tower safety; never hidden casts.
static func pressure(c,point: Vector2,team: int) -> float:
 var result=0.
 for unit in GameState.champions:
  if not is_instance_valid(unit) or unit.dead or not unit.roster_active or unit.team!=team:continue
  if team!=c.team and not BrushVision.visible_to(unit,c.team):continue
  var distance=unit.world_pos().distance_to(point)
  if distance>520:continue
  var reach=maxf(unit.effective_attack_range(),230.)
  var readiness=.45 if unit.stun>0 else 1.
  result+=readiness*(.5+.5*unit.hp/unit.hp_max)*clampf(1.-maxf(0.,distance-reach)/350.,0.,1.)
 return result
static func select_target(c):
 var best=null;var best_score=-INF
 var vision=float(c.difficulty_stats.get("vision",440.))
 for enemy in GameState.champions:
  if not is_instance_valid(enemy) or enemy.dead or not enemy.roster_active or enemy.team==c.team or not enemy.is_targetable or not BrushVision.visible_to(enemy,c.team):continue
  var distance=c.world_pos().distance_to(enemy.world_pos())
  if distance>vision:continue
  var approach=BotSafety.approach(c,enemy)
  if not BotSafety.can_enter(c,approach,true,enemy):continue
  var allies=pressure(c,enemy.world_pos(),c.team)
  var enemies=pressure(c,enemy.world_pos(),enemy.team)
  var hp=c.hp/c.hp_max
  var wounded=1.-enemy.hp/enemy.hp_max
  var lethal=c.can_secure_kill(enemy)
  # Healthy fighters may start a favourable trade; finishing isn't a prerequisite.
  if hp<.24 and (not lethal or not c._safe_pursuit(enemy)):continue
  if enemies>allies+.8 and not (lethal and c._safe_pursuit(enemy)):continue
  if hp<.5 and enemy.hp/enemy.hp_max>hp+.2 and allies<enemies+.4:continue
  var score=wounded*360.-distance*.35+(180. if lethal else 0.)+(allies-enemies)*85.
  if enemy.stun>0:score+=65.
  if enemy==c.attack_target:score+=70. # Hysteresis stops frame-to-frame switches.
  if enemy==c.chase_target:score+=60.
  for ally in GameState.champions:
   if ally!=c and ally.team==c.team and not ally.dead and ally.attack_target==enemy:score+=45.
  if score>best_score:best_score=score;best=enemy
 return best
static func space(c,delta: float) -> void:
 # Gentle separation only for bots, never displace a player's commanded position.
 if c.queued_auto_target!=null or c.is_dashing or c.stun>0 or c.recall_time>=0:return
 var offset=Vector2.ZERO
 for ally in GameState.champions:
  if ally==c or ally.dead or ally.team!=c.team or not ally.roster_active:continue
  var gap=c.world_pos()-ally.world_pos();var distance=gap.length()
  if distance>=28:continue
  if distance<.01:gap=Vector2(0,1 if GameState.champions.find(c)>GameState.champions.find(ally) else -1)
  offset+=gap.normalized()*(28.-distance)*2.
 var point=GameState.clamp_walkable(c.world_pos()+offset.limit_length(40.)*delta)
 if BotSafety.can_enter(c,point):c.global_position=point
