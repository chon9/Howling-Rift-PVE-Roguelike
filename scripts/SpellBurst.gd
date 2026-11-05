extends Node2D

var row: int = 0
var radius: float = 40.0
var elapsed: float = 0.0
var duration: float = 0.45

func _ready() -> void:
	z_index = Constants.Z_FX
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta: float) -> void:
	if GameState.paused: return
	elapsed += delta
	queue_redraw()
	if elapsed >= duration: queue_free()

func _draw() -> void:
	var frame = mini(7, int(elapsed / duration * 8))
	draw_texture_rect_region(SpellArt.impacts, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), SpellArt.frame(SpellArt.impacts, row, frame), Color(1, 1, 1, 0.85))
