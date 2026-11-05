extends Control
# HUD — all UI panels, built in code. Lives inside a CanvasLayer so it stays
# fixed on screen regardless of camera position.

var player = null
var root: Control
var top_bar: PanelContainer
var time_label: Label
var scoreboard: PanelContainer
var score_label: RichTextLabel
var wave_label: Label
var difficulty_label: Label

var status_tray: Control
var action_bar: Control
var action_content: Control
var inventory_grid: GridContainer
var shop_button: Button
var combat_stats: Label
var player_panel: PanelContainer
var player_name: Label
var player_level: Label
var player_sp_chip: PanelContainer
var player_sp_label: Label
var player_cs: Label
var player_gold: Label
var player_kda: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_text: Label
var mp_text: Label
var skill_slots: Array = []
var summoner_slots: Array = []

var blue_panel: VBoxContainer
var red_panel: VBoxContainer
var team_rows: Dictionary = {}  # champion -> row dict

var minimap: Control
var player_portrait: TextureRect
var minimap_timer: float = 0.0
var farming_label: Label

var announcement: PanelContainer
var announcement_title: Label
var announcement_hero: Label
var announcement_timer: float = 0
var kill_celebration
var kill_feed: VBoxContainer
var kill_feed_frame: Control
var tooltip_label: Label
var tooltip_panel: PanelContainer
var hovered_skill: int = -1

var side_tip: PanelContainer

var recall_bar: PanelContainer
var recall_fill: ProgressBar
var recall_label: Label

var death_overlay: Control
var death_timer_label: Label

var end_overlay: Control
var end_title: Label
var end_stats: Label

var flash_rect: ColorRect

# Shop & inventory
var inv_slots: Array = []     # Array of Dict { panel, icon_label }
var _xp_tooltip_key := Vector2i(-1, -1)        # refresh(): last XP tooltip inputs (perf)
var _combat_tooltip_key := Vector2(-1.0, -1.0)  # refresh(): last combat-stats tooltip inputs (perf)
var shop_panel: PanelContainer
var shop_open: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	root = self
	_build_top_bar()
	_build_team_panels()
	_build_bottom_hud()
	_build_minimap()
	_build_kill_feed()
	_build_announcement()
	_build_side_tip()
	_build_recall_bar()
	_build_death_overlay()
	_build_end_overlay()
	_build_flash_rect()
	_build_inventory_bar()
	_build_shop_panel()
	_build_skill_tooltip()
	farming_label = Label.new()
	farming_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	farming_label.position = Vector2(-300, -194)
	farming_label.size = Vector2(600,28)
	farming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	farming_label.add_theme_font_size_override("font_size",18)
	farming_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(farming_label)

func _build_skill_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.z_index = 200
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.anchor_left = 0.5
	tooltip_panel.anchor_right = 0.5
	tooltip_panel.anchor_top = 1
	tooltip_panel.anchor_bottom = 1
	tooltip_panel.position = Vector2(-240, -420)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.98)
	style.border_color = Color(0.9, 0.75, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(tooltip_panel)
	tooltip_label = Label.new()
	tooltip_label.custom_minimum_size.x = 620
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.add_theme_font_size_override("font_size", 18)
	tooltip_panel.add_child(tooltip_label)
	tooltip_panel.hide()

func show_skill_description(index: int) -> void:
	if player == null: return
	hovered_skill = index
	tooltip_label.text = ChampionData.skill_description(player.hero_key, index, player)
	tooltip_panel.show()
	_position_skill_tooltip()

func _position_skill_tooltip() -> void:
	tooltip_panel.size = Vector2(660,tooltip_panel.get_combined_minimum_size().y)
	tooltip_panel.offset_left = -330
	tooltip_panel.offset_right = 330
	tooltip_panel.offset_top = -174-tooltip_panel.size.y
	tooltip_panel.offset_bottom = -174

func hide_skill_description() -> void:
	hovered_skill = -1
	tooltip_panel.hide()

func hide_game_hud() -> void:
	top_bar.hide(); action_bar.hide(); farming_label.hide()
	blue_panel.hide(); red_panel.hide()
	minimap.hide(); kill_feed_frame.hide(); kill_feed.hide(); side_tip.hide()
	recall_bar.hide(); death_overlay.hide(); end_overlay.hide()
	flash_rect.hide()
	announcement.hide()
	set_scoreboard_visible(false)

func show_game_hud() -> void:
	top_bar.show(); action_bar.show()
	blue_panel.show(); red_panel.show()
	minimap.show(); kill_feed_frame.show(); kill_feed.show(); side_tip.show()
	flash_rect.show()

# ======================= Top Bar =======================
func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.1, 0.95)
	sb.border_color = Color(1.0, 0.86, 0.52, 0.5)
	sb.border_width_bottom = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 8
	sb.content_margin_left = 26; sb.content_margin_right = 26
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	top_bar.add_theme_stylebox_override("panel", sb)
	top_bar.anchor_left = 0.5; top_bar.anchor_right = 0.5
	top_bar.position = Vector2(-220, 0)
	top_bar.size = Vector2(440, 48)
	root.add_child(top_bar)

	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(h)

	time_label = Label.new()
	time_label.text = "00:00"
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	h.add_child(time_label)

	score_label = RichTextLabel.new()
	score_label.bbcode_enabled = true
	score_label.text = "[color=#4aaeff]0[/color]  ·  [color=#ff5a5a]0[/color]"
	score_label.custom_minimum_size = Vector2(100, 28)
	score_label.fit_content = true
	score_label.scroll_active = false
	h.add_child(score_label)
	score_label.tooltip_text = "Match scoreboard • hold Tab or click to toggle"
	score_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(scoreboard): set_scoreboard_visible(not scoreboard.visible))

	wave_label = Label.new()
	wave_label.text = "WAVE 0"
	difficulty_label = Label.new()
	difficulty_label.text = "PVP • "+("BLUE" if GameState.player!=null and GameState.player.team==0 else "RED") if GameState.is_pvp() else "N%d" % GameState.difficulty
	difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	h.add_child(difficulty_label)
	wave_label.add_theme_font_size_override("font_size", 11)
	wave_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	h.add_child(wave_label)

