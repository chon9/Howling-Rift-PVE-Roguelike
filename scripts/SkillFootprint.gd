class_name SkillFootprint
extends RefCounted
# Ground-plane geometry. Decorative altitude and glow never define a hit area.
static func circle(radius: float,angle: float=-999.,arc: float=0.) -> Dictionary:
 return {"shape":"cone" if angle>-900 else "circle","radius":radius,"angle":angle,"arc":arc}
static func capsule(length: float,width: float) -> Dictionary:
 return {"shape":"capsule","length":length,"width":width}
static func contains(shape: Dictionary,point: Vector2,padding: float=0.) -> bool:
 match shape.shape:
  "capsule":return Geometry2D.get_closest_point_to_segment(point,Vector2(-shape.length*.5,0),Vector2(shape.length*.5,0)).distance_to(point)<=shape.width+padding
  "rectangle":return absf(point.x)<=shape.length*.5+padding and absf(point.y)<=shape.width+padding
  "cone":return point.length()<=shape.radius+padding and absf(wrapf(point.angle()-shape.angle,-PI,PI))<=shape.arc*.5
  "ring":return point.length()<=shape.radius+shape.get("outer_width",0.)+padding and absf(point.length()-shape.radius)<=shape.width+padding
  _:return point.length()<=shape.radius+padding
static func polygon(shape: Dictionary) -> PackedVector2Array:
 var points=PackedVector2Array()
 match shape.shape:
  "rectangle":return PackedVector2Array([Vector2(-shape.length*.5,-shape.width),Vector2(shape.length*.5,-shape.width),Vector2(shape.length*.5,shape.width),Vector2(-shape.length*.5,shape.width)])
  "capsule":
   for side in range(2):
    var center=Vector2(shape.length*.5 if side==0 else -shape.length*.5,0)
    for i in range(17):points.append(center+Vector2.from_angle(-PI*.5+side*PI+i*PI/16.)*shape.width)
  "cone":
   points.append(Vector2.ZERO)
   for i in range(33):points.append(Vector2.from_angle(shape.angle-shape.arc*.5+shape.arc*i/32.)*shape.radius)
  "box":
   for i in range(5):points.append(Vector2.from_angle(-PI*.5+i*TAU/5.)*shape.radius)
  _:
   for i in range(64):points.append(Vector2.from_angle(i*TAU/64.)*shape.radius)
 return points
static func draw_outline(canvas: CanvasItem,shape: Dictionary,tint: Color,fill: bool=false) -> void:
 if shape.shape in ["circle","marker","ring"]:
  if fill and shape.shape!="ring":canvas.draw_circle(Vector2.ZERO,shape.radius,Color(tint,.12))
  canvas.draw_arc(Vector2.ZERO,shape.radius,0,TAU,64,Color(.015,.025,.04,tint.a),4.,true)
  canvas.draw_arc(Vector2.ZERO,shape.radius,0,TAU,64,tint,1.6,true)
  if shape.shape=="ring":
   canvas.draw_arc(Vector2.ZERO,maxf(0.,shape.radius-shape.width),0,TAU,64,Color(tint,.35),1.,true)
   if shape.get("outer_width",0.)>0.:canvas.draw_arc(Vector2.ZERO,shape.radius+shape.outer_width,0,TAU,64,Color(tint,.35),1.,true)
  return
 var points=polygon(shape)
 if fill and shape.shape!="ring":canvas.draw_colored_polygon(points,Color(tint,.12))
 points.append(points[0]);canvas.draw_polyline(points,Color(.015,.025,.04,tint.a),4.,true);canvas.draw_polyline(points,tint,1.6,true)
static func draw_clipped(canvas: CanvasItem,texture: Texture2D,region: Rect2,rect: Rect2,shape: Dictionary,tint: Color) -> void:
 var bounds=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
 for points in Geometry2D.intersect_polygons(polygon(shape),bounds):
  var uv=PackedVector2Array()
  for p in points:uv.append((region.position+(p-rect.position)/rect.size*region.size)/texture.get_size())
  canvas.draw_colored_polygon(points,tint,uv,texture)

