class_name ActionSpriteArt
extends RefCounted
# Per-cell metadata comes from the real generated atlases, never from a placeholder.
static var manifest: Dictionary = {}
static var textures: Dictionary = {}
const CACHE_BUDGET_BYTES = 128 * 1024 * 1024
static var pinned_paths: Dictionary = {}
static var texture_costs: Dictionary = {}
static var last_used: Dictionary = {}
static var access_serial: int = 0
static var cached_bytes: int = 0
static func entry(key: String) -> Dictionary:
 if manifest.is_empty():
  manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/manifest.json"))
 return manifest[key]
static func texture(key: String, override_path: String = "") -> Texture2D:
 var path = override_path if override_path!="" else str(entry(key).path)
 access_serial += 1;last_used[path] = access_serial
 if textures.has(path):return textures[path]
 var result: Texture2D = load(path)
 textures[path] = result
 var cost = int(result.get_width()*result.get_height()*4*4./3.)
 texture_costs[path] = cost;cached_bytes += cost
 trim_cache()
 return result
static func begin_match(hero_keys: Array) -> void:
 pinned_paths.clear()
 if manifest.is_empty():entry("minion_melee")
 for key in manifest:
  if not key.begins_with("minion_") and key.trim_prefix("hero_") not in hero_keys:continue
  var data=manifest[key];pinned_paths[str(data.path)]=true
  for cell in data.frames:pinned_paths[str(cell.get("path",data.path))]=true
 trim_cache()
static func trim_cache() -> void:
 if cached_bytes<=CACHE_BUDGET_BYTES:return
 var unused=textures.keys().filter(func(path):return not pinned_paths.has(path))
 unused.sort_custom(func(a,b):return int(last_used.get(a,0))<int(last_used.get(b,0)))
 for path in unused:
  if cached_bytes<=CACHE_BUDGET_BYTES:break
  cached_bytes-=int(texture_costs[path]);textures.erase(path);texture_costs.erase(path);last_used.erase(path)
static func texture_for_frame(key: String, action: String, index: int) -> Texture2D:
 return texture(key,str(frame(key,action,index).get("path","")))
static func frame(key: String, action: String, index: int) -> Dictionary:
 var data = entry(key)
 var row = int(data.actions.get(action,0))
 return data.frames[row*6+clampi(index,0,5)]
static func region(key: String, action: String, index: int) -> Rect2:
 var cell = frame(key,action,index).region
 return Rect2(cell[0],cell[1],cell[2],cell[3])
static func rect(key: String, action: String, index: int, height: float) -> Rect2:
 var data = entry(key)
 var cell = frame(key,action,index)
 var scale = height/float(data.body_height)*float(cell.get("relative_scale",1.0))
 return Rect2(-Vector2(cell.pivot[0],cell.pivot[1])*scale,Vector2(cell.region[2],cell.region[3])*scale)
static func body_rect(key: String, height: float, flip: bool = false) -> Rect2:
 var data = entry(key)
 var cell = frame(key,"idle",0)
 var scale = height/float(data.body_height)
 var body = cell.body
 var result = Rect2(Vector2(body[0]-cell.pivot[0],body[1]-cell.pivot[1])*scale,Vector2(body[2],body[3])*scale)
 if flip: result.position.x = -result.end.x
 return result

static func apply_frame_mask(material: ShaderMaterial, key: String, action: String, index: int) -> void:
 var stamp=key+":"+action+":"+str(index)
 if material.get_meta("action_frame_mask","")==stamp:return
 material.set_meta("action_frame_mask",stamp)
 var cell=frame(key,action,index)
 var texture=texture_for_frame(key,action,index)
 var dimensions=Vector2(texture.get_width(),texture.get_height())
 var values=PackedVector4Array()
 for bounds in cell.get("exclusions",[]):
  values.append(Vector4(bounds[0]/dimensions.x,bounds[1]/dimensions.y,bounds[2]/dimensions.x,bounds[3]/dimensions.y))
 material.set_shader_parameter("atlas_pixel_size",Vector2.ONE/dimensions)
 material.set_shader_parameter("exclusion_count",values.size())
 values.resize(8)
 material.set_shader_parameter("excluded_rects",values)
