class_name ZoneProp3D
extends Node3D
## Standing parts of AoE zones (W2-ZONES). The AoE keeps drawing its ground footprint flat in the overlay
## (AoE._draw gates skip only the upright pieces while ViewConfig.is_active()); this view stands those pieces up:
##   soul/dagger pickups (procedural world objects: a glowing soul wisp, a dagger stuck in the deck), ring spikes, WindArt cards, Xin Zhao swipes, GROUND_PROFILE pillars (the column from the
##   cell top down to the rim centre, standing at the AoE centre with a soft base; KitEffectArt.pillar_band),
##   Syndra spheres (bobbing card + ground blob), Caitlyn traps and Thresh lanterns (+ "RIGHT-CLICK" caption),
##   side-view kit art (KitEffectArt.STANDING: comets, missiles, slashes, volleys) as a standing card, and swept
##   side-view bands (KitEffectArt.BANDS: Thresh E, Xin Zhao W) as a raised ribbon along effect_dir. For those two
##   kinds AoE._draw keeps only a soft footprint (fill + rim) on the ground.
## Read-only: never writes AoE fields. Bound 1:1 to the AoE node; frees itself when the AoE leaves the tree
## (expiry, Roster12Kits.remove_sphere, LAN reconcile). Fields are read live every sync (replicas never run setup).

const KIND_ICON := "icon"
const KIND_RING := "ring"
const KIND_WIND := "wind"
const KIND_SWIPE := "swipe"
const KIND_PILLAR := "pillar"
const KIND_SPHERE := "sphere"
const KIND_TRAP := "trap"
const KIND_LANTERN := "lantern"
const KIND_STAND := "stand"
const KIND_BAND := "band"

const ICON_PX := 24.0                 # AoE.gd:68 Rect2(-12, -24, 24, 24): the 2D icon tile (kept for reference)
## Pickups (final polish): drawn as world objects instead of the 2D ability-icon tile. Card 0 is the object (soul:
## additive procedural wisp floating and bobbing; dagger: procedural blade stuck point-first in the deck, falling
## and spinning in while the AoE arms), card 1 a soft additive glow lying on the deck under it.
const SOUL_PX := Vector2(34.0, 46.0)        # wisp card (art px, FX_SCALE), centre-anchored
const SOUL_LIFT_PX := 24.0
const SOUL_BOB_PX := 3.0
const SOUL_BOB_HZ := 0.8
const SOUL_COLOR := Color(0.38, 1.0, 0.78)
const SOUL_GLOW_M := 0.95
const DAGGER_PX := Vector2(18.0, 40.0)      # dagger card (art px, FX_SCALE)
const DAGGER_SINK_PX := 3.0                 # the tip is buried this far below the deck
const DAGGER_DROP_PX := 70.0                # height it falls from while arming
const DAGGER_SPINS := 1.5                   # turns while falling
const DAGGER_TILT := 0.22                   # radians the stuck blade leans (art is drawn tilted)
const DAGGER_GLOW_COLOR := Color(1.0, 0.25, 0.3)
const DAGGER_GLOW_M := 0.8
const PROC_SOUL := 1
const PROC_DAGGER := 2
const PROC_GROUND_GLOW := 3
const RING_BARS := 8
const RING_BAR_PX := Vector2(5.0, 30.0)
const SWIPE_LIFT := {"xinzhao_q": 25.0, "xinzhao_e": 32.0}
const SWIPE_SIZE := {"xinzhao_q": Vector2(1.0, 0.36), "xinzhao_e": Vector2(1.2, 0.56)}   # times radius (AoE.gd:155/157)
const SPHERE_LIFT_PX := 40.0
const SPHERE_BOB_PX := 4.0
const SPHERE_BOB_HZ := 2.0
const SPHERE_BLOB_M := 0.5
const BLOB_Y_M := 0.01
const PILLAR_SIDE_FADE := 0.08        # soften the atlas-cell crop at the pillar card's sides
const PILLAR_BASE_FADE := 0.8         # share of the rim's back half faded where the column meets the flat rim
const STAND_ASPECT := Vector2(0.45, 1.6)   # standing card height / width clamp (atlas crop aspect is kept)
const STAND_BASE_FADE := 0.12           # soft bottom edge where a standing card meets the deck
const STAND_FADE_FROM := 0.7            # standing cards fade out over the last 30% of the AoE
const STAND_AURA_S := 3.0               # kit effects lasting longer than this (persistent auras) stay flat; duration is replicated
const STAND_CASTER_PX := 30.0           # an AoE this close to its caster is caster-centred: drawn additively
const BAND_CHEST_PX := 27.0             # ViewConfig.CHEST_PX: ribbon centre height
const BAND_HEIGHT_K := 0.5              # ribbon height = BAND_HEIGHT_K * band width (2D across extent)
const BAND_THRESH_E := Vector2(440.0, 130.0)   # AoE.gd thresh_e rect Rect2(-220, -65, 440, 130)
const LANTERN_LABEL := "RIGHT-CLICK"
const LANTERN_LABEL_COLOR := Color("b9ffe6")
const LANTERN_LABEL_OFFSET := Vector2(-44, 38)

