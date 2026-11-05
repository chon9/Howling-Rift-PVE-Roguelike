shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// W2-EXTRAS: additive unit-attached effects (UnitExtras3D).
//   mode 0: atlas card (wind wall). Samples tex inside region_uv (u_min, v_min, u_max, v_max), mip-clamped.
//   mode 1: procedural light pillar on an open cylinder (recall, level-up): vertical fade plus
//           streaks that scroll upward with `phase` (host.anim_time, so it freezes while paused).
// Colour contract: raw samples, display-space maths, ALBEDO = v3d_albedo(c). No source_color.
uniform int mode = 0;
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint = vec4(1.0);
uniform float max_lod = 1.25;
uniform float height_m = 2.6;
uniform float phase = 0.0;
uniform float scroll = 1.2;
uniform float streaks = 10.0;
varying float hn;

void vertex() {
	// 0 at the pillar foot, 1 at its top (cylinder meshes are centred on their origin).
	hn = clamp(VERTEX.y / max(height_m, 0.001) + 0.5, 0.0, 1.0);
}

void fragment() {
	if (mode == 0) {
		vec2 uv = mix(region_uv.xy, region_uv.zw, UV);
		vec2 ts = vec2(textureSize(tex, 0));
		vec4 t = textureLod(tex, uv, v3d_lod(uv, ts, max_lod));
		ALBEDO = v3d_albedo(t.rgb * tint.rgb);
		ALPHA = t.a * tint.a;
	} else {
		float fade_top = 1.0 - smoothstep(0.3, 1.0, hn);
		float fade_foot = smoothstep(0.0, 0.14, hn);   // soft foot: the pillar is screen-upright (card_up axis)
		float s = fract(UV.x * streaks + 0.12 * sin(hn * 6.0 + phase * 2.0));
		float band = smoothstep(0.0, 0.2, s) * (1.0 - smoothstep(0.45, 0.75, s));
		float rise = fract(hn * 2.5 - phase * scroll);
		float pulse = 0.55 + 0.45 * smoothstep(0.55, 1.0, rise);
		float glow = (0.35 + 0.65 * band) * pulse * fade_top * fade_foot;
		ALBEDO = v3d_albedo(tint.rgb);
		ALPHA = clamp(glow * tint.a * 1.5, 0.0, 1.0);
	}
}
