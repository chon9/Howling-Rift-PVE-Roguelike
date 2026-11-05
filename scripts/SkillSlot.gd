extends Control
class_name SkillSlot
# A proper LoL-style skill slot. Replaces the previous PanelContainer "+ button"
# ugliness with a bigger slot (76px) that:
#   * draws its own frame, hotkey, pips, icon
#   * pulses a gold border when the champion has a point to spend on it
#   * has a radial cooldown wipe baked in
#   * offers a separate + button when upgradeable
#   * dims and shows "NOT LEARNED" when rank is 0

const SIZE = 76.0

var slot_idx: int = 0
var sk_data: Dictionary = {}
var player = null

# Interaction signals so Main / HUD can bind without touching internals
var panel_texture: Texture2D = preload("res://assets/ui/rift-panel.png")
var icon_texture: Texture2D
var upgrade_button: Button
signal upgrade_requested
signal clicked
signal hover_entered
signal hover_exited

# Transient state used by draw
var rank: int = 0
var max_rank: int = 5
var cd_frac: float = 0.0           # 0 = ready, 1 = full cooldown
var cd_remaining: float = 0.0
var ready_to_cast: bool = false
var can_level: bool = false
var not_learned: bool = true
var hero_color: Color = Color(0.4, 0.5, 0.7)
var pulse_t: float = 0.0
var recast_state: Dictionary = {}
var empowered: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	upgrade_button = Button.new()
	upgrade_button.text = "+"
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.position = Vector2(48, 46)
	upgrade_button.size = Vector2(28, 30)
	upgrade_button.add_theme_font_size_override("font_size", 18)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.11, 0.03, 0.98)
	style.border_color = Color(1, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "focus"]:
		upgrade_button.add_theme_stylebox_override(state, style)
	upgrade_button.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	add_child(upgrade_button)
	upgrade_button.hide()
	set_process(true)

func _process(delta: float) -> void:
	pulse_t += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sk_data.get("kind","")!="passive":clicked.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hover_entered.emit()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover_exited.emit()

func set_data(idx: int, hero_data: Dictionary, hero_key: String = "") -> void:
	icon_texture = AbilityArt.icon_for(hero_key, idx)
	slot_idx = idx
	sk_data = hero_data["skills"][idx]
	max_rank = sk_data["max"]
	hero_color = hero_data["accent"]

var disable_reason: String = ""

func set_state(p) -> void:
	player = p
	if player == null: return
	rank = player.skill_ranks[slot_idx]
	not_learned = rank <= 0
	cd_remaining = player.skill_cds[slot_idx]
	var base_cd = player.effective_cd(sk_data["cd"])
	cd_frac = (cd_remaining / base_cd) if base_cd > 0.001 else 0.0
	cd_frac = clamp(cd_frac, 0.0, 1.0)
	ready_to_cast = rank > 0 and cd_remaining <= 0 and player.mp >= sk_data["cost"]
	recast_state = NewHeroKits.recast_info(player,slot_idx)
	empowered = player.hero_key == "yasuo" and slot_idx == 0 and int(player.buffs.get("tempest",{}).get("stacks",0)) == 2
	if not recast_state.is_empty():
		ready_to_cast = recast_state.available and player.stun <= 0 and not player.buffs.has("silence")
		cd_frac = 0
		cd_remaining = 0
	disable_reason = "DEAD" if player.dead else ("SILENCED" if player.buffs.has("silence") else ("STUNNED" if player.stun>0 else ""))
	if sk_data.get("kind","")=="passive":disable_reason=""
	if disable_reason!="":ready_to_cast=false
	can_level = player.can_level_skill(slot_idx)
	upgrade_button.visible = can_level
	upgrade_button.tooltip_text = "Upgrade %s  [Ctrl+%s]" % [sk_data.name, sk_data.key]

