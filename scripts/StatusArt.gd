class_name StatusArt
extends RefCounted
# One shared atlas per family; presentation reads gameplay state, never changes it.
const TYPES={
 "silence":["control",0,"bc97ff",0],"stun":["control",1,"ffcf70",0],
 "airborne":["control",2,"90eaff",0],"root":["control",3,"77e8bd",0],
 "slow":["control",4,"85cfff",1],"burn":["control",5,"ff965c",1],
 "shield":["boons",0,"8ddfff",2],"heal":["boons",1,"94efaa",2],
 "haste":["boons",2,"78e6dc",2],"empower":["boons",3,"ffcf75",2],
 "guard":["boons",4,"fff0ac",2],"mark":["boons",5,"f69dcf",1],
 "bleed":["debuffs",0,"ed7587",1],"grievous":["debuffs",1,"ec9093",1],
 "shred":["debuffs",2,"e7b684",1],"cripple":["debuffs",3,"bf9dda",1]}
const PATHS={"control":"res://assets/vfx/status-control-v2.png","boons":"res://assets/vfx/status-boons-v2.png","debuffs":"res://assets/vfx/status-debuffs-v2.png"}
const GROUPS={
 "silence":["silence"],"root":["root","snare","held_sphere"],"slow":["slow","frost"],
 "burn":["ignite","item_burn","blaze","blaze_detonate"],
 "bleed":["hemorrhage_"],"grievous":["grievous"],"shred":["armor_shred"],"cripple":["cripple"],
 "mark":["flux_mark","sonic_mark","chain_mark","death_mark","radiant_mark","rifle_mark","illumination","sunlight","static_mark","grand_challenge","vital_","soul_chains"],
 "heal":["support_heal","rejuvenation","rejuvenation_shared","monsoon"],
 "haste":["flowing","haste","ghost","excited","fleet_foot","overdrive","roster_as","spell_force","flurry","ascent","focus"],
 "empower":["ardent","gale_charge","decisive","empowered","spellblade","righteous","runes","roster_attack","bladework","noxian_might","hunt","vigilance","lightslinger","ricochet","exile","rockets","silver","tempest","sphere_barrage","wind_thunder","broken_arc","dice","force_of_will","shadow","spin","artillery","arcanopulse","culling","challenge"],
 "guard":["courage","cc_guard","divine","parry","spell_guard","spell_ward","crescent_guard","nature_guard","eclipse","molten","iron_will","dominion","wind_wall"]}
const LABELS={"silence":"SILENCED","held_sphere":"HELD","broken_arc":"Q RECAST","dice":"E RECAST","force_of_will":"W THROW READY","shadow":"SHADOW ACTIVE","spin":"SPINNING","artillery":"ARTILLERY","arcanopulse":"CHARGING Q","culling":"CHANNELING","challenge":"CHALLENGE","root":"ROOTED","snare":"ROOTED","slow":"SLOWED","ignite":"IGNITE","item_burn":"BURNING","blaze":"BLAZE","blaze_detonate":"DETONATING","grievous":"HEALING REDUCED","armor_shred":"ARMOR SHRED","cripple":"ATTACK SPEED REDUCED","decisive":"SILENCING STRIKE READY","empowered":"EMPOWERED ATTACK","roster_attack":"EMPOWERED ATTACK","sonic_mark":"SONIC MARK","chain_mark":"HOOK MARK","death_mark":"DEATH MARK","cc_guard":"CC IMMUNE","divine":"INVULNERABLE","spell_guard":"SPELL BLOCK","spell_ward":"SPELL WARD","crescent_guard":"CRESCENT GUARD","courage":"DAMAGE REDUCTION","parry":"PARRY","soul_chains":"SOUL CHAINS","ascent":"ASCENT","focus":"ATTACK FLURRY","spell_force":"ATTACK SPEED","roster_as":"ATTACK SPEED","overdrive":"OVERDRIVE","righteous":"RIGHTEOUS ATTACKS"}
static var textures={}
static var icons={}
static var categories={}
static func texture(id: String) -> Texture2D:
 var family=TYPES[id][0]
 if not textures.has(family):textures[family]=load(PATHS[family])
 return textures[family]
static func frame_rect(id: String,phase: float) -> Rect2:
 var tex=texture(id);var rows=4 if TYPES[id][0]=="debuffs" else 6
 var cell=Vector2(tex.get_width()/4.,tex.get_height()/float(rows))
 var inset=Vector2.ONE*(12. if TYPES[id][0]=="debuffs" else 8.)
 return Rect2(Vector2(int(phase*8.)%4,int(TYPES[id][1]))*cell+inset,cell-inset*2.)
static func icon(id: String,phase: float=0.) -> AtlasTexture:
 var key=id+str(int(phase*8.)%4)
 if not icons.has(key):
  var result=AtlasTexture.new();result.atlas=texture(id);result.region=frame_rect(id,phase);result.filter_clip=true;icons[key]=result
 return icons[key]
static func color(id: String) -> Color:return Color(TYPES[id][2])
static func category(key: String) -> String:
 if categories.is_empty():
  for id in GROUPS:
   for candidate in GROUPS[id]:categories[candidate]=id
 if categories.has(key):return categories[key]
 if key.begins_with("hemorrhage_"):return "bleed"
 if key.begins_with("vital_"):return "mark"
 return "shield" if key.ends_with("_shield") or key in ["lifeline","mana_barrier","valor"] else ""
static func collect(unit) -> Array:
 var result=[]
 if not is_instance_valid(unit) or unit.dead:return result
 if unit.stun>0:
  var air=unit.buffs.has("airborne")
  result.append({"id":"airborne" if air else "stun","label":"AIRBORNE" if air else "STUNNED","time":float(unit.stun),"stacks":0,"detail":"Movement and attacks disabled."})
 for key in unit.buffs:
  var b=unit.buffs[key];var time=float(b.get("time",0.))
  if time<=0:continue
  var id=category(key)
  if id=="" or id=="shield":continue # Shields reflect actual remaining absorption below.
  if key=="tempest" and int(b.get("stacks",0))<2:continue
  if key=="decisive" and b.get("used",false):continue
  var label=str(LABELS.get(key,key.replace("_"," ").to_upper()))
  if key.begins_with("hemorrhage_"):label="BLEEDING"
  if key.begins_with("vital_"):label="EXPOSED VITAL"
  var detail=""
  if key=="silence":detail="Skills disabled. Movement and basic attacks still work."
  elif b.has("pct"):detail="%.0f%% reduction" % (float(b.pct)*100.)
  elif b.has("mult"):detail="%.0f%% speed bonus" % ((float(b.mult)-1.)*100.)
  elif b.has("dr"):detail="%.0f%% damage reduction" % (float(b.dr)*100.)
  var stacks=int(b.get("stacks",b.get("hits",0)))
  result.append({"id":id,"label":label,"time":time,"stacks":stacks,"detail":detail})
 if unit.kind=="champion" and unit.shield>0:result.append({"id":"shield","label":"SHIELDED","time":0.,"stacks":0,"detail":"Absorbs %.0f damage." % unit.shield})
 result.sort_custom(func(a,b):return int(TYPES[a.id][3])<int(TYPES[b.id][3]))
 return result
static func tooltip(status: Dictionary) -> String:
 return status.label+(" · %.1fs" % status.time if status.time>0 else "")+(" · %d stacks / attacks" % status.stacks if status.stacks>0 else "")+("\n"+status.detail if status.detail!="" else "")
