extends Node
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL KILL FEED: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._start_game("veigar");game.set_process(false)
 var ui=game.hud.get_node("HudRoot")
 var p=GameState.player;var enemy=GameState.champions[3]
 p.char_name="A very long player name [with brackets] that should never push outside the kill feed"
 enemy.char_name="An enemy with a similarly long name to verify clipping"
 for i in range(12):ui.log_kill(p,enemy)
 await get_tree().process_frame;await get_tree().process_frame
 check(ui.kill_feed.get_child_count()==5,"kill feed retains at most five rows")
 check(ui.kill_feed_frame.clip_contents,"feed clips drawing to fixed frame")
 var frame=ui.kill_feed_frame.get_global_rect()
 check(ui.get_global_rect().encloses(frame),"feed frame remains inside HUD")
 for entry in ui.kill_feed.get_children():
  check(frame.encloses(entry.get_global_rect()),"row fits inside frame")
  check(entry.clip_contents and entry.mouse_filter==Control.MOUSE_FILTER_IGNORE,"rows clip and allow battlefield clicks")
  for label in entry.get_child(0).get_children():
   if label.text!="⚔":check(label.clip_text and label.text_overrun_behavior==TextServer.OVERRUN_TRIM_ELLIPSIS,"long names shorten within their slots")
 ui.log_kill(null,enemy)
 await get_tree().process_frame;await get_tree().process_frame
 check(ui.kill_feed.get_child_count()==5,"execution also respects row limit")
 if DisplayServer.get_name()!="headless":
  game.camera.position=Vector2(1300,270);game.camera.reset_smoothing()
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/kill-feed-fit-v034.png")
 ui.hide_game_hud();check(not ui.kill_feed_frame.visible,"feed frame hides with HUD")
 print("KILL FEED FIT: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