# ======================= Team Panels =======================
func _build_team_panels() -> void:
	blue_panel = VBoxContainer.new()
	blue_panel.add_theme_constant_override("separation", 6)
	blue_panel.position = Vector2(14, 72)
	blue_panel.custom_minimum_size = Vector2(220, 180)
	root.add_child(blue_panel)

	red_panel = VBoxContainer.new()
	red_panel.add_theme_constant_override("separation", 6)
	red_panel.anchor_left = 1; red_panel.anchor_right = 1
	red_panel.position = Vector2(-234, 72)
	red_panel.custom_minimum_size = Vector2(220, 180)
	root.add_child(red_panel)

func _create_team_row(c, is_blue: bool) -> PanelContainer:
	var row = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.11, 0.95)
	sb.border_color = Constants.TEAM_COLOR[c.team]
	sb.border_width_left = 4 if is_blue else 0
	sb.border_width_right = 0 if is_blue else 4
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 7; sb.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", sb)
	row.custom_minimum_size = Vector2(220, 54)

	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)

	var icon = TextureRect.new()
	var portrait = AtlasTexture.new()
	portrait.atlas = c.champion_texture
	portrait.region = Rect2(0, 0, c.champion_texture.get_width(), c.champion_texture.get_width())
	icon.texture = portrait
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	h.add_child(icon)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "%s  L%d" % [c.char_name, c.level]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color",
		Color(1, 0.86, 0.52) if c == player else Color.WHITE)
	vbox.add_child(name_label)

	var hp_rect = ProgressBar.new()
	hp_rect.show_percentage = false
	hp_rect.max_value = c.hp_max
	hp_rect.value = c.hp
	hp_rect.custom_minimum_size = Vector2(0, 5)
	var hp_sb = StyleBoxFlat.new()
	hp_sb.bg_color = Color(0.05, 0.07, 0.14)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.27, 1.0, 0.4)
	hp_rect.add_theme_stylebox_override("background", hp_sb)
	hp_rect.add_theme_stylebox_override("fill", hp_fill)
	vbox.add_child(hp_rect)

	var mp_rect = ProgressBar.new()
	mp_rect.show_percentage = false
	mp_rect.max_value = max(c.mp_max, 1)
	mp_rect.value = c.mp
	mp_rect.custom_minimum_size = Vector2(0, 4)
	var mp_sb = StyleBoxFlat.new()
	mp_sb.bg_color = Color(0.05, 0.07, 0.14)
	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.33, 0.67, 1.0)
	mp_rect.add_theme_stylebox_override("background", mp_sb)
	mp_rect.add_theme_stylebox_override("fill", mp_fill)
	vbox.add_child(mp_rect)

	return row

