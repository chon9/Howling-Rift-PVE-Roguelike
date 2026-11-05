class_name OverheadLayer
extends CanvasLayer
## Screen-space bars, names, status badges, floating text and captions (W1-OVERHEAD).
## Bars and name Labels are the units' own Controls, reparented (member references stay valid) into a
## BarAnchor placed over the projected head at a constant OVERHEAD_SCALE, like LoL. A BodyAnchor at the
## (lifted) feet, scaled to the body's on-screen size, carries the body-attached status sprites.
## Read only: never writes sim fields. The unit's own StatusVisual stays under the unit (GROUND mode).

const STATUS_SCRIPT := preload("res://scripts/StatusVisual.gd")
const CHAMPION_CONTROLS := ["name_label", "shield_bar_bg", "shield_bar", "hp_bar_bg", "hp_bar", "mp_bar"]
const SMALL_CONTROLS := ["hp_bar_bg", "hp_bar"]
const UNIT_KINDS := ["champion", "minion", "structure"]
const CHEST_ART_PX := 28.0          # Deadeye aim line height (2D muzzle y -28)
const FLOAT_BASE_ART_PX := 10.0     # floating text starts this far above its world point
const FLOAT_RISE_ART_PX := 40.0     # FloatingText rises 40 px over its life
const DEADEYE_GOLD := Color("ffd176")
## Overhead StatusVisual scale relative to the bars. In 3D the ground is foreshortened, so units stand
## ~25% closer on screen than in 2D while bars keep OVERHEAD_SCALE; badges and icons shrink about a pivot
## just above the name (champions) or the bar (minions) so they stay legible without clouding the fight.
const STATUS_SCALE_CHAMPION := 0.72
const STATUS_SCALE_SMALL := 0.8
const STATUS_PIVOT_CHAMPION_PX := 36.0   # above the head line: the name label's top edge
const STATUS_PIVOT_SMALL_PX := 8.0       # above the minion art top: the hp bar
const BADGE_GAP_PX := 3.0                # screen px kept between nudged champion status blocks
## Draw priority (CanvasItem z_index, W2 fix): champion bars always beat minion and structure bars, as in LoL /
## MLBB, and among champions the nearer one (lower on screen) draws on top. Body anchors stay under every bar;
## floating text and captions stay above all of them.
const Z_BODY := -1
const Z_SMALL_BAR := 0
const Z_STRUCTURE_BAR := 1
const Z_CHAMPION_BAR := 2               # + 2 per nearer champion (each bar's decor draws at +1)
const Z_TOP := 64                       # floats_root and the caption canvas
## Champion name + bars block in authored bar-local px (name label top -89 to mp bar bottom -60, level badge at
## x -37). Overlapping champion blocks are nudged upward (farther one moves), at most CHAMP_NUDGE_MAX blocks.
const CHAMP_BLOCK := Rect2(-40.0, -89.0, 80.0, 31.0)
const CHAMP_NUDGE_MAX := 2.0          # W3 fix: three stacked champions resolve (was 1.0)
const CHAMP_BLOCK_GAP_PX := 2.0
const OFFSCREEN_MARGIN_PX := 160.0      # head points this far outside the viewport still place their bars
## Floating text declutter (final fix): each frame the shown texts are stacked (big callouts first, then newest first:
## the newest number sits at its spawn point, older ones are pushed up above it) and kept off the champion name/bar
## blocks and status blocks. The push is eased (FLOAT_NUDGE_SPEED_PX screen px per second) so a text never teleports;
## a number that would need more than FLOAT_NUDGE_MAX_PX is dropped for that frame.
const FLOAT_GAP_PX := 2.0
const FLOAT_NUDGE_MAX_PX := 160.0
const FLOAT_NUDGE_SPEED_PX := 900.0

var anchors_root: Node2D
var floats_root: Node2D
var canvas: Control

