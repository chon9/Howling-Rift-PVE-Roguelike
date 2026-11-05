class_name CombatFeedbackArt
extends RefCounted
static var hits: Texture2D
static var crests: Dictionary={}
static var title_font: SystemFont
const CREST_KEYS=["knockout","double","triple","maniac","savage","spree"]
static func impact_texture() -> Texture2D:
 if hits==null:hits=load("res://assets/vfx/combat-impact-v1.png")
 return hits
static func banner_texture(row: int=0) -> Texture2D:
 var key=CREST_KEYS[clampi(row,0,5)]
 if not crests.has(key):crests[key]=load("res://assets/vfx/crests-v2/"+key+".png")
 return crests[key]
static func font() -> Font:
 if title_font==null:
  title_font=SystemFont.new()
  title_font.font_names=PackedStringArray(["Georgia","Constantia","Times New Roman"])
  title_font.font_weight=700
 return title_font
static func frame(texture: Texture2D,row: int,index: int,rows: int) -> Rect2:
 var cell=texture.get_size()/Vector2(4,rows)
 # Keep filtering within the selected cell, including non-integer atlas dimensions.
 return Rect2(Vector2(clampi(index,0,3),row)*cell+Vector2.ONE*2.,cell-Vector2.ONE*4.)
