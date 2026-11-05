// Shared helpers for every view3d spatial shader. Verified on Godot 4.7.2 (gl_compatibility + forward_plus).
// Colour contract: sample textures WITHOUT source_color, do all colour maths in display (sRGB) space,
// then write ALBEDO = v3d_albedo(colour). Never use source_color on samplers or uniforms.
vec3 v3d_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
vec3 v3d_albedo(vec3 display_rgb) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return display_rgb;
#else
	return v3d_srgb_to_linear(display_rgb);
#endif
}
// Same maths as assets/minions/team-cloth.gdshader (display space).
vec3 v3d_cloth(vec3 c, bool red_team) {
	float mask = smoothstep(0.06, 0.22, c.b - c.r) * smoothstep(0.0, 0.08, c.b - c.g);
	float light = max(c.b, c.g);
	return mix(c, vec3(light, light * 0.20, light * 0.16), red_team ? mask : 0.0);
}
bool v3d_excluded(vec2 uv, int count, vec4 rects[8]) {
	for (int i = 0; i < count; i++) {
		vec4 r = rects[i];
		if (uv.x >= r.x && uv.y >= r.y && uv.x <= r.z && uv.y <= r.w) { return true; }
	}
	return false;
}
// Mip level clamp against atlas-cell bleed: lod from pixel-space derivatives, clamped to max_lod.
float v3d_lod(vec2 uv, vec2 tex_size, float max_lod) {
	vec2 px = uv * tex_size;
	return clamp(0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))), 0.0, max_lod);
}
// Premultiplied ground-overlay composite (SubViewport stores premultiplied display colour).
vec3 v3d_overlay(vec3 base_display, vec4 overlay) {
	return base_display * (1.0 - overlay.a) + overlay.rgb;
}
// Move a view-space position toward the camera along its own view ray: same pixel, nearer depth.
// Valid for the perspective Camera3D only.
vec3 v3d_ray_bias(vec3 view_pos, float metres) {
	float l = length(view_pos);
	return view_pos * (max(l - metres, 0.05) / max(l, 0.0001));
}
