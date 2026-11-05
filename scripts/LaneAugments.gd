extends Node
# Build variety inside a continuous MOBA match. Drafts never stop the lane.

const MILESTONES = [4, 6, 8, 10, 12, 14, 16, 18]
const AUGMENTS = [

	{"name": "Rapid Fire", "desc": "+25% attack speed", "stats": {"bonus_as": 0.25}},
	{"name": "Spellweaver", "desc": "+30 ability power", "stats": {"bonus_ap": 30.0}},
	{"name": "Vampiric Edge", "desc": "+10% lifesteal and +8 attack damage", "stats": {"bonus_lifesteal": 0.1, "bonus_ad": 8.0}},
	{"name": "Iron Vanguard", "desc": "+25 armor and +100 max health", "stats": {"bonus_armor": 25.0, "bonus_hp": 100.0}},
	{"name": "Fleet Footwork", "desc": "+12% movement speed", "stats": {"bonus_ms": 0.12}},
	{"name": "Heavy Hitter", "desc": "+25 attack damage", "stats": {"bonus_ad": 25.0}},
	{"name": "Arcane Battery", "desc": "+180 mana and +20 ability power", "stats": {"bonus_mp": 180.0, "bonus_ap": 20.0}},
	{"name": "Relentless", "desc": "+10% cooldown reduction (40% cap)", "stats": {"bonus_cdr": 0.1}},
	{"name": "Second Wind", "desc": "+150 max health and +3 health regeneration", "stats": {"bonus_hp": 150.0, "bonus_hp_regen": 3.0}},
	{"name": "Stonebound", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp": 250.0, "bonus_armor": 12.0}},
	{"name": "Runic Bastion", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp": 200.0, "bonus_mr": 20.0}},
	{"name": "Unbreakable", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_armor": 18.0, "bonus_mr": 18.0}},
	{"name": "Deep Reserves", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp": 350.0}},
	{"name": "Restoring Guard", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp_regen": 6.0, "bonus_mr": 12.0}},
	{"name": "Frontline Engine", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp": 150.0, "bonus_cdr": 0.06}},
	{"name": "Heavy Guard", "desc": "Rolled combat stats", "role": "tank", "stats": {"bonus_hp": 180.0, "bonus_ad": 14.0}},
	{"name": "Arcane Surge", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 45.0}},
	{"name": "Spell Reservoir", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 24.0, "bonus_mp": 240.0}},
	{"name": "Spell Tempo", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 20.0, "bonus_cdr": 0.06}},
	{"name": "Battle Mage", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 24.0, "bonus_hp": 160.0}},
	{"name": "Runic Mobility", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 18.0, "bonus_ms": 0.06}},
	{"name": "Arcane Ward", "desc": "Rolled combat stats", "role": "caster", "stats": {"bonus_ap": 22.0, "bonus_mr": 16.0}},
	{"name": "Spellfighter", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_ad": 18.0, "bonus_cdr": 0.06}},
	{"name": "Brawlers Heart", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_ad": 18.0, "bonus_hp": 180.0}},
	{"name": "Relentless Duelist", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_as": 0.18, "bonus_lifesteal": 0.05}},
	{"name": "Steel and Fury", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_ad": 16.0, "bonus_armor": 16.0}},
	{"name": "Skirmish Runner", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_ad": 14.0, "bonus_ms": 0.07}},
	{"name": "Sustained Fighter", "desc": "Rolled combat stats", "role": "bruiser", "stats": {"bonus_ad": 12.0, "bonus_hp_regen": 4.0}},
	{"name": "Precision Rhythm", "desc": "Rolled combat stats", "role": "marksman", "stats": {"bonus_as": 0.2, "bonus_crit": 0.08}},
	{"name": "Sharpened Edge", "desc": "Rolled combat stats", "role": "marksman", "stats": {"bonus_ad": 20.0, "bonus_crit": 0.07}},
 {"name":"Blessed Hands","desc":"Rolled support stats","role":"support","stats":{"bonus_heal_power":.1,"bonus_ap":15.}},
 {"name":"Enduring Grace","desc":"Rolled support stats","role":"support","stats":{"bonus_heal_power":.07,"bonus_hp":150.}},
 {"name":"Mana Spring","desc":"Rolled support stats","role":"support","stats":{"bonus_mp_regen":3.,"bonus_cdr":.05}}
]

var main
var awarded: Dictionary = {}
var pending: Array = []
var choices: Array = []
var offers: Dictionary = {}
var picked: Array = []
var panel: PanelContainer
var content: VBoxContainer
var badge: Button
var ready_prompt: Button
var ready_style: StyleBoxFlat
var idle_style: StyleBoxFlat
var attention_phase: float = 0.0
var objective: Label
var rng = RandomNumberGenerator.new()

func setup(game) -> void:
	main = game
	rng.randomize()
	var layer = CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	badge = Button.new()
	badge.position = Vector2(280, 14)
	badge.custom_minimum_size = Vector2(300, 48)
	badge.add_theme_font_size_override("font_size", 20)
	badge.focus_mode = Control.FOCUS_NONE
	badge.pressed.connect(toggle_panel)
	idle_style = StyleBoxFlat.new()
	idle_style.bg_color = Color("102032")
	idle_style.border_color = Color("465467")
	idle_style.set_border_width_all(1)
	idle_style.set_corner_radius_all(5)
	ready_style = StyleBoxFlat.new()
	ready_style.bg_color = Color("493416")
	ready_style.border_color = Color("f5d178")
	ready_style.set_border_width_all(3)
	ready_style.set_corner_radius_all(6)
	ready_style.shadow_color = Color(1,0.65,0.2,0.3)
	ready_style.shadow_size = 10
	badge.tooltip_text = "Level up to earn a choice of three build upgrades. Click or press U."
	root.add_child(badge)
	ready_prompt = Button.new()
	ready_prompt.name = "BuildReadyPrompt"
	root.add_child(ready_prompt)
	ready_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ready_prompt.offset_left = -340; ready_prompt.offset_right = 340
	ready_prompt.offset_top = 112; ready_prompt.offset_bottom = 168
	ready_prompt.text = "BUILD UPGRADE READY • CHOOSE NOW [U]"
	ready_prompt.add_theme_font_size_override("font_size",23)
	ready_prompt.add_theme_color_override("font_color",Color("fff3cc"))
	ready_prompt.focus_mode = Control.FOCUS_NONE
	ready_prompt.pressed.connect(toggle_panel)
	ready_prompt.hide()
	objective = Label.new()
	objective.position = Vector2(550, 65)
	objective.add_theme_font_size_override("font_size", 17)
	objective.add_theme_color_override("font_color", Color("e5cf92"))
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective)
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -290; panel.offset_right = 290
	panel.offset_top = 190
	panel.custom_minimum_size = Vector2(580, 260)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.085, 0.97)
	style.border_color = Color("bb9b51")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	panel.hide()
	main.hud.get_node("HudRoot").side_tip.hide()

func _process(delta: float) -> void:
	if not GameState.started: return
	if not GameState.paused: attention_phase += delta
	refresh_attention()
	badge.visible = GameState.running
	objective.visible = GameState.running and not main.hud.get_node("HudRoot").shop_open
	if not GameState.running:
		panel.hide()
		return
	var next = null
	for structure in GameState.structures:
		if structure.team != GameState.player.team and structure.is_structure_attackable():
			if next == null or structure.world_pos().distance_to(GameState.player.world_pos()) < next.world_pos().distance_to(GameState.player.world_pos()): next = structure
	objective.text = "Push with your wave • %s: %d / %d HP" % [next.type.replace("_", " ").to_upper(), next.hp, next.hp_max] if next != null else "Destroy the enemy nexus"

func refresh_attention() -> void:
	var ready = not pending.is_empty()
	badge.text = "★ BUILD READY (%d) [U]" % pending.size() if ready else "NEXT BUILD: LV %s [U]" % str(next_milestone())
	badge.add_theme_color_override("font_color",Color("fff1bb") if ready else Color("b9c6d6"))
	var glow = 0.5+0.5*sin(attention_phase*3.0)
	ready_style.border_color = Color(1,0.74+glow*0.15,0.35+glow*0.15)
	ready_style.shadow_color = Color(1,0.65,0.2,0.15+glow*0.2)
	for state in ["normal", "hover", "pressed"]:
		badge.add_theme_stylebox_override(state,ready_style if ready else idle_style)
		ready_prompt.add_theme_stylebox_override(state,ready_style)
	ready_prompt.visible = ready and GameState.running and not GameState.paused and not panel.visible and not main.hud.get_node("HudRoot").shop_open and not main.hud.get_node("HudRoot").announcement.visible and not main.in_game_menu.has_node("MatchPanel")
	ready_prompt.tooltip_text = "%d unspent level-up build choice(s). Select one of three upgrades." % pending.size()

func next_milestone():
	for threshold in MILESTONES:
		if GameState.player.level < threshold: return threshold
	return "MAX"
func on_level_up(champion) -> void:
	if not MILESTONES.has(champion.level): return
	if not awarded.has(champion): awarded[champion] = []
	if awarded[champion].has(champion.level): return
	awarded[champion].append(champion.level)
	if champion == GameState.player:
		pending.append(champion.level)
		main.floating_text(champion.world_pos(), "LEVEL %d • CHOOSE BUILD [U]" % champion.level, Color("efce82"))
		if panel.visible: build_panel()
		refresh_attention()
	else:
		var copied=BuildStealer.upgrade_at(champion,champion.level)
		if not copied.is_empty():apply_augment(champion,copied.index,copied,champion.level)
		else:
			var index=roll_choices(champion)[0]
			apply_augment(champion,index,roll_offer(index,champion.level),champion.level)
# Compatibility entry used by tests: rewards come only from on_level_up.
func refresh_milestones() -> void:
	pass

func apply_augment(champion, index: int, offer: Dictionary = {},earned_level: int=0) -> void:
	var augment = AUGMENTS[index] if offer.is_empty() else offer
	if earned_level in MILESTONES and champion.augment_history.size()<8 and not champion.augment_history.any(func(entry):return entry.level==earned_level):champion.augment_history.append({"level":earned_level,"index":index,"stats":augment.stats.duplicate(true)})
	for stat in augment.stats:
		champion.run_bonus[stat] = champion.run_bonus.get(stat, 0.0) + augment.stats[stat]
	champion._apply_items()

func toggle_panel() -> void:
	if not GameState.running: return
	if panel.visible: panel.hide()
	else:
		build_panel()
		panel.show()
	refresh_attention()

func build_panel() -> void:
	if content != null:
		panel.remove_child(content)
		content.queue_free()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var title = Label.new()
	title.text = "LEVEL %d UPGRADE • CHOOSE ONE" % pending[0] if not pending.is_empty() else "LEVEL-UP BUILDS"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	if not pending.is_empty():
		if choices.is_empty():
			choices = roll_choices(GameState.player)
			for index in choices: offers[index] = roll_offer(index,int(pending[0]))
		for index in choices:
			var button = Button.new()
			button.text = "%s • %s" % [AUGMENTS[index].name, offers.get(index,AUGMENTS[index]).desc]
			button.custom_minimum_size = Vector2(540, 64)
			button.add_theme_font_size_override("font_size", 21)
			button.pressed.connect(func(): choose(index))
			content.add_child(button)
	var history = Label.new()
	history.text = "Picked: " + (", ".join(picked) if not picked.is_empty() else "none • Earn choices at levels 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18")
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history.custom_minimum_size.x = 540
	content.add_child(history)
	var close = Button.new()
	close.text = "BACK TO LANE [U]"
	close.custom_minimum_size.y = 42
	close.pressed.connect(func(): panel.hide())
	content.add_child(close)

func choose(index: int) -> void:
	if LanSession.is_client():
		LanSession.send_command("draft",{"index":index})
		panel.hide()
		return
	if pending.is_empty() or not choices.has(index) or not GameState.running or GameState.paused: return
	apply_augment(GameState.player, index,offers.get(index,{}),int(pending[0]))
	picked.append(AUGMENTS[index].name)
	pending.pop_front()
	choices.clear()
	offers.clear()
	panel.hide()
	refresh_attention()

func role_for(c) -> String:
	if c.hero_key in SupportRoster.KEYS:return "support"
	if c.hero_key in RosterExpansion12.KEYS:return RosterExpansion12.role(c.hero_key)
	if c.hero_key in ["garen","malphite","thresh"]: return "tank"
	if c.hero_key in ["darius","leesin","yasuo","zed"]: return "bruiser"
	if c.hero_key in ["ashe","jinx","vayne","kayle"]: return "marksman"
	return "caster"
func roll_choices(c) -> Array:
	var matching=[];var pool=range(AUGMENTS.size())
	for i in pool:
		if AUGMENTS[i].get("role","")==role_for(c): matching.append(i)
	matching.shuffle();pool.shuffle()
	var result=[]
	if not matching.is_empty():result.append(matching[0])
	for i in pool:
		if not result.has(i):result.append(i)
		if result.size()==3:break
	return result
func roll_offer(index: int, level: int) -> Dictionary:
	var result=AUGMENTS[index].duplicate(true)
	var labels={"bonus_ad":"AD","bonus_ap":"AP","bonus_hp":"HP","bonus_mp":"mana","bonus_armor":"armor","bonus_mr":"magic resist","bonus_as":"attack speed","bonus_ms":"move speed","bonus_crit":"crit chance","bonus_cdr":"cooldown reduction","bonus_lifesteal":"lifesteal","bonus_hp_regen":"HP regen/s","bonus_heal_power":"heal/shield power","bonus_mp_regen":"mana regen/s"}
	var lines=[]
	for stat in result.stats:
		var percent=stat in ["bonus_as","bonus_ms","bonus_crit","bonus_cdr","bonus_lifesteal","bonus_heal_power"]
		var value=float(result.stats[stat])*rng.randf_range(.85,1.2)*(1.+.025*maxi(0,level-4))
		value=roundf(value*100.)/100. if percent else roundf(value)
		result.stats[stat]=value
		lines.append("+%.0f%s %s" % [value*(100 if percent else 1),"%" if percent else "",labels.get(stat,stat)])
	result.desc=", ".join(lines)
	if result.stats.has("bonus_cdr"):result.desc+=" (CDR cap 40%)"
	return result
