extends Node2D
# Main.gd — orchestrator. Boots champion select, then runs the match.

const BLUE = 0
const RED = 1

# ----- Preloads -----
const ChampionS   = preload("res://scripts/Champion.gd")
const MinionS     = preload("res://scripts/Minion.gd")
const StructureS  = preload("res://scripts/Structure.gd")
const ProjectileS = preload("res://scripts/Projectile.gd")
const AoES        = preload("res://scripts/AoE.gd")
const FloatingTextS = preload("res://scripts/FloatingText.gd")
const MapRendererS  = preload("res://scripts/MapRenderer.gd")
const HUDS          = preload("res://scripts/HUD.gd")
const SkillAimerS   = preload("res://scripts/SkillAimer.gd")

# ----- Scene nodes -----
var camera: Camera2D
var map_renderer: Node2D
var world_root: Node2D
var hud: CanvasLayer
var menu: CanvasLayer
var skill_aimer: Node2D
var reticle_node: Node2D

# ----- Input state -----
var attack_move_pending: bool = false:
	set(value):
		attack_move_pending = value
		GameState.attack_move_pending = value
var mouse_world: Vector2 = Vector2.ZERO
var view3d: View3D = null
var camera_shake_offset: Vector2 = Vector2.ZERO
var pending_skill: int = -1
var cam_shake_t: float = 0.0
var cam_shake_amp: float = 0.0
var cam_shake_duration: float = 0.0
var selected_hero: String = "ashe"
var hero_cards: Dictionary = {}
var selected_summoners: Array = ["flash", "ignite"]
var launch_button: Button
var summoner_selectors: Array = []
var lane_augments: Node
var economy_timer: float = 0.0
var music: Node
var sound_fx: Node
var in_game_menu: CanvasLayer
var menu_was_paused: bool = false
var menu_page: String = "main"
var menu_status: Label
var lobby_roster: Label
var lobby_start: Button
var lobby_team: OptionButton
var lobby_ready: Button
var lobby_hint: Label
var lobby_size: OptionButton
var lobby_bots: CheckButton
var lobby_team_rosters: Array=[]
var last_lan_address: String = ""
var network_config: Dictionary = {}
var graphics_quality: CanvasLayer
var kill_announcer
var match_loader: MatchLoading
var match_load_serial: int = 0
var archive_report: String = ""
var force_match_loading: bool = false # Native loading path can also run in headless integration tests.

func _ready() -> void:
	Input.use_accumulated_input = false
	if get_tree().current_scene == self: Progression.load_profile()
	set_fullscreen(Progression.fullscreen_enabled, false)
	add_to_group("game_main")
	kill_announcer = load("res://scripts/KillAnnouncer.gd").new()
	kill_announcer.main = self
	add_child(kill_announcer)
	sound_fx = load("res://scripts/SoundFX.gd").new()
	add_child(sound_fx)
	music = preload("res://scripts/MusicDirector.gd").new()
	music.name = "MusicDirector"
	music.main = self
	add_child(music)
	world_root = Node2D.new()
	world_root.name = "World"
	world_root.y_sort_enabled = true
	add_child(world_root)

	map_renderer = MapRendererS.new()
	map_renderer.name = "Map"
	world_root.add_child(map_renderer)

	# Skill range indicator overlay
	skill_aimer = SkillAimerS.new()
	skill_aimer.name = "SkillAimer"
	world_root.add_child(skill_aimer)

	# Reticle layer (hover / attack-target)
	reticle_node = _ReticleLayer.new()
	reticle_node.name = "Reticles"
	reticle_node.main = self
	reticle_node.z_index = Constants.Z_FX
	world_root.add_child(reticle_node)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2.ONE * Constants.BATTLE_CAMERA_ZOOM
	camera.position = Constants.FOUNT_B
	camera.limit_left = -2000
	camera.limit_right = int(Constants.WORLD_W) + 2000
	camera.limit_top = -2000
	camera.limit_bottom = int(Constants.WORLD_H) + 2000
	add_child(camera)
	camera.make_current()
	ViewConfig.configure()
	if ViewConfig.enabled:
		view3d = View3D.new(); view3d.name = "View3D"; add_child(view3d); view3d.setup(self)

	graphics_quality = preload("res://scripts/GraphicsQuality.gd").new()
	add_child(graphics_quality)

	# HUD overlay
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	var hud_node = HUDS.new()
	hud_node.name = "HudRoot"
	hud.add_child(hud_node)
	add_child(hud)
	hud_node.hide_game_hud()
	hud_node.hide()

	var cursor = preload("res://scripts/MobaCursor.gd").new()
	cursor.name = "MobaCursor"
	cursor.main = self
	add_child(cursor)
	_add_version_label()
	LanSession.main = self
	_show_main_menu()

func _add_version_label() -> void:
	var overlay = CanvasLayer.new()
	overlay.name = "VersionOverlay"
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label = Label.new()
	label.name = "VersionLabel"
	label.text = "v%s" % GameUpdates.current
	var refresh_version=func():
		label.text="v"+GameUpdates.current+(" • Update v"+GameUpdates.latest if GameUpdates.phase in ["available","downloading","ready"] else " • Latest" if GameUpdates.phase=="current" and GameUpdates.latest==GameUpdates.current else "")
	GameUpdates.changed.connect(refresh_version)
	label.tree_exiting.connect(func():GameUpdates.changed.disconnect(refresh_version))
	refresh_version.call()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.81))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -340
	label.offset_right = -14
	label.offset_top = -21
	label.offset_bottom = -2

# =============================================================================
# MENU: Champion Select (built with Godot Control nodes)
# =============================================================================
func _show_menu() -> void:
	if LanSession.active: LanSession.ready_player(selected_hero,selected_summoners,Progression.bonuses(),false)
	hero_cards.clear()
	summoner_selectors.clear()
	var root = RiftMenus.backdrop(self,"heroes")
	var title = Label.new()
	title.text = "CHOOSE YOUR HERO"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	title.add_theme_color_override("font_outline_color", Color(0.5, 0.3, 0.1))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.5; title.anchor_right = 0.5
	title.position = Vector2(-600, 140)
	title.size = Vector2(1200, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "%d HEROES • SCROLL TO SEE ALL • CHOOSE TWO SUMMONERS • ARAM PvE" % ChampionData.CHAMPIONS.size()
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.54, 0.63, 0.72))
	subtitle.anchor_left = 0.5; subtitle.anchor_right = 0.5
	subtitle.position = Vector2(-500, 240)
	subtitle.size = Vector2(1000, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	var hero_scroll = ScrollContainer.new()
	hero_scroll.position=Vector2(150,300);hero_scroll.size=Vector2(1635,560)
	hero_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(hero_scroll)
	var hbox = GridContainer.new()
	hbox.columns = 6
	hbox.anchor_left = 0.5; hbox.anchor_top = 0.5
	hbox.anchor_right = 0.5; hbox.anchor_bottom = 0.5
	hbox.position = Vector2.ZERO
	hbox.size = Vector2(1620, 600)
	hbox.add_theme_constant_override("h_separation", 12)
	hbox.add_theme_constant_override("v_separation", 16)
	hero_scroll.add_child(hbox)

	var keys = ChampionData.CHAMPIONS.keys()
	for key in keys:
		var card = _make_champion_card(key)
		hbox.add_child(card)

	var tip = Label.new()
	tip.text = "Right-click move / attack • Q W E R skills • P shop • B recall • U augments • Destroy their nexus"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	tip.anchor_left = 0.5; tip.anchor_right = 0.5
	tip.anchor_top = 1; tip.anchor_bottom = 1
	tip.position = Vector2(-550, -24)
	tip.size = Vector2(1100, 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tip)
	var back = Button.new()
	back.text = "BACK [ESC]"
	back.position = Vector2(24,160)
	back.custom_minimum_size = Vector2(200,56)
	back.pressed.connect(_back_from_heroes)
	root.add_child(back)
	_build_summoner_select(root)
	_build_progression_menu(root)
	_select_hero(selected_hero)

func _make_champion_card(hero_key: String) -> PanelContainer:
	var H = ChampionData.CHAMPIONS[hero_key]
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 280)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.1, 0.19, 0.95)
	sb.border_color = Color(H.color.r, H.color.g, H.color.b, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_hero(hero_key)
	)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(v)

	# All thirty portraits share the same clipped square and external frame.
	var portrait = Control.new()
	portrait.custom_minimum_size = Vector2(0, 94)
	portrait.clip_contents=true
	v.add_child(portrait)
	var pdraw = _CardPortraitDraw.new()
	pdraw.hero_color = H.color
	pdraw.hero_trim = H.trim
	pdraw.icon_text = H.icon
	pdraw.texture = HeroArt.texture_for(hero_key)
	pdraw.anchor_right = 1; pdraw.anchor_bottom = 1
	portrait.add_child(pdraw)
	var nm = Label.new()
	nm.text = H.name
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)

	var tt = Label.new()
	tt.text = H.title
	tt.add_theme_font_size_override("font_size", 11)
	tt.add_theme_color_override("font_color", Color(0.6, 0.72, 0.88))
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tt)

	var hpM = Label.new()
	hpM.text = "HP %d · AD %d · Range %d" % [int(H.hp), int(H.ad), int(H.atk_range)]
	hpM.add_theme_font_size_override("font_size", 11)
	hpM.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hpM.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hpM)
	var passive=Label.new();passive.text="P • "+HeroPassives.DATA[hero_key][0];passive.tooltip_text=HeroPassives.description(hero_key);passive.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;passive.add_theme_font_size_override("font_size",12);passive.add_theme_color_override("font_color",Color("d8bb83"));v.add_child(passive)

	# Skills row
	var sh = HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 6)
	v.add_child(sh)
	for index in range(4):
		var sl = TextureRect.new()
		sl.texture = AbilityArt.icon_for(hero_key, index)
		sl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sl.custom_minimum_size = Vector2(32, 32)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.add_child(sl)
	var role = Label.new()
	role.text = {"ashe": "KITE • SLOW • MULTISHOT\nKeep your distance and rain arrows.", "annie": "BURST • SHIELD • SUMMON\nBurn packs down with spell combos.", "garen": "MELEE • SPIN • EXECUTE\nClose the gap and fight in the crowd."}.get(hero_key, H.get("role", ""))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 13)
	role.add_theme_color_override("font_color", Color("a2c3d5"))
	v.add_child(role)

	hero_cards[hero_key] = card
	_ignore_card_input(card)
	return card

