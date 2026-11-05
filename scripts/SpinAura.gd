extends Node2D
# Animated spell artwork for spinning champion skills.

var t: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta: float) -> void:
	if GameState.paused: return
	t += delta
	queue_redraw()

func _draw() -> void:
	var pulse = 1.0 + sin(t * 20.0) * 0.08
	var parent=get_parent()
	var r = float(parent.buffs.get("spin",{}).get("radius",72.))
	draw_texture_rect_region(SpellArt.impacts, Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2), SpellArt.frame(SpellArt.impacts, maxi(0,SpellArt.row_for(parent)), 3 + int(t * 12) % 4), Color(1, 1, 1, 0.7+pulse*.1))
