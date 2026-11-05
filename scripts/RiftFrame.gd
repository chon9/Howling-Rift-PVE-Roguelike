extends Control
class_name RiftFrame
# Draw a generated frame with small screen-space corners at any UI size.
var inset: float = 16
var corner: float = 22
var frame_texture: Texture2D = preload("res://assets/ui/rift-panel.png")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_frame(self, Rect2(Vector2.ZERO, size).grow(inset), frame_texture, corner)

static func draw_frame(canvas: CanvasItem, target: Rect2, texture: Texture2D, edge: float = 22) -> void:
	var source = texture.get_size()
	var sx = source.x * 0.09
	var sy = source.y * 0.09
	var width = minf(edge, target.size.x * 0.25)
	var height = minf(edge, target.size.y * 0.25)
	var xs = [0.0, sx, source.x - sx, source.x]
	var ys = [0.0, sy, source.y - sy, source.y]
	var tx = [target.position.x, target.position.x + width, target.end.x - width, target.end.x]
	var ty = [target.position.y, target.position.y + height, target.end.y - height, target.end.y]
	for row in range(3):
		for col in range(3):
			canvas.draw_texture_rect_region(texture, Rect2(tx[col], ty[row], tx[col+1]-tx[col], ty[row+1]-ty[row]), Rect2(xs[col], ys[row], xs[col+1]-xs[col], ys[row+1]-ys[row]))

static func decorate(panel: PanelContainer, margin: float = 16, edge: float = 22) -> void:
	var style = StyleBoxEmpty.new()
	style.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", style)
	var art = load("res://scripts/RiftFrame.gd").new()
	art.inset = margin
	art.corner = edge
	panel.add_child(art)
	panel.move_child(art, 0)
