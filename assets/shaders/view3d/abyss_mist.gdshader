shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Drifting mist sheet over the abyss (W3-POLISH). Two value-noise layers scroll in different directions on
// mist_time (the host's anim_time, frozen while paused). Unshaded, alpha blended, never writes depth.
// Colour maths in display space, then v3d_albedo (colour contract).
uniform float mist_time = 0.0;
uniform vec3 mist_color = vec3(0.36, 0.47, 0.64);
uniform float density = 0.45;
uniform float scale_m = 9.0;                    // feature size of the first layer in metres
uniform vec2 scroll_a = vec2(0.40, 0.12);       // metres per second
uniform vec2 scroll_b = vec2(-0.25, 0.30);
uniform vec2 centre = vec2(28.0, 5.4);          // metres: the mist thins out toward the sheet edges
uniform vec2 half_size = vec2(150.0, 100.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.03 + 17.1) * 0.3 + vnoise(p * 4.1 + 3.7) * 0.1;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = fbm((p + scroll_a * mist_time) / scale_m);
	float n2 = fbm((p + scroll_b * mist_time) / (scale_m * 0.6) + 5.3);
	float n = n1 * 0.62 + n2 * 0.38;
	float wisps = smoothstep(0.42, 0.78, n);
	vec2 e = abs(p - centre) / half_size;
	float edge = 1.0 - smoothstep(0.55, 1.0, max(e.x, e.y));
	ALBEDO = v3d_albedo(mist_color * (0.75 + 0.5 * n));
	ALPHA = clamp(wisps * density * edge, 0.0, 1.0);
}