const _SHADER_HEAD := "shader_type spatial;\nrender_mode %s, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;\n"
const _SHADER_BODY := """#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// ZoneProp3D card (runtime shader, W2-ZONES). Colour contract: raw samples, display-space maths, v3d_albedo.
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform bool use_tex = true;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint = vec4(1.0);
uniform float bias_m = 0.3;
uniform float max_lod = 1.25;
uniform float blob = 0.0;            // > 0: radial soft disc (ground shadow), no texture
uniform vec4 edge_fade = vec4(0.0);  // soft card edges as UV fractions: left, right, top, bottom (0 = hard)
uniform int proc = 0;                // 0 texture / blob; 1 soul wisp; 2 dagger; 3 soft ground glow (pickups)
uniform float proc_time = 0.0;
uniform vec4 proc_color = vec4(1.0);
uniform float proc_aspect = 0.45;    // soul / dagger: card width / height
uniform float proc_tilt = 0.22;      // dagger: lean of the blade (radians)
// Thresh soul: a glowing orb with a swaying flame tail rising from it, a hot core and a soft halo. Additive card.
// Coordinates in card-height units (x scaled by proc_aspect), so the orb stays round.
vec4 zp_soul(vec2 uv) {
	float t = proc_time;
	vec2 p = vec2((uv.x - 0.5) * proc_aspect, 1.0 - uv.y);
	float sway = sin(p.y * 8.0 - t * 5.0) * 0.05 * smoothstep(0.3, 0.9, p.y);
	float x = p.x - sway;
	float cy = 0.32;
	float r = 0.17;
	float w = p.y < cy ? r * sqrt(max(1.0 - pow((cy - p.y) / r, 2.0), 0.0)) : r * pow(max(1.0 - (p.y - cy) / 0.62, 0.0), 1.4);
	float q = abs(x) / max(w, 0.001);
	float body = exp(-q * q * 1.6) * step(cy - r, p.y);
	float flick = 0.85 + 0.15 * sin(t * 11.0 + p.y * 9.0);
	vec2 o = vec2(x, p.y - cy);
	float core = exp(-dot(o, o) / 0.006);
	float halo = exp(-dot(vec2(p.x, p.y - cy), vec2(p.x, p.y - cy)) / 0.03) * 0.45;
	vec3 c = mix(proc_color.rgb, vec3(1.0), clamp(core, 0.0, 1.0) * 0.8);
	return vec4(c, clamp(body * flick + core + halo, 0.0, 1.0));
}
float zp_box(vec2 p, vec2 c, vec2 h) {
	vec2 q = abs(p - c) - h;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}
// Katarina dagger stuck point-first in the deck: steel blade (lit left half, ridge, glint), crimson guard with gold
// trim, wrapped grip and gold pommel, with a dark outline. Card units: x across, y up from the deck (0) to the top.
vec4 zp_dagger(vec2 uv) {
	vec2 p = vec2((uv.x - 0.5) * proc_aspect, 1.0 - uv.y - 0.07);
	float ca = cos(proc_tilt);
	float sa = sin(proc_tilt);
	p = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
	float aa = max(fwidth(p.y), 0.002);
	float bw = 0.075 * clamp((p.y + 0.06) / 0.26, 0.0, 1.0);
	float d_blade = max(abs(p.x) - bw, max(-0.06 - p.y, p.y - 0.56));
	float d_guard = zp_box(p, vec2(0.0, 0.59), vec2(0.19, 0.026)) - 0.012;
	float d_grip = zp_box(p, vec2(0.0, 0.74), vec2(0.036, 0.13));
	float d_pommel = length(p - vec2(0.0, 0.9)) - 0.052;
	float d = min(min(d_blade, d_guard), min(d_grip, d_pommel));
	float ow = 2.2 * aa;
	float a = clamp(0.5 - (d - ow) / aa, 0.0, 1.0);
	vec3 c = vec3(0.05, 0.02, 0.03);
	if (d < 0.0) {
		if (d_blade <= min(min(d_guard, d_grip), d_pommel)) {
			c = mix(vec3(0.5, 0.54, 0.62), vec3(0.9, 0.93, 0.98), step(p.x, 0.0));
			c *= 1.0 - 0.35 * exp(-p.x * p.x / 0.00012);
			c += vec3(0.25) * smoothstep(bw - 0.02, bw, abs(p.x)) * step(0.0, p.y);
			float glint = exp(-pow((p.y - (fract(proc_time * 0.45) * 1.6 - 0.3)) * 10.0, 2.0));
			c += vec3(0.6) * glint;
		} else if (d_guard <= min(d_grip, d_pommel)) {
			c = mix(vec3(0.66, 0.1, 0.14), vec3(0.96, 0.76, 0.36), smoothstep(-0.012, -0.002, d_guard));
		} else if (d_grip <= d_pommel) {
			c = vec3(0.24, 0.07, 0.08) * (0.8 + 0.4 * step(0.5, fract(p.y * 38.0)));
		} else {
			c = vec3(0.96, 0.78, 0.38);
		}
	}
	return vec4(c, a);
}
void vertex() {
	VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec4 t = vec4(1.0);
	if (proc == 1) {
		t = zp_soul(UV);
	} else if (proc == 2) {
		t = zp_dagger(UV);
	} else if (proc == 3) {
		float d = length(UV * 2.0 - 1.0);
		t = vec4(proc_color.rgb, exp(-d * d * 3.5) * (1.0 - smoothstep(0.75, 1.0, d)));
	} else if (blob > 0.0) {
		float d = length(UV * 2.0 - 1.0);
		t.a = 1.0 - smoothstep(blob, 1.0, d);
	} else if (use_tex) {
		vec2 uv = mix(region_uv.xy, region_uv.zw, UV);
		t = textureLod(tex, uv, v3d_lod(uv, vec2(textureSize(tex, 0)), max_lod));
	}
	float f = 1.0;
	if (edge_fade.x > 0.0) { f *= smoothstep(0.0, edge_fade.x, UV.x); }
	if (edge_fade.y > 0.0) { f *= smoothstep(0.0, edge_fade.y, 1.0 - UV.x); }
	if (edge_fade.z > 0.0) { f *= smoothstep(0.0, edge_fade.z, UV.y); }
	if (edge_fade.w > 0.0) { f *= smoothstep(0.0, edge_fade.w, 1.0 - UV.y); }
	ALBEDO = v3d_albedo(t.rgb * tint.rgb);
	ALPHA = t.a * tint.a * f;
}
"""

