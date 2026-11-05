class_name VfxRegistry
extends RefCounted
## Classifies world_root nodes into presentation policies and creates their 3D views (W2-VFX; plan 4.5).
## Unregistered FX stay FLAT: they keep drawing on the ground overlay and never vanish.
##
## HIDE / VIEW: View3D sets node.visible = false (stateless FX only). FLAT / BOTH leave the node visible.
## create_view returns an already-bound view parented under host.add_fx (View3D.register never binds FX views);
## View3D then syncs it every frame and disposes it after the source's tree_exiting.

enum Policy { FLAT, HIDE, VIEW, BOTH }

const SCRIPT_CHAMPION := "res://scripts/Champion.gd"
const SCRIPT_MINION := "res://scripts/Minion.gd"
const SCRIPT_STRUCTURE := "res://scripts/Structure.gd"
const SCRIPT_CORPSE := "res://scripts/AnimatedCorpse.gd"
const SCRIPT_FLOATING_TEXT := "res://scripts/FloatingText.gd"
const SCRIPT_MAP := "res://scripts/MapRenderer.gd"
const SCRIPT_SKILL_AIMER := "res://scripts/SkillAimer.gd"
const SCRIPT_PROJECTILE := "res://scripts/Projectile.gd"
const SCRIPT_BEAM := "res://scripts/Beam.gd"
const SCRIPT_AOE := "res://scripts/AoE.gd"
const SCRIPT_SPELL_BURST := "res://scripts/SpellBurst.gd"
const SCRIPT_WIND_BURST := "res://scripts/WindBurst.gd"
const SCRIPT_HERO_IMPACT := "res://scripts/HeroImpact.gd"
const SCRIPT_MINION_HIT := "res://scripts/MinionHit.gd"
const SCRIPT_MELEE_STRIKE := "res://scripts/MeleeStrike.gd"

## Keyed by script resource_path and by inner-class fx_kind (Main.gd inner FX classes). Units, corpses,
## floating text and the map renderer are handled by View3D itself; their entries document the same policy.
## AoE is BOTH only when ZoneProp3D.wants(aoe), otherwise FLAT (see classify).
const POLICY_TABLE := {
	SCRIPT_CHAMPION: Policy.VIEW,
	SCRIPT_MINION: Policy.VIEW,
	SCRIPT_STRUCTURE: Policy.VIEW,
	SCRIPT_CORPSE: Policy.HIDE,
	SCRIPT_FLOATING_TEXT: Policy.HIDE,
	SCRIPT_MAP: Policy.HIDE,
	SCRIPT_SKILL_AIMER: Policy.FLAT,
	SCRIPT_PROJECTILE: Policy.VIEW,
	SCRIPT_BEAM: Policy.VIEW,      # BeamView3D draws both the raised laser and a thin ground rim (no 2D strip)
	SCRIPT_AOE: Policy.BOTH,
	SCRIPT_SPELL_BURST: Policy.VIEW,
	SCRIPT_WIND_BURST: Policy.VIEW,
	SCRIPT_HERO_IMPACT: Policy.VIEW,
	SCRIPT_MINION_HIT: Policy.VIEW,
	SCRIPT_MELEE_STRIKE: Policy.FLAT,
	"impact": Policy.VIEW,
	"burst_particle": Policy.VIEW,
	"puff": Policy.FLAT,
	"target_ring": Policy.FLAT,
	"levelup_ring": Policy.FLAT,
	"flash": Policy.FLAT,
	"reticles": Policy.FLAT,
}

## Table key -> FxCard3D kind for the card-backed entries.
const CARD_KINDS := {
	SCRIPT_SPELL_BURST: "spell_burst",
	SCRIPT_WIND_BURST: "wind_burst",
	SCRIPT_HERO_IMPACT: "hero_impact",
	SCRIPT_MINION_HIT: "minion_hit",
	"impact": "impact",
}


## Policy for a node: the table value for its fx_kind or script (walking base scripts); FLAT when unknown.
static func classify(node: Node) -> int:
	var key := policy_key(node)
	if key == "":
		return Policy.FLAT
	if key == SCRIPT_AOE:
		return Policy.BOTH if ZoneProp3D.wants(node as Node2D) else Policy.FLAT
	return int(POLICY_TABLE[key])


## True when the node has an explicit table entry (coverage guard: unknown nodes fall back to FLAT).
static func is_known(node: Node) -> bool:
	return policy_key(node) != ""


## The POLICY_TABLE key that applies to a node: its inner-class fx_kind first, then its script path chain.
static func policy_key(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if "fx_kind" in node:
		var k := str(node.get("fx_kind"))
		if POLICY_TABLE.has(k):
			return k
	var s: Script = node.get_script() as Script
	while s != null:
		var path := s.resource_path
		if POLICY_TABLE.has(path):
			return path
		s = s.get_base_script()
	return ""


## Creates, parents (host.add_fx) and binds the 3D view for a VIEW / BOTH node; null when none applies.
static func create_view(node: Node, host: Node3D) -> Node3D:
	if node == null or not is_instance_valid(node) or host == null or not is_instance_valid(host):
		return null
	var key := policy_key(node)
	if key == "":
		return null
	if CARD_KINDS.has(key):
		var card := FxCard3D.new()
		host.add_fx(card)
		card.bind(node, host, String(CARD_KINDS[key]))
		card.sync(0.0)
		return card
	if key == "burst_particle":
		return FxBurst3D.batch(node, host)
	if key == SCRIPT_PROJECTILE:
		var pv := ProjectileView3D.new()
		host.add_fx(pv)
		pv.bind(node as Node2D, host)
		return pv
	if key == SCRIPT_BEAM:
		var bv := BeamView3D.new()
		host.add_fx(bv)
		bv.bind(node as Node2D, host)
		return bv
	if key == SCRIPT_AOE and ZoneProp3D.wants(node as Node2D):
		var zp := ZoneProp3D.new()
		host.add_fx(zp)
		zp.bind(node as Node2D, host)
		return zp
	return null
