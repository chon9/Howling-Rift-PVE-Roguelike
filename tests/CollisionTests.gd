extends Node
# Walking collision: buildings are solid, heroes and minions keep apart, and nothing gets stuck.
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0
var game: Node2D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL COLLISION: " + message)

func _ready() -> void:
	game = View3DTestKit.start_3d_match(self, "lux")
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		c.global_position = Constants.FOUNT_B if c.team == 0 else Constants.FOUNT_R
	_test_layout()
	_test_minion_rounds_tower()
	_test_minions_reach_enemy_tower()
	_test_hero_rounds_tower()
	_test_hero_keeps_out_of_minion()
	_test_minion_rounds_hero()
	_test_landing_and_ghost()
	print("COLLISION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _structure(team: int, type: String, variant: String = ""):
	for s in GameState.structures:
		if s.team == team and s.type == type and (variant == "" or s.variant == variant):
			return s
	return null

func _minion(team: int, kind: String, at: Vector2):
	var m = game.MinionS.new()
	game.world_root.add_child(m)
	m.setup(team, kind, at)
	GameState.minions.append(m)
	return m

func _remove(m) -> void:
	GameState.minions.erase(m)
	m.free()

func _clearance(unit, radius: float) -> float:
	var best := INF
	for s in GameState.structures:
		if not s.dead:
			best = minf(best, unit.global_position.distance_to(s.global_position) - s.collision_radius - radius)
	return best

func _test_layout() -> void:
	for team in [0, 1]:
		var fountain: Vector2 = Constants.FOUNT_B if team == 0 else Constants.FOUNT_R
		var nexus = GameState.nexus[team]
		check(fountain.distance_to(nexus.global_position) - 78.0 - nexus.collision_radius >= 40.0, "fountain disc stands well clear of the Throne (team %d)" % team)
		check(absf(fountain.x - Constants.WORLD_W * 0.5) > absf(nexus.global_position.x - Constants.WORLD_W * 0.5), "fountain is behind the Throne (team %d)" % team)
		var turrets := []
		for s in GameState.structures:
			if s.team == team and s.type == "nexus_turret":
				turrets.append(s)
		check(turrets.size() == 2, "two Throne turrets (team %d)" % team)
		for t in turrets:
			var gap: float = t.global_position.distance_to(nexus.global_position) - t.collision_radius - nexus.collision_radius
			check(gap > UnitCollision.HERO_RADIUS * 2.0, "a hero fits between a Throne turret and the Throne (team %d, %.0f px)" % [team, gap])
		check(turrets[0].global_position.distance_to(turrets[1].global_position) - turrets[0].collision_radius * 2.0 > 60.0, "the front of the Throne stays open for melee (team %d)" % team)

func _test_minion_rounds_tower() -> void:
	var tower = _structure(0, "turret", "outer")
	var start: Vector2 = tower.global_position - Vector2(90, 0)
	for kind in ["melee", "caster", "siege", "super"]:
		var m = _minion(0, kind, start)
		var worst := INF
		for i in range(240):
			m.update_frame(STEP)
			worst = minf(worst, _clearance(m, UnitCollision.radius_of(m)))
		check(worst > -0.5, "%s minion never walks into the tower (%.1f px)" % [kind, worst])
		check(m.global_position.x > tower.global_position.x + 60.0, "%s minion gets past the tower (x %.0f)" % [kind, m.global_position.x])
		_remove(m)

func _test_minions_reach_enemy_tower() -> void:
	var tower = _structure(1, "turret", "outer")
	for kind in ["melee", "super"]:
		var m = _minion(0, kind, tower.global_position - Vector2(160, 10))
		var hit := false
		for i in range(300):
			m.update_frame(STEP)
			hit = hit or m.queued_attack_target == tower or m.attack_anim > 0.0
		check(hit, "%s minion stops at the enemy tower and attacks it" % kind)
		check(_clearance(m, UnitCollision.radius_of(m)) > -0.5, "%s minion attacks from outside the tower" % kind)
		_remove(m)
	var hero = GameState.champions[0]
	check(hero.auto_attack_reach(tower) >= UnitCollision.contact_distance(hero, tower) + 6.0, "a hero touching a tower can hit it")

func _test_hero_rounds_tower() -> void:
	var hero = GameState.player
	var tower = _structure(0, "turret", "inner")
	hero.global_position = tower.global_position - Vector2(120, 0)
	hero.move_target = tower.global_position + Vector2(120, 0)
	hero.has_move_target = true
	var worst := INF
	for i in range(300):
		hero.update_frame(STEP)
		worst = minf(worst, _clearance(hero, UnitCollision.HERO_RADIUS))
		if not hero.has_move_target:
			break
	check(worst > -0.5, "hero never walks into a tower (%.1f px)" % worst)
	check(hero.global_position.distance_to(tower.global_position + Vector2(120, 0)) < 6.0, "hero walks around the tower to its order")
	hero.stop_actions()
	hero.global_position = Constants.FOUNT_B

func _test_hero_keeps_out_of_minion() -> void:
	var hero = GameState.player
	var m = _minion(0, "melee", Vector2(1300, 270))
	m.stun = 100.0
	hero.global_position = Vector2(1250, 270)
	hero.move_target = Vector2(1350, 270)
	hero.has_move_target = true
	var worst := INF
	var limit: float = UnitCollision.contact_distance(hero, m)
	for i in range(240):
		hero.update_frame(STEP)
		worst = minf(worst, hero.global_position.distance_to(m.global_position) - limit)
		if not hero.has_move_target:
			break
	check(worst > -6.0, "hero curves around a minion instead of walking through it (%.1f px)" % worst)
	check(hero.global_position.distance_to(Vector2(1350, 270)) < 6.0, "hero walks around the minion to its order")
	# A crowd never stops a hero: it keeps its order and comes out the other side.
	hero.stop_actions()
	hero.global_position = Vector2(1300 - limit, 270)
	var wall := [m]
	for offset in [-24.0, 24.0]:
		for x in [-24.0, 0.0, 24.0]:
			var extra = _minion(0, "melee", Vector2(1300 + x, 270 + offset))
			extra.stun = 100.0
			wall.append(extra)
	hero.move_target = Vector2(1300, 270)
	hero.has_move_target = true
	for i in range(240):
		hero.update_frame(STEP)
		for w in wall:
			UnitCollision.resolve_minion(w)
	check(hero.global_position.distance_to(Vector2(1300, 270)) < 6.0, "hero reaches an order inside a crowd")
	for w in wall:
		_remove(w)
	hero.stop_actions()
	hero.global_position = Constants.FOUNT_B

func _test_minion_rounds_hero() -> void:
	var hero = GameState.player
	hero.stop_actions()
	hero.global_position = Vector2(1300, 270)
	var m = _minion(0, "melee", Vector2(1250, 270))
	var limit: float = UnitCollision.contact_distance(hero, m)
	var worst := INF
	for i in range(180):
		m.update_frame(STEP)
		worst = minf(worst, hero.global_position.distance_to(m.global_position) - limit)
	check(worst > -0.5, "minion does not walk through a standing hero (%.1f px)" % worst)
	check(m.global_position.x > 1340.0, "minion walks around the standing hero (x %.0f)" % m.global_position.x)
	check(hero.global_position == Vector2(1300, 270), "minion does not shove the hero")
	_remove(m)
	hero.global_position = Constants.FOUNT_B

func _test_landing_and_ghost() -> void:
	var tower = _structure(0, "turret", "outer")
	var landing: Vector2 = GameState.clamp_walkable(tower.global_position)
	check(landing.distance_to(tower.global_position) >= tower.collision_radius + UnitCollision.HERO_RADIUS - 0.01, "blink and order points land outside buildings")
	tower.dead = true
	check(GameState.clamp_walkable(tower.global_position) == tower.global_position, "a destroyed building no longer blocks")
	tower.dead = false
	var hero = GameState.player
	var m = _minion(0, "melee", Vector2(1300, 270))
	m.stun = 100.0
	hero.buffs["ghost"] = {"time": 10.0, "mult": 1.0}
	hero.global_position = Vector2(1300, 270)
	UnitCollision.resolve_champion(hero)
	check(hero.global_position == Vector2(1300, 270), "Ghost walks through minions")
	hero.buffs.erase("ghost")
	UnitCollision.resolve_champion(hero)
	check(hero.global_position == Vector2(1300, 270), "a minion never pushes a hero")
	UnitCollision.resolve_minion(m)
	check(hero.global_position.distance_to(m.global_position) >= UnitCollision.contact_distance(hero, m) - 0.01, "the minion steps out of the hero's way")
	_remove(m)
