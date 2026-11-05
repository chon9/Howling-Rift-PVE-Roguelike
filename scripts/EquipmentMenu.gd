extends Control
var game
var design: Control
var selected_id=""
var selected_slot="weapon"
var filter_kind="all"
var detail: VBoxContainer
var stash_list: VBoxContainer
var status: Label
var day_timer=0.
const GOLD=Color("cfad6c")
const LIGHT=Color("eadfc6")
const MUTED=Color("a3b7c8")
func style(border: Color=GOLD) -> StyleBoxFlat:
 var box=StyleBoxFlat.new();box.bg_color=Color("0b1724");box.border_color=border;box.set_border_width_all(1)
 box.set_content_margin_all(12);box.set_corner_radius_all(4)
 return box
func label(value: String,font_size: int=20,color: Color=LIGHT) -> Label:
 var node=Label.new();node.text=value;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return node
func button(value: String,callback: Callable) -> Button:
 var node=Button.new();node.text=value;node.add_theme_font_size_override("font_size",20)
 node.add_theme_color_override("font_color",LIGHT);node.add_theme_stylebox_override("normal",style(Color("6d634e")))
 node.add_theme_stylebox_override("hover",style(Color("f3cf7c")));node.add_theme_stylebox_override("pressed",style(GOLD))
 node.custom_minimum_size.y=44;node.pressed.connect(callback);return node
func place(node: Control,at: Vector2,dimensions: Vector2) -> void:
 design.add_child(node);node.position=at;node.size=dimensions
func _ready() -> void:
 name="EquipmentScreen";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 design=Control.new();design.size=Vector2(1920,1080);add_child(design)
 Progression.refresh_daily()
 build()
 resized.connect(layout);layout()
func layout() -> void:
 var scale_factor=minf(size.x/1920.,size.y/1080.)
 design.scale=Vector2.ONE*scale_factor;design.position=(size-Vector2(1920,1080)*scale_factor)*.5
