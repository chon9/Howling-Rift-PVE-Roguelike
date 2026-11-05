extends Node
# Adapted ARAM items, component recipes and real combat passives.
func _ready() -> void:
 ITEMS.merge(ExpansionItems.items())
 ORDER.append_array(ExpansionItems.KEYS)
 BUILD_ORDERS.merge(ExpansionItems.BUILDS,true)
 BUILD_ORDERS["ashe"]=["long_sword","boots","berserker_greaves","infinity_edge","phantom_dancer","lord_dominik","bloodthirster"]
 BUILD_ORDERS["jinx"]=["long_sword","boots","berserker_greaves","infinity_edge","phantom_dancer","lord_dominik","bloodthirster"]
 BUILD_ORDERS["lux"]=["amp_tome","boots","ludens","sorcerer_shoes","rabadon","void_staff","banshee"]
 BUILD_ORDERS["ahri"]=["amp_tome","boots","ludens","sorcerer_shoes","rabadon","void_staff","morello"]
 BUILD_ORDERS["annie"]=["amp_tome","boots","liandry","sorcerer_shoes","rabadon","banshee","void_staff"]
 BUILD_ORDERS["garen"]=["long_sword","boots","black_cleaver","berserker_greaves","sterak","spirit_visage","warmog"]
 ITEMS.merge(TankADItems.items())
 ORDER.append_array(TankADItems.KEYS)
 BUILD_ORDERS.merge(TankADItems.BUILDS,true)
 BUILD_ORDERS.merge(RosterExpansion12.builds(),true)
 ITEMS.merge(SupportItems.items())
 ORDER.append_array(SupportItems.KEYS)
 BUILD_ORDERS.merge(SupportItems.builds(),true)
 ITEMS.merge(MatchTraining.items())
 ORDER.append_array(MatchTraining.KEYS)
