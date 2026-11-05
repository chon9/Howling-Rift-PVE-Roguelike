class_name MatchRoster
extends RefCounted
static var previous_enemies: Array = []
static func unique_enemies(enemies: Array,allies: Array) -> Array:
 var result=[]
 for key in enemies.slice(0,3):
  if ChampionData.CHAMPIONS.has(key) and not result.has(key):result.append(key)
 while result.size()<3:
  var options=ChampionData.CHAMPIONS.keys().filter(func(key):return not result.has(key) and not allies.has(key) and not previous_enemies.has(key))
  if options.is_empty():options=ChampionData.CHAMPIONS.keys().filter(func(key):return not result.has(key))
  result.append(options.pick_random())
 return result
static func enemy_team(allies: Array) -> Array:
 var fresh=ChampionData.CHAMPIONS.keys().filter(func(key):return not allies.has(key) and not previous_enemies.has(key))
 fresh.shuffle()
 var fallback=ChampionData.CHAMPIONS.keys().filter(func(key):return not allies.has(key) and not fresh.has(key))
 fallback.shuffle();fresh.append_array(fallback)
 previous_enemies=fresh.slice(0,3)
 return previous_enemies.duplicate()
