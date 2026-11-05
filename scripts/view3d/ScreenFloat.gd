class_name ScreenFloat
extends Node2D
## Screen-space holder for a FloatingText label (W1-OVERHEAD). The label keeps its authored local position
## (-60, -10) apart from the lift below; OverheadLayer.sync places this node over the text's rising world point and
## scales it by the overhead scale k.
##
## Readability (final polish), all inside the holder so OverheadLayer's placement contract is unchanged:
## - the label is lifted LIFT_PX (local px, so k times that on screen) above the anchor, clear of the chest-height
##   spell and hit bursts it used to sit inside;
## - a heavier dark outline plus a soft drop shadow, so numbers read over additive FX and bright snow;
## - LoL-like timing: full opacity for HOLD of the life, then a quick fade (FloatingText fades linearly from the
##   start, which kept the number dim while it mattered). Driven from the source's own elapsed / life, so it is
##   stable while paused and identical on every peer. The font size (the LoL-like scale) is left as authored.
##
## Declutter (final fix): OverheadLayer places the holder at `anchor` (the projected rising world point) minus
## `nudge` (screen px, eased) so texts stack instead of overlapping each other and the champion name/bar blocks,
## and scales it by text_scale() (numbers vs worded callouts, ViewConfig.FLOAT_SCALE_*). Long labels are
## re-centred on the anchor (a Label wider than its authored 120 px grows to the right only).

const LIFT_PX := 22.0                  # local px above the anchor (x OVERHEAD_SCALE on screen)
const OUTLINE_SMALL := 6               # outline_size for 14 px text (FloatingText uses 3)
const OUTLINE_BIG := 8                 # ... for 22 px crit / big text (FloatingText uses 4)
const OUTLINE_COLOR := Color(0.02, 0.02, 0.04, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const SHADOW_OFFSET := Vector2i(1, 2)
const POP_TIME := 0.16
const HOLD := 0.6                      # share of the life at full opacity

var source: Node2D
var label: Control = null
var _styled: Control = null
var anchor: Vector2 = Vector2.ZERO     # unnudged screen position (OverheadLayer)
var nudge: float = 0.0                 # current upward stacking shift in screen px
var placed: bool = false               # false until the first shown frame (the first nudge snaps)
var _rect_key: String = ""
var _rect: Rect2 = Rect2()


func _init() -> void:
	# After FloatingText (priority 0) so the alpha written here wins in the same frame; below View3D's
	# ViewConfig.PROCESS_PRIORITY (100), which must stay the last view-side process.
	process_priority = 50


func _process(_delta: float) -> void:
	if label == null or not is_instance_valid(label):
		return
	if _styled != label:
		style_label(label)
		_styled = label
	if is_instance_valid(source) and "elapsed" in source and "life" in source:
		label.modulate.a = alpha_at(float(source.elapsed) / maxf(float(source.life), 0.001))
		# Numbers and callouts pop in, then settle at their normal size.
		var pop := 1.0 + 0.55 * pow(maxf(0.0, 1.0 - float(source.elapsed) / POP_TIME), 2.0)
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(pop, pop)


## Seconds since the source text spawned (0 when unknown).
func age() -> float:
	if is_instance_valid(source) and "elapsed" in source:
		return float(source.elapsed)
	return 0.0


## Screen scale for this text: FLOAT_SCALE_NUMBER for plain numbers, FLOAT_SCALE_WORD for worded callouts.
func text_scale() -> float:
	if label == null or not is_instance_valid(label) or not ("text" in label):
		return ViewConfig.FLOAT_SCALE_WORD
	return ViewConfig.FLOAT_SCALE_NUMBER if is_number_text(str(label.text)) else ViewConfig.FLOAT_SCALE_WORD


## Big worded callout ("TURRET DESTROYED", "INHIBITOR DOWN", "LEVEL 4"): placed first and never dropped.
func is_callout() -> bool:
	if label == null or not is_instance_valid(label):
		return false
	return label.get_theme_font_size("font_size") >= 20 and not is_number_text(str(label.get("text")))


## "-112", "+42g", "245": a signed integer with an optional gold suffix.
static func is_number_text(text: String) -> bool:
	var t := text.strip_edges()
	if t.begins_with("-") or t.begins_with("+"):
		t = t.substr(1)
	if t.ends_with("g"):
		t = t.left(t.length() - 1)
	return t != "" and t.is_valid_int()


## Keeps the label centred on the anchor and returns the drawn text's box in holder-local px (glyph width plus
## outline, not the label's fixed 120 px), cached while the text and font size are unchanged.
func text_rect() -> Rect2:
	if label == null or not is_instance_valid(label):
		return Rect2()
	var w: float = label.size.x
	if not is_equal_approx(label.position.x, -0.5 * w):
		label.position.x = -0.5 * w
	var text := str(label.get("text"))
	var font_size: int = label.get_theme_font_size("font_size")
	var key := "%s|%d|%.1f" % [text, font_size, label.position.y]
	if key != _rect_key:
		_rect_key = key
		var font: Font = label.get_theme_font("font")
		var outline: float = float(label.get_theme_constant("outline_size"))
		var tw := w
		var th: float = label.size.y
		if font != null:
			tw = minf(w, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + outline
			th = maxf(th, font.get_height(font_size))
		_rect = Rect2(Vector2(-0.5 * tw, label.position.y), Vector2(tw, th))
	return _rect


## Label alpha at life fraction t (0..1): held, then a smooth fade.
static func alpha_at(t: float) -> float:
	return 1.0 - smoothstep(HOLD, 1.0, clampf(t, 0.0, 1.0))


## Heavier outline, drop shadow and the lift. Idempotent (meta flag), so a re-adopted label is not lifted twice.
static func style_label(l: Control) -> void:
	if l.has_meta("screen_float_styled"):
		return
	l.set_meta("screen_float_styled", true)
	var big := l.get_theme_font_size("font_size") >= 20
	var outline := OUTLINE_BIG if big else OUTLINE_SMALL
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	l.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	l.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET.x)
	l.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET.y)
	l.add_theme_constant_override("shadow_outline_size", outline + 2)
	l.position.y -= LIFT_PX
