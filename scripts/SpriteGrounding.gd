extends RefCounted
static var anchors: Dictionary = {}
static func foot(key: String) -> Vector2:
 if anchors.is_empty():
  anchors = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ground-anchors.json"))
 var point = anchors.get(key,[0.5,1.0])
 return Vector2(point[0],point[1])
static func rect(key: String, dimensions: Vector2) -> Rect2:
 return Rect2(-foot(key)*dimensions,dimensions)
