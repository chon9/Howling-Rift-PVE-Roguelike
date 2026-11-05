class_name GearArt
extends RefCounted
# Dedicated permanent equipment atlas, with measured crops for all nineteen objects.
const PATH="res://assets/ui/permanent-equipment-v1.png"
const KEYS=["iron_helm","seer_hood","rift_breastplate","astral_robe","frost_sword","starwood_staff","siege_maul","sentinel_shield","moon_orb","parrying_dagger","wayfarer_boots","sentinel_treads","ruby_ring","spellstone_ring","war_ring","dawn_necklace","arcane_necklace","duelist_gloves","bulwark_gauntlets"]
const SOURCE_SIZE=Vector2(1122,1402)
# Opaque bounds measured from the generated PNG; padded square crops preserve full objects.
const BOUNDS=[Rect2(83,76,140,192),Rect2(336,81,166,187),Rect2(603,82,192,186),Rect2(891,77,163,194),Rect2(64,342,176,190),Rect2(331,345,180,189),Rect2(603,355,195,176),Rect2(902,341,143,195),Rect2(57,596,188,198),Rect2(334,609,166,180),Rect2(612,612,187,182),Rect2(897,609,171,188),Rect2(69,873,163,166),Rect2(348,874,160,161),Rect2(615,876,173,158),Rect2(893,854,164,207),Rect2(67,1114,162,199),Rect2(340,1128,177,190),Rect2(605,1124,209,189)]
static var atlas: Texture2D
static var icons: Dictionary={}
static func sheet() -> Texture2D:
 if atlas==null:atlas=load(PATH)
 return atlas
static func region(id: String) -> Rect2:
 var index=KEYS.find(id)
 if index<0:return Rect2()
 var bounds: Rect2=BOUNDS[index]
 var side=maxf(bounds.size.x,bounds.size.y)+24.
 var rect=Rect2(bounds.get_center()-Vector2.ONE*side*.5,Vector2.ONE*side)
 var scale=sheet().get_size()/SOURCE_SIZE
 return Rect2(rect.position*scale,rect.size*scale)
static func icon_for(id: String) -> Texture2D:
 if not KEYS.has(id):return null
 if not icons.has(id):
  var icon=AtlasTexture.new();icon.atlas=sheet();icon.region=region(id);icon.filter_clip=true
  icons[id]=icon
 return icons[id]