func _ignore_card_input(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_PASS if not child.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
		_ignore_card_input(child)

func _select_hero(hero_key: String) -> void:
	selected_hero = hero_key
	if launch_button != null: launch_button.text = ("READY • " if LanSession.active else "PLAY ARAM • ") + ChampionData.CHAMPIONS[hero_key].name
	for key in hero_cards:
		var style = hero_cards[key].get_theme_stylebox("panel")
		var color = ChampionData.CHAMPIONS[key].color
		style.border_color = Color(color.r,color.g,color.b,1.0 if key == hero_key else 0.3)
		style.set_border_width_all(3 if key == hero_key else 2)
		hero_cards[key].modulate = Color.WHITE if key == hero_key else Color(0.85,0.85,0.85)

func award_match_credits(won: bool, kills: int) -> int:
	if GameState.is_pvp():return 0
	return Progression.complete_match(won, GameState.time, kills, GameState.reward_difficulty, GameState.player.cs if is_instance_valid(GameState.player) else 0)

func _build_progression_menu(root: Control, in_match: bool = false) -> void:
	var bar = HBoxContainer.new()
	bar.anchor_left = 0.5; bar.anchor_right = 0.5
	bar.position = Vector2(-540, 54)
	bar.size = Vector2(1080, 52)
	bar.add_theme_constant_override("separation", 24)
	root.add_child(bar)
	var balance = Label.new()
	balance.custom_minimum_size.x = 310
	balance.add_theme_font_size_override("font_size", 22)
	bar.add_child(balance)
	var label = Label.new()
	label.text = "DIFFICULTY  N"
	label.add_theme_font_size_override("font_size", 20)
	bar.add_child(label)
	var stage = SpinBox.new()
	stage.min_value = 1
	stage.max_value = 99
	stage.name = "PreGameDifficulty"
	stage.value = GameState.difficulty if in_match else Progression.difficulty
	stage.editable = not in_match and not LanSession.is_client()
	stage.custom_minimum_size = Vector2(100, 48)
	bar.add_child(stage)
	var upgrades = Button.new()
	upgrades.text = "PERMANENT UPGRADES"
	upgrades.custom_minimum_size = Vector2(280, 48)
	bar.add_child(upgrades)
	var info = Label.new()
	info.anchor_left = 0.5; info.anchor_right = 0.5
	info.position = Vector2(-540, 112)
	info.size = Vector2(1080, 26)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info)
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.05, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	shade.hide()
	var panel = VBoxContainer.new()
	var scroll = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.anchor_left = 0.5; scroll.anchor_right = 0.5
	scroll.offset_left = -490; scroll.offset_right = 490
	scroll.offset_top = 90 if in_match else 100
	scroll.offset_bottom = 1000
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shade.add_child(scroll)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	if in_match: panel.add_theme_constant_override("separation", 10)
	scroll.add_child(panel)
	var heading = Label.new()
	heading.text = "SETTINGS" if in_match and GameState.is_pvp() else "SETTINGS / PERMANENT STATS" if in_match else "PERMANENT UPGRADES"
	heading.add_theme_font_size_override("font_size", 36)
	panel.add_child(heading)
	var wallet = Label.new()
	wallet.add_theme_font_size_override("font_size", 22)
	panel.add_child(wallet)
	if in_match:
		var difficulty_row = HBoxContainer.new()
		panel.add_child(difficulty_row)
		label.reparent(difficulty_row)
		stage.reparent(difficulty_row)
		stage.hide()
		label.text = "PVP — EQUAL STARTING STATS" if GameState.is_pvp() else "DIFFICULTY N%d (LOCKED)" % GameState.difficulty
		bar.hide()
		info.reparent(panel)
		info.custom_minimum_size.y = 28
	var note = Label.new()
	note.text = "PvP uses equal starting stats. Permanent upgrades and N difficulty apply to PvE only." if in_match and GameState.is_pvp() else "Difficulty and permanent stats are locked for this run.\nReturn to the main menu to buy upgrades for your next game." if in_match else "Farm completed runs for permanent credits. Higher N pays more.\nSmall stat gains last forever; higher ranks cost much more. Buy before starting."
	note.add_theme_font_size_override("font_size", 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	var buttons: Dictionary = {}
	for key in ([] if in_match and GameState.is_pvp() else Progression.UPGRADES.keys()):
		var button = Button.new()
		button.name = "Permanent_"+key
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 20)
		panel.add_child(button)
		buttons[key] = button
	var fullscreen = CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "FULLSCREEN  [F11]  •  Native display resolution"
	fullscreen.button_pressed = Progression.fullscreen_enabled
	fullscreen.toggled.connect(set_fullscreen)
	panel.add_child(fullscreen)
	var close = Button.new()
	var sound_toggle = CheckButton.new()
	sound_toggle.text = "SOUND EFFECTS"
	sound_toggle.button_pressed = sound_fx.enabled
	sound_toggle.toggled.connect(sound_fx.set_enabled)
	panel.add_child(sound_toggle)
	var cast_toggle = CheckButton.new()
	cast_toggle.name = "SmartCast"
	cast_toggle.text = "SMART CAST Q / W / E / R"
	cast_toggle.button_pressed = Progression.smart_cast
	cast_toggle.tooltip_text = "On: cast at the cursor immediately. Off: aim, then left-click to cast; right-click or Esc cancels. Self buffs and fixed-target recasts remain instant."
	cast_toggle.toggled.connect(func(enabled):
		Progression.smart_cast = enabled
		_cancel_pending_skill()
		Progression.save_profile())
	panel.add_child(cast_toggle)
	GraphicsQuality.settings_row(panel,graphics_quality)
	var bots = RiftMenus.bot_picker(panel)
	bots.disabled = in_match or (LanSession.active and not LanSession.is_host())
	if in_match:
		bots.set_pressed_no_signal(GameState.allied_bots)
		bots.text = "AI EMPTY SLOTS (LOCKED THIS MATCH)" if GameState.is_pvp() else bots.text + " (LOCKED THIS MATCH)"
	var music_row = HBoxContainer.new()
	music_row.name = "MusicVolumeRow"
	music_row.add_theme_constant_override("separation",20)
	panel.add_child(music_row)
	var music_label = Label.new()
	music_label.name = "MusicVolumeLabel"
	music_label.custom_minimum_size.x = 210
	music_label.add_theme_font_size_override("font_size",20)
	music_label.text = "MUSIC OFF" if music.user_volume<=0 else "MUSIC %d%%" % int(round(music.user_volume*100))
	music_row.add_child(music_label)
	var music_slider = HSlider.new()
	music_slider.name = "MusicVolume"
	music_slider.min_value = 0; music_slider.max_value = 100; music_slider.step = 1
	music_slider.value = music.user_volume*100
	music_slider.custom_minimum_size = Vector2(520,40)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.tooltip_text = "Background music volume • 0 mutes music"
	music_slider.value_changed.connect(func(value):
		music.set_volume(value/100.0)
		music_label.text = "MUSIC OFF" if value<=0 else "MUSIC %d%%" % int(value))
	music_row.add_child(music_slider)
	close.text = "BACK TO GAME  [M / ESC]" if in_match else ("MAIN MENU [ESC]" if menu_page == "upgrades" else "BACK TO HERO SELECT")
	close.custom_minimum_size.y = 52
	panel.add_child(close)
	close.pressed.connect(func():
		if in_match: toggle_in_game_menu()
		elif menu_page in ["upgrades","equipment","pvp"]: _show_main_menu()
		else: shade.hide()
	)
	var refresh = func():
		balance.text = "%d PERMANENT CREDITS" % Progression.credits
		wallet.text = "Credits: %d   %s" % [Progression.credits, Progression.save_error]
		var selected_stage = GameState.difficulty if in_match else Progression.difficulty
		var scale = Progression.scaling(selected_stage)
		info.text = "N%d • Enemy HP x%.2f / Damage x%.2f • %s" % [selected_stage, scale.health, scale.damage, Progression.reward_preview(selected_stage)]
		stage.tooltip_text = Progression.difficulty_preview(selected_stage)
		if in_match and GameState.is_pvp():
			info.text="PVP • Same starting stats for both teams • No difficulty cheats"
			wallet.hide();balance.hide()
		elif in_match: info.text += "\nLocked at match start • Time and kills add bonus credits"
		for key in buttons:
			var upgrade = Progression.UPGRADES[key]
			var lv = int(Progression.levels.get(key, 0))
			var percent = key in ["haste", "stride"]
			var total = "%.1f%%" % (upgrade.value*lv*100) if percent else "%.1f" % (upgrade.value*lv)
			var next = "%.1f%%" % (upgrade.value*(lv+1)*100) if percent else "%.1f" % (upgrade.value*(lv+1))
			var unit = {"vitality":"HP", "might":"AD", "sorcery":"AP", "guard":"armor", "recovery":"HP/sec", "haste":"attack speed", "stride":"move speed"}[key]
			buttons[key].text = "%s Lv.%d/99 • +%s %s%s • %s" % [upgrade.name, lv, total, unit, " → +%s" % next if lv < 99 else "", "%d credits" % Progression.cost(key) if lv < 99 else "MAX"]
			buttons[key].tooltip_text = "Account-wide starting stats • Buy between games • Each rank adds %s %s" % ["%.1f%%" % (upgrade.value*100) if percent else str(upgrade.value), upgrade.unit]
			buttons[key].disabled = in_match or lv >= 99 or Progression.credits < Progression.cost(key)
	for key in buttons:
		buttons[key].pressed.connect(func():
			if in_match: return
			if Progression.buy(key): play_sfx("coin")
			refresh.call()
		)
	stage.value_changed.connect(func(value):
		if in_match or LanSession.is_client(): return
		Progression.difficulty = clampi(int(value), 1, 99)
		Progression.save_profile()
		refresh.call()
	)
	upgrades.pressed.connect(func(): refresh.call(); shade.show())
	refresh.call()
	if in_match: shade.show()

class _CardPortraitDraw extends Control:
	var hero_color: Color
	var hero_trim: Color
	var icon_text: String
	var texture: Texture2D
	func _draw():
		var c = size * 0.5
		var frame=Rect2(c-Vector2(44,44),Vector2(88,88))
		draw_rect(frame,Color("101c2b"))
		if texture != null:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			draw_texture_rect(texture,frame.grow(-3),false)
		draw_rect(frame,Color("bd985b"),false,2.,true)
		draw_rect(frame.grow(-2),Color("493e2a"),false,1.,true)

func _exit_tree() -> void:
	if is_instance_valid(match_loader):match_loader.cancel()

func _resolve_match_roster(player_hero: String) -> Dictionary:
	var hero_keys=ChampionData.CHAMPIONS.keys();hero_keys.shuffle()
	var others=hero_keys.filter(func(h):return h!=player_hero)
	var blue=network_config.get("blue",[player_hero,others[0],others[1]]).duplicate()
	var red=network_config.red.duplicate() if network_config.has("red") else MatchRoster.enemy_team(blue)
	var roster={"blue":blue,"red":red,"mode":str(network_config.get("mode","pve")),"stolen_builds":network_config.get("stolen_builds",[]).duplicate(true)}
	if network_config.is_empty():BuildStealer.assign(roster)
	return roster

func _launch_game(hero_key: String) -> void:
	if GameState.started or is_instance_valid(match_loader):return
	var roster=_resolve_match_roster(hero_key)
	if DisplayServer.get_name()=="headless" and not force_match_loading:
		_start_game(hero_key,roster,not LanSession.loading_match)
		if LanSession.active:LanSession.mark_match_loaded()
		return
	match_load_serial+=1
	var serial=match_load_serial
	var loader=MatchLoading.new();match_loader=loader
	get_tree().root.add_child.call_deferred(loader)
	await loader.ready
	if serial!=match_load_serial:
		loader.pending=false;loader.cancel();return
	loader.show_loading(_return_to_main_menu)
	if not await loader.prepare(roster.blue+roster.red):return
	if serial!=match_load_serial or not is_instance_valid(loader):return
	_start_game(hero_key,roster,false)
	if view3d != null:
		await view3d.warm_up()
		if serial!=match_load_serial or not is_instance_valid(loader):return
	if not await loader.finish_render():return
	if serial!=match_load_serial or not is_instance_valid(loader):return
	if LanSession.active:LanSession.mark_match_loaded()
	else:_finish_match_loading()