static var _shaders: Dictionary = {}
static var _quad: QuadMesh

var source: Node2D
var host: Node3D
var kind: String = ""
var cards: Array = []                 # MeshInstance3D, one ShaderMaterial each
var blob: MeshInstance3D = null
var _label_added := false
var _bound := false


# --- classification ---

## The standing-part kind for this AoE, or "" (pure ground footprint). Mirrors the AoE._draw branch order.
static func kind_of(aoe: Node2D) -> String:
	if aoe == null or not is_instance_valid(aoe) or not ("zone_kind" in aoe):
		return ""
	var zone := str(aoe.zone_kind)
	if zone in ["soul", "dagger"]:
		return KIND_ICON
	var id := str(aoe.effect_id)
	if KitEffectArt.has_effect(id):
		if KitEffectArt.is_band(id) and float(aoe.cone_ang) <= -900.0 and (id == "thresh_e" or str(aoe.footprint_kind) in ["capsule", "rectangle"]):
			return KIND_BAND
		if float(aoe.cone_ang) > -900.0 or str(aoe.footprint_kind) in ["capsule", "rectangle"]:
			return ""
		if id in ["xinzhao_q", "xinzhao_e"]:
			return KIND_SWIPE
		if KitEffectArt.has_ground_profile(id):
			return KIND_PILLAR
		if zone == "sphere":
			return KIND_SPHERE
		if zone == "trap":
			return KIND_TRAP
		if zone == "lantern":
			return KIND_LANTERN
		if zone == "" and KitEffectArt.stands_upright(id) and float(aoe.duration) <= STAND_AURA_S:
			return KIND_STAND
		return ""
	if float(aoe.cone_ang) > -900.0:
		return ""
	if bool(aoe.ring):
		return KIND_RING
	if int(aoe.wind_kind) >= 0:
		return KIND_WIND
	return ""


