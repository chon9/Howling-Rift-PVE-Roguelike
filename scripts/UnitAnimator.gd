class_name UnitAnimator
extends Node
# Animation is presentation only. Actual auto windup/release drives contact frames.
var unit
var key: String
var phase: float = 0.0
var moving: bool = false
var movement_hold: float = 0.0
var idle_phase: float = 0.0
var visual_facing_sign: int = 1
var previous_position: Vector2
var last_action: String = "idle"
var last_frame: int = 0
func _ready() -> void:
 previous_position = unit.world_pos()
func start(action: String, duration: float = 0.36) -> void:
 unit.anim_from = 0
 unit.anim_to = 5
 unit.anim_action = action
 unit.anim_elapsed = 0.0
 unit.anim_duration = duration
 unit.anim_serial += 1
func begin_attack(windup: float) -> void:
 unit.anim_windup = maxf(windup,0.001)
 unit.anim_released = false
 start("attack",windup)
func release_attack(recovery: float) -> void:
 unit.anim_released = true
 start("attack",maxf(0.08,recovery))
func cancel_attack() -> void:
 if unit.anim_action == "attack" and not unit.anim_released:
  start("idle",0)
func hit() -> void:
 # Never overwrite a real windup or skill with cosmetic hit-stun.
 if unit.anim_action in ["idle", "run"]: start("hit",0.18)
func advance(delta: float) -> void:
 if GameState.paused: return
 var distance = unit.world_pos().distance_to(previous_position)
 if distance>0.03 and distance<180:
  movement_hold = 0.06
 elif distance>=180:
  movement_hold = 0.0
 else:
  movement_hold = maxf(0.0,movement_hold-delta)
 moving = movement_hold>0.0
 previous_position = unit.world_pos()
 var stride = Constants.CHAMP_RUN_STRIDE if unit.kind=="champion" else maxf(24,unit.size*2.7*1.5)
 # About two cycles/sec at normal hero speed, without tiny-step flicker.
 if distance>0.03 and distance<180: phase += distance/stride
 idle_phase += delta*0.65
 unit.anim_elapsed += delta
 if unit.anim_elapsed>=unit.anim_duration and (unit.anim_action!="attack" or unit.anim_released):
  unit.anim_action = "idle"
 var pose = pose()
 last_action = pose.action; last_frame = pose.frame
 unit.queue_redraw()
func _process(delta: float) -> void:
 advance(delta)
func pose() -> Dictionary:
 if unit.dead: return {"action":"death","frame":5}
 if unit.stun>0: return {"action":"hit","frame":1}
 if unit.kind == "champion":
  if unit.recall_time>=0: return {"action":"recall","frame":int(unit.recall_time*5)%6}
  var charge=DeadeyeCue.channel(unit)
  if not charge.is_empty():return {"action":"r","frame":mini(3,int(charge.progress*4))}
  if unit.buffs.has("spin"):
   var spin_action = "r" if unit.hero_key=="katarina" else "e"
   if unit.anim_action in ["idle", "run", spin_action] or unit.anim_elapsed >= unit.anim_duration:
    return {"action":spin_action,"frame":int(unit.anim_elapsed*16)%6}
 if unit.anim_action=="attack":
  if not unit.anim_released:
   var remaining = unit.auto_windup if unit.kind=="champion" else unit.attack_windup
   return {"action":"attack","frame":clampi(int((1-remaining/unit.anim_windup)*3),0,2)}
  if unit.anim_elapsed<unit.anim_duration and not moving:
   return {"action":"attack","frame":3+clampi(int(unit.anim_elapsed/unit.anim_duration*3),0,2)}
 elif unit.anim_action not in ["idle","run"] and unit.anim_elapsed<unit.anim_duration:
  return {"action":unit.anim_action,"frame":unit.anim_from+clampi(int(unit.anim_elapsed/unit.anim_duration*(unit.anim_to-unit.anim_from+1)),0,unit.anim_to-unit.anim_from)}
 return {"action":"run" if moving else "idle","frame":int((phase if moving else idle_phase)*6)%6}
func draw_rect() -> Rect2:
 var value=pose()
 return ActionSpriteArt.rect(key,value.action,value.frame,Constants.CHAMP_ART_HEIGHT if unit.kind=="champion" else unit.size*2.7)
func source_rect() -> Rect2:
 var value=pose()
 return ActionSpriteArt.region(key,value.action,value.frame)
func texture() -> Texture2D:
 var value=pose()
 return ActionSpriteArt.texture_for_frame(key,value.action,value.frame)

func is_flipped() -> bool:
 # Keep the previous side when walking nearly straight up/down.
 # Tiny horizontal changes must not make the whole body flicker left/right.
 if unit.kind=="champion":
  if unit.facing.x>0.15: visual_facing_sign=1
  elif unit.facing.x< -0.15: visual_facing_sign=-1
 else: visual_facing_sign=unit.facing_sign
 return visual_facing_sign<0
