extends RefCounted
# Legacy damage payloads receive this hero's AP ratio in Main.deal_damage.
const LEGACY_AP_RATIOS = {"lux":0.6,"ahri":0.35,"annie":0.6,"katarina":0.15,"kayle":0.5,"ezreal":0.3}
static func legacy_ap_ratio(hero_key: String) -> float:
 return LEGACY_AP_RATIOS.get(hero_key,0.0)
# [base, base per rank, total AD ratio, AP ratio, label]
const VALUES = {
 "lux_q":[70,30,0,1,"Damage"],"lux_w":[60,35,0,0.5,"Shield per ally"],"lux_e":[65,35,0,1,"Damage"],"lux_r":[180,100,0,1,"Damage"],
 "ahri_q":[45,25,0,1,"Damage per pass"],"ahri_w":[35,15,0,1,"Damage per bolt (3 bolts)"],"ahri_e":[55,25,0,1,"Damage"],"ahri_r":[45,25,0,1,"Damage per bolt (3 bolts)"],
 "ezreal_q":[20,20,1.1,1,"Damage"],"ezreal_w":[60,30,0,0,"Mark bonus on next hit"],"ezreal_e":[50,30,0,1,"Bolt damage"],"ezreal_r":[150,100,0.8,1,"Damage"],
 "ashe_w":[20,20,0.6,1,"Damage per arrow (9 arrows)"],"ashe_r":[150,100,0.6,1,"Damage"],
 "annie_q":[60,25,0.3,1,"Damage"],"annie_w":[70,30,0.3,1,"Damage"],"annie_e":[50,30,0,0,"Shield"],"annie_r":[150,125,0.3,1,"Impact damage"],
 "garen_q":[30,25,0.4,0,"Bonus on next attack"],"garen_w":[60,40,0,0,"Shield"],"garen_e":[12,8,0.4,1,"Damage per 0.25s tick"],"garen_r":[150,150,0,0,"Base execute damage"],
 "yasuo_q":[45,25,0.6,1,"Damage"],"yasuo_e":[45,25,0.4,1,"Damage"],"yasuo_r":[150,100,0,1,"Damage"],
 "leesin_q":[55,30,0.6,1,"Q1 damage"],"leesin_q2":[70,35,0,1,"Q2 base damage"],"leesin_w":[70,35,0,0,"Shield"],"leesin_e":[50,30,0,1,"Damage"],"leesin_r":[150,100,0.8,1,"Kick damage"],
 "zed_q":[40,25,0.65,1,"Damage per shuriken"],"zed_e":[40,30,0,1,"Damage per slash"],"zed_r":[90,80,0,0,"Base mark detonation"],
 "jinx_w":[40,30,0.8,1,"Damage"],"jinx_e":[35,25,0,1,"Damage per trap"],"jinx_r":[150,100,0.6,1,"Direct hit damage"],
 "katarina_q":[40,25,0,1,"Damage per dagger"],"katarina_w":[35,25,0,1,"Damage"],"katarina_e":[45,30,0,1,"Enemy blink damage"],"katarina_r":[30,20,0,1,"Damage per 0.25s tick"],
 "kayle_q":[45,30,0,1,"Damage"],"kayle_w":[90,45,0,0,"Heal per ally"],"kayle_e":[25,15,0,0,"Bonus per attack"],"kayle_r":[120,80,0,1,"Sword eruption damage"]}
static func ap_ratio(id: String) -> float:
 var formula=VALUES[id]
 # Shields already calculate their own coefficient; damage flows through Main.
 return legacy_ap_ratio(id.get_slice("_",0)) if formula[3]==1 else formula[3]
static func value(id: String, rank: int, ad: float, ap: float) -> float:
 var formula = VALUES[id]
 return formula[0]+formula[1]*rank+formula[2]*ad+ap_ratio(id)*ap
static func _line(id: String, rank: int, c) -> String:
 var f = VALUES[id]
 var ratio = ap_ratio(id)
 var ad = c.ad if c != null else 0.0
 var ap = c.bonus_ap if c != null else 0.0
 var base = f[0]+f[1]*rank
 var amount = value(id,rank,ad,ap)
 var formula = "%.0f base" % base
 if f[2]>0: formula += " + %.0f%% AD (%.1f)" % [f[2]*100,f[2]*ad]
 if ratio>0: formula += " + %.0f%% AP (%.1f)" % [ratio*100,ratio*ap]
 var result = "%s: %.1f\n%s" % [f[4],amount,formula]
 if f[2]==0 and ratio==0: result += " • no AD/AP scaling"
 return result
