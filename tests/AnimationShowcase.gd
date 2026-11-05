extends Node2D
# Native render QA, using the same animator/atlases as matches.
var units = []
var homes = []
var caption: Label
var stages = ["idle","run","run","attack","q","w","e","r","hit","recall","death"]
func label_at(text: String, at: Vector2, font_size: int, width: float = 280) -> Label:
 var label = Label.new()
 label.text = text; label.position = at; label.size.x = width
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("cdd8df"))
 add_child(label)
 return label
func _draw() -> void:
 draw_rect(Rect2(0,0,1920,1080),Color("121e2a"))
 for row in range(3):
  for col in range(6 if row<2 else 5):
   var center = Vector2(210+300*col,365+290*row)
   draw_rect(Rect2(center-Vector2(138,192),Vector2(276,256)),Color("192b3a"),true)
   draw_line(center+Vector2(-105,0),center+Vector2(105,0),Color("47717c"),1.5)
func _ready() -> void:
 Progression.persistent=false; GameState.reset()
 get_window().size=Vector2i(1920,1080)
 label_at("HOWLING RIFT  /  ACTION ANIMATION REVIEW",Vector2(280,25),34,1360)
 caption=label_at("",Vector2(280,78),26,1360)
 var heroes=["yasuo","leesin","garen","katarina","zed","jinx","kayle","ashe","annie","lux","ahri","ezreal"]
 for i in range(heroes.size()):
  var c=load("res://scripts/Champion.gd").new(); add_child(c)
  c.setup(Constants.BLUE,heroes[i],true,"")
  c.name_label.hide(); c.skill_ranks=[1,1,1,0]; c.scale=Vector2(1.3,1.3)
  c.animator.set_process(false)
  c.global_position=Vector2(210+300*(i%6),365+290*(i/6))
  units.append(c);homes.append(c.global_position)
  label_at(heroes[i].capitalize(),c.global_position+Vector2(-140,28),23)
 for i in range(5):
  var key=["melee","caster","siege","super","tibbers"][i]
  var m=load("res://scripts/Minion.gd").new();add_child(m)
  m.setup(Constants.BLUE,key,Vector2(210+300*i,945));m.scale=Vector2(1.6,1.6)
  m.animator.set_process(false)
  units.append(m);homes.append(m.global_position)
  label_at(key.capitalize(),m.global_position+Vector2(-140,28),23)
 var folder="res://tests/animation-frames"
 DirAccess.make_dir_recursive_absolute(folder)
 for stage in range(stages.size()):
  var action=stages[stage]
  caption.text="%s  /  six articulated frames  /  runtime ground anchors" % ("Run left" if stage==2 else action.capitalize())
  for u in units:
   u.buffs.clear();u.stun=0;u.animator.start(action,1)
   if u.kind=="champion":u.recall_time=-1
  for frame in range(24):
   var t=frame/24.0
   for index in range(units.size()):
    var u=units[index]
    var a=action if u.kind=="champion" or action in ["idle","run","attack","hit","death"] else "idle"
    u.global_position=homes[index]+Vector2((40*t if stage==1 else -40*t if stage==2 else 0),0)
    u.animator.moving=a=="run";u.animator.phase=t;u.anim_action=a;u.anim_duration=1.;u.anim_elapsed=t
    if u.kind=="champion":u.facing=Vector2.LEFT if stage==2 else Vector2.RIGHT
    else:u.facing_sign=-1 if stage==2 else 1
    if a=="attack":
     u.anim_windup=.5;u.anim_released=t>=.5
     if u.anim_released:u.anim_duration=.5;u.anim_elapsed=t-.5
     elif u.kind=="champion":u.auto_windup=.5-t
     else:u.attack_windup=.5-t
    if a=="recall":u.recall_time=t*1.2
    u.queue_redraw()
   await RenderingServer.frame_post_draw
   if frame==12:get_viewport().get_texture().get_image().save_png("res://tests/animation-review-%s.png" % ("run-left" if stage==2 else action))
   get_viewport().get_texture().get_image().save_png(folder+"/frame-%04d.png" % (stage*24+frame))
 print("NATIVE ANIMATION REVIEW: 17 units, 11 action stages, 264 rendered frames")
 get_tree().quit()
