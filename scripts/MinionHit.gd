extends Node2D
# Tiny contact marks, never a radial explosion over the wave.
var elapsed: float = 0.0
const DURATION = 0.12
func _ready() -> void:
 z_index = Constants.Z_FX
func _process(delta: float) -> void:
 if GameState.paused: return
 elapsed += delta
 if elapsed>=DURATION: queue_free(); return
 queue_redraw()
func _draw() -> void:
 var alpha = (1.0-elapsed/DURATION)*0.6
 var length = 3.0+elapsed/DURATION*3.0
 draw_line(Vector2(-length,-12-length),Vector2(length,-12+length),Color(0.9,0.83,0.65,alpha),1.4,true)
 draw_line(Vector2(-length,-12+length),Vector2(length,-12-length),Color(1,0.94,0.8,alpha*0.7),1,true)
