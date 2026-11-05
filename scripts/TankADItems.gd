class_name TankADItems
extends RefCounted
const KEYS=["bami","bramble","tiamat","hexdrinker","plated_steelcaps","mercury_treads","sunfire","hollow_radiance","force_nature","randuin","dead_mans","unending_despair","jaksho","locket","deaths_dance","maw","ravenous_hydra","titanic_hydra","sundered_sky","shojin","essence_reaver","kraken","collector","mortal_reminder"]
const BUILDS={
 "malphite":["ruby_crystal","boots","plated_steelcaps","sunfire","force_nature","jaksho","unending_despair","randuin"],
 "thresh":["ruby_crystal","boots","mercury_treads","locket","hollow_radiance","frozen_heart","force_nature","warmog"],
 "garen":["long_sword","boots","plated_steelcaps","black_cleaver","sundered_sky","sterak","dead_mans","spirit_visage"],
 "darius":["long_sword","boots","plated_steelcaps","black_cleaver","titanic_hydra","sundered_sky","sterak","spirit_visage"],
 "leesin":["long_sword","boots","mercury_treads","sundered_sky","black_cleaver","deaths_dance","shojin","maw"],
 "yasuo":["long_sword","boots","berserker_greaves","phantom_dancer","infinity_edge","deaths_dance","mortal_reminder","bloodthirster"],
 "zed":["long_sword","serrated","boots","mercury_treads","collector","black_cleaver","shojin","maw","lord_dominik"],
 "ezreal":["long_sword","sheen","boots","berserker_greaves","essence_reaver","shojin","ravenous_hydra","lord_dominik","maw"],
 "vayne":["long_sword","boots","berserker_greaves","blade_ruined_king","kraken","phantom_dancer","mortal_reminder","maw"],
 "ashe":["long_sword","boots","berserker_greaves","kraken","infinity_edge","phantom_dancer","mortal_reminder","bloodthirster"],
 "jinx":["long_sword","boots","berserker_greaves","collector","infinity_edge","kraken","mortal_reminder","bloodthirster"]}
