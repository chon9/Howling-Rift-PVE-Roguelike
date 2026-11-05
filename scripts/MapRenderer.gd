extends Node2D
# Painted bridge tiles and chasm backdrop, with gameplay boundaries unchanged.
var battlefield_texture: Texture2D
var chasm_texture: Texture2D
var cliff_texture: Texture2D
var brush_texture: Texture2D
func _ready() -> void:
	brush_texture=load("res://assets/environment/frost-brush-v1.png")
	battlefield_texture = load("res://assets/environment/rift-lane.png")
	chasm_texture = load("res://assets/environment/rift-chasm.png")
	cliff_texture=load("res://assets/environment/throne-cliff-cutout-v1.png")
	for right in [false,true]:
		var cap=Sprite2D.new();cap.texture=cliff_texture
		cap.position=Vector2(280 if not right else Constants.WORLD_W-280,343)
		cap.scale=Vector2(-1 if right else 1,1)*(1000./cliff_texture.get_width())
		cap.modulate=Color(.82,.86,.9)
		var blend=ShaderMaterial.new();blend.shader=load("res://assets/environment/cliff-blend.gdshader");cap.material=blend
		add_child(cap)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = Constants.Z_GROUND
	queue_redraw()
func _draw() -> void:
	# Crisp painted ravine tiles extend past the bridge on every screen edge.
	for row in range(-2, 3):
		for column in range(-2, 6):
			var flip_x = absi(column) % 2 == 1
			var flip_y = absi(row) % 2 == 1
			var origin = Vector2(column * 810 + (810 if flip_x else 0), row * 540 + (540 if flip_y else 0))
			draw_set_transform(origin, 0, Vector2(-1 if flip_x else 1, -1 if flip_y else 1))
			draw_texture_rect(chasm_texture, Rect2(0, 0, 810, 540), false, Color(0.5, 0.55, 0.65))
			draw_set_transform(Vector2.ZERO)
	var source = battlefield_texture.get_size()
	var tile_width = source.x / source.y * Constants.WORLD_H
	var x = 0.0
	var tile = 0
	while x < Constants.WORLD_W:
		var width = minf(tile_width, Constants.WORLD_W - x)
		var clipped_start=maxf(x,360.)
		var clipped_end=minf(x+width,Constants.WORLD_W-360.)
		if clipped_start>=clipped_end:x+=width;tile+=1;continue
		var skipped=clipped_start-x
		width=clipped_end-clipped_start
		var source_width = source.x * width / tile_width
		if tile % 2 == 0:
			draw_texture_rect_region(battlefield_texture, Rect2(clipped_start, 0, width, Constants.WORLD_H), Rect2(skipped*source.x/tile_width, 0, source_width, source.y), Color(0.82, 0.86, 0.9))
		else:
			# Mirroring joins identical edge pixels and prevents obvious tile seams.
			draw_set_transform(Vector2(clipped_end, 0), 0, Vector2(-1, 1))
			draw_texture_rect_region(battlefield_texture, Rect2(0, 0, width, Constants.WORLD_H), Rect2(source.x-(skipped+width)*source.x/tile_width, 0, source_width, source.y), Color(0.82, 0.86, 0.9))
			draw_set_transform(Vector2.ZERO)
		x += tile_width
		tile += 1
	for team in [Constants.BLUE, Constants.RED]:
		var point = Constants.FOUNT_B if team == Constants.BLUE else Constants.FOUNT_R
		var tint = Constants.TEAM_COLOR[team]
		draw_circle(point, 78, Color(tint.r, tint.g, tint.b, 0.12))
		draw_arc(point, 78, 0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.55), 2, true)

	# Painted concealment patches live on the walkable edges of the bridge.
	if brush_texture != null:
		for patch in BrushVision.PATCHES:
			draw_texture_rect(brush_texture,patch.grow(22),false,Color(.78,.9,.9))
