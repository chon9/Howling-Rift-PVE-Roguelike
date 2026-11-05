class_name OverheadAnchor
extends Node2D
## Screen-space anchor that carries a unit's reparented bars and overhead StatusVisual (W1-OVERHEAD).
## Its local space is the unit's authored 2D space: (0, 0) is the (virtual) feet point and -y is up, so
## reparented Controls keep their original local positions. OverheadLayer.sync positions and scales it.

const ROLE_BAR := "bar"
const ROLE_BODY := "body"

var unit: Node2D
var view: Node3D = null
var role: String = ROLE_BAR
## Controls moved here from the unit: [{"node": Control, "index": int}]. Returned or freed on detach.
var adopted: Array = []

var _decor: Node2D = null
var _decor_stamp: Vector3 = Vector3(-1.0, -1.0, -1.0)   # (hp_max, level, dead) last drawn


## Adds the decoration child (HP ticks and level badge). Call after the bars are adopted so it draws over them.
func add_decor() -> void:
	if _decor == null:
		_decor = Node2D.new()
		_decor.name = "Decor"
		_decor.z_index = 1
		add_child(_decor)
		_decor.draw.connect(_draw_decor)


## Redraws the decor only when what it shows changes (hp_max ticks, level, death): it is drawn in the anchor's
## local space, so moving or scaling the anchor never needs a redraw. Only champions draw decor.
func refresh_decor() -> void:
	if _decor == null or not is_instance_valid(unit):
		return
	if str(unit.get("kind")) != "champion":
		return
	var stamp := Vector3(float(unit.hp_max), float(unit.level), 1.0 if unit.dead else 0.0)
	if stamp == _decor_stamp:
		return
	_decor_stamp = stamp
	_decor.queue_redraw()


func _draw_decor() -> void:
	if not is_instance_valid(unit) or str(unit.get("kind")) != "champion" or unit.dead:
		return
	_draw_ticks(_decor)
	_draw_level(_decor)


## HP-bar ticks at the 2D formula (bar_y -68, every 100 HP), heavier (x2) every 1000 HP.
func _draw_ticks(canvas: CanvasItem) -> void:
	var bar_x: float = -Constants.CHAMP_BAR_WIDTH / 2.0
	var bar_y: float = -Constants.CHAMP_ART_HEIGHT - 12.0
	var bar_w: float = Constants.CHAMP_BAR_WIDTH
	var hp_max: float = float(unit.hp_max)
	if hp_max <= 0.0:
		return
	var ticks := int(hp_max / 100.0)
	if ticks <= 1:
		return
	for i in range(1, ticks):
		var heavy := i % 10 == 0
		if ticks >= 25 and not heavy:
			continue
		var tx := bar_x + bar_w * i * 100.0 / hp_max
		canvas.draw_line(Vector2(tx, bar_y), Vector2(tx, bar_y + 5), Color(0, 0, 0, 0.8 if heavy else 0.6), 2.0 if heavy else 1.0)


## Level badge Rect2(-37, -69, 12, 12), left of the bars, level in WorldTextFont size 9.
func _draw_level(canvas: CanvasItem) -> void:
	var rect := Rect2(-37, -69, 12, 12)
	canvas.draw_rect(rect, Color(0.025, 0.035, 0.055, 0.94))
	canvas.draw_rect(rect, Color(0.85, 0.72, 0.42, 0.9), false, 1.0)
	var font: Font = WorldTextFont.get_font()
	var text := str(int(unit.level))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var at := Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + 9.5)
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color.BLACK)
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.93, 0.75))
