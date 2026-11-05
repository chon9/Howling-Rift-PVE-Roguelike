extends Node2D
# Read only presentation. All durations come from host gameplay / replicated buffs.
var unit
var phase: float = 0.0
var stun_remaining: float = 0.0
var ignite_remaining: float = 0.0
var silence_remaining: float = 0.0
var shield_amount: float = 0.0
var shield_pulse: float = 0.0
var heal_remaining: float = 0.0
var previous_hp: float = -1.0
var previous_hp_max: float = -1.0
var statuses: Array = []
var primary_status: Dictionary = {}
var fire_texture: Texture2D
var font: Font = WorldTextFont.get_font()
var badge_boxes: Dictionary = {}
# Rift3D: ALL draws everything (classic 2D). In 3D the unit's own instance is GROUND (ground marks in the
# overlay) and OverheadLayer adds OVERHEAD (badges, icons) and BODY (shield/guard/burn, lock reticle) copies.
const MODE_ALL=0
const MODE_GROUND=1
const MODE_OVERHEAD=2
const MODE_BODY=3
var mode := MODE_ALL
const PRIMARY_IDS := ["airborne","stun","silence","root"]   # crowd control shown as the primary badge
# Perf: what the last redraw showed (_redraw_key). A frame whose key is unchanged skips the redraw; the key holds
# everything _draw reads except continuous animation, which redraws every frame (_redraw_key returns null).
var _drawn_key: Array = []
var _drawn_valid := false

func _ready() -> void:
 z_index = Constants.Z_FX-Constants.Z_UNITS
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 fire_texture = StatusArt.texture("burn")
 refresh()

func refresh() -> void:
 if not is_instance_valid(unit):return
 stun_remaining=maxf(0.,unit.stun) if not unit.dead else 0.
 ignite_remaining=maxf(0.,float(unit.buffs.get("ignite",{}).get("time",0.))) if not unit.dead else 0.
 silence_remaining=maxf(0.,float(unit.buffs.get("silence",{}).get("time",0.))) if not unit.dead else 0.
 var next_shield=maxf(0.,unit.shield) if unit.kind=="champion" and not unit.dead else 0.
 if next_shield!=shield_amount:shield_pulse=.3 if next_shield>shield_amount else .18
 shield_amount=next_shield
 if not unit.dead and previous_hp>=0 and is_equal_approx(previous_hp_max,unit.hp_max) and unit.hp-previous_hp>=maxf(1.,unit.hp_max*.005):heal_remaining=.7
 previous_hp=unit.hp;previous_hp_max=unit.hp_max
 if unit.dead:heal_remaining=0.
 # Perf fast path (identical result): a dead unit, or a non-champion with no stun, no buffs and no heal cue, has
 # nothing to show (StatusArt.collect is empty, Deadeye needs a buff or a champion target, ignite needs a buff).
 if unit.dead or (unit.kind!="champion" and unit.stun<=0 and unit.buffs.is_empty() and heal_remaining<=0):
  if not statuses.is_empty():statuses=[]
  primary_status={}
  visible=false
  return
 statuses=_collect()
 if heal_remaining>0:statuses.append({"id":"heal","label":"HEALING","time":heal_remaining,"stacks":0,"detail":"Health restored."})
 primary_status={}
 for status in statuses:
  if status.id in PRIMARY_IDS:primary_status=status;break
 if primary_status.is_empty() and ignite_remaining>0:
  primary_status={"id":"burn","label":"IGNITE","time":ignite_remaining}
 visible=not unit.dead and (not statuses.is_empty() or not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty() or unit.buffs.has("artillery") or unit.buffs.has("arcanopulse") or unit.buffs.has("parry") or unit.buffs.has("roster_attack"))
 # Hidden items are not drawn, and Godot redraws a CanvasItem when it becomes visible in the tree again.
 if not visible or not is_visible_in_tree():return
 var key=_redraw_key()
 if typeof(key)==TYPE_NIL:
  _drawn_valid=false
  queue_redraw()
 elif not _drawn_valid or key!=_drawn_key:
  _drawn_key=key;_drawn_valid=true
  queue_redraw()

