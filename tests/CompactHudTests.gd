extends Node
var failures = 0
var checks = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+message)
func click(at: Vector2) -> void:
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = at
 event.pressed = true
 get_viewport().push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 get_viewport().push_input(event,true)
func capture(path: String) -> void:
 await get_tree().process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("leesin")
 var ui = game.hud.get_node("HudRoot")
 var p = GameState.player
 p.gold = 12345
 p.inventory = ["infinity_edge","berserker","bloodthirster","trinity","guardian_angel","black_cleaver"]
 # Use real catalog keys if a future item rename changes the preview build.
 for i in range(6):
  if not ItemData.ITEMS.has(p.inventory[i]): p.inventory[i] = ItemData.ORDER[i]
 p._apply_items()
 p.xp = 90
 p.skill_ranks = [1,1,1,1]
 p.skill_cds[0] = 4.5
 p.skill_points = 1
 p.level = 6
 p.global_position = Vector2(1280,270)
 game._update_camera(1)
 ui.refresh(0)
 game.set_fullscreen(true)
 await get_tree().create_timer(0.25).timeout
 check(ui.action_bar.size.y <= 160,"compact action bar height")
 var bar = ui.action_bar.get_global_rect()
 for meter in [ui.hp_bar,ui.mp_bar,ui.xp_bar]:
  check(bar.encloses(meter.get_global_rect()),"resource bars stay inside the action bar")
 check(ui.xp_bar.size.y <= 5,"XP strip remains thin")
 for slot in ui.inv_slots:
  check(bar.encloses(slot.panel.get_global_rect()),"inventory stays inside the action bar")
 for slot in ui.skill_slots:
  check(bar.encloses(slot.get_global_rect()),"abilities stay inside the action bar")
 for slot in ui.summoner_slots:
  check(bar.encloses(slot.panel.get_global_rect()),"summoners stay inside the action bar")
 check(ui.inventory_grid.columns == 3,"inventory uses three columns and two rows")
 check(ui.inv_slots[3].panel.global_position.y > ui.inv_slots[0].panel.global_position.y,"second item row")
 check(ui.inv_slots[0].panel.global_position.x > ui.summoner_slots[1].panel.global_position.x,"items sit to the right of summoners")
 check(not ui.farming_label.visible,"farming instructions do not cover the battlefield")
 check(ui.player_gold.text.contains("12345"),"gold updates in the shop button")
 await capture("res://tests/36-compact-hud-fullscreen.png")
 click(ui.shop_button.get_global_rect().get_center())
 await get_tree().process_frame
 check(ui.shop_open,"clicking gold opens the shop")
 check(ui.shop_panel.get_global_rect().end.y < bar.position.y,"shop leaves the action bar visible")
 check(not ui.shop_panel.get_global_rect().intersects(ui.minimap.get_global_rect()),"shop leaves the minimap visible")
 game.lane_augments._process(0)
 ui.shop_panel.selected = "infinity_edge"
 ui.shop_panel.refresh_shop(true)
 await capture("res://tests/37-compact-hud-shop.png")
 var escape = InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 game._input(escape)
 check(not ui.shop_open and not GameState.paused,"Esc closes shop without pausing")
 ui.skill_slots[0].hover_entered.emit()
 await capture("res://tests/38-compact-hud-tooltip.png")
 check(ui.tooltip_panel.visible and ui.tooltip_label.text.contains(p.hero.skills[0].name),"skill hover description works")
 ui.skill_slots[0].hover_exited.emit()
 p.start_recall()
 ui.refresh(0)
 check(ui.recall_bar.visible and ui.recall_bar.get_global_rect().end.y < bar.position.y,"recall progress sits above the action bar")
 await capture("res://tests/39-compact-hud-recall.png")
 p.recall_time = -1
 ui.refresh(0)
 game.set_fullscreen(false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 await get_tree().create_timer(0.25).timeout
 await capture("res://tests/40-compact-hud-windowed.png")
 print("COMPACT HUD: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
