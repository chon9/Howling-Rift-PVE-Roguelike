// Shared body of brush_card.gdshader (opaque, alpha scissor) and brush_card_fade.gdshader (the patch the
// local player stands in: smooth alpha blend). Include after view3d_common.gdshaderinc; define
// BRUSH_FADED first for the blended variant. Each instance samples a horizontal slice of frost-brush-v1.png
// given by INSTANCE_CUSTOM (u0, v0, du, dv), shaped into a dome by a soft procedural silhouette.
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;   // frost-brush-v1.png (raw)
uniform vec3 tint = vec3(0.78, 0.9, 0.9);
uniform float fade = 1.0;
uniform float bottom_shade = 0.78;
uniform float brightness = 1.12;
uniform float lod_bias = 0.6;   // slightly softer mips: calms the high-frequency leaf noise
// W3-POLISH sway: the card tops lean back and forth (sway_hz, sway_m metres at the top, quadratic with
// height so the base stays planted). sway_time is the host's anim_time (frozen while paused); sway_m is 0
// on Low quality. Each card gets its own phase from its world position and slice seed.
uniform float sway_time = 0.0;
uniform float sway_hz = 1.3;
uniform float sway_m = 0.04;
varying vec4 slice;
varying vec3 inst_tint;
varying float seed;

void vertex() {
	slice = INSTANCE_CUSTOM;
	inst_tint = COLOR.rgb;
	seed = fract(INSTANCE_CUSTOM.x * 13.7 + INSTANCE_CUSTOM.y * 7.3);
	if (sway_m > 0.0) {
		float h = clamp(VERTEX.y, 0.0, 1.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float ph = sway_time * 6.2831853 * sway_hz + origin.x * 0.9 + origin.z * 0.6 + seed * 6.2831853;
		// Mostly sideways (screen x) with a smaller, slower fore-aft component: reads as wind, not a wobble.
		vec3 off = vec3(sin(ph), 0.0, 0.35 * sin(ph * 0.77 + 1.3)) * (sway_m * h * h);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	}
}

void fragment() {
	vec2 suv = slice.xy + UV * slice.zw;
	vec4 t = texture(tex, suv, lod_bias);
	// Dome silhouette: lower at the sides, with a few gentle bumps along the top edge.
	float x = UV.x * 2.0 - 1.0;
	float top = 0.12 + 0.55 * pow(abs(x), 2.5) + 0.05 * abs(sin(UV.x * 5.0 + seed * 6.2831));
	float sil = smoothstep(top - 0.05, top + 0.05, UV.y);
	float a = t.a * sil;
	vec3 c = t.rgb * tint * inst_tint * brightness;
	c *= mix(1.0, bottom_shade, smoothstep(0.35, 1.0, UV.y));
	ALBEDO = v3d_albedo(clamp(c, 0.0, 1.0));
#ifdef BRUSH_FADED
	ALPHA = smoothstep(0.25, 0.75, a) * fade;
#else
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
	// Lit like the ground: a world-up normal on both faces.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.95;
}
