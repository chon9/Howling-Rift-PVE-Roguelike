extends Control
# Main menu artwork and controls share a 1920x1080 design, scaled as a unit.
var game
var design: Control
var rewards: Label
const GOLD=Color("c9a764")
const LIGHT=Color("f3ddb0")
const MUTED=Color("a8b0bb")
func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
 var style=StyleBoxFlat.new()
 style.bg_color=fill;style.border_color=border;style.set_border_width_all(width)
 style.content_margin_left=20;style.content_margin_right=20
 style.content_margin_top=10;style.content_margin_bottom=10
 return style
func text(value: String, at: Vector2, font_size: int, color: Color = LIGHT, width: float = 560, serif: bool = false) -> Label:
 var item=Label.new();item.text=value;item.position=at;item.size.x=width
 item.add_theme_font_size_override("font_size",font_size)
 item.add_theme_color_override("font_color",color)
 item.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
 item.add_theme_constant_override("shadow_offset_y",2)
 item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if serif:
  var font=SystemFont.new();font.font_names=PackedStringArray(["Georgia","Noto Serif","DejaVu Serif"])
  item.add_theme_font_override("font",font)
 design.add_child(item);return item
func action(value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false) -> Button:
 var item=Button.new();item.text=value;item.position=at;item.size=dimensions
 item.add_theme_font_size_override("font_size",26 if primary else 22)
 item.add_theme_color_override("font_color",LIGHT)
 item.add_theme_color_override("font_hover_color",Color("fff4d4"))
 item.add_theme_color_override("font_pressed_color",Color("ffffff"))
 item.add_theme_stylebox_override("normal",box(Color("604922") if primary else Color(.025,.045,.072,.92),Color("e1bd77") if primary else Color("6e5d3b"),2 if primary else 1))
 item.add_theme_stylebox_override("hover",box(Color("87672e") if primary else Color("182937"),Color("f1d497"),2))
 item.add_theme_stylebox_override("pressed",box(Color("493719") if primary else Color("0b1721"),GOLD,2))
 item.add_theme_stylebox_override("focus",box(Color(0,0,0,0),Color("fce4a3"),2))
 item.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 item.pressed.connect(callback);design.add_child(item)
 return item
func line(at: Vector2, dimensions: Vector2, color: Color) -> void:
 var item=ColorRect.new();item.position=at;item.size=dimensions;item.color=color
 item.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(item)
