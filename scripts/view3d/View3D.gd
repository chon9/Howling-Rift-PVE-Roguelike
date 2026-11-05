class_name View3D
extends Node3D
## Rift3D presentation hub (W1-HUB). Mirrors the 2D sim into 3D views and implements the ViewHost interface
## (plan 5.4). Built by Main._ready when ViewConfig.enabled; setup() adopts world_root into the GroundOverlay and
## builds the arena while staying inactive; activate() (end of Main._build_match) makes the Camera3D current,
## registers every existing sim node and starts mirroring. Views only READ sim state; the only sim-side writes
## are `visible = false` on the map renderer and on HIDE/VIEW FX nodes (stateless, plan 4.5).
##
## Frame order (plan 4.2), process_priority 100 so this runs after LanSession, Main and every UnitAnimator:
##   flush pending + scan GameState -> rig.follow -> overlay.sync -> picker.poll (windowed) -> unit views
##   -> FX views -> arena.update -> overhead.sync

signal view_created(source, view)

static var current: View3D = null

const GROUND_CLAMP := Rect2(-200.0, -200.0, 3200.0, 940.0)  # screen_to_ground result clamp (sim px)

var main: Node2D
var rig: CameraRig3D
var overlay: GroundOverlay
var arena: WorldBuilder3D
var picker: Picker3D
var overhead: OverheadLayer
var units_root: Node3D
var fx_root: Node3D

var _anim_time: float = 0.0
var _active: bool = false
var _pending: Array = []            # Nodes waiting for classification (flushed in _process, after their setup)
var _entries: Dictionary = {}       # instance id -> {"node", "view", "policy", "armed"}
var _unit_views: Array = []         # unit + corpse views, synced in step 5
var _fx_views: Array = []           # FX views, synced in step 6
var _last_ground: Vector2 = Vector2(Constants.FOUNT_B.x, Constants.LANE_Y)
var _windowed: bool = DisplayServer.get_name() != "headless"
## Set by _step for the unit views of the current frame (see _step); frame_valid is false outside it.
var frame_valid: bool = false
var frame_up: Vector3 = Vector3.UP
var frame_pitch_rad: float = 0.0
var frame_shadows: bool = true
## Champions a structure card may hide this frame (final fix: structure see-through), built by _step before the
## unit views sync: [{"feet": Vector3, "rect": Rect2 (screen body rect)}] for every shown champion on screen.
var frame_occludees: Array = []
## Diagnostics: per-stage frame timing of _step (see _lap), off by default.
var profiling: bool = false
var profile: Dictionary = {}


func setup(main_node: Node2D) -> void:
	main = main_node
	current = self
	name = "View3D"
	process_priority = ViewConfig.PROCESS_PRIORITY
	picker = Picker3D.new(self)
	visible = false
	if not _hosts_world(main_node):
		# Not a Main (no world_root / camera facade): nothing to present. Stay an inert host that keeps the
		# 2D canvas maths, so tools and contract tests can still instantiate and query it.
		return
	var m: Variant = main
	rig = CameraRig3D.new()
	rig.name = "CameraRig"
	rig.apply_preset(ViewConfig.preset)
	add_child(rig)
	overlay = GroundOverlay.new()
	overlay.name = "GroundOverlay"
	add_child(overlay)
	overlay.configure(ViewConfig.quality_settings().overlay)
	if m != null and is_instance_valid(m.world_root):
		overlay.adopt(m.world_root)
	arena = WorldBuilder3D.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(overlay)
	if arena.ground_material != null:
		overlay.bind_material(arena.ground_material)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	overhead = OverheadLayer.new()
	overhead.name = "OverheadLayer"
	add_child(overhead)
	overhead.visible = false
	if m != null and is_instance_valid(m.map_renderer):
		m.map_renderer.visible = false
	if m != null and is_instance_valid(m.world_root):
		watch(m.world_root)
	visible = false
	overlay.set_live(false)