# ======================= Bottom HUD (Player panel + skillbar) =======================
func _hud_label(parent: Control, text: String, at: Vector2, dimensions: Vector2, font_size: int = 16) -> Label:
	var label = Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _hud_meter(at: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var meter = ProgressBar.new()
	meter.position = at
	meter.size = dimensions
	meter.show_percentage = false
	meter.add_theme_font_size_override("font_size",1)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = StyleBoxFlat.new()
	background.bg_color = Color("071017")
	background.border_color = Color("3c4a50")
	background.set_border_width_all(1)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	meter.add_theme_stylebox_override("background",background)
	meter.add_theme_stylebox_override("fill",fill)
	action_content.add_child(meter)
	meter.size = dimensions
	return meter

func _build_bottom_hud() -> void:
	# One shallow PC MOBA bar: stats / portrait / abilities / summoners / items.
	action_bar = Control.new()
	action_bar.name = "ActionBar"
	action_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	action_bar.position = Vector2(-470,-158)
	action_bar.size = Vector2(940,150)
	action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(action_bar)
	status_tray=preload("res://scripts/StatusTray.gd").new()
	status_tray.position=Vector2(240,-40);status_tray.size=Vector2(408,36)
	action_bar.add_child(status_tray)
	status_tray.hide()
	player_panel = PanelContainer.new()
	player_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color("08151d")
	frame.border_color = Color("8e8057")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	frame.shadow_size = 3
	frame.shadow_color = Color(0,0,0,0.5)
	frame.set_content_margin_all(0)
	player_panel.add_theme_stylebox_override("panel",frame)
	action_bar.add_child(player_panel)
	action_content = Control.new()
	action_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_panel.add_child(action_content)
	combat_stats = _hud_label(action_content,"",Vector2(12,20),Vector2(110,98),16)
	combat_stats.add_theme_color_override("font_color",Color("b6c5ca"))
	player_cs = _hud_label(action_content,"CS 0",Vector2(12,119),Vector2(70,24),15)
	player_kda = _hud_label(action_content,"0/0/0",Vector2(86,119),Vector2(116,24),15)
	player_name = _hud_label(action_content,"Hero",Vector2(128,5),Vector2(90,20),15)
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_portrait = TextureRect.new()
	player_portrait.position = Vector2(130,28)
	player_portrait.size = Vector2(82,82)
	player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	player_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_content.add_child(player_portrait)
	var passive_hint=_hud_label(action_content,"P • PASSIVE",Vector2(125,113),Vector2(100,17),10);passive_hint.name="PassiveCounter";passive_hint.clip_text=true;passive_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;passive_hint.add_theme_color_override("font_color",Color("d8bb83"))
	player_level = _hud_label(action_content,"3",Vector2(187,87),Vector2(26,24),18)
	player_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_level.add_theme_color_override("font_color",Color("f5d78a"))
	player_sp_chip = PanelContainer.new()
	player_sp_chip.position = Vector2(230,-25)
	player_sp_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip = StyleBoxFlat.new()
	chip.bg_color = Color("59451c")
	chip.set_content_margin_all(3)
	player_sp_chip.add_theme_stylebox_override("panel",chip)
	player_sp_label = Label.new()
	player_sp_label.add_theme_font_size_override("font_size",16)
	player_sp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_sp_chip.add_child(player_sp_label)
	action_content.add_child(player_sp_chip)
	player_sp_chip.hide()
	for i in range(4):
		var slot = load("res://scripts/SkillSlot.gd").new()
		slot.position = Vector2(230+i*82,20)
		action_content.add_child(slot)
		skill_slots.append(slot)
	for i in range(2):
		var slot = _make_slot("D" if i == 0 else "F","",50)
		slot.panel.position = Vector2(568+i*56,20)
		action_content.add_child(slot.panel)
		summoner_slots.append(slot)
	var recall = Button.new()
	recall.text = "B"
	recall.position = Vector2(684,20)
	recall.size = Vector2(32,50)
	recall.focus_mode = Control.FOCUS_NONE
	recall.tooltip_text = "Recall [B] • return to the fountain in 1 second"
	recall.pressed.connect(func():
		if player != null and not GameState.paused: player.start_recall())
	action_content.add_child(recall)
	hp_bar = _hud_meter(Vector2(230,104),Vector2(486,20),Color("3d994e"))
	mp_bar = _hud_meter(Vector2(230,126),Vector2(486,16),Color("277ba9"))
	xp_bar = _hud_meter(Vector2(130,113),Vector2(82,5),Color("b9964f"))
	hp_text = _hud_label(hp_bar,"",Vector2.ZERO,Vector2(486,20),14)
	mp_text = _hud_label(mp_bar,"",Vector2.ZERO,Vector2(486,16),13)
	for text in [hp_text,mp_text]:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_constant_override("outline_size",2)
		text.add_theme_color_override("font_outline_color",Color.BLACK)

func _make_slot(key: String, _title: String, sz: float, _is_skill: bool = false) -> Dictionary:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(sz,sz)
	panel.size = Vector2(sz,sz)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("071017")
	style.border_color = Color("8e8057")
	style.set_border_width_all(2)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel",style)
	var inner = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var icon = TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)
	var label = _hud_label(inner,key,Vector2(2,0),Vector2(20,18),14)
	label.add_theme_constant_override("outline_size",3)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	var cd = _hud_label(inner,"",Vector2.ZERO,Vector2(sz-4,sz-4),22)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_constant_override("outline_size",4)
	cd.add_theme_color_override("font_outline_color",Color.BLACK)
	cd.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not GameState.paused:
			get_tree().call_group("game_main","_player_cast_summoner",0 if key == "D" else 1))
	return {"panel":panel,"icon":icon,"cd":cd,"label":label}