var ITEMS = {
  "long_sword": {
    "name": "Long Sword",
    "cost": 350,
    "cat": "ad",
    "stats": {
      "bonus_ad": 10.0
    },
    "desc": "+10 attack damage",
    "recipe": [],
    "icon": ""
  },
  "bf_sword": {
    "name": "B.F. Sword",
    "cost": 1300,
    "cat": "ad",
    "stats": {
      "bonus_ad": 40.0
    },
    "desc": "+40 attack damage",
    "recipe": [],
    "icon": ""
  },
  "infinity_edge": {
    "name": "Infinity Edge",
    "cost": 3400,
    "cat": "ad",
    "stats": {
      "bonus_ad": 70.0,
      "bonus_crit": 0.25,
      "bonus_crit_damage": 0.35
    },
    "desc": "+70 AD, +25% critical chance. Critical strikes deal 210% damage.",
    "recipe": [
      "bf_sword",
      "cloak",
      "long_sword"
    ],
    "icon": ""
  },
  "bloodthirster": {
    "name": "Bloodthirster",
    "cost": 3200,
    "cat": "ad",
    "stats": {
      "bonus_ad": 65.0,
      "bonus_lifesteal": 0.2
    },
    "desc": "+65 AD, +20% lifesteal. Excess lifesteal becomes a shield up to 15% max HP.",
    "recipe": [
      "bf_sword",
      "vampiric_scepter",
      "long_sword"
    ],
    "icon": ""
  },
  "amp_tome": {
    "name": "Amplifying Tome",
    "cost": 400,
    "cat": "ap",
    "stats": {
      "bonus_ap": 20.0
    },
    "desc": "+20 ability power",
    "recipe": [],
    "icon": ""
  },
  "needlessly_rod": {
    "name": "Needlessly Large Rod",
    "cost": 1250,
    "cat": "ap",
    "stats": {
      "bonus_ap": 60.0
    },
    "desc": "+60 ability power",
    "recipe": [],
    "icon": ""
  },
  "rabadon": {
    "name": "Rabadon's Deathcap",
    "cost": 3400,
    "cat": "ap",
    "stats": {
      "bonus_ap": 100.0
    },
    "desc": "+100 AP. Increases all your ability power by 30%.",
    "recipe": [
      "needlessly_rod",
      "needlessly_rod"
    ],
    "icon": ""
  },
  "archangel": {
    "name": "Archangel's Staff",
    "cost": 2800,
    "cat": "ap",
    "stats": {
      "bonus_ap": 60.0,
      "bonus_mp": 500.0,
      "bonus_cdr": 0.1
    },
    "desc": "+60 AP, +500 mana, +10% cooldown reduction. Gain AP equal to 2.5% max mana.",
    "recipe": [
      "amp_tome",
      "sapphire_crystal",
      "kindlegem"
    ],
    "icon": ""
  },
  "ruby_crystal": {
    "name": "Ruby Crystal",
    "cost": 400,
    "cat": "hp",
    "stats": {
      "bonus_hp": 150.0
    },
    "desc": "+150 max health",
    "recipe": [],
    "icon": ""
  },
  "giants_belt": {
    "name": "Giant's Belt",
    "cost": 900,
    "cat": "hp",
    "stats": {
      "bonus_hp": 350.0
    },
    "desc": "+350 max health",
    "recipe": [
      "ruby_crystal"
    ],
    "icon": ""
  },
  "warmog": {
    "name": "Warmog's Armor",
    "cost": 2800,
    "cat": "hp",
    "stats": {
      "bonus_hp": 800.0,
      "bonus_hp_regen": 5.0
    },
    "desc": "+800 HP, +5 regeneration. After 6 seconds without damage, regenerate 2% max HP per second.",
    "recipe": [
      "giants_belt",
      "kindlegem",
      "ruby_crystal"
    ],
    "icon": ""
  },
  "chain_vest": {
    "name": "Chain Vest",
    "cost": 800,
    "cat": "def",
    "stats": {
      "bonus_armor": 40.0
    },
    "desc": "+40 armor",
    "recipe": [
      "cloth_armor"
    ],
    "icon": ""
  },
  "thornmail": {
    "name": "Thornmail",
    "cost": 2700,
    "cat": "def",
    "stats": {
      "bonus_armor": 60.0,
      "bonus_hp": 350.0,
      "bonus_reflect": 25.0
    },
    "desc": "+60 armor, +350 HP. Reflect 25 damage when struck by a basic attack.",
    "recipe": [
      "chain_vest",
      "giants_belt"
    ],
    "icon": ""
  },
  "boots": {
    "name": "Boots",
    "cost": 300,
    "cat": "boot",
    "stats": {
      "bonus_ms": 0.12
    },
    "desc": "+12% movement speed. One boots item at a time.",
    "recipe": [],
    "icon": ""
  },
  "berserker_greaves": {
    "name": "Berserker's Greaves",
    "cost": 1100,
    "cat": "boot",
    "stats": {
      "bonus_ms": 0.2,
      "bonus_as": 0.35
    },
    "desc": "+20% movement speed, +35% attack speed.",
    "recipe": [
      "boots",
      "dagger",
      "dagger"
    ],
    "icon": ""
  },
  "sorcerer_shoes": {
    "name": "Sorcerer's Shoes",
    "cost": 1100,
    "cat": "boot",
    "stats": {
      "bonus_ms": 0.2,
      "bonus_cdr": 0.1,
      "bonus_ap": 25.0
    },
    "desc": "+20% movement speed, +25 AP, +10% cooldown reduction.",
    "recipe": [
      "boots",
      "amp_tome"
    ],
    "icon": ""
  },
  "dagger": {
    "name": "Dagger",
    "cost": 300,
    "cat": "ad",
    "stats": {
      "bonus_as": 0.12
    },
    "desc": "+12% attack speed",
    "recipe": [],
    "icon": ""
  },
  "cloak": {
    "name": "Cloak of Agility",
    "cost": 600,
    "cat": "ad",
    "stats": {
      "bonus_crit": 0.2
    },
    "desc": "+20% critical chance",
    "recipe": [],
    "icon": ""
  },
  "cloth_armor": {
    "name": "Cloth Armor",
    "cost": 300,
    "cat": "def",
    "stats": {
      "bonus_armor": 15.0
    },
    "desc": "+15 armor",
    "recipe": [],
    "icon": ""
  },
  "sapphire_crystal": {
    "name": "Sapphire Crystal",
    "cost": 350,
    "cat": "ap",
    "stats": {
      "bonus_mp": 200.0
    },
    "desc": "+200 max mana",
    "recipe": [],
    "icon": ""
  },
  "vampiric_scepter": {
    "name": "Vampiric Scepter",
    "cost": 900,
    "cat": "ad",
    "stats": {
      "bonus_ad": 15.0,
      "bonus_lifesteal": 0.1
    },
    "desc": "+15 attack damage, +10% lifesteal",
    "recipe": [
      "long_sword"
    ],
    "icon": ""
  },
  "kindlegem": {
    "name": "Kindlegem",
    "cost": 800,
    "cat": "hp",
    "stats": {
      "bonus_hp": 200.0,
      "bonus_cdr": 0.08
    },
    "desc": "+200 max HP, +8% cooldown reduction",
    "recipe": [
      "ruby_crystal"
    ],
    "icon": ""
  },
  "recurve_bow": {
    "name": "Recurve Bow",
    "cost": 700,
    "cat": "ad",
    "stats": {
      "bonus_as": 0.25
    },
    "desc": "+25% attack speed",
    "recipe": [
      "dagger"
    ],
    "icon": ""
  },
  "sheen": {
    "name": "Sheen",
    "cost": 900,
    "cat": "ad",
    "stats": {
      "bonus_mp": 150.0
    },
    "desc": "Spellblade: after casting a skill, your next basic attack within 5s deals +75% AD.",
    "recipe": [
      "sapphire_crystal"
    ],
    "icon": ""
  },
  "blade_ruined_king": {
    "name": "Blade of the Ruined King",
    "cost": 3200,
    "cat": "ad",
    "stats": {
      "bonus_ad": 40.0,
      "bonus_as": 0.3,
      "bonus_lifesteal": 0.1
    },
    "desc": "+40 AD, +30% attack speed, +10% lifesteal. Attacks add 6% of target current HP (60 max vs creeps).",
    "recipe": [
      "vampiric_scepter",
      "recurve_bow",
      "long_sword"
    ],
    "icon": ""
  },
  "ludens": {
    "name": "Luden's Echo",
    "cost": 3000,
    "cat": "ap",
    "stats": {
      "bonus_ap": 80.0,
      "bonus_mp": 300.0,
      "bonus_cdr": 0.1
    },
    "desc": "+80 AP, +300 mana, +10% cooldown reduction. A skill hit deals +70 +10% AP every 6 seconds.",
    "recipe": [
      "needlessly_rod",
      "sapphire_crystal",
      "amp_tome"
    ],
    "icon": ""
  }
}

