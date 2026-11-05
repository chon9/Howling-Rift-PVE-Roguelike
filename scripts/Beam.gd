extends Node2D

var length: float
var width: float
var color: Color
var life: float = 0.4
var art_row: int = 3

func setup(src, direction: Vector2, reach: float, half_width: float, damage: float, tint: Color) -> void:
	length = reach
	width = half_width
	color = tint
	global_position = src.world_pos()
	rotation = direction.angle()
	z_index = Constants.Z_PROJ
	art_row = maxi(0, SpellArt.row_for(src))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for target in GameState.champions + GameState.minions + GameState.structures:
		if target.dead or target.team == src.team or not target.is_targetable: continue
		if target.kind == "structure" and not target.is_structure_attackable(): continue
		var offset = target.world_pos() - global_position
		var along = offset.dot(direction)
		var across = abs(offset.cross(direction))
		if along >= 0 and along <= length and across <= width + target.size * 0.5:
			get_tree().call_group("game_main", "deal_damage", src, target, damage, "skill",src.active_cast_id)

func _process(delta: float) -> void:
	if GameState.paused: return
	life -= delta
	queue_redraw()
	if life <= 0: queue_free()

func _draw() -> void:
	var alpha = maxf(0, life / 0.4)
	draw_texture_rect_region(SpellArt.missiles, Rect2(Vector2(0, -width), Vector2(length, width * 2)), SpellArt.frame(SpellArt.missiles, art_row, mini(7, int((0.4 - life) * 20))), Color(1, 1, 1, alpha))
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(color.r, color.g, color.b, alpha * 0.2), width * 2., true)
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(color.r, color.g, color.b, alpha), width, true)
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(1, 1, 1, alpha), width * 0.2, true)