# Explicit impact geometry, separate from cast/target acquisition range.
const AREA_RADII={"soraka_q":105.,"soraka_e":120.,"janna_r":240.,"lux_e":120.,"annie_r":200.,"yasuo_r":140.,"leesin_e":170.,"zed_e":135.,"katarina_w":140.,"katarina_r":140.,"garen_e":72.,"darius_q":165.,"malphite_e":165.,"malphite_r":160.,"veigar_w":150.,"veigar_e":155.,"morgana_w":145.,"morgana_r":230.,"leona_w":165.,"leona_r":145.,"blitzcrank_r":230.,"renekton_q":160.,"renekton_r":140.,"xinzhao_r":220.,"riven_q":110.,"riven_w":125.,"caitlyn_w":35.,"brand_w":140.,"syndra_q":110.,"xerath_w":145.,"xerath_r":130.}
const SHOT_SIZES={"lux_q":10.,"ahri_q":13.,"ahri_e":12.,"ezreal_q":8.,"ezreal_w":11.,"ezreal_r":30.,"ashe_r":16.,"zed_q":10.,"jinx_w":10.,"jinx_r":24.,"kayle_q":10.,"caitlyn_q":12.,"riven_r":20.}
const SHOT_REACH={"lux_q":585.,"ahri_q":520.,"ahri_e":585.,"ezreal_q":680.,"ezreal_w":585.,"ezreal_r":1430.,"ashe_r":2800.,"zed_q":975.,"jinx_w":787.5,"jinx_r":1800.,"kayle_q":975.,"morgana_q":637.5,"thresh_q":750.,"leesin_q":712.5,"sivir_q":648.}
static func preview(c,skill: Dictionary) -> Dictionary:
 var id=skill.cast_id;var kind=skill.get("kind","self");var reach=float(skill.get("range",0.))
 var result={"shape":"marker","radius":18.,"at":"cursor","reach":reach}
 if AREA_RADII.has(id):
  result=circle(AREA_RADII[id]);result.at="self" if kind=="self" else "cursor";result.reach=reach
 elif kind=="line":result=capsule(SHOT_REACH.get(id,reach),SHOT_SIZES.get(id,10.));result.at="line";result.reach=reach
 elif kind=="self":result={"shape":"none","at":"self","reach":reach}
 if id=="annie_w":result=circle(300.,0.,1.2);result.at="cone";result.reach=reach
 if id=="darius_e":result=circle(220.,0.,acos(.35)*2.);result.at="cone";result.reach=reach
 if id=="syndra_e":result=circle(210.,0.,acos(.2 if c.passive_state.get("splinters",0)>=80 else .5)*2.);result.at="cone";result.reach=reach
 if id=="thresh_e":result={"shape":"rectangle","length":440.,"width":65.,"at":"direction","reach":reach}
 if id=="thresh_r":result={"shape":"box","radius":180.,"at":"self","reach":reach}
 if id=="lux_r":result={"shape":"rectangle","length":1100.,"width":32.,"at":"line","reach":reach}
 if id=="lucian_q":result=capsule(620.,26.);result.at="line";result.reach=reach
 if id=="xinzhao_w":result=capsule(470.,42.);result.at="line";result.reach=reach
 if id=="xerath_q":
  var charge=c.buffs.get("arcanopulse",{});var length=350.+400.*clampf((1.5-charge.get("time",1.5))/1.5,0.,1.)
  result=capsule(length,30.);result.at="line";result.reach=length
 if id=="yasuo_w":result={"shape":"rectangle","length":50.,"width":90.,"at":"wall","reach":reach}
 if id=="yasuo_q":result=capsule(487.5,20. if c.buffs.get("tempest",{}).get("stacks",0)==2 else 9.);result.at="line";result.reach=reach
 if id=="syndra_w" and c.buffs.has("force_of_will"):result=circle(135.);result.at="cursor";result.reach=reach
 if id=="brand_e":
  var target=NewHeroKits.target(c,GameState.cursor_world if ViewConfig.is_active() else c.get_global_mouse_position(),reach)
  result=circle(190. if is_instance_valid(target) and target.buffs.has("blaze") else 95.);result.at="target";result.reach=reach
 if id=="jinx_e":result={"shape":"traps","radius":32.,"at":"cursor","reach":reach}
 if id=="ashe_w":result=circle(930.,0.,.72);result.at="cone";result.reach=reach
 if id=="janna_r":result=circle(240.);result.at="self";result.reach=reach
 if id=="lux_w":result=circle(250.);result.at="self";result.reach=reach
 if id=="ahri_w":result=circle(420.);result.at="self";result.reach=reach
 if id=="sivir_r":result=circle(450.);result.at="self";result.reach=reach
 if id=="thresh_w":result=circle(100.);result.at="cursor";result.reach=reach
 # A targeted spell shows target selection, never an invented damage circle.
 if kind=="target" and not AREA_RADII.has(id) and id not in ["brand_e","lucian_q"]:result.shape="marker"
 if kind=="passive":result.shape="none"
 return result
