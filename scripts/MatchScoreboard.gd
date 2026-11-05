extends PanelContainer
# Live per-player stats. The host's replicated champion state also drives LAN guests.
var rows: Dictionary = {}
var summary: Label
signal close_requested
func text_label(text: String, width: float, font: int = 20) -> Label:
 var result = Label.new()
 result.text = text
 result.custom_minimum_size.x = width
 result.add_theme_font_size_override("font_size",font)
 result.mouse_filter = Control.MOUSE_FILTER_IGNORE
 result.clip_text = true
 return result
func _ready() -> void:
 name = "MatchScoreboard"
 anchor_left = 0.5
 anchor_right = 0.5
 offset_left = -620
 offset_right = 620
 offset_top = 130
 offset_bottom = 830
 custom_minimum_size = Vector2(1240,0)
 z_index = 150
 mouse_filter = Control.MOUSE_FILTER_STOP
 var style = StyleBoxFlat.new()
 style.bg_color = Color("07131ff7")
 style.border_color = Color("aa935d")
 style.set_border_width_all(2)
 style.set_content_margin_all(18)
 add_theme_stylebox_override("panel",style)
 var column = VBoxContainer.new()
 column.add_theme_constant_override("separation",10)
 add_child(column)
 var heading = HBoxContainer.new()
 column.add_child(heading)
 summary = text_label("MATCH SCOREBOARD",980,24)
 summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(summary)
 var close = Button.new()
 close.text = "CLOSE"
 close.focus_mode = Control.FOCUS_NONE
 close.add_theme_font_size_override("font_size",18)
 close.pressed.connect(func(): close_requested.emit())
 heading.add_child(close)
 column.add_child(text_label("Hold TAB to view • click the team score to toggle • match keeps running",0,16))
 for team in [Constants.BLUE,Constants.RED]:
  var team_header = text_label("BLUE TEAM" if team == Constants.BLUE else "RED TEAM",0,20)
  team_header.add_theme_color_override("font_color",Constants.TEAM_COLOR[team])
  column.add_child(team_header)
  var headings = HBoxContainer.new()
  headings.add_theme_constant_override("separation",12)
  column.add_child(headings)
  for entry in [["HERO / PLAYER",284],["LV",42],["K / D / A",148],["CS",64],["GOLD",90],["ITEMS",300]]:
   headings.add_child(text_label(entry[0],entry[1],15))
  for champion in GameState.champions:
   if champion.team != team: continue
   var panel = PanelContainer.new()
   var plate = StyleBoxFlat.new()
   plate.bg_color = Color("102c3c") if team == Constants.BLUE else Color("301b27")
   plate.set_content_margin_all(6)
   panel.add_theme_stylebox_override("panel",plate)
   column.add_child(panel)
   var row = HBoxContainer.new()
   row.add_theme_constant_override("separation",12)
   panel.add_child(row)
   var portrait = TextureRect.new()
   var crop = AtlasTexture.new()
   crop.atlas = champion.champion_texture
   crop.region = Rect2(0,0,champion.champion_texture.get_width(),champion.champion_texture.get_width())
   portrait.texture = crop
   portrait.custom_minimum_size = Vector2(52,52)
   portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
   row.add_child(portrait)
   var hero = text_label("",220,18)
   row.add_child(hero)
   var level = text_label("",42)
   row.add_child(level)
   var kda = text_label("",148)
   row.add_child(kda)
   var cs = text_label("",64)
   row.add_child(cs)
   var gold = text_label("",90)
   row.add_child(gold)
   var icons = []
   for i in range(6):
    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(40,40)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)
    icons.append(icon)
   rows[champion] = {"hero":hero,"level":level,"kda":kda,"cs":cs,"gold":gold,"icons":icons,"portrait":portrait,"panel":panel}
 refresh()
func refresh() -> void:
 summary.text = "BLUE %d  —  %d RED     •     MATCH SCOREBOARD" % [GameState.score[0],GameState.score[1]]
 for champion in rows:
  if not is_instance_valid(champion): continue
  var row = rows[champion]
  row.panel.visible = champion.roster_active
  if not champion.roster_active: continue
  var state = " • Respawn %ds" % maxi(0,ceili(champion.respawn_at-GameState.time)) if champion.dead else ""
  row.hero.text = champion.hero.name+"\n"+champion.char_name+state
  row.level.text = str(champion.level)
  row.kda.text = "%d / %d / %d" % [champion.kills,champion.deaths,champion.assists]
  row.cs.text = str(champion.cs)
  row.gold.text = "%dg" % int(champion.gold)
  row.gold.tooltip_text="Bonus gold from defeats: %dg · Last grant: %dg" % [champion.comeback_gold_awarded,champion.last_comeback_gold]
  row.level.tooltip_text="Level %d / %d · XP gain x%.2f" % [champion.level,Constants.MAX_LEVEL,champion.difficulty_stats.get("experience",1.) if champion.is_bot and champion.team==Constants.RED and not GameState.is_pvp() else 1.]
  row.hero.tooltip_text="Enemy comeback gold starts at death 11 and increases every death." if champion.is_bot and champion.team==Constants.RED and not GameState.is_pvp() else ""
  if not champion.stolen_blueprint.is_empty():row.hero.tooltip_text=BuildStealer.tooltip(champion.stolen_blueprint)
  row.portrait.modulate = Color(0.4,0.4,0.4) if champion.dead else Color.WHITE
  for i in range(6):
   var id = champion.inventory[i]
   row.icons[i].texture = ShopArt.item_icon(id)
   row.icons[i].tooltip_text = ItemData.ITEMS[id].name+"\n"+ItemData.ITEMS[id].desc if id != "" else "Empty item slot"
