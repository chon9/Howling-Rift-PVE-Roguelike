extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL CLARITY: "+message)
class Pattern extends Node2D:
 func _draw() -> void:
  draw_rect(Rect2(270,90,640,180),Color(.07,.09,.12))
  var font=ThemeDB.fallback_font
  for i in range(5):
   draw_string(font,Vector2(285,115+i*26),"SILENCED 1.5s   SHIELD 180   BASTION 0123456789",HORIZONTAL_ALIGNMENT_LEFT,-1,14+i,Color(.75,.78,.85))
  for i in range(24):draw_line(Vector2(715+i*6,101),Vector2(730+i*6,243),Color(.8,.81,.85),1.,true)
func capture() -> Image:
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 return get_viewport().get_texture().get_image()
func difference(a: Image,b: Image,rect: Rect2i) -> float:
 var total=0.;var count=0
 for y in range(rect.position.y,rect.end.y,3):
  for x in range(rect.position.x,rect.end.x,3):
   var p=a.get_pixel(x,y);var q=b.get_pixel(x,y)
   total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b);count+=3
 return total/count
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false;Progression.world_sharpness=.35
 var original_path=Progression.save_path;Progression.save_path="res://tests/clarity-settings-temp.cfg";Progression.persistent=true
 Progression.world_sharpness=.7;check(Progression.save_profile(),"sharpness saves")
 Progression.world_sharpness=0.;Progression.load_profile();check(is_equal_approx(Progression.world_sharpness,.7),"sharpness survives reopening")
 var legacy=ConfigFile.new();legacy.set_value("profile","credits",4321);legacy.save(Progression.save_path)
 Progression.load_profile();check(is_equal_approx(Progression.world_sharpness,.35) and Progression.credits==4321,"existing saves receive balanced sharpness without changing credits")
 legacy.set_value("graphics","world_sharpness",9.);legacy.save(Progression.save_path);Progression.load_profile();check(Progression.world_sharpness==1.,"out-of-range sharpness is clamped")
 DirAccess.remove_absolute(Progression.save_path);Progression.save_path=original_path;Progression.persistent=false;Progression.world_sharpness=.35
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game.network_config={"blue":["garen","lux","leona"],"red":["ashe","brand","renekton"],"players":[{"peer":1,"name":"Test","bonuses":{},"spells":["flash","heal"]}],"stage":1};game._start_game("garen")
 for i in range(6):
  var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.global_position=Vector2(1000+i*90,270)
  c.set_process(false);c.animator.set_process(false);c.get_node("StatusVisual").set_process(false)
 for slot in game.hud.get_node("HudRoot").skill_slots:slot.set_process(false)
 GameState.champions[3].buffs.silence={"time":1.5};GameState.champions[3].get_node("StatusVisual").refresh()
 CombatEffects.shield(GameState.player,"test_shield",180.,4.);GameState.player.get_node("StatusVisual").refresh()
 game.camera.global_position=Vector2(1300,270)
 GameState.paused=true
 var quality=game.graphics_quality;var material=quality.screen.material
 check(WorldTextFont.get_font().multichannel_signed_distance_field and GameState.player.name_label.get_theme_font("font")==WorldTextFont.get_font(),"camera-scaled names and status text use shared distance-field glyphs")
 game.hud.get_node("HudRoot").refresh(0)
 check(get_window().content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and get_window().content_scale_factor==1.,"game uses native canvas rendering with no reduced resolution factor")
 Progression.edge_smoothing=true;quality.apply();check(material.get_shader_parameter("smoothing")==.45,"balanced edge blending configured")
 Progression.edge_smoothing=false;quality.apply();check(quality.screen.visible and material.get_shader_parameter("smoothing")==0.,"sharpening can run without smoothing")
 Progression.world_sharpness=0.;quality.apply();check(not quality.screen.visible,"zero sharpness plus smoothing off removes GPU pass")
 Progression.world_sharpness=.35;Progression.edge_smoothing=true;quality.apply()
 check(quality.layer<game.hud.layer and quality.screen.mouse_filter==Control.MOUSE_FILTER_IGNORE,"clarity preserves HUD layer and movement input")
 game._show_start_upgrades();await get_tree().process_frame
 var slider=game.menu.find_child("WorldSharpness",true,false);check(slider!=null,"sharpness is reachable in graphics settings")
 slider.value=60.;check(is_equal_approx(Progression.world_sharpness,.6),"graphics slider immediately applies sharpness")
 slider.value=35.;game.menu.hide();game.hud.get_node("HudRoot").show_game_hud()
 if DisplayServer.get_name()!="headless":await native_checks(quality,material)
 GameState.paused=false;game._return_to_main_menu()
 print("CLARITY: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
func native_checks(quality,material) -> void:
 quality.set_process(false)
 var overlay=CanvasLayer.new();overlay.layer=0;game.add_child(overlay);overlay.add_child(Pattern.new())
 var old=ShaderMaterial.new();old.shader=load("res://tests/fixtures/world-fxaa-v060.gdshader")
 for size in [Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]:
  get_window().size=size;await get_tree().process_frame;await get_tree().process_frame
  Progression.edge_smoothing=false;Progression.world_sharpness=0.;quality.apply()
  var raw=await capture();check(raw.get_size()==size,"actual framebuffer is native "+str(size))
  quality.screen.material=old;quality.screen.show();var before=await capture()
  quality.screen.material=material;Progression.edge_smoothing=true;Progression.world_sharpness=.35;quality.apply();var after=await capture()
  var scale=Vector2(size)/get_viewport().get_visible_rect().size
  var region=Rect2i(Vector2(270,90)*scale,Vector2(640,180)*scale)
  var old_error=difference(raw,before,region);var new_error=difference(raw,after,region)
  print("DETAIL ",size," old difference ",old_error," new ",new_error)
  check(new_error<old_error,"new pass preserves thin text and lines better than v0.6.0 "+str(size))
  var hud_region=Rect2i(Vector2(500,944)*scale,Vector2(260,65)*scale)
  check(raw.get_region(hud_region).get_data()==after.get_region(hud_region).get_data(),"HUD remains pixel-identical "+str(size))
  check(after.get_pixelv(Vector2(905,263)*scale)==raw.get_pixelv(Vector2(905,263)*scale),"flat backgrounds receive no blur/sharpen halos "+str(size))
  before.save_png("res://tests/clarity-before-%d.png" % size.y);after.save_png("res://tests/clarity-after-%d.png" % size.y)
 overlay.queue_free();await get_tree().process_frame
 quality.screen.material=material;quality.apply()
 game.set_fullscreen(true,false);await get_tree().process_frame;await get_tree().process_frame
 var native=await capture()
 check(native.get_size()==DisplayServer.window_get_size(),"fullscreen renders actual display dimensions")
 native.save_png("res://tests/clarity-fullscreen-v061.png")
 game.set_fullscreen(false,false)
