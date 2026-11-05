extends PanelContainer
# Live shop: browsing is allowed anywhere; transactions require the fountain or death.
var player = null
var selected: String = "long_sword"
var category: String = "all"
var grid: GridContainer
var search: LineEdit
var status: Label
var detail: Label
var detail_scroller: ScrollContainer
var detail_icon: TextureRect
var recipe: HBoxContainer
var buy: Button
var sell: Button
var inventory_buttons: Array = []
var selected_slot: int = -1
var last_inventory: String = ""
var last_catalog_counts: String = ""
var category_buttons: Array = []
var upgrade_source: String = ""
var upgrades_button: Button
signal close_requested

func label(text: String, font: int = 22) -> Label:
 var result = Label.new()
 result.text = text
 result.add_theme_font_size_override("font_size", font)
 return result

func button(text: String, dimensions: Vector2) -> Button:
 var result = load("res://scripts/ItemButton.gd").new()
 result.text = text
 result.custom_minimum_size = dimensions
 result.add_theme_font_size_override("font_size", 22)
 result.focus_mode = Control.FOCUS_NONE
 return result

func _ready() -> void:
 set_anchors_preset(Control.PRESET_TOP_LEFT)
 offset_left = 32
 offset_right = 1392
 offset_top = 70
 offset_bottom = 880
 custom_minimum_size = Vector2(1360, 810)
 mouse_filter = Control.MOUSE_FILTER_STOP
 z_index = 100
 var style = StyleBoxFlat.new()
 style.bg_color = Color("091422")
 style.border_color = Color("b49b60")
 style.set_border_width_all(2)
 style.content_margin_left = 24
 style.content_margin_right = 24
 style.content_margin_top = 20
 style.content_margin_bottom = 20
 add_theme_stylebox_override("panel", style)
 var outer = VBoxContainer.new()
 outer.add_theme_constant_override("separation", 12)
 add_child(outer)
 var header = HBoxContainer.new()
 outer.add_child(header)
 var title = label("ITEM SHOP", 32)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 var close = button("CLOSE [ESC / P]", Vector2(240,48))
 close.pressed.connect(func(): close_requested.emit())
 header.add_child(close)
 status = label("", 22)
 outer.add_child(status)
 var body = HBoxContainer.new()
 body.add_theme_constant_override("separation", 16)
 outer.add_child(body)
 var filters = VBoxContainer.new()
 filters.custom_minimum_size.x = 160
 body.add_child(filters)
 for cat in ItemData.CATEGORIES:
  var filter = button(cat.label, Vector2(160,40))
  filter.pressed.connect(func(): category = cat.id; rebuild_catalog())
  filter.set_meta("category",cat.id)
  category_buttons.append(filter)
  filters.add_child(filter)
 for path in [{"id":"mage","label":"Mage builds"},{"id":"tank","label":"Tank builds"},{"id":"bruiser","label":"Bruiser builds"},{"id":"marksman","label":"Marksman builds"}]:
  var filter=button(path.label,Vector2(160,40))
  filter.add_theme_font_size_override("font_size",18)
  filter.pressed.connect(func():category=path.id;rebuild_catalog())
  filter.set_meta("category",path.id)
  category_buttons.append(filter)
  filters.add_child(filter)
 var catalog = VBoxContainer.new()
 body.add_child(catalog)
 search = LineEdit.new()
 search.placeholder_text = "Search items or passives..."
 search.custom_minimum_size = Vector2(660,48)
 search.add_theme_font_size_override("font_size",22)
 search.text_changed.connect(func(_text): rebuild_catalog())
 catalog.add_child(search)
 var scroll = ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(660,460)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 catalog.add_child(scroll)
 grid = GridContainer.new()
 grid.columns = 3
 grid.add_theme_constant_override("h_separation",8)
 grid.add_theme_constant_override("v_separation",8)
 scroll.add_child(grid)
 var info = VBoxContainer.new()
 info.custom_minimum_size.x = 440
 info.add_theme_constant_override("separation",10)
 body.add_child(info)
 detail_icon = TextureRect.new()
 detail_icon.custom_minimum_size = Vector2(112,112)
 detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 info.add_child(detail_icon)
 detail = label("",22)
 detail.custom_minimum_size = Vector2(420,0)
 detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail_scroller=ScrollContainer.new()
 detail_scroller.custom_minimum_size=Vector2(440,200)
 detail_scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 info.add_child(detail_scroller)
 detail_scroller.add_child(detail)
 info.add_child(label("BUILDS FROM",20))
 recipe = HBoxContainer.new()
 info.add_child(recipe)
 buy = button("BUY",Vector2(440,62))
 buy.pressed.connect(func():
  if player != null: player.try_buy_item(selected); rebuild_catalog())
 var actions=HBoxContainer.new()
 actions.add_theme_constant_override("separation",8)
 buy.custom_minimum_size.x=272
 actions.add_child(buy)
 upgrades_button=button("UPGRADES",Vector2(160,62))
 upgrades_button.pressed.connect(func():view_upgrades(selected))
 actions.add_child(upgrades_button)
 info.add_child(actions)
 outer.add_child(label("YOUR INVENTORY   •   Select an item to sell for 70%",20))
 var inventory_row = HBoxContainer.new()
 inventory_row.add_theme_constant_override("separation",12)
 outer.add_child(inventory_row)
 for index in range(6):
  var slot = button("",Vector2(96,96))
  slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  slot.expand_icon = true
  slot.add_theme_constant_override("icon_max_width",78)
  slot.pressed.connect(func():
   selected_slot = index
   if player != null and player.inventory[index] != "":view_upgrades(player.inventory[index])
   else:refresh_shop(true))
  inventory_row.add_child(slot)
  inventory_buttons.append(slot)
 sell = button("SELECT ITEM TO SELL",Vector2(420,96))
 sell.pressed.connect(func():
  if player != null and selected_slot >= 0: player.try_sell_item(selected_slot); refresh_shop(true))
 inventory_row.add_child(sell)
 rebuild_catalog()