func _finish_match_loading() -> void:
	GameState.paused=false
	GameState.running=true
	if is_instance_valid(match_loader):match_loader.dismiss()

func _start_game(hero_key: String,roster: Dictionary={},activate: bool=true) -> void:
	if GameState.started: return
	GameState.match_mode=str(network_config.get("mode","pve"))
	GameState.difficulty = 1 if GameState.is_pvp() else int(network_config.get("stage",Progression.difficulty))
	GameState.reward_difficulty = GameState.difficulty
	if not GameState.is_pvp():Progression.begin_match()
	menu.queue_free()
	hud.get_node("HudRoot").show()
	hud.get_node("HudRoot").show_game_hud()
	_build_match(hero_key,roster,activate)
	_build_in_game_menu()

# =============================================================================
# MATCH BOOT
# =============================================================================
func _build_match(player_hero: String,roster: Dictionary={},activate: bool=true) -> void:
	GameState.reset()
	archive_report=""
	GameState.paused=not activate
	GameState.match_mode=str(network_config.get("mode","pve"))
	GameState.team_size=int(network_config.get("team_size",3))
	GameState.fill_bots=bool(network_config.get("fill_bots",true))
	if GameState.is_pvp():GameState.difficulty=1
	GameState.allied_bots = bool(network_config.get("allied_bots",Progression.allied_bots))
	_cancel_pending_skill()
	_reset_camera_shake()
	hero_impact_times.clear()
	spell_hit_times.clear()
	# Structures per team
	for team in [BLUE, RED]:
		_build_base(team)
	# Champion compositions
	if roster.is_empty():roster=_resolve_match_roster(player_hero)
	var blue_pick=roster.blue
	var red_pick=roster.red
	ActionSpriteArt.begin_match(blue_pick+red_pick)
	KitEffectArt.begin_match(blue_pick+red_pick)
	var configs: Array=network_config.get("players",[])
	for team in [BLUE,RED]:
		for i in range(3):
			var config={}
			for index in range(configs.size()):
				if int(configs[index].get("slot",index))==team*3+i:config=configs[index];break
			var owner=int(config.get("peer",1 if team==BLUE and i==0 and network_config.is_empty() else 0))
			if LanSession.active and owner>1 and not LanSession.players.has(owner):owner=0
			var is_player=owner==multiplayer.get_unique_id()
			var c=ChampionS.new();world_root.add_child(c)
			var hero=(blue_pick if team==BLUE else red_pick)[i]
			c.setup(team,hero,owner==0,"You" if is_player else config.get("name",["Ally","Buddy","Vanguard"][i] if team==BLUE else ["Rival","Villain","Nemesis"][i]))
			c.owner_peer=owner
			for echo in range(roster.get("stolen_builds",[]).size()):
				var borrowed=roster.stolen_builds[echo]
				if int(borrowed.slot)==team*3+i:BuildStealer.attach(c,borrowed.record,echo+1)
			if not config.is_empty():
				c.permanent_bonus={} if GameState.is_pvp() else config.get("bonuses",{}).duplicate()
				c.summoner_spells=config.spells.duplicate();c._apply_items()
			GameState.champions.append(c)
			if is_player:GameState.player=c
	# Spread spawns
	for c in GameState.champions:
		c.level = 3
		c.skill_ranks = [1, 1, 1, 0]
		c.skill_history.clear()
		c.skill_points = 0
		if c == GameState.player: c.summoner_spells = selected_summoners.duplicate()
		c._recompute_stats()
		c.hp = c.hp_max
		c.mp = c.mp_max
		var team_idx = 0
		var count = 0
		for d in GameState.champions:
			if d.team == c.team:
				if d == c: team_idx = count
				count += 1
		c.global_position.y = Constants.LANE_Y + (team_idx - 1) * 32
		if GameState.is_pvp():
			if team_idx>=GameState.team_size or (c.is_bot and not GameState.fill_bots and not network_config.get("resuming",false)):c.disable_roster_slot()
		elif c.team == BLUE and c.is_bot and not GameState.allied_bots: c.disable_roster_slot()

	GameState.cam_target.x = GameState.player.global_position.x
	GameState.cam_target.y = GameState.player.global_position.y
	camera.position = GameState.cam_target
	hud.get_node("HudRoot").build_for_player(GameState.player)
	GameState.started = true
	GameState.running = activate
	lane_augments = load("res://scripts/LaneAugments.gd").new()
	add_child(lane_augments)
	lane_augments.setup(self)

	floating_text(GameState.player.global_position + Vector2(0, -60),
		"Minions in 3s", Color(1.0, 0.86, 0.52), true)
	if view3d != null: view3d.activate()

func _build_base(team: int) -> void:
	var dir = 1 if team == BLUE else -1
	var base_x = Constants.BASE_B_X if team == BLUE else Constants.BASE_R_X

	var nx = StructureS.new(); world_root.add_child(nx)
	nx.setup(team, "nexus", Vector2(base_x + dir * 120, Constants.LANE_Y))
	GameState.structures.append(nx)
	GameState.nexus[team] = nx

	for off_y in [-100, 100]:
		var nt = StructureS.new(); world_root.add_child(nt)
		nt.setup(team, "nexus_turret", Vector2(base_x + dir * 220, Constants.LANE_Y + off_y))
		GameState.structures.append(nt)

	var inhib = StructureS.new(); world_root.add_child(inhib)
	inhib.setup(team, "inhibitor", Vector2(base_x + dir * 320, Constants.LANE_Y))
	GameState.structures.append(inhib)
	GameState.inhibitors[team] = inhib

	var inner = StructureS.new(); world_root.add_child(inner)
	inner.setup(team, "turret", Vector2(base_x + dir * 560, Constants.LANE_Y), "inner")
	GameState.structures.append(inner)

	var outer = StructureS.new(); world_root.add_child(outer)
	outer.setup(team, "turret", Vector2(base_x + dir * 860, Constants.LANE_Y), "outer")
	GameState.structures.append(outer)