var ORDER = ["long_sword", "bf_sword", "infinity_edge", "bloodthirster", "amp_tome", "needlessly_rod", "rabadon", "archangel", "ruby_crystal", "giants_belt", "warmog", "chain_vest", "thornmail", "boots", "berserker_greaves", "sorcerer_shoes", "dagger", "cloak", "cloth_armor", "sapphire_crystal", "vampiric_scepter", "kindlegem", "recurve_bow", "sheen", "blade_ruined_king", "ludens"]
const CATEGORIES = [{"id":"all","label":"All items"}, {"id":"recommended","label":"Recommended"}, {"id":"ad","label":"Attack"}, {"id":"ap","label":"Magic"}, {"id":"hp","label":"Health"}, {"id":"def","label":"Defense"}, {"id":"boot","label":"Boots"}, {"id":"support","label":"Support"},{"id":"consumable","label":"Stat consumables"}]
var BUILD_ORDERS = {
 "yasuo":["long_sword","boots","berserker_greaves","infinity_edge","bloodthirster","blade_ruined_king","thornmail"],
 "leesin":["long_sword","boots","vampiric_scepter","berserker_greaves","bloodthirster","warmog","thornmail"],
 "zed":["long_sword","sheen","boots","berserker_greaves","infinity_edge","bloodthirster","thornmail"],
 "jinx":["long_sword","boots","berserker_greaves","infinity_edge","blade_ruined_king","bloodthirster"],
 "katarina":["amp_tome","boots","sorcerer_shoes","ludens","rabadon","archangel"],
 "kayle":["amp_tome","boots","berserker_greaves","archangel","rabadon","blade_ruined_king"],
 "ashe":["long_sword","boots","vampiric_scepter","berserker_greaves","blade_ruined_king","infinity_edge","bloodthirster","thornmail"],
 "ezreal":["long_sword","sheen","boots","berserker_greaves","blade_ruined_king","infinity_edge","bloodthirster"],
 "lux":["amp_tome","boots","sorcerer_shoes","ludens","rabadon","archangel","warmog"],
 "ahri":["amp_tome","boots","sorcerer_shoes","ludens","archangel","rabadon","warmog"],
 "annie":["amp_tome","boots","sorcerer_shoes","ludens","rabadon","warmog","archangel"],
 "garen":["ruby_crystal","boots","giants_belt","berserker_greaves","warmog","thornmail","infinity_edge","bloodthirster"]}
