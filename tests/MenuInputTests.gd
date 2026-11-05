extends Node
var failures = 0
var checks = 0
func check(value: bool,text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func descendants(node: Node) -> Array:
 var nodes = [node]
 for child in node.get_children(): nodes.append_array(descendants(child))
 return nodes
func button(node: Node, text: String):
 for child in descendants(node):
  if child is Button and child.text == text: return child
 return null
func click(control: Control) -> void:
 await get_tree().process_frame
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = control.get_global_rect().get_center()
 event.pressed = true
 get_viewport().push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 get_viewport().push_input(event,true)
 await get_tree().process_frame
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 await click(button(game.menu,"PLAY SOLO ARAM"))
 check(game.menu_page == "heroes" and not GameState.started,"title Play click opens hero selection")
 await click(game.hero_cards.yasuo)
 check(game.selected_hero == "yasuo" and game.launch_button.text.contains("Kaze"),"hero click selects wind samurai")
 await click(game.launch_button)
 check(GameState.started and GameState.player.hero_key == "yasuo","Play click starts selected hero")
 var esc = InputEventKey.new()
 esc.keycode = KEY_ESCAPE
 esc.pressed = true
 get_viewport().push_input(esc,true)
 check(game.in_game_menu.has_node("MatchPanel") and GameState.paused,"real Esc opens pause menu")
 await click(button(game.in_game_menu,"RETURN TO MAIN MENU"))
 check(game.has_node("ReturnConfirmation"),"Return menu action opens confirmation")
 game.get_node("ReturnConfirmation").canceled.emit()
 await get_tree().process_frame
 check(GameState.started and GameState.paused,"cancel keeps current match paused")
 await click(button(game.in_game_menu,"QUIT GAME"))
 check(game.has_node("QuitConfirmation"),"Quit menu action opens confirmation")
 game.get_node("QuitConfirmation").canceled.emit()
 await get_tree().process_frame
 check(GameState.started,"cancel quit preserves the match")
 await click(button(game.in_game_menu,"RETURN TO MAIN MENU"))
 game.get_node("ReturnConfirmation").confirmed.emit()
 await get_tree().process_frame
 check(game.menu_page == "main" and not GameState.started and GameState.champions.is_empty(),"confirmed return clears match and shows title")
 await click(button(game.menu,"PLAY SOLO ARAM"))
 check(game.hero_cards.size() == ChampionData.CHAMPIONS.size(),"new match can select all eighteen heroes after return")
 print("MENU INPUT: %d checks, %d failures" % [checks,failures])
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
