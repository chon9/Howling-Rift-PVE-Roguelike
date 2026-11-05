class_name HeroArt
extends RefCounted
const EXTENDED = preload("res://assets/champions/extended-roster.png")
const KEYS = ["yasuo","leesin","zed","jinx","katarina","kayle"]
static func raw_texture_for(key: String) -> Texture2D:
 if key in SupportRoster.KEYS:return SupportArt.icon(key,0)
 if key in RosterExpansion12.KEYS:return Roster12Art.icon(key,0)
 if ExpansionRoster.KEYS.has(key): return expansion_icon(key,0)
 var index = KEYS.find(key)
 if index < 0: return load("res://assets/champions/%s-painted.png" % key)
 var result = AtlasTexture.new()
 result.atlas = EXTENDED
 var cell = Vector2(EXTENDED.get_width()/3.0,EXTENDED.get_height()/2.0)
 result.region = Rect2(Vector2(index%3,index/3)*cell,cell)
 result.filter_clip = true
 return result
static func expansion_icon(key: String,row: int) -> Texture2D:
 var atlas=load("res://assets/ui/expansion-hero-icons-v1.png")
 var result=AtlasTexture.new();result.atlas=atlas
 var cell=Vector2(atlas.get_width()/6.,atlas.get_height()/5.)
 result.region=Rect2(Vector2(ExpansionRoster.KEYS.find(key),row)*cell+Vector2(3,3),cell-Vector2(6,6));result.filter_clip=true
 return result

# Inspected head-and-shoulder crops, normalized to each original atlas cell.
const PORTRAIT_CROPS={
 "lux":[.29,.006,.5],"ahri":[.46,.015,.52],"ezreal":[.22,.02,.5],"ashe":[.25,.018,.52],"annie":[.28,.002,.6],"garen":[.3,.02,.54],
 "yasuo":[.3,.005,.5],"leesin":[.2,.005,.5],"zed":[.22,.015,.56],"jinx":[.44,.02,.5],"katarina":[.3,.015,.5],"kayle":[.23,.025,.55]}
static func texture_for(key: String) -> Texture2D:
 var raw=raw_texture_for(key);var side=minf(raw.get_width(),raw.get_height())
 var region: Rect2
 if PORTRAIT_CROPS.has(key):
  var crop=PORTRAIT_CROPS[key];var edge=raw.get_width()*crop[2];region=Rect2(raw.get_width()*crop[0],raw.get_height()*crop[1],edge,edge)
 else:
  var margin=side*.07;var top=(raw.get_height()-side)*.5;region=Rect2((raw.get_width()-side)*.5+margin,top+margin,side-2*margin,side-2*margin)
 var result=AtlasTexture.new();result.atlas=raw;result.region=region;result.filter_clip=true;return result