# =============================================================================
# INPUT / COMMANDS
# =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_world = screen_to_ground(event.position)
		GameState.cursor_world = mouse_world
	if not GameState.running: return
	if GameState.paused or (in_game_menu != null and in_game_menu.has_node("MatchPanel")): return
	if event is InputEventMouseButton and event.pressed:
		mouse_world = screen_to_ground(event.position)
		GameState.cursor_world = mouse_world
		if view3d != null and view3d.is_active() and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			view3d.rig.wheel(-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if pending_skill >= 0:
				_cancel_pending_skill()
				return
			_issue_player_order({"type":"smart", "point": pick_point(event.position, Picker3D.Pick.ANY)})
			attack_move_pending = false
			_spawn_target_marker(mouse_world)
		elif event.button_index == MOUSE_BUTTON_LEFT and pending_skill >= 0:
			var idx = pending_skill
			_cancel_pending_skill()
			if is_instance_valid(GameState.player): GameState.player.try_cast_skill(idx, pick_point(event.position, Picker3D.Pick.ANY))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and attack_move_pending:
			_issue_player_order({"type":"amove", "point": pick_point(event.position, Picker3D.Pick.ENEMY)})
			attack_move_pending = false
			_spawn_target_marker(mouse_world)

	if event is InputEventKey and event.pressed and not event.echo:
		var p = GameState.player
		if p == null: return
		# Ctrl + Q/W/E/R = level up that skill
		if event.ctrl_pressed:
			match event.keycode:
				KEY_Q: p.try_level_skill(0)
				KEY_W: p.try_level_skill(1)
				KEY_E: p.try_level_skill(2)
				KEY_R: p.try_level_skill(3)
			return
		match event.keycode:
			KEY_Q: _player_cast_skill(0)
			KEY_W: _player_cast_skill(1)
			KEY_E: _player_cast_skill(2)
			KEY_R: _player_cast_skill(3)
			KEY_D: _player_cast_summoner(0)
			KEY_F: _player_cast_summoner(1)
			KEY_A:
				if p.dead: return
				_cancel_pending_skill()
				if event.shift_pressed:
					_issue_player_order({"type":"amove", "point":_cursor_point(Picker3D.Pick.ENEMY)})
					attack_move_pending = false
				else: attack_move_pending = true
			KEY_S:
				_cancel_pending_skill()
				attack_move_pending = false
				p.stop_actions()
			KEY_B:
				_cancel_pending_skill()
				p.start_recall()
			KEY_P:
				_cancel_pending_skill()
				hud.get_node("HudRoot").toggle_shop()
			KEY_U:
				_cancel_pending_skill()
				lane_augments.toggle_panel()
			KEY_SPACE:
				GameState.cam_target = p.global_position
				GameState.cam_locked = true
			KEY_Y:
				GameState.cam_locked = not GameState.cam_locked

# Screen <-> ground seams shared by 2D and Rift3D. In 2D they are the canvas transform maths.
func screen_to_ground(screen: Vector2) -> Vector2:
	if view3d != null and view3d.is_active(): return view3d.screen_to_ground(screen)
	return get_canvas_transform().affine_inverse() * screen

func world_to_screen(point: Vector2, height_px: float = 0.0) -> Vector2:
	if view3d != null and view3d.is_active(): return view3d.world_to_screen(point, height_px)
	return get_canvas_transform() * (point - Vector2(0, height_px))

func pick_point(screen: Vector2, mode: int) -> Vector2:
	if view3d != null and view3d.is_active() and GameState.player != null:
		return view3d.picker.pick_point(screen, GameState.player.team, mode)
	return screen_to_ground(screen)

func _cursor_point(mode: int) -> Vector2:
	if view3d == null or not view3d.is_active(): return get_global_mouse_position()
	if get_viewport().gui_get_hovered_control() != null: return mouse_world
	return pick_point(get_viewport().get_mouse_position(), mode)

func cursor_ui_point() -> Vector2:
	if view3d == null or not view3d.is_active(): return get_global_mouse_position()
	if is_instance_valid(GameState.hover_unit) and not GameState.hover_unit.dead: return GameState.hover_unit.world_pos()
	return GameState.cursor_world

func _issue_player_order(order: Dictionary) -> void:
	if LanSession.is_client():
		LanSession.send_command("order",ClientMovement.order(GameState.player,order))
		return
	_issue_champion_order(GameState.player,order)

func _issue_champion_order(p, order: Dictionary) -> void:
	if p == null or p.dead or GameState.paused or not GameState.running: return
	p.manual_move = Vector2.ZERO
	if p.buffs.has("monsoon"): SupportKits.cancel_channel(p)
	p.last_order_sequence = int(order.get("sequence",p.last_order_sequence))
	var destination = GameState.clamp_walkable(order.point)
	if p.recall_time >= 0: p.recall_time = -1.0
	var target = null
	if order.type=="smart":
		for zone in GameState.aoes:
			if is_instance_valid(zone) and zone.try_lantern(p,order.point):return
	if order.type == "smart": target = GameState.find_target_at(order.point,p.team,8)
	elif order.type == "amove":
		target = GameState.find_attack_move_target(p,order.point,true)
		if target == null: target = GameState.find_attack_move_target(p,order.point)
	else: return
	# Reissuing an attack on the same target must not restart its windup.
	if target != p.queued_auto_target: p.cancel_auto()
	p.attack_target = target
	p.attack_move = order.type == "amove"
	p.attack_move_destination = destination
	p.move_target = destination
	p.has_move_target = target == null

func _player_cast_skill(idx: int) -> void:
	var p = GameState.player
	if not is_instance_valid(p) or idx < 0 or idx >= 4 or p.dead or p.stun > 0 or p.buffs.has("silence") or GameState.paused or not GameState.running: return
	if in_game_menu != null and in_game_menu.has_node("MatchPanel"): return
	mouse_world = _cursor_point(Picker3D.Pick.ANY)
	var recast = NewHeroKits.recast_info(p,idx)
	if not Progression.smart_cast and p.hero.skills[idx].kind != "self" and recast.is_empty():
		if p.skill_ranks[idx] <= 0 or p.skill_cds[idx] > 0 or p.mp < p.hero.skills[idx].cost: return
		pending_skill = idx
		attack_move_pending = false
		skill_aimer.set_aim(p,idx)
		return
	_cancel_pending_skill()
	p.try_cast_skill(idx, mouse_world)

func _cancel_pending_skill() -> void:
	pending_skill = -1
	if is_instance_valid(skill_aimer): skill_aimer.clear_aim()

func _player_cast_summoner(idx: int) -> void:
	_cancel_pending_skill()
	var p = GameState.player
	if p == null: return
	mouse_world = _cursor_point(Picker3D.Pick.ANY)
	cast_summoner(p, idx)

# =============================================================================
# UPDATE LOOP
# =============================================================================
func _process(delta: float) -> void:
	if pending_skill >= 0 and (not GameState.running or GameState.paused or not is_instance_valid(GameState.player) or GameState.player.dead):
		_cancel_pending_skill()
	if (view3d == null or not view3d.is_active()) and GameState.started: GameState.cursor_world = get_global_mouse_position()
	if not GameState.started: return
	if not GameState.running:
		_update_camera(delta)
		return
	if LanSession.is_client():
		BrushVision.update_presentation()
		_update_camera(delta)
		hud.get_node("HudRoot").refresh(delta)
		return
	if GameState.paused: return
	# Subdivide long frames instead of discarding elapsed combat/movement time.
	var remaining = minf(delta,0.15)
	while remaining > 0.00001:
		var step = minf(remaining,0.02)
		_simulate_step(step)
		remaining -= step
	LanSession.replicate(delta)
	_update_camera(delta)
	hud.get_node("HudRoot").refresh(delta)

func _simulate_step(delta: float) -> void:
	GameState.time += delta

	BrushVision.update_presentation()
	_tick_waves()
	_tick_economy(delta)
	for c in GameState.champions:
		if not c.roster_active: continue
		if c.dead:
			c.tick_cooldowns(delta)
			if GameState.time >= c.respawn_at:
				_respawn_champion(c)
		else:
			c.update_frame(delta)
	for m in GameState.minions:
		if not m.dead: m.update_frame(delta)
	for s in GameState.structures:
		s.update_frame(delta)
	# Clean dead minions
	for i in range(GameState.minions.size() - 1, -1, -1):
		var m = GameState.minions[i]
		if m.dead:
			if not m.corpse_spawned: AnimatedCorpse.spawn(m)
			m.queue_free()
			GameState.minions.remove_at(i)
	# Projectiles / AoEs are self-cleaning but iterate
	for pr in GameState.projectiles.duplicate():
		if is_instance_valid(pr): pr.update_frame(delta)
	for a in GameState.aoes.duplicate():
		if is_instance_valid(a): a.update_frame(delta)

func _update_camera(delta: float) -> void:
	var sp = (ViewConfig.EDGE_PAN_SPEED_3D if view3d != null else 540.0) * delta
	var panned = false
	if not GameState.cam_locked and Input.is_physical_key_pressed(KEY_LEFT): GameState.cam_target.x -= sp; panned = true
	if not GameState.cam_locked and Input.is_physical_key_pressed(KEY_RIGHT): GameState.cam_target.x += sp; panned = true
	if not GameState.cam_locked and Input.is_physical_key_pressed(KEY_UP): GameState.cam_target.y -= sp; panned = true
	if not GameState.cam_locked and Input.is_physical_key_pressed(KEY_DOWN): GameState.cam_target.y += sp; panned = true
	var mp = get_viewport().get_mouse_position()
	var vp = get_viewport().get_visible_rect().size
	var edge = 18.0 if not GameState.cam_locked else 0.0
	if mp.x > 0 and mp.x < edge: GameState.cam_target.x -= sp; panned = true
	if mp.x > vp.x - edge and mp.x < vp.x: GameState.cam_target.x += sp; panned = true
	if mp.y > 0 and mp.y < edge: GameState.cam_target.y -= sp; panned = true
	if mp.y > vp.y - edge and mp.y < vp.y: GameState.cam_target.y += sp; panned = true
	if panned: GameState.cam_locked = false
	if GameState.cam_locked and GameState.player != null:
		var target = GameState.player.global_position
		GameState.cam_target = target if GameState.cam_target.distance_to(target) > 400 else GameState.cam_target.lerp(target, 1.0 - exp(-24.0 * delta))
	else:
		GameState.cam_target.x = clamp(GameState.cam_target.x, 0, Constants.WORLD_W)
		if view3d != null: GameState.cam_target.y = clamp(GameState.cam_target.y, ViewConfig.CAM_Y_CLAMP_3D.x, ViewConfig.CAM_Y_CLAMP_3D.y)
		else: GameState.cam_target.y = clamp(GameState.cam_target.y, 0, Constants.WORLD_H)

	var shake = Vector2.ZERO
	if cam_shake_t > 0:
		cam_shake_t = maxf(0.0, cam_shake_t - delta)
		var amp = cam_shake_amp * (cam_shake_t / cam_shake_duration)
		shake = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		if cam_shake_t == 0.0: _reset_camera_shake()
	camera_shake_offset = shake
	camera.position = GameState.cam_target + shake

func _tick_waves() -> void:
	if GameState.time >= GameState.next_wave_at:
		_spawn_wave(BLUE)
		_spawn_wave(RED)
		GameState.wave_num += 1
		GameState.next_wave_at = GameState.time + Constants.WAVE_INTERVAL

func _spawn_wave(team: int) -> void:
	var sx: float = (Constants.BASE_B_X + 40) if team == BLUE else (Constants.BASE_R_X - 40)
	var dir = -1 if team == BLUE else 1
	var y_off = [-25, 0, 25]
	var minutes = GameState.time / 60.0
	var scale_mult = 1.0 + minutes * 0.08
	for i in range(3):
		var m = MinionS.new()
		world_root.add_child(m)
		m.setup(team, "melee", Vector2(sx + dir * (i * 32), Constants.LANE_Y + y_off[i % 3]), scale_mult)
		GameState.minions.append(m)
	for i in range(3):
		var m = MinionS.new()
		world_root.add_child(m)
		m.setup(team, "caster", Vector2(sx + dir * (110 + i * 32), Constants.LANE_Y + y_off[i % 3]), scale_mult)
		GameState.minions.append(m)
	if GameState.wave_num % 3 == 2:
		var m = MinionS.new()
		world_root.add_child(m)
		m.setup(team, "siege", Vector2(sx + dir * 220, Constants.LANE_Y), scale_mult)
		GameState.minions.append(m)
	var enemy_inhib = GameState.inhibitors[BLUE if team == RED else RED]
	if enemy_inhib != null and enemy_inhib.dead:
		for i in range(2):
			var m2 = MinionS.new()
			world_root.add_child(m2)
			m2.setup(team, "super", Vector2(sx + dir * (260 + i * 32), Constants.LANE_Y + y_off[i]), scale_mult)
			GameState.minions.append(m2)


func _tick_economy(delta: float) -> void:
	if LanSession.is_client() or not GameState.started or not GameState.running or GameState.paused or not is_finite(delta) or delta <= 0: return
	economy_timer += delta
	var seconds = floori(economy_timer)
	if seconds <= 0: return
	economy_timer -= seconds
	for c in GameState.champions:
		if not c.roster_active: continue
		c.passive_gold_remainder += Constants.PASSIVE_GOLD * seconds
		var payout = floori(c.passive_gold_remainder + 0.00000001)
		c.passive_gold_remainder = maxf(0., c.passive_gold_remainder - payout)
		c.gold += payout
		c.grant_xp(Constants.PASSIVE_XP * seconds)

func _respawn_champion(c) -> void:
	if not c.roster_active: return
	c.assist_hits.clear()
	c.assist_support.clear()
	c.dead = false
	c.hit_flash=0.;c.material.set_shader_parameter("hit_whiten",0.)
	c.animator.start("idle",0)
	c.is_targetable = true
	c.hp = c.hp_max; c.mp = c.mp_max; c.shield = 0; c.stun = 0
	c.visible = true
	c.buffs.clear()
	c._apply_items()
	c.buffs["haste"] = {"time": 5.0, "mult": 1.55}
	c.manual_move = Vector2.ZERO
	c.stop_actions()
	c.is_dashing = false
	c.global_position = Constants.FOUNT_B if c.team == BLUE else Constants.FOUNT_R
	HeroPassives.respawn(c)
	if c == GameState.player:
		hud.get_node("HudRoot").hide_death_overlay()

# =============================================================================
# GROUP CALLS (invoked via get_tree().call_group("game_main", ...))
# =============================================================================
func spawn_projectile(src, pos: Vector2, dir: Vector2, opts: Dictionary) -> void:
	var p = ProjectileS.new()
	world_root.add_child(p)
	if src.kind=="champion":
		opts=opts.duplicate();opts["spell_id"]=opts.get("spell_id",opts.get("effect_id",src.active_cast_id));opts["stun"]=maxf(opts.get("stun",0.),src.cast_passive_stun)
	p.setup(src, pos, dir, opts)
	GameState.projectiles.append(p)

func spawn_aoe(src, pos: Vector2, opts: Dictionary) -> void:
	var a = AoES.new()
	world_root.add_child(a)
	if src.kind=="champion":
		opts=opts.duplicate();opts["spell_id"]=opts.get("spell_id",opts.get("effect_id",src.active_cast_id));opts["stun"]=maxf(opts.get("stun",0.),src.cast_passive_stun)
	a.setup(src, pos, opts)
	GameState.aoes.append(a)

func floating_text(pos: Vector2, text: String, color: Color, big: bool = false, audience: Array = []) -> void:
	LanSession.send_effect("text",null,pos,{"text":text,"color":color,"big":big,"audience":audience})
	if not audience.is_empty() and not audience.has(multiplayer.get_unique_id()):return
	var ft = FloatingTextS.new()
	world_root.add_child(ft)
	ft.setup(pos, text, color, big)

func spawn_trail(pos: Vector2, color: Color, size: float) -> void:
	var puff = _PuffFx.new()
	puff.col = color
	puff.sz = size
	puff.global_position = pos
	puff.z_index = Constants.Z_FX
	world_root.add_child(puff)

func spawn_impact(pos: Vector2, color: Color, size: float) -> void:
	LanSession.send_effect("impact",null,pos,{"color":color,"size":size})
	var imp = _ImpactFx.new()
	imp.col = color
	imp.start_sz = minf(size,14.)
	imp.global_position = pos
	imp.z_index = Constants.Z_FX
	world_root.add_child(imp)

func _spawn_target_marker(pos: Vector2) -> void:
	var m = _TargetRing.new()
	m.global_position = pos
	m.z_index = Constants.Z_FX
	world_root.add_child(m)

func on_level_up(c) -> void:
	if lane_augments != null:
		if LanSession.is_host() and c.owner_peer > 1: LanSession.award_draft(c)
		else: lane_augments.on_level_up(c)
	if c == GameState.player: play_sfx("level")
	var ring = _LevelUpRing.new()
	ring.global_position = c.global_position
	ring.z_index = Constants.Z_FX
	world_root.add_child(ring)
	# Big floating callout
	if c.owner_peer>0:floating_text(c.global_position+Vector2(0,-60),"LEVEL %d" % c.level,Color(1.,.86,.33),true,[c.owner_peer])
	# Celebrate the player's level-up with screen effects
	if c == GameState.player:
		# Burst of golden particles
		for i in range(18):
			var p = _BurstParticle.new()
			var ang = TAU * i / 18.0 + randf_range(-0.1, 0.1)
			p.vel = Vector2(cos(ang), sin(ang)) * randf_range(90, 180)
			p.col = Color(1.0, 0.86, 0.33)
			p.global_position = c.global_position
			p.z_index = Constants.Z_FX
			world_root.add_child(p)

func camera_shake(duration: float, amp: float, origin = null) -> void:
	if origin is Vector2 and camera.position.distance_to(origin)>550.:return
	if duration <= 0.0 or amp <= 0.0: return
	cam_shake_t = max(cam_shake_t, duration)
	cam_shake_amp = minf(6.,max(cam_shake_amp, amp))
	cam_shake_duration = cam_shake_t

func _reset_camera_shake() -> void:
	cam_shake_t = 0.0
	cam_shake_amp = 0.0
	cam_shake_duration = 0.0
	camera_shake_offset = Vector2.ZERO

func set_aiming_skill(idx: int) -> void:
	if pending_skill >= 0: return
	# Called from HUD when the player hovers a skill slot.
	if skill_aimer != null and GameState.player != null:
		skill_aimer.set_aim(GameState.player, idx)

func clear_aiming_skill() -> void:
	if pending_skill >= 0: return
	if skill_aimer != null:
		skill_aimer.clear_aim()

func camera_flash(duration: float, color: Color, origin = null) -> void:
	if origin is Vector2 and camera.position.distance_to(origin)>550.:return
	hud.get_node("HudRoot").flash(duration, color)

# =============================================================================
# COMBAT RESOLUTION
# =============================================================================
func deal_damage(src, target, dmg: float, dmg_type: String, spell_id: String = "") -> void:
	if LanSession.is_client(): return
	if typeof(src) == TYPE_OBJECT and not is_instance_valid(src): src = null
	if target == null or target.dead: return
	var cast_id=spell_id if not spell_id.is_empty() else src.active_cast_id if is_instance_valid(src) and src.kind=="champion" else ""
	if dmg_type=="mark" and cast_id=="ezreal_w":dmg_type="magic"
	var legacy_damage=dmg_type=="skill"
	if legacy_damage and not cast_id.is_empty():dmg_type=preload("res://scripts/SkillScaling.gd").damage_type(cast_id)
	if Roster12Combat.blocked(src,target,dmg_type):return
	if ExpansionCombat.spell_block(target,dmg_type):return
	if "buffs" in target and target.buffs.has("divine"): return
	if dmg<=0:return
	if dmg_type in ["auto", "secondary_auto", "skill","magic","physical"] and "buffs" in target and target.buffs.has("flux_mark"):
		var mark = target.buffs["flux_mark"]
		if is_instance_valid(mark.src) and is_instance_valid(src) and mark.src == src:
			dmg += mark.bonus
			target.buffs.erase("flux_mark")
	if GameState.paused or not GameState.running: return
	if dmg_type in ["auto","skill","magic","physical"]:
		BrushVision.reveal(target,1.25)
		BrushVision.reveal(src)
	# Preserve the raw rocket payload; each victim applies difficulty/armor once.
	var rocket_splash_damage = dmg*0.35
	# Repeated hits use a bounded coefficient, rather than 100% AP every tick.
	if legacy_damage and src != null and "bonus_ap" in src:
		dmg += src.bonus_ap * preload("res://scripts/SkillScaling.gd").legacy_ap_ratio(src.hero_key)
	if src is Object and src.kind == "champion":
		dmg *= src.difficulty_stats.get("damage", 1.0)
	var luden_proc=0.
	if dmg_type in ["skill","magic","physical"] and target.kind!="structure" and is_instance_valid(src) and src.kind == "champion" and src.inventory.has("ludens") and src.item_cds.get("ludens", 0.0) <= 0:
		luden_proc = 70 + src.bonus_ap * 0.1
		src.item_cds["ludens"] = 6.0
		spawn_spell_burst(src, target.world_pos(), 38)
	# Armor: LoL formula dmg * 100 / (100 + armor), applies to all incoming non-"exec" damage
	if dmg_type != "exec":
		dmg = dmg * 100.0 / (100.0 + ExpansionCombat.resist(target,src,dmg_type))
	dmg *= TankADCombat.damage_multiplier(src,target,dmg_type)
	ExpansionCombat.on_spell(src,target,dmg_type)
	TankADCombat.on_damage(src,target,dmg_type,dmg)
	# Damage reduction buff (Garen W)
	if dmg_type!="exec" and "buffs" in target and target.buffs.has("courage"):
		dmg *= (1.0 - target.buffs["courage"]["dr"])
	# Hitting a protected champion draws tower aggro even when armor or shields absorb the hit.
	if dmg > 0 and src is Object and src.kind == "champion" and target.kind == "champion" and src.team != target.team:
		for tower in GameState.structures:
			if tower.team == target.team and tower.atk_dmg > 0 and not tower.dead and tower.world_pos().distance_to(target.world_pos()) <= tower.atk_range:
				tower.provoke(src)
	if dmg > 0 and target.kind == "champion": target.time_since_damage = 0
	if dmg > 0 and "recall_time" in target:
		target.recall_time = -1.0
		target.queue_redraw()
	dmg = floor(dmg)
	if target.kind=="champion" and dmg>0:
		var health_after=maxf(0.,target.hp-maxf(0.,dmg-target.shield))
		TankADCombat.lifeline(target,"legacy_magic" if ExpansionCombat.is_magic(src,dmg_type) else dmg_type,health_after)
	if dmg_type != "mark" and "buffs" in target and target.buffs.has("death_mark") and target.buffs.death_mark.src == src:
		target.buffs.death_mark.stored += dmg
	HeroPassives.before_damage(src,target,dmg_type,dmg)
	if dmg > 0: CombatParticipation.hit(src,target)
	var damage_before_shield=dmg
	# Shield absorb
	if "shield" in target and target.shield > 0:
		var absorb = min(target.shield, dmg)
		var untracked_absorb=TankADCombat.consume_shield(target,absorb)
		if target.kind=="champion" and target.hero_key=="malphite":target.passive_state.granite=maxf(0.,target.passive_state.get("granite",0.)-untracked_absorb)
		target.shield -= absorb
		if target.kind=="champion" and target.buffs.has("storm_shield") and target.buffs.storm_shield.shield<=0:target._apply_items()
		dmg -= absorb
		if target.kind=="champion" and target.owner_peer>0:floating_text(target.world_pos()+Vector2(0,-20),"-"+str(int(absorb)),Color(.55,.73,1.),false,[target.owner_peer])
	var health_damage=minf(maxf(0.,target.hp),dmg)
	if dmg > 0:
		if is_instance_valid(src) and src.kind=="champion" and src.inventory.has("collector") and target.kind=="champion" and dmg_type in ["auto","skill","magic","physical"] and target.hp-dmg>0 and target.hp-dmg<target.hp_max*.04:
			dmg=target.hp
		target.hp -= dmg
		if "hit_flash" in target: target.hit_flash = 0.14
		if target.kind == "champion":
			target.animator.hit()
			var row=1 if ExpansionCombat.is_magic(src,dmg_type) or dmg_type=="skill" else 0
			if dmg_type in ["burn","reflect"]:row=2
			var impact_radius=clampf(16.+dmg/maxf(1.,target.hp_max)*60.,16.,26.)
			var impact_angle=(target.world_pos()-src.world_pos()).angle() if is_instance_valid(src) else 0.
			spawn_hero_impact(target.world_pos()+Vector2(0,-30),row,impact_radius,impact_angle,target)
		var hits_minion = target.kind == "minion"
		var champion_hit = src is Object and src.kind == "champion"
		if hits_minion:
			if champion_hit and GameState.time>=target.next_hit_feedback:
				target.next_hit_feedback = GameState.time+0.12
				spawn_minion_hit(target.world_pos())
				target.take_flash()
		else:
			play_sfx("hurt" if target == GameState.player else "impact", target)
			if dmg_type == "skill" and champion_hit and target.kind!="champion": spawn_spell_burst(src, target.world_pos(), 34.0)
		if "recall_time" in target: target.recall_time = -1.0
		var col = Color.WHITE
		match dmg_type:
			"exec": col = Color(1.0, 0.27, 1.0)
			"skill": col = Color(1.0, 0.71, 0.33)
			"crit": col = Color(1.0, 0.47, 0.2)
		# Human farming numbers stay visible; automated wave trading stays quiet.
		var viewers=[]
		if champion_hit and src.owner_peer>0:viewers.append(src.owner_peer)
		if target.kind=="champion" and target.owner_peer>0 and not viewers.has(target.owner_peer):viewers.append(target.owner_peer)
		if not viewers.is_empty() and (not hits_minion or GameState.time>=target.next_damage_label):
			if hits_minion: target.next_damage_label = GameState.time+0.25
			floating_text(target.world_pos()+Vector2(0,-20),"-"+str(int(dmg)),col,dmg_type in ["exec","crit"],viewers)
		# Lifesteal — attacker heals on auto-attack damage
		if dmg_type in ["auto","secondary_auto","attack_fragment"] and src != null and "bonus_lifesteal" in src and (src.bonus_lifesteal > 0 or src.buffs.has("iron_will")):
			var restored = ExpansionCombat.healing_multiplier(src) * health_damage * (src.bonus_lifesteal + src.buffs.get("iron_will",{}).get("lifesteal",0.0))
			if src.inventory.has("bloodthirster"):
				CombatEffects.overheal(src,maxf(0, src.hp + restored - src.hp_max))
			src.hp = min(src.hp_max, src.hp + restored)
	if dmg_type == "auto" and is_instance_valid(src) and src.kind == "champion" and src.buffs.has("rockets"):
		for neighbor in GameState.champions+GameState.minions:
			if neighbor == target or neighbor.dead or neighbor.team == src.team or neighbor.world_pos().distance_to(target.world_pos()) > 80: continue
			deal_damage(src,neighbor,rocket_splash_damage,"splash")
	# Thornmail reflect — on taking auto-attack damage, reflect flat damage back to attacker
	if dmg_type in ["auto","secondary_auto"] and "bonus_reflect" in target and target.bonus_reflect > 0 \
			and src != null and ("kind" in src) and (src.kind == "champion" or src.kind == "minion"):
		deal_damage(target, src, target.bonus_reflect, "reflect")
	# Molten shield reflect (Annie E buff)
	if "buffs" in target and target.buffs.has("molten") and \
			src != null and ("kind" in src) and src.kind == "champion" and dmg_type in ["auto","secondary_auto"]:
		deal_damage(target, src, target.buffs["molten"]["reflect"], "reflect")
	if is_instance_valid(src) and src.kind=="champion":SupportCombat.on_damage(src,target,dmg_type,damage_before_shield,cast_id)
	HeroPassives.on_damage(src,target,"auto" if dmg_type=="secondary_auto" else dmg_type,damage_before_shield,cast_id,health_damage)
	ExpansionCombat.after_hit(src,target,dmg_type)
	if luden_proc>0 and target.hp>0 and not target.dead:deal_damage(src,target,luden_proc,"item_magic")
	ExpansionCombat.lifeline(target,dmg_type,src)
	if target.hp <= 0:
		_handle_death(src, target)

func _handle_death(killer, victim) -> void:
	if victim.dead: return
	HeroPassives.on_death(killer,victim)
	if victim.kind == "champion": play_sfx("death" if victim == GameState.player else "kill", victim)
	elif victim.kind == "structure": play_sfx("kill", victim)
	if victim.kind in ["champion","minion"]:Roster12Combat.on_death(victim)
	victim.dead = true
	victim.hp = 0
	if victim.kind in ["champion","minion"]: AnimatedCorpse.spawn(victim)
	if victim.kind == "minion": victim.corpse_spawned = true
	if victim.kind == "champion": victim.stop_actions()
	match victim.kind:
		"champion":
			victim.deaths += 1
			victim.grant_comeback_gold()
			var now = GameState.time
			var respawn = clampf(4.0 + victim.level * 0.16, 4.0, 7.0)
			victim.respawn_at = now + respawn
			victim.visible = false
			victim.is_targetable = false
			victim.attack_target = null
			victim.has_move_target = false
			var winning_team = RED if victim.team == BLUE else BLUE
			GameState.score[winning_team] += 1
			spawn_hero_impact(victim.world_pos(),3,34.,0.)
			if killer != null and ("kind" in killer) and killer.kind == "champion":
				killer.kills += 1
				killer.gold += Constants.HERO_KILL_GOLD
				killer.grant_xp(Constants.HERO_KILL_XP + victim.level * Constants.HERO_KILL_XP_PER_LEVEL)
				if killer.owner_peer>0:floating_text(killer.world_pos()+Vector2(0,-68),"+%dg" % Constants.HERO_KILL_GOLD,Color("f4d481"),false,[killer.owner_peer])
				TankADCombat.champion_kill(killer)
			kill_announcer.register(killer,victim)
			_log_kill(killer, victim)
			for c in CombatParticipation.assistants(killer,victim):
				c.gold += CombatParticipation.ASSIST_GOLD
				c.grant_xp(Constants.ASSIST_XP + victim.level * Constants.ASSIST_XP_PER_LEVEL)
				c.assists += 1
				if c.owner_peer>0:floating_text(c.world_pos()+Vector2(0,-68),"+%dg ASSIST" % CombatParticipation.ASSIST_GOLD,Color("f4d481"),false,[c.owner_peer])
			victim.assist_hits.clear()
			if victim == GameState.player:
				hud.get_node("HudRoot").show_death_overlay()
				camera_shake(0.3, 10.0)
				camera_flash(0.4, Color(0.6, 0.0, 0.0))
		"minion":
			if killer != null and ("kind" in killer) and killer.kind == "champion":
				killer.cs += 1
				killer.gold += victim.gold_val
				if killer.owner_peer>0:floating_text(victim.world_pos()+Vector2(0,-20),"+"+str(victim.gold_val)+"g",Color(1.,.86,.2),false,[killer.owner_peer])
			for c in GameState.champions:
				if not c.dead and c.team != victim.team and c.global_position.distance_to(victim.world_pos()) <= 650:
					var reward = victim.xp_val * Constants.MINION_SOAK_XP_MULTIPLIER
					if c == killer: reward *= Constants.LAST_HIT_XP_MULTIPLIER
					c.grant_xp(reward)
		"structure":
			victim.visible = false
			victim.is_targetable = false
			if victim.type == "inhibitor":
				victim.respawn_timer = Structure.SPECS["inhibitor"]["respawn"]
				floating_text(victim.world_pos() + Vector2(0, -50),
					"INHIBITOR DOWN", Color(1.0, 0.86, 0.2), true)
			elif victim.type == "nexus":
				var winner = RED if victim.team == BLUE else BLUE
				_end_game(winner)
			else:
				floating_text(victim.world_pos() + Vector2(0, -50),
					"TURRET DESTROYED", Color(1.0, 0.86, 0.2), true)
			_death_burst(victim.global_position, Color(1.0, 0.7, 0.3))
			camera_shake(0.2, 5.0)
			if killer != null and ("kind" in killer) and killer.kind == "champion":
				killer.gold += victim.gold_val
			if killer != null and "team" in killer:
				for c in GameState.champions:
					if c.team == killer.team and not c.dead:
						c.gold += 50

func _death_burst(pos: Vector2, color: Color) -> void:
	for i in range(14):
		var p = _BurstParticle.new()
		var ang = TAU * i / 14.0 + randf_range(-0.3, 0.3)
		p.vel = Vector2(cos(ang), sin(ang)) * randf_range(80, 160)
		p.col = color
		p.global_position = pos
		p.z_index = Constants.Z_FX
		world_root.add_child(p)

func _log_kill(killer, victim) -> void:
	LanSession.send_effect("kill",killer,victim.world_pos(),{"victim":GameState.champions.find(victim)})
	if victim.kind != "champion": return
	hud.get_node("HudRoot").log_kill(killer, victim)

# =============================================================================
# SUMMONER
# =============================================================================
func cast_summoner(c, idx: int) -> void:
	if c == null or c.dead or c.stun > 0 or idx < 0 or idx >= 2 or GameState.paused: return
	if c.summoner_cds[idx] > 0: return
	if LanSession.is_client():
		LanSession.send_command("summoner",{"index":idx,"point":mouse_world})
		return
	var spell: String = c.summoner_spells[idx]
	match spell:
		"flash":
			var point = c.ai_flash_pt if c.is_bot else mouse_world
			var direction = (point - c.world_pos()).limit_length(300)
			var from = _FlashFx.new()
			from.global_position = c.world_pos()
			world_root.add_child(from)
			c.global_position = GameState.clamp_walkable(c.world_pos() + direction)
			c.is_dashing = false
			var to = _FlashFx.new()
			to.global_position = c.world_pos()
			world_root.add_child(to)
			play_sfx("dash", c)
		"ignite":
			var target = c.ai_ignite_target if c.is_bot else GameState.find_nearest_enemy(c, mouse_world, 100)
			if not is_instance_valid(target) or target.dead or target.kind != "champion" or c.world_pos().distance_to(target.world_pos()) > 300:
				floating_text(c.world_pos(), "Ignite: hero within 300 range", Color("ffd288"))
				return
			target.buffs["ignite"] = {"time":5.0,"tick":0.0,"total":70.0+c.level*20,"src":c}
			floating_text(target.world_pos(), "IGNITED", Color("ff7044"))
		"heal":
			var amount = 100.0 + c.level * 25
			c.hp = minf(c.hp_max, c.hp + amount * ExpansionCombat.healing_multiplier(c))
			c.buffs["haste"] = {"time":2.0,"mult":1.25}
			var ally = null
			for hero in GameState.champions:
				if hero == c or hero.dead or hero.team != c.team or hero.world_pos().distance_to(c.world_pos()) > 450: continue
				if ally == null or hero.hp / hero.hp_max < ally.hp / ally.hp_max: ally = hero
			if ally != null:
				ally.hp = minf(ally.hp_max, ally.hp + amount * ExpansionCombat.healing_multiplier(ally))
				HeroPassives.support(c,ally)
				ally.buffs["haste"] = {"time":2.0,"mult":1.25}
			floating_text(c.world_pos(), "+%d HEAL" % amount, Color("6fffa4"))
			spawn_spell_burst(c, c.world_pos(), 45)
			play_sfx("level", c)
		"ghost":
			c.buffs["ghost"] = {"time":6.0,"mult":1.4}
			floating_text(c.world_pos(), "GHOST", Color("77eaff"))
			play_sfx("dash", c)
	c.recall_time = -1
	c.summoner_cds[idx] = SummonerData.SPELLS[spell].cd

func _build_summoner_select(root: Control) -> void:
	var row = HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1
	row.anchor_bottom = 1
	row.position = Vector2(-520, -100)
	row.add_theme_constant_override("separation", 18)
	root.add_child(row)
	for index in range(2):
		var label = Label.new()
		label.text = "D" if index == 0 else "F"
		label.add_theme_font_size_override("font_size", 24)
		row.add_child(label)
		var choice = OptionButton.new()
		choice.custom_minimum_size = Vector2(235, 58)
		choice.add_theme_font_size_override("font_size", 24)
		for spell in SummonerData.ORDER: choice.add_icon_item(ShopArt.icon_for(SummonerData.SPELLS[spell].art), SummonerData.SPELLS[spell].name)
		choice.get_popup().add_theme_constant_override("icon_max_width", 40)
		choice.add_theme_constant_override("icon_max_width", 40)
		choice.select(SummonerData.ORDER.find(selected_summoners[index]))
		choice.tooltip_text = SummonerData.SPELLS[selected_summoners[index]].desc
		var slot = index
		choice.item_selected.connect(func(value):
			var spell = SummonerData.ORDER[value]
			var other = 1 - slot
			if selected_summoners[other] == spell:
				selected_summoners[other] = selected_summoners[slot]
				summoner_selectors[other].select(SummonerData.ORDER.find(selected_summoners[other]))
			summoner_selectors[other].tooltip_text = SummonerData.SPELLS[selected_summoners[other]].desc
			selected_summoners[slot] = spell
			choice.tooltip_text = SummonerData.SPELLS[spell].desc
		)
		summoner_selectors.append(choice)
		row.add_child(choice)
	launch_button = Button.new()
	launch_button.text = ("READY • " if LanSession.active else "PLAY ARAM • ") + ChampionData.CHAMPIONS[selected_hero].name
	launch_button.custom_minimum_size = Vector2(390, 58)
	launch_button.add_theme_font_size_override("font_size", 24)
	launch_button.pressed.connect(func():
		if LanSession.active:
			LanSession.ready_player(selected_hero,selected_summoners,Progression.bonuses())
			_show_lobby()
		else: _launch_game(selected_hero))
	row.add_child(launch_button)

func spawn_tibbers(src, pt: Vector2) -> void:
	var t = MinionS.new()
	world_root.add_child(t)
	t.setup(src.team, "tibbers", pt, 1.0 + 0.6 * src.rank(3))
	GameState.minions.append(t)

func spawn_beam(src, direction: Vector2, length: float, width: float, damage: float, color: Color) -> void:
	LanSession.send_effect("beam",src,src.world_pos(),{"direction":direction,"length":length,"width":width,"color":color})
	direction = direction.normalized()
	if direction.length_squared() < 0.01: direction = src.facing if src.facing.length_squared() > 0.01 else Vector2.RIGHT
	var beam = load("res://scripts/Beam.gd").new()
	world_root.add_child(beam)
	beam.setup(src, direction, length, width, damage, color)
	camera_shake(0.2, 3,src.world_pos())

# =============================================================================
# END GAME
# =============================================================================
func _end_game(winner_team: int) -> void:
	if not GameState.running: return
	_cancel_pending_skill()
	play_sfx("victory" if winner_team == GameState.player.team else "defeat")
	sound_fx.announce("victory_voice" if winner_team == GameState.player.team else "defeat_voice")
	GameState.running = false
	award_match_credits(winner_team == GameState.player.team, GameState.player.kills)
	if not LanSession.is_client():archive_report=BuildStealer.record_match(winner_team)
	LanSession.finish(winner_team)
	hud.get_node("HudRoot").show_end_screen(winner_team == GameState.player.team)
	if GameState.is_pvp():
		hud.get_node("HudRoot").end_stats.text+="\n%dv%d PVP • %s TEAM\nEqual starting stats • PvE progression unaffected" % [GameState.team_size,GameState.team_size,"BLUE" if GameState.player.team==BLUE else "RED"]
	else:
		hud.get_node("HudRoot").end_stats.text += "\nN%d  •  +%d permanent credits  •  Balance: %d\n%s" % [GameState.difficulty, Progression.last_reward, Progression.credits, Progression.save_error]
		hud.get_node("HudRoot").end_stats.text += "\n"+Progression.drop_summary()
		if not archive_report.is_empty():hud.get_node("HudRoot").end_stats.text+="\n"+archive_report
	hud.get_node("HudRoot").end_stats.text=hud.get_node("HudRoot").end_stats.text.replace("\n\n","\n").strip_edges()
	if in_game_menu != null: in_game_menu.visible = false
	camera_shake(1.0, 12.0)
	if winner_team == GameState.player.team:
		camera_flash(1.2, Color(1.0, 0.86, 0.52))
	else:
		camera_flash(1.2, Color(0.5, 0.1, 0.1))

# =============================================================================
# INLINE FX NODE CLASSES
# =============================================================================
class _PuffFx extends Node2D:
	var fx_kind := "puff"
	var col: Color = Color.WHITE
	var sz: float = 6
	var life: float = 0.3
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		modulate.a = max(0.0, 1.0 - elapsed / life)
		scale = Vector2.ONE * (1.0 - elapsed / life * 0.5)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		draw_circle(Vector2.ZERO, sz, Color(col.r, col.g, col.b, 0.5))

class _ImpactFx extends Node2D:
	var fx_kind := "impact"
	var col: Color = Color.WHITE
	var start_sz: float = 12
	var life: float = 0.2
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		modulate.a = max(0.0, 1.0 - elapsed / life)
		scale = Vector2.ONE * (1.0 + elapsed / life*.15)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		var atlas=CombatFeedbackArt.impact_texture()
		var region=CombatFeedbackArt.frame(atlas,1,mini(3,int(elapsed/life*4.)),4)
		draw_texture_rect_region(atlas,Rect2(-start_sz,-start_sz,start_sz*2.,start_sz*2.),region,Color(1,1,1,.75))

class _TargetRing extends Node2D:
	var fx_kind := "target_ring"
	var life: float = 0.4
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		scale = Vector2.ONE * (1.0 + elapsed / life * 1.5)
		modulate.a = max(0.0, 1.0 - elapsed / life)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(1.0, 0.86, 0.52), 2.5, true)

