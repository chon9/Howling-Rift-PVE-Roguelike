class_name CombatParticipation
extends RefCounted
const ASSIST_GOLD = 75
const WINDOW = 10.0
static func valid_hero(c) -> bool:
 return is_instance_valid(c) and c.kind == "champion" and c.roster_active
static func hit(src,target) -> void:
 if not valid_hero(src) or not valid_hero(target) or src.team == target.team: return
 var index = GameState.champions.find(src)
 if index < 0: return
 target.assist_hits[index] = GameState.time
 for helper in src.assist_support:
  if GameState.time-float(src.assist_support[helper]) <= WINDOW:
   target.assist_hits[helper] = GameState.time
static func support(src,ally) -> void:
 if not valid_hero(src) or not valid_hero(ally) or src == ally or src.team != ally.team: return
 var index = GameState.champions.find(src)
 var beneficiary = GameState.champions.find(ally)
 if index < 0 or beneficiary < 0: return
 ally.assist_support[index] = GameState.time
 # A shield/heal after the ally's hit also counts, without refreshing stale hits.
 for enemy in GameState.champions:
  if enemy.team == src.team or enemy.dead: continue
  if enemy.assist_hits.has(beneficiary) and GameState.time-float(enemy.assist_hits[beneficiary]) <= WINDOW:
   enemy.assist_hits[index] = GameState.time
static func assistants(killer,victim) -> Array:
 var result: Array = []
 for index in victim.assist_hits:
  if index < 0 or index >= GameState.champions.size(): continue
  var c = GameState.champions[index]
  if valid_hero(c) and c != killer and c != victim and c.team != victim.team and GameState.time-float(victim.assist_hits[index]) <= WINDOW:
   result.append(c)
 return result
