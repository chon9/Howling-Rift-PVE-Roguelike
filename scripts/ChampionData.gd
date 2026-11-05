extends Node

func skill_description(key: String, index: int, champion = null) -> String:
	var skill = CHAMPIONS[key].skills[index]
	var rank_text = ""
	var cooldown = float(skill.cd)
	if champion != null:
		rank_text = "  •  Rank %d/%d" % [champion.skill_ranks[index], skill.max]
		cooldown = champion.effective_cd(cooldown)
	var recast_text = ""
	if champion != null:
		var recast = NewHeroKits.recast_info(champion,index)
		if not recast.is_empty(): recast_text = "\n\n%s: %.1fs remaining%s" % [recast.label,recast.time," • target out of range" if not recast.available else " • press again to recast"]
	var numbers = preload("res://scripts/SkillScaling.gd").description(skill.cast_id,champion.skill_ranks[index] if champion != null else 1,champion)
	if ExpansionRoster.KEYS.has(key): numbers = ExpansionKits.description(skill.cast_id,champion,champion.skill_ranks[index] if champion != null else 1)
	if key in RosterExpansion12.KEYS: numbers = Roster12Kits.description(skill.cast_id,champion,champion.skill_ranks[index] if champion != null else 1)
	if key in SupportRoster.KEYS: numbers = SupportKits.description(skill.cast_id,champion,champion.skill_ranks[index] if champion != null else 1)
	var reach = "Self" if skill.range <= 0 else "%d units" % int(skill.range)
	return "%s  •  %s%s\n\n%s\n\n%s: %d  •  Cooldown: %.1fs  •  Range: %s" % [skill.key, skill.name, rank_text, skill.desc+"\n\n"+numbers+recast_text, "Energy" if key in ["leesin","zed"] else "Mana", skill.cost, cooldown, reach]
# Autoload: ChampionData — stat tables + skill metadata for each champion.
# Skills reference a `cast_id` string that Champion.gd dispatches to the actual
# implementation methods (keeps data pure and avoids Callable serialisation).

func _ready() -> void:
	CHAMPIONS.merge(ExpansionRoster.heroes())
	CHAMPIONS.merge(RosterExpansion12.heroes())
	CHAMPIONS.merge(SupportRoster.heroes())
	for key in CHAMPIONS:
		CHAMPIONS[key]["passive"]=HeroPassives.DATA[key]
		if key in ["yasuo","katarina","riven","renekton","garen"]:
			for stat in ["mp","mp_per_lv","mp_regen","mp_regen_per_lv"]:CHAMPIONS[key][stat]=0.
			for sk in CHAMPIONS[key].skills:sk.cost=0
		if key in ["leesin","zed"]:
			CHAMPIONS[key].mp=200.;CHAMPIONS[key].mp_per_lv=0.;CHAMPIONS[key].mp_regen=10.;CHAMPIONS[key].mp_regen_per_lv=0.
			CHAMPIONS[key].skills[3].cost=0
