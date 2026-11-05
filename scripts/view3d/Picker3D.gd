class_name Picker3D
extends RefCounted
## Screen-space unit picking and ground ray (W1-PICK; W3-READ polishes).
## Rects are computed from sim/source data only (no view dependency): the painted body rect
## (ActionSpriteArt.body_rect / Structure.art_rect) spanned along camera X and card-up U from the lifted
## feet, projected to the screen and unioned with the projected feet circle. Read-only: never writes sim fields.
## W3-READ: champions win near-ties over minions on padded hits (MINION_PAD_BIAS_PX), and poll() drives the
## hover outline (UnitView3D.set_hover) on the hovered unit's view, clearing the previous one.

enum Pick { ENEMY, ALLY, ANY }

const BODY_GROW_PX := 6.0        # projected body rect growth (canvas px)
const PAD_PX := 12.0             # padded (inexact) hit margin; about 8 sim px at the 2D zoom of 1.7
const PAD_PENALTY := 1000.0      # exact hits always beat padded ones
const FEET_RADIUS := 0.7         # feet circle radius as a fraction of unit.size (as target_click_rect)
const FEET_SEGMENTS := 12
const MINION_PAD_BIAS_PX := 6.0  # padded minion hits score 6 px worse, so a champion wins a padded near-tie
const HOVER_NONE := 0
const HOVER_ENEMY := 1
const HOVER_ALLY := 2

var host: Node3D
var _last_ground: Vector2 = Vector2.ZERO
var _has_ground := false
var _in_host := false            # re-entrancy guard for host fallbacks
var _hover_view: Node3D = null   # view currently showing the hover outline
var _hover_mode := HOVER_NONE
var _poll_frame := 0
var _poll_mouse := Vector2(-1e9, -1e9)
var _extent_cache: Dictionary = {}   # unit instance id -> Vector2(size, body extent art px) for _surely_misses


func _init(h: Node3D = null) -> void:
	host = h


func _camera() -> Camera3D:
	if host == null or not is_instance_valid(host):
		return null
	var cam: Camera3D = host.camera()
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return null
	return cam


func screen_to_ground(screen: Vector2) -> Vector2:
	var cam := _camera()
	if cam != null:
		var hit = ViewMath.ground_hit(cam, screen)
		if hit != null:
			_last_ground = ViewMath.to2(hit)
			_has_ground = true
			return _last_ground
	if _has_ground:
		return _last_ground
	# No valid hit yet (no camera, or the first ray missed): defer to the host's own fallback.
	if host != null and is_instance_valid(host) and not _in_host:
		_in_host = true
		var p: Vector2 = host.screen_to_ground(screen)
		_in_host = false
		return p
	return screen


func world_to_screen(p: Vector2, h_art_px := 0.0) -> Vector2:
	var cam := _camera()
	if cam != null:
		return cam.unproject_position(ViewMath.lifted(p, h_art_px, ViewMath.card_up(cam)))
	if host != null and is_instance_valid(host) and not _in_host:
		_in_host = true
		var s: Vector2 = host.world_to_screen(p, h_art_px)
		_in_host = false
		return s
	return p


## Best unit under the screen point (canvas px), or null. team is the picking player's team.
func pick_unit(screen: Vector2, team: int, mode: int) -> Node2D:
	var cam := _camera()
	if cam == null:
		return null
	var best: Node2D = null
	var best_score := INF
	var view_inv := cam.global_transform.affine_inverse()
	var focal := cam.get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	for lst in [GameState.champions, GameState.minions, GameState.structures]:
		for u in lst:
			if u == null or not is_instance_valid(u) or not u.is_inside_tree():
				continue
			# Perf: _eligible's cheap rejections first (it still runs below), so they skip the projection cull.
			if u == GameState.player or u.dead or not u.is_targetable or not u.visible:
				continue
			if _surely_misses(cam, view_inv, focal, u, screen):
				continue
			if not _eligible(u, team, mode):
				continue
			var info := unit_screen_info(cam, u)
			if info.is_empty():
				continue
			var rect: Rect2 = info.rect
			if not rect.grow(PAD_PX).has_point(screen):
				continue
			var score := hit_score(u.kind, rect.has_point(screen), screen.distance_to(info.feet), screen.distance_to(info.centre))
			if score < best_score:
				best_score = score
				best = u
	return best


