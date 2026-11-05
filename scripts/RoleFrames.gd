class_name RoleFrames
extends RefCounted
## Why each role is worth picking. Range is the strongest stat in a MOBA, so ranged heroes pay for it with a thin body,
## and melee heroes get the toughness, speed and sticking power to reach them. Tanks turn their health into damage and
## protect the team around them. HERO_MODS are small per-hero damage modifiers for outliers, the way ARAM balances.

const FRAMES := {
	"tank": {"armor": 40.0, "armor_lv": 5.0, "mr": 8.0, "mr_lv": 1.25, "hp": 1.2, "dealt": 1.0},
	"bruiser": {"armor": 30.0, "armor_lv": 3.8, "mr": 3.0, "mr_lv": 0.5, "hp": 1.1, "dealt": 1.12},
	"support": {"armor": 20.0, "armor_lv": 3.0, "mr": 0.0, "mr_lv": 0.0, "hp": 1.0, "dealt": 1.0},
	"caster": {"armor": 18.0, "armor_lv": 2.5, "mr": 0.0, "mr_lv": 0.0, "hp": 0.95, "dealt": 1.0},
	"marksman": {"armor": 16.0, "armor_lv": 2.6, "mr": 0.0, "mr_lv": 0.0, "hp": 0.92, "dealt": 0.88},
}
const NEUTRAL := {"armor": 0.0, "armor_lv": 0.0, "mr": 0.0, "mr_lv": 0.0, "hp": 1.0, "dealt": 1.0}
const MELEE_SPEED := 18.0         # melee heroes outrun the ranged heroes they have to catch
const MELEE_STICK := 0.15         # melee attacks on heroes slow by this much...
const MELEE_STICK_TIME := 1.2     # ...for this long, so they cannot simply be walked away from
const TANK_HIT_HP := 0.02         # tank hits deal this share of its max health as extra damage
const GUARD_RANGE := 320.0        # allies this close to a tank...
const GUARD_TAKEN := 0.9          # ...take this share of damage
const HERO_MODS := {"jinx": {"dealt": 0.9}}   # hero key: {"dealt": x, "taken": y}

## Tests that pin exact formula numbers switch the frames off.
static var enabled := true


static func role_of(hero_key: String) -> String:
	if hero_key in SupportRoster.KEYS:
		return "support"
	if hero_key in RosterExpansion12.KEYS:
		return RosterExpansion12.role(hero_key)
	if hero_key in ["garen", "malphite", "thresh"]:
		return "tank"
	if hero_key in ["darius", "leesin", "yasuo", "zed"]:
		return "bruiser"
	if hero_key in ["ashe", "jinx", "vayne", "kayle"]:
		return "marksman"
	return "caster"


static func frame(hero_key: String) -> Dictionary:
	return FRAMES.get(role_of(hero_key), NEUTRAL) if enabled else NEUTRAL


static func speed_bonus(c) -> float:
	return MELEE_SPEED if enabled and c.auto_type == "melee" else 0.0


## Damage a hero deals to an enemy hero, before armor.
static func dealt(src, target, dmg: float, dmg_type: String) -> float:
	if not enabled or src.team == target.team:
		return dmg
	if role_of(src.hero_key) == "tank" and dmg_type in ["auto", "secondary_auto", "skill", "magic", "physical"] and dmg > 0.0:
		dmg += src.hp_max * TANK_HIT_HP
	return dmg * float(frame(src.hero_key).dealt) * float(HERO_MODS.get(src.hero_key, {}).get("dealt", 1.0))


## Share of incoming damage a hero takes.
static func taken(target) -> float:
	if not enabled:
		return 1.0
	var mult := float(HERO_MODS.get(target.hero_key, {}).get("taken", 1.0))
	for ally in GameState.champions:
		if ally != target and ally.team == target.team and not ally.dead and ally.roster_active and role_of(ally.hero_key) == "tank" \
				and ally.global_position.distance_squared_to(target.global_position) <= GUARD_RANGE * GUARD_RANGE:
			return mult * GUARD_TAKEN
	return mult


## A melee attack that lands on an enemy hero.
static func on_hit(src, target, dmg_type: String) -> void:
	if not enabled or src.auto_type != "melee" or dmg_type not in ["auto", "secondary_auto"] or src.team == target.team:
		return
	if target.buffs.has("cc_guard") or target.buffs.has("spell_guard"):
		return
	var slow = target.buffs.get("slow")
	if slow == null or float(slow.pct) <= MELEE_STICK:
		target.buffs["slow"] = {"time": MELEE_STICK_TIME, "pct": MELEE_STICK}
