extends Node2D
class_name FloatingText

var label: Label
var life: float = 1.2
var elapsed: float = 0.0
var vel_y: float = -40
var start_y: float = 0.0

func setup(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	global_position = pos
	start_y = pos.y
	z_index = Constants.Z_FLOAT
	label = Label.new()
	label.add_theme_font_override("font",WorldTextFont.get_font())
	label.text = text
	label.add_theme_font_size_override("font_size", 22 if big else 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4 if big else 3)
	label.position = Vector2(-60, -10)
	label.size = Vector2(120, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func _process(delta: float) -> void:
	if GameState.paused:return
	elapsed += delta
	var t = elapsed / life
	global_position.y = start_y - 40 * t
	label.modulate.a = max(0.0, 1.0 - t)
	if elapsed >= life:
		queue_free()