func rebuild_catalog() -> void:
 last_catalog_counts = str(player.consumable_counts) if player != null else ""
 for filter in category_buttons:
  filter.modulate = Color("f5d38c") if filter.get_meta("category") == category else Color.WHITE
 for child in grid.get_children(): grid.remove_child(child); child.queue_free()
 for id in ItemData.ORDER:
  var item = ItemData.ITEMS[id]
  if category == "recommended":
   if player != null and not ItemData.BUILD_ORDERS.get(player.hero_key,[]).has(id): continue
  elif category == "upgrades":
   if not ItemData.upgrades_for(upgrade_source).has(id): continue
  elif category == "mage":
   if not ItemData.matches_mage_build(id): continue
  elif category in ["tank","bruiser","marksman"]:
   if not TankADItems.matches(id,category):continue
  elif not ItemData.matches_category(id,category): continue
  if not search.text.is_empty() and not (item.name + " " + item.desc).to_lower().contains(search.text.to_lower()): continue
  var cost = MatchTraining.price(id,player.consumable_counts) if item.get("consumable",false) and player != null else item.cost
  var card = button("", Vector2(208,116))
  card.tooltip_text = ItemData.item_tooltip(id,player.consumable_counts if player != null else {})
  grid.add_child(card)
  var row = HBoxContainer.new()
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  row.offset_left = 8; row.offset_right = -8
  card.add_child(row)
  var icon = TextureRect.new()
  icon.texture = ShopArt.item_icon(id)
  icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(64,64)
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(icon)
  var text = label("%s\n%dg" % [item.name,cost],18)
  text.custom_minimum_size.x = 126
  text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  text.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(text)
  card.pressed.connect(func(): view_upgrades(id))
 if category=="upgrades" and grid.get_child_count()==0:
  var empty=label("Finished item\nNo further upgrades",22)
  empty.custom_minimum_size=Vector2(640,100);grid.add_child(empty)
 refresh_shop(true)

func view_upgrades(id: String) -> void:
 if not ItemData.ITEMS.has(id): return
 selected=id;upgrade_source=id;category="upgrades";search.text="";rebuild_catalog()

func refresh_shop(force: bool = false) -> void:
 if player == null: return
 if last_catalog_counts != str(player.consumable_counts):
  rebuild_catalog()
  return
 status.text = "%dg   •   %s" % [int(player.gold), "Fountain shop available" if player.can_shop() else "Recall to the fountain to buy or sell • browsing available anywhere"]
 if category == "upgrades": status.text += "   •   Upgrades for " + ItemData.ITEMS[upgrade_source].name
 var item = ItemData.ITEMS[selected]
 var plan = ItemData.purchase_plan(selected,player.inventory,player.consumable_counts)
 upgrades_button.disabled = ItemData.upgrades_for(selected).is_empty()
 upgrades_button.tooltip_text = "Finished item: no upgrades" if upgrades_button.disabled else "Show all items this can become"
 buy.disabled = not player.can_shop() or not plan.valid or player.gold < plan.cost
 buy.text = "BUY • %dg" % plan.cost if plan.valid else plan.reason
 buy.tooltip_text = "Owned components are consumed and their full cost is credited."
 detail_icon.texture = ShopArt.item_icon(selected)
 detail.text = "%s • %dg\n\n%s\n\nRemaining cost: %dg" % [item.name,item.cost,item.desc,plan.cost]
 if item.get("consumable",false):
  detail.text = "%s • Purchased %d times\n\n%s\n\nNext cost: %dg" % [item.name,player.consumable_counts.get(selected,0),item.desc,plan.cost]
  buy.tooltip_text = "Consumed instantly. No slot required. Match-only stats; next purchase costs more."
 var inventory_key = str(player.inventory) + selected
 if force or inventory_key != last_inventory:
  detail_scroller.scroll_vertical=0
  last_inventory = inventory_key
  for child in recipe.get_children(): recipe.remove_child(child); child.queue_free()
  for component in item.recipe:
   var part = button("%dg" % ItemData.ITEMS[component].cost,Vector2(130,80))
   part.icon = ShopArt.item_icon(component)
   part.expand_icon = true
   part.add_theme_constant_override("icon_max_width",42)
   part.tooltip_text = ItemData.ITEMS[component].name
   part.pressed.connect(func(): view_upgrades(component))
   recipe.add_child(part)
  for index in range(6):
   var id = player.inventory[index]
   inventory_buttons[index].icon = ShopArt.item_icon(id)
   inventory_buttons[index].tooltip_text = ItemData.item_tooltip(id,player.consumable_counts)
   inventory_buttons[index].modulate = Color("f5d38c") if index == selected_slot else Color.WHITE
 var sell_id = player.inventory[selected_slot] if selected_slot >= 0 else ""
 sell.disabled = sell_id == "" or not player.can_shop()
 sell.text = "SELL %s • %dg" % [ItemData.ITEMS[sell_id].name,ItemData.sell_value(sell_id)] if sell_id != "" else "SELECT ITEM TO SELL"