class _LevelUpRing extends Node2D:
	var fx_kind := "levelup_ring"
	var life: float = 0.6
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		scale = Vector2.ONE * (1.0 + elapsed / life * 4.0)
		modulate.a = max(0.0, 1.0 - elapsed / life)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(1.0, 0.86, 0.33), 3.5, true)
		draw_circle(Vector2.ZERO, 22, Color(1.0, 0.86, 0.33, 0.3))

class _FlashFx extends Node2D:
	var fx_kind := "flash"
	var life: float = 0.3
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		scale = Vector2.ONE * (1.0 + elapsed / life * 2.0)
		modulate.a = max(0.0, 1.0 - elapsed / life)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		draw_circle(Vector2.ZERO, 28, Color(1.0, 1.0, 0.8, 0.75))
		draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color.WHITE, 2.0, true)

class _ReticleLayer extends Node2D:
	var main
	var fx_kind := "reticles"
	var _drew := true   # the previous redraw had something to draw (perf: idle 3D frames skip the redraw)
	func _process(_delta):
		var busy = _busy()
		if busy or _drew: queue_redraw()
		_drew = busy
	# True when _draw would draw anything. Classic 2D always redraws (cursor hover scan and captions).
	func _busy() -> bool:
		if not GameState.running: return false
		var p = GameState.player
		if p == null or p.dead: return false
		if not (main != null and main.view3d != null and main.view3d.is_active()): return true
		if GameState.attack_move_pending: return true
		if is_instance_valid(GameState.hover_unit) and not GameState.hover_unit.dead: return true
		if is_instance_valid(p.attack_target) and not p.attack_target.dead: return true
		return p.hero_key in ["leesin","thresh"] and not NewHeroKits.recast_info(p,0).is_empty()
	func _draw():
		if not GameState.running: return
		# Hover reticle: unit nearest to cursor
		var three_d = main != null and main.view3d != null and main.view3d.is_active()
		var mouse = GameState.cursor_world if three_d else get_global_mouse_position()
		var p = GameState.player
		if p == null or p.dead: return
		# One last-hit scan per frame: ReticleText.labels applies the same creep filter as the arcs below, and
		# classic 2D draws those captions too.
		var captions = null
		if GameState.attack_move_pending:
			draw_circle(p.world_pos(), p.effective_attack_range(), Color(1, 0.75, 0.25, 0.035))
			draw_arc(p.world_pos(), p.atk_range, 0, TAU, 128, Color(1, 0.75, 0.25, 0.65), 1.5, true)
			var candidate = GameState.find_attack_move_target(p, mouse, true)
			if candidate == null: candidate = GameState.find_attack_move_target(p, mouse)
			if candidate != null:
				draw_arc(candidate.world_pos(), candidate.size + 12, 0, TAU, 32, Color(1, 0.85, 0.3), 3, true)
			captions = ReticleText.labels(mouse)
			for item in captions:
				if item.text == "LAST HIT":
					var creep = item.unit
					draw_arc(creep.world_pos(), creep.size + 5, 0, TAU, 32, Color(1, 0.85, 0.2), 2.5, true)
		var mark = NewHeroKits.recast_info(p,0)
		if p.hero_key in ["leesin","thresh"] and not mark.is_empty():
			var target = mark.target
			var position = target.world_pos()
			draw_arc(position,target.size+14,-PI/2,-PI/2+TAU*clampf(mark.time/mark.duration,0,1),48,Color("95f2eb"),4,true)
		var hover_u = null
		if three_d:
			if is_instance_valid(GameState.hover_unit) and not GameState.hover_unit.dead: hover_u = GameState.hover_unit
		else: hover_u = _find_hover(mouse)
		if hover_u != null:
			var col = Color(1, 0.3, 0.3, 0.9) if hover_u.team != p.team else Color(0.3, 1, 0.3, 0.9)
			var r = hover_u.size + 4
			draw_arc(hover_u.world_pos(), r, 0, TAU, 32, col, 2.0, true)
			# Crosshair ticks
			for i in range(4):
				var a = i * PI / 2
				var p0 = hover_u.world_pos() + Vector2(cos(a), sin(a)) * (r + 2)
				var p1 = hover_u.world_pos() + Vector2(cos(a), sin(a)) * (r + 8)
				draw_line(p0, p1, col, 2.0, true)
		# Attack-target reticle (persistent while attacking)
		if is_instance_valid(p.attack_target) and not p.attack_target.dead:
			var t = p.attack_target
			var tr = t.size + 7
			var tc = Color(1, 0.3, 0.3, 0.8)
			var ang_offset = Time.get_ticks_msec() / 500.0
			for i in range(4):
				var a0 = ang_offset + i * PI / 2 - 0.3
				var a1 = ang_offset + i * PI / 2 + 0.3
				draw_arc(t.world_pos(), tr, a0, a1, 8, tc, 2.5, true)
		if not three_d: ReticleText.draw_2d(self, captions if captions != null else ReticleText.labels(mouse))

	var _reach := {}   # unit instance id -> Vector2(size, farthest click-rect point from its feet, art px)
	func _find_hover(mouse: Vector2):
		# Perf: GameState.find_target_at measures every unit's click rect; skip it while no live unit can reach the
		# cursor (each reach bounds the art rect for either facing, the feet rect and the 8 px pick padding).
		for lst in [GameState.champions, GameState.minions, GameState.structures]:
			for unit in lst:
				if is_instance_valid(unit) and not unit.dead and unit.world_pos().distance_to(mouse) <= _reach_of(unit) + 12.0:
					return GameState.find_target_at(mouse,-1,8)
		return null
	func _reach_of(unit) -> float:
		if unit.kind == "structure":
			var ar: Rect2 = unit.art_rect
			return Vector2(maxf(absf(ar.position.x), absf(ar.end.x)), maxf(absf(ar.position.y), absf(ar.end.y))).length()
		var id = unit.get_instance_id()
		var size = float(unit.size)
		var cached = _reach.get(id)
		if cached != null and cached.x == size: return cached.y
		var rects = [Picker3D._body_rect_facing(unit, false), Picker3D._body_rect_facing(unit, true), Rect2(-Vector2(size * 0.7, 6), Vector2(size * 1.4, 12))]
		var reach = 0.0
		for r in rects:
			reach = maxf(reach, Vector2(maxf(absf(r.position.x), absf(r.end.x)), maxf(absf(r.position.y), absf(r.end.y))).length())
		if _reach.size() > 512: _reach.clear()
		_reach[id] = Vector2(size, reach)
		return reach