func build() -> void:
 for child in design.get_children():design.remove_child(child);child.queue_free()
 place(label("DAILY QUESTS  /  RIFT RELICS",36,GOLD),Vector2(300,42),Vector2(1040,56))
 place(button("MAIN MENU [ESC]",func():game._show_main_menu()),Vector2(60,46),Vector2(220,50))
 place(label("%d permanent credits" % Progression.credits,23,GOLD),Vector2(1430,58),Vector2(430,50))
 place(label("DAILY QUESTS",25,GOLD),Vector2(60,130),Vector2(400,40))
 place(label("EQUIPPED  ·  9 SLOTS",25,GOLD),Vector2(520,130),Vector2(660,40))
 place(label("STASH  ·  %d / %d" % [Progression.gear_stash.size(),Progression.STASH_LIMIT],25,GOLD),Vector2(1220,130),Vector2(390,40))
 var filter=OptionButton.new();filter.name="GearFilter";filter.add_theme_font_size_override("font_size",19)
 filter.add_item("All equipment");var types=["all"]
 for type in GearLoot.BASES:filter.add_item("Ring" if type=="ring" else GearLoot.SLOTS[type]);types.append(type)
 filter.selected=types.find(filter_kind)
 filter.item_selected.connect(func(index):filter_kind=types[index];refresh_stash())
 place(filter,Vector2(1610,128),Vector2(250,44))
 var quest_scroll=ScrollContainer.new();quest_scroll.name="DailyQuestScroll";quest_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var quest_list=VBoxContainer.new();quest_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;quest_list.add_theme_constant_override("separation",14);quest_scroll.add_child(quest_list)
 place(quest_scroll,Vector2(60,190),Vector2(420,775))
 for key in Progression.DAILY_QUESTS:
  var quest=Progression.DAILY_QUESTS[key];var claimed=Progression.daily.claimed.has(key)
  var ready=Progression.daily.ready.has(key)
  var card=PanelContainer.new();card.add_theme_stylebox_override("panel",style(Color("657b54") if claimed else Color("746344")))
  var column=VBoxContainer.new();column.add_theme_constant_override("separation",5);card.add_child(column)
  column.add_child(label(("✓ " if claimed else "")+quest.name,23,GOLD))
  var description=label(quest.desc,19,MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(description)
  var progress=mini(int(Progression.daily.progress[quest.field]),quest.goal)
  column.add_child(label("DROP RECEIVED" if claimed else ("READY · Make stash space to claim" if ready else "%d / %d  ·  Reward: 1 random relic" % [progress,quest.goal]),18,Color("aacb91") if claimed else LIGHT))
  card.custom_minimum_size=Vector2(0,117);quest_list.add_child(card)
 var daily_note=label(Progression.daily_summary()+"\nDefeats count after 2 minutes.\nQuest progress counts at match completion.\nHigher N gives stronger drops and better rarity odds.",19,MUTED)
 daily_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 daily_note.custom_minimum_size.y=140;quest_list.add_child(daily_note)
 var claim=button("CLAIM WAITING DROPS",func():Progression.claim_pending();build())
 claim.disabled=Progression.daily.ready.size()<=Progression.daily.claimed.size() or Progression.gear_stash.size()>=Progression.STASH_LIMIT
 place(claim,Vector2(60,985),Vector2(420,48))
 var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",14)
 place(grid,Vector2(520,190),Vector2(660,370))
 for slot in GearLoot.SLOTS:
  var item=Progression.gear_item(str(Progression.gear_equipped.get(slot,"")))
  var node=button(GearLoot.SLOTS[slot]+"\n"+("Empty" if item.is_empty() else "%s · Lv %d" % [GearLoot.RARITIES[item.rarity],item.level]),func():
   selected_slot=slot;selected_id=str(Progression.gear_equipped.get(slot,""));refresh_detail())
  node.name="GearSlot_"+slot;node.custom_minimum_size=Vector2(210,112);node.add_theme_font_size_override("font_size",18)
  if not item.is_empty():
   node.icon=GearArt.icon_for(GearLoot.icon_key(item));node.expand_icon=true;node.add_theme_constant_override("icon_max_width",45)
   node.tooltip_text=GearLoot.description(item);node.add_theme_stylebox_override("normal",style(GearLoot.COLORS[item.rarity]))
  grid.add_child(node)
 var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",style(Color("6d634e")))
 detail=VBoxContainer.new();detail.name="GearDetails";detail.add_theme_constant_override("separation",8);panel.add_child(detail)
 place(panel,Vector2(520,580),Vector2(660,385))
 var scroll=ScrollContainer.new();scroll.name="GearStashScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 stash_list=VBoxContainer.new();stash_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stash_list.add_theme_constant_override("separation",10);scroll.add_child(stash_list)
 place(scroll,Vector2(1220,190),Vector2(640,790))
 status=label(Progression.save_error,19,Color("efad8b"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 place(status,Vector2(520,985),Vector2(660,60))
 refresh_stash();refresh_detail()
func _process(delta: float) -> void:
 day_timer+=delta
 if day_timer<5.:return
 day_timer=0.
 var previous=str(Progression.daily.get("date",""));Progression.refresh_daily()
 if str(Progression.daily.get("date",""))!=previous:build()
func refresh_stash() -> void:
 for child in stash_list.get_children():stash_list.remove_child(child);child.queue_free()
 var items=Progression.gear_stash.duplicate()
 items.sort_custom(func(a,b):return a.level>b.level if a.level!=b.level else a.rarity>b.rarity)
 for item in items:
  if filter_kind!="all" and item.slot!=filter_kind:continue
  var relic=item
  var node=button("%s\n%s · Lv %d · %s%s" % [item.name,GearLoot.RARITIES[item.rarity],item.level,"Ring" if item.slot=="ring" else GearLoot.SLOTS[item.slot]," · EQUIPPED" if Progression.gear_equipped.values().has(item.id) else ""],func():
   selected_id=relic.id
   selected_slot="ring_2" if relic.slot=="ring" and Progression.gear_equipped.has("ring_1") else "ring_1" if relic.slot=="ring" else relic.slot
   refresh_detail())
  node.name="Relic_"+item.id;node.custom_minimum_size=Vector2(600,78)
  node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;node.alignment=HORIZONTAL_ALIGNMENT_LEFT
  node.icon=GearArt.icon_for(GearLoot.icon_key(item));node.expand_icon=true;node.add_theme_constant_override("icon_max_width",54)
  node.add_theme_stylebox_override("normal",style(GearLoot.COLORS[item.rarity]));node.tooltip_text=GearLoot.description(item)
  stash_list.add_child(node)
 if stash_list.get_child_count()==0:
  var empty=label("No relics in this category.\nComplete daily quests to earn equipment.",21,MUTED);stash_list.add_child(empty)
func refresh_detail() -> void:
 for child in detail.get_children():detail.remove_child(child);child.queue_free()
 var item=Progression.gear_item(selected_id)
 if item.is_empty():
  detail.add_child(label("YOUR STARTING EQUIPMENT BONUSES",23,GOLD))
  detail.add_child(label("Select a relic to inspect, compare and equip.\nEquipment is saved and carried into every match.\nTwo rings can be equipped, each using a different item.",20,MUTED))
  var stats=Progression.equipment_bonuses()
  if stats.is_empty():detail.add_child(label("No equipment bonuses yet.",20))
  else:add_stats(stats)
  return
 detail.add_child(label(item.name,25,GearLoot.COLORS[item.rarity]))
 detail.add_child(label("%s · Item level %d · %d random modifiers" % [GearLoot.RARITIES[item.rarity],item.level,item.affixes.size()],20,MUTED))
 add_stats(item.stats)
 var current=Progression.gear_item(str(Progression.gear_equipped.get(selected_slot,"")))
 var comparison=PackedStringArray()
 var union=item.stats.duplicate()
 for stat in current.get("stats",{}):union[stat]=item.stats.get(stat,0.)
 for stat in union:
  var delta=float(item.stats.get(stat,0.))-float(current.get("stats",{}).get(stat,0.))
  if absf(delta)<.00001:continue
  comparison.append(("%+.1f%% " % (delta*100.) if GearLoot.CAPS.has(stat) else "%+.1f " % delta)+GearLoot.STAT_NAMES[stat])
 var compare=label("Compared with "+GearLoot.SLOTS[selected_slot]+": "+" · ".join(comparison),17,MUTED)
 compare.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;compare.max_lines_visible=3;detail.add_child(compare)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",10);detail.add_child(row)
 if item.slot=="ring":
  var target=OptionButton.new();target.add_item("Ring I");target.add_item("Ring II");target.selected=1 if selected_slot=="ring_2" else 0
  target.item_selected.connect(func(index):selected_slot="ring_1" if index==0 else "ring_2";refresh_detail());row.add_child(target)
 var equip=button("EQUIP",func():Progression.equip_gear(item.id,selected_slot);build());equip.name="EquipRelic";row.add_child(equip)
 var equipped=Progression.gear_equipped.values().has(item.id)
 if equipped:
  row.add_child(button("UNEQUIP",func():
   for slot in Progression.gear_equipped.keys():
    if Progression.gear_equipped[slot]==item.id:Progression.unequip_gear(slot)
   build()))
 var salvage=button("SALVAGE +%d" % Progression.salvage_value(item),func():confirm_salvage(item));salvage.disabled=equipped;row.add_child(salvage)
 detail.add_child(label("Hover a relic for its full stats. Changes apply next match.",17,MUTED))
func add_stats(stats: Dictionary) -> void:
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",16);detail.add_child(grid)
 for stat in stats:
  var line=label(GearLoot.stat_line(stat,stats[stat]),19);line.custom_minimum_size.x=296;grid.add_child(line)
func confirm_salvage(item: Dictionary) -> void:
 var dialog=ConfirmationDialog.new();dialog.title="Salvage relic";dialog.dialog_text="Destroy %s for %d permanent credits?" % [item.name,Progression.salvage_value(item)]
 add_child(dialog);dialog.confirmed.connect(func():Progression.salvage_gear(item.id);selected_id="";build())
 dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(520,160))
