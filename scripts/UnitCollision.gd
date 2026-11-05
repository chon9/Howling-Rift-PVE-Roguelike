class_name UnitCollision
extends RefCounted
## Walking collision for heroes and minions. Runs on the host sim and in guest movement prediction.
## Buildings are solid circles under their painted bases, and heroes plan routes around them (HeroPath). Minions never
## stop a hero: the hero curves around them (veer) and they step out of its way (resolve_minion), so units do not pass
## through each other and nobody gets stuck. Minions do not block minions and heroes do not block heroes. Dashes, blinks
## and forced motion pass through everything and only land outside buildings (GameState.clamp_walkable). Ghost ignores
## units, as in LoL.

const HERO_RADIUS := 14.0
const MINION_RADIUS_K := 0.6       # of Minion.size
const REACH_MARGIN := 10.0         # melee attackers can always hit a building they are touching
const STEER_MARGIN := 6.0          # walkers start turning this far before a building
const UNIT_MARGIN := 2.0
const UNIT_LOOKAHEAD := 70.0       # only steer around units this close
const BAND_SLACK := 8.0            # steering may graze the edge of the walkable band
const VEER_LOOKAHEAD := 56.0       # a hero starts curving around a minion this far ahead
const VEER_ANGLE := 0.75           # sharpest curve, radians
const VEER_HOLD := 0.35            # seconds a hero keeps curving to the same side, so it never wobbles


static func radius_of(unit) -> float:
	match unit.kind:
		"champion": return HERO_RADIUS
		"minion": return unit.size * MINION_RADIUS_K
	return unit.collision_radius


## Centre distance at which two units touch.
static func contact_distance(a, b) -> float:
	return radius_of(a) + radius_of(b)


static func _is_obstacle(u, mover) -> bool:
	if not is_instance_valid(u) or u == mover or u.dead or not u.is_targetable or u.buffs.has("airborne") or u.buffs.has("ghost"):
		return false
	return u.kind != "champion" or u.roster_active


## Moves a point out of every standing building, keeping radius clear of it.
static func push_out_of_structures(point: Vector2, radius: float) -> Vector2:
	for s in GameState.structures:
		if not is_instance_valid(s) or s.dead:
			continue
		var reach: float = s.collision_radius + radius
		var gap: Vector2 = point - s.global_position
		if absf(gap.x) >= reach or absf(gap.y) >= reach:
			continue
		var d2 := gap.length_squared()
		if d2 >= reach * reach:
			continue
		if d2 < 0.01:
			gap = Vector2(0.0, -1.0 if point.y < Constants.LANE_Y else 1.0)
		point = s.global_position + gap.normalized() * reach
	return point


static func _push_out_of_units(point: Vector2, radius: float, units: Array, mover) -> Vector2:
	for u in units:
		if not _is_obstacle(u, mover):
			continue
		var reach: float = radius_of(u) + radius
		var gap: Vector2 = point - u.global_position
		if absf(gap.x) >= reach or absf(gap.y) >= reach:
			continue
		var d2 := gap.length_squared()
		if d2 >= reach * reach:
			continue
		if d2 < 0.01:
			gap = Vector2(0.0, -1.0 if mover.get_instance_id() & 1 else 1.0)
		point = u.global_position + gap.normalized() * reach
	return point


## Hero after a walking step: only buildings can stop a hero.
static func resolve_champion(c) -> void:
	c.global_position = push_out_of_structures(c.global_position, HERO_RADIUS)


