class_name RosterExpansion12
extends RefCounted
# Original identities; recognizable MOBA mechanics adapted to this ARAM's scale.
const KEYS=["leona","blitzcrank","renekton","xinzhao","riven","fiora","caitlyn","lucian","sivir","brand","syndra","xerath"]
const SPECS=[
 ["Aegis","Solar Vanguard","tank","f2cc75",710,59,95,190,360],
 ["Bolt","Steam Sentinel","tank","70dfef",720,62,95,185,360],
 ["Saur","Crescent Tyrant","bruiser","dd8866",680,68,105,195,0],
 ["Lancer","Spear of Dawn","bruiser","d7a7b5",650,66,110,200,330],
 ["Riftblade","Runebroken Exile","bruiser","82e9b5",630,65,100,205,0],
 ["Duelia","Fourfold Duelist","bruiser","b9c7fb",625,67,100,205,320],
 ["Caliber","Longshot Marshal","marksman","d7b8f2",570,60,405,190,340],
 ["Solstice","Twinlight Hunter","marksman","f6dfa7",590,62,335,205,340],
 ["Zephyr","Crossblade Captain","marksman","82d6ce",600,60,340,205,350],
 ["Pyre","Living Inferno","caster","ffa464",565,52,345,190,440],
 ["Umbra","Gravity Sovereign","caster","c09bff",565,52,350,190,460],
 ["Arclight","Arcane Ascendant","caster","86dfff",550,50,345,185,480]]
const KITS={
 "leona":[["Dawn Bash","Next attack adds magic damage and stuns for 1 second. Allied hits consume your Sunlight marks.","self",0,35,6],["Solar Bulwark","Reduce damage by 30% for 3 seconds, then explode. Hitting an enemy extends protection by 2 seconds.","self",0,55,12],["Zenith Reach","Pierce minions with your blade. Root the last enemy champion struck, then dash to them.","line",510,60,11],["Sunfall","After 0.65 seconds, sunlight strikes a circle. Center stuns for 1.5 seconds; outer rim slows 70%.","point",650,100,45]],
 "blitzcrank":[["Rocket Fist","Hook the first enemy and pull them to you. Cannot hook structures.","line",600,70,13],["Steam Overdrive","Gain 40% movement and attack speed for 4 seconds, then slow yourself 30% for 1 second.","self",0,50,13],["Hydraulic Uppercut","Reset attack timer. Next attack deals bonus physical damage and knocks up for 1 second.","self",0,30,7],["Static Nova","Remove nearby shields, deal magic damage and silence for 1.2 seconds. Attacks with R learned leave delayed lightning.","self",0,100,45]],
 "renekton":[["Crescent Cull","Circular physical sweep heals per enemy (more for heroes). 50 Fury empowers damage and healing.","self",0,0,8],["Ruthless Jaws","Next attack stuns. 50 Fury increases damage, breaks shields and doubles stun duration.","self",0,0,10],["Slice / Dice","Dash through enemies. If it hits, recast within 4 seconds. Empowered second dash shreds armor.","point",240,0,12],["Dominion","For 8 seconds gain temporary health, Fury over time and a damaging aura. Basic attacks generate Fury.","self",0,0,50]],
 "xinzhao":[["Threefold Spear","Empower the next three attacks. The third knocks up; each hit reduces basic skill cooldowns.","self",0,30,8],["Wind / Thunder","A sweep followed by a piercing spear thrust. Slows enemies and challenges the target.","line",470,50,10],["Audacious Charge","Dash to an enemy, splash magic damage and gain 40% attack speed for 4 seconds.","target",360,50,11],["Crescent Guard","Sweep nearby enemies away except your challenged target. For 3 seconds, ignore damage from enemies farther than 220 units.","self",0,100,45]],
 "riven":[["Broken Arc","Three short dashes with cleaves. Recast within 4 seconds; the third knocks up. Abilities charge rune attacks.","point",150,0,9],["Rune Burst","A close burst of physical damage stuns for 0.75 seconds.","self",0,0,10],["Valor","Dash and gain a 2-second shield.","point",190,0,10],["Exile / Wind Slash","Gain 20% AD and 40 attack range for 8 seconds. Recast to fire a crescent that deals up to 3x damage to wounded enemies.","line",650,0,45]],
 "fiora":[["Lunge","Dash and strike a nearby enemy. Hitting refunds 40% cooldown. Hit a hero's marked side for true damage and healing.","point",190,30,7],["Riposte","Parry damage and crowd control for 0.75 seconds, then stab forward. Slow on hit; stuns if you parried a disabling attack.","line",360,50,13],["Bladework","Two fast attacks: first slows, second deals guaranteed 160% physical damage.","self",0,35,10],["Grand Challenge","Reveal four directional vitals on a hero for 8 seconds. Hit all four, or kill after hitting one, to create an allied healing field.","target",410,100,45]],
 "caitlyn":[["Piltover Line","Fire a long piercing rifle shot; damage after the first enemy is reduced to 65%.","line",720,50,7],["Snap Trap","Place a trap that arms after 0.6 seconds and lasts 12 seconds. Enemy heroes trigger a root and a bonus headshot.","point",420,30,9],["Recoil Net","Fire a slowing net and dash backward. Hitting grants a bonus headshot on that target.","line",470,60,11],["Deadeye","Lock onto a hero, aim for 1 second, then fire a powerful bullet. Enemy heroes can intercept it; moving or being stunned cancels aiming.","target",900,100,45]],
 "lucian":[["Piercing Light","Target an enemy and fire through them in a straight line. Skills prime a second basic-attack shot.","target",440,45,7],["Radiant Mark","A missile bursts and marks enemies for 4 seconds. Hitting marked enemies grants haste.","line",610,50,10],["Relentless Dash","Dash toward the cursor. Passive second shots reduce this cooldown.","point",220,35,10],["The Culling","Channel 18 piercing pistol shots along the chosen direction for 2.4 seconds. You can move; stun cancels the channel.","line",720,100,45]],
 "sivir":[["Boomerang Blade","Crossblade pierces out and returns, damaging once on each leg.","line",650,50,8],["Ricochet","Next three attacks bounce to up to three nearby enemies at 45% damage. Bounces cannot bounce again.","self",0,45,10],["Spell Ward","Block one enemy spell in 2 seconds and restore 60 mana.","self",0,35,14],["On the Hunt","Nearby allies gain 30% movement speed for 6 seconds.","self",0,100,45]],
 "brand":[["Sear","Fire bolt. Stuns targets already burning for 1.5 seconds. Spells apply Blaze; three stacks detonate after 1 second.","line",600,45,7],["Flame Pillar","After 0.7 seconds, erupt in an area. Deals 25% more damage to burning targets.","point",520,60,9],["Conflagration","Ignite a target and spread to nearby enemies. Spread radius doubles if target was burning.","target",400,60,11],["Pyroclasm","Launch a fire orb that bounces up to five hits, preferring heroes. Each impact applies Blaze; repeat hits are possible.","target",500,100,45]],
 "syndra":[["Dark Sphere","Damage an area and leave a gravity sphere for 6 seconds. Spheres fuel E and R.","point",490,40,6],["Force of Will","Pick up a nearby sphere or enemy minion. Recast within 4 seconds to throw it at an area; slows on impact.","point",490,50,10],["Scatter the Weak","Push enemies in a cone. Existing spheres launch forward and stun targets they hit.","line",360,60,13],["Unleashed Power","Target a hero with three spheres plus up to four nearby grounded spheres. Consumes those spheres; damage scales per orb.","target",500,100,45]],
 "xerath":[["Arcanopulse","Charge for up to 1.5 seconds (slowed while charging); press Q again to release a piercing beam. Range grows from 350 to 750.","line",750,50,7],["Eye of Destruction","After 0.6 seconds, strike a circle. Center deals 50% extra damage and slows 60%; outer area slows 25%.","point",610,60,9],["Shocking Orb","Orb stuns from 0.5 to 1.8 seconds depending on distance traveled.","line",650,55,11],["Arcane Barrage","Root yourself for up to 8 seconds. Press R three more times for delayed artillery blasts. Stun cancels. Attacks periodically restore mana.","point",1000,100,50]]}