# ======================= Minimap =======================
func _build_minimap() -> void:
	minimap = load("res://scripts/RiftMinimap.gd").new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position = Vector2(-334, -196)
	minimap.custom_minimum_size = Vector2(320, 170)
	minimap.size = Vector2(320, 170)
	root.add_child(minimap)
func _draw_minimap() -> void:
	minimap.player = player
	minimap.queue_redraw()

# ======================= Kill feed =======================
func _build_kill_feed() -> void:
	kill_feed_frame=Control.new()
	kill_feed_frame.name="KillFeedFrame"
	kill_feed_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(kill_feed_frame)
	kill_feed_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_frame.offset_left=-374;kill_feed_frame.offset_right=-18
	kill_feed_frame.offset_top=290;kill_feed_frame.offset_bottom=500
	kill_feed_frame.clip_contents=true
	kill_feed=VBoxContainer.new()
	kill_feed.name="KillFeedEntries"
	kill_feed.mouse_filter=Control.MOUSE_FILTER_IGNORE
	kill_feed.add_theme_constant_override("separation",4)
	kill_feed.alignment=BoxContainer.ALIGNMENT_BEGIN
	kill_feed_frame.add_child(kill_feed)
	kill_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_announcement() -> void:
	announcement = PanelContainer.new()
	announcement.set_anchors_preset(Control.PRESET_CENTER_TOP)
	announcement.position = Vector2(-310,105)
	announcement.custom_minimum_size = Vector2(620,190)
	announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announcement.z_index = 80
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	style.border_color = Color("b69d62")
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.set_content_margin_all(8)
	announcement.add_theme_stylebox_override("panel",style)
	add_child(announcement)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announcement.add_child(column)
	announcement_title = Label.new()
	announcement_title.add_theme_font_size_override("font_size",30)
	announcement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(announcement_title)
	announcement_hero = Label.new()
	announcement_hero.add_theme_font_size_override("font_size",17)
	announcement_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(announcement_hero)
	column.hide()
	kill_celebration=load("res://scripts/KillCelebration.gd").new()
	announcement.add_child(kill_celebration)
	announcement.hide()

func show_announcement(title: String, hero_name: String, team: int) -> void:
	announcement_title.text = title
	announcement_title.add_theme_color_override("font_color",Color("e4cb8a"))
	announcement_hero.text = hero_name
	announcement_hero.add_theme_color_override("font_color",Constants.TEAM_COLOR[team])
	kill_celebration.play(title,hero_name,team)
	announcement_timer = kill_celebration.duration
	announcement.show()

func log_kill(killer, victim) -> void:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("0c1620")
	sb.border_color=Color("796544")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.clip_contents=true
	panel.custom_minimum_size=Vector2(0,36)
	var killer_name = "Execution"
	var killer_col = "#ffdb85"
	if killer != null:
		if "char_name" in killer:
			killer_name = killer.char_name
			killer_col = "#8cc8e6" if killer.team == Constants.BLUE else "#e78f80"
		elif "kind" in killer and killer.kind == "minion":
			killer_name = "A minion"
			killer_col = "#8cc8e6" if killer.team == Constants.BLUE else "#e78f80"
		elif "kind" in killer and killer.kind == "structure":
			killer_name = "Turret"
			killer_col = "#8cc8e6" if killer.team == Constants.BLUE else "#e78f80"
	var victim_col = "#8cc8e6" if victim.team == Constants.BLUE else "#e78f80"
	var row=HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	for index in range(3):
		var label=Label.new()
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.text=killer_name if index==0 else "⚔" if index==1 else victim.char_name
		label.add_theme_font_size_override("font_size",17)
		label.add_theme_font_override("font",CombatFeedbackArt.font())
		label.add_theme_color_override("font_color",Color(killer_col if index==0 else "#e2c885" if index==1 else victim_col))
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if index!=1:
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			label.clip_text=true
		row.add_child(label)
	while kill_feed.get_child_count()>=5:
		var oldest=kill_feed.get_child(0)
		kill_feed.remove_child(oldest);oldest.queue_free()
	kill_feed.add_child(panel)
	# Auto remove after 4s
	var timer = Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	panel.add_child(timer)
	timer.timeout.connect(panel.queue_free)
	timer.start()

