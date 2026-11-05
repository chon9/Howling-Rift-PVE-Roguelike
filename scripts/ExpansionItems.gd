class_name ExpansionItems
extends RefCounted
const KEYS=["pickaxe","blasting_wand","null_mantle","negatron","caulfield","zeal","serrated","last_whisper","trinity","black_cleaver","sterak","phantom_dancer","lord_dominik","nashor","liandry","morello","void_staff","banshee","spirit_visage","frozen_heart"]
const BUILDS={
 "darius":["long_sword","boots","black_cleaver","berserker_greaves","sterak","spirit_visage","bloodthirster"],
 "malphite":["ruby_crystal","boots","frozen_heart","sorcerer_shoes","spirit_visage","liandry","warmog"],
 "veigar":["amp_tome","boots","ludens","sorcerer_shoes","rabadon","void_staff","banshee"],
 "morgana":["amp_tome","boots","liandry","sorcerer_shoes","morello","banshee","rabadon"],
 "vayne":["long_sword","boots","blade_ruined_king","berserker_greaves","phantom_dancer","infinity_edge","lord_dominik"],
 "thresh":["ruby_crystal","boots","spirit_visage","sorcerer_shoes","frozen_heart","liandry","warmog"],
 "yasuo":["long_sword","boots","berserker_greaves","phantom_dancer","infinity_edge","bloodthirster","lord_dominik"],
 "leesin":["long_sword","boots","black_cleaver","berserker_greaves","sterak","spirit_visage","bloodthirster"],
 "zed":["long_sword","serrated","boots","black_cleaver","berserker_greaves","lord_dominik","bloodthirster"],
 "ezreal":["long_sword","sheen","boots","trinity","berserker_greaves","blade_ruined_king","lord_dominik"],
 "kayle":["amp_tome","boots","berserker_greaves","nashor","rabadon","void_staff","bloodthirster"]}
static func items() -> Dictionary:
 var specs=[
 ["Pickaxe",875,"ad",{"bonus_ad":25.},[],""],
 ["Blasting Wand",850,"ap",{"bonus_ap":40.},[],""],
 ["Null-Magic Mantle",450,"def",{"bonus_mr":20.},[],""],
 ["Negatron Cloak",900,"def",{"bonus_mr":40.},["null_mantle"],""],
 ["Caulfield's Warhammer",1100,"ad",{"bonus_ad":25.,"bonus_cdr":.1},["long_sword","long_sword"],""],
 ["Zeal",1100,"ad",{"bonus_as":.2,"bonus_crit":.15,"bonus_ms":.05},["dagger","cloak"],""],
 ["Serrated Dirk",1100,"ad",{"bonus_ad":25.,"bonus_lethality":10.},["long_sword","long_sword"],""],
 ["Last Whisper",1450,"ad",{"bonus_ad":20.,"bonus_armor_pen":.2},["pickaxe","long_sword"],""],
 ["Trinity Force",3300,"ad",{"bonus_ad":35.,"bonus_as":.3,"bonus_hp":250.,"bonus_cdr":.1},["sheen","caulfield","kindlegem"],"Spellblade: next attack after casting adds 150% AD. Does not stack with Sheen."],
 ["Black Cleaver",3000,"ad",{"bonus_ad":40.,"bonus_hp":400.,"bonus_cdr":.15},["caulfield","kindlegem","long_sword"],"Attacks shred 5% armor per hit, up to 20%, for 4 seconds."],
 ["Sterak's Gage",3100,"hp",{"bonus_ad":45.,"bonus_hp":450.},["pickaxe","giants_belt"],"Below 30% HP gain a 25% max-HP shield for 3 seconds. 60s cooldown."],
 ["Phantom Dancer",2800,"ad",{"bonus_as":.5,"bonus_crit":.25,"bonus_ms":.07},["zeal","recurve_bow"],""],
 ["Lord Dominik's Regards",3100,"ad",{"bonus_ad":35.,"bonus_crit":.2,"bonus_armor_pen":.35},["last_whisper","cloak","long_sword"],""],
 ["Nashor's Tooth",3000,"ap",{"bonus_ap":70.,"bonus_as":.4,"bonus_cdr":.1},["recurve_bow","blasting_wand","amp_tome"],"Attacks add 15 + 15% AP magic damage."],
 ["Liandry's Torment",3200,"ap",{"bonus_ap":75.,"bonus_hp":350.},["blasting_wand","kindlegem","amp_tome"],"Skill hits burn 1% target max HP per second for 3 seconds (30 cap against minions). Refreshes without stacking."],
 ["Morellonomicon",2700,"ap",{"bonus_ap":70.,"bonus_hp":250.},["blasting_wand","kindlegem","amp_tome"],"Skill hits reduce healing and regeneration by 40% for 3 seconds."],
 ["Void Staff",3000,"ap",{"bonus_ap":85.,"bonus_magic_pen":.35},["blasting_wand","amp_tome"],""],
 ["Banshee's Veil",2800,"ap",{"bonus_ap":65.,"bonus_mr":45.},["blasting_wand","negatron","amp_tome"],"Block one enemy spell and its crowd control. 35s cooldown."],
 ["Spirit Visage",2900,"def",{"bonus_hp":450.,"bonus_mr":50.,"bonus_hp_regen":4.},["negatron","kindlegem","ruby_crystal"],"Healing and regeneration received increase by 25%."],
 ["Frozen Heart",2800,"def",{"bonus_armor":80.,"bonus_mp":350.,"bonus_cdr":.15},["chain_vest","sapphire_crystal","kindlegem"],"Enemies within 300 units have 20% reduced attack speed."]]
 var labels={"bonus_ad":"AD","bonus_ap":"AP","bonus_hp":"HP","bonus_mr":"magic resist","bonus_armor":"armor","bonus_mp":"mana","bonus_hp_regen":"HP regen/s","bonus_as":"attack speed","bonus_ms":"move speed","bonus_crit":"crit chance","bonus_cdr":"cooldown reduction","bonus_lethality":"flat armor penetration","bonus_armor_pen":"armor penetration","bonus_magic_pen":"magic penetration"}
 var result={}
 for i in range(KEYS.size()):
  var spec=specs[i];var lines=[]
  for field in spec[3]:
   var percent=field in ["bonus_as","bonus_ms","bonus_crit","bonus_cdr","bonus_armor_pen","bonus_magic_pen"]
   lines.append("+%.0f%s %s" % [spec[3][field]*(100 if percent else 1),"%" if percent else "",labels[field]])
  result[KEYS[i]]={"name":spec[0],"cost":spec[1],"cat":spec[2],"stats":spec[3],"recipe":spec[4],"desc":", ".join(lines)+(". "+spec[5] if not spec[5].is_empty() else ""),"icon":""}
 return result
