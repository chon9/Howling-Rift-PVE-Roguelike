shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Beam ribbon (W2-PROJ). UV.x runs along the beam (0 at the caster), UV.y across it. One SpellArt.missiles
// cell is tiled every tile_m metres and scrolled by `scroll` tiles (driven from the host clock on the CPU so it
// freezes while paused), on top of the 2D beam's three colour lines (glow, body, tinted core).
// ground_mode = 1: the flat hit-band quad on the deck: a faint tinted fill and a thin rim, no texture.
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);   // u0, v0, u1, v1 of the missile cell
uniform vec4 tint = vec4(1.0);                       // a = life / 0.4
uniform vec4 core_color = vec4(1.0);                 // Beam.color (display space)
uniform float length_m = 1.0;
uniform float tile_m = 2.0;
uniform float scroll = 0.0;
uniform float max_lod = 1.25;
uniform float bias_m = 0.3;
uniform int ground_mode = 0;

void vertex() {
	VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float along = UV.x * length_m / tile_m - scroll;
	vec2 cell = vec2(fract(along), UV.y);
	vec2 uv = mix(region_uv.xy, region_uv.zw, cell);
	vec2 tex_size = vec2(textureSize(tex, 0));
	vec4 t = textureLod(tex, uv, v3d_lod(uv, tex_size, max_lod));
	float across = abs(UV.y - 0.5) * 2.0;           // 0 centre .. 1 edge
	float aa = max(fwidth(across), 0.001);
	vec3 c;
	if (ground_mode == 1) {
		// Hit band on the deck: a barely-there fill plus a thin tinted rim (no opaque white strip).
		float rim = smoothstep(0.78, 0.9, across) * (1.0 - smoothstep(0.93, 1.0, across));
		float fill = 0.07 * (1.0 - smoothstep(0.2, 0.95, across));
		c = core_color.rgb * (fill + 0.32 * rim);
	} else {
		// Additive light on a bright deck saturates quickly: the 2D line alphas (0.2 glow, 1 body, 1 white core)
		// are scaled well down and the edges fall off softly so the beam reads as a laser, not as a wall.
		float edge = 1.0 - smoothstep(0.45, 1.0, across);
		float glow = 0.05;
		float body = 0.14 * clamp((0.5 - across) / aa + 0.5, 0.0, 1.0);
		float core = 0.26 * clamp((0.12 - across) / aa + 0.5, 0.0, 1.0);
		c = (t.rgb * t.a * 0.42 + core_color.rgb * (glow + body)) * edge + mix(core_color.rgb, vec3(1.0), 0.6) * core;
	}
	// Soften the two ends so the tiles do not stop on a hard edge.
	float ends = smoothstep(0.0, 0.02, UV.x) * (1.0 - smoothstep(0.97, 1.0, UV.x));
	ALBEDO = v3d_albedo(clamp(c, vec3(0.0), vec3(1.0)));
	ALPHA = clamp(tint.a, 0.0, 1.0) * ends;
}
