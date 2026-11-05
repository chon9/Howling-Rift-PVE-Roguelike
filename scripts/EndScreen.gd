class_name EndScreen
extends Control
## Match result screen: a crest with the result over the dimmed battlefield, the player's line, both teams and the
## match report. HUD keeps title and stats as end_title and end_stats; Main appends rewards to stats.

const GOLD := Color(1.0, 0.84, 0.46)
const BORDER := Color(0.67, 0.58, 0.36)
const MUTED := Color(0.68, 0.74, 0.84)
const WIN_RAY := Color(1.0, 0.8, 0.42)
const LOSS_RAY := Color(0.86, 0.2, 0.17)
const LOSS_TEXT := Color(1.0, 0.42, 0.38)

var crest: _Crest
var title: Label
var subtitle: Label
var stats: Label
var portrait: TextureRect
var player_name: Label
var player_info: Label
var kda_value: Label
var cs_value: Label
var gold_value: Label
var time_value: Label
var team_rows: Array = []     # one VBoxContainer per team
var team_heads: Array = []
var continue_button: Button
var menu_button: Button
var _won := false
var _sections: Array = []


func _init() -> void:
	name = "EndScreen"
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.03, 0.06, 0.74)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	add_child(_vignette())

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1120, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	crest = _Crest.new()
	crest.custom_minimum_size = Vector2(1120, 250)
	column.add_child(crest)
	title = Label.new()
	title.text = "VICTORY"
	title.anchor_right = 1.0
	title.anchor_bottom = 1.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var heading := FontVariation.new()
	heading.base_font = CombatFeedbackArt.font()
	heading.spacing_glyph = 16
	title.add_theme_font_override("font", heading)
	title.add_theme_font_size_override("font_size", 112)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 6)
	crest.add_child(title)

	subtitle = _label("", 24, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_player_panel())
	column.add_child(_teams_row())
	column.add_child(_report_panel())

	continue_button = _gold_button("PLAY AGAIN")
	continue_button.pressed.connect(func(): get_tree().call_group("game_main", "start_next_match", _won))
	menu_button = _gold_button("MAIN MENU")
	menu_button.name = "MainMenu"
	menu_button.custom_minimum_size.x = 240
	menu_button.pressed.connect(func(): get_tree().call_group("game_main", "_return_to_main_menu"))
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	button_row.add_child(continue_button)
	button_row.add_child(menu_button)
	column.add_child(button_row)
	_sections = [subtitle, column.get_child(2), column.get_child(3), column.get_child(4), button_row]
	set_process(false)


## Fills the screen for this result and plays the reveal. The match report text arrives through stats afterwards.
func present(won: bool, player, match_time: float) -> void:
	show()
	title.text = "VICTORY" if won else "DEFEAT"
	title.add_theme_color_override("font_color", GOLD if won else LOSS_TEXT)
	_won = won
	subtitle.text = "The enemy Throne has fallen" if won else "Your Throne has fallen"
	var solo: bool = not LanSession.active and not GameState.is_pvp()
	if won and solo and Progression.win_streak >= 2:
		subtitle.text += "  •  WIN STREAK %d" % Progression.win_streak
	continue_button.visible = solo
	continue_button.text = ("NEXT: N%d" % mini(99, Progression.difficulty + 1)) if won else "TRY AGAIN"
	crest.setup(won)
	if player != null and is_instance_valid(player):
		portrait.texture = _portrait_of(player)
		player_name.text = str(player.hero.name)
		player_info.text = "Level %d  •  %s" % [player.level, player.char_name]
		kda_value.text = "%d / %d / %d" % [player.kills, player.deaths, player.assists]
		cs_value.text = str(player.cs)
		gold_value.text = str(int(player.gold))
	time_value.text = "%02d:%02d" % [int(match_time / 60.0), int(match_time) % 60]
	var winner: int = -1
	if player != null and is_instance_valid(player):
		winner = player.team if won else (Constants.RED if player.team == Constants.BLUE else Constants.BLUE)
	_fill_teams(winner, player)
	set_process(true)
	(continue_button if solo else menu_button).grab_focus()
	if is_inside_tree():
		_reveal()


func _process(delta: float) -> void:
	crest.spin(delta)


func _reveal() -> void:
	modulate.a = 0.0
	title.pivot_offset = crest.custom_minimum_size * 0.5
	title.scale = Vector2.ONE * 1.3
	for section in _sections:
		section.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.45)
	tween.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := 0.35
	for section in _sections:
		tween.tween_property(section, "modulate:a", 1.0, 0.3).set_delay(delay)
		delay += 0.1


func _fill_teams(winner: int, player) -> void:
	for team in [Constants.BLUE, Constants.RED]:
		var rows: VBoxContainer = team_rows[team]
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		var head: Label = team_heads[team]
		head.text = ("BLUE TEAM" if team == Constants.BLUE else "RED TEAM") + ("  •  WINNER" if team == winner else "")
		head.add_theme_color_override("font_color", GOLD if team == winner else MUTED)
		for c in GameState.champions:
			if is_instance_valid(c) and c.team == team and c.roster_active:
				rows.add_child(_team_row(c, c == player))


