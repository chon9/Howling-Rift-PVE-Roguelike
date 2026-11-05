shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Projectile card layers (W2-PROJ). Every layer is one camera-facing quad whose UV maps onto a box in the
// projectile's 2D local pixel space (+X = travel direction, +Y = 2D screen-down), so the shapes below are the
// exact Projectile._draw primitives. shape: -1 textured atlas region, 0 orb, 1 arrow, 2 fireball, 3 bolt,
// 4 ice, 5 wave, 6 heart, 10 line set (trail band / Vesper rim / core line). Colours are display space.
uniform int shape = 0;
uniform vec4 color = vec4(1.0);
uniform float size_px = 8.0;
uniform vec4 box_px = vec4(-17.6, -17.6, 35.2, 35.2);   // x, y, w, h of the quad in 2D local px
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);      // u0, v0, u1, v1 of the atlas cell
uniform vec4 tint = vec4(1.0);                          // rgb multiplies the texture; a fades every mode
uniform float max_lod = 1.25;
uniform float bias_m = 0.3;
uniform int line_count = 0;
uniform vec4 lines[4];                                  // x0, x1, width, softness px (horizontal lines on y = 0)
uniform vec4 line_colors[4];
uniform vec4 head_dot = vec4(0.0);                      // x, y, radius (radius 0 disables)
uniform vec4 head_dot_color = vec4(1.0);
uniform float taper = 0.0;                              // line set: 1 = taper width and fade alpha toward x0 (tail)

void vertex() {
	VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Coverage of a signed distance (negative inside) with a one-pixel soft edge.
float pj_cov(float d, float aa) {
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

float pj_circle(vec2 p, vec2 c, float r) {
	return length(p - c) - r;
}

float pj_edge(vec2 p, vec2 a, vec2 b, vec2 inside) {
	vec2 n = normalize(vec2(b.y - a.y, a.x - b.x));
	if (dot(n, inside - a) > 0.0) { n = -n; }
	return dot(n, p - a);
}

float pj_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 m = (a + b + c) / 3.0;
	return max(max(pj_edge(p, a, b, m), pj_edge(p, b, c, m)), pj_edge(p, c, a, m));
}

float pj_quad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 m = (a + b + c + d) * 0.25;
	return max(max(pj_edge(p, a, b, m), pj_edge(p, b, c, m)), max(pj_edge(p, c, d, m), pj_edge(p, d, a, m)));
}

