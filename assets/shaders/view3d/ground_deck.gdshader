shader_type spatial;
render_mode cull_back;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Bridge deck, base aprons and fountain discs (W1-ARENA). Every top surface at y = 0 uses this so the
// GroundOverlay (premultiplied display-space 2D ground drawing) composites with perspective.
uniform sampler2D albedo_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // rift-lane.png (raw)
uniform float sim_scale = 0.02;
uniform float tile_px = 810.0;                    // mirrored tiles, as MapRenderer
uniform vec3 base_tint = vec3(0.82, 0.86, 0.9);
uniform float contrast = 1.06;
uniform float saturation = 1.08;
uniform sampler2D overlay_tex : filter_linear, repeat_disable;
uniform vec4 overlay_rect = vec4(0.0, 0.0, 1.0, 1.0);   // sim px x, y, w, h (GroundOverlay.sync)
uniform float overlay_emission = 0.35;
// Paving band of rift-lane.png in sim px; the painted parapets above and below it are mirrored away
// because real walls replace them.
uniform vec2 paving_band = vec2(98.0, 415.0);
// Contact darkening along the deck edges next to the walls: bridge x range, then deck y (north, south)
// on the bridge and on the base aprons.
uniform vec2 bridge_x = vec2(420.0, 2380.0);
uniform vec4 deck_edges = vec4(70.0, 470.0, 20.0, 520.0);
uniform float edge_ao = 0.3;
// Pools of coloured light from crystals and fountains: x, y and radius in sim px, w intensity.
uniform int pool_count = 0;
uniform vec4 pools[16];
uniform vec4 pool_colors[16];
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float mirror_band(float y, vec2 band) {
	if (y < band.x) { y = band.x + (band.x - y); }
	if (y > band.y) { y = band.y - (y - band.y); }
	return clamp(y, band.x, band.y);
}

void fragment() {
	vec2 sim = wpos.xz / sim_scale;
	// Mirrored tiles. Gradients come from the unwrapped coordinates so the folds never pick a wrong mip.
	float u_raw = sim.x / tile_px;
	float f = fract(u_raw * 0.5) * 2.0;
	float u = f < 1.0 ? f : 2.0 - f;
	float v = mirror_band(sim.y, paving_band) / 540.0;
	vec2 grad_x = vec2(dFdx(u_raw), dFdx(sim.y / 540.0));
	vec2 grad_y = vec2(dFdy(u_raw), dFdy(sim.y / 540.0));
	vec3 base = textureGrad(albedo_tex, vec2(u, v), grad_x, grad_y).rgb * base_tint;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(luma), base, saturation);
	base = clamp((base - 0.5) * contrast + 0.5, 0.0, 1.0);
	bool bridge = sim.x > bridge_x.x && sim.x < bridge_x.y;
	float north = bridge ? deck_edges.x : deck_edges.z;
	float south = bridge ? deck_edges.y : deck_edges.w;
	float ao = 1.0 - edge_ao * (1.0 - smoothstep(north, north + 28.0, sim.y));
	ao *= 1.0 - edge_ao * 0.6 * smoothstep(south - 18.0, south, sim.y);
	base *= ao;
	vec3 pooled = vec3(0.0);
	for (int i = 0; i < pool_count; i++) {
		float fall = max(1.0 - distance(sim, pools[i].xy) / pools[i].z, 0.0);
		pooled += pool_colors[i].rgb * pools[i].w * fall * fall;
	}
	base += base * pooled * 1.7 + pooled * 0.05;
	vec2 ouv = (sim - overlay_rect.xy) / overlay_rect.zw;
	vec4 o = vec4(0.0);
	if (ouv.x > 0.0 && ouv.y > 0.0 && ouv.x < 1.0 && ouv.y < 1.0) { o = texture(overlay_tex, ouv); }
	ALBEDO = v3d_albedo(v3d_overlay(base, o));
	EMISSION = v3d_albedo(o.rgb) * overlay_emission;
	ROUGHNESS = 0.9;
}