func activate() -> void:
	if main == null or rig == null or overlay == null:
		return
	rig.camera.make_current()
	overlay.set_live(true)
	visible = true
	overhead.visible = true
	_active = true
	ViewConfig.set_active(true)
	var m: Variant = main
	if is_instance_valid(m.world_root):
		for child in m.world_root.get_children():
			register(child)
	_flush_pending()
	_scan_state()
	var q := ViewConfig.quality_settings()
	get_viewport().msaa_3d = q.msaa
	arena.apply_quality(q)
	sync_now()


func is_active() -> bool:
	return _active


## Runs the full frame pipeline with delta 0 (tests, warm-up, after activation).
func sync_now() -> void:
	_step(0.0)


func warm_up() -> void:
	await ViewWarmup.run(self)


## Ground hits of the four screen corners in sim px [TL, TR, BR, BL]; empty until the camera is in the tree.
func footprint_sim() -> PackedVector2Array:
	var cam := camera()
	if cam == null or not cam.is_inside_tree():
		return PackedVector2Array()
	return GroundOverlay.corner_hits(cam)


func view_for(source: Node) -> Node:
	if source == null or not is_instance_valid(source):
		return null
	var e = _entries.get(source.get_instance_id())
	if e == null:
		return null
	var v = e.view
	if v == null or not is_instance_valid(v) or v.is_queued_for_deletion():
		return null
	return v


## Policy the classifier applied to a node (-1 when not registered). Diagnostic and test helper.
func policy_of(source: Node) -> int:
	if source == null or not is_instance_valid(source):
		return -1
	var e = _entries.get(source.get_instance_id())
	return -1 if e == null else int(e.policy)