class _BurstParticle extends Node2D:
	var fx_kind := "burst_particle"
	var vel: Vector2 = Vector2.ZERO
	var col: Color = Color.WHITE
	var life: float = 0.7
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		global_position += vel * delta
		vel *= 0.9
		modulate.a = max(0.0, 1.0 - elapsed / life)
		queue_redraw()
		if elapsed >= life: queue_free()
	func _draw():
		var sz = 4.0 * (1.0 - elapsed / life)
		draw_circle(Vector2.ZERO, sz, col)


func _build_in_game_menu() -> void:
	in_game_menu = CanvasLayer.new()
	in_game_menu.layer = 40
	add_child(in_game_menu)
	var button = Button.new()
	button.text = "MENU / UPGRADES  [M]"
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -270
	button.offset_right = -20
	button.offset_top = 14
	button.offset_bottom = 60
	in_game_menu.add_child(button)
	button.pressed.connect(toggle_in_game_menu)

func _input(event: InputEvent) -> void:
	if is_instance_valid(match_loader) and is_instance_valid(match_loader.overlay) and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode==KEY_ESCAPE:_return_to_main_menu()
		if event.keycode!=KEY_F11 and not (event.keycode==KEY_ENTER and event.alt_pressed):
			get_viewport().set_input_as_handled();return
	if pending_skill >= 0:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			_cancel_pending_skill()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_TAB and GameState.started:
		var ui = hud.get_node("HudRoot")
		if event.pressed and not event.echo and not GameState.paused: ui.set_scoreboard_visible(true)
		elif not event.pressed: ui.set_scoreboard_visible(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not Progression.fullscreen_enabled)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _close_confirmation(): get_viewport().set_input_as_handled(); return
		if is_instance_valid(menu) and menu.has_node("BuildLibrary"):
			menu.get_node("BuildLibrary").queue_free();get_viewport().set_input_as_handled();return
		if not GameState.started:
			if menu_page == "heroes": _back_from_heroes()
			elif menu_page in ["upgrades","equipment","pvp"]: _show_main_menu()
			elif menu_page in ["lobby","steam"]: LanSession.leave(); _show_main_menu()
			get_viewport().set_input_as_handled()
			return
	if in_game_menu == null or not GameState.started: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if in_game_menu.has_node("MatchPanel/UpgradeLayer"):
				var upgrades = in_game_menu.get_node("MatchPanel/UpgradeLayer")
				upgrades.get_parent().remove_child(upgrades); upgrades.queue_free()
			elif in_game_menu.has_node("MatchPanel"): toggle_in_game_menu()
			elif hud.get_node("HudRoot").scoreboard.visible: hud.get_node("HudRoot").set_scoreboard_visible(false)
			elif hud.get_node("HudRoot").shop_open: hud.get_node("HudRoot").close_shop()
			elif lane_augments != null and lane_augments.panel.visible: lane_augments.panel.hide()
			elif attack_move_pending: attack_move_pending = false
			else: toggle_in_game_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			toggle_in_game_menu()
			get_viewport().set_input_as_handled()