static func heroes() -> Dictionary:
 var result={}
 for n in range(KEYS.size()):
  var key=KEYS[n];var s=SPECS[n];var role=s[2]
  var h=ChampionData.CHAMPIONS["garen" if role in ["tank","bruiser"] else "ashe" if role=="marksman" else "lux"].duplicate(true)
  h.name=s[0];h.title=s[1];h.role=role.to_upper();h.color=Color(s[3]);h.accent=h.color;h.trim=Color("192639")
  h.hp=float(s[4]);h.ad=float(s[5]);h.atk_range=float(s[6]);h.move_speed=float(s[7]);h.mp=float(s[8]);h.mp_regen=7. if h.mp>0 else 0.;h.mp_per_lv=45. if h.mp>0 else 0.;h.mp_regen_per_lv=.5 if h.mp>0 else 0.
  h.mr=38. if role in ["tank","bruiser"] else 30.;h.auto_type="melee" if role in ["tank","bruiser"] else "ranged";h.auto_color=h.accent;h.priority=[2,0,1,3];h.skills=[]
  for i in range(4):
   var a=KITS[key][i]
   h.skills.append({"key":["Q","W","E","R"][i],"name":a[0],"desc":a[1],"kind":a[2],"range":float(a[3]),"cost":a[4],"cd":float(a[5]),"max":3 if i==3 else 5,"cast_id":key+"_"+["q","w","e","r"][i],"icon":""})
  result[key]=h
 return result
static func role(key: String) -> String:
 return SPECS[KEYS.find(key)][2] if key in KEYS else "caster"
static func builds() -> Dictionary:
 var result={}
 for key in KEYS:
  match role(key):
   "tank":result[key]=["ruby_crystal","boots","plated_steelcaps","sunfire","frozen_heart","thornmail","spirit_visage","warmog"]
   "bruiser":result[key]=["long_sword","boots","plated_steelcaps","black_cleaver","sterak","deaths_dance","spirit_visage","bloodthirster"]
   "marksman":result[key]=["long_sword","boots","berserker_greaves","infinity_edge","phantom_dancer","lord_dominik","bloodthirster"]
   _:result[key]=["amp_tome","boots","sorcerer_shoes","ludens","liandry","rabadon","void_staff","banshee"]
 return result