## Classifies a 2D node and creates its 3D view (idempotent by instance id).
func register(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var id := node.get_instance_id()
	if _entries.has(id):
		return
	var entry := {"node": node, "view": null, "policy": VfxRegistry.Policy.FLAT, "armed": false}
	_entries[id] = entry
	var view: Node = null
	if node is Champion or node is Minion or node is Structure:
		entry.policy = VfxRegistry.Policy.VIEW
		var uv: UnitView3D = UnitViewFactory.create(node)
		if uv != null:
			add_unit_view(uv)
			uv.bind(node, self)
			_unit_views.append(uv)
			view = uv
			if overhead != null:
				overhead.attach(node, uv)
	elif node is AnimatedCorpse:
		entry.policy = VfxRegistry.Policy.HIDE
		node.visible = false
		var cv := UnitViewFactory.create_corpse(node)
		if cv != null:
			add_unit_view(cv)
			if cv.has_method("bind"):
				cv.bind(node, self)
			_unit_views.append(cv)
			view = cv
	elif node is FloatingText:
		entry.policy = VfxRegistry.Policy.HIDE
		if overhead != null:
			overhead.add_float(node)
	elif _is_map(node):
		entry.policy = VfxRegistry.Policy.HIDE
		(node as CanvasItem).visible = false
	else:
		var policy := VfxRegistry.classify(node)
		entry.policy = policy
		if policy == VfxRegistry.Policy.VIEW or policy == VfxRegistry.Policy.BOTH:
			var fv := VfxRegistry.create_view(node, self)
			if fv != null:
				if fv.get_parent() == null:
					add_fx(fv)
				_fx_views.append(fv)
				view = fv
			elif policy == VfxRegistry.Policy.VIEW:
				policy = VfxRegistry.Policy.FLAT   # no view: keep drawing flat, never vanish
				entry.policy = policy
		if (policy == VfxRegistry.Policy.HIDE or policy == VfxRegistry.Policy.VIEW) and node is CanvasItem:
			(node as CanvasItem).visible = false
	entry.view = view
	_arm(id, entry)
	if view != null:
		view_created.emit(node, view)


## Queues every current and future direct child of a 2D root for registration.
func watch(root2d: Node) -> void:
	if root2d == null or not is_instance_valid(root2d):
		return
	if not root2d.child_entered_tree.is_connected(_on_child_entered):
		root2d.child_entered_tree.connect(_on_child_entered)
	if not root2d.child_exiting_tree.is_connected(_on_child_exiting):
		root2d.child_exiting_tree.connect(_on_child_exiting)
	for child in root2d.get_children():
		if not _pending.has(child):
			_pending.append(child)


# --- ViewHost interface (plan 5.4) ---

func camera() -> Camera3D:
	return rig.camera if rig != null else null


func card_up() -> Vector3:
	var cam := camera()
	if cam == null or not cam.is_inside_tree():
		return Vector3.UP
	return ViewMath.card_up(cam)


func pitch_deg() -> float:
	if rig != null:
		return rig.pitch()
	return float(ViewConfig.camera_preset().pitch)


func anim_time() -> float:
	return _anim_time


func local_team() -> int:
	if GameState.player != null and is_instance_valid(GameState.player):
		return int(GameState.player.team)
	return 0


func add_fx(node: Node3D) -> void:
	var root: Node = fx_root if fx_root != null else self
	root.add_child(node)


func add_unit_view(node: Node3D) -> void:
	var root: Node = units_root if units_root != null else self
	root.add_child(node)


func overhead_layer() -> CanvasLayer:
	return overhead


func world_to_screen(p: Vector2, h_art_px: float = 0.0) -> Vector2:
	var cam := camera()
	if _active and cam != null and cam.is_inside_tree():
		return cam.unproject_position(ViewMath.lifted(p, h_art_px, ViewMath.card_up(cam)))
	if main == null:
		return p
	return main.get_canvas_transform() * (p - Vector2(0, h_art_px))


func screen_to_ground(screen: Vector2) -> Vector2:
	var cam := camera()
	if _active and cam != null and cam.is_inside_tree():
		var hit = ViewMath.ground_hit(cam, screen)
		if hit != null:
			var g := ViewMath.to2(hit)
			_last_ground = Vector2(clampf(g.x, GROUND_CLAMP.position.x, GROUND_CLAMP.end.x), clampf(g.y, GROUND_CLAMP.position.y, GROUND_CLAMP.end.y))
		return _last_ground
	if main == null:
		return screen
	return main.get_canvas_transform().affine_inverse() * screen


# --- frame pipeline ---

func _process(delta: float) -> void:
	if not _active:
		return
	if not GameState.paused:
		_anim_time += delta
	_step(delta)


func _step(delta: float) -> void:
	if not _active or main == null or not is_instance_valid(main):
		return
	var t := Time.get_ticks_usec() if profiling else 0
	# 1. registrations
	_flush_pending()
	_scan_state()
	if profiling:
		t = _lap("scan", t)
	# 2. camera rig follows the Camera2D facade (shake as lens offset)
	var m: Variant = main
	var cam2d = m.camera
	if is_instance_valid(cam2d):
		var shake: Vector2 = m.camera_shake_offset
		rig.follow(cam2d.position - shake, shake, cam2d.zoom.x, delta)
	# 3. ground overlay follows the 3D footprint
	overlay.sync(rig.camera)
	# Per-frame values every unit view reads (perf: computed once here instead of once per view, valid only
	# inside this _step; views fall back to asking the host outside it).
	frame_up = card_up()
	frame_pitch_rad = deg_to_rad(pitch_deg())
	frame_shadows = bool(ViewConfig.quality_settings().shadows)
	_collect_occludees()
	frame_valid = true
	if profiling:
		t = _lap("rig+overlay", t)
	# 4. picking (windowed only)
	if picker != null and _windowed:
		picker.poll(main)
	if profiling:
		t = _lap("picker", t)
	# 5. unit views
	_sync_list(_unit_views, delta)
	if profiling:
		t = _lap("units", t)
	# 6. FX views
	_sync_list(_fx_views, delta)
	if profiling:
		t = _lap("fx", t)
	# 7. arena
	if arena != null:
		arena.update(self, delta)
	if profiling:
		t = _lap("arena", t)
	# 8. overhead layer
	if overhead != null:
		overhead.sync(self)
	frame_valid = false
	if profiling:
		_lap("overhead", t)
		profile["frames"] = float(profile.get("frames", 0.0)) + 1.0


## Diagnostics (perf tests): with `profiling` on, _step adds each stage's wall time (ms) to `profile`.
func _lap(key: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	profile[key] = float(profile.get(key, 0.0)) + float(now - t0) / 1000.0
	return now


## frame_occludees for this frame: the feet and on-screen body rect of every shown champion (sim read only).
func _collect_occludees() -> void:
	frame_occludees.clear()
	var cam := camera()
	if cam == null or not cam.is_inside_tree():
		return
	var screen := cam.get_viewport().get_visible_rect()
	for c in GameState.champions:
		if not is_instance_valid(c) or not c.is_inside_tree() or not c.visible or bool(c.dead):
			continue
		if "roster_active" in c and not bool(c.roster_active):
			continue
		var v = view_for(c)
		if v == null or not v.has_method("screen_rect"):
			continue
		var r: Rect2 = v.screen_rect(cam)
		if r.get_area() <= 0.0 or not screen.intersects(r):
			continue
		frame_occludees.append({"feet": ViewMath.to3(c.global_position), "rect": r})


func _sync_list(list: Array, delta: float) -> void:
	var i := 0
	while i < list.size():
		var v = list[i]
		if v == null or not is_instance_valid(v) or v.is_queued_for_deletion():
			list.remove_at(i)
			continue
		if v.has_method("sync"):
			v.sync(delta)
		i += 1


func _flush_pending() -> void:
	if _pending.is_empty():
		return
	var batch := _pending
	_pending = []
	for n in batch:
		if is_instance_valid(n) and n.is_inside_tree():
			register(n)


func _scan_state() -> void:
	for list in [GameState.champions, GameState.minions, GameState.structures, GameState.projectiles, GameState.aoes]:
		for n in list:
			if is_instance_valid(n) and n.is_inside_tree() and not _entries.has(n.get_instance_id()):
				register(n)


static func _hosts_world(node: Node) -> bool:
	return node != null and is_instance_valid(node) and "world_root" in node and "camera" in node and "map_renderer" in node


func _is_map(node: Node) -> bool:
	var m: Variant = main
	if _hosts_world(m) and is_instance_valid(m.map_renderer) and node == m.map_renderer:
		return true
	var s: Variant = node.get_script()
	return s != null and str(s.resource_path).ends_with("/MapRenderer.gd")


func _arm(id: int, entry: Dictionary) -> void:
	var n = entry.node
	if entry.armed or not is_instance_valid(n):
		return
	n.tree_exiting.connect(_on_source_exiting.bind(id), CONNECT_ONE_SHOT)
	entry.armed = true


func _on_source_exiting(id: int) -> void:
	var e = _entries.get(id)
	if e != null:
		e.armed = false
	_check_source.call_deferred(id)


## A source left the tree: free its view unless it came straight back (reparent).
func _check_source(id: int) -> void:
	var e = _entries.get(id)
	if e == null:
		return
	var n = e.node
	if is_instance_valid(n) and n.is_inside_tree() and not n.is_queued_for_deletion():
		_arm(id, e)
		return
	_entries.erase(id)
	var v = e.view
	if v != null and is_instance_valid(v) and not v.is_queued_for_deletion():
		if v.has_method("dispose"):
			v.dispose()
		else:
			v.queue_free()


func _on_child_entered(node: Node) -> void:
	if not _entries.has(node.get_instance_id()) and not _pending.has(node):
		_pending.append(node)


func _on_child_exiting(node: Node) -> void:
	_pending.erase(node)


func _exit_tree() -> void:
	if _active or current == self:
		_active = false
		ViewConfig.set_active(false)
	if current == self:
		current = null