func toggle_in_game_menu() -> void:
	_cancel_pending_skill()
	hud.get_node("HudRoot").set_scoreboard_visible(false)
	if in_game_menu.has_node("MatchPanel"):
		var panel = in_game_menu.get_node("MatchPanel")
		in_game_menu.remove_child(panel)
		panel.queue_free()
		GameState.paused = menu_was_paused if GameState.running else false
		return
	menu_was_paused = GameState.paused
	GameState.paused = not LanSession.active
	attack_move_pending = false
	var panel = ColorRect.new()
	panel.name = "MatchPanel"
	panel.color = Color(0.015, 0.025, 0.05)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	in_game_menu.add_child(panel)
	RiftMenus.pause(self,panel)

func change_match_difficulty(stage: int) -> void:
	# Kept for callers: a started run cannot change its enemies or reward stage.
	if GameState.started or LanSession.is_client(): return
	Progression.difficulty = clampi(stage, 1, 99)
	Progression.save_profile()


func announce_kill(event: String, team: int, hero_name: String,killer=null) -> void:
	LanSession.send_effect("announce",killer,Vector2.ZERO,{"event":event,"team":team,"hero":hero_name})
	var friendly = GameState.player != null and GameState.player.team == team
	var key = event if event != "slain" else ("enemy_slain" if friendly else "ally_slain")
	if event=="slain" and friendly and is_instance_valid(killer) and killer!=GameState.player:key="team_enemy_slain"
	sound_fx.announce(key)
	var titles = kill_announcer.TITLES
	var title = titles.get(event,"CHAMPION SLAIN")
	if event == "slain": title = "ENEMY SLAIN" if friendly else "ALLY SLAIN"
	hud.get_node("HudRoot").show_announcement(title,hero_name,team)

