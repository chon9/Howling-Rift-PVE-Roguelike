class_name ShopArt
extends RefCounted
const ATLAS = preload("res://assets/ui/item-summoner-icons.png")
static func icon_for(index: int) -> AtlasTexture:
 var texture = AtlasTexture.new()
 texture.atlas = ATLAS
 var cell = Vector2(ATLAS.get_width()/6.0, ATLAS.get_height()/5.0)
 texture.region = Rect2(Vector2(index%6, index/6)*cell + Vector2(3,3), cell-Vector2(6,6))
 return texture
static func item_icon(id: String):
 if id in SupportItems.KEYS:
  var texture=AtlasTexture.new();texture.atlas=load("res://assets/ui/support-item-icons-v1.png")
  var cell=texture.atlas.get_size()/Vector2(4,2);var index=SupportItems.KEYS.find(id)
  texture.region=Rect2(Vector2(index%4,index/4)*cell+Vector2.ONE*12,cell-Vector2.ONE*24);texture.filter_clip=true;return texture
 if MatchTraining.KEYS.has(id): return item_icon(MatchTraining.icon_source(id))
 if TankADItems.KEYS.has(id):
  var texture=AtlasTexture.new();texture.atlas=load("res://assets/ui/tank-ad-item-icons-v1.png")
  var cell=Vector2(texture.atlas.get_width()/6.,texture.atlas.get_height()/4.)
  var index=TankADItems.KEYS.find(id)
  texture.region=Rect2(Vector2(index%6,index/6)*cell+Vector2(3,3),cell-Vector2(6,6));texture.filter_clip=true
  return texture
 if ExpansionItems.KEYS.has(id):
  var texture=AtlasTexture.new();texture.atlas=load("res://assets/ui/expansion-item-icons-v1.png")
  var cell=Vector2(texture.atlas.get_width()/5.,texture.atlas.get_height()/4.)
  var index=ExpansionItems.KEYS.find(id)
  texture.region=Rect2(Vector2(index%5,index/5)*cell+Vector2(3,3),cell-Vector2(6,6));texture.filter_clip=true
  return texture
 var index = ItemData.ORDER.find(id)
 return icon_for(index) if index >= 0 else null
