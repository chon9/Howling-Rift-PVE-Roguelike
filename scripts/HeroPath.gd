class_name HeroPath
extends RefCounted
## Walking routes around buildings. A hero plans its way before it walks, like every MOBA since Warcraft 3, so it curves
## past a tower instead of running into it and sliding. Open ground needs no search: a straight line is checked first.

const CELL := 8              # fine enough for the gaps around the Throne, which are barely wider than a hero
const WALL_BAND := 16.0      # cells this close to a building cost more, so routes keep off walls when there is room
const WALL_COST := 4.0
const LINE_MARGIN := 1.0     # a straight line may pass this close to a building
const PULL_GIVE_UP := 12     # cells to look past a blocked one when straightening a route
const REPLAN_AFTER := 0.5    # seconds a route is trusted for
const REPLAN_MIN := 0.1      # never plan more often than this, even when knocked off a route
const GOAL_MOVED := 12.0     # a chased target has moved this far: plan again
const ARRIVED := 10.0
const FREE_CELL_RINGS := 8

static var _grid: AStarGrid2D = null
static var _signature := 0


## Where to head next on the way to goal. Stores its route on the hero.
static func next_waypoint(c, goal: Vector2) -> Vector2:
	var pos: Vector2 = c.global_position
	var now: float = GameState.time
	# A fresh plan is followed to its end. Asking "is the straight line clear?" on every step instead would change its
	# answer as the hero moves, near a building, and turn it back and forth.
	var planned: bool = c.route_goal.distance_to(goal) <= GOAL_MOVED and now >= c.route_at and now < c.route_at + REPLAN_AFTER
	if not planned or (not c.route.is_empty() and not clear_line(pos, c.route[0])):
		if not planned and clear_line(pos, goal):
			c.route = PackedVector2Array()
			return goal
		if now >= c.route_at and now < c.route_at + REPLAN_MIN and not c.route.is_empty():
			return c.route[0]
		c.route = find(pos, goal)
		c.route_goal = goal
		c.route_at = now
	while not c.route.is_empty():
		if pos.distance_to(c.route[0]) < ARRIVED or (c.route.size() > 1 and clear_line(pos, c.route[1])):
			c.route.remove_at(0)
		else:
			return c.route[0]
	return goal


## The corners of a walkable route, ending at goal when it can be reached.
static func find(from: Vector2, goal: Vector2) -> PackedVector2Array:
	_ensure_grid()
	var start := _free_cell(from)
	var end := _free_cell(goal)
	var out := PackedVector2Array()
	if start.x < 0 or end.x < 0:
		out.append(goal)
		return out
	var cells := _grid.get_point_path(start, end, true)
	var at := from
	var i := 0
	while i < cells.size():
		# Skip ahead to the farthest cell that can be seen from here.
		var next := i
		for j in range(i + 1, cells.size()):
			if clear_line(at, cells[j]):
				next = j
			elif j - next > PULL_GIVE_UP:
				break
		at = cells[next]
		out.append(at)
		i = next + 1
	if clear_line(at, goal):
		out.append(goal)
	return out


## True when a hero can walk this straight line. A building the line starts or ends beside only counts as far as the
## line actually goes into it, so walking away from a building or up to one is always clear.
static func clear_line(a: Vector2, b: Vector2) -> bool:
	for s in GameState.structures:
		if not is_instance_valid(s) or s.dead:
			continue
		var center: Vector2 = s.global_position
		var rr: float = minf(minf(s.collision_radius + UnitCollision.HERO_RADIUS + LINE_MARGIN, a.distance_to(center)), b.distance_to(center))
		if _distance_to_segment(center, a, b) < rr - 0.5:
			return false
	return true


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return point.distance_to(a)
	return point.distance_to(a + ab * clampf((point - a).dot(ab) / len2, 0.0, 1.0))


static func _ensure_grid() -> void:
	var signature := 17
	for s in GameState.structures:
		if is_instance_valid(s) and not s.dead:
			signature = signature * 31 + s.get_instance_id()
	if _grid != null and signature == _signature:
		return
	_signature = signature
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, int(Constants.WORLD_W) / CELL, int(Constants.WORLD_H) / CELL)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.offset = Vector2(CELL, CELL) * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.update()
	var size := _grid.region.size
	var top: int = ceili((Constants.LANE_Y - Constants.LANE_HALF + 20.0 - CELL * 0.5) / CELL)
	var bottom: int = floori((Constants.LANE_Y + Constants.LANE_HALF - 20.0 - CELL * 0.5) / CELL)
	var side: int = ceili((40.0 - CELL * 0.5) / CELL)
	_grid.fill_solid_region(Rect2i(0, 0, size.x, top))
	_grid.fill_solid_region(Rect2i(0, bottom + 1, size.x, size.y - bottom - 1))
	_grid.fill_solid_region(Rect2i(0, 0, side, size.y))
	_grid.fill_solid_region(Rect2i(size.x - side, 0, side, size.y))
	for s in GameState.structures:
		if not is_instance_valid(s) or s.dead:
			continue
		var center: Vector2 = s.global_position
		var solid_r: float = s.collision_radius + UnitCollision.HERO_RADIUS
		var reach: int = ceili((solid_r + WALL_BAND) / CELL) + 1
		var mid := Vector2i(center / CELL)
		for x in range(maxi(mid.x - reach, 0), mini(mid.x + reach, size.x - 1) + 1):
			for y in range(maxi(mid.y - reach, 0), mini(mid.y + reach, size.y - 1) + 1):
				var cell := Vector2i(x, y)
				var d: float = (Vector2(cell) * CELL + _grid.offset).distance_to(center)
				if d < solid_r:
					_grid.set_point_solid(cell, true)
				elif d < solid_r + WALL_BAND:
					_grid.set_point_weight_scale(cell, WALL_COST)


## The nearest open cell to a point, or (-1, -1) when there is none close by.
static func _free_cell(point: Vector2) -> Vector2i:
	var size := _grid.region.size
	var home := Vector2i(clampi(int(point.x) / CELL, 0, size.x - 1), clampi(int(point.y) / CELL, 0, size.y - 1))
	if not _grid.is_point_solid(home):
		return home
	for ring in range(1, FREE_CELL_RINGS + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell := home + Vector2i(dx, dy)
				if not _grid.is_in_boundsv(cell) or _grid.is_point_solid(cell):
					continue
				var d := point.distance_squared_to(Vector2(cell) * CELL + _grid.offset)
				if d < best_d:
					best_d = d
					best = cell
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
