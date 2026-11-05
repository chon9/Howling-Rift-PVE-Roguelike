class_name KitEffectArt
extends RefCounted
const GROUPS={"thresh": "warden-vexel", "veigar":"warden-vexel","darius":"rook-granite","malphite":"rook-granite","morgana":"noctra-vesper","vayne":"noctra-vesper"}
static var textures: Dictionary={}
static var bounds: Dictionary={}
static var ground_texture: Texture2D
static func has_effect(id: String) -> bool:
 if SupportArt.ROWS.has(id):return true
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return id.get_slice("_",1) in ["q","w","e","r","auto"]
 return GROUPS.has(id.get_slice("_",0)) and id.get_slice("_",1) in ["q","w","e","r"]
static func sheet(id: String) -> Texture2D:
 if SupportArt.ROWS.has(id):return SupportArt.sheet()
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return Roster12Art.sheet(id)
 if id in ["veigar_w","veigar_e"]:
  if ground_texture==null:ground_texture=load("res://assets/vfx/vexel-ground-v2.png")
  return ground_texture
 var group=GROUPS[id.get_slice("_",0)]
 if not textures.has(group):textures[group]=load("res://assets/vfx/"+group+"-skills-v1.png")
 return textures[group]
static func region(id: String,frame: int) -> Rect2:
 if SupportArt.ROWS.has(id):return SupportArt.region(id,frame)
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return Roster12Art.region(id,frame)
 if id in ["veigar_w","veigar_e"]:
  var cell=sheet(id).get_size()/Vector2(4,2)
  return Rect2(Vector2(clampi(frame,0,3),0 if id=="veigar_w" else 1)*cell+Vector2.ONE*2,cell-Vector2.ONE*4)
 if bounds.is_empty():bounds=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/kit-effect-crops-v1.json"))
 var hero=id.get_slice("_",0);var skill=id.get_slice("_",1)
 var row=["q","w","e","r"].find(skill)
 if hero in ["veigar","malphite","vayne"]:row+=4
 var texture=sheet(id);var cell=Vector2(texture.get_width()/4.,texture.get_height()/8.)
 var crop=bounds[GROUPS[hero]][row]
 return Rect2(Vector2(clampi(frame,0,3),row)*cell+Vector2(crop[0],crop[1]),Vector2(crop[2],crop[3]))
static func ground_rect(id: String,radius: float) -> Rect2:
 # Map the painted ground rim, rather than pillar/glow bounds, to collision radius.
 var cell=sheet(id).get_size()/Vector2(4,2)
 var rim_ratio=.39 if id=="veigar_w" else .375
 var anchor=cell*Vector2(.5,.5 if id=="veigar_w" else .48)-Vector2.ONE*2
 var scale_factor=radius/(cell.x*rim_ratio)
 return Rect2(-anchor*scale_factor,(cell-Vector2.ONE*4)*scale_factor)

static func begin_match(hero_keys: Array) -> void:
 var groups={}
 for key in hero_keys:
  if GROUPS.has(key):groups[GROUPS[key]]=true
 for group in textures.keys():
  if not groups.has(group):textures.erase(group)
 if "veigar" not in hero_keys:ground_texture=null
 Roster12Art.trim_skill_sheets(hero_keys)

# Ground anchors measured in the original atlas cell: x/y center and rim x/y radii.
# Keep this coordinate system across frames; tight per-frame crops cannot define it.
const GROUND_PROFILES={
 "brand_w":Vector4(.5,.86,.34,.10),
 "leona_r":Vector4(.5,.78,.35,.14),
 "xerath_w":Vector4(.5,.76,.34,.17),
 "xerath_r":Vector4(.5,.76,.35,.18),
 "thresh_r":Vector4(.5,.61,.39,.30)}
static func has_ground_profile(id: String) -> bool:return GROUND_PROFILES.has(id)
# Rift3D: kit art painted from the side rather than from above (missiles, comets, slashes, fists, volleys, upright
# weapons). A plain circular AoE with one of these ids stands up as a ZoneProp3D card in 3D and its ground keeps
# only a soft disc and rim; top-down art (sigils, rings, pools, auras) keeps drawing flat.
const STANDING={"leona_q":true,"leona_e":true,"blitzcrank_q":true,"blitzcrank_e":true,"renekton_w":true,"renekton_e":true,
 "xinzhao_w":true,"riven_q":true,"riven_e":true,"riven_r":true,"fiora_q":true,"fiora_w":true,"fiora_e":true,
 "caitlyn_q":true,"caitlyn_e":true,"caitlyn_r":true,"lucian_q":true,"lucian_e":true,"lucian_r":true,"sivir_q":true,
 "sivir_w":true,"brand_q":true,"brand_e":true,"brand_r":true,"syndra_w":true,"syndra_e":true,"syndra_r":true,
 "xerath_q":true,"xerath_e":true,"darius_w":true,"darius_e":true,"darius_r":true,"malphite_q":true,"veigar_q":true,
 "veigar_r":true,"morgana_q":true,"vayne_q":true,"vayne_e":true,"vayne_r":true,"thresh_q":true,"soraka_w":true,
 "janna_q":true,"janna_w":true}
# Rift3D: side-view bands swept along effect_dir (Thresh E flay chains, Xin Zhao W capsule sweep) stand up as a
# raised ribbon along their footprint in 3D; the footprint keeps only a soft outline on the ground.
const BANDS={"thresh_e":true,"xinzhao_w":true}
static func stands_upright(id: String) -> bool:return STANDING.has(id)
static func is_band(id: String) -> bool:return BANDS.has(id)
static func ground_region(id: String,frame: int) -> Rect2:
 var cell=sheet(id).get_size()/Vector2(4,4 if id.get_slice("_",0) in RosterExpansion12.KEYS else 8)
 var row=["q","w","e","r"].find(id.get_slice("_",1))
 return Rect2(Vector2(clampi(frame,0,3),row)*cell+Vector2.ONE*2,cell-Vector2.ONE*4)
