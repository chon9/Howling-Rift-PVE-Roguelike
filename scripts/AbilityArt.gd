extends RefCounted
class_name AbilityArt

static var atlas: Texture2D = preload("res://assets/ui/ability-icons.png")
const ROWS = {"ashe":0, "annie":1, "garen":2, "lux":3, "ahri":4, "ezreal":5}
# Measured row dividers of the generated 1024 x 1536 atlas.
const ROW_EDGES = [0, 249, 495, 743, 988, 1234, 1536]
static var cache: Dictionary = {}
static var extended: Texture2D = preload("res://assets/ui/extended-ability-icons.png")

static func icon_for(hero_key: String, index: int) -> Texture2D:
	if hero_key in SupportRoster.KEYS:return SupportArt.icon(hero_key,index+1)
	if hero_key in RosterExpansion12.KEYS:return Roster12Art.icon(hero_key,index+1)
	if ExpansionRoster.KEYS.has(hero_key): return HeroArt.expansion_icon(hero_key,index+1)
	if HeroArt.KEYS.has(hero_key) and index >= 0 and index < 4:
		var texture = AtlasTexture.new()
		texture.atlas = extended
		var cell = Vector2(extended.get_width()/4.0,extended.get_height()/6.0)
		texture.region = Rect2(Vector2(index,HeroArt.KEYS.find(hero_key))*cell+Vector2(2,2),cell-Vector2(4,4))
		texture.filter_clip = true
		return texture
	if not ROWS.has(hero_key) or index < 0 or index >= 4: return null
	var key = hero_key + str(index)
	if not cache.has(key):
		var row: int = ROWS[hero_key]
		var height: float = ROW_EDGES[row + 1] - ROW_EDGES[row]
		var side = minf(256, height) - 4
		var texture = AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(index * 256 + (256 - side) * 0.5, ROW_EDGES[row] + (height - side) * 0.5, side, side)
		texture.filter_clip = true
		cache[key] = texture
	return cache[key]
