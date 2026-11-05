extends Node
# How controlling a hero must feel: orders are obeyed, clicks mean what they showed, and nothing stops a walking hero
# except a building it plans its way around.
const STEP := 0.02

var failures = 0
var checks = 0
var game
var hero
var foe

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL CONTROLS: " + message)

func _ready() -> void:
	await get_tree().process_frame
	Progression.persistent = false
	GameState.reset()
	game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._show_menu()
	game._start_game("garen")
	await get_tree().process_frame
	hero = GameState.player
	for c in GameState.champions:
		c.is_bot = false
		c.stop_actions()
		if c.team != hero.team and foe == null and c.roster_active:
			foe = c
	for c in GameState.champions:
		if c != hero and c != foe:
			c.global_position = Vector2(4000, 4000)
	_test_ground_click_is_a_move()
	_test_click_attacks_what_it_showed()
	_test_network_click()
	_test_routes_around_buildings()
	_test_never_stuck_on_minions()
	_test_keeps_order_while_blocked()
	_test_idle_hero_fights_back()
	_test_cast_buffer()
	_test_bar_colours()
	_report_planning_cost()
	game.queue_free()
	await get_tree().process_frame
	print("CONTROL FEEL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _clear_minions() -> void:
	for m in GameState.minions:
		m.queue_free()
	GameState.minions.clear()

func _minion(team: int, at: Vector2):
	var m = game.MinionS.new()
	game.world_root.add_child(m)
	m.setup(team, "melee", at, 1.0)
	m.stun = 100.0
	GameState.minions.append(m)
	return m

func _place(at: Vector2) -> void:
	hero.stop_actions()
	hero.buffs.clear()
	hero.global_position = at
	foe.global_position = Vector2(1500, 270)

func _report_planning_cost() -> void:
	var nexus = GameState.nexus[1]
	var from: Vector2 = Constants.FOUNT_B + Vector2(40, 0)
	var goal: Vector2 = GameState.clamp_walkable(nexus.global_position + Vector2(nexus.collision_radius + 40.0, 0))
	nexus.dead = true
	HeroPath.find(from, goal)
	nexus.dead = false
	var t0 := Time.get_ticks_usec()
	HeroPath.find(from, goal)
	var build := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for i in range(20):
		HeroPath.find(from, goal)
	var whole_lane := (Time.get_ticks_usec() - t0) / 20
	t0 = Time.get_ticks_usec()
	for i in range(1000):
		HeroPath.clear_line(from, goal)
	print("PLANNING COST: rebuild + route %d us, whole-lane route %d us, straight-line check %d us" % [build, whole_lane, (Time.get_ticks_usec() - t0) / 1000])
	check(whole_lane < 8000, "planning the longest route stays cheap (%d us)" % whole_lane)

func _test_ground_click_is_a_move() -> void:
	_place(Vector2(1300, 270))
	# This point is on the ground above the enemy, inside its tall 2D body rectangle.
	var above: Vector2 = foe.world_pos() + Vector2(0, -30)
	game._issue_player_order({"type": "smart", "point": above, "target": null})
	check(hero.attack_target == null and hero.has_move_target, "a click on the ground is a move, even near an enemy")
	check(hero.move_target.distance_to(above) < 1.0, "the hero walks to the clicked spot")

func _test_click_attacks_what_it_showed() -> void:
	_clear_minions()
	_place(Vector2(1300, 270))
	var creep = _minion(foe.team, foe.world_pos())
	game._issue_player_order({"type": "smart", "point": foe.world_pos(), "target": foe})
	check(hero.attack_target == foe, "the clicked hero is attacked, not the minion on top of it")
	game._issue_player_order({"type": "smart", "point": foe.world_pos(), "target": creep})
	check(hero.attack_target == creep, "the clicked minion is attacked, not the hero under it")
	game._issue_player_order({"type": "amove", "point": foe.world_pos(), "target": foe})
	check(hero.attack_target == foe and hero.attack_move, "attack-move click goes for the clicked unit")
	creep.dead = true
	game._issue_player_order({"type": "smart", "point": Vector2(1200, 270), "target": creep})
	check(hero.attack_target == null and hero.has_move_target, "a target that has just died falls back to a move")
	_clear_minions()

func _test_network_click() -> void:
	_place(Vector2(1300, 270))
	var creep = _minion(foe.team, foe.world_pos() + Vector2(4, 0))
	check(GameState.find_unit_of_kind(foe.world_pos(), hero.team, "champion") == foe, "the host finds the clicked hero by kind")
	check(GameState.find_unit_of_kind(foe.world_pos(), hero.team, "minion") == creep, "the host finds the clicked minion by kind")
	check(GameState.find_unit_of_kind(foe.world_pos(), hero.team, "") == null, "a ground click finds nothing")
	check(GameState.find_unit_of_kind(foe.world_pos() + Vector2(300, 0), hero.team, "champion") == null, "a click far away finds nothing")
	var sent: Dictionary = ClientMovement.order(hero, {"type": "smart", "point": Vector2(1, 1), "target": foe})
	check(not sent.has("target") and sent.target_kind == "champion" and sent.point == foe.world_pos(), "a guest's click crosses the network as data")
	var ground: Dictionary = ClientMovement.order(hero, {"type": "smart", "point": Vector2(1200, 270), "target": null})
	check(ground.target_kind == "" and ground.point == Vector2(1200, 270), "a guest's ground click stays a ground click")
	ClientMovement.clear()
	_clear_minions()

## Walks to the goal and reports how it went. Slowest progress is the distance covered in the worst half second.
func _walk(goal: Vector2, seconds: float, each_frame = null) -> Dictionary:
	hero.move_target = goal
	hero.has_move_target = true
	var start: Vector2 = hero.global_position
	var travelled := 0.0
	var worst := INF
	var last: Vector2 = start
	var flips := 0
	var last_dir := Vector2.ZERO
	var t := 0.0
	var window := []
	var slowest := INF
	while t < seconds and hero.has_move_target:
		hero.update_frame(STEP)
		if each_frame != null:
			each_frame.call()
		var moved: float = last.distance_to(hero.global_position)
		travelled += moved
		window.append(moved)
		if window.size() > 25:
			window.pop_front()
			var sum := 0.0
			for v in window:
				sum += v
			slowest = minf(slowest, sum)
		if moved > 0.01:
			var dir: Vector2 = (hero.global_position - last).normalized()
			if last_dir != Vector2.ZERO and dir.dot(last_dir) < 0.0:
				flips += 1
			last_dir = dir
		last = hero.global_position
		for s in GameState.structures:
			if not s.dead:
				worst = minf(worst, hero.global_position.distance_to(s.global_position) - s.collision_radius - UnitCollision.HERO_RADIUS)
		t += STEP
	return {"arrived": hero.global_position.distance_to(goal) < 6.0, "time": t, "travelled": travelled, "worst": worst, "flips": flips, "slowest": slowest}

func _test_routes_around_buildings() -> void:
	var speed: float = hero.effective_move_speed()
	for s in GameState.structures:
		if s.type != "turret" and s.type != "nexus" and s.type != "nexus_turret":
			continue
		for side in [Vector2(-1, 0), Vector2(-1, 0.4), Vector2(-1, -0.4)]:
			var away: Vector2 = side.normalized() * (s.collision_radius + 70.0)
			var from: Vector2 = GameState.clamp_walkable(s.global_position + away)
			var goal: Vector2 = GameState.clamp_walkable(s.global_position - away)
			_place(from)
			foe.global_position = Vector2(4000, 4000)
			var r := _walk(goal, 12.0)
			var name_: String = "%s team %d" % [s.type, s.team]
			check(r.arrived, "%s: the hero gets past it (ended %.0f away)" % [name_, hero.global_position.distance_to(goal)])
			check(r.worst > -0.5, "%s: the hero never touches it (%.1f px)" % [name_, r.worst])
			check(r.flips == 0, "%s: the hero never doubles back (%d)" % [name_, r.flips])
			check(r.slowest > speed * 0.5 * 0.85, "%s: the hero never slows down (%.0f of %.0f px per half second)" % [name_, r.slowest, speed * 0.5])
	_place(Constants.FOUNT_B)
	# The whole lane, from one fountain to the enemy's Throne, in one click.
	foe.global_position = Vector2(4000, 4000)
	var nexus = GameState.nexus[1]
	var goal: Vector2 = GameState.clamp_walkable(nexus.global_position - Vector2(nexus.collision_radius + 40.0, 0))
	var whole := _walk(goal, 30.0)
	check(whole.arrived, "one click walks the whole lane (ended %.0f away)" % hero.global_position.distance_to(goal))
	check(whole.time < hero.global_position.distance_to(Constants.FOUNT_B) / speed * 1.15, "the route around every building is nearly straight (%.1fs)" % whole.time)
	hero.stop_actions()

func _test_never_stuck_on_minions() -> void:
	_clear_minions()
	_place(Vector2(1200, 270))
	foe.global_position = Vector2(4000, 4000)
	var crowd := []
	for x in range(5):
		for y in range(5):
			crowd.append(_minion(hero.team if (x + y) % 2 == 0 else foe.team, Vector2(1300 + x * 26, 222 + y * 24)))
	var goal := Vector2(1500, 270)
	var speed: float = hero.effective_move_speed()
	var r := _walk(goal, 6.0, func():
		for m in crowd:
			UnitCollision.resolve_minion(m))
	check(r.arrived, "a hero walks straight through the middle of a dense wave (ended %.0f away)" % hero.global_position.distance_to(goal))
	check(r.time < 300.0 / speed * 1.35, "the wave barely slows it (%.2fs for %.2fs straight)" % [r.time, 300.0 / speed])
	check(r.flips == 0, "the hero never wobbles in the crowd (%d)" % r.flips)
	var moved := 0
	for m in crowd:
		if m.global_position.distance_to(hero.global_position) >= UnitCollision.contact_distance(hero, m) - 0.5:
			moved += 1
	check(moved == crowd.size(), "minions stepped aside and none stand inside the hero")
	# A hero with Ghost does not shove anybody.
	var m = _minion(foe.team, Vector2(1400, 270))
	hero.buffs["ghost"] = {"time": 10.0, "mult": 1.0}
	hero.global_position = Vector2(1400, 270)
	var before: Vector2 = m.global_position
	UnitCollision.resolve_minion(m)
	check(m.global_position == before, "Ghost passes through minions without moving them")
	hero.buffs.clear()
	_clear_minions()
	hero.stop_actions()

func _test_keeps_order_while_blocked() -> void:
	_place(Vector2(1200, 270))
	var hold: Vector2 = GameState.structures[0].global_position
	hero.global_position = hold
	game._issue_player_order({"type": "smart", "point": Vector2(hold.x + 300, 270), "target": null})
	var r := _walk(GameState.clamp_walkable(Vector2(hold.x + 300, 270)), 4.0)
	check(r.arrived, "a hero overlapping a building still gets out and goes (ended at %s from %s)" % [str(hero.global_position), str(hold)])
	hero.stop_actions()

func _test_idle_hero_fights_back() -> void:
	_clear_minions()
	_place(Vector2(1300, 270))
	foe.global_position = hero.global_position + Vector2(40, 0)
	foe.visible = true
	GameState.idle_attack = false
	for i in range(30):
		hero.update_frame(STEP)
	check(hero.attack_target == null, "scripted test heroes stay passive")
	GameState.idle_attack = true
	var creep = _minion(foe.team, hero.global_position + Vector2(20, 0))
	for i in range(30):
		hero.update_frame(STEP)
	check(hero.attack_target == foe, "an idle hero attacks the enemy hero in range before the minion beside it")
	game._issue_player_order({"type": "smart", "point": Vector2(1200, 270), "target": null})
	hero.update_frame(STEP)
	check(hero.attack_target == null and hero.has_move_target, "walking away is obeyed at once, with no attack in the way")
	GameState.idle_attack = false
	_clear_minions()
	hero.stop_actions()
	hero.global_position = Constants.FOUNT_B

func _test_cast_buffer() -> void:
	_place(Vector2(1300, 270))
	foe.global_position = Vector2(1340, 270)
	hero.mp = hero.mp_max
	hero.skill_ranks[0] = 1
	hero.skill_cds[0] = 0.2
	game._player_cast_skill(0)
	check(not game._cast_buffer.is_empty(), "a press just before the cooldown ends is remembered")
	hero.skill_cds[0] = 0.0
	game._tick_cast_buffer()
	check(game._cast_buffer.is_empty() and hero.skill_cds[0] > 0.0, "the remembered press fires as soon as it can")
	hero.skill_cds[0] = 5.0
	game._player_cast_skill(0)
	check(game._cast_buffer.is_empty(), "a press with a long cooldown left is not remembered")
	hero.skill_cds[0] = 0.0

func _test_bar_colours() -> void:
	check(hero.hp_bar.color == Constants.BAR_SELF, "your own bar has its own colour")
	check(foe.hp_bar.color == Constants.BAR_ENEMY, "the enemy bar is red")
	for c in GameState.champions:
		if c != hero and c.team == hero.team:
			check(c.hp_bar.color == Constants.BAR_ALLY, "ally bars are blue")
