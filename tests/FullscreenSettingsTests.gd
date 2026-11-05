extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL FULLSCREEN: "+message)
func key(code: int,alt: bool=false) -> void:
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;event.alt_pressed=alt
 game._input(event)
func _ready() -> void:
 await get_tree().process_frame
 var original_path=Progression.save_path
 Progression.save_path="res://tests/fullscreen-settings-temp.cfg";Progression.persistent=true
 Progression.credits=1234;Progression.fullscreen_enabled=false
 check(Progression.save_profile(),"isolated profile saves")
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 await get_tree().process_frame;await get_tree().process_frame
 game._show_start_upgrades()
 await get_tree().process_frame;await get_tree().process_frame
 var toggle=game.menu.find_child("Fullscreen",true,false)
 check(toggle!=null and not toggle.button_pressed,"windowed preference appears in settings")
 toggle.button_pressed=true
 check(Progression.fullscreen_enabled,"settings toggle updates preference")
 var disk=ConfigFile.new();check(disk.load(Progression.save_path)==OK and disk.get_value("graphics","fullscreen",false),"toggle saves fullscreen immediately")
 if DisplayServer.get_name()!="headless":check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"toggle applies actual fullscreen")
 await get_tree().process_frame;await get_tree().process_frame
 game.queue_free();await get_tree().process_frame;await get_tree().process_frame
 Progression.fullscreen_enabled=false;Progression.load_profile()
 check(Progression.fullscreen_enabled and Progression.credits==1234,"reload remembers fullscreen without changing credits")
 Progression.fullscreen_enabled=false
 get_tree().current_scene=null
 check(get_tree().change_scene_to_file("res://scenes/Main.tscn")==OK,"real startup scene opens")
 await get_tree().scene_changed
 game=get_tree().current_scene;game.set_process(false)
 await get_tree().process_frame;await get_tree().process_frame
 check(Progression.fullscreen_enabled,"real startup loads saved display preference before applying it")
 if DisplayServer.get_name()!="headless":check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"next game instance starts fullscreen")
 await get_tree().process_frame;await get_tree().process_frame
 game._show_start_upgrades();await get_tree().process_frame;await get_tree().process_frame;toggle=game.menu.find_child("Fullscreen",true,false)
 check(toggle.button_pressed,"reopened settings reflect restored fullscreen")
 key(KEY_F11)
 check(not Progression.fullscreen_enabled and not toggle.button_pressed,"F11 exits fullscreen and synchronizes toggle")
 Progression.load_profile();check(not Progression.fullscreen_enabled,"F11 remembers windowed mode too")
 if DisplayServer.get_name()!="headless":check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"F11 applies actual windowed mode")
 key(KEY_ENTER,true)
 Progression.fullscreen_enabled=false;Progression.load_profile()
 check(Progression.fullscreen_enabled,"Alt+Enter also saves fullscreen")
 game.set_fullscreen(false)
 var legacy=ConfigFile.new();legacy.set_value("profile","credits",4321);legacy.save(Progression.save_path)
 Progression.fullscreen_enabled=true;Progression.load_profile()
 check(not Progression.fullscreen_enabled and Progression.credits==4321,"older profiles default to windowed without losing progression")
 await get_tree().process_frame;await get_tree().process_frame
 game.queue_free();await get_tree().process_frame;await get_tree().process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.save_path))
 Progression.save_path=original_path;Progression.persistent=false
 print("FULLSCREEN SETTINGS: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