static func wants(aoe: Node2D) -> bool:
	return kind_of(aoe) != ""


# --- lifecycle ---

func bind(aoe: Node2D, h: Node3D) -> void:
	source = aoe
	host = h
	kind = kind_of(aoe)
	name = "Zone_%s_%d" % [kind if kind != "" else "none", aoe.get_instance_id() if is_instance_valid(aoe) else 0]
	_build()
	if is_instance_valid(aoe) and not aoe.tree_exiting.is_connected(_on_source_exiting):
		aoe.tree_exiting.connect(_on_source_exiting, CONNECT_ONE_SHOT)
	_bound = true
	visible = false   # shown by the first sync with a live camera


func dispose() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _on_source_exiting() -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		dispose()
	else:
		_check_source.call_deferred()


## A source that left without being freed (a reparent) keeps its prop; anything else frees it.
func _check_source() -> void:
	if is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion():
		if not source.tree_exiting.is_connected(_on_source_exiting):
			source.tree_exiting.connect(_on_source_exiting, CONNECT_ONE_SHOT)
		return
	dispose()


func _build() -> void:
	match kind:
		KIND_RING:
			for i in RING_BARS:
				cards.append(_make_card("Spike%d" % i, true))
		KIND_STAND, KIND_BAND:
			cards.append(_make_card("Card", stand_additive(source)))
		KIND_ICON:
			var soul := is_instance_valid(source) and str(source.zone_kind) == "soul"
			cards.append(_make_card("Card", soul))
			cards.append(_make_card("Glow", true))
			var cm := cards[0].material_override as ShaderMaterial
			cm.set_shader_parameter("proc", PROC_SOUL if soul else PROC_DAGGER)
			cm.set_shader_parameter("proc_color", SOUL_COLOR if soul else Color.WHITE)
			cm.set_shader_parameter("proc_aspect", (SOUL_PX.x / SOUL_PX.y) if soul else (DAGGER_PX.x / DAGGER_PX.y))
			cm.set_shader_parameter("proc_tilt", DAGGER_TILT)
			var gm := cards[1].material_override as ShaderMaterial
			gm.set_shader_parameter("proc", PROC_GROUND_GLOW)
			gm.set_shader_parameter("proc_color", SOUL_COLOR if soul else DAGGER_GLOW_COLOR)
			gm.set_shader_parameter("bias_m", 0.0)
		KIND_SPHERE:
			cards.append(_make_card("Card", false))
			blob = _make_card("Blob", false)
			var bm := blob.material_override as ShaderMaterial
			bm.set_shader_parameter("blob", 0.35)
			bm.set_shader_parameter("use_tex", false)
			bm.set_shader_parameter("bias_m", 0.0)
			bm.set_shader_parameter("tint", Color(0.02, 0.02, 0.05, 0.5))
		"":
			pass
		_:
			cards.append(_make_card("Card", false))


