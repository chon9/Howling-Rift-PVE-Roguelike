extends Node
var failures=0
var checks=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL: "+message)
func find_button(node: Node,title: String):
 if node is Button and node.text==title:return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found!=null:return found
 return null
func click(control: Control) -> void:
 await get_tree().process_frame
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
 event.position=control.get_global_rect().get_center();event.pressed=true
 get_viewport().push_input(event,true)
 event=event.duplicate();event.pressed=false;get_viewport().push_input(event,true)
 await get_tree().process_frame
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 await click(find_button(game.menu,"HOST STEAM"))
 check(game.menu_page=="main" and not LanSession.active,"offline Steam host keeps title usable")
 check(game.menu_status.text.contains("unavailable"),"offline Steam status visible")
 await click(find_button(game.menu,"JOIN STEAM"))
 check(game.menu_page=="steam","actual Join Steam button opens browser")
 await click(find_button(game.menu,"JOIN BY LOBBY CODE"))
 check(not LanSession.active and game.menu_page=="steam","invalid code does not create transport")
 await click(find_button(game.menu,"BACK TO MAIN MENU"))
 check(game.menu_page=="main","browser Back returns to title")
 var count=SteamSession.changed.get_connections().size()
 for i in range(3):
  await click(find_button(game.menu,"JOIN STEAM"))
  var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
  get_viewport().push_input(esc,true);await get_tree().process_frame
  check(game.menu_page=="main","Esc leaves Steam browser")
 check(SteamSession.changed.get_connections().size()==count,"menu changes disconnect old Steam status handlers")
 await click(find_button(game.menu,"PLAY SOLO ARAM"))
 check(game.hero_cards.size()==ChampionData.CHAMPIONS.size(),"solo hero selection still works without Steam")
 game.queue_free();await get_tree().process_frame
 print("STEAM MENU INPUT: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
