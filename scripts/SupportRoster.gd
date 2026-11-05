class_name SupportRoster
extends RefCounted
const KEYS=["soraka","janna"]
const PASSIVES={"soraka":["Salvation","Gain 35% movement speed toward an allied hero below 40% health within 700. Starfall hits on heroes grant Rejuvenation: healing over 3 seconds and cheaper health costs for W."],"janna":["Tailwind","Allies within 250 gain 5% movement speed while you are alive. While W is ready, gain another 8% movement speed. Charging Q changes its range, damage and knock-up duration."]}
const KITS={
 "soraka":[["Starfall","After 0.4s, a star hits a 105-unit area, slowing 30% for 2s. Hero hits grant Rejuvenation.","point",480,45,6],["Astral Mend","Heal an allied hero. Costs 8% maximum health; Rejuvenation halves this health cost. Cannot target yourself or cast below the health cost.","ally",370,50,5],["Equinox","Silence enemies while they stand inside a 120-unit field for 1.5s. Enemies still inside when it expires are rooted for 1s.","point",490,60,14],["Celestial Wish","Heal all living allied heroes. Healing increases by 35% on allies below 40% health.","self",0,100,55]],
 "janna":[["Howling Gale","Charge a tornado for up to 3s; press Q again to release early. It pierces, damages and knocks up. Range, damage and knock-up increase with charge.","line",700,55,11],["Zephyr Feather","A targeted wind bolt damages and slows an enemy for 2s. While ready, grants 8% movement speed.","target",390,45,8],["Eye of the Storm","Shield yourself or an allied hero for 4s. While the shield remains, grant bonus attack damage.","ally",400,55,10],["Monsoon","Push nearby enemies away, then channel healing for nearby allies over 3s. Moving, recasting R, silence or stun cancels the channel.","self",0,100,50]]}
static func heroes() -> Dictionary:
 var result={}
 for key in KEYS:
  var h=ChampionData.CHAMPIONS.lux.duplicate(true)
  h.name="Seren" if key=="soraka" else "Galea";h.title="Celestial Mender" if key=="soraka" else "Wind Guardian";h.role="SUPPORT • HEAL • SILENCE" if key=="soraka" else "SUPPORT • SHIELD • DISENGAGE"
  h.color=Color("91e7ae" if key=="soraka" else "8bdeed");h.accent=h.color;h.trim=Color("223e50")
  h.hp=550.;h.hp_per_lv=85.;h.ad=49.;h.ad_per_lv=2.5;h.mp=470.;h.atk_range=320.;h.move_speed=195.;h.auto_color=h.accent;h.priority=[0,2,1,3];h.skills=[]
  for i in range(4):
   var a=KITS[key][i]
   h.skills.append({"key":["Q","W","E","R"][i],"name":a[0],"desc":a[1],"kind":a[2],"range":float(a[3]),"cost":a[4],"cd":float(a[5]),"max":3 if i==3 else 5,"cast_id":key+"_"+["q","w","e","r"][i],"icon":""})
  result[key]=h
 return result
