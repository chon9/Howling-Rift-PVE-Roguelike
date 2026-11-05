extends Node2D
# Brief slash at contact makes the melee hit moment visible for last-hit timing.
var origin: Vector2
var contact: Vector2
var color: Color
var light_hit: bool = false
var elapsed: float = 0
const DURATION = 0.16
func _ready() -> void:
 z_index = Constants.Z_FX
 global_position = origin
func _process(delta: float) -> void:
 if GameState.paused: return
 elapsed += delta
 if elapsed >= DURATION: queue_free(); return
 queue_redraw()
func _draw() -> void:
 var offset = contact-origin
 var angle = offset.angle()
 var radius = maxf(24,offset.length())
 var alpha = 1.0-elapsed/DURATION
 var tint = Color(color,alpha*(0.4 if light_hit else 0.8))
 draw_arc(Vector2.ZERO,radius,angle-0.22 if light_hit else angle-0.45,angle+0.22 if light_hit else angle+0.45,20,tint,2 if light_hit else 4,true)
 draw_arc(Vector2.ZERO,radius-4,angle-0.25,angle+0.35,16,Color(1,1,1,alpha*(0.35 if light_hit else 1.0)),1 if light_hit else 2,true)
 draw_line(offset-Vector2(0,4 if light_hit else 12),offset+Vector2(0,4 if light_hit else 12),Color(1,0.9,0.6,alpha),2,true)