float pj_hline(vec2 p, float x0, float x1, float y, float w) {
	vec2 c = vec2((x0 + x1) * 0.5, y);
	vec2 h = vec2(abs(x1 - x0) * 0.5, w * 0.5);
	vec2 q = abs(p - c) - h;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// Right half of a ring (Projectile "wave": draw_arc from -PI/2 to PI/2).
float pj_half_arc(vec2 p, vec2 c, float r) {
	vec2 q = p - c;
	if (q.x >= 0.0) { return abs(length(q) - r); }
	return min(length(q - vec2(0.0, r)), length(q + vec2(0.0, r)));
}

// Premultiplied "over".
vec4 pj_over(vec4 dst, vec4 col, float cov) {
	float a = col.a * cov;
	return vec4(col.rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

vec4 pj_shape(vec2 p, float aa) {
	float s = size_px;
	vec4 o = vec4(0.0);
	vec4 c = color;
	if (shape == 0) {
		o = pj_over(o, vec4(c.rgb, 0.35), pj_cov(pj_circle(p, vec2(0.0), s * 1.7), aa));
		o = pj_over(o, c, pj_cov(pj_circle(p, vec2(0.0), s), aa));
		o = pj_over(o, vec4(1.0, 1.0, 1.0, 0.75), pj_cov(pj_circle(p, vec2(0.0), s * 0.5), aa));
	} else if (shape == 1) {
		o = pj_over(o, vec4(c.rgb, 0.3), pj_cov(pj_circle(p, vec2(0.0), s * 1.3), aa));
		o = pj_over(o, vec4(1.0), pj_cov(pj_hline(p, -s * 1.4, s * 1.2, 0.0, 2.0), aa));
		o = pj_over(o, c, pj_cov(pj_tri(p, vec2(s * 2.0, 0.0), vec2(s * 0.8, s * 0.7), vec2(s * 0.8, -s * 0.7)), aa));
		o = pj_over(o, vec4(c.rgb, 0.8), pj_cov(pj_tri(p, vec2(-s * 1.6, 0.0), vec2(-s * 0.8, s * 0.5), vec2(-s * 0.8, -s * 0.5)), aa));
	} else if (shape == 2) {
		o = pj_over(o, vec4(1.0, 0.4, 0.0, 0.3), pj_cov(pj_circle(p, vec2(0.0), s * 2.0), aa));
		o = pj_over(o, vec4(1.0, 0.5, 0.1, 0.6), pj_cov(pj_circle(p, vec2(0.0), s * 1.4), aa));
		o = pj_over(o, c, pj_cov(pj_circle(p, vec2(0.0), s), aa));
		o = pj_over(o, vec4(1.0, 1.0, 0.7, 0.95), pj_cov(pj_circle(p, vec2(0.0), s * 0.5), aa));
		o = pj_over(o, vec4(1.0, 0.3, 0.0, 0.5), pj_cov(pj_tri(p, vec2(-s * 2.5, 0.0), vec2(-s * 0.3, s * 0.6), vec2(-s * 0.3, -s * 0.6)), aa));
	} else if (shape == 3) {
		o = pj_over(o, vec4(c.rgb, 0.3), pj_cov(pj_circle(p, vec2(0.0), s * 1.6), aa));
		o = pj_over(o, c, pj_cov(pj_quad(p, vec2(s * 1.8, 0.0), vec2(0.0, s * 0.5), vec2(-s * 1.2, 0.0), vec2(0.0, -s * 0.5)), aa));
		o = pj_over(o, vec4(1.0, 1.0, 1.0, 0.9), pj_cov(pj_circle(p, vec2(0.0), s * 0.6), aa));
	} else if (shape == 4) {
		o = pj_over(o, vec4(c.rgb, 0.4), pj_cov(pj_circle(p, vec2(0.0), s * 1.8), aa));
		o = pj_over(o, c, pj_cov(pj_quad(p, vec2(s * 1.7, 0.0), vec2(0.0, s), vec2(-s * 1.2, 0.0), vec2(0.0, -s)), aa));
		o = pj_over(o, vec4(1.0, 1.0, 1.0, 0.9), pj_cov(pj_quad(p, vec2(s * 0.9, 0.0), vec2(0.0, s * 0.5), vec2(-s * 0.6, 0.0), vec2(0.0, -s * 0.5)), aa));
	} else if (shape == 5) {
		float d = pj_half_arc(p, vec2(-10.0, 0.0), s);
		o = pj_over(o, vec4(c.rgb, 0.3), pj_cov(d - 8.0, aa));
		o = pj_over(o, c, pj_cov(d - 3.0, aa));
	} else if (shape == 6) {
		float d = min(min(pj_circle(p, vec2(-3.0, -4.0), s * 0.55), pj_circle(p, vec2(3.0, -4.0), s * 0.55)),
				pj_tri(p, vec2(-9.0, -3.0), vec2(9.0, -3.0), vec2(0.0, 10.0)));
		o = pj_over(o, c, pj_cov(d, aa));
	}
	return o;
}

vec4 pj_lines(vec2 p, float aa) {
	vec4 o = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		if (i >= line_count) { break; }
		vec4 l = lines[i];
		// Tail taper: 0 at the tail (x0) .. 1 at the head (x1). Width narrows and alpha fades toward the tail.
		float k = clamp((p.x - l.x) / max(l.y - l.x, 0.001), 0.0, 1.0);
		float w = l.z * mix(1.0, mix(0.3, 1.0, k), taper);
		float fade = mix(1.0, smoothstep(0.0, 0.85, k) * k, taper);
		vec4 lc = line_colors[i];
		lc.a *= fade;
		// softness > 0 turns the bar into a gradient that fades out across its width (art glow band).
		o = pj_over(o, lc, pj_cov(pj_hline(p, l.x, l.y, 0.0, w) + l.w * 0.5, max(aa, l.w)));
	}
	if (head_dot.z > 0.0) {
		o = pj_over(o, head_dot_color, pj_cov(pj_circle(p, head_dot.xy, head_dot.z), aa));
	}
	return o;
}

void fragment() {
	vec4 o;
	if (shape < 0) {
		vec2 uv = mix(region_uv.xy, region_uv.zw, UV);
		vec4 t = textureLod(tex, uv, v3d_lod(uv, vec2(textureSize(tex, 0)), max_lod));
		o = vec4(t.rgb * tint.rgb * t.a, t.a);
	} else {
		vec2 p = box_px.xy + UV * box_px.zw;
		float aa = max(length(fwidth(p)), 0.001);
		o = shape >= 10 ? pj_lines(p, aa) : pj_shape(p, aa);
	}
	float a = o.a * tint.a;
	if (a < 0.003) { discard; }
	ALBEDO = v3d_albedo(o.rgb / max(o.a, 0.0001));
	ALPHA = a;
}