var _host: Node3D = null
var _entries: Dictionary = {}       # unit instance id -> {"unit", "view", "bar", "body", "exit"}
var _floats: Array = []             # ScreenFloat
var _labels: Array = []             # {"source", "text", "color", "offset", "size"}
var _captions: Array = []           # computed each sync: {"text", "pos", "size", "color"}
var _deadeye: Array = []            # computed each sync: {"from", "to", "progress", "phase"}
var _canvas_drew := true            # the last canvas redraw had captions or Deadeye lines
var _blocks: Array = []             # this frame's champion name/bar and status blocks (screen Rect2), for floats


func _init() -> void:
	layer = 5
	name = "OverheadLayer"
	anchors_root = Node2D.new()
	anchors_root.name = "Anchors"
	add_child(anchors_root)
	floats_root = Node2D.new()
	floats_root.name = "Floats"
	floats_root.z_index = Z_TOP
	add_child(floats_root)
	canvas = Control.new()
	canvas.name = "OverheadCanvas"
	canvas.z_index = Z_TOP
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	canvas.draw.connect(_draw_canvas)


# --- units ---

func attach(unit: Node2D, view: Node3D) -> void:
	if not is_instance_valid(unit) or not (str(unit.get("kind")) in UNIT_KINDS):
		return
	var id := unit.get_instance_id()
	if _entries.has(id):
		_entries[id].view = view
		return
	var champion: bool = unit.kind == "champion"
	var body := OverheadAnchor.new()
	body.name = "Body_%d" % id
	body.unit = unit
	body.view = view
	body.role = OverheadAnchor.ROLE_BODY
	body.z_index = Z_BODY
	body.visible = false
	anchors_root.add_child(body)
	var bar := OverheadAnchor.new()
	bar.name = "Bar_%d" % id
	bar.unit = unit
	bar.view = view
	bar.role = OverheadAnchor.ROLE_BAR
	bar.z_index = Z_CHAMPION_BAR if champion else (Z_STRUCTURE_BAR if unit.kind == "structure" else Z_SMALL_BAR)
	bar.visible = false
	anchors_root.add_child(bar)
	for member in (CHAMPION_CONTROLS if champion else SMALL_CONTROLS):
		var control = unit.get(member)
		if control is Control and is_instance_valid(control) and control.get_parent() == unit:
			var index: int = control.get_index()
			unit.remove_child(control)
			bar.add_child(control)
			bar.adopted.append({"node": control, "index": index})
	# Only units that carry a StatusVisual in 2D get screen-space ones (structures have no status fields).
	if unit.get_node_or_null("StatusVisual") != null:
		var overhead_status = STATUS_SCRIPT.new()
		overhead_status.name = "OverheadStatus"
		overhead_status.unit = unit
		overhead_status.mode = STATUS_SCRIPT.MODE_OVERHEAD
		bar.add_child(overhead_status)
		var body_status = STATUS_SCRIPT.new()
		body_status.name = "BodyStatus"
		body_status.unit = unit
		body_status.mode = STATUS_SCRIPT.MODE_BODY
		body.add_child(body_status)
	bar.add_decor()
	var on_exit := _on_unit_exiting.bind(id)
	unit.tree_exiting.connect(on_exit)
	_entries[id] = {"unit": unit, "view": view, "bar": bar, "body": body, "exit": on_exit, "status": bar.get_node_or_null("OverheadStatus")}