# ======================= Side tip (controls) =======================
func _build_side_tip() -> void:
	side_tip = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.1, 0.75)
	sb.border_color = Color(0.3, 0.4, 0.6, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	side_tip.add_theme_stylebox_override("panel", sb)
	side_tip.position = Vector2(240, 72)
	side_tip.custom_minimum_size = Vector2(170, 180)

	var rt = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = "[color=#ffdb85][b]CONTROLS[/b][/color]
[b]Right-click[/b] move/attack
[b]Q W E R[/b] skills (cursor)
[b]Ctrl+QWER[/b] or [b]+[/b] level up
[b]P[/b] open shop  [b]R-click[/b] sell
[b]D[/b] Flash  [b]F[/b] Ignite
[b]A[/b]+click attack-move
[b]A + click[/b] attack / last hit
[b]Shift+A[/b] quick attack move
[b]S[/b] stop  [b]B[/b] recall / cancel
[b]Space[/b] center cam
[b]Y[/b] toggle cam lock
[b]Arrows/edges[/b] pan when unlocked"
	side_tip.add_child(rt)
	root.add_child(side_tip)

# ======================= Recall bar =======================
func _build_recall_bar() -> void:
	recall_bar = PanelContainer.new()
	recall_bar.anchor_left = 0.5; recall_bar.anchor_right = 0.5
	recall_bar.anchor_top = 1; recall_bar.anchor_bottom = 1
	recall_bar.position = Vector2(-140, -222)
	recall_bar.custom_minimum_size = Vector2(280, 20)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.14, 0.9)
	sb.border_color = Color(1.0, 0.86, 0.52)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	recall_bar.add_theme_stylebox_override("panel", sb)
	recall_bar.hide()
	root.add_child(recall_bar)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	recall_bar.add_child(box)
	recall_label = Label.new()
	recall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recall_label.add_theme_font_size_override("font_size", 18)
	box.add_child(recall_label)
	recall_fill = ProgressBar.new()
	recall_fill.custom_minimum_size = Vector2(276, 12)
	recall_fill.show_percentage = false
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.8, 1)
	recall_fill.add_theme_stylebox_override("fill", fill_style)
	box.add_child(recall_fill)

# ======================= Death overlay =======================
func _build_death_overlay() -> void:
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.4, 0, 0, 0.35)
	death_overlay.anchor_right = 1; death_overlay.anchor_bottom = 1
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.hide()
	root.add_child(death_overlay)

	var v = VBoxContainer.new()
	v.anchor_left = 0.5; v.anchor_top = 0.5
	v.anchor_right = 0.5; v.anchor_bottom = 0.5
	v.position = Vector2(-150, -100)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	death_overlay.add_child(v)

	var h2 = Label.new()
	h2.text = "YOU DIED"
	h2.add_theme_font_size_override("font_size", 50)
	h2.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	h2.add_theme_color_override("font_outline_color", Color(0.3, 0, 0))
	h2.add_theme_constant_override("outline_size", 10)
	h2.custom_minimum_size = Vector2(300, 70)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h2)

	death_timer_label = Label.new()
	death_timer_label.text = "0"
	death_timer_label.add_theme_font_size_override("font_size", 72)
	death_timer_label.add_theme_color_override("font_color", Color.WHITE)
	death_timer_label.add_theme_color_override("font_outline_color", Color(0.3, 0, 0))
	death_timer_label.add_theme_constant_override("outline_size", 8)
	death_timer_label.custom_minimum_size = Vector2(300, 80)
	death_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(death_timer_label)

func show_death_overlay() -> void:
	death_overlay.show()

func hide_death_overlay() -> void:
	death_overlay.hide()

# ======================= End overlay =======================
func _build_end_overlay() -> void:
	end_overlay = EndScreen.new()
	end_overlay.hide()
	root.add_child(end_overlay)
	end_title = end_overlay.title
	end_stats = end_overlay.stats

func show_end_screen(won: bool) -> void:
	announcement.hide()
	set_scoreboard_visible(false)
	end_stats.text = ""
	root.move_child(end_overlay, -1)
	end_overlay.present(won, GameState.player, GameState.time)

# ======================= Flash =======================
func _build_flash_rect() -> void:
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.anchor_right = 1; flash_rect.anchor_bottom = 1
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

var flash_duration: float = 0.0
var flash_elapsed: float = 0.0
var flash_color: Color = Color(1,1,1,0)
func flash(duration: float, color: Color) -> void:
	flash_duration = duration
	flash_elapsed = 0.0
	flash_color = color
	flash_rect.color = Color(color.r, color.g, color.b, 0.5)

