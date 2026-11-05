shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Camera-facing painted unit card (champions, minions, corpses, structures). Owner: W1-UNITS; outline: W3-READ.
// Names shared with team-cloth.gdshader so ActionSpriteArt.apply_frame_mask() works unchanged.
// Colour contract: raw samples (no source_color), maths in display space, ALBEDO = v3d_albedo(c).
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform bool red_team = false;
uniform float hit_whiten = 0.0;
uniform int exclusion_count = 0;
uniform vec2 atlas_pixel_size = vec2(0.0);
uniform vec4 excluded_rects[8];
uniform vec3 tint = vec3(1.0);            // display-space multiplier: champions (1.3,1.15,1.08) / minions (1.10,1.06,1.02) while flashing
uniform float fade = 1.0;                 // BrushVision modulate.a, corpse fade
uniform float dissolve = 0.0;             // 0 intact .. 1 gone (structures, corpses)
uniform vec3 dissolve_edge = vec3(1.0, 0.75, 0.4);
uniform vec4 outline_color = vec4(0.0);   // a > 0 enables the hover outline
uniform float outline_px = 2.0;           // solid core width in screen px; the soft edge reaches OUTLINE_SOFT x further
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0); // current frame region in UV as (u_min, v_min, u_max, v_max) (outline neighbour clamp)
uniform float max_lod = 1.25;
uniform float key_light = 0.0;            // warm sun on the top of the art (0 off)
uniform float ground_shade = 0.0;         // bluish shade toward the ground (0 off)
uniform float ground_band = 0.62;         // ground shade starts this far down the frame
const float OUTLINE_SOFT = 1.5;          // soft outer edge: the line fades out at 1.5 x outline_px
float v3d_hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	if (v3d_excluded(UV, exclusion_count, excluded_rects)) { discard; }
	vec2 tex_size = atlas_pixel_size.x > 0.0 ? vec2(1.0) / atlas_pixel_size : vec2(textureSize(tex, 0));
	float lod = v3d_lod(UV, tex_size, max_lod);
	// Outline step: one screen pixel in UV (derivatives taken in uniform control flow), never under a texel.
	vec2 px_uv = max(fwidth(UV), vec2(1.0) / tex_size);
	vec4 t = textureLod(tex, UV, lod);
	vec3 c = mix(v3d_cloth(t.rgb, red_team) * tint, vec3(1.0, 0.95, 0.87), hit_whiten);
	float a = t.a;
	float art_v = clamp((UV.y - region_uv.y) / max(region_uv.w - region_uv.y, 0.0001), 0.0, 1.0);
	c *= mix(vec3(1.0), vec3(1.08, 1.03, 0.94), key_light * (1.0 - art_v));
	c *= mix(vec3(1.0), vec3(0.48, 0.53, 0.68), ground_shade * smoothstep(ground_band, 1.0, art_v));
	// Hover outline (final polish, LoL style): a continuous, soft line about 3 px wide drawn BEHIND the painted
	// silhouette. 16 directions on three rings (1, 2/3 and 1/3 of outline_px * OUTLINE_SOFT) take the strongest
	// neighbour alpha, so thin weapons and semi-transparent hair still register; the coverage ramps with a
	// smoothstep instead of a hard threshold and the outer ring is weaker, which softens the outer pixel.
	// Neighbours outside the frame region (the next atlas cell) or inside a masked-out rect count as empty.
	// Where the silhouette is cut by the frame's own edge (feet on the bottom row, a weapon at the side), the
	// line closes along that edge on the inside, so the outline never has an open gap there.
	if (outline_color.a > 0.0) {
		vec2 reach = px_uv * outline_px * OUTLINE_SOFT;
		float hit = 0.0;
		if (a < 0.98) {
			for (int i = 0; i < 16; i++) {
				float ang = float(i) * 0.39269908;
				vec2 dir = vec2(cos(ang), sin(ang));
				for (int ring = 0; ring < 3; ring++) {
					float r = 1.0 - float(ring) / 3.0;                       // 1, 2/3, 1/3 of the reach
					vec2 nuv = UV + dir * reach * r;
					if (any(lessThan(nuv, region_uv.xy)) || any(greaterThan(nuv, region_uv.zw))) { continue; }
					if (v3d_excluded(nuv, exclusion_count, excluded_rects)) { continue; }
					hit = max(hit, textureLod(tex, nuv, lod).a * (ring == 0 ? 0.4 : ring == 1 ? 0.85 : 1.0));
				}
			}
		}
		float line = smoothstep(0.05, 0.85, hit);
		// Inner closing line along the frame edges the silhouette touches.
		vec2 lo = (UV - region_uv.xy) / (px_uv * outline_px);
		vec2 hi = (region_uv.zw - UV) / (px_uv * outline_px);
		float edge = min(min(lo.x, lo.y), min(hi.x, hi.y));
		float cut = (1.0 - smoothstep(0.6, 1.0, edge)) * smoothstep(0.2, 0.6, a);
		// Behind the silhouette: the painted texel keeps its colour over the line.
		float la = line * outline_color.a;
		float ba = a + la * (1.0 - a);
		vec3 behind = (c * a + outline_color.rgb * la * (1.0 - a)) / max(ba, 0.0001);
		c = mix(behind, outline_color.rgb, cut);
		a = max(ba, cut * outline_color.a);
	}
	if (dissolve > 0.0) {
		float n = v3d_hash(floor(UV * tex_size / 3.0));
		if (n < dissolve) { discard; }
		if (n < dissolve + 0.08) { c = dissolve_edge; }
	}
	ALBEDO = v3d_albedo(c);
	ALPHA = a * fade;
}