## The heading that curves a walking hero around the minion ahead of it. ignore is the unit it is attacking.
static func veer(c, dir: Vector2, ignore = null) -> Vector2:
	if c.buffs.has("ghost"):
		return dir
	var nearest := VEER_LOOKAHEAD
	var ahead := Vector2.ZERO
	var found := false
	for m in GameState.minions:
		if m == ignore or not _is_obstacle(m, c):
			continue
		var rel: Vector2 = m.global_position - c.global_position
		var along := rel.dot(dir)
		if along <= 0.0 or along >= nearest or absf(dir.cross(rel)) >= radius_of(m) + HERO_RADIUS:
			continue
		nearest = along
		ahead = rel
		found = true
	var now: float = GameState.time
	if not found:
		return dir
	if now >= c.veer_until or now < c.veer_until - VEER_HOLD:
		c.veer_side = -1.0 if dir.cross(ahead) > 0.0 else 1.0
		var pass_y: float = c.global_position.y + dir.rotated(c.veer_side * VEER_ANGLE).y * VEER_LOOKAHEAD
		if absf(pass_y - Constants.LANE_Y) > Constants.LANE_HALF - 20.0:
			c.veer_side = -c.veer_side
	c.veer_until = now + VEER_HOLD
	return dir.rotated(c.veer_side * VEER_ANGLE * (1.0 - 0.5 * nearest / VEER_LOOKAHEAD))


## Minion after a walking step: out of the way of heroes, then out of buildings.
static func resolve_minion(m) -> void:
	var radius: float = radius_of(m)
	var p: Vector2 = _push_out_of_units(m.global_position, radius, GameState.champions, m)
	m.global_position = push_out_of_structures(p, radius)


## Where a minion walks this step to reach target without running into something: target itself when the way is clear,
## otherwise a point past the edge of the nearest blocker. ignore is the unit being attacked.
static func steer(unit, target: Vector2, radius: float, ignore = null) -> Vector2:
	var pos: Vector2 = unit.global_position
	var to := target - pos
	var length := to.length()
	if length < 1.0:
		return target
	var dir := to / length
	var best := INF
	var center := Vector2.ZERO
	var best_rr := 0.0
	for s in GameState.structures:
		if not is_instance_valid(s) or s.dead or s == ignore:
			continue
		var c: Vector2 = s.global_position
		var rr := minf(s.collision_radius + radius + STEER_MARGIN, target.distance_to(c))
		var e := _entry(pos, dir, length, c, rr)
		if e < best:
			best = e
			center = c
			best_rr = rr
	for u in GameState.champions:
		if u == ignore or not _is_obstacle(u, unit):
			continue
		var c: Vector2 = u.global_position
		if pos.distance_squared_to(c) > UNIT_LOOKAHEAD * UNIT_LOOKAHEAD:
			continue
		var rr := minf(radius_of(u) + radius + UNIT_MARGIN, target.distance_to(c))
		var e := _entry(pos, dir, length, c, rr)
		if e < best:
			best = e
			center = c
			best_rr = rr
	if best == INF:
		return target
	var rel := center - pos
	var dist := rel.length()
	var cross := dir.x * rel.y - dir.y * rel.x
	var side := -1.0 if cross > 0.0 else 1.0
	if absf(cross) < 1.0:
		side = -1.0 if unit.get_instance_id() & 1 else 1.0
	# Pass on the side with room to walk.
	var pass_y: float = center.y + dir.rotated(side * PI * 0.5).y * best_rr
	if absf(pass_y - Constants.LANE_Y) > Constants.LANE_HALF - 20.0 + BAND_SLACK:
		side = -side
	var way := rel.rotated(side * asin(best_rr / dist)) if dist > best_rr else rel.rotated(side * PI * 0.5)
	return pos + way.normalized() * maxf(dist, 40.0)


## Distance along the walking line at which it enters a circle, or INF when the way past it is clear.
static func _entry(pos: Vector2, dir: Vector2, length: float, center: Vector2, rr: float) -> float:
	var rel := center - pos
	var along := rel.dot(dir)
	if along <= 0.0:
		return INF
	var perp2 := rel.length_squared() - along * along
	if perp2 >= rr * rr:
		return INF
	var e := along - sqrt(rr * rr - perp2)
	if e >= length - 1.0:
		return INF
	return maxf(e, 0.0)
