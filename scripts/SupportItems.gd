class_name SupportItems
extends RefCounted
const KEYS=["faerie_charm","forbidden_idol","moonstone","ardent_censer","flowing_staff","redemption","dawn_bell","guardian_oath"]
static func items() -> Dictionary:
 var specs=[
  ["Faerie Charm",250,{"bonus_mp_regen":2.},[],"+2 mana regeneration per second."],
  ["Forbidden Idol",800,{"bonus_mp_regen":3.,"bonus_heal_power":.08},["faerie_charm"],"+3 mana regen/s, +8% outgoing healing and shielding."],
  ["Moonstone Reliquary",2700,{"bonus_ap":45.,"bonus_hp":200.,"bonus_cdr":.1,"bonus_heal_power":.15},["forbidden_idol","kindlegem","amp_tome"],"+45 AP, +200 HP, +10% cooldown reduction, +15% heal/shield power. Helping an ally also heals the most wounded OTHER ally within 300 for 45 + 10% AP; 4s cooldown."],
  ["Ardent Censer",2600,{"bonus_ap":50.,"bonus_mp_regen":4.,"bonus_heal_power":.1},["forbidden_idol","blasting_wand"],"+50 AP, +4 mana regen/s, +10% heal/shield power. Healing or shielding an ally grants both of you 20% attack speed and 12 + 5% AP magic damage on attacks for 4s. Refreshes without stacking."],
  ["Staff of Flowing Light",2600,{"bonus_ap":55.,"bonus_cdr":.1,"bonus_heal_power":.1},["forbidden_idol","blasting_wand"],"+55 AP, +10% cooldown reduction, +10% heal/shield power. Helping an ally grants both of you 20 AP and 12% move speed for 4s. Refreshes without stacking."],
  ["Redemption",2800,{"bonus_hp":300.,"bonus_cdr":.1,"bonus_mp_regen":3.,"bonus_heal_power":.15},["forbidden_idol","kindlegem","ruby_crystal"],"+300 HP, +10% cooldown reduction, +3 mana regen/s, +15% heal/shield power. In combat, an ally below 35% health within 450 triggers a healing burst after 0.6s: 100 + 15% AP + 5% ally max HP within 180. 45s cooldown."],
  ["Dawn Bell",2500,{"bonus_ap":40.,"bonus_hp":250.,"bonus_heal_power":.1},["forbidden_idol","kindlegem"],"+40 AP, +250 HP, +10% heal/shield power. Helping an ally grants them a 2s shield worth 35 + 10% AP and cleanses slows. 8s cooldown per recipient."],
  ["Guardian's Oath",2700,{"bonus_hp":350.,"bonus_armor":35.,"bonus_mr":25.},["kindlegem","chain_vest","null_mantle"],"+350 HP, +35 armor, +25 magic resist. Shield the most wounded ally below 45% health within 300 for 120 + 8% your max HP for 3s. 20s cooldown; matching Oath shields refresh without stacking."]]
 var result={}
 for i in range(KEYS.size()):
  var s=specs[i];result[KEYS[i]]={"name":s[0],"cost":s[1],"cat":"support","stats":s[2],"recipe":s[3],"desc":s[4],"icon":""}
 return result
static func builds() -> Dictionary:
 return {"soraka":["faerie_charm","boots","forbidden_idol","mercury_treads","moonstone","redemption","flowing_staff","ardent_censer","dawn_bell"],"janna":["faerie_charm","boots","forbidden_idol","mercury_treads","ardent_censer","moonstone","guardian_oath","flowing_staff","redemption"],"thresh":["ruby_crystal","boots","plated_steelcaps","locket","guardian_oath","frozen_heart","redemption","spirit_visage"]}
