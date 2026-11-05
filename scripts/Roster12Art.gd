class_name Roster12Art
extends RefCounted
static var textures: Dictionary={}
static var crops: Dictionary={}
static var icon_crops: Dictionary={}
static var skill_bounds: Dictionary={}
static func texture(path: String) -> Texture2D:
 if not textures.has(path):textures[path]=load(path)
 return textures[path]
static func icon(key: String,row: int) -> Texture2D:
 var i=RosterExpansion12.KEYS.find(key);var atlas=texture("res://assets/ui/roster12-icons-%d-v1.png" % (i/4))
 if icon_crops.is_empty():icon_crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/roster12-icon-crops.json"))
 var crop=icon_crops[str(i/4)][row*4+i%4]
 var result=AtlasTexture.new();result.atlas=atlas;result.region=Rect2(crop[0],crop[1],crop[2],crop[3]);result.filter_clip=true;return result
static func sheet(id: String) -> Texture2D:
 return texture("res://assets/vfx/"+id.get_slice("_",0)+"-skills-v1.png")
static func region(id: String,frame: int) -> Rect2:
 if crops.is_empty():crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/roster12-crops.json"))
 var hero=id.get_slice("_",0);var row=["q","w","e","r"].find(id.get_slice("_",1));row=maxi(0,row)
 # Use one row crop across all four frames so the same footprint never changes scale.
 var cell=sheet(id).get_size()/Vector2(4,4)
 var key=hero+str(row)
 if not skill_bounds.has(key):
  var merged=Rect2()
  for column in range(4):
   var values=crops[hero][row*4+column]
   var local=Rect2(Vector2(values[0],values[1])-Vector2(column,row)*cell,Vector2(values[2],values[3]))
   merged=local if column==0 else merged.merge(local)
  skill_bounds[key]=merged
 var crop: Rect2=skill_bounds[key]
 return Rect2(Vector2(clampi(frame,0,3),row)*cell+crop.position,crop.size)


static func trim_skill_sheets(hero_keys: Array) -> void:
 for path in textures.keys():
  if path.begins_with("res://assets/vfx/") and path.get_file().trim_suffix("-skills-v1.png") not in hero_keys:textures.erase(path)