static func draw_ground(canvas: CanvasItem,id: String,frame: int,radius: float,tint: Color,broken: Array=[],rim_only: bool=false) -> void:
 var source=ground_region(id,frame);var cell=source.size+Vector2.ONE*4;var profile=GROUND_PROFILES[id]
 var anchor=cell*Vector2(profile.x,profile.y)-Vector2.ONE*2
 var scale_x=radius/(cell.x*profile.z);var rim_y=cell.y*profile.w
 var cuts=[0.,maxf(0.,anchor.y-rim_y),minf(source.size.y,anchor.y+rim_y),source.size.y]
 # Expand the ground rim to the collision circle while keeping pillar height proportional.
 for band in range(3):
  var top=float(cuts[band]);var bottom=float(cuts[band+1])
  if bottom<=top:continue
  # Rift3D: the pillar band (above the rim) stands up as a ZoneProp3D card; the rim and the art in front of it
  # (band 2, e.g. the front of a ring or the feet of front posts) stay flat so the footprint is not cut off.
  if rim_only and band==0:continue
  var y_scale=radius/rim_y if band==1 else scale_x
  var y_start=-radius+(top-(anchor.y-rim_y))*scale_x if band==0 else (top-anchor.y)*y_scale if band==1 else radius+(top-(anchor.y+rim_y))*scale_x
  var rect=Rect2(-anchor.x*scale_x,y_start,source.size.x*scale_x,(bottom-top)*y_scale)
  var region=Rect2(source.position+Vector2(0,top),Vector2(source.size.x,bottom-top))
  if rim_only and band==1:
   _draw_rim_faded(canvas,id,rect,region,tint,broken)
   continue
  if broken.is_empty() or not broken.has(true):canvas.draw_texture_rect_region(sheet(id),rect,region,tint)
  else:
   var corners=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
   for wall in range(5):
    if broken[wall]:continue
    var extent=rect.size.length()*4.
    var wedge=PackedVector2Array([Vector2.ZERO,Vector2.from_angle(-PI/2+wall*TAU/5)*extent,Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*extent])
    for points in Geometry2D.intersect_polygons(wedge,corners):
     var uv=PackedVector2Array()
     for point in points:uv.append((region.position+(point-rect.position)/rect.size*region.size)/sheet(id).get_size())
     canvas.draw_colored_polygon(points,tint,uv,sheet(id))
# Rift3D flat rim (rim_only): the rim's back half still holds the base of the standing column, which the
# ZoneProp3D pillar card shows upright. Fade that half in from the back edge so the flat copy meets the card
# without a hard seam; the front half stays solid. Broken-wall wedges are cut exactly as in the full draw.
static func _draw_rim_faded(canvas: CanvasItem,id: String,rect: Rect2,region: Rect2,tint: Color,broken: Array) -> void:
 var tex=sheet(id);var half=rect.size.y*.5
 var halves=[Rect2(rect.position,Vector2(rect.size.x,half)),Rect2(rect.position+Vector2(0,half),Vector2(rect.size.x,rect.size.y-half))]
 for part in halves:
  var corners=PackedVector2Array([part.position,part.position+Vector2(part.size.x,0),part.end,part.position+Vector2(0,part.size.y)])
  var pieces=[corners]
  if not broken.is_empty() and broken.has(true):
   pieces=[]
   for wall in range(5):
    if broken[wall]:continue
    var extent=rect.size.length()*4.
    var wedge=PackedVector2Array([Vector2.ZERO,Vector2.from_angle(-PI/2+wall*TAU/5)*extent,Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*extent])
    pieces.append_array(Geometry2D.intersect_polygons(wedge,corners))
  for points in pieces:
   if points.size()<3:continue
   var uv=PackedVector2Array();var colors=PackedColorArray()
   for point in points:
    uv.append((region.position+(point-rect.position)/rect.size*region.size)/tex.get_size())
    colors.append(Color(tint,tint.a*clampf((point.y-rect.position.y)/maxf(.001,half),0.,1.)))
   canvas.draw_polygon(points,colors,uv,tex)
# Rift3D pillar card: the standing column of a GROUND_PROFILE sprite, from the cell top down to the rim centre
# (band 0 of draw_ground plus the back half of the rim, where the column meets the ground). Art px around the AoE centre.
# Returns {region: Rect2 (atlas px), size: Vector2 (art px), offset_x: float (art px, card centre from the AoE x),
# rim_fraction: float (share of the card height below the rim's back edge, faded out by ZoneProp3D)}.
static func pillar_band(id: String,frame: int,radius: float) -> Dictionary:
 var source=ground_region(id,frame);var cell=source.size+Vector2.ONE*4;var profile=GROUND_PROFILES[id]
 var anchor=cell*Vector2(profile.x,profile.y)-Vector2.ONE*2
 var scale_x=radius/(cell.x*profile.z);var rim_y=cell.y*profile.w
 var bottom=clampf(anchor.y,0.,source.size.y);var rim_top=clampf(anchor.y-rim_y,0.,bottom)
 var size=Vector2(source.size.x*scale_x,bottom*scale_x)
 return {"region":Rect2(source.position,Vector2(source.size.x,bottom)),"size":size,"offset_x":-anchor.x*scale_x+size.x*.5,"rim_fraction":(bottom-rim_top)/maxf(1.,bottom)}
