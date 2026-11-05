class_name WindArt
extends RefCounted
static var texture: Texture2D = preload("res://assets/vfx/wind-samurai-v2.png")
static func frame(row: int, column: int) -> Rect2:
 var cell = texture.get_size()/4
 return Rect2(Vector2(clampi(column,0,3),clampi(row,0,3))*cell,cell)