static func description(id: String, rank: int, c = null) -> String:
 var preview = rank<=0
 rank = maxi(1,rank)
 var lines = []
 if VALUES.has(id): lines.append(_line(id,rank,c))
 match id:
  "ashe_q":
   lines.append("3 arrows per attack: %.0f%% total AD (%.1f total before on-hit effects)." % [(1.05+.05*rank)*100,c.ad*(1.05+.05*rank) if c != null else 0])
   lines.append("Attack speed ×1.4 for 4s. No AP scaling.")
  "ashe_e": lines.append("Movement only • no damage or AD/AP scaling.")
  "yasuo_w": lines.append("Blocks enemy projectiles for 2.5s. No damage or AD/AP scaling.")
  "zed_w": lines.append("Shadow duplicates Q and E at their displayed damage. No direct damage or independent AD/AP scaling.")
  "jinx_q": lines.append("Attacks splash for 35% of the raw attack damage. Each target applies its own armor; no AP scaling.")
  "ahri_q": lines.append("Two passes: %.1f if both connect." % (value(id,rank,c.ad,c.bonus_ap)*2 if c != null else value(id,rank,0,0)*2))
  "ahri_w","ahri_r": lines.append("Three bolts: %.1f if all connect." % (value(id,rank,c.ad,c.bonus_ap)*3 if c != null else value(id,rank,0,0)*3))
  "leesin_q":
   lines.append(_line("leesin_q2",rank,c))
   lines.append("Q2 also adds 10% of target missing HP, capped at 150.")
  "leesin_r": lines.append("Knockback projectile: %.1f (%.0f base; no AP scaling)." % [80+60*rank,80+60*rank])
  "zed_r": lines.append("Also adds 30% of damage stored during its 3s mark. Armor reduces detonation damage.")
  "garen_r": lines.append("Also adds %d%% of target missing HP. Execute ignores armor." % int((0.2+0.05*rank)*100))
  "garen_q": lines.append("Total empowered auto: %.1f before crit/item effects." % (c.ad+value(id,rank,c.ad,c.bonus_ap) if c != null else value(id,rank,0,0)))
  "garen_w": lines.append("Damage reduction: %d%% for 3s." % int((0.3+0.03*rank)*100))
  "garen_e": lines.append("Up to 12 ticks over 3s; each tick gains the displayed AD/AP scaling.")
  "katarina_r": lines.append("Up to 10 ticks over 2.5s; each tick gains the displayed AP scaling.")
  "annie_e": lines.append("Reflect: %.0f per enemy auto • no AD/AP scaling." % (20+10*rank))
  "annie_r": lines.append("Also summons a bear; its attacks deal %d before armor." % 60)
  "leesin_w": lines.append("Also grants 20% lifesteal for 4s.")
  "jinx_e": lines.append("Each target can be damaged and stunned once per trap cast.")
  "jinx_r": lines.append("Nearby-target explosion: %.1f (65%% of base + AD hit; no AP scaling). The direct target is excluded." % ((150+100*rank+(c.ad*0.6 if c != null else 0))*0.65))
  "kayle_e": lines.append("Total empowered auto: %.1f before crit/item effects." % (c.ad+value(id,rank,c.ad,c.bonus_ap) if c != null else value(id,rank,0,0)))
 if preview: lines.push_front("Rank 1 preview • skill not learned")
 if c != null: lines.append("Current stats: %.1f total AD • %.1f AP" % [c.ad,c.bonus_ap])
 lines.append("Damage is before armor, magic resistance and target reductions; conditional item procs are extra.")
 return "\n".join(lines)

static func damage_type(id: String) -> String:
 if id in ["ezreal_q","ashe_w","garen_e","yasuo_q","yasuo_r","leesin_q","leesin_q2","leesin_r","zed_q","zed_e","zed_r","jinx_w","jinx_r"]:return "physical"
 return "magic"
