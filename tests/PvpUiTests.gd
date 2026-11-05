extends Node
var game
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("PVP UI: "+message)
func capture(name: String) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/pvp-"+name+".png")
func _ready() -> void:
 Progression.persistent=false;Progression.fullscreen_enabled=false
 game=load("res://scripts/Main.gd").new();add_child(game)
 check(game.menu.find_child("PlayPvp",true,false)!=null,"main PvP entry")
 await capture("main")
 game.menu.find_child("PlayPvp",true,false).pressed.emit()
 check(game.menu_page=="pvp","PvP setup opens")
 await capture("setup")
 var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
 game._input(esc);check(game.menu_page=="main","Escape returns from setup")
 check(LanSession.host_game("pvp",3,true)==OK,"host lobby starts")
 LanSession.players[2]={"peer":2,"name":"Red Guest","hero":"yasuo","spells":["flash","ignite"],"team":1,"ready":true,"bonuses":{}}
 LanSession.ready_player("ashe",["heal","ghost"],{})
 game._show_lobby()
 await capture("lobby")
 check(game.lobby_start.disabled==false,"ready humans enable start")
 var bounds=Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
 for node in [game.lobby_team,game.lobby_ready,game.lobby_start]:check(bounds.encloses(node.get_global_rect()),"lobby control stays on screen")
 # Render Steam's additional invite row with the same layout, without API calls.
 LanSession.transport="steam";game._show_lobby()
 await capture("steam-lobby")
 var leave=game.menu.get_children()[0].get_children().filter(func(n):return n is VBoxContainer)[0].get_children().back()
 check(bounds.encloses(leave.get_global_rect()),"Steam leave button stays on screen")
 LanSession.transport="lan"
 LanSession.players[1].team=1;LanSession.players[2].team=0
 var config=MatchRules.build_config(LanSession.players,LanSession.rules,99,true)
 game._start_network_match(config)
 await capture("red-match")
 check(GameState.player.team==1,"red local player")
 check(game.hud.get_node("HudRoot").difficulty_label.text.contains("RED"),"HUD identifies red side")
 game.toggle_in_game_menu();game._show_pause_upgrades()
 await capture("settings")
 check(game.in_game_menu.find_child("Permanent_might",true,false)==null,"PvP settings omit permanent purchases")
 game._return_to_main_menu()
 print("PVP UI: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