func sell_value(id: String) -> int:
 return int(ITEMS[id].cost * 0.7)
func consume_component(id: String, working: Array, consumed: Array) -> int:
 var slot = working.find(id)
 if slot >= 0:
  working[slot] = ""
  consumed.append(slot)
  return ITEMS[id].cost
 var credit = 0
 for child in ITEMS[id].recipe:
  credit += consume_component(child, working, consumed)
 return credit
func purchase_plan(id: String, inventory: Array, counts: Dictionary = {}) -> Dictionary:
 if not ITEMS.has(id): return {"valid":false,"reason":"Unknown item","cost":0,"consume":[],"slot":-1}
 if ITEMS[id].get("consumable",false):
  return {"valid":true,"reason":"","cost":MatchTraining.price(id,counts),"consume":[],"slot":-1}
 var working = inventory.duplicate()
 var consumed: Array = []
 var credit = 0
 for component in ITEMS[id].recipe:
  credit += consume_component(component, working, consumed)
 var slot = working.find("")
 var reason = ""
 if not ITEMS[id].recipe.is_empty() and inventory.has(id): reason = "Already owned"
 if ITEMS[id].cat == "boot":
  for index in range(inventory.size()):
   if inventory[index] != "" and ITEMS[inventory[index]].cat == "boot" and not consumed.has(index): reason = "One boots item at a time"
 if slot < 0: reason = "Inventory full: upgrade a component or sell an item"
 return {"valid":reason.is_empty(),"reason":reason,"cost":maxi(0, ITEMS[id].cost-credit),"consume":consumed,"slot":slot}

func matches_category(id: String, category: String) -> bool:
 if not ITEMS.has(id): return false
 var item = ITEMS[id]
 if category == "all": return true
 if category == "consumable": return item.get("consumable",false)
 if item.get("consumable",false): return false
 var stats = item.stats
 match category:
  "ad": return item.cat == "ad" or stats.get("bonus_ad",0)>0 or stats.get("bonus_as",0)>0 or stats.get("bonus_crit",0)>0 or stats.get("bonus_lifesteal",0)>0 or stats.get("bonus_armor_pen",0)>0 or stats.get("bonus_lethality",0)>0
  "ap": return item.cat == "ap" or stats.get("bonus_ap",0)>0 or stats.get("bonus_magic_pen",0)>0
  "hp": return stats.get("bonus_hp",0)>0 or stats.get("bonus_hp_regen",0)>0
  "def": return item.cat == "def" or stats.get("bonus_armor",0)>0 or stats.get("bonus_mr",0)>0 or id in ["sterak","locket"]
  "support": return item.cat == "support" or id in ["locket","spirit_visage","kindlegem","boots","mercury_treads"]
  "boot": return item.cat == "boot"
 return false

func matches_mage_build(id: String) -> bool:
 if not ITEMS.has(id) or ITEMS[id].get("consumable",false): return false
 return matches_category(id,"ap") or id in ["boots","sorcerer_shoes","mercury_treads","plated_steelcaps","sapphire_crystal","ruby_crystal","kindlegem","null_mantle","negatron","cloth_armor","chain_vest","frozen_heart"]

func upgrades_for(id: String) -> Array:
 var result: Array = []
 var frontier: Array = [id]
 while not frontier.is_empty():
  var part=frontier.pop_front()
  for candidate in ORDER:
   if candidate!=id and not result.has(candidate) and ITEMS[candidate].recipe.has(part):
    result.append(candidate);frontier.append(candidate)
 return result
func item_tooltip(id: String, counts: Dictionary = {}) -> String:
 if not ITEMS.has(id): return "Empty item slot"
 var item=ITEMS[id]
 var cost=MatchTraining.price(id,counts) if item.get("consumable",false) else item.cost
 var text="%s • %dg\n\n%s" % [item.name,cost,item.desc]
 var upgrades=upgrades_for(id)
 if not upgrades.is_empty():
  var names=[]
  for next in upgrades.slice(0,6):names.append(ITEMS[next].name)
  text+="\n\nUpgrades into: "+", ".join(names)
 elif not item.get("consumable",false):text+="\n\nFinished item • no further upgrades."
 if not item.get("consumable",false):text+="\nLeft-click: browse upgrades • Right-click owned item: sell at shop"
 return text
