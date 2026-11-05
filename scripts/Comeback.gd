class_name Comeback
extends RefCounted
## Keeps matches close: the team behind on levels hits harder, takes less and levels faster, and killing someone far
## below you pays little. Without this, one early fight decides the match. Equal-level kills pay their normal rewards.
## Player-versus-player matches keep equal rules.

const DAMAGE_PER_LEVEL := 0.05
const MAX_DAMAGE := 1.35
const TAKEN_PER_LEVEL := 0.035
const MIN_TAKEN := 0.72
const XP_PER_LEVEL := 0.2
const MAX_XP := 2.5
const MIN_XP := 0.6
const REWARD_PER_LEVEL := 0.12
const MIN_REWARD := 0.35
const MAX_REWARD := 1.75
const RALLY_GAP := 2.0
const RALLY_STRUCTURES := 2
const REFRESH := 0.5
const START_TIME := 60.0 # levels are close in the first minute, so nothing applies yet

static var _behind := [0.0, 0.0]
static var _checked_at := -1.0


## How many levels this team is behind the other on average. Negative when it is ahead.
static func levels_behind(team: int) -> float:
	var now: float = GameState.time
	if now < START_TIME:
		return 0.0
	if now < _checked_at or now >= _checked_at + REFRESH or _checked_at < 0.0:
		_checked_at = now
		_refresh()
	return _behind[team]


static func damage_dealt(team: int) -> float:
	return clampf(1.0 + DAMAGE_PER_LEVEL * levels_behind(team), 1.0, MAX_DAMAGE)


static func damage_taken(team: int) -> float:
	return clampf(1.0 - TAKEN_PER_LEVEL * levels_behind(team), MIN_TAKEN, 1.0)


static func xp_multiplier(team: int) -> float:
	return clampf(1.0 + XP_PER_LEVEL * levels_behind(team), MIN_XP, MAX_XP)


## Reward for a hero kill compared with the normal amount, from the two heroes' levels.
static func reward_scale(killer, victim) -> float:
	if GameState.is_pvp() or GameState.time < START_TIME:
		return 1.0
	return clampf(1.0 + REWARD_PER_LEVEL * (victim.level - killer.level), MIN_REWARD, MAX_REWARD)


static func rallying(team: int) -> bool:
	if GameState.is_pvp() or GameState.time < START_TIME:
		return false
	if levels_behind(team) >= RALLY_GAP:
		return true
	var lost := [0, 0]
	for s in GameState.structures:
		if s.dead:
			lost[s.team] += 1
	return lost[team] - lost[1 - team] >= RALLY_STRUCTURES


## Drops the cached gap so the next question sees the current levels.
static func reset() -> void:
	_checked_at = -1.0
	_behind = [0.0, 0.0]


static func _refresh() -> void:
	if GameState.is_pvp():
		_behind = [0.0, 0.0]
		return
	var total := [0.0, 0.0]
	var count := [0, 0]
	for c in GameState.champions:
		if is_instance_valid(c) and c.roster_active:
			total[c.team] += c.level
			count[c.team] += 1
	if count[0] == 0 or count[1] == 0:
		_behind = [0.0, 0.0]
		return
	var gap: float = total[1] / count[1] - total[0] / count[0]
	_behind = [gap, -gap]
