extends RefCounted
const ROWS = {"melee":0,"caster":1,"siege":2,"super":3,"tibbers":4}
static var sheet: Texture2D
static func texture() -> Texture2D:
 if sheet == null: sheet = load("res://assets/minions/minion-roster-v2.png")
 return sheet
static func frame(kind: String, column: int) -> Rect2:
 var atlas = texture()
 var cell = Vector2(atlas.get_width()/4.0,atlas.get_height()/5.0)
 return Rect2(Vector2(clampi(column,0,3),ROWS.get(kind,0))*cell,cell)