func _draw() -> void:
	var c = size * 0.5
	var pulse = 0.5 + 0.5 * sin(pulse_t * 4.0)

	# Outer soft glow when upgradeable OR ready
	if can_level:
		for i in range(4):
			var g = Color(1.0, 0.86, 0.33, 0.08 + 0.04 * pulse)
			draw_rect(Rect2(Vector2(-i*2, -i*2), size + Vector2(i*4, i*4)), g, true)
	elif ready_to_cast:
		for i in range(2):
			draw_rect(Rect2(Vector2(-i*2, -i*2), size + Vector2(i*4, i*4)),
				Color(hero_color.r, hero_color.g, hero_color.b, 0.1), true)

	# Base plate (dark gradient approximated with 2 rects)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.13), true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, size.y * 0.5)),
		Color(0.09, 0.12, 0.22, 0.6), true)
	RiftFrame.draw_frame(self, Rect2(Vector2.ZERO, size), panel_texture, 10)
	# Inner icon area
	var pad = 6
	draw_rect(Rect2(Vector2(pad, pad), size - Vector2(pad*2, pad*2)),
		Color(0.11, 0.14, 0.25), true)
	# Dim if not learned
	if not_learned:
		draw_rect(Rect2(Vector2(pad, pad), size - Vector2(pad*2, pad*2)),
			Color(0, 0, 0, 0.5), true)

	# Outer border — colour depends on state
	var border_col: Color
	var border_w: float = 2.0
	if can_level:
		border_col = Color(1.0, 0.86 + 0.1 * pulse, 0.2 + 0.3 * pulse)
		border_w = 3.0
	elif not recast_state.is_empty() or empowered:
		border_col = Color("8ae7ed")
		border_w = 3.0
	elif ready_to_cast:
		border_col = Color(1.0, 0.75, 0.3)
		border_w = 2.5
	elif cd_remaining > 0:
		border_col = Color(0.3, 0.35, 0.5)
	elif not_learned:
		border_col = Color(0.25, 0.28, 0.4)
	else:
		border_col = Color(hero_color.r, hero_color.g, hero_color.b, 0.8)
	draw_rect(Rect2(Vector2.ZERO, size), border_col, false, border_w)

	# Rank pips (top of slot)
	var pip_y = 4.0
	var pip_w = 10.0
	var pip_h = 4.0
	var pip_gap = 2.0
	var total_w = max_rank * pip_w + (max_rank - 1) * pip_gap
	var pip_x = (size.x - total_w) * 0.5
	for i in range(max_rank):
		var filled = i < rank
		var pcol = Color(1.0, 0.75, 0.2) if filled else Color(0.2, 0.23, 0.33)
		if can_level and i == rank:
			pcol = Color(1.0, 0.86 + 0.1 * pulse, 0.4)
		draw_rect(Rect2(Vector2(pip_x + i * (pip_w + pip_gap), pip_y),
			Vector2(pip_w, pip_h)), pcol, true)
		if filled:
			# Thin highlight
			draw_rect(Rect2(Vector2(pip_x + i * (pip_w + pip_gap), pip_y),
				Vector2(pip_w, 1)), Color(1, 1, 1, 0.6), true)

	# Painted ability art; hotkeys, pips and cooldowns remain readable overlays.
	var font = get_theme_default_font()
	if icon_texture != null:
		draw_texture_rect(icon_texture, Rect2(Vector2(6, 9), size - Vector2(12, 15)), false, Color(0.4, 0.4, 0.45) if not_learned else Color.WHITE)
	# Redraw pips above the image.
	for i in range(max_rank):
		draw_rect(Rect2(Vector2(pip_x + i * (pip_w + pip_gap), pip_y), Vector2(pip_w, pip_h)), Color(1, 0.8, 0.25) if i < rank else Color(0.18, 0.21, 0.28), true)
	draw_rect(Rect2(3, 9, 18, 18), Color(0.02, 0.03, 0.05, 0.85))
	# Hotkey (top-left)
	var key_text = "P" if sk_data.get("kind","")=="passive" else sk_data.get("key", "")
	draw_string(font, Vector2(6, 23), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1.0, 0.86, 0.33))

	# Mana cost (bottom-right small label)
	var cost = sk_data.get("cost", 0)
	if cost > 0 and not not_learned and recast_state.is_empty():
		var cost_s = str(int(cost))
		var cs = font.get_string_size(cost_s, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10)
		draw_string(font, Vector2(6, size.y - 5),
			cost_s, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.5, 0.75, 1.0))

	# Cooldown radial sweep (dark overlay)
	if cd_frac > 0.001:
		var start_a = -PI * 0.5
		var end_a = start_a + TAU * cd_frac
		var r = size.x * 0.65
		var pts = PackedVector2Array([c])
		for i in range(33):
			var t = float(i) / 32.0
			var a = start_a + (end_a - start_a) * t
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if cd_frac >= 0.999:
			draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.78))
		else:
			draw_colored_polygon(pts, Color(0.02, 0.03, 0.06, 0.78))
		# Trailing edge line
		draw_line(c, c + Vector2(cos(end_a), sin(end_a)) * r,
			Color(1.0, 0.86, 0.33, 0.9), 1.5, true)
		# Big cooldown number
		var cd_s = "%.1f" % cd_remaining if cd_remaining < 10 else "%d" % int(cd_remaining)
		var cds = font.get_string_size(cd_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		draw_string(font, Vector2(c.x - cds.x * 0.5, c.y + 7),
			cd_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

	if not recast_state.is_empty():
		var ratio = clampf(recast_state.time/recast_state.duration,0,1)
		draw_rect(Rect2(4,size.y-9,(size.x-8)*ratio,5),Color("75e0e7"))
		draw_rect(Rect2(3,28,size.x-6,22),Color(0.01,0.06,0.08,0.92))
		var countdown = "%.1fs" % recast_state.time
		var measure = font.get_string_size(countdown,HORIZONTAL_ALIGNMENT_CENTER,-1,18)
		draw_string(font,Vector2(c.x-measure.x/2,46),countdown,HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color("d5ffff"))
		var caption = recast_state.label if recast_state.available else "TOO FAR"
		var caption_width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_CENTER,-1,10).x
		draw_string(font,Vector2(c.x-caption_width/2,size.y-15),caption,HORIZONTAL_ALIGNMENT_CENTER,-1,10,Color("a3edf2"))
	elif empowered:
		draw_rect(Rect2(3,size.y-23,size.x-6,20),Color(0.02,0.09,0.12,0.92))
		draw_string(font,Vector2(9,size.y-9),"TORNADO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("baf7ff"))
	# "NOT LEARNED" banner across slot
	if not_learned:
		var nl_s = "NOT LEARNED"
		var nls = font.get_string_size(nl_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
		draw_string(font, Vector2(c.x - nls.x * 0.5, c.y + 24),
			nl_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.7, 0.7, 0.75))

	if disable_reason!="" and not not_learned:
		draw_rect(Rect2(3,28,size.x-6,22),Color(.07,.025,.1,.9))
		var width=font.get_string_size(disable_reason,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_string(font,Vector2(c.x-width/2,43),disable_reason,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("dabaff"))