# ======================= Entry: build for player =======================
func build_for_player(c) -> void:
	player = c
	var portrait = AtlasTexture.new()
	portrait.atlas = c.champion_texture
	portrait.region = Rect2(0, 0, c.champion_texture.get_width(), c.champion_texture.get_width())
	player_portrait.texture = portrait
	player_portrait.mouse_filter=Control.MOUSE_FILTER_STOP
	if not player_portrait.mouse_entered.is_connected(show_passive_description):player_portrait.mouse_entered.connect(show_passive_description);player_portrait.mouse_exited.connect(hide_skill_description)
	difficulty_label.text = "PVP • "+("BLUE" if GameState.player!=null and GameState.player.team==0 else "RED") if GameState.is_pvp() else "N%d" % GameState.difficulty
	player_name.text = c.hero.name
	# Configure SkillSlot widgets with hero data and wire interactions
	for i in range(4):
		var idx = i  # capture
		var slot: SkillSlot = skill_slots[i]
		slot.set_data(idx, c.hero, c.hero_key)
		slot.upgrade_requested.connect(func():
			if player == null or GameState.paused: return
			player.try_level_skill(idx)
			refresh(0)
		)
		slot.clicked.connect(func():
			if player == null or GameState.paused: return
			if not Progression.smart_cast:
				get_tree().call_group("game_main","_player_cast_skill",idx)
				return
			var target = GameState.find_nearest_enemy(player, player.world_pos(), max(500, player.hero.skills[idx].range))
			player.try_cast_skill(idx, target.world_pos() if target != null else player.world_pos() + player.facing * 300)
		)
		slot.hover_entered.connect(func():
			show_skill_description(idx)
			get_tree().call_group("game_main", "set_aiming_skill", idx)
		)
		slot.hover_exited.connect(func():
			hide_skill_description()
			get_tree().call_group("game_main", "clear_aiming_skill")
		)
	scoreboard = load("res://scripts/MatchScoreboard.gd").new()
	add_child(scoreboard)
	scoreboard.close_requested.connect(func(): set_scoreboard_visible(false))
	scoreboard.hide()
	# Build team rows
	for ch in GameState.champions:
		var row = _create_team_row(ch, ch.team == player.team)
		if ch.team == player.team: blue_panel.add_child(row)
		else: red_panel.add_child(row)
		row.visible = ch.roster_active
		team_rows[ch] = row

func set_scoreboard_visible(enabled: bool) -> void:
	if not is_instance_valid(scoreboard): return
	if enabled and not GameState.running: return
	scoreboard.visible = enabled
	if enabled:
		hide_skill_description()
		scoreboard.refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(scoreboard): scoreboard.hide()

