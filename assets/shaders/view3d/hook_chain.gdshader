shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Hook chain ribbon (W2-PROJ). UV.x runs caster -> hook, UV.y across. Mirrors the 2D chain: a translucent
// teal glow, a bright core and a link every dash_m metres (2D: a dot every 15 px).
uniform vec4 glow_color = vec4(0.1, 0.8, 0.65, 0.25);
uniform vec4 core_color = vec4(0.62, 0.95, 0.8, 0.8);
uniform vec4 link_color = vec4(0.6, 0.9, 0.75, 0.85);
uniform vec4 tint = vec4(1.0);
uniform float length_m = 1.0;
uniform float dash_m = 0.3;
uniform float bias_m = 0.3;

void vertex() {
	VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 hc_over(vec4 dst, vec4 col, float cov) {
	float a = col.a * cov;
	return vec4(col.rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float aa = max(fwidth(across), 0.001);
	vec4 o = vec4(0.0);
	o = hc_over(o, glow_color, clamp((1.0 - across) / aa, 0.0, 1.0));
	o = hc_over(o, core_color, clamp((0.36 - across) / aa + 0.5, 0.0, 1.0));
	float f = fract(UV.x * length_m / dash_m);
	float link = min(f, 1.0 - f) * dash_m;                 // metres to the nearest link centre
	float la = max(fwidth(UV.x * length_m), 0.0005);
	o = hc_over(o, link_color, clamp((0.035 - link) / la + 0.5, 0.0, 1.0) * clamp((0.9 - across) / aa, 0.0, 1.0));
	float a = o.a * tint.a;
	if (a < 0.003) { discard; }
	ALBEDO = v3d_albedo(o.rgb / max(o.a, 0.0001));
	ALPHA = a;
}
