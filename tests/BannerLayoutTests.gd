extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL BANNER LAYOUT: "+message)
func _ready() -> void:
 await get_tree().process_frame
 var background=ColorRect.new();background.color=Color("0c1624");background.size=Vector2(1920,1080);add_child(background)
 var font=CombatFeedbackArt.font()
 var titles=["FIRST BLOOD","DOUBLE KILL","TRIPLE KILL","MANIAC","SAVAGE","KILLING SPREE","MEGA KILL","UNSTOPPABLE","MONSTER KILL","GODLIKE","LEGENDARY","SHUTDOWN","ALLY SLAIN"]
 var seen={}
 for title in titles:
  var banner=load("res://scripts/KillCelebration.gd").new();add_child(banner)
  banner.size=Vector2(604,174);banner.play(title,"Very long summoner name with brackets [Alexander the Unstoppable]",0);banner.set_process(false)
  seen[banner.row]=CombatFeedbackArt.banner_texture(banner.row).resource_path
  for phase in [0.,.11,.45,banner.duration-.2]:
   banner.elapsed=phase
   check(Rect2(Vector2.ZERO,banner.size).encloses(banner.art_rect()),title+" whole crest stays inside control throughout animation")
   var safe=banner.text_rect();var layout=banner.lettering()
   for line in [[banner.headline,layout.title_size,layout.title_pos],[layout.sub_text,layout.sub_size,layout.sub_pos]]:
    var bounds=Rect2(line[2]-Vector2(0,font.get_ascent(line[1])),Vector2(font.get_string_size(line[0],HORIZONTAL_ALIGNMENT_LEFT,-1,line[1]).x,font.get_height(line[1])))
    check(safe.grow(.1).encloses(bounds),title+" lettering fits inside clear plaque")
    check(absf(bounds.get_center().x-safe.get_center().x)<.1,title+" lettering is centered")
   check(layout.sub_text.ends_with("…"),"long subtitle shortens safely")
  banner.queue_free()
 check(seen.size()==6 and seen.values().all(func(path):return path.begins_with("res://assets/vfx/crests-v2/")),"six separate complete crest textures")
 for index in range(6):
  var banner=load("res://scripts/KillCelebration.gd").new();add_child(banner)
  banner.position=Vector2(320+(index%2)*680,150+int(index/2)*270);banner.size=Vector2(604,174)
  banner.play(["FIRST BLOOD","DOUBLE KILL","TRIPLE KILL","MONSTER KILL","LEGENDARY","KILLING SPREE"][index],"Windblade",0)
  banner.set_process(false);banner.elapsed=.45;banner.queue_redraw()
 await get_tree().process_frame;await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/banner-gallery-v034.png")
 print("BANNER LAYOUT: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