## Conservative cull for pick_unit (perf: one projection instead of seventeen per unit). Every point of the unit's
## padded rect comes from a world point within `reach` metres of its feet; under perspective such a point lands
## within focal * reach * (1 + |x/z|, 1 + |y/z|) / (z - reach) px of the projected feet. True only when the screen
## point is farther than that bound (plus the rect growth and padding), so it never drops a real hit.
func _surely_misses(cam: Camera3D, view_inv: Transform3D, focal: float, u, screen: Vector2) -> bool:
	var feet3 := ViewMath.to3(u.world_pos())
	var v := view_inv * feet3
	var z := -v.z
	var kind: String = u.kind
	var scale := ViewConfig.MINION_SCALE if kind == "minion" else (ViewConfig.STRUCTURE_SCALE if kind == "structure" else ViewConfig.UNIT_SCALE)
	var ext := _art_extent(u)
	var lift := 0.0 if kind == "structure" or not u.buffs.has("airborne") else HeroControl.lift(u)
	var reach := ViewMath.art_m(ext * 1.4143 + absf(lift), scale) + float(u.size) * FEET_RADIUS * ViewConfig.S
	if z - reach <= 0.05:
		return false
	var k := focal * reach / (z - reach)
	var bound_x := k * (1.0 + absf(v.x / z)) + BODY_GROW_PX + PAD_PX + 1.0
	var bound_y := k * (1.0 + absf(v.y / z)) + BODY_GROW_PX + PAD_PX + 1.0
	var feet_s := cam.unproject_position(feet3)
	return absf(screen.x - feet_s.x) > bound_x or absf(screen.y - feet_s.y) > bound_y


## Largest |coordinate| of the unit's body rect (art px) for the cull. Perf: units cache it per instance while
## their size is unchanged, as the max over both facings (so a turn never shrinks it); structures read art_rect.
func _art_extent(u) -> float:
	if u.kind == "structure":
		var r: Rect2 = u.art_rect
		return maxf(maxf(absf(r.position.x), absf(r.end.x)), maxf(absf(r.position.y), absf(r.end.y)))
	var id: int = u.get_instance_id()
	var size := float(u.size)
	var cached = _extent_cache.get(id)
	if cached != null and cached.x == size:
		return cached.y
	var ext := 0.0
	for flip in [false, true]:
		var r := _body_rect_facing(u, flip)
		ext = maxf(ext, maxf(maxf(absf(r.position.x), absf(r.end.x)), maxf(absf(r.position.y), absf(r.end.y))))
	if _extent_cache.size() > 512:
		_extent_cache.clear()
	_extent_cache[id] = Vector2(size, ext)
	return ext


## body_rect_of with an explicit facing.
static func _body_rect_facing(u, flip: bool) -> Rect2:
	if u.kind == "champion":
		return ActionSpriteArt.body_rect("hero_" + str(u.hero_key), Constants.CHAMP_ART_HEIGHT, flip)
	if u.kind == "minion":
		return ActionSpriteArt.body_rect("minion_" + str(u.subkind), float(u.size) * 2.7, flip)
	var s := float(u.size)
	return Rect2(-s, -s * 2.0, s * 2.0, s * 2.0)


## Selection score (lower wins): distance to the nearer of feet and body centre. Padded hits add PAD_PENALTY so
## any exact hit wins; among padded hits a minion adds MINION_PAD_BIAS_PX so a champion wins a near-tie.
static func hit_score(kind: String, exact: bool, feet_dist: float, centre_dist: float) -> float:
	var score := minf(feet_dist, centre_dist)
	if not exact:
		score += PAD_PENALTY
		if kind == "minion":
			score += MINION_PAD_BIAS_PX
	return score


## Pick-then-snap: the unit's ground point when a unit is under the cursor, else the ground hit.
func pick_point(screen: Vector2, team: int, mode: int) -> Vector2:
	var u := pick_unit(screen, team, mode)
	if u != null:
		return u.world_pos()
	return screen_to_ground(screen)


