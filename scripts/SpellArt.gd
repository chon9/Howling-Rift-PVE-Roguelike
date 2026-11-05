extends RefCounted
class_name SpellArt

static var missiles: Texture2D = preload("res://assets/vfx/projectiles.png")
static var impacts: Texture2D = preload("res://assets/vfx/impacts.png")
static var expansion_missiles: Texture2D
static func missile_sheet(expansion: bool = false) -> Texture2D:
	if not expansion: return missiles
	if expansion_missiles == null: expansion_missiles = load("res://assets/vfx/expansion-projectiles-v1.png")
	return expansion_missiles
const ROWS = {"soraka":3,"janna":0,"ashe":0, "annie":1, "garen":2, "lux":3, "ahri":4, "ezreal":5, "yasuo":0, "leesin":2, "zed":4, "jinx":5, "katarina":1, "kayle":3,"darius":2,"malphite":5,"veigar":4,"morgana":4,"vayne":0,"thresh":3}

static func row_for(source) -> int:
	return ROWS.get(source.hero_key, 5) if is_instance_valid(source) and source.kind == "champion" else -1

static func frame(sheet: Texture2D, row: int, column: int) -> Rect2:
	var cell = Vector2(sheet.get_width() / 8.0, sheet.get_height() / 6.0)
	return Rect2(Vector2(clampi(column, 0, 7), clampi(row, 0, 5)) * cell, cell)

static var missile_bounds: Dictionary = {}
static func missile_frame(sheet: Texture2D, row: int, column: int) -> Rect2:
	if missile_bounds.is_empty():
		missile_bounds=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/missile-crops-v1.json"))
	var key="expansion" if sheet==expansion_missiles else "legacy"
	var bounds=missile_bounds[key][clampi(row,0,5)]
	var base=frame(sheet,row,column)
	return Rect2(base.position+Vector2(bounds[0],bounds[1]),Vector2(bounds[2],bounds[3]))