## Everything _draw shows for the current mode, or null while the drawing animates every frame (Deadeye aim and
## lock cues, a shield pulse, an airborne lift in classic 2D). Sprites step at 8 fps and timers at 0.1 s.
func _redraw_key():
 var m=mode
 if m==MODE_ALL and ViewConfig.is_active():m=MODE_GROUND
 if m==MODE_GROUND:
  # GROUND (the unit's own instance in 3D) draws only the vital / grand challenge marks under the unit.
  var vital_key=_vital_key()
  return [m,unit.buffs[vital_key].get("side") if unit.buffs.has(vital_key) else null,unit.buffs.grand_challenge.get("mask") if unit.buffs.has("grand_challenge") else null]
 var champion=unit.kind=="champion"
 if (unit.buffs.has("deadeye") and not DeadeyeCue.channel(unit).is_empty()) or (champion and not DeadeyeCue.locks_on(unit).is_empty()):return null
 if shield_pulse>0. and shield_amount>0. and m!=MODE_OVERHEAD:return null
 var guard=false
 var burn=false
 for status in statuses:
  if status.id=="guard":guard=true
  elif status.id=="burn":burn=true
 if m==MODE_BODY:
  # BODY draws only the shield / guard / burn sprites (the lock ring returned null above).
  var drawn=shield_amount>0. or guard or burn
  return [m,int(phase*8.) if drawn else 0,shield_amount>0.,guard,burn,unit.size]
 if m==MODE_ALL and unit.buffs.has("airborne") and HeroControl.lift(unit)!=0.:return null
 var key=[m,int(phase*8.),unit==GameState.player,shield_amount>0.]
 if not champion:key.append_array([unit.size,unit.get("facing_sign")])
 for status in statuses:key.append_array([status.id,status.stacks])
 if not primary_status.is_empty():key.append_array([primary_status.id,primary_status.label,ceilf(primary_status.time*10.)])
 # Buff-driven drawings that are not status icons: rifle mark, vital / challenge marks, roster badges.
 if unit.buffs.has("rifle_mark"):key.append("rifle_mark")
 var vital=_vital_key()
 if unit.buffs.has(vital):key.append_array(["vital",unit.buffs[vital].get("side")])
 if unit.buffs.has("grand_challenge"):key.append_array(["grand",unit.buffs.grand_challenge.get("mask")])
 for k in ["roster_attack","artillery","parry"]:
  if unit.buffs.has(k):
   var b=unit.buffs[k]
   key.append_array([k,b.get("hits"),b.get("shots"),"%.1f" % float(b.get("time",0.))])
 if unit.buffs.has("arcanopulse"):key.append("arcanopulse")
 return key

# Rift3D perf: a unit's GROUND, OVERHEAD and BODY instances share one StatusArt.collect while its inputs (dead, stun,
# shield and a deep snapshot of buffs) are unchanged; any change, including one made between two refresh() calls in
# the same frame, recomputes. Classic 2D has one instance per unit and always collects directly.
static var _collect_cache: Dictionary = {}
func _collect() -> Array:
 if not ViewConfig.is_active():return StatusArt.collect(unit)
 var id=unit.get_instance_id()
 var hit=_collect_cache.get(id)
 var shield=unit.get("shield")
 if hit!=null and hit[0]==unit.dead and hit[1]==unit.stun and hit[2]==shield and hit[3]==unit.buffs:
  return hit[4].duplicate()
 var result=StatusArt.collect(unit)
 if _collect_cache.size()>1024:_collect_cache.clear()
 _collect_cache[id]=[unit.dead,unit.stun,shield,unit.buffs.duplicate(true),result.duplicate()]
 return result

static var _vital_player=null
static var _vital_count:=-1
static var _vital_text:=""
## "vital_<player index>" (the local player's Exposed Vital buff key), cached while the player and roster hold.
static func _vital_key() -> String:
 if not is_instance_valid(GameState.player):return ""
 if GameState.player!=_vital_player or GameState.champions.size()!=_vital_count:
  _vital_player=GameState.player;_vital_count=GameState.champions.size()
  _vital_text="vital_"+str(GameState.champions.find(GameState.player))
 return _vital_text

func _process(delta: float) -> void:
 if not GameState.paused:
  phase+=delta
  shield_pulse=maxf(0.,shield_pulse-delta)
  heal_remaining=maxf(0.,heal_remaining-delta)
 # Rift3D perf: an OVERHEAD / BODY copy whose anchor OverheadLayer hid (unit off screen or dead) only keeps its
 # change trackers current, so it neither flashes a stale heal or shield cue nor pays for statuses nobody sees.
 # The first frame its anchor shows again refreshes it in full.
 if mode!=MODE_ALL and is_instance_valid(unit) and get_parent() is CanvasItem and not get_parent().visible:
  previous_hp=unit.hp;previous_hp_max=unit.hp_max
  shield_amount=maxf(0.,unit.shield) if unit.kind=="champion" and not unit.dead else 0.
  return
 refresh()

func fire_frame() -> Rect2:return StatusArt.frame_rect("burn",phase)

func effective_mode() -> int:
 if mode==MODE_ALL and ViewConfig.is_active():return MODE_GROUND
 return mode

