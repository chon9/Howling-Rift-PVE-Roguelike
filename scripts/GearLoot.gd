class_name GearLoot
extends RefCounted

const SLOTS={"head":"Head","body":"Body armor","weapon":"Weapon","sub_weapon":"Sub weapon","shoes":"Shoes","ring_1":"Ring I","ring_2":"Ring II","necklace":"Necklace","gloves":"Gloves"}
const RARITIES=["Common","Magic","Rare","Epic","Legendary"]
const COLORS=[Color("bec6cc"),Color("78baff"),Color("e9cd6f"),Color("b591f3"),Color("ffad58")]
const BASES={
 "head":[["Iron Helm","iron_helm",{"bonus_hp":70.,"bonus_armor":4.}],["Seer's Hood","seer_hood",{"bonus_ap":10.,"bonus_mp":40.}]],
 "body":[["Rift Breastplate","rift_breastplate",{"bonus_hp":130.,"bonus_armor":5.}],["Astral Robe","astral_robe",{"bonus_hp":60.,"bonus_mr":6.}]],
 "weapon":[["Frost Sword","frost_sword",{"bonus_ad":12.}],["Starwood Staff","starwood_staff",{"bonus_ap":18.}],["Siege Maul","siege_maul",{"bonus_ad":7.,"bonus_hp":70.}]],
 "sub_weapon":[["Sentinel Shield","sentinel_shield",{"bonus_armor":5.,"bonus_hp":70.}],["Moon Orb","moon_orb",{"bonus_ap":10.,"bonus_mp":60.}],["Parrying Dagger","parrying_dagger",{"bonus_ad":4.,"bonus_as":.025}]],
 "shoes":[["Wayfarer Boots","wayfarer_boots",{"bonus_ms":.008,"bonus_hp":40.}],["Sentinel Treads","sentinel_treads",{"bonus_ms":.006,"bonus_mr":3.}]],
 "ring":[["Ruby Ring","ruby_ring",{"bonus_hp":70.}],["Spellstone Ring","spellstone_ring",{"bonus_ap":7.,"bonus_mp":40.}],["War Ring","war_ring",{"bonus_ad":5.}]],
 "necklace":[["Dawn Necklace","dawn_necklace",{"bonus_mr":4.,"bonus_hp_regen":.35}],["Arcane Necklace","arcane_necklace",{"bonus_ap":8.,"bonus_mp":60.}]],
 "gloves":[["Duelist Gloves","duelist_gloves",{"bonus_as":.035,"bonus_ad":3.}],["Bulwark Gauntlets","bulwark_gauntlets",{"bonus_hp":60.,"bonus_armor":3.}]]
}
# Legacy shop references map within their actual equipment category only.
const LEGACY_ICONS={"chain_vest":"iron_helm","rabadon":"seer_hood","sunfire":"rift_breastplate","banshee":"astral_robe","bf_sword":"frost_sword","needlessly_rod":"starwood_staff","black_cleaver":"siege_maul","cloth_armor":"sentinel_shield","amp_tome":"moon_orb","dagger":"parrying_dagger","boots":"wayfarer_boots","mercury_treads":"sentinel_treads","ruby_crystal":"ruby_ring","sapphire_crystal":"spellstone_ring","long_sword":"war_ring","spirit_visage":"dawn_necklace","archangel":"arcane_necklace","cloak":"duelist_gloves","sterak":"bulwark_gauntlets"}
const LEGACY_NAMES={"iron_helm":"Iron Crown","rift_breastplate":"Rift Plate","frost_sword":"Frostblade","ruby_ring":"Ruby Band","war_ring":"War Band","dawn_necklace":"Dawn Pendant","arcane_necklace":"Arcane Pendant","duelist_gloves":"Duelist Grips"}
# Flat stats grow with item level. Percentage affixes grow more slowly.
const AFFIXES={
 "bonus_ad":["Savage",3.,7.,false],"bonus_ap":["Arcane",4.,10.,false],"bonus_hp":["Vital",35.,85.,false],
 "bonus_mp":["Insightful",25.,65.,false],"bonus_armor":["Ironbound",2.,6.,false],"bonus_mr":["Warding",2.,6.,false],
 "bonus_hp_regen":["Renewing",.15,.45,false],"bonus_as":["Frenzied",.012,.027,true],"bonus_ms":["Fleet",.002,.005,true],
 "bonus_cdr":["Quickened",.006,.014,true],"bonus_crit":["Precise",.008,.018,true],"bonus_lifesteal":["Vampiric",.006,.014,true]
}
const STAT_NAMES={"bonus_ad":"Attack damage","bonus_ap":"Ability power","bonus_hp":"Health","bonus_mp":"Mana","bonus_armor":"Armor","bonus_mr":"Magic resist","bonus_hp_regen":"Health / sec","bonus_as":"Attack speed","bonus_ms":"Move speed","bonus_cdr":"Cooldown reduction","bonus_crit":"Critical chance","bonus_lifesteal":"Lifesteal"}
const CAPS={"bonus_as":.75,"bonus_ms":.12,"bonus_cdr":.20,"bonus_crit":.35,"bonus_lifesteal":.20}

static func kind(slot: String) -> String:
 return "ring" if slot in ["ring_1","ring_2"] else slot
