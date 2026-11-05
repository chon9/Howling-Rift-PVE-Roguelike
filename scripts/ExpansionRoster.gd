class_name ExpansionRoster
extends RefCounted
const KEYS=["darius","malphite","veigar","morgana","vayne","thresh"]
static func heroes() -> Dictionary:
 var result={}
 var specs=[
 ["darius","Rook","The Crimson Marshal","BRUISER • PULL • EXECUTE","b44839","garen",690,68,95,190],
 ["malphite","Granite","The Living Bastion","TANK • SLOW • ENGAGE","78c9d8","garen",720,62,90,180],
 ["veigar","Vexel","The Starless Arcanist","MAGE • CAGE • EXECUTE","b97aff","lux",550,52,330,185],
 ["morgana","Noctra","The Twilight Binder","MAGE • ROOT • SHIELD","d078d9","lux",600,54,340,190],
 ["vayne","Vesper","The Silver Pursuer","MARKSMAN • TUMBLE • TRUE DAMAGE","e48797","ashe",570,62,355,205],
 ["thresh","Warden","The Chain Keeper","SUPPORT • HOOK • LANTERN","65d39c","lux",660,56,250,185]]
 var kits={
 "darius":[["Blood Sweep","Sweep the axe around you. Hitting a champion heals 8% max HP.","self",0,45,8],["Crushing Edge","Empower the next attack with bonus damage and a 45% slow.","self",0,30,7],["Apprehend","Hook nearby enemies in a cone and pull them toward you.","line",220,60,15],["Crimson Verdict","Execute an enemy for true damage, increased 20% per bleed stack. A killing blow resets R.","target",220,100,45]],
 "malphite":[["Seismic Shard","Homing stone slows its target by 35%.","target",430,55,8],["Stoneplate","Gain a shield and 25% damage reduction for three seconds.","self",0,45,12],["Ground Slam","Slam the ground, damaging and slowing enemies.","self",0,60,10],["Unstoppable Charge","Charge to the cursor, damaging and stunning enemies on arrival.","point",460,100,55]],
 "veigar":[["Dark Matter Bolt","A dark bolt pierces two targets. Q last hits grant AP; spell hits on heroes and takedowns also grant match AP.","line",580,40,6],["Falling Star","Mark a location; after one second a meteor hits the area.","point",500,65,9],["Event Horizon","After 0.5 seconds, form a cage for three seconds. Crossing its rim stuns; the center is safe.","point",430,70,16],["Primordial Burst","Homing dark orb gains up to 100% extra damage against a low-health target.","target",430,100,50]],
 "morgana":[["Twilight Binding","A dark projectile binds the first enemy for 1.8 seconds.","line",600,50,10],["Tormented Ground","Corrupt a patch of ground for four seconds, damaging enemies every second.","point",500,60,12],["Black Ward","Shield yourself or an allied champion and resist crowd control for 2.5 seconds.","point",400,60,14],["Soul Chains","Damage nearby enemies, then damage and stun those still nearby after 1.5 seconds.","self",0,100,50]],
 "vayne":[["Tumble","Roll toward the cursor and empower the next basic attack.","point",190,30,5],["Silver Bolts","For five seconds, every third attack on the same target deals true damage.","self",0,35,10],["Condemn","Knock an enemy backward. Hitting the lane boundary also stuns them.","target",380,60,13],["Final Hunt","Gain attack damage and movement speed for six seconds.","self",0,80,45]],
 "thresh":[["Death Hook","Hook and drag the first enemy. Press Q again within 1.5 seconds to dash to them.","line",550,60,12],["Soul Lantern","Throw a lantern that shields nearby allies. Allies right-click it to dash to you.","point",400,50,12],["Flay","Sweep both sides with your chain. Aim away to push, behind you to pull. Slows for 1.5 seconds. Waiting charges bonus magic damage on your next attack.","line",220,50,9],["The Prison","Raise five breakable walls for five seconds. First wall deals damage and slows 99% for two seconds; later walls only slow.","self",0,100,55]]}
 for spec in specs:
  var key=spec[0];var data=ChampionData.CHAMPIONS[spec[5]].duplicate(true)
  data.name=spec[1];data.title=spec[2]+" • "+{"darius":"Darius","malphite":"Malphite","veigar":"Veigar","morgana":"Morgana","vayne":"Vayne","thresh":"Thresh"}[key];data.role=spec[3];data.color=Color(spec[4]);data.accent=Color(spec[4]);data.trim=Color("192639")
  data.hp=float(spec[6]);data.ad=float(spec[7]);data.atk_range=float(spec[8]);data.move_speed=float(spec[9]);data.auto_type="melee" if key in ["darius","malphite"] else "ranged"
  # Each kit owns its resource stats; do not inherit Garen's zero-mana pool.
  var resources={"darius":[340.,45.,6.5,.5],"malphite":[360.,50.,7.,.55],"veigar":[420.,50.,8.,.6],"morgana":[400.,45.,8.,.6],"vayne":[300.,35.,6.,.45],"thresh":[380.,45.,7.,.55]}
  var resource=resources[key]
  data.mp=resource[0];data.mp_per_lv=resource[1];data.mp_regen=resource[2];data.mp_regen_per_lv=resource[3]
  data.mr=42. if key=="malphite" else 38. if key in ["darius","thresh"] else 30.
  data.auto_color=data.accent;data.priority=[2,0,3,1];data.skills=[]
  for i in range(4):
   var s=kits[key][i]
   data.skills.append({"key":["Q","W","E","R"][i],"name":s[0],"desc":s[1],"kind":s[2],"range":float(s[3]),"cost":s[4],"cd":float(s[5]),"max":3 if i==3 else 5,"cast_id":key+"_"+["q","w","e","r"][i],"icon":""})
  if key=="vayne":data.skills[1].kind="passive";data.skills[1].cost=0;data.skills[1].cd=0.;data.skills[1].desc="Always active once learned. Consecutive attacks and Condemn against the same target proc true damage every third hit. Changing target resets stacks."
  result[key]=data
 return result