# ======================= Refresh (called each frame) =======================
func refresh(delta: float) -> void:
	if hovered_skill==-2 and player!=null:tooltip_label.text=HeroPassives.description(player.hero_key,player);_position_skill_tooltip()
	if hovered_skill >= 0 and player != null:
		tooltip_label.text = ChampionData.skill_description(player.hero_key, hovered_skill, player)
		_position_skill_tooltip()
	if player == null: return
	status_tray.unit=player
	var counter=action_content.get_node_or_null("PassiveCounter")
	if counter!=null:
		var text=HeroPassives.state_text(player);counter.text="P • "+text.split(" • ")[0] if text!="Active from level 1" else "P • PASSIVE"
	announcement_timer = maxf(0,announcement_timer-delta)
	if announcement_timer <= 0: announcement.hide()
	if is_instance_valid(scoreboard) and scoreboard.visible: scoreboard.refresh()

	# Flash fade
	if flash_duration > 0:
		flash_elapsed += delta
		var a = max(0.0, 0.5 * (1.0 - flash_elapsed / flash_duration))
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, a)
		if flash_elapsed >= flash_duration:
			flash_duration = 0.0
			flash_rect.color = Color(0,0,0,0)

	# Top bar
	var mm = int(GameState.time / 60.0)
	var ss = int(GameState.time) % 60
	time_label.text = "%02d:%02d" % [mm, ss]
	score_label.text = "[color=#4aaeff]%d[/color]  ·  [color=#ff5a5a]%d[/color]" % \
		[GameState.score[Constants.BLUE], GameState.score[Constants.RED]]
	wave_label.text = "WAVE %d" % GameState.wave_num

	# Player panel
	player_level.text = str(player.level)
	player_cs.text = "CS %d" % player.cs
	player_gold.text = "%dg  [P]" % int(player.gold)
	combat_stats.text = "AD  %d   AP  %d\nAS  %.2f\nARM %d  MR %d\nMS  %d" % [int(player.ad),int(player.bonus_ap),player.effective_atk_spd(),int(ExpansionCombat.resist(player,null,"auto")),int(ExpansionCombat.resist(player,null,"magic")),int(player.effective_move_speed())]
	var cs_key := Vector2(player.bonus_heal_power, player.mp_regen)
	if cs_key != _combat_tooltip_key:
		_combat_tooltip_key = cs_key
		combat_stats.tooltip_text = "Heal / shield power: +%.0f%%\nMana regeneration: %.1f per second\nHealing reduction and healing received apply after outgoing power." % [player.bonus_heal_power*100.,player.mp_regen]
	player_kda.text = "%d/%d/%d" % [player.kills, player.deaths, player.assists]
	# Skill point chip
	if player.skill_points > 0:
		player_sp_chip.visible = true
		player_sp_label.text = "+%d SP" % player.skill_points
		var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		player_sp_chip.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.3, 0.8), pulse)
	else:
		player_sp_chip.visible = false
	hp_bar.max_value = player.hp_max
	hp_bar.value = player.hp
	# One assignment per label per frame: a base text then a suffix re-shaped the label twice every frame.
	var hp_line = "%d / %d" % [int(ceil(player.hp)), int(ceil(player.hp_max))]
	if player.shield > 0: hp_line += "  +%d" % int(player.shield)
	hp_text.text = hp_line
	if player.hero_key=="renekton":
		mp_bar.max_value=100.;mp_bar.value=player.buffs.get("fury",{}).get("value",0.);mp_text.text="%d / 100 FURY" % int(mp_bar.value)
	elif player.mp_max > 0:
		mp_bar.max_value = player.mp_max
		mp_bar.value = player.mp
		mp_text.text = ("Energy " if player.hero_key in ["leesin","zed"] else "")+"%d / %d" % [int(ceil(player.mp)), int(ceil(player.mp_max))]
	else:
		mp_bar.value = 0
		mp_text.text = "— NO MANA —"
	xp_bar.max_value = Constants.xp_to_level(player.level)
	xp_bar.value = xp_bar.max_value if player.level>=Constants.MAX_LEVEL else player.xp
	farming_label.visible = GameState.attack_move_pending and GameState.running
	farming_label.text = "ATTACK MOVE • Left-click near your creep target • S cancels"
	if GameState.attack_move_pending: farming_label.text = "ATTACK MOVE • Left-click near your creep target • S cancels"

	# Skill slots — new widget encapsulates all state
	for i in range(4):
		var slot: SkillSlot = skill_slots[i]
		slot.set_state(player)

	# Summoner slots
	for i in range(2):
		var slot = summoner_slots[i]
		# Perf: icon (a new AtlasTexture per call), label and tooltip only change with the spell.
		var spell_key = player.summoner_spells[i]
		if slot.get("spell_key") != spell_key:
			var spell = SummonerData.SPELLS[spell_key]
			slot["spell_key"] = spell_key
			slot["icon"].texture = ShopArt.icon_for(spell.art)
			slot["label"].text = ("D" if i == 0 else "F")
			slot["panel"].tooltip_text = spell.desc + " • %ds cooldown" % spell.cd
		if player.summoner_cds[i] > 0:
			slot["cd"].visible = true
			slot["cd"].text = "%d" % int(ceil(player.summoner_cds[i]))
			slot["icon"].modulate = Color(0.35, 0.4, 0.45)
		else:
			slot["cd"].visible = false
			slot["icon"].modulate = Color.WHITE

	# Death overlay timer
	if player.dead:
		death_timer_label.text = str(int(ceil(player.respawn_at - GameState.time)))
	# Team rows
	for ch in GameState.champions:
		var row = team_rows.get(ch, null)
		if row == null: continue
		row.visible = ch.roster_active
		if not ch.roster_active: continue
		var vb = row.get_child(0).get_child(1)
		var hidden = not ch.dead and not BrushVision.visible_to(ch,player.team)
		vb.get_child(0).text = ch.char_name + "  HIDDEN" if hidden else "%s  L%d%s" % [ch.char_name, ch.level, "  💀" if ch.dead else ""]
		var hp_r = vb.get_child(1)
		hp_r.max_value = ch.hp_max
		hp_r.value = ch.hp
		var mp_r = vb.get_child(2)
		mp_r.max_value = max(ch.mp_max, 1)
		mp_r.value = ch.mp
		hp_r.visible = not hidden
		mp_r.visible = not hidden
		row.modulate = Color(1,1,1,0.45) if ch.dead else Color(1,1,1,1)

	# Recall bar
	if player.recall_time >= 0 and not player.dead:
		recall_bar.show()
		recall_fill.max_value = player.recall_duration
		recall_fill.value = player.recall_time
		recall_label.text = "RECALLING  %.1fs" % maxf(0, player.recall_duration - player.recall_time)
	else:
		recall_bar.hide()

	# Minimap (throttled)
	minimap_timer += delta
	if minimap_timer > 0.1:
		minimap_timer = 0
		_draw_minimap()

	if shop_open: shop_panel.refresh_shop()
	# Perf: the XP tooltip only changes with whole XP points and the level.
	var xp_key := Vector2i(int(player.xp), int(player.level))
	if xp_key != _xp_tooltip_key:
		_xp_tooltip_key = xp_key
		xp_bar.tooltip_text = "XP %d / %d • +%.1f XP/sec while alive • soak within 650 range\nLast hits grant 25%% extra minion XP and normal last-hit gold\nBuild upgrades at levels 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18\nLevel cap 100 · After earning all skill points: +3 AD / +5 AP / +45 HP / +25 mana per level" % [player.xp, Constants.xp_to_level(player.level), Constants.PASSIVE_XP]
		if player.level>=Constants.MAX_LEVEL:xp_bar.tooltip_text="LEVEL 100 · MAX LEVEL\nVeteran stats stay for this match, including after death."
	# Inventory slots. Perf: the icon (a new AtlasTexture per call) and tooltip only change with the item id and, for
	# consumables, the purchase counts, so they are rebuilt only then.
	for i in range(6):
		var inv = inv_slots[i]
		var id = player.inventory[i]
		if inv.get("item_id") == id and (id == "" or inv.get("item_counts") == player.consumable_counts):
			continue
		inv["item_id"] = id
		inv["item_counts"] = player.consumable_counts.duplicate(true)
		if id == "":
			inv["icon"].texture = null
			# No hover card for an empty slot: ItemHover skips an empty tooltip. A resting cursor over the item grid
			# used to open a 590 px "Empty item slot" card over the minimap. A card already open for this slot
			# (its item was just sold or used up) is closed rather than left showing an empty panel.
			inv["panel"].tooltip_text = ""
			_close_item_hover(inv["panel"])
			inv["panel"].modulate = Color(0.6, 0.65, 0.75)
		else:
			inv["icon"].texture = ShopArt.item_icon(id)
			inv["panel"].tooltip_text = ItemData.item_tooltip(id,player.consumable_counts)
			inv["panel"].modulate = Color(1, 1, 1)

