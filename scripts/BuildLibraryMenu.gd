class_name BuildLibraryMenu
extends RefCounted
static func show(game) -> void:
 if GameState.started:return
 if is_instance_valid(game.menu.get_node_or_null("BuildLibrary")):return
 var shade=ColorRect.new();shade.name="BuildLibrary";shade.color=Color(0,0,0,.88);game.menu.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel=PanelContainer.new();shade.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-660;panel.offset_right=660;panel.offset_top=-430;panel.offset_bottom=430
 var style=StyleBoxFlat.new();style.bg_color=Color("0c1724");style.border_color=Color("c5a15e");style.set_border_width_all(2);style.set_content_margin_all(24.);panel.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
 column.add_child(RiftMenus.label("BUILD STEALER • BEST %d / 10 HEROES" % Progression.build_records.size(),32))
 column.add_child(RiftMenus.label("Completed PvE runs • 15+ hero kills • K/D ≥ 5 • Saved on the host",19))
 column.add_child(RiftMenus.label("One best build per hero; a higher score replaces it. Up to two Echoes; enemy heroes never repeat.",18))
 var scroll=ScrollContainer.new();scroll.name="BuildRows";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
 if Progression.build_records.is_empty():
  var empty=RiftMenus.label("No stolen builds yet.\nFinish a dominant PvE run with at least one purchased item.\nThe host also records qualifying co-op teammates.",24);empty.custom_minimum_size.y=260;list.add_child(empty)
 for rank in range(Progression.build_records.size()):
  var record=Progression.build_records[rank];var card=PanelContainer.new();list.add_child(card)
  var bg=StyleBoxFlat.new();bg.bg_color=Color("142232");bg.border_color=Color("594b34");bg.set_border_width_all(1);bg.set_content_margin_all(14.);card.add_theme_stylebox_override("panel",bg)
  var content=VBoxContainer.new();content.add_theme_constant_override("separation",10);card.add_child(content)
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",16);content.add_child(row)
  var number=RiftMenus.label("#%d" % (rank+1),25);number.custom_minimum_size.x=58;number.modulate=Color("e1bf7b");row.add_child(number)
  var portrait=TextureRect.new();portrait.texture=HeroArt.texture_for(record.hero);portrait.custom_minimum_size=Vector2(64,64);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
  var identity=VBoxContainer.new();identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(identity)
  var title=RiftMenus.label(ChampionData.CHAMPIONS[record.hero].name+" • "+record.name,22);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.clip_text=true;identity.add_child(title)
  var result=RiftMenus.label("N%d • Score %d • %d / %d / %d • %s" % [record.stage,record.score,record.kills,record.deaths,record.assists,"Victory" if record.won else "Defeat"],18);result.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;result.clip_text=true;identity.add_child(result)
  for id in record.items:
   var icon=TextureRect.new();icon.texture=ShopArt.item_icon(id);icon.custom_minimum_size=Vector2(56,56);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.tooltip_text=ItemData.item_tooltip(id);icon.mouse_filter=Control.MOUSE_FILTER_STOP;row.add_child(icon)
  for spell in record.spells:
   var icon=TextureRect.new();icon.texture=ShopArt.icon_for(SummonerData.SPELLS[spell].art);icon.custom_minimum_size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.tooltip_text=SummonerData.SPELLS[spell].desc;icon.mouse_filter=Control.MOUSE_FILTER_STOP;row.add_child(icon)
  var upgrade_names=[]
  for upgrade in record.augments:upgrade_names.append("Lv%d %s" % [upgrade.level,upgrade.name])
  var elixir_names=[]
  for id in record.elixirs:elixir_names.append("%s ×%d" % [ItemData.ITEMS[id].name,record.elixirs[id]])
  var detail=RiftMenus.label(" • ".join(upgrade_names)+("\n"+" • ".join(elixir_names) if not elixir_names.is_empty() else ""),17);detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.tooltip_text="\n".join(record.augments.map(func(upgrade):return "Lv%d %s: %s" % [upgrade.level,upgrade.name,BuildStealer.stats_label(upgrade.stats)]));detail.mouse_filter=Control.MOUSE_FILTER_STOP;content.add_child(detail)
 column.add_child(RiftMenus.label("Saved path first, then normal hero skills, upgrades and item build. Full loadouts continue into stat elixirs.",17))
 column.add_child(RiftMenus.label("Score: difficulty reward multiplier × (100 × kills + 15 × assists) / max(1, deaths), plus 500 for a victory.",16))
 column.add_child(RiftMenus.button("BACK",func():shade.queue_free()))
