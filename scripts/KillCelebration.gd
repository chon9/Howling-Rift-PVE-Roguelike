extends Control
var elapsed=0.
var duration=2.7
var row=0
var headline="K.O."
var subtitle=""
var team=0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 hide()
func play(title: String,hero: String,killer_team: int) -> void:
 row={"DOUBLE KILL":1,"TRIPLE KILL":2,"MANIAC":3,"SAVAGE":4,"KILLING SPREE":5,"MEGA KILL":1,"UNSTOPPABLE":2,"MONSTER KILL":3,"GODLIKE":4,"LEGENDARY":4,"SHUTDOWN":5}.get(title,0)
 team=killer_team
 headline="K.O." if title in ["ENEMY SLAIN","CHAMPION SLAIN","FIRST BLOOD"] else title
 subtitle=("FIRST BLOOD · " if title=="FIRST BLOOD" else "")+hero
 elapsed=0.;duration=2.7 if row==0 else 3.2
 show();queue_redraw()
func _process(delta: float) -> void:
 if not visible or GameState.paused:return
 elapsed+=delta;queue_redraw()
 if elapsed>=duration:hide()
func art_rect() -> Rect2:
 var texture=CombatFeedbackArt.banner_texture(row)
 var entry=clampf(elapsed/.22,0.,1.)
 var pop=1.+sin(entry*PI)*.04
 var aspect=texture.get_width()/float(texture.get_height())
 var width=minf(520.,minf(size.x*.92,size.y*.94*aspect))*pop
 var dimensions=Vector2(width,width/aspect)
 return Rect2(size*.5-dimensions*.5,dimensions)
func text_rect() -> Rect2:
 var rect=art_rect()
 # Each generated crest has a different plaque; keep lettering away from gems and rims.
 var plaques=[Rect2(.32,.355,.36,.27),Rect2(.345,.405,.31,.235),Rect2(.345,.385,.31,.23),Rect2(.33,.40,.34,.235),Rect2(.35,.415,.30,.23),Rect2(.35,.415,.30,.23)]
 var plaque: Rect2=plaques[row]
 return Rect2(rect.position+rect.size*plaque.position,rect.size*plaque.size)
func fitted_size(text: String,width: float,maximum: int) -> int:
 var font=CombatFeedbackArt.font()
 var result=maximum
 while result>10 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x>width:result-=1
 return result
func clipped_text(text: String,width: float,font_size: int) -> String:
 var font=CombatFeedbackArt.font()
 if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=width:return text
 var short=text
 while short.length()>1 and font.get_string_size(short+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:short=short.left(short.length()-1)
 return short+"…"
func lettering() -> Dictionary:
 var safe=text_rect()
 var font=CombatFeedbackArt.font()
 var headline_height=safe.size.y*.62
 var font_size=fitted_size(headline,safe.size.x-12,34 if headline=="K.O." else 28)
 while font_size>10 and font.get_height(font_size)>headline_height:font_size-=1
 var title_center=safe.position+Vector2(safe.size.x*.5,headline_height*.5)
 var baseline=title_center+Vector2(-font.get_string_size(headline,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,(font.get_ascent(font_size)-font.get_descent(font_size))*.5)
 var small_size=fitted_size(subtitle,safe.size.x-12,13)
 var sub_text=clipped_text(subtitle,safe.size.x-12,small_size)
 var subtitle_center=safe.position+Vector2(safe.size.x*.5,headline_height+(safe.size.y-headline_height)*.5)
 var sub_pos=subtitle_center+Vector2(-font.get_string_size(sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,small_size).x*.5,(font.get_ascent(small_size)-font.get_descent(small_size))*.5)
 return {"title_size":font_size,"title_pos":baseline,"sub_size":small_size,"sub_text":sub_text,"sub_pos":sub_pos}
func _draw() -> void:
 var fade=1.-smoothstep(duration-.45,duration,elapsed)
 draw_texture_rect(CombatFeedbackArt.banner_texture(row),art_rect(),false,Color(1,1,1,fade))
 var layout=lettering()
 var font=CombatFeedbackArt.font()
 draw_string_outline(font,layout.title_pos,headline,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.title_size,2,Color(.025,.025,.035,fade))
 draw_string(font,layout.title_pos,headline,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.title_size,Color(1.,.87,.55,fade))
 draw_string(font,layout.sub_pos,layout.sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.sub_size,Color(.8,.85,.9,fade))