func _make_card(card_name: String, additive: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = card_name
	mi.mesh = _quad_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _shader(additive)
	mi.material_override = mat
	add_child(mi)
	return mi


static func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


static func _shader(additive: bool) -> Shader:
	var key := "add" if additive else "mix"
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = (_SHADER_HEAD % ("blend_add" if additive else "blend_mix")) + _SHADER_BODY
		_shaders[key] = sh
	return _shaders[key]


# --- per frame ---

func sync(_delta: float) -> void:
	if not _bound:
		return
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		dispose()
		return
	if not is_inside_tree():
		return
	var cam: Camera3D = host.camera() if is_instance_valid(host) else null
	if kind == "" or cam == null or not cam.is_inside_tree() or not source.is_inside_tree() or not source.is_visible_in_tree():
		visible = false
		return
	visible = true
	var fade: float = clampf(source.modulate.a, 0.0, 1.0)
	var pos: Vector2 = source.global_position
	var up: Vector3 = host.card_up()
	match kind:
		KIND_ICON:
			_sync_icon(cam, pos, fade)
		KIND_RING:
			_sync_ring(cam, pos, fade)
		KIND_WIND:
			_sync_wind(cam, pos, up, fade)
		KIND_SWIPE:
			_sync_swipe(cam, pos, up, fade)
		KIND_PILLAR:
			_sync_pillar(cam, pos, fade)
		KIND_SPHERE:
			_sync_sphere(cam, pos, up, fade)
		KIND_TRAP:
			_sync_kit_card(cam, pos, fade)
		KIND_LANTERN:
			_sync_kit_card(cam, pos, fade)
			_sync_label()
		KIND_STAND:
			_sync_stand(cam, pos, fade)
		KIND_BAND:
			_sync_band(cam, pos, up, fade)


func _sync_icon(cam: Camera3D, pos: Vector2, fade: float) -> void:
	var soul: bool = str(source.zone_kind) == "soul"
	var t: float = float(host.anim_time()) if host.has_method("anim_time") else 0.0
	var up: Vector3 = host.card_up()
	var mat := cards[0].material_override as ShaderMaterial
	mat.set_shader_parameter("proc_time", t)
	mat.set_shader_parameter("tint", Color(1, 1, 1, fade))
	var glow_alpha := 0.0
	if soul:
		var size := Vector2(ViewMath.art_m(SOUL_PX.x, ViewConfig.FX_SCALE), ViewMath.art_m(SOUL_PX.y, ViewConfig.FX_SCALE))
		var lift := SOUL_LIFT_PX + SOUL_BOB_PX * sin(t * TAU * SOUL_BOB_HZ)
		_place(cards[0], cam, ViewMath.lifted(pos, lift, up, ViewConfig.FX_SCALE), 0.0, size, false)
		glow_alpha = 0.55 * fade
		_place_flat(cards[1], pos, SOUL_GLOW_M)
	else:
		var k := dagger_landed(source)
		var size := Vector2(ViewMath.art_m(DAGGER_PX.x, ViewConfig.FX_SCALE), ViewMath.art_m(DAGGER_PX.y, ViewConfig.FX_SCALE))
		var lift := DAGGER_DROP_PX * (1.0 - k * k) - DAGGER_SINK_PX + DAGGER_PX.y * 0.5
		var spin := (1.0 - k) * TAU * DAGGER_SPINS
		_place(cards[0], cam, ViewMath.lifted(pos, lift, up, ViewConfig.FX_SCALE), spin, size, false)
		glow_alpha = 0.5 * fade * smoothstep(0.7, 1.0, k)
		_place_flat(cards[1], pos, DAGGER_GLOW_M)
	(cards[1].material_override as ShaderMaterial).set_shader_parameter("tint", Color(1, 1, 1, glow_alpha))
	cards[1].visible = glow_alpha > 0.002


## Dagger landing progress: 0 when tossed .. 1 once armed (stuck in the deck). Replicated fields only.
static func dagger_landed(aoe: Node2D) -> float:
	var arm := float(aoe.arm_delay)
	if arm <= 0.0:
		return 1.0
	return clampf(float(aoe.elapsed) / arm, 0.0, 1.0)


## A flat card lying on the deck (just above it), side metres, centred on the sim point.
func _place_flat(card: MeshInstance3D, pos: Vector2, side: float) -> void:
	card.global_transform = Transform3D(Basis(Vector3(side, 0, 0), Vector3(0, 0, -side), Vector3(0, 1, 0)), ViewMath.to3(pos, 0.012))


func _sync_ring(cam: Camera3D, pos: Vector2, fade: float) -> void:
	var ring_fade := clampf((float(source.duration) - float(source.elapsed)) * 2.0, 0.0, 1.0)
	var radius: float = float(source.radius)
	var col: Color = source.color
	var size := Vector2(ViewMath.art_m(RING_BAR_PX.x, ViewConfig.FX_SCALE), ViewMath.art_m(RING_BAR_PX.y, ViewConfig.FX_SCALE))
	for i in cards.size():
		var point := pos + Vector2.from_angle(i * TAU / float(RING_BARS)) * radius
		_place(cards[i], cam, ViewMath.to3(point), 0.0, size, true)
		_paint(cards[i], null, Rect2(), Color(col.r, col.g, col.b, ring_fade * fade))


func _sync_wind(cam: Camera3D, pos: Vector2, up: Vector3, fade: float) -> void:
	var wind: int = int(source.wind_kind)
	var frame := mini(3, int(float(source.elapsed) / maxf(0.01, float(source.duration)) * 4.0))
	var side: float = 2.0 * float(source.radius) * ViewConfig.S
	var tornado := wind == 1
	var at: Vector3 = ViewMath.to3(pos) if tornado else ViewMath.lifted(pos, ViewConfig.CHEST_PX, up)
	_place(cards[0], cam, at, 0.0, Vector2(side, side), tornado)
	_paint(cards[0], WindArt.texture, WindArt.frame(wind, frame), Color(1, 1, 1, 0.9 * fade))


func _sync_swipe(cam: Camera3D, pos: Vector2, up: Vector3, fade: float) -> void:
	var id := str(source.effect_id)
	var radius: float = float(source.radius)
	var dims: Vector2 = SWIPE_SIZE.get(id, Vector2.ONE) * radius
	var size := Vector2(ViewMath.art_m(dims.x, ViewConfig.FX_SCALE), ViewMath.art_m(dims.y, ViewConfig.FX_SCALE))
	var at := ViewMath.lifted(pos, float(SWIPE_LIFT.get(id, 25.0)), up, ViewConfig.FX_SCALE)
	_place(cards[0], cam, at, swipe_screen_angle(cam, ViewMath.to3(pos), source.effect_dir), size, false)
	_paint(cards[0], KitEffectArt.sheet(id), KitEffectArt.region(id, kit_frame(source)), Color(1, 1, 1, 0.9 * fade))


## On-screen card rotation for a swipe direction. Roster12Combat.gd:73 passes Vector2.UP for the vertical
## uppercut: that means "up the screen" (a knock-up), not sim north, so it maps straight to -PI/2.
static func swipe_screen_angle(cam: Camera3D, ground: Vector3, dir: Vector2) -> float:
	if dir == Vector2.UP:
		return -PI * 0.5
	if dir.length_squared() < 0.0001:
		return 0.0
	return ViewMath.screen_angle(cam, ground, dir)


func _sync_pillar(cam: Camera3D, pos: Vector2, fade: float) -> void:
	var id := str(source.effect_id)
	var band: Dictionary = KitEffectArt.pillar_band(id, kit_frame(source), float(source.radius))
	var size: Vector2 = band.size * ViewConfig.S
	if size.x <= 0.0 or size.y <= 0.0:
		cards[0].visible = false
		return
	cards[0].visible = true
	var right := ViewMath.card_basis(cam, 0.0).x.normalized()
	var foot := ViewMath.to3(pos) + right * float(band.offset_x) * ViewConfig.S
	_place(cards[0], cam, foot, 0.0, size, true)
	var alpha := 0.9
	if str(source.zone_kind) == "box":
		# Broken Thresh R walls are cut out of the flat rim; the standing band fades with the walls left.
		var intact := 0
		for broken in source.broken_walls:
			if not broken:
				intact += 1
		alpha *= lerpf(0.35, 1.0, float(intact) / 5.0)
	_paint(cards[0], KitEffectArt.sheet(id), band.region, Color(1, 1, 1, alpha * fade))
	(cards[0].material_override as ShaderMaterial).set_shader_parameter("edge_fade",
		Vector4(PILLAR_SIDE_FADE, PILLAR_SIDE_FADE, 0.0, float(band.get("rim_fraction", 0.0)) * PILLAR_BASE_FADE))


func _sync_sphere(cam: Camera3D, pos: Vector2, up: Vector3, fade: float) -> void:
	var id := str(source.effect_id)
	var side := ViewMath.art_m(2.0 * float(source.radius), ViewConfig.FX_SCALE)
	var t: float = float(host.anim_time()) if host.has_method("anim_time") else 0.0
	var lift := SPHERE_LIFT_PX + SPHERE_BOB_PX * sin(t * TAU * SPHERE_BOB_HZ)
	_place(cards[0], cam, ViewMath.lifted(pos, lift, up, ViewConfig.FX_SCALE), 0.0, Vector2(side, side), false)
	_paint(cards[0], KitEffectArt.sheet(id), KitEffectArt.region(id, kit_frame(source)), Color(1, 1, 1, 0.9 * fade))
	var d := SPHERE_BLOB_M
	blob.global_transform = Transform3D(Basis(Vector3(d, 0, 0), Vector3(0, 0, -d), Vector3(0, 1, 0)), ViewMath.to3(pos, BLOB_Y_M))
	(blob.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.02, 0.02, 0.05, 0.5 * fade))