static func items() -> Dictionary:
 var specs=[
 ["Bami's Cinder",1000,"hp",{"bonus_hp":200.},["ruby_crystal"],"Burn enemies within 170 units each second for 8 + 0.5% max HP magic damage (40 cap against minions). Burn auras do not stack."],
 ["Bramble Vest",900,"def",{"bonus_armor":30.,"bonus_reflect":8.},["cloth_armor","cloth_armor"],"Enemy attackers suffer 40% reduced healing for 3s. Reflect 8 damage on their attacks."],
 ["Tiamat",1200,"ad",{"bonus_ad":20.},["pickaxe"],"Attacks cleave enemies within 100 of the victim for 20% AD physical damage. Cleave items do not stack."],
 ["Hexdrinker",1300,"ad",{"bonus_ad":25.,"bonus_mr":25.},["long_sword","null_mantle"],"Taking magic damage below 30% HP grants a 15% max-HP shield for 3s. 60s cooldown shared with Maw and Sterak."],
 ["Plated Steelcaps",1200,"boot",{"bonus_armor":25.,"bonus_ms":.2},["boots","cloth_armor"],"Take 10% less basic attack damage."],
 ["Mercury's Treads",1200,"boot",{"bonus_mr":25.,"bonus_ms":.2},["boots","null_mantle"],"Stuns, roots, slows and silences expire 25% faster."],
 ["Sunfire Aegis",2900,"def",{"bonus_hp":450.,"bonus_armor":50.},["bami","chain_vest","ruby_crystal"],"Burn nearby enemies each second for 14 + 1% max HP magic damage (40 cap against minions). Burn auras do not stack."],
 ["Hollow Radiance",2900,"def",{"bonus_hp":450.,"bonus_mr":50.,"bonus_hp_regen":3.},["bami","negatron","ruby_crystal"],"Burn nearby enemies each second for 14 + 1% max HP magic damage (40 minion cap). Choose this burn armor against mages."],
 ["Force of Nature",2900,"def",{"bonus_hp":400.,"bonus_mr":65.,"bonus_ms":.05},["negatron","giants_belt"],"After 3 magic hits in 8s, take 15% less magic damage and gain 8% movement speed for 5s."],
 ["Randuin's Omen",2900,"def",{"bonus_hp":400.,"bonus_armor":65.},["chain_vest","giants_belt"],"Take 15% less basic attack damage. Enemy champion attackers are slowed by 20% for 1s."],
 ["Dead Man's Plate",2900,"def",{"bonus_hp":400.,"bonus_armor":45.,"bonus_ms":.05},["chain_vest","giants_belt"],"Moving charges Momentum. At 100 stacks your next attack adds 50 physical damage and slows by 30% for 1.5s."],
 ["Unending Despair",3000,"def",{"bonus_hp":450.,"bonus_armor":50.,"bonus_cdr":.1},["chain_vest","kindlegem","ruby_crystal"],"Every 5s drain champions within 180 for 20 + 1.2% max HP magic damage. Heal 50% of actual HP damage dealt."],
 ["Jak'Sho",3200,"def",{"bonus_hp":400.,"bonus_armor":40.,"bonus_mr":40.},["chain_vest","negatron","ruby_crystal"],"After 3s in champion combat gain 20 armor and MR until 4s without champion damage."],
 ["Locket of the Iron Solari",2500,"def",{"bonus_hp":300.,"bonus_armor":30.,"bonus_mr":30.},["chain_vest","null_mantle","ruby_crystal"],"Below 35% HP shield you and allies within 250 for 120 + 8% your max HP for 3s. Automatic; 60s cooldown."],
 ["Death's Dance",3200,"ad",{"bonus_ad":55.,"bonus_armor":45.,"bonus_cdr":.1},["caulfield","chain_vest","pickaxe"],"Take 15% less physical damage. Killing a champion restores 10% max HP."],
 ["Maw of Malmortius",3000,"ad",{"bonus_ad":55.,"bonus_mr":50.,"bonus_cdr":.1},["hexdrinker","caulfield"],"Taking magic damage below 30% HP grants a 25% max-HP shield for 3s. 60s cooldown shared with Hexdrinker and Sterak."],
 ["Ravenous Hydra",3300,"ad",{"bonus_ad":65.,"bonus_lifesteal":.12,"bonus_cdr":.1},["tiamat","vampiric_scepter","caulfield"],"Attacks cleave nearby enemies for 35% AD physical damage. Cleave items do not stack."],
 ["Titanic Hydra",3300,"ad",{"bonus_ad":35.,"bonus_hp":550.},["tiamat","giants_belt","ruby_crystal"],"Attacks add 1% your max HP physical damage and cleave nearby enemies for 10 + 1.5% max HP. Cleave items do not stack."],
 ["Sundered Sky",3100,"ad",{"bonus_ad":45.,"bonus_hp":400.,"bonus_cdr":.1},["caulfield","kindlegem","long_sword"],"First attack on each champion adds 30% AD physical damage and heals 4% max HP. 6s cooldown per target."],
 ["Spear of Shojin",3100,"ad",{"bonus_ad":45.,"bonus_hp":350.,"bonus_cdr":.15},["caulfield","kindlegem","pickaxe"],"Spell hits build 3% spell damage per stack, up to 9%, for 4s. Does not boost item procs."],
 ["Essence Reaver",3000,"ad",{"bonus_ad":55.,"bonus_crit":.2,"bonus_cdr":.1},["sheen","caulfield","cloak"],"Spellblade: next attack after a skill adds 80% total AD + 20% bonus AD and restores 8% max mana. Strongest Spellblade only."],
 ["Kraken Slayer",3100,"ad",{"bonus_ad":40.,"bonus_as":.35,"bonus_ms":.04},["recurve_bow","pickaxe","dagger"],"Every third consecutive attack on the same target adds 30 + 45% AD physical damage. Stacks expire after 5s."],
 ["The Collector",3000,"ad",{"bonus_ad":50.,"bonus_crit":.2,"bonus_lethality":12.},["serrated","pickaxe","cloak"],"Direct attacks and spells execute champions left below 4% HP after shields. Champion kills grant 25 extra gold."],
 ["Mortal Reminder",3100,"ad",{"bonus_ad":35.,"bonus_crit":.2,"bonus_armor_pen":.3},["last_whisper","pickaxe"],"Attacks and physical spell hits reduce healing by 40% for 3s. Percent armor penetration uses your strongest item."]]
 var labels={"bonus_ad":"AD","bonus_hp":"HP","bonus_mr":"magic resist","bonus_armor":"armor","bonus_hp_regen":"HP regen/s","bonus_as":"attack speed","bonus_ms":"move speed","bonus_crit":"crit chance","bonus_cdr":"cooldown reduction","bonus_lethality":"flat armor penetration","bonus_armor_pen":"armor penetration","bonus_lifesteal":"lifesteal","bonus_reflect":"reflect damage"}
 var result={}
 for i in range(KEYS.size()):
  var spec=specs[i];var lines=[]
  for field in spec[3]:
   var percent=field in ["bonus_as","bonus_ms","bonus_crit","bonus_cdr","bonus_armor_pen","bonus_lifesteal"]
   lines.append("+%.0f%s %s" % [spec[3][field]*(100 if percent else 1),"%" if percent else "",labels[field]])
  result[KEYS[i]]={"name":spec[0],"cost":spec[1],"cat":spec[2],"stats":spec[3],"recipe":spec[4],"desc":", ".join(lines)+". "+spec[5],"icon":""}
 return result
static func matches(id: String, path: String) -> bool:
 match path:
  "tank":return id in ["ruby_crystal","giants_belt","cloth_armor","chain_vest","null_mantle","negatron","kindlegem","bami","bramble","plated_steelcaps","mercury_treads","sunfire","hollow_radiance","force_nature","randuin","dead_mans","unending_despair","jaksho","locket","thornmail","warmog","spirit_visage","frozen_heart"]
  "bruiser":return id in ["long_sword","pickaxe","caulfield","hexdrinker","tiamat","sheen","plated_steelcaps","mercury_treads","black_cleaver","trinity","sterak","deaths_dance","maw","ravenous_hydra","titanic_hydra","sundered_sky","shojin"]
  "marksman":return id in ["long_sword","pickaxe","bf_sword","dagger","recurve_bow","zeal","cloak","last_whisper","berserker_greaves","phantom_dancer","infinity_edge","bloodthirster","blade_ruined_king","lord_dominik","essence_reaver","kraken","collector","mortal_reminder"]
 return false
