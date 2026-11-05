extends Control
# Draws a radial cooldown wipe over a skill slot (LoL-style). Set `fraction`
# between 0 and 1 — the covered sector shrinks clockwise as cooldown finishes.

var fraction: float = 0.0  # 0 = ready, 1 = just started cooldown

func _draw() -> void:
	if fraction <= 0.001: return
	var c = size * 0.5
	var r = size.x * 0.72
	# Dark overlay: unfilled sector means "still on cooldown"
	var start_ang = -PI * 0.5  # 12 o'clock
	var end_ang = start_ang + TAU * fraction
	var pts = PackedVector2Array([c])
	var seg = 32
	for i in range(seg + 1):
		var t = float(i) / float(seg)
		var a = start_ang + (end_ang - start_ang) * t
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(c)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.72))
	# Thin leading-edge sweep line
	draw_line(c, c + Vector2(cos(end_ang), sin(end_ang)) * r,
		Color(1.0, 0.86, 0.33, 0.9), 1.5)

func set_fraction(f: float) -> void:
	fraction = clamp(f, 0.0, 1.0)
	queue_redraw()