func _sync_kit_card(cam: Camera3D, pos: Vector2, fade: float) -> void:
	var id := str(source.effect_id)
	var side := ViewMath.art_m(2.0 * float(source.radius), ViewConfig.FX_SCALE)
	_place(cards[0], cam, ViewMath.to3(pos), 0.0, Vector2(side, side), true)
	_paint(cards[0], KitEffectArt.sheet(id), KitEffectArt.region(id, kit_frame(source)), Color(1, 1, 1, 0.9 * fade))


## Side-view kit art standing on the AoE centre: a camera-facing card 2 * radius wide (the 2D rect's width), the
## crop's aspect kept, bottom on the deck. Caster-centred bursts are additive so the champion stays readable.
func _sync_stand(cam: Camera3D, pos: Vector2, fade: float) -> void:
	var id := str(source.effect_id)
	var region := KitEffectArt.region(id, kit_frame(source))
	var w := 2.0 * float(source.radius) * ViewConfig.S
	var aspect := clampf(region.size.y / maxf(region.size.x, 1.0), STAND_ASPECT.x, STAND_ASPECT.y)
	_place(cards[0], cam, ViewMath.to3(pos), 0.0, Vector2(w, w * aspect), true)
	_paint(cards[0], KitEffectArt.sheet(id), region, Color(1, 1, 1, 0.9 * fade * stand_fade(source)))
	(cards[0].material_override as ShaderMaterial).set_shader_parameter("edge_fade", Vector4(0.0, 0.0, 0.0, STAND_BASE_FADE))


