extends Node2D
var row: int = 0
var radius: float = 50
var elapsed: float = 0
var duration: float = 0.3
func _ready() -> void:
 z_index = Constants.Z_FX
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _process(delta: float) -> void:
 if GameState.paused: return
 elapsed += delta
 if elapsed>=duration: queue_free(); return
 queue_redraw()
func _draw() -> void:
 draw_texture_rect_region(WindArt.texture,Rect2(Vector2(-radius,-radius),Vector2.ONE*radius*2),WindArt.frame(row,mini(3,int(elapsed/duration*4))),Color(1,1,1,1-elapsed/duration*0.4))
