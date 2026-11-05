extends Control
# Generated map and frame with runtime units and a camera viewport overlay.
var map_texture: Texture2D = preload("res://assets/ui/rift-minimap.png")
var frame_texture: Texture2D = preload("res://assets/ui/rift-panel.png")
var player = null
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tooltip_text = "Left-click: move camera. Right-click: move / attack. Space: follow hero."
	resized.connect(queue_redraw)
func map_rect() -> Rect2:
	return Rect2(14, 30, maxf(1, size.x - 28), maxf(1, size.y - 46))
func world_to_map(point: Vector2) -> Vector2:
	return map_rect().position + point / Vector2(Constants.WORLD_W, Constants.WORLD_H) * map_rect().size
func map_to_world(point: Vector2) -> Vector2:
	return ((point - map_rect().position) / map_rect().size).clamp(Vector2.ZERO, Vector2.ONE) * Vector2(Constants.WORLD_W, Constants.WORLD_H)
func _gui_input(event: InputEvent) -> void:
	if not GameState.running or GameState.paused or not event is InputEventMouseButton or not event.pressed: return
	if not map_rect().has_point(event.position): return
	var point = map_to_world(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		GameState.cam_locked = false
		GameState.cam_target = point
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		get_tree().call_group("game_main", "_issue_player_order", {"type":"smart", "point":point})
		accept_event()
func _draw() -> void:
	RiftFrame.draw_frame(self, Rect2(Vector2.ZERO, size), frame_texture, 20)
	draw_texture_rect(map_texture, map_rect(), false)
	draw_rect(map_rect(), Color(0.0, 0.03, 0.07, 0.16))
	for patch in BrushVision.PATCHES:
		draw_rect(Rect2(world_to_map(patch.position),patch.size/Vector2(Constants.WORLD_W,Constants.WORLD_H)*map_rect().size),Color(.2,.5,.4,.8))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(16, 22), "HOWLING RIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6c799"))
	for structure in GameState.structures:
		if not is_instance_valid(structure) or structure.dead: continue
		var point = world_to_map(structure.world_pos())
		var color = Constants.TEAM_COLOR[structure.team].lightened(0.25)
		var radius = 5.0 if structure.type == "nexus" else 3.0
		draw_rect(Rect2(point - Vector2.ONE * (radius + 1), Vector2.ONE * (radius + 1) * 2), Color("071018"))
		draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2), color)
	for creep in GameState.minions:
		if not is_instance_valid(creep) or creep.dead: continue
		draw_circle(world_to_map(creep.world_pos()), 1.5, Constants.TEAM_COLOR[creep.team].lightened(0.3))
	for champion in GameState.champions:
		if not is_instance_valid(champion) or champion.dead or (is_instance_valid(player) and not BrushVision.visible_to(champion,player.team)): continue
		var point = world_to_map(champion.world_pos())
		var color = Color("ffe082") if champion == player else Constants.TEAM_COLOR[champion.team].lightened(0.35)
		draw_circle(point, 5.5, Color("061018"))
		draw_circle(point, 3.5, color)
		if champion == player: draw_arc(point, 6, 0, TAU, 24, color, 1, true)
	var footprint = View3D.current.footprint_sim() if View3D.current != null and View3D.current.is_active() else PackedVector2Array()
	if footprint.size() == 4:
		var outline = PackedVector2Array()
		var bounds = map_rect()
		for pt in footprint:
			outline.append(world_to_map(pt).clamp(bounds.position, bounds.end))
		outline.append(outline[0])
		draw_polyline(outline, Color(0.9, 0.95, 1, 0.65), 1, true)
		return
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		var half_view = get_viewport_rect().size / camera.zoom * 0.5
		var camera_box = Rect2(world_to_map(camera.global_position - half_view), half_view * 2 / Vector2(Constants.WORLD_W, Constants.WORLD_H) * map_rect().size)
		draw_rect(camera_box.intersection(map_rect()), Color(0.9, 0.95, 1, 0.65), false, 1, true)
