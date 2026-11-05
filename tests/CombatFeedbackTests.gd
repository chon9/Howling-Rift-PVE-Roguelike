extends Node
var game
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL FEEDBACK: "+message)
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 game.camera.position=Vector2(1300,270);game.camera.reset_smoothing()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/feedback-"+name+"-v034.png")
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game._start_game("yasuo");game.set_process(false)
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Vector2(2000,270)
 var p=GameState.player;var enemy=GameState.champions[3]
 p.global_position=Vector2(1240,270);enemy.global_position=Vector2(1330,270);enemy.hp_max=10000.;enemy.hp=10000.;enemy.shield=0
 for texture in [CombatFeedbackArt.impact_texture(),CombatFeedbackArt.banner_texture()]:check(texture!=null,"generated atlas loads")
 for row in range(4):
  for frame in range(4):check(Rect2(Vector2.ZERO,CombatFeedbackArt.impact_texture().get_size()).encloses(CombatFeedbackArt.frame(CombatFeedbackArt.impact_texture(),row,frame,4)),"impact frame in atlas")
 for row in range(6):
  check(CombatFeedbackArt.banner_texture(row)!=null and CombatFeedbackArt.banner_texture(row).get_size().x>0,"complete standalone crest loads")
 var before=game.world_root.get_child_count()
 game.deal_damage(p,enemy,80,"auto")
 check(enemy.hit_flash>0 and enemy.hp<10000,"hero damage flashes on contact")
 var impacts=game.world_root.get_children().filter(func(n):return n.get_script()==load("res://scripts/HeroImpact.gd"))
 check(impacts.size()==1 and impacts[0].row==0,"physical hit creates gold sprite impact")
 check(impacts[0].radius>=16. and impacts[0].radius<=26.,"normal impacts stay smaller than the hero")
 impacts[0].set_process(false);impacts[0].elapsed=.09;impacts[0].queue_redraw()
 await capture("gold-impact")
 enemy.update_frame(.2)
 check(enemy.hit_flash==0,"damage flash expires")
 game.hero_impact_times.clear();game.deal_damage(p,enemy,130,"magic")
 impacts=game.world_root.get_children().filter(func(n):return n.get_script()==load("res://scripts/HeroImpact.gd") and not n.is_queued_for_deletion())
 check(impacts.any(func(n):return n.row==1),"magic damage creates magic sprite impact")
 var count=impacts.size();game.deal_damage(p,enemy,1,"magic")
 impacts=game.world_root.get_children().filter(func(n):return n.get_script()==load("res://scripts/HeroImpact.gd") and not n.is_queued_for_deletion())
 check(impacts.size()==count,"rapid same-target damage bounds effect spam")
 var ui=game.hud.get_node("HudRoot")
 for index in range(5):
  for fx in game.world_root.get_children():
   if fx.get_script() in [load("res://scripts/HeroImpact.gd"),load("res://scripts/FloatingText.gd")]:fx.queue_free()
  await get_tree().process_frame
  game._respawn_champion(enemy);enemy.global_position=Vector2(1330,270)
  GameState.time=float(index)
  game.deal_damage(p,enemy,enemy.hp+enemy.shield+1.,"exec")
  var souls=game.world_root.get_children().filter(func(n):return n.get_script()==load("res://scripts/HeroImpact.gd") and n.row==3)
  check(souls.size()==1 and souls[0].global_position==enemy.world_pos(),"kill flame is anchored to victim feet")
  check(souls[0].visual_rect(34.).end.y==0. and souls[0].visual_rect(34.).size.x<Constants.CHAMP_ART_HEIGHT,"kill flame footprint fits the hero")
  var banner=ui.kill_celebration
  check(enemy.dead and ui.announcement.visible and banner.visible,"kill banner appears immediately")
  check(banner.row==index,"consecutive kills increase crest tier")
  check(banner.mouse_filter==Control.MOUSE_FILTER_IGNORE and ui.announcement.mouse_filter==Control.MOUSE_FILTER_IGNORE,"kill celebration never intercepts attacks or movement")
  banner.set_process(false);banner.elapsed=.45;banner.queue_redraw()
  game.lane_augments._process(.01)
  check(not game.lane_augments.ready_prompt.visible,"build-ready prompt yields to kill celebration")
  await capture(["ko","double","triple","quadra","penta"][index])
 check(ui.kill_celebration.headline=="SAVAGE","multikill banner has clear title")
 ui.kill_celebration._process(4.);ui.refresh(4.)
 check(not ui.announcement.visible and not ui.kill_celebration.visible,"celebration fades and expires")
 game._return_to_main_menu();check(game.hero_impact_times.is_empty(),"second match clears impact throttles")
 print("COMBAT FEEDBACK: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