func play_sfx(event: String, actor = null) -> void:
	LanSession.send_effect("sound",actor,Vector2.ZERO,{"event":event})
	if sound_fx != null: sound_fx.play(event, actor)


func set_fullscreen(enabled: bool, persist_change: bool = true) -> void:
	var changed = Progression.fullscreen_enabled != enabled
	Progression.fullscreen_enabled = enabled
	if changed and persist_change: Progression.save_profile()
	if DisplayServer.get_name() != "headless":
		var mode=DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode()!=mode:DisplayServer.window_set_mode(mode)
	for overlay in [menu, in_game_menu]:
		if not is_instance_valid(overlay): continue
		for control in overlay.find_children("*", "CheckButton", true, false):
			if control.text.begins_with("FULLSCREEN"): control.set_pressed_no_signal(enabled)


var spell_hit_times: Dictionary = {}
func spawn_spell_burst(source, point: Vector2, radius: float = 40.0) -> void:
	LanSession.send_effect("burst",source,point,{"radius":radius})
	var row = SpellArt.row_for(source)
	if row < 0: return
	var key = source.get_instance_id()
	var now = Time.get_ticks_msec()
	if now - int(spell_hit_times.get(key, -1000)) < 80: return
	spell_hit_times[key] = now
	var burst = load("res://scripts/WindBurst.gd" if source.hero_key == "yasuo" else "res://scripts/SpellBurst.gd").new()
	burst.row = 0 if source.hero_key == "yasuo" else row
	burst.radius = radius
	world_root.add_child(burst)
	burst.global_position = point

func spawn_minion_hit(point: Vector2) -> void:
	LanSession.send_effect("minion_hit",null,point)
	var hit = preload("res://scripts/MinionHit.gd").new()
	hit.global_position = point
	world_root.add_child(hit)

func spawn_melee_strike(source, point: Vector2, light_hit: bool = false) -> void:
	LanSession.send_effect("melee",source,point,{"light_hit":light_hit})
	var strike = load("res://scripts/MeleeStrike.gd").new()
	strike.origin = source.world_pos()
	strike.contact = point
	strike.color = source.hero.accent
	strike.light_hit = light_hit
	world_root.add_child(strike)

func begin_attack_move() -> void:
	if GameState.running and not GameState.paused: attack_move_pending = true

func _show_main_menu() -> void:
	RiftMenus.start(self)
func _show_lobby() -> void:
	RiftMenus.lobby(self)
func _back_from_heroes() -> void:
	if LanSession.active: _show_lobby()
	else: _show_main_menu()
func _refresh_lobby() -> void:
	if menu_page != "lobby" or not is_instance_valid(menu_status): return
	menu_status.text = LanSession.status
	if LanSession.is_pvp():
		var local=LanSession.local_config()
		if is_instance_valid(lobby_team):lobby_team.select(int(local.get("team",0)));lobby_team.disabled=local.is_empty()
		if is_instance_valid(lobby_ready):lobby_ready.text="UNREADY" if local.get("ready",false) else "READY";lobby_ready.disabled=local.is_empty()
		if is_instance_valid(lobby_size):lobby_size.select(int(LanSession.rules.team_size)-1)
		if is_instance_valid(lobby_bots):lobby_bots.set_pressed_no_signal(bool(LanSession.rules.fill_bots))
		for team in range(2):
			var lines: PackedStringArray=[]
			for config in LanSession.players.values():
				if config.get("team",0)==team:lines.append("%s • %s • %s" % [config.name,ChampionData.CHAMPIONS[config.hero].name,"READY" if config.ready else "Choosing"])
			for slot in range(lines.size(),int(LanSession.rules.team_size)):lines.append("Empty • AI" if LanSession.rules.fill_bots else "Empty • waiting for player")
			if team<lobby_team_rosters.size() and is_instance_valid(lobby_team_rosters[team]):lobby_team_rosters[team].text="\n".join(lines)
		if is_instance_valid(lobby_hint):lobby_hint.text=LanSession.start_error() if not LanSession.start_error().is_empty() else "Both teams ready • host can start."
	else:
		var entries: PackedStringArray = []
		for config in LanSession.players.values():entries.append("%s • %s • %s" % [config.get("name","Player"),ChampionData.CHAMPIONS[config.hero].name,"READY" if config.get("ready",false) else "Choosing hero"])
		lobby_roster.text="\n".join(entries)
	lobby_start.disabled=not LanSession.can_start()

func _show_equipment() -> void:
	if GameState.started:return
	var root=RiftMenus.backdrop(self,"equipment")
	var screen=load("res://scripts/EquipmentMenu.gd").new()
	screen.game=self;root.add_child(screen)

func _show_start_upgrades() -> void:
	var root = RiftMenus.backdrop(self,"upgrades")
	_build_progression_menu(root)
	# The account menu opens directly instead of requiring a second click.
	root.get_child(root.get_child_count()-1).show()
	var back = Button.new()
	back.text = "MAIN MENU [ESC]"
	back.position = Vector2(20,20)
	back.custom_minimum_size = Vector2(260,60)
	back.pressed.connect(_show_main_menu)
	root.add_child(back)
func _show_pause_upgrades() -> void:
	if not in_game_menu.has_node("MatchPanel"): return
	var layer = Control.new()
	layer.name = "UpgradeLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	in_game_menu.get_node("MatchPanel").add_child(layer)
	_build_progression_menu(layer,true)
func _request_return() -> void:
	_request_confirmation("ReturnConfirmation",("Return to main menu?\nThis unfinished match will not award credits." if GameState.running and not GameState.is_pvp() else "Return to main menu?") + ("\nLeaving as host ends the multiplayer session." if LanSession.is_host() else ""),_return_to_main_menu)
func _request_quit() -> void:
	_request_confirmation("QuitConfirmation","Quit Howling Rift?" + ("\nThis unfinished match will not award credits." if GameState.running else ""),func(): LanSession.leave(); get_tree().quit())
func _request_confirmation(id: String, text: String, action: Callable) -> void:
	if has_node(id): return
	var dialog = ConfirmationDialog.new()
	dialog.name = id
	dialog.title = "Howling Rift"
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.exclusive = true
	dialog.get_label().add_theme_font_size_override("font_size",22)
	dialog.get_ok_button().add_theme_font_size_override("font_size",22)
	dialog.get_cancel_button().add_theme_font_size_override("font_size",22)
	dialog.get_ok_button().custom_minimum_size = Vector2(160,48)
	dialog.get_cancel_button().custom_minimum_size = Vector2(160,48)
	dialog.confirmed.connect(func(): dialog.queue_free(); action.call())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(620,240))
func _close_confirmation() -> bool:
	for id in ["ReturnConfirmation","QuitConfirmation"]:
		if has_node(id):
			var dialog = get_node(id)
			remove_child(dialog); dialog.queue_free()
			return true
	return false
func _return_to_main_menu() -> void:
	match_load_serial+=1
	if is_instance_valid(match_loader):match_loader.cancel()
	match_loader=null
	_cancel_pending_skill()
	var sound_enabled = sound_fx.enabled if is_instance_valid(sound_fx) else true
	_reset_camera_shake()
	hero_impact_times.clear()
	spell_hit_times.clear()
	LanSession.leave()
	GameState.reset()
	for child in get_children():
		remove_child(child); child.queue_free()
	hero_cards.clear()
	summoner_selectors.clear()
	in_game_menu = null
	lane_augments = null
	menu = null
	network_config.clear()
	economy_timer = 0
	attack_move_pending = false
	_ready()
	sound_fx.set_enabled(sound_enabled)

func _start_network_match(config: Dictionary) -> void:
	network_config = config.duplicate(true)
	for player in config.players:
		if player.peer == multiplayer.get_unique_id():
			selected_hero = player.hero
			selected_summoners = player.spells.duplicate()
	_launch_game(selected_hero)

var hero_impact_times: Dictionary={}
func spawn_hero_impact(point: Vector2,row: int,radius: float,angle: float=0.,victim=null) -> void:
	if is_instance_valid(victim):
		victim.hit_flash=maxf(victim.hit_flash,.14)
		var key=victim.get_instance_id();var now=Time.get_ticks_msec()
		if now-int(hero_impact_times.get(key,-1000))<55:return
		hero_impact_times[key]=now
	LanSession.send_effect("hero_impact",victim,point,{"row":row,"radius":radius,"angle":angle})
	var fx=load("res://scripts/HeroImpact.gd").new()
	fx.row=row;fx.radius=radius;fx.angle=angle;fx.duration=.55 if row==3 else .26
	world_root.add_child(fx);fx.global_position=point
