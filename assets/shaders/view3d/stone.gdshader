shader_type spatial;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Walls, slab, pillars, plinths and rocks (W1-ARENA). Triplanar sample of the rift-lane paving band
// (v 0.30..0.70) at tile_m metre tiles, mirrored so tiles join without seams, with a snow cap on
// up-facing surfaces (snow_amount 0 for the bare / deep variants). Colour maths in display space, then
// v3d_albedo (colour contract).
// W3 fix: masonry > 0 (walls, piers, arches) lays world-space ashlar courses over vertical faces (running
// bond, mortar joints, per-block tint and edge shading) and coping joints over top faces, and samples the
// paving texture finer there (masonry_tile_m) as stone grain. A thin face therefore shows blocks, not a
// stretched slice of one 2 m paving tile.
// Final polish: masonry also gets weathering (low-frequency stains), contact darkening where walls meet the deck,
// depth darkening down the viaduct piers toward the abyss, and coping slabs with wider joints and stronger
// per-slab tone, so wall tops and caps read as laid stone instead of flat light boxes.
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;   // rift-lane.png (raw)
uniform float tile_m = 2.0;
uniform vec2 band_v = vec2(0.30, 0.70);
uniform float tint = 0.62;
uniform vec3 stone_tint = vec3(0.86, 0.92, 1.0);
uniform vec3 snow_color = vec3(0.5, 0.55, 0.63);   // packed grey-blue snow, not a white cap
uniform float snow_amount = 1.0;
uniform float roughness = 0.85;
uniform float masonry = 0.0;                      // 0 paving only .. 1 full ashlar courses
uniform vec2 block_m = vec2(0.62, 0.21);          // block length, course height (metres)
uniform float mortar_m = 0.022;                   // joint half-width (metres)
uniform float coping_m = 0.9;                     // joint spacing on top faces (metres)
uniform float masonry_tile_m = 0.9;               // paving texture tile on masonry faces (stone grain)
uniform float weathering = 0.32;                  // masonry stain strength (0 = clean)
uniform float contact_ao = 0.3;                   // darkening at the foot of walls standing on the deck
uniform float depth_dark = 0.45;                  // darkening down the piers (deck level -> ABYSS)
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri_wave(float x) {
	float f = fract(x * 0.5) * 2.0;
	return f < 1.0 ? f : 2.0 - f;
}

vec3 sample_plane(vec2 p, float tile) {
	vec2 raw = p / tile;
	vec2 uv = vec2(tri_wave(raw.x), band_v.x + (band_v.y - band_v.x) * tri_wave(raw.y));
	vec2 k = vec2(1.0, band_v.y - band_v.x);
	return textureGrad(albedo_tex, uv, dFdx(raw) * k, dFdy(raw) * k).rgb;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Running-bond blocks on a face: x along the face, y up. Returns (joint mask, block shade, edge shade).
vec3 ashlar(vec2 p) {
	float row = floor(p.y / block_m.y);
	float len = block_m.x * (0.8 + 0.4 * hash12(vec2(row, 7.0)));   // course-to-course length variation
	float shift = mod(row, 2.0) * 0.5 * len + hash12(vec2(row, 3.0)) * 0.2 * len;
	float col = floor((p.x + shift) / len);
	vec2 f = vec2(fract((p.x + shift) / len) * len, fract(p.y / block_m.y) * block_m.y);
	vec2 size = vec2(len, block_m.y);
	vec2 d = min(f, size - f);                            // distance to the block's edges (metres)
	float edge = min(d.x, d.y);
	float joint = 1.0 - smoothstep(mortar_m * 0.6, mortar_m * 1.3, edge);
	float shade = 0.88 + 0.3 * hash12(vec2(col, row));
	float bevel = 0.86 + 0.14 * smoothstep(0.0, 0.06, edge);
	return vec3(joint, shade, bevel);
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	float tile = mix(tile_m, masonry_tile_m, step(0.001, masonry));
	vec3 c = sample_plane(wpos.zy, tile) * w.x + sample_plane(wpos.xz, tile) * w.y + sample_plane(wpos.xy, tile) * w.z;
	// Snow cap where the surface faces up, broken up by the stone texture's own light/dark pattern.
	float grain = clamp(dot(c, vec3(0.333)) * 1.8 - 0.2, 0.0, 1.0);
	c *= tint * stone_tint;
	float top_mason = 0.0;                            // masonry top faces (coping): snow follows the drifts
	if (masonry > 0.0) {
		// Vertical faces: ashlar courses along whichever horizontal axis the face runs.
		float vertical = 1.0 - smoothstep(0.5, 0.85, abs(n.y));
		vec2 face = abs(n.x) > abs(n.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		vec3 a = ashlar(face);
		// Top faces: coping slabs with joints across both axes.
		vec2 cp = wpos.xz / coping_m;
		vec2 cd = min(fract(cp), 1.0 - fract(cp)) * coping_m;
		float cj = 1.0 - smoothstep(mortar_m * 1.0, mortar_m * 2.2, min(cd.x, cd.y));
		float cshade = (0.82 + 0.3 * hash12(floor(cp))) * (0.9 + 0.1 * smoothstep(0.0, 0.12, min(cd.x, cd.y)));
		float joint = mix(cj, a.x, vertical);
		float shade = mix(cshade, a.y * a.z, vertical);
		// The paving texture's own joints and slab edges ran along thin faces as streaks: keep only its
		// grain on masonry (contrast pulled toward the texture's average colour), the blocks carry the shape.
		vec3 avg = textureLod(albedo_tex, vec2(0.5, 0.5 * (band_v.x + band_v.y)), 10.0).rgb * tint * stone_tint;
		c = mix(c, avg, mix(0.6, 0.45, vertical) * masonry);
		// Snow on coping follows the slabs, not the (minified, streaky) paving grain.
		// Patchy drifts: some slabs nearly bare, others carrying snow, broken up across each slab.
		float drift = vnoise(wpos.xz * 1.7 + 3.1) * (0.55 + 0.45 * hash12(floor(cp) + 17.0));
		grain = mix(grain, 0.05 + 0.8 * drift, (1.0 - vertical) * masonry);
		top_mason = (1.0 - vertical) * masonry;
		vec3 blocks = c * shade;
		vec3 mortar = c * 0.5;
		c = mix(c, mix(blocks, mortar, joint), masonry);
		// Weathering: broad stains and streaks running down the faces (low frequency, so no shimmer).
		float stain = vnoise(vec2(wpos.x + wpos.z, wpos.y * 0.35) * 0.9) * 0.65 + vnoise((wpos.xz + wpos.y) * 2.3) * 0.35;
		c *= 1.0 - weathering * masonry * (stain - 0.4);
		// Walls on the deck: darker where they meet it. Below the deck: darker toward the abyss.
		float foot = wpos.y > -0.45 ? mix(1.0 - contact_ao, 1.0, smoothstep(0.0, 0.3, wpos.y)) : mix(1.0 - depth_dark, 1.0, smoothstep(-9.0, -0.6, wpos.y));
		c *= mix(1.0, foot, vertical * masonry);
	}
	// Patchy, textured snow: coverage and brightness follow the paving grain so the stone pattern shows
	// through instead of clipping to a flat bright top.
	float snow = smoothstep(0.7, 0.9, n.y) * snow_amount * mix(0.35 + 0.45 * grain, 0.9 * grain, top_mason);
	c = mix(c, snow_color * (0.72 + 0.4 * grain), snow);
	ALBEDO = v3d_albedo(c);
	ROUGHNESS = mix(roughness, 0.6, snow);
}
