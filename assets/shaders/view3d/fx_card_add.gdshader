shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// W2-VFX: camera-facing FX card (plan 5.6). fx_card_add and fx_card_mix differ only in the blend mode.
// The card basis/rotation is built on the CPU (ViewMath.card_basis); the vertex stage pulls the card bias_m
// toward the camera along its own view ray (same pixel, nearer depth) so upright FX beat coplanar unit cards.
// Colour contract: raw sample (no source_color), display-space tint, ALBEDO = v3d_albedo(colour).
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0); // atlas cell (u_min, v_min, u_max, v_max)
uniform vec4 tint = vec4(1.0);                     // display-space rgb multiplier, alpha multiplier
uniform float bias_m = 0.3;
uniform float max_lod = 1.25;                      // mip clamp against atlas-cell bleed
void vertex() {
	VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = mix(region_uv.xy, region_uv.zw, UV);
	vec4 t = textureLod(tex, uv, v3d_lod(uv, vec2(textureSize(tex, 0)), max_lod));
	ALBEDO = v3d_albedo(t.rgb * tint.rgb);
	ALPHA = t.a * tint.a;
}
