class_name BrushVision
extends RefCounted
const PATCHES = [Rect2(650,112,250,84),Rect2(1275,112,250,84),Rect2(1900,112,250,84),Rect2(650,344,250,84),Rect2(1275,344,250,84),Rect2(1900,344,250,84)]
static func patch_at(point: Vector2) -> int:
 for i in range(PATCHES.size()):
  if PATCHES[i].has_point(point): return i
 return -1
static func visible_to(unit, team: int) -> bool:
 if not is_instance_valid(unit) or unit.dead: return false
 if unit.team==team or unit.kind!="champion": return true
 if LanSession.is_client():return bool(unit.vision_teams[team])
 var patch=patch_at(unit.world_pos())
 if patch<0 or unit.brush_revealed_until>GameState.time: return true
 for ally in GameState.champions+GameState.minions:
  if not is_instance_valid(ally) or ally.dead or ally.team!=team: continue
  if patch_at(ally.world_pos())==patch or ally.world_pos().distance_to(unit.world_pos())<95: return true
 for tower in GameState.structures:
  if not tower.dead and tower.team==team and tower.atk_dmg>0 and tower.world_pos().distance_to(unit.world_pos())<=tower.atk_range: return true
 return false
static func reveal(unit, seconds: float = 2.0) -> void:
 if is_instance_valid(unit) and unit.kind=="champion": unit.brush_revealed_until=maxf(unit.brush_revealed_until,GameState.time+seconds)
static func update_presentation() -> void:
 if not is_instance_valid(GameState.player): return
 for c in GameState.champions:
  c.visible=not c.dead and visible_to(c,GameState.player.team)
  c.modulate=Color(1,1,1,.72) if not c.dead and patch_at(c.world_pos())>=0 and c.brush_revealed_until<=GameState.time else Color.WHITE
static func ambush_point(c):
 if c.hp<c.hp_max*.65 or GameState.time<c.ambush_rest_until: return null
 for tower in GameState.structures:
  if not tower.dead and tower.team!=c.team and tower.atk_dmg>0 and c.world_pos().distance_to(tower.world_pos())<550 and BotSafety.wave_covers(c,tower): return null
 var chosen=null
 var best=INF
 for patch in PATCHES:
  var center=patch.get_center()
  if c.world_pos().distance_to(center)>330 or not BotSafety.can_enter(c,center): continue
  for enemy in GameState.champions:
   if enemy.dead or enemy.team==c.team or not visible_to(enemy,c.team): continue
   var distance=center.distance_to(enemy.world_pos())
   if distance<180 or distance>500: continue
   var progress=(enemy.world_pos()-center).x*(1 if c.team==Constants.BLUE else -1)
   if progress<0: continue
   if distance<best:best=distance;chosen=center
 return chosen
