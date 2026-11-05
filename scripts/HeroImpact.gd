extends Node2D
var row=0
var radius=20.
var elapsed=0.
var duration=.26
var angle=0.
func _ready() -> void:
 z_index=Constants.Z_FX
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 if row!=3:
  var glow=CanvasItemMaterial.new();glow.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=glow
func _process(delta: float) -> void:
 if GameState.paused:return
 elapsed+=delta;queue_redraw()
 if elapsed>=duration:queue_free()
func _draw() -> void:
 var progress=clampf(elapsed/duration,0,1)
 var frame=mini(3,int(progress*4))
 var scale_factor=lerpf(.96,1.04,progress) if row==3 else lerpf(.9,1.05,progress)
 var r=radius*scale_factor
 var fade=1.-smoothstep(.65,1.,progress)
 draw_set_transform(Vector2.ZERO,angle if row!=3 else 0.)
 draw_texture_rect_region(CombatFeedbackArt.impact_texture(),visual_rect(r),CombatFeedbackArt.frame(CombatFeedbackArt.impact_texture(),row,frame,4),Color(1,1,1,fade*(.85 if row==3 else 1.)))
 # A very short white contact core makes the hit readable even over spell pools.
 if row!=3 and progress<.24:draw_circle(Vector2.ZERO,lerpf(3.,1.,progress/.24),Color(1,1,.9,(1.-progress/.24)*.8))
func visual_rect(r: float) -> Rect2:
 # Soul flames grow upward from the victim's feet; hits stay centered on contact.
 return Rect2(-r*.7,-r*2.2,r*1.4,r*2.2) if row==3 else Rect2(-r,-r,r*2,r*2)