## Swept side-view band: a ribbon along effect_dir at chest height, as long as the 2D band, facing the camera
## around its axis (art top kept screen-up).
func _sync_band(cam: Camera3D, pos: Vector2, up: Vector3, fade: float) -> void:
	var id := str(source.effect_id)
	var dims := band_dims(source)
	var dir: Vector2 = source.effect_dir
	dir = Vector2.RIGHT if dir.length_squared() < 1e-6 else dir.normalized()
	var axis := Vector3(dir.x, 0.0, dir.y) * dims.x * ViewConfig.S
	var height := dims.y * BAND_HEIGHT_K * ViewConfig.S
	var across := axis.cross(cam.global_basis.z)
	if across.length_squared() < 1e-6:
		across = up
	across = across.normalized()
	if across.dot(cam.global_basis.y) < 0.0:
		across = -across
	var normal := axis.normalized().cross(across).normalized()
	var lift := maxf(ViewMath.art_m(BAND_CHEST_PX, ViewConfig.FX_SCALE), height * 0.5 + 0.05)
	cards[0].global_transform = Transform3D(Basis(axis, across * height, normal), ViewMath.to3(pos) + up * lift)
	_paint(cards[0], KitEffectArt.sheet(id), KitEffectArt.region(id, kit_frame(source)), Color(1, 1, 1, 0.9 * fade * stand_fade(source)))


## Band length and across extent in 2D px (AoE._draw_kit_effect rects).
static func band_dims(aoe: Node2D) -> Vector2:
	var r := float(aoe.radius)
	var fw := float(aoe.footprint_width)
	if str(aoe.effect_id) == "thresh_e":
		return BAND_THRESH_E
	if str(aoe.footprint_kind) in ["capsule", "rectangle"] and fw > 0.0:
		return Vector2((r + fw) * 2.0, fw * 2.0)
	return Vector2(r * 2.0, r * 0.72)