func _team_row(c, is_player: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(38, 38)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture = _portrait_of(c)
	row.add_child(face)
	var who := _label(str(c.char_name), 20, GOLD if is_player else Color(0.9, 0.93, 0.98))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	row.add_child(who)
	row.add_child(_label("L%d" % c.level, 18, MUTED))
	var kda := _label("%d / %d / %d" % [c.kills, c.deaths, c.assists], 20, Color(0.9, 0.93, 0.98))
	kda.custom_minimum_size.x = 112
	kda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(kda)
	return row


func _player_panel() -> Control:
	var panel := _panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0.5)
	frame_style.border_color = GOLD
	frame_style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(portrait)
	row.add_child(frame)
	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name = _label("", 36, Color.WHITE)
	player_name.add_theme_font_override("font", CombatFeedbackArt.font())
	player_info = _label("", 20, MUTED)
	who.add_child(player_name)
	who.add_child(player_info)
	row.add_child(who)
	kda_value = _tile(row, "KILLS / DEATHS / ASSISTS", 188)
	cs_value = _tile(row, "CREEPS", 90)
	gold_value = _tile(row, "GOLD", 110)
	time_value = _tile(row, "TIME", 100)
	return panel


func _tile(parent: Control, caption: String, width: float) -> Label:
	var tile := VBoxContainer.new()
	tile.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.custom_minimum_size.x = width
	var value := _label("0", 34, GOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label := _label(caption, 15, MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(value)
	tile.add_child(label)
	parent.add_child(tile)
	return value


func _teams_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for team in [Constants.BLUE, Constants.RED]:
		var panel := _panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		var head := _label("", 18, MUTED)
		box.add_child(head)
		team_heads.append(head)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		box.add_child(rows)
		team_rows.append(rows)
		row.add_child(panel)
	return row


func _report_panel() -> Control:
	var panel := _panel()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	stats = _label("", 19, Color(0.85, 0.89, 0.96))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stats)
	return panel


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.055, 0.095, 0.93)
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_content_margin_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _gold_button(text: String) -> Button:
	var button := Button.new()
	button.name = "PlayAgain"
	button.text = text
	button.custom_minimum_size = Vector2(320, 62)
	button.add_theme_font_size_override("font_size", 24)
	for state in [["normal", Color(0.86, 0.68, 0.3)], ["hover", Color(1.0, 0.85, 0.47)], ["pressed", Color(0.68, 0.52, 0.22)], ["focus", Color(1.0, 0.85, 0.47)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = state[1]
		style.border_color = Color(1.0, 0.95, 0.76)
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state[0], style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.08, 0.06, 0.03))
	return button


func _vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.72))
	gradient.add_point(0.55, Color(0, 0, 0, 0.1))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill = GradientTexture2D.FILL_RADIAL
	fill.fill_from = Vector2(0.5, 0.42)
	fill.fill_to = Vector2(1.05, 0.42)
	fill.width = 256
	fill.height = 144
	var rect := TextureRect.new()
	rect.texture = fill
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _portrait_of(c) -> Texture2D:
	var art: Texture2D = c.champion_texture
	if art == null:
		return HeroArt.texture_for(str(c.hero_key))
	var face := AtlasTexture.new()
	face.atlas = art
	face.region = Rect2(0, 0, art.get_width(), mini(art.get_width(), art.get_height()))
	return face


## Slowly turning light rays, gold wings and a gem behind the title.
class _Crest extends Control:
	const RAYS := 18
	var won := true
	var turn := 0.0

	func setup(result_won: bool) -> void:
		won = result_won
		queue_redraw()

	func spin(delta: float) -> void:
		turn += delta * (0.07 if won else 0.025)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var ray_color: Color = WIN_RAY if won else LOSS_RAY
		for i in range(RAYS):
			var angle := turn + TAU * i / RAYS
			var reach := 470.0 if i % 2 == 0 else 340.0
			var width := 0.07 if i % 2 == 0 else 0.045
			var tip := Vector2.from_angle(angle) * reach
			var left := Vector2.from_angle(angle - width) * 60.0
			var right := Vector2.from_angle(angle + width) * 60.0
			var points := PackedVector2Array([center + left, center + right, center + tip])
			var fade := Color(ray_color.r, ray_color.g, ray_color.b, 0.0)
			draw_polygon(points, PackedColorArray([Color(ray_color, 0.17), Color(ray_color, 0.17), fade]))
		var wing: Color = GOLD if won else Color(0.62, 0.6, 0.62)
		for side in [-1.0, 1.0]:
			for feather in range(5):
				var f := float(feather)
				var root := center + Vector2(side * (300.0 + f * 18.0), 44.0 - f * 13.0)
				var tip := center + Vector2(side * (440.0 + f * 28.0), -6.0 - f * 25.0)
				var belly := (root + tip) * 0.5 + Vector2(side * -8.0, 13.0)
				var shade := Color(wing, 0.92 - f * 0.13)
				draw_colored_polygon(PackedVector2Array([root, belly, tip, (root + tip) * 0.5 + Vector2(side * 8.0, -9.0)]), shade)
		var rule_y := center.y + 84.0
		for side in [-1.0, 1.0]:
			draw_line(center + Vector2(side * 26.0, 84.0), center + Vector2(side * 430.0, 84.0), Color(wing, 0.85), 2.0, true)
		_diamond(Vector2(center.x, rule_y), 11.0, wing)
		var gem: Color = Constants.TEAM_COLOR[Constants.BLUE] if won else LOSS_RAY
		_diamond(Vector2(center.x, center.y - 96.0), 19.0, wing)
		_diamond(Vector2(center.x, center.y - 96.0), 12.0, gem)

	func _diamond(at: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.72, 0), at + Vector2(0, r), at + Vector2(-r * 0.72, 0)]), color)
