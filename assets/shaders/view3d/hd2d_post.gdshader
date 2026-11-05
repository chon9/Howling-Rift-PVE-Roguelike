shader_type canvas_item;
// HD-2D finish over the 3D world only (the overhead UI and HUD draw above this layer): a gentle diorama blur at the
// top and bottom of the screen, warm highlights over cool shadows, a soft bloom halo, and a vignette.
// Works the same in Compatibility and Forward+.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float tilt_px = 2.4;          // blur radius at the very edge of the screen
uniform float tilt_top = 0.2;         // blur ends this far down from the top
uniform float tilt_bottom = 0.86;     // blur starts this far down
uniform float bloom = 0.15;           // 0 turns the halo off
uniform float bloom_px = 7.0;
uniform float bloom_threshold = 0.72;
uniform float split_tone = 0.55;
uniform float contrast = 1.1;
uniform float saturation = 1.14;
uniform float vignette = 0.42;

const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.71, 0.71), vec2(0.0, 1.0), vec2(-0.71, 0.71), vec2(-1.0, 0.0), vec2(-0.71, -0.71), vec2(0.0, -1.0), vec2(0.71, -0.71));

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;
	float blur = max(1.0 - smoothstep(0.0, tilt_top, uv.y), smoothstep(tilt_bottom, 1.0, uv.y));
	if (blur > 0.02 && tilt_px > 0.0) {
		vec3 sum = col;
		for (int i = 0; i < 8; i++) { sum += texture(screen_tex, uv + RING[i] * px * tilt_px * blur).rgb; }
		col = sum / 9.0;
	}
	if (bloom > 0.0) {
		vec3 halo = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			vec3 s = texture(screen_tex, uv + RING[i] * px * bloom_px).rgb;
			halo += s * smoothstep(bloom_threshold, 1.0, max(s.r, max(s.g, s.b)));
		}
		col += halo / 8.0 * bloom;
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(vec3(1.0), vec3(0.9, 0.96, 1.12), (1.0 - smoothstep(0.0, 0.55, luma)) * split_tone);
	col *= mix(vec3(1.0), vec3(1.09, 1.0, 0.86), smoothstep(0.35, 1.0, luma) * split_tone);
	col = mix(vec3(luma), col, saturation);
	col = clamp((col - 0.5) * contrast + 0.5, 0.0, 1.5);
	vec2 d = (uv - vec2(0.5, 0.46)) * vec2(1.05, 1.2);
	col *= 1.0 - vignette * smoothstep(0.32, 0.86, length(d));
	COLOR = vec4(col, 1.0);
}