func detach(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		_prune_invalid()
		return
	_detach_id(unit.get_instance_id())


func anchor_for(unit: Node2D) -> Node2D:
	if unit == null or not is_instance_valid(unit):
		return null
	var entry = _entries.get(unit.get_instance_id())
	return entry.bar if entry != null else null


## The BodyAnchor of a unit (null if not attached).
func body_anchor_for(unit: Node2D) -> Node2D:
	if unit == null or not is_instance_valid(unit):
		return null
	var entry = _entries.get(unit.get_instance_id())
	return entry.body if entry != null else null


func _on_unit_exiting(id: int) -> void:
	# tree_exiting also fires on a plain reparent, so decide once the frame settles.
	call_deferred("_check_unit_exited", id)


func _check_unit_exited(id: int) -> void:
	var entry = _entries.get(id)
	if entry == null:
		return
	var unit = entry.unit
	if is_instance_valid(unit) and unit.is_inside_tree():
		return
	_detach_id(id)


func _detach_id(id: int) -> void:
	var entry = _entries.get(id)
	if entry == null:
		return
	_entries.erase(id)
	var unit = entry.unit
	var alive: bool = is_instance_valid(unit) and not unit.is_queued_for_deletion()
	if is_instance_valid(unit) and unit.tree_exiting.is_connected(entry.exit):
		unit.tree_exiting.disconnect(entry.exit)
	var bar: OverheadAnchor = entry.bar
	if is_instance_valid(bar):
		for record in bar.adopted:
			var control = record.node
			if not is_instance_valid(control):
				continue
			if alive:
				# The unit lives on (removed, not freed): give its Controls back unchanged.
				bar.remove_child(control)
				unit.add_child(control)
				unit.move_child(control, mini(int(record.index), unit.get_child_count() - 1))
		bar.adopted.clear()
		bar.visible = false
		bar.queue_free()
	if is_instance_valid(entry.body):
		entry.body.visible = false
		entry.body.queue_free()


func _prune_invalid() -> void:
	for id in _entries.keys():
		if not is_instance_valid(_entries[id].unit):
			_detach_id(id)


# --- floating text ---

func add_float(ft: Node2D) -> void:
	if not is_instance_valid(ft) or not ("label" in ft) or not ("start_y" in ft):
		return
	for sf in _floats:
		if is_instance_valid(sf) and sf.source == ft:
			return
	var holder := ScreenFloat.new()
	holder.name = "Float_%d" % ft.get_instance_id()
	holder.source = ft
	holder.visible = false
	floats_root.add_child(holder)
	_floats.append(holder)
	ft.tree_exiting.connect(_on_float_exiting.bind(holder), CONNECT_ONE_SHOT)
	_adopt_float_label(holder)


func _adopt_float_label(holder: ScreenFloat) -> void:
	if holder.label != null:
		return
	var ft = holder.source
	if not is_instance_valid(ft):
		return
	var label = ft.get("label")
	if label is Control and is_instance_valid(label) and label.get_parent() == ft:
		ft.remove_child(label)
		holder.add_child(label)
		holder.label = label


func _on_float_exiting(holder: ScreenFloat) -> void:
	call_deferred("_check_float_exited", holder)


func _check_float_exited(holder) -> void:
	if not is_instance_valid(holder):
		return
	var ft = holder.source
	if is_instance_valid(ft) and ft.is_inside_tree():
		ft.tree_exiting.connect(_on_float_exiting.bind(holder), CONNECT_ONE_SHOT)
		return
	if is_instance_valid(ft) and not ft.is_queued_for_deletion() and is_instance_valid(holder.label):
		holder.remove_child(holder.label)
		ft.add_child(holder.label)
	_floats.erase(holder)
	holder.queue_free()


# --- free labels ---

## A caption that follows `source` (Node2D sim point or Node3D) at a fixed screen offset until the source
## leaves the tree. font_size is in authored 2D px and is scaled by OVERHEAD_SCALE.
func add_label(source: Node, text: String, color: Color, screen_offset: Vector2, font_size: int = 12) -> void:
	if not is_instance_valid(source):
		return
	var item := {"source": source, "text": text, "color": color, "offset": screen_offset, "size": font_size}
	_labels.append(item)
	source.tree_exiting.connect(_on_label_source_exiting.bind(item), CONNECT_ONE_SHOT)


func _on_label_source_exiting(item: Dictionary) -> void:
	_labels.erase(item)


# --- per frame ---

func sync(host: Node3D) -> void:
	_host = host
	_captions.clear()
	_deadeye.clear()
	var cam: Camera3D = host.camera() if host != null and is_instance_valid(host) else null
	if cam == null or not cam.is_inside_tree():
		canvas.queue_redraw()
		return
	var up: Vector3 = host.card_up()
	var k: float = ViewConfig.OVERHEAD_SCALE
	_sync_units(cam, up, k)
	_sync_floats(cam, up, k)
	_sync_captions(cam, up, k)
	_sync_labels(cam, k)
	_sync_deadeye(cam, up, host.anim_time())
	# Perf: the caption canvas only redraws while it has something to show (and once more to clear it).
	var busy := not _captions.is_empty() or not _deadeye.is_empty()
	if busy or _canvas_drew:
		canvas.queue_redraw()
	_canvas_drew = busy


func _sync_units(cam: Camera3D, up: Vector3, k: float) -> void:
	var screen := cam.get_viewport().get_visible_rect()
	var blocks: Array = []
	_blocks.clear()
	var shown_entries: Array = []
	var champion_bars: Array = []
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		var unit = entry.unit
		var bar: OverheadAnchor = entry.bar
		var body: OverheadAnchor = entry.body
		if not is_instance_valid(unit):
			bar.visible = false
			body.visible = false
			continue
		var kind: String = unit.kind
		var top_px := _cached_top_px(entry, unit, kind)
		var scale_mult: float = ViewConfig.UNIT_SCALE
		var ku: float = k
		if kind == "minion":
			scale_mult = ViewConfig.MINION_SCALE
			ku = ViewConfig.OVERHEAD_SCALE_MINION
		elif kind == "structure":
			scale_mult = ViewConfig.STRUCTURE_SCALE
		var lift := 0.0 if kind == "structure" or not unit.buffs.has("airborne") else lift_of(unit)
		var feet3 := ViewMath.to3(unit.global_position)
		var head3 := feet3 + up * ViewMath.art_m(top_px + lift, scale_mult)
		var body3 := feet3 + up * ViewMath.art_m(lift, scale_mult)
		var shown: bool = unit.is_inside_tree() and unit.is_visible_in_tree() and not unit.dead and not cam.is_position_behind(head3)
		var head_screen := Vector2.ZERO
		if shown:
			head_screen = cam.unproject_position(head3)
			# Off-screen units (beyond a bar's reach of the viewport) skip the anchor work entirely.
			shown = screen.grow(OFFSCREEN_MARGIN_PX).has_point(head_screen)
		if bar.visible != shown:
			bar.visible = shown
			body.visible = shown
			if shown:
				# Status copies skip their refresh while the anchors are hidden (StatusVisual._process): bring
				# them current before this frame places and draws them.
				for copy in [entry.get("status"), body.get_node_or_null("BodyStatus")]:
					if copy != null and is_instance_valid(copy):
						copy.refresh()
		if not shown:
			continue
		# Perf: transforms and modulate are only written when they change (each write re-sends the canvas item and
		# notifies the adopted bars), so units standing still cost no canvas updates.
		var bar_pos := head_screen + Vector2(0.0, top_px * ku)
		if bar.position != bar_pos:
			bar.position = bar_pos
		if bar.scale != Vector2(ku, ku):
			bar.scale = Vector2(ku, ku)
		var body_screen := cam.unproject_position(body3)
		if body.position != body_screen:
			body.position = body_screen
		var kb := head_screen.distance_to(body_screen) / maxf(top_px, 1.0)
		if body.scale != Vector2(kb, kb):
			body.scale = Vector2(kb, kb)
		# 2D bars inherited the unit's modulate (BrushVision fade); mirror it read-only.
		var tint: Color = unit.modulate
		if bar.modulate != tint:
			bar.modulate = tint
		if body.modulate != tint:
			body.modulate = tint
		if kind == "champion":
			bar.refresh_decor()   # only champions draw decor (refresh_decor checks the kind again)
		shown_entries.append([entry, top_px])
		if kind == "champion":
			champion_bars.append(bar)
	_order_champion_bars(champion_bars, k)
	# Status blocks are placed after the champion bars settle (they ride on the bar anchors).
	for pair in shown_entries:
		var entry: Dictionary = pair[0]
		var status = entry.get("status")
		if status != null and is_instance_valid(status):
			var block = _place_status(status, entry.unit, float(pair[1]), k)
			if block != null:
				blocks.append(block)
	_declutter(blocks, k)
	for block in blocks:
		_blocks.append(block.rect)


## top_px_of; minions cache it per entry while their size is unchanged (Minion.art_rect() builds a body rect).
func _cached_top_px(entry: Dictionary, unit: Node2D, kind: String) -> float:
	if kind != "minion":
		return top_px_of(unit)
	var size: float = unit.size
	if entry.get("top_size", -1.0) != size:
		entry["top_size"] = size
		entry["top_px"] = top_px_of(unit)
	return entry["top_px"]


## Champion bars: nearer (lower on screen) draws on top, and a farther champion's name + bars block that
## overlaps a nearer one is nudged up (at most CHAMP_NUDGE_MAX block heights) so names never stack.
func _order_champion_bars(bars: Array, k: float) -> void:
	bars.sort_custom(func(a, b): return a.position.y > b.position.y)
	var placed: Array = []
	for i in bars.size():
		var bar: Node2D = bars[i]
		bar.z_index = Z_CHAMPION_BAR + 2 * (bars.size() - 1 - i)
		var rect := Rect2(bar.position + CHAMP_BLOCK.position * k, CHAMP_BLOCK.size * k)
		var y0 := rect.position.y
		for _pass in range(bars.size()):
			var moved := false
			for other in placed:
				if rect.intersects(other):
					rect.position.y = other.position.y - rect.size.y - CHAMP_BLOCK_GAP_PX
					moved = true
			if not moved:
				break
		var shift := maxf(rect.position.y - y0, -CHAMP_BLOCK.size.y * k * CHAMP_NUDGE_MAX)
		rect.position.y = y0 + shift
		bar.position.y += shift
		placed.append(rect)
	_blocks.append_array(placed)


## Scales the overhead StatusVisual about its pivot line; returns the champion's status block (screen
## rect) for decluttering, or null.
func _place_status(status, unit, top_px: float, k: float):
	var champion: bool = unit.kind == "champion"
	var s: float = STATUS_SCALE_CHAMPION if champion else STATUS_SCALE_SMALL
	var pivot: float = -top_px - (STATUS_PIVOT_CHAMPION_PX if champion else STATUS_PIVOT_SMALL_PX)
	if status.scale != Vector2(s, s):
		status.scale = Vector2(s, s)
	var at := Vector2(0.0, pivot * (1.0 - s))
	if status.position != at:
		status.position = at
	if not champion or not status.visible:
		return null
	var has_badge: bool = not status.primary_status.is_empty()
	var has_icons: bool = not status.overhead_statuses().is_empty()
	if not has_badge and not has_icons:
		return null
	# Status-local extent (StatusVisual._draw_overhead): badge around head_y, icon row above it.
	var head_y: float = -top_px - 56.0
	var y0: float = head_y - (34.0 if has_badge and has_icons else (17.0 if has_badge else 22.0))
	var y1: float = head_y + (6.0 if has_badge else 2.0)
	var half_w: float = 64.0 if has_badge else 30.0
	var bar: Node2D = status.get_parent()
	var top_left: Vector2 = bar.position + k * (status.position + s * Vector2(-half_w, y0))
	var bottom_right: Vector2 = bar.position + k * (status.position + s * Vector2(half_w, y1))
	return {"status": status, "rect": Rect2(top_left, bottom_right - top_left)}


## Champion status blocks that overlap on screen are nudged upward, nearest unit (lowest on screen) first.
func _declutter(blocks: Array, k: float) -> void:
	if blocks.size() < 2:
		return
	blocks.sort_custom(func(a, b): return a.rect.end.y > b.rect.end.y)
	var placed: Array = []
	for block in blocks:
		var rect: Rect2 = block.rect
		for _pass in range(blocks.size()):
			var moved := false
			for other in placed:
				if rect.intersects(other):
					rect.position.y = other.position.y - rect.size.y - BADGE_GAP_PX
					moved = true
			if not moved:
				break
		var shift: float = rect.position.y - block.rect.position.y
		if shift != 0.0:
			block.status.position.y += shift / k
		block.rect = rect
		placed.append(rect)


func _sync_floats(cam: Camera3D, up: Vector3, _k: float) -> void:
	var shown_list: Array = []
	for holder in _floats.duplicate():
		if not is_instance_valid(holder):
			_floats.erase(holder)
			continue
		var ft = holder.source
		if not is_instance_valid(ft):
			holder.visible = false
			continue
		_adopt_float_label(holder)
		var t: float = (float(ft.start_y) - ft.global_position.y) / FLOAT_RISE_ART_PX
		var p3 := ViewMath.to3(Vector2(ft.global_position.x, ft.start_y)) + up * ViewMath.art_m(FLOAT_BASE_ART_PX + FLOAT_RISE_ART_PX * t)
		var shown: bool = holder.label != null and ft.is_inside_tree() and ft.is_visible_in_tree() and not cam.is_position_behind(p3)
		holder.visible = shown
		if not shown:
			holder.placed = false
			continue
		holder.anchor = cam.unproject_position(p3)
		var ks: float = holder.text_scale()
		if holder.scale != Vector2(ks, ks):
			holder.scale = Vector2(ks, ks)
		shown_list.append(holder)
	_stack_floats(shown_list)


## Places the shown floats. Big worded callouts ("TURRET DESTROYED", "LEVEL 4") go first, then the rest newest
## first; each is pushed up above anything it overlaps (earlier floats and this frame's champion blocks), eased.
## A non-callout text that would need more than FLOAT_NUDGE_MAX_PX is dropped for the frame (holder alpha 0)
## instead of piling onto the others: in a crowded fight the newest numbers win.
func _stack_floats(list: Array) -> void:
	list.sort_custom(_float_before)
	var placed: Array = _blocks.duplicate()
	var step: float = FLOAT_NUDGE_SPEED_PX * maxf(get_process_delta_time(), 0.0)
	for holder in list:
		var local: Rect2 = holder.text_rect()
		var ks: float = holder.scale.x
		var base := Rect2(holder.anchor + local.position * ks, local.size * ks)
		var rect := base
		for _pass in range(placed.size() + 1):
			var moved := false
			for other in placed:
				if rect.intersects(other):
					rect.position.y = other.position.y - rect.size.y - FLOAT_GAP_PX
					moved = true
			if not moved:
				break
		var need := base.position.y - rect.position.y
		var overflow: bool = need > FLOAT_NUDGE_MAX_PX and not holder.is_callout()
		var alpha := 0.0 if overflow else 1.0
		if holder.modulate.a != alpha:
			holder.modulate.a = alpha
		if overflow:
			holder.placed = false
			continue
		var target := clampf(need, 0.0, FLOAT_NUDGE_MAX_PX)
		if not holder.placed:
			holder.nudge = target
			holder.placed = true
		else:
			holder.nudge = move_toward(holder.nudge, target, step)
		placed.append(Rect2(base.position - Vector2(0.0, target), base.size))
		var at: Vector2 = holder.anchor - Vector2(0.0, holder.nudge)
		if holder.position != at:
			holder.position = at


## Stacking order: callouts first, then newer before older (instance id breaks ties).
static func _float_before(a, b) -> bool:
	var ca: bool = a.is_callout()
	if ca != b.is_callout():
		return ca
	var ta: float = a.age()
	var tb: float = b.age()
	if ta != tb:
		return ta < tb
	return a.get_instance_id() > b.get_instance_id()


func _sync_captions(cam: Camera3D, up: Vector3, k: float) -> void:
	for item in ReticleText.labels(GameState.cursor_world):
		var pos := Vector2.ZERO
		if str(item.anchor) == "unit" and is_instance_valid(item.unit):
			var bar = anchor_for(item.unit)
			if bar != null and bar.visible:
				pos = bar.position + item.offset * k
			else:
				var feet3 := ViewMath.to3(item.unit.global_position)
				if cam.is_position_behind(feet3):
					continue
				pos = cam.unproject_position(feet3) + item.offset * k
		else:
			pos = _cursor_screen(cam, item.world) + item.offset * k
		_captions.append({"text": str(item.text), "pos": pos, "size": maxi(1, roundi(float(item.size) * k)), "color": item.color})


func _cursor_screen(cam: Camera3D, world: Vector2) -> Vector2:
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		return get_viewport().get_mouse_position()
	return cam.unproject_position(ViewMath.to3(world))


func _sync_labels(cam: Camera3D, k: float) -> void:
	for item in _labels.duplicate():
		var source = item.source
		if not is_instance_valid(source):
			_labels.erase(item)
			continue
		if not source.is_inside_tree():
			continue
		if (source is CanvasItem or source is Node3D) and not source.is_visible_in_tree():
			continue
		var p3 := Vector3.ZERO
		if source is Node3D:
			p3 = source.global_position
		elif source is Node2D:
			p3 = ViewMath.to3(source.global_position)
		else:
			continue
		if cam.is_position_behind(p3):
			continue
		_captions.append({"text": item.text, "pos": cam.unproject_position(p3) + item.offset, "size": maxi(1, roundi(float(item.size) * k)), "color": item.color})


func _sync_deadeye(cam: Camera3D, up: Vector3, phase: float) -> void:
	for c in GameState.champions:
		if not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
			continue
		var charge: Dictionary = DeadeyeCue.channel(c)
		if charge.is_empty() or not DeadeyeCue.visible(charge.target):
			continue
		var from3 := chest3(c, up)
		var to_p := chest3(charge.target, up)
		if cam.is_position_behind(from3) or cam.is_position_behind(to_p):
			continue
		_deadeye.append({"caster": c, "target": charge.target, "from": cam.unproject_position(from3), "to": cam.unproject_position(to_p), "progress": float(charge.progress), "phase": phase})


# --- drawing (OverheadCanvas) ---

func _draw_canvas() -> void:
	var k: float = ViewConfig.OVERHEAD_SCALE
	for line in _deadeye:
		var from: Vector2 = line.from
		var to: Vector2 = line.to
		var direction := (to - from).normalized()
		var muzzle := from + direction * 22.0 * k
		var progress: float = line.progress
		var phase: float = line.phase
		canvas.draw_line(muzzle, to, Color(0.02, 0.02, 0.03, 0.8), 3.5, true)
		canvas.draw_line(muzzle, to, Color(DEADEYE_GOLD, 0.55 + 0.3 * sin(phase * 18.0)), 1.3, true)
		canvas.draw_circle(muzzle, (6.0 + progress * 4.0) * k, Color(DEADEYE_GOLD, 0.18))
		canvas.draw_arc(muzzle, 10.0 * k, phase * 4.0, phase * 4.0 + TAU * progress, 32, DEADEYE_GOLD, 2.0, true)
		canvas.draw_circle(muzzle, (2.0 + progress * 2.0) * k, Color("fff4d9"))
	var font: Font = ThemeDB.fallback_font
	for caption in _captions:
		canvas.draw_string_outline(font, caption.pos, caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.size, 3, Color(0, 0, 0, 0.8))
		canvas.draw_string(font, caption.pos, caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.size, caption.color)


# --- queries (tests and other packages) ---

## Screen-space captions drawn this frame (ReticleText captions and add_label labels).
func captions() -> Array:
	return _captions


## Deadeye aim lines drawn this frame: {caster, target, from, to, progress, phase} in screen px.
func deadeye_lines() -> Array:
	return _deadeye


func float_for(ft: Node2D) -> Node2D:
	for holder in _floats:
		if is_instance_valid(holder) and holder.source == ft:
			return holder
	return null


## Authored art px from the feet to the top of the head (the 2D bar layout's reference line).
static func top_px_of(unit: Node2D) -> float:
	match str(unit.get("kind")):
		"champion":
			return Constants.CHAMP_ART_HEIGHT
		"minion":
			return -float(unit.art_rect().position.y)
		"structure":
			return -float(unit.art_rect.position.y)
	return Constants.CHAMP_ART_HEIGHT


static func lift_of(unit: Node2D) -> float:
	if not ("buffs" in unit) or not (unit.buffs is Dictionary):
		return 0.0
	return HeroControl.lift(unit)


static func chest3(unit: Node2D, up: Vector3) -> Vector3:
	return ViewMath.to3(unit.global_position) + up * ViewMath.art_m(CHEST_ART_PX + lift_of(unit))