## Standing / band cards spawned on their caster draw additively: light over the body. Uses replicated fields only
## (position and src), so host and LAN replicas agree.
static func stand_additive(aoe: Node2D) -> bool:
	if aoe == null or not is_instance_valid(aoe):
		return false
	var src = aoe.src
	return is_instance_valid(src) and src is Node2D and (src as Node2D).global_position.distance_to(aoe.global_position) < STAND_CASTER_PX


## Alpha multiplier of a standing card: full, then fading over the AoE's last 30%.
static func stand_fade(aoe: Node2D) -> float:
	var p := float(aoe.elapsed) / maxf(0.01, float(aoe.duration))
	return 1.0 - smoothstep(STAND_FADE_FROM, 1.0, clampf(p, 0.0, 1.0))


func _sync_label() -> void:
	if _label_added or not is_instance_valid(host) or not host.has_method("overhead_layer"):
		return
	if int(host.local_team()) != int(source.team):
		return
	var layer = host.overhead_layer()
	if layer == null or not layer.has_method("add_label"):
		return
	layer.add_label(source, LANTERN_LABEL, LANTERN_LABEL_COLOR, LANTERN_LABEL_OFFSET)
	_label_added = true


## The kit-effect frame AoE._draw_kit_effect picks (box/cage arming loop, Veigar W timing).
static func kit_frame(aoe: Node2D) -> int:
	var elapsed: float = float(aoe.elapsed)
	var duration: float = float(aoe.duration)
	var arm: float = float(aoe.arm_delay)
	var frame := mini(3, int(elapsed / maxf(0.01, duration) * 4.0))
	if str(aoe.zone_kind) in ["box", "cage"]:
		frame = 0 if elapsed < arm else 3 if duration - elapsed < 0.35 else 1 + int(elapsed * 3.0) % 2
	if str(aoe.effect_id) == "veigar_w":
		frame = 0 if elapsed < arm * 0.6 else 1 if elapsed < arm else 2 if elapsed < arm + 0.2 else 3
	return frame


# --- card helpers ---

## Camera-facing card of size (w, h) metres rotated by screen_rot in the image plane. bottom = true anchors the
## card's bottom edge at `at` (standing on the ground); otherwise `at` is the card centre.
func _place(card: MeshInstance3D, cam: Camera3D, at: Vector3, screen_rot: float, size: Vector2, bottom: bool) -> void:
	var b := ViewMath.card_basis(cam, screen_rot)
	var x := b.x.normalized()
	var y := b.y.normalized()
	var centre := at + (y * size.y * 0.5 if bottom else Vector3.ZERO)
	card.global_transform = Transform3D(Basis(x * size.x, y * size.y, b.z.normalized()), centre)


func _paint(card: MeshInstance3D, tex: Texture2D, region: Rect2, tint: Color) -> void:
	var mat := card.material_override as ShaderMaterial
	if tex == null:
		mat.set_shader_parameter("use_tex", false)
	else:
		var r := region if region.size.x > 0.0 and region.size.y > 0.0 else Rect2(Vector2.ZERO, tex.get_size())
		# An AtlasTexture's RID is its whole atlas: sample the atlas with the sub-region offset.
		while tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
			r.position += (tex as AtlasTexture).region.position
			tex = (tex as AtlasTexture).atlas
		mat.set_shader_parameter("use_tex", true)
		mat.set_shader_parameter("tex", tex)
		var ts := tex.get_size()
		mat.set_shader_parameter("region_uv", Vector4(r.position.x / ts.x, r.position.y / ts.y, r.end.x / ts.x, r.end.y / ts.y))
	mat.set_shader_parameter("tint", tint)


## Test / diagnostic helper: world-space centre, size, axes and bottom point of card i.
func card_info(i: int = 0) -> Dictionary:
	if i < 0 or i >= cards.size():
		return {}
	var c: MeshInstance3D = cards[i]
	var bx := c.global_transform.basis
	return {"centre": c.global_position, "width": bx.x.length(), "height": bx.y.length(), "x_axis": bx.x.normalized(),
		"up": bx.y.normalized(), "bottom": c.global_position - bx.y * 0.5, "visible": c.visible and visible,
		"material": c.material_override}