func _ready() -> void:
 name="GoldenMainScreen";mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color("07111d")
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
 var art=TextureRect.new();art.name="GoldenRiftBackdrop"
 art.texture=load("res://assets/menu/golden-rift-main-v1.png")
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var backdrop_material=ShaderMaterial.new()
 backdrop_material.shader=load("res://assets/menu/golden-backdrop.gdshader")
 art.material=backdrop_material
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
 design=Control.new();design.name="Design";design.size=Vector2(1920,1080)
 design.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(design)
 line(Vector2(90,50),Vector2(1740,1),Color(.75,.60,.34,.55))
 line(Vector2(90,1015),Vector2(1740,1),Color(.75,.60,.34,.4))
 var crest=TextureRect.new();crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.texture=load("res://assets/branding/howling-rift-icon-v1.png")
 crest.position=Vector2(120,67);crest.size=Vector2(38,38)
 crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.mouse_filter=Control.MOUSE_FILTER_IGNORE
 design.add_child(crest)
 text("H O W L I N G   R I F T",Vector2(172,73),18,GOLD)
 text("HOWLING",Vector2(114,126),74,LIGHT,660,true)
 text("RIFT",Vector2(112,207),108,Color("e1bc72"),660,true)
 line(Vector2(122,339),Vector2(66,3),GOLD)
 text("A R A M   /   P V E   &   P V P",Vector2(122,359),18,GOLD)
 text("One lane. Endless builds.",Vector2(122,394),26,LIGHT)
 text("Fight, earn credits, and grow stronger.",Vector2(122,431),19,MUTED)
 var difficulty=Panel.new();difficulty.name="DifficultyCard"
 difficulty.position=Vector2(120,482);difficulty.size=Vector2(540,105)
 difficulty.add_theme_stylebox_override("panel",box(Color(.02,.04,.065,.94),Color("66583d")))
 difficulty.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(difficulty)
 text("DIFFICULTY",Vector2(142,495),17,GOLD)
 var scale=Progression.scaling(Progression.difficulty)
 var challenge=text("Enemy HP x%.2f • Towers x%.2f" % [scale.health,scale.structure_health],Vector2(142,520),16,MUTED,320)
 var stage=SpinBox.new();stage.name="PreGameDifficulty"
 stage.min_value=1;stage.max_value=99;stage.step=1;stage.value=Progression.difficulty
 stage.position=Vector2(482,496);stage.size=Vector2(155,44)
 var edit=stage.get_line_edit();edit.add_theme_font_size_override("font_size",23)
 edit.add_theme_color_override("font_color",LIGHT)
 edit.add_theme_stylebox_override("normal",box(Color("09121c"),GOLD))
 edit.add_theme_stylebox_override("focus",box(Color("12202c"),LIGHT,2))
 design.add_child(stage)
 stage.tooltip_text=Progression.difficulty_preview(Progression.difficulty)
 text("N",Vector2(458,502),22,GOLD,24)
 rewards=text(Progression.reward_preview(Progression.difficulty),Vector2(142,550),17,Color("d7bb7f"),490)
 stage.value_changed.connect(func(value):
  if GameState.started or LanSession.is_client():return
  Progression.difficulty=clampi(int(value),1,99);Progression.save_profile()
  var next_scale=Progression.scaling(Progression.difficulty)
  challenge.text="Enemy HP x%.2f • Towers x%.2f" % [next_scale.health,next_scale.structure_health]
  stage.tooltip_text=Progression.difficulty_preview(Progression.difficulty)
  rewards.text=Progression.reward_preview(Progression.difficulty))
 action("PLAY SOLO ARAM",Vector2(120,608),Vector2(540,78),func():game._show_menu(),true)
 action("HOST STEAM",Vector2(120,703),Vector2(264,57),func():
  var result=SteamSession.host_game()
  if result!=OK:game.menu_status.text=SteamSession.status if result==ERR_UNAVAILABLE else "Could not host: "+error_string(result))
 action("JOIN STEAM",Vector2(396,703),Vector2(264,57),func():SteamLobbyMenu.show_browser(game))
 action("HOST LAN CO-OP",Vector2(120,773),Vector2(250,56),func():
  var result=LanSession.host_game()
  if result==OK:game._show_lobby()
  else:game.menu_status.text="Could not host: "+error_string(result))
 var address=LineEdit.new();address.name="LanAddress"
 address.position=Vector2(382,773);address.size=Vector2(166,56)
 address.placeholder_text="LAN IP address";address.text=game.last_lan_address
 address.add_theme_font_size_override("font_size",17)
 address.add_theme_color_override("font_color",LIGHT)
 address.add_theme_color_override("font_placeholder_color",MUTED)
 address.add_theme_stylebox_override("normal",box(Color(.025,.045,.07,.95),Color("5b5139")))
 address.add_theme_stylebox_override("focus",box(Color("11212f"),GOLD,2))
 design.add_child(address)
 var join_action=func():
  game.last_lan_address=address.text.strip_edges()
  var result=LanSession.join_game(game.last_lan_address)
  if result==OK:game._show_lobby()
  else:game.menu_status.text="Could not join: "+error_string(result)
 var lan_join=action("JOIN LAN",Vector2(560,773),Vector2(100,56),join_action)
 lan_join.add_theme_font_size_override("font_size",16)
 address.text_submitted.connect(func(_value):join_action.call())
 action("PERMANENT UPGRADES / SETTINGS",Vector2(120,845),Vector2(540,60),func():game._show_start_upgrades())
 var quit_button=action("QUIT GAME",Vector2(120,923),Vector2(540,44),func():game._request_quit())
 quit_button.add_theme_font_size_override("font_size",18)
 quit_button.add_theme_color_override("font_color",MUTED)
 quit_button.add_theme_stylebox_override("normal",box(Color(0,0,0,0),Color(0,0,0,0),0))
 game.menu_status=text(LanSession.status if not LanSession.status.is_empty() else SteamSession.status,Vector2(120,975),16,Color("f1bba4"),620)
 game.menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var steam_status=func():
  if is_instance_valid(game.menu_status) and game.menu_page=="main":game.menu_status.text=SteamSession.status
 SteamSession.changed.connect(steam_status)
 tree_exiting.connect(func():SteamSession.changed.disconnect(steam_status))
 var wallet=Panel.new();wallet.position=Vector2(1510,62);wallet.size=Vector2(300,96)
 wallet.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.88),Color("6e5d3b")))
 wallet.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(wallet)
 text("PERMANENT CREDITS",Vector2(1530,75),16,GOLD,260)
 var balance=text(str(Progression.credits),Vector2(1530,99),32,LIGHT,260,true)
 balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 line(Vector2(1530,144),Vector2(260,1),Color(.75,.60,.34,.5))
 action("DAILY QUESTS / EQUIPMENT",Vector2(1440,180),Vector2(370,58),func():game._show_equipment())
 var bots_card=Panel.new();bots_card.position=Vector2(1440,324);bots_card.size=Vector2(370,102)
 bots_card.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.94),Color("6e5d3b")))
 bots_card.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(bots_card)
 var bots=RiftMenus.bot_picker(design)
 bots.position=Vector2(1455,330);bots.size=Vector2(340,48)
 bots.add_theme_color_override("font_color",GOLD)
 text("Off: humans only vs 3 enemy heroes",Vector2(1455,380),16,MUTED,340)
 var pvp=action("PLAY PVP ARAM",Vector2(1440,450),Vector2(370,64),func():RiftMenus.pvp(game),true)
 pvp.name="PlayPvp";pvp.add_theme_font_size_override("font_size",24)
 var pvp_note=Panel.new();pvp_note.position=Vector2(1440,520);pvp_note.size=Vector2(370,32)
 pvp_note.mouse_filter=Control.MOUSE_FILTER_IGNORE;pvp_note.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.94),Color(0,0,0,0),0));design.add_child(pvp_note)
 text("1v1 / 2v2 / 3v3 • Equal starting stats",Vector2(1450,524),17,GOLD,350)
 if LanSession.can_reconnect():
  var reconnect=action("RECONNECT PVP",Vector2(1440,566),Vector2(370,56),func():
   var error=LanSession.reconnect_game()
   if error==OK:game._show_lobby()
   else:game.menu_status.text=error_string(error))
  reconnect.name="ReconnectPvp"
 var library=action("BUILD STEALER • %d / 10" % Progression.build_records.size(),Vector2(1440,636),Vector2(370,56),func():BuildLibraryMenu.show(game))
 library.name="BuildLibraryAction";library.add_theme_font_size_override("font_size",20)
 text("15+ kills / K-D ≥ 5 • Best per hero",Vector2(1440,704),16,MUTED,370)
 Progression.refresh_daily()
 var daily_card=Panel.new();daily_card.position=Vector2(1440,245);daily_card.size=Vector2(370,62)
 daily_card.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.90),Color("6e5d3b")))
 daily_card.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(daily_card)
 var daily_progress=text("Daily gear drops: %d / 5\nResets at local midnight" % Progression.daily.claimed.size(),Vector2(1455,252),17,GOLD,340)
 daily_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 # Update controls stay on the main screen; installation never interrupts a match.
 var updates=Panel.new();updates.position=Vector2(1120,730);updates.size=Vector2(670,160)
 updates.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.94),GOLD));design.add_child(updates)
 var update_label=text(GameUpdates.status,Vector2(1140,744),18,LIGHT,625)
 update_label.name="UpdateStatus";update_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var update_button=action("CHECK FOR UPDATES",Vector2(1140,798),Vector2(365,46),func():
  if GameUpdates.phase=="ready":GameUpdates.restart_to_update()
  elif GameUpdates.phase=="available":GameUpdates.download_update()
  else:GameUpdates.check_latest())
 update_button.name="UpdateAction";update_button.add_theme_font_size_override("font_size",18)
 var page=action("RELEASE NOTES",Vector2(1518,798),Vector2(250,46),func():GameUpdates.open_release())
 page.add_theme_font_size_override("font_size",18)
 var automatic=CheckButton.new();automatic.text="Download updates automatically";automatic.position=Vector2(1140,849)
 automatic.add_theme_font_size_override("font_size",17);automatic.set_pressed_no_signal(GameUpdates.auto_download)
 automatic.toggled.connect(func(value):GameUpdates.set_auto_download(value));design.add_child(automatic)
 var refresh_updates=func():
  update_label.text=GameUpdates.status
  update_button.text="RESTART TO UPDATE" if GameUpdates.phase=="ready" else "DOWNLOAD UPDATE" if GameUpdates.phase=="available" else "DOWNLOADING…" if GameUpdates.phase=="downloading" else "CHECK FOR UPDATES"
  update_button.disabled=GameUpdates.phase in ["checking","downloading","installing"]
 GameUpdates.changed.connect(refresh_updates);refresh_updates.call()
 tree_exiting.connect(func():GameUpdates.changed.disconnect(refresh_updates))
 var info=Panel.new();info.position=Vector2(920,912);info.size=Vector2(870,88)
 info.add_theme_stylebox_override("panel",box(Color(.025,.04,.065,.82),Color(.7,.57,.32,.65)))
 info.mouse_filter=Control.MOUSE_FILTER_IGNORE;design.add_child(info)
 for i in range(3):
  var value=text([str(ChampionData.CHAMPIONS.size()),"3","N1 - N99"][i],Vector2(950+i*280,921),30,LIGHT,250,true)
  value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  var desc=text(["HEROES","PLAYERS IN CO-OP","DIFFICULTY LEVELS"][i],Vector2(950+i*280,963),14,GOLD,250)
  desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if i<2:line(Vector2(1215+i*280,934),Vector2(1,43),Color(.7,.57,.32,.4))
 text("3v3 ARAM  /  Hero drafts  /  Permanent progression",Vector2(120,1033),16,MUTED,980)
 resized.connect(layout);layout()
func layout() -> void:
 if design==null:return
 var ratio=minf(size.x/1920.0,size.y/1080.0)
 design.scale=Vector2.ONE*ratio
 design.position=(size-Vector2(1920,1080)*ratio)*.5