func _badge(text: String,y: float,color: Color,_spiral: bool=false) -> void:
 var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16
 draw_style_box(_background(color),Rect2(-width/2,y-17,width,23))
 draw_string_outline(font,Vector2(-width/2+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,1,Color.BLACK)
 draw_string(font,Vector2(-width/2+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color.lightened(.35))
 draw_line(Vector2(-width/2,y+5),Vector2(width/2,y+5),color,1.5,true)

func _background(color: Color) -> StyleBoxFlat:
 if badge_boxes.has(color):return badge_boxes[color]
 var box=StyleBoxFlat.new();box.bg_color=Color(.025,.035,.055,.94);box.border_color=Color(color,.8)
 box.set_border_width_all(1);box.set_corner_radius_all(3);badge_boxes[color]=box
 return box

func _sprite(id: String,rect: Rect2,alpha: float=1.) -> void:
 draw_texture_rect_region(StatusArt.texture(id),rect,StatusArt.frame_rect(id,phase),Color(1,1,1,alpha))

func overhead_statuses() -> Array:
 # One icon per family, CC first. Full named buffs remain available in the HUD.
 var result=[];var seen={}
 if not primary_status.is_empty():seen[primary_status.id]=true
 for status in statuses:
  if unit!=GameState.player and status.id in ["haste","empower","heal","guard"]:continue
  if not seen.has(status.id):result.append(status);seen[status.id]=true
 return result

func _draw() -> void:
 if not is_instance_valid(unit) or unit.dead:return
 var m=effective_mode()
 _draw_deadeye(m);_draw_roster_status(m)
 if m==MODE_GROUND:return
 var hero=unit.kind=="champion"
 var height=Constants.CHAMP_ART_HEIGHT if hero else unit.size*2.7
 var head_y=-height-56. if hero else unit.art_rect().position.y-24.
 # Screen-space anchors already include the airborne lift.
 var lift=HeroControl.lift(unit) if m==MODE_ALL else 0.
 if not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty():head_y-=40.
 if m!=MODE_OVERHEAD:_draw_body_sprites(height,lift)
 if m==MODE_BODY:return
 # Rift3D overhead copies of minions are compact: units sit ~25% closer on screen than in 2D (foreshortened
 # ground) while overhead art keeps its 2D size, so caption badges and non-CC icons would cloud the fight.
 _draw_overhead(hero,head_y,lift,m==MODE_OVERHEAD and not hero)

func _draw_body_sprites(height: float,lift: float) -> void:
 if shield_amount>0:_sprite("shield",Rect2(-height*.66,-height*1.12-lift,height*1.32,height*1.32),.42+shield_pulse*.5)
 if statuses.any(func(status):return status.id=="guard"):_sprite("guard",Rect2(-height*.69,-height*1.15-lift,height*1.38,height*1.38),.45)
 if statuses.any(func(status):return status.id=="burn"):
  # Flames stay at the body edges; they do not obscure the torso or health bar.
  for side in [-1.,1.]:_sprite("burn",Rect2(side*height*.32-height*.18,-height*.45-lift,height*.36,height*.48),.75)

func _draw_overhead(hero: bool,head_y: float,lift: float,compact: bool=false) -> void:
 if compact:
  if not primary_status.is_empty():
   draw_circle(Vector2(0,head_y-2),12,Color(.02,.035,.06,.85))
   _sprite(primary_status.id,Rect2(-11,head_y-13,22,22))
  return
 if not primary_status.is_empty():
  var text=primary_status.label+" %.1fs" % (ceilf(primary_status.time*10.)/10.)
  var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16
  _badge(text,head_y-lift,StatusArt.color(primary_status.id))
  _sprite(primary_status.id,Rect2(-width/2-29,head_y-24-lift,28,28))
 var items=overhead_statuses();var limit=2 if hero else 1;var count=mini(items.size(),limit)
 var row_y=head_y-34.-lift if not primary_status.is_empty() else head_y-22.-lift
 # Avoid stacking status icons onto Deadeye/channel captions.
 if not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty() or unit.buffs.has("artillery") or unit.buffs.has("arcanopulse") or unit.buffs.has("parry") or unit.buffs.has("roster_attack"):row_y-=48.
 for i in range(count):
  var status=items[i];var x=(float(i)-(count-1)*.5)*29.
  draw_circle(Vector2(x,row_y+12),13,Color(.02,.035,.06,.9))
  _sprite(status.id,Rect2(x-12,row_y,24,24))
  var text=""
  if status.stacks>0:text="x%d" % status.stacks
  var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
  draw_string_outline(font,Vector2(x-width/2,row_y+30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,2,Color.BLACK)
  draw_string(font,Vector2(x-width/2,row_y+30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
 if items.size()>limit:draw_string(font,Vector2(count*14.5+3,row_y+17),"+%d" % (items.size()-limit),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)

func _draw_roster_status(m: int=MODE_ALL) -> void:
 if m==MODE_BODY:return
 var vital_key="vital_"+str(GameState.champions.find(GameState.player)) if is_instance_valid(GameState.player) else ""
 if m!=MODE_OVERHEAD and (unit.buffs.has(vital_key) or unit.buffs.has("grand_challenge")):
  var challenge=unit.buffs.has("grand_challenge");var b=unit.buffs.grand_challenge if challenge else unit.buffs[vital_key]
  for side in range(4):
   if challenge and int(b.mask)&(1<<side):continue
   if not challenge and side!=int(b.side):continue
   var direction=Vector2.from_angle(side*PI/2);var point=direction*42;var tangent=direction.orthogonal()
   draw_colored_polygon(PackedVector2Array([point-direction*9,point+direction*5+tangent*8,point+direction*5-tangent*8]),Color("f4c46f"))
   draw_arc(Vector2.ZERO,42,side*PI/2-.3,side*PI/2+.3,12,Color("fff1bc"),3.,true)
 if m==MODE_GROUND:return
 if unit.buffs.has("rifle_mark"):draw_arc(Vector2(0,-45),22,0,TAU,32,Color("e6b4ff"),2.5,true)
 if unit.kind!="champion":return
 var y=-Constants.CHAMP_ART_HEIGHT-90
 if unit.hero_key=="xinzhao" and unit.buffs.has("roster_attack"):_badge("Q • %d HITS • %.1fs" % [unit.buffs.roster_attack.hits,unit.buffs.roster_attack.time],y,Color("edc895"))
 elif unit.buffs.has("artillery"):_badge("ARTILLERY %d • %.1fs" % [unit.buffs.artillery.shots,unit.buffs.artillery.time],y,Color("8adfff"))
 elif unit.buffs.has("arcanopulse"):_badge("CHARGING • Q TO FIRE",y,Color("8adfff"))
 elif unit.buffs.has("parry"):_badge("PARRY %.1fs" % unit.buffs.parry.time,y,Color("b4d9ff"))

func _draw_deadeye(m: int=MODE_ALL) -> void:
 if m==MODE_GROUND:return
 var charge=DeadeyeCue.channel(unit)
 var gold=Color("ffd176")
 if not charge.is_empty() and DeadeyeCue.visible(charge.target) and m!=MODE_BODY:
  _badge("DEADEYE • %.1fs" % (ceilf(charge.time*10)/10.),-Constants.CHAMP_ART_HEIGHT-70,gold)
 # The aim line joins two units; in 3D OverheadLayer draws it between projected chests.
 if not charge.is_empty() and DeadeyeCue.visible(charge.target) and m==MODE_ALL:
  var direction=(charge.target.world_pos()-unit.world_pos()).normalized()
  var muzzle=Vector2(0,-28)+direction*22
  var end=charge.target.world_pos()-unit.world_pos()+Vector2(0,-28)
  draw_line(muzzle,end,Color(0.02,0.02,0.03,.8),3.5,true)
  draw_line(muzzle,end,Color(gold,.55+.3*sin(phase*18)),1.3,true)
  draw_circle(muzzle,6+charge.progress*4,Color(gold,.18))
  draw_arc(muzzle,10,phase*4,phase*4+TAU*charge.progress,32,gold,2,true)
  draw_circle(muzzle,2+charge.progress*2,Color("fff4d9"))
 if not charge.is_empty() and DeadeyeCue.visible(charge.target) and m!=MODE_BODY:
  draw_line(Vector2(-40,-Constants.CHAMP_ART_HEIGHT-62),Vector2(40,-Constants.CHAMP_ART_HEIGHT-62),Color(0,0,0,.9),5,true)
  draw_line(Vector2(-40,-Constants.CHAMP_ART_HEIGHT-62),Vector2(-40+80*charge.progress,-Constants.CHAMP_ART_HEIGHT-62),gold,3,true)
 var locks=DeadeyeCue.locks_on(unit)
 if locks.is_empty():return
 locks.sort_custom(func(a,b):return a.time<b.time)
 var lock=locks[0]
 var tint=Color("ff6e68") if is_instance_valid(GameState.player) and unit.team==GameState.player.team else gold
 if m!=MODE_OVERHEAD:
  var center=Vector2(0,-28)
  var radius=30-6*lock.progress
  draw_arc(center,radius,0,TAU,48,Color(0,0,0,.9),4,true)
  draw_arc(center,radius,-PI/2,-PI/2+TAU*(1-lock.progress),48,tint,2.5,true)
  for side in range(4):
   var d=Vector2.from_angle(side*PI/2+phase*.35)
   draw_line(center+d*(radius-5),center+d*(radius+5),tint,2,true)
 if m==MODE_BODY:return
 _badge("LOCKED • %.1fs" % (ceilf(lock.time*10)/10.),-Constants.CHAMP_ART_HEIGHT-(102 if not charge.is_empty() else 70),tint)