var CHAMPIONS = {
	"lux": {
		"name":"Solara", "title":"The Prism Keeper", "role":"ARTILLERY • ROOT • LASER", "icon":"✦",
		"color":Color("efda9b"), "trim":Color("415a94"), "accent":Color("ffe9a5"),
		"hp":560.0, "hp_per_lv":95.0, "hp_regen":4.0, "hp_regen_per_lv":0.4,
		"mp":440.0, "mp_per_lv":45.0, "mp_regen":8.0, "mp_regen_per_lv":0.6,
		"ad":54.0, "ad_per_lv":3.0, "atk_range":350.0, "atk_spd":0.62, "move_speed":185.0,
		"auto_type":"ranged", "auto_color":Color("ffe9a5"), "priority":[3,2,0,1],
		"skills":[
			{"key":"Q","name":"Light Binding","icon":"✧","cost":50,"cd":9.0,"max":5,"kind":"line","range":580.0,"desc":"Light bolt stuns up to two enemies for 1.5s.","cast_id":"lux_q"},
			{"key":"W","name":"Prismatic Barrier","icon":"◇","cost":50,"cd":12.0,"max":5,"kind":"self","range":0.0,"desc":"Shield yourself and allied champions within 250 units for 3 seconds.","cast_id":"lux_w"},
			{"key":"E","name":"Lucent Singularity","icon":"✺","cost":65,"cd":8.0,"max":5,"kind":"point","range":500.0,"desc":"Detonate a light field that damages and slows enemies.","cast_id":"lux_e"},
			{"key":"R","name":"Final Spark","icon":"━","cost":100,"cd":45.0,"max":3,"kind":"line","range":1100.0,"desc":"Fire a piercing laser through every enemy in its path.","cast_id":"lux_r"}
		]
	},
	"ahri": {
		"name":"Nyra", "title":"The Veil Dancer", "role":"MOBILITY • CHARM • ORB", "icon":"◉",
		"color":Color("edafd5"), "trim":Color("913d72"), "accent":Color("8aeff5"),
		"hp":590.0,"hp_per_lv":96.0,"hp_regen":4.0,"hp_regen_per_lv":0.5,
		"mp":420.0,"mp_per_lv":40.0,"mp_regen":8.0,"mp_regen_per_lv":0.6,
		"ad":53.0,"ad_per_lv":3.0,"atk_range":330.0,"atk_spd":0.66,"move_speed":200.0,
		"auto_type":"ranged","auto_color":Color("8aeff5"),"priority":[3,0,1,2],
		"skills":[
			{"key":"Q","name":"Orb of Deception","icon":"◉","cost":60,"cd":7.0,"max":5,"kind":"line","range":500.0,"desc":"Piercing orb travels out and returns, hitting each enemy twice.","cast_id":"ahri_q"},
			{"key":"W","name":"Fox-Fire","icon":"♨","cost":40,"cd":9.0,"max":5,"kind":"self","range":0.0,"desc":"Three homing flames strike nearby foes. Requires a target.","cast_id":"ahri_w"},
			{"key":"E","name":"Charm","icon":"♥","cost":60,"cd":12.0,"max":5,"kind":"line","range":550.0,"desc":"A charm projectile damages and stuns the first enemy hit.","cast_id":"ahri_e"},
			{"key":"R","name":"Spirit Rush","icon":"»","cost":100,"cd":35.0,"max":3,"kind":"point","range":300.0,"desc":"Dash toward cursor and launch three spirit bolts at nearby foes.","cast_id":"ahri_r"}
		]
	},
	"ezreal": {
		"name":"Kael","title":"The Runebound Explorer","role":"POKE • BLINK • BARRAGE","icon":"➤",
		"color":Color("e6cd8e"),"trim":Color("775343"),"accent":Color("64dcec"),
		"hp":580.0,"hp_per_lv":100.0,"hp_regen":4.0,"hp_regen_per_lv":0.4,
		"mp":360.0,"mp_per_lv":45.0,"mp_regen":8.0,"mp_regen_per_lv":0.6,
		"ad":60.0,"ad_per_lv":3.5,"atk_range":360.0,"atk_spd":0.7,"move_speed":195.0,
		"auto_type":"ranged","auto_color":Color("64dcec"),"priority":[3,0,2,1],
		"skills":[
			{"key":"Q","name":"Mystic Shot","icon":"➤","cost":30,"cd":4.0,"max":5,"kind":"line","range":620.0,"desc":"Fast long-range bolt. Scales strongly with attack damage.","cast_id":"ezreal_q"},
			{"key":"W","name":"Essence Flux","icon":"◎","cost":50,"cd":10.0,"max":5,"kind":"line","range":550.0,"desc":"Marks the first foe. Your next attack or spell detonates it.","cast_id":"ezreal_w"},
			{"key":"E","name":"Arcane Shift","icon":"»","cost":70,"cd":14.0,"max":5,"kind":"point","range":260.0,"desc":"Blink toward cursor and fire a homing bolt at the nearest foe.","cast_id":"ezreal_e"},
			{"key":"R","name":"Trueshot Barrage","icon":"≋","cost":100,"cd":55.0,"max":3,"kind":"line","range":1400.0,"desc":"Wide energy wave pierces all enemies along its path.","cast_id":"ezreal_r"}
		]
	},
	"ashe": {
		"name": "Skadi",
		"title": "The Winter Huntress",
		"icon": "🏹",
		"color": Color(0.624, 0.816, 1.0),
		"trim": Color(0.102, 0.290, 0.478),
		"accent": Color(0.267, 0.867, 1.0),
		"hp": 570.0, "hp_per_lv": 95.0, "hp_regen": 3.0, "hp_regen_per_lv": 0.4,
		"mp": 280.0, "mp_per_lv": 40.0, "mp_regen": 7.0, "mp_regen_per_lv": 0.4,
		"ad": 60.0, "ad_per_lv": 3.0,
		"atk_range": 380.0, "atk_spd": 0.66, "move_speed": 195.0,
		"auto_type": "ranged", "auto_color": Color(0.533, 0.867, 1.0),
		"priority": [3, 1, 0, 2],
		"skills": [
			{ "key":"Q", "name":"Ranger's Focus", "icon":"🏹", "cost":50, "cd":10.0, "max":5,
				"kind":"self", "range":0.0, "desc":"For 4s autos fire 3 arrows and gain attack speed.",
				"cast_id":"ashe_q" },
			{ "key":"W", "name":"Volley", "icon":"🎯", "cost":70, "cd":11.0, "max":5,
				"kind":"line", "range":450.0, "desc":"Fires 9 arrows in a cone. Each slows for 2s.",
				"cast_id":"ashe_w" },
			{ "key":"E", "name":"Hawkshot", "icon":"💨", "cost":50, "cd":14.0, "max":5,
				"kind":"point", "range":400.0, "desc":"Dash a short distance toward cursor.",
				"cast_id":"ashe_e" },
			{ "key":"R", "name":"Enchanted Crystal Arrow", "icon":"❄️", "cost":100, "cd":90.0, "max":3,
				"kind":"line", "range":2000.0, "desc":"Massive stun arrow. Travel = stun duration.",
				"cast_id":"ashe_r" }
		]
	},
	"annie": {
		"name": "Ember",
		"title": "The Cinder Caller",
		"icon": "🔥",
		"color": Color(1.0, 0.675, 0.522),
		"trim": Color(0.416, 0.082, 0.0),
		"accent": Color(1.0, 0.333, 0.0),
		"hp": 600.0, "hp_per_lv": 103.0, "hp_regen": 5.0, "hp_regen_per_lv": 0.5,
		"mp": 418.0, "mp_per_lv": 25.0, "mp_regen": 8.0, "mp_regen_per_lv": 0.8,
		"ad": 50.0, "ad_per_lv": 2.6,
		"atk_range": 350.0, "atk_spd": 0.58, "move_speed": 180.0,
		"auto_type": "ranged", "auto_color": Color(1.0, 0.333, 0.0),
		"priority": [3, 0, 1, 2],
		"skills": [
			{ "key":"Q", "name":"Disintegrate", "icon":"🔥", "cost":60, "cd":3.0, "max":5,
				"kind":"target", "range":450.0, "desc":"Fireball. Refunds mana on kill.",
				"cast_id":"annie_q" },
			{ "key":"W", "name":"Incinerate", "icon":"🌋", "cost":80, "cd":7.0, "max":5,
				"kind":"cone", "range":300.0, "desc":"Flame cone — damages everything in a wide arc.",
				"cast_id":"annie_w" },
			{ "key":"E", "name":"Molten Shield", "icon":"🛡️", "cost":30, "cd":10.0, "max":5,
				"kind":"self", "range":0.0, "desc":"3-second shield + reflect damage.",
				"cast_id":"annie_e" },
			{ "key":"R", "name":"Summon: Cinderbear", "icon":"🐻", "cost":100, "cd":90.0, "max":3,
				"kind":"point", "range":400.0, "desc":"AoE blast + summon Cinderbear for 45s.",
				"cast_id":"annie_r" }
		]
	},
	"garen": {
		"name": "Bastion",
		"title": "The Iron Vanguard",
		"icon": "⚔️",
		"color": Color(1.0, 0.914, 0.627),
		"trim": Color(0.353, 0.251, 0.0),
		"accent": Color(1.0, 0.667, 0.0),
		"hp": 690.0, "hp_per_lv": 114.0, "hp_regen": 8.0, "hp_regen_per_lv": 0.9,
		"mp": 0.0, "mp_per_lv": 0.0, "mp_regen": 0.0, "mp_regen_per_lv": 0.0,
		"ad": 69.0, "ad_per_lv": 4.5,
		"atk_range": 95.0, "atk_spd": 0.62, "move_speed": 205.0,
		"auto_type": "melee", "auto_color": Color.WHITE,
		"priority": [3, 2, 0, 1],
		"skills": [
			{ "key":"Q", "name":"Decisive Strike", "icon":"⚡", "cost":0, "cd":8.0, "max":5,
				"kind":"self", "range":0.0, "desc":"Burst of speed. Next attack silences and deals bonus damage.",
				"cast_id":"garen_q" },
			{ "key":"W", "name":"Courage", "icon":"🛡️", "cost":0, "cd":20.0, "max":5,
				"kind":"self", "range":0.0, "desc":"3-second shield + damage reduction.",
				"cast_id":"garen_w" },
			{ "key":"E", "name":"Judgment", "icon":"🌀", "cost":0, "cd":9.0, "max":5,
				"kind":"self", "range":0.0, "desc":"Spin for 3s dealing damage to nearby enemies.",
				"cast_id":"garen_e" },
			{ "key":"R", "name":"Demacian Justice", "icon":"⚔️", "cost":0, "cd":60.0, "max":3,
				"kind":"target", "range":180.0, "desc":"Execute: huge damage based on missing HP.",
				"cast_id":"garen_r" }
		]
	},
  "yasuo": {
    "name": "Kaze",
    "title": "The Wind Samurai · Yasuo",
    "role": "WIND • DASH • AIRBORNE",
    "icon": "",
    "color": Color("81d8ff"),
    "trim": Color("344054"),
    "accent": Color("81d8ff"),
    "hp": 620.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 0.0,
    "mp_per_lv": 0.0,
    "mp_regen": 0.0,
    "mp_regen_per_lv": 0.0,
    "ad": 66.0,
    "ad_per_lv": 3.5,
    "atk_range": 105.0,
    "atk_spd": 0.72,
    "move_speed": 205.0,
    "auto_type": "melee",
    "auto_color": Color("81d8ff"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Steel Tempest",
        "icon": "",
        "cost": 0,
        "cd": 3,
        "max": 5,
        "kind": "line",
        "range": 360.0,
        "desc": "Thrust a piercing wind blade. Every third thrust becomes a tornado that lifts enemies for 1.25s.",
        "cast_id": "yasuo_q"
      },
      {
        "key": "W",
        "name": "Windguard",
        "icon": "",
        "cost": 0,
        "cd": 14,
        "max": 5,
        "kind": "line",
        "range": 150.0,
        "desc": "Create a wind wall in front of you for 2.5s. Blocks enemy missiles except tower shots.",
        "cast_id": "yasuo_w"
      },
      {
        "key": "E",
        "name": "Sweeping Dash",
        "icon": "",
        "cost": 0,
        "cd": 5,
        "max": 5,
        "kind": "target",
        "range": 280.0,
        "desc": "Dash through a targeted enemy and slash them.",
        "cast_id": "yasuo_e"
      },
      {
        "key": "R",
        "name": "Skybreaker",
        "icon": "",
        "cost": 0,
        "cd": 35,
        "max": 3,
        "kind": "target",
        "range": 500.0,
        "desc": "Blink to a stunned enemy, strike nearby foes and extend the lift. Requires a stunned target.",
        "cast_id": "yasuo_r"
      }
    ]
  },
  "leesin": {
    "name": "Rokan",
    "title": "The Blind Monk · Lee Sin",
    "role": "SONIC • WARD • KICK",
    "icon": "",
    "color": Color("efbd63"),
    "trim": Color("344054"),
    "accent": Color("efbd63"),
    "hp": 650.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 0.0,
    "mp_per_lv": 0.0,
    "mp_regen": 0.0,
    "mp_regen_per_lv": 0.0,
    "ad": 65.0,
    "ad_per_lv": 3.5,
    "atk_range": 100.0,
    "atk_spd": 0.72,
    "move_speed": 210.0,
    "auto_type": "melee",
    "auto_color": Color("efbd63"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Sonic Strike",
        "icon": "",
        "cost": 30,
        "cd": 8,
        "max": 5,
        "kind": "line",
        "range": 650.0,
        "desc": "A sonic wave marks the first enemy. Press Q again within 4s to dash to the mark and deal missing-health damage.",
        "cast_id": "leesin_q"
      },
      {
        "key": "W",
        "name": "Safeguard",
        "icon": "",
        "cost": 40,
        "cd": 10,
        "max": 5,
        "kind": "point",
        "range": 400.0,
        "desc": "Dash to an allied hero or minion near your cursor, or protect yourself. Shield yourself and allied heroes; gain 20% lifesteal for 4s.",
        "cast_id": "leesin_w"
      },
      {
        "key": "E",
        "name": "Tempest",
        "icon": "",
        "cost": 35,
        "cd": 8,
        "max": 5,
        "kind": "self",
        "range": 0.0,
        "desc": "Slam the ground around you, damaging and slowing enemies for 2s.",
        "cast_id": "leesin_e"
      },
      {
        "key": "R",
        "name": "Dragon Kick",
        "icon": "",
        "cost": 70,
        "cd": 30,
        "max": 3,
        "kind": "target",
        "range": 210.0,
        "desc": "Kick an enemy away from you, stun them and send a shockwave through enemies behind them.",
        "cast_id": "leesin_r"
      }
    ]
  },
  "zed": {
    "name": "Shade",
    "title": "The Shadowblade · Zed",
    "role": "SHADOW • SWAP • ASSASSIN",
    "icon": "",
    "color": Color("b094ed"),
    "trim": Color("344054"),
    "accent": Color("b094ed"),
    "hp": 600.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 0.0,
    "mp_per_lv": 0.0,
    "mp_regen": 0.0,
    "mp_regen_per_lv": 0.0,
    "ad": 67.0,
    "ad_per_lv": 3.5,
    "atk_range": 105.0,
    "atk_spd": 0.72,
    "move_speed": 210.0,
    "auto_type": "melee",
    "auto_color": Color("b094ed"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Razor Shuriken",
        "icon": "",
        "cost": 30,
        "cd": 6,
        "max": 5,
        "kind": "line",
        "range": 600.0,
        "desc": "Throw a piercing shuriken. Your active shadow throws one too.",
        "cast_id": "zed_q"
      },
      {
        "key": "W",
        "name": "Living Shadow",
        "icon": "",
        "cost": 40,
        "cd": 12,
        "max": 5,
        "kind": "point",
        "range": 320.0,
        "desc": "Place a shadow at your cursor for 4s. Press W again to swap places with it.",
        "cast_id": "zed_w"
      },
      {
        "key": "E",
        "name": "Shadow Slash",
        "icon": "",
        "cost": 30,
        "cd": 7,
        "max": 5,
        "kind": "self",
        "range": 0.0,
        "desc": "Slash around you and your shadow, slowing nearby enemies.",
        "cast_id": "zed_e"
      },
      {
        "key": "R",
        "name": "Death Mark",
        "icon": "",
        "cost": 70,
        "cd": 35,
        "max": 3,
        "kind": "target",
        "range": 400.0,
        "desc": "Blink behind an enemy and mark them. After 3s, repeat 30% of your damage plus a finishing strike.",
        "cast_id": "zed_r"
      }
    ]
  },
  "jinx": {
    "name": "Rixa",
    "title": "The Loose Cannon · Jinx",
    "role": "ROCKETS • TRAPS • RANGE",
    "icon": "",
    "color": Color("79dfff"),
    "trim": Color("344054"),
    "accent": Color("79dfff"),
    "hp": 570.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 360.0,
    "mp_per_lv": 35.0,
    "mp_regen": 9.0,
    "mp_regen_per_lv": 0.5,
    "ad": 62.0,
    "ad_per_lv": 3.5,
    "atk_range": 390.0,
    "atk_spd": 0.72,
    "move_speed": 195.0,
    "auto_type": "ranged",
    "auto_color": Color("79dfff"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Rocket Party",
        "icon": "",
        "cost": 35,
        "cd": 7,
        "max": 5,
        "kind": "self",
        "range": 0.0,
        "desc": "For 6s gain 100 attack range and explosive attacks that splash nearby enemies.",
        "cast_id": "jinx_q"
      },
      {
        "key": "W",
        "name": "Zap!",
        "icon": "",
        "cost": 45,
        "cd": 7,
        "max": 5,
        "kind": "line",
        "range": 750.0,
        "desc": "Fire a long-range zap that damages and slows the first enemy by 50%.",
        "cast_id": "jinx_w"
      },
      {
        "key": "E",
        "name": "Flame Chompers",
        "icon": "",
        "cost": 60,
        "cd": 14,
        "max": 5,
        "kind": "point",
        "range": 460.0,
        "desc": "Place three traps for 3s. Each enemy takes damage and is stunned once per cast.",
        "cast_id": "jinx_e"
      },
      {
        "key": "R",
        "name": "Mega Rocket",
        "icon": "",
        "cost": 90,
        "cd": 40,
        "max": 3,
        "kind": "line",
        "range": 1400.0,
        "desc": "Launch a giant rocket. It hits the first enemy and splashes nearby enemies; the direct target is hit once.",
        "cast_id": "jinx_r"
      }
    ]
  },
  "katarina": {
    "name": "Scarlet",
    "title": "The Dagger Dancer · Katarina",
    "role": "DAGGERS • BLINK • STORM",
    "icon": "",
    "color": Color("ff789c"),
    "trim": Color("344054"),
    "accent": Color("ff789c"),
    "hp": 610.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 0.0,
    "mp_per_lv": 0.0,
    "mp_regen": 0.0,
    "mp_regen_per_lv": 0.0,
    "ad": 64.0,
    "ad_per_lv": 3.5,
    "atk_range": 105.0,
    "atk_spd": 0.72,
    "move_speed": 210.0,
    "auto_type": "melee",
    "auto_color": Color("ff789c"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Bouncing Blades",
        "icon": "",
        "cost": 0,
        "cd": 6,
        "max": 5,
        "kind": "target",
        "range": 500.0,
        "desc": "Hurl up to three homing daggers at enemies clustered near your target.",
        "cast_id": "katarina_q"
      },
      {
        "key": "W",
        "name": "Preparation",
        "icon": "",
        "cost": 0,
        "cd": 8,
        "max": 5,
        "kind": "self",
        "range": 0.0,
        "desc": "Spin your daggers around you and gain 30% speed for 2s.",
        "cast_id": "katarina_w"
      },
      {
        "key": "E",
        "name": "Shunpo",
        "icon": "",
        "cost": 0,
        "cd": 8,
        "max": 5,
        "kind": "target",
        "range": 380.0,
        "desc": "Blink beside an enemy or allied hero. An enemy takes slash damage.",
        "cast_id": "katarina_e"
      },
      {
        "key": "R",
        "name": "Death Lotus",
        "icon": "",
        "cost": 0,
        "cd": 35,
        "max": 3,
        "kind": "self",
        "range": 0.0,
        "desc": "Whirl a dagger storm for 2.5s, repeatedly damaging enemies within 140 units.",
        "cast_id": "katarina_r"
      }
    ]
  },
  "kayle": {
    "name": "Aurelia",
    "title": "The Ascended · Kayle",
    "role": "HEAL • ASCEND • PROTECT",
    "icon": "",
    "color": Color("ffe3a0"),
    "trim": Color("344054"),
    "accent": Color("ffe3a0"),
    "hp": 610.0,
    "hp_per_lv": 100.0,
    "hp_regen": 5.0,
    "hp_regen_per_lv": 0.5,
    "mp": 360.0,
    "mp_per_lv": 35.0,
    "mp_regen": 9.0,
    "mp_regen_per_lv": 0.5,
    "ad": 59.0,
    "ad_per_lv": 3.5,
    "atk_range": 110.0,
    "atk_spd": 0.72,
    "move_speed": 195.0,
    "auto_type": "melee",
    "auto_color": Color("ffe3a0"),
    "priority": [
      3,
      0,
      2,
      1
    ],
    "skills": [
      {
        "key": "Q",
        "name": "Radiant Judgment",
        "icon": "",
        "cost": 45,
        "cd": 8,
        "max": 5,
        "kind": "line",
        "range": 600.0,
        "desc": "Pierce enemies with radiant sword energy and slow them.",
        "cast_id": "kayle_q"
      },
      {
        "key": "W",
        "name": "Celestial Blessing",
        "icon": "",
        "cost": 55,
        "cd": 12,
        "max": 5,
        "kind": "point",
        "range": 400.0,
        "desc": "Heal yourself and a nearby ally and grant both 30% speed for 2s.",
        "cast_id": "kayle_w"
      },
      {
        "key": "E",
        "name": "Righteous Fire",
        "icon": "",
        "cost": 35,
        "cd": 8,
        "max": 5,
        "kind": "self",
        "range": 0.0,
        "desc": "Empower attacks with radiant damage for 5s. At level 6, permanently ascend to ranged attacks.",
        "cast_id": "kayle_e"
      },
      {
        "key": "R",
        "name": "Divine Intervention",
        "icon": "",
        "cost": 100,
        "cd": 45,
        "max": 3,
        "kind": "point",
        "range": 400.0,
        "desc": "Protect yourself or an ally near the cursor from damage for 2s, then erupt in a circle of swords.",
        "cast_id": "kayle_r"
      }
    ]
  }
}