func _close_item_hover(slot: Control) -> void:
	var hover = get_tree().root.get_node_or_null("ItemHover") if is_inside_tree() else null
	if hover != null and hover.get("watched") == slot:
		hover.hide_hover()

# ======================= Inventory bar =======================
func _build_inventory_bar() -> void:
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = 3
	inventory_grid.position = Vector2(734,12)
	inventory_grid.add_theme_constant_override("h_separation",4)
	inventory_grid.add_theme_constant_override("v_separation",4)
	action_content.add_child(inventory_grid)
	for i in range(6):
		var slot_idx = i
		var panel = load("res://scripts/ItemSlot.gd").new()
		panel.custom_minimum_size = Vector2(50,50)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var style = StyleBoxFlat.new()
		style.bg_color = Color("0b2029")
		style.border_color = Color("62634c")
		style.set_border_width_all(1)
		style.set_content_margin_all(2)
		panel.add_theme_stylebox_override("panel",style)
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and player != null and player.inventory[slot_idx] != "":
				shop_open = true; shop_panel.player = player; shop_panel.show(); hide_skill_description(); shop_panel.view_upgrades(player.inventory[slot_idx])
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and player != null and not GameState.paused:
				player.try_sell_item(slot_idx))
		inventory_grid.add_child(panel)
		inv_slots.append({"panel":panel,"icon":icon})
	shop_button = Button.new()
	shop_button.name = "ShopGold"
	shop_button.tooltip_text = "+%.1f gold/sec • Last-hit minions for gold\nHero kill: %dg • Assist: %dg\n[P] Open shop" % [Constants.PASSIVE_GOLD, Constants.HERO_KILL_GOLD, CombatParticipation.ASSIST_GOLD]
	shop_button.position = Vector2(734,122)
	shop_button.size = Vector2(158,24)
	shop_button.focus_mode = Control.FOCUS_NONE
	shop_button.tooltip_text = "Open item shop [P]"
	shop_button.pressed.connect(toggle_shop)
	action_content.add_child(shop_button)
	player_gold = _hud_label(shop_button,"500g  [P]",Vector2.ZERO,Vector2(158,24),17)
	player_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_gold.add_theme_color_override("font_color",Color("e3c67e"))

# ======================= Shop panel =======================
func _build_shop_panel() -> void:
	shop_panel = load("res://scripts/ARAMShop.gd").new()
	root.add_child(shop_panel)
	shop_panel.close_requested.connect(close_shop)
	shop_panel.hide()

func toggle_shop() -> void:
	shop_open = not shop_open
	shop_panel.visible = shop_open
	shop_panel.player = player
	if shop_open:
		hide_skill_description()
		shop_panel.rebuild_catalog()

func close_shop() -> void:
	shop_open = false
	shop_panel.visible = false

func show_passive_description() -> void:
	if player==null:return
	hovered_skill=-2;tooltip_label.text=HeroPassives.description(player.hero_key,player);tooltip_panel.show();_position_skill_tooltip()
