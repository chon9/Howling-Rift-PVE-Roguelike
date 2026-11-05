shader_type spatial;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Abyss floor far below the bridge (W1-ARENA): rift-chasm.png tiled (uv_scale), tinted and darkened with
// view depth so the drop reads as deep. Colour maths in display space, then v3d_albedo.
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;   // rift-chasm.png (raw)
uniform vec2 uv_scale = vec2(12.0, 8.0);
uniform vec3 tint = vec3(0.3, 0.34, 0.44);   // dark: off-lane space recedes (height fog does the rest)
uniform float near_m = 20.0;
uniform float far_m = 70.0;
uniform float far_dark = 0.35;
uniform vec2 bridge_z = vec2(0.4, 10.4);   // metres: the strip under the bridge is shaded darker
uniform float under_dark = 0.55;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV * uv_scale).rgb * tint;
	float d = length(VERTEX);
	c *= mix(1.0, far_dark, smoothstep(near_m, far_m, d));
	float under = smoothstep(bridge_z.x - 3.0, bridge_z.x + 1.0, wpos.z) * (1.0 - smoothstep(bridge_z.y - 1.0, bridge_z.y + 3.0, wpos.z));
	c *= mix(1.0, under_dark, under);
	ALBEDO = v3d_albedo(c);
	ROUGHNESS = 1.0;
}