static func compatible(item: Dictionary,slot: String) -> bool:
 return SLOTS.has(slot) and item.get("slot","")==kind(slot)
static func rarity_odds(stage: int) -> Array:
 var n=(clampi(stage,1,99)-1)/98.
 return [lerpf(.35,.05,n),lerpf(.40,.20,n),lerpf(.19,.35,n),lerpf(.05,.25,n),lerpf(.01,.15,n)]
static func roll(stage: int,rng: RandomNumberGenerator,id: String) -> Dictionary:
 var level=clampi(stage-rng.randi_range(0,mini(2,stage-1)),1,99)
 var chance=rng.randf();var rarity=0;var cumulative=0.
 var odds=rarity_odds(stage)
 for index in range(5):
  cumulative+=odds[index]
  if chance<cumulative:rarity=index;break
 var types=BASES.keys();var slot: String=types[rng.randi_range(0,types.size()-1)]
 var pool=BASES[slot];var base=pool[rng.randi_range(0,pool.size()-1)]
 var stats={};var power=(1.+(level-1)*.035)*(1.+rarity*.12)
 for stat in base[2]:
  var percentage=AFFIXES[stat][3]
  stats[stat]=snappedf(base[2][stat]*(1.+(level-1)*.008 if percentage else power)*rng.randf_range(.9,1.1),.0001 if percentage else .1)
 var keys=AFFIXES.keys();var affixes=[]
 for index in range(rarity+1):
  var pick=rng.randi_range(0,keys.size()-1);var stat: String=keys[pick];keys.remove_at(pick)
  var spec=AFFIXES[stat];var value=snappedf(rng.randf_range(spec[1],spec[2])*(1.+(level-1)*(.008 if spec[3] else .04)),.0001 if spec[3] else .1)
  affixes.append({"name":spec[0],"stat":stat,"value":value})
  stats[stat]=stats.get(stat,0.)+value
 return {"id":id,"name":affixes[0].name+" "+base[0],"slot":slot,"level":level,"rarity":rarity,"base_id":base[1],"icon":base[1],"stats":stats,"affixes":affixes}
static func validate(raw: Variant) -> Dictionary:
 if not raw is Dictionary:return {}
 if not BASES.has(str(raw.get("slot",""))) or str(raw.get("id","")).is_empty():return {}
 if not raw.get("stats",{}) is Dictionary or not raw.get("affixes",[]) is Array:return {}
 var stats={}
 for stat in raw.stats:
  if not STAT_NAMES.has(stat):continue
  if not raw.stats[stat] is float and not raw.stats[stat] is int:continue
  var value=float(raw.stats[stat])
  if is_finite(value) and value>0:stats[stat]=minf(value,1. if CAPS.has(stat) else 5000.)
 if stats.is_empty():return {}
 var item=raw.duplicate(true)
 item.id=str(raw.id).left(64);item.name=str(raw.get("name","Rift Relic")).left(80)
 item.level=clampi(int(raw.get("level",1)),1,99);item.rarity=clampi(int(raw.get("rarity",0)),0,4);item.stats=stats
 item.affixes=[]
 for affix in raw.affixes:
  if not affix is Dictionary or not STAT_NAMES.has(str(affix.get("stat",""))):continue
  var value=float(affix.get("value",0.))
  if is_finite(value) and value>0:item.affixes.append({"name":str(AFFIXES[affix.stat][0]),"stat":affix.stat,"value":minf(value,1. if CAPS.has(affix.stat) else 5000.)})

 var base=resolve_base(item)
 item.base_id=base[1];item.icon=base[1]
 var prefix=str(item.affixes[0].name) if not item.affixes.is_empty() else ""
 item.name=(prefix+" " if not prefix.is_empty() else "")+base[0]
 return item
static func resolve_base(item: Dictionary) -> Array:
 var slot=str(item.get("slot",""))
 if not BASES.has(slot):return []
 var id=str(item.get("base_id",item.get("icon","")))
 id=LEGACY_ICONS.get(id,id)
 for base in BASES[slot]:
  if base[1]==id:return base
 # A damaged/older icon reference must never choose art from a different slot.
 var saved_name=str(item.get("name",""))
 for base in BASES[slot]:
  if saved_name.ends_with(str(base[0])) or saved_name.ends_with(str(LEGACY_NAMES.get(base[1],base[0]))):return base
 return BASES[slot][0]
static func icon_key(item: Dictionary) -> String:
 var base=resolve_base(item)
 return str(base[1]) if not base.is_empty() else ""
static func stat_line(stat: String,value: float) -> String:
 return "+%.1f%% %s" % [value*100.,STAT_NAMES[stat]] if CAPS.has(stat) else "+%.1f %s" % [value,STAT_NAMES[stat]]
static func description(item: Dictionary) -> String:
 var lines=PackedStringArray([item.name,"%s · Item level %d · %s" % [RARITIES[item.rarity],item.level,SLOTS.get(item.slot,"Ring")],"Permanent equipment — carried into every match",""])
 for stat in item.stats:lines.append(stat_line(stat,item.stats[stat]))
 lines.append("\nRandom modifiers:")
 for affix in item.affixes:lines.append(affix.name+": "+stat_line(affix.stat,affix.value))
 return "\n".join(lines)
