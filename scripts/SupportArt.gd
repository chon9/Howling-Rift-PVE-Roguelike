class_name SupportArt
extends RefCounted
static var icons: Texture2D
static var effects: Texture2D
const ROWS={"soraka_auto":1,"janna_auto":5,"soraka_q":0,"soraka_w":1,"soraka_e":2,"soraka_r":3,"janna_q":4,"janna_w":5,"janna_e":6,"janna_r":7}
static func icon(key: String,row: int) -> Texture2D:
 if icons==null:icons=load("res://assets/ui/support-icons-v1.png")
 # Measured borders of the generated atlas: omit the outer gold frame in portraits.
 var xs=[34.,414.];var ys=[41.,416.,783.,1152.,1526.]
 var result=AtlasTexture.new();result.atlas=icons
 result.region=Rect2(xs[SupportRoster.KEYS.find(key)]+8.,ys[clampi(row,0,4)]+8.,328.,328.);result.filter_clip=true
 return result
static func sheet() -> Texture2D:
 if effects==null:effects=load("res://assets/vfx/support-skills-v1.png")
 return effects
static func region(id: String,frame: int) -> Rect2:
 var tex=sheet();var row=ROWS.get(id,0)
 var cuts=[0.,250.,502.,715.,922.,1140.,1340.,1550.,1774.]
 var width=tex.get_width()/4.;var scale=tex.get_height()/1774.
 return Rect2(clampi(frame,0,3)*width+3.,cuts[row]*scale+3.,width-6.,(cuts[row+1]-cuts[row])*scale-6.)