## Windowed only: refresh the cursor ground point and the hover unit unless the GUI is hovered
## (then the last values are kept, so HUD-button casts aim at the last world pick).
func poll(main: Node2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if main == null or not is_instance_valid(main) or not main.is_inside_tree():
		return
	var vp := main.get_viewport()
	if vp == null or vp.gui_get_hovered_control() != null:
		# Keep the last pick, but drop an outline whose unit is gone or no longer pickable.
		if _hover_view != null and (not is_instance_valid(_hover_view) or not _hover_alive(GameState.hover_unit)):
			set_hover_unit(null, 0)
		return
	var mouse := vp.get_mouse_position()
	var ground := screen_to_ground(mouse)
	# Real Main has mouse_world; test stubs pass a plain Node2D.
	if "mouse_world" in main:
		main.mouse_world = ground
	GameState.cursor_world = ground
	var p = GameState.player
	if p != null and is_instance_valid(p):
		# Low quality re-picks every Nth frame while the mouse rests (a moved mouse always re-picks).
		var every := maxi(1, int(ViewConfig.quality_settings().get("hover_every", 1)))
		_poll_frame += 1
		var hovered = GameState.hover_unit
		var stale: bool = hovered != null and not _hover_alive(hovered)
		if every <= 1 or _poll_frame % every == 0 or mouse.distance_squared_to(_poll_mouse) > 4.0 or stale:
			_poll_mouse = mouse
			GameState.hover_unit = pick_unit(mouse, p.team, Pick.ANY)
		set_hover_unit(GameState.hover_unit, p.team)
	else:
		GameState.hover_unit = null
		set_hover_unit(null, 0)


## Moves the hover outline to u's view (enemy red / ally blue relative to team), clearing the previous view.
## u == null clears it. Presentation only: calls set_hover on views, never touches sim fields.
func set_hover_unit(u, team: int) -> void:
	var view: Node3D = null
	var mode := HOVER_NONE
	if u != null and is_instance_valid(u):
		view = view_for_unit(u)
		mode = HOVER_ENEMY if int(u.team) != team else HOVER_ALLY
	if view == null:
		mode = HOVER_NONE
	if _hover_view != null and _hover_view != view and is_instance_valid(_hover_view) and _hover_view.has_method("set_hover"):
		_hover_view.set_hover(HOVER_NONE)
	_hover_view = view
	_hover_mode = mode
	if view != null and view.has_method("set_hover"):
		view.set_hover(mode)


## The view now showing the hover outline (null when none), and its mode (0 none, 1 enemy, 2 ally).
func hovered_view() -> Node3D:
	if _hover_view != null and not is_instance_valid(_hover_view):
		_hover_view = null
		_hover_mode = HOVER_NONE
	return _hover_view


func hover_mode() -> int:
	return _hover_mode if hovered_view() != null else HOVER_NONE


## The host's unit view for a sim unit: View3D.view_for, else a scan of the host's units_root (test FakeView).
func view_for_unit(u) -> Node3D:
	if host == null or not is_instance_valid(host) or u == null or not is_instance_valid(u):
		return null
	if host.has_method("view_for"):
		var v = host.view_for(u)
		if v == null or not is_instance_valid(v):
			return null
		return v as Node3D
	var root = host.get("units_root")
	if root is Node:
		for child in root.get_children():
			if child is Node3D and not child.is_queued_for_deletion() and child.get("source") == u:
				return child
	return null


func _hover_alive(u) -> bool:
	return u != null and is_instance_valid(u) and u.is_inside_tree() and not u.dead and u.visible


func _eligible(u, team: int, mode: int) -> bool:
	if u == null or not is_instance_valid(u) or not u.is_inside_tree():
		return false
	if u == GameState.player or u.dead or not u.is_targetable or not u.visible:
		return false
	if u.kind == "champion" and not u.roster_active:
		return false
	if u.team != team:
		if mode == Pick.ALLY:
			return false
		if not BrushVision.visible_to(u, team):
			return false
		if u.kind == "structure" and not u.is_structure_attackable():
			return false
		return true
	if mode == Pick.ENEMY:
		return false
	return BrushVision.visible_to(u, team)


## Screen data for one unit: {rect, feet, centre} in canvas px, or {} when it cannot be projected.
func unit_screen_info(cam: Camera3D, u) -> Dictionary:
	var feet2: Vector2 = u.world_pos()
	var feet3 := ViewMath.to3(feet2)
	if cam.is_position_behind(feet3):
		return {}
	var up := ViewMath.card_up(cam)
	var right := cam.global_basis.x.normalized()
	var body: Rect2
	var scale := ViewConfig.scale_of(u)
	var lift := 0.0
	if u.kind == "structure":
		body = u.art_rect
		scale = ViewConfig.STRUCTURE_SCALE
	else:
		body = body_rect_of(u)
		lift = HeroControl.lift(u)
	var base := feet3 + up * ViewMath.art_m(lift, scale)
	var rect := Rect2()
	var first := true
	var corners := [body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]
	for corner in corners:
		var p3: Vector3 = base + right * ViewMath.art_m(corner.x, scale) - up * ViewMath.art_m(corner.y, scale)
		if cam.is_position_behind(p3):
			continue
		var s := cam.unproject_position(p3)
		if first:
			rect = Rect2(s, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(s)
	if first:
		return {}
	var centre := rect.get_center()
	if u.kind != "structure":
		rect = rect.grow(BODY_GROW_PX)
		var r := float(u.size) * FEET_RADIUS
		for i in range(FEET_SEGMENTS):
			var a := TAU * i / float(FEET_SEGMENTS)
			rect = rect.expand(cam.unproject_position(ViewMath.to3(feet2 + Vector2(cos(a), sin(a)) * r)))
	return {"rect": rect, "feet": cam.unproject_position(feet3), "centre": centre}


## 2D body rect (art px, feet-relative, up is negative y) matching the painted card and the units' art_rect().
static func body_rect_of(u) -> Rect2:
	if u.kind == "champion":
		var flip := false
		if u.animator != null and is_instance_valid(u.animator):
			flip = u.animator.is_flipped()
		return ActionSpriteArt.body_rect("hero_" + str(u.hero_key), Constants.CHAMP_ART_HEIGHT, flip)
	if u.kind == "minion":
		var mflip: bool = u.facing_sign < 0
		if u.animator != null and is_instance_valid(u.animator):
			mflip = u.animator.is_flipped()
		return ActionSpriteArt.body_rect("minion_" + str(u.subkind), float(u.size) * 2.7, mflip)
	var s := float(u.size)
	return Rect2(-s, -s * 2.0, s * 2.0, s * 2.0)
