shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Objective glow (W3-POLISH): fountain halos lying on the deck and the hot cores of the structure crystals.
// A soft radial blob whose colour is pushed above 1.0 (energy) so the environment glow (hdr_threshold 1.0)
// blooms it. billboard = true turns the quad to the camera and pulls it bias_m toward the camera along its
// view ray (same pixel, nearer depth: it never z-fights the card behind it).
// Final polish: mode 1 is a missile streak (ProjectileView3D "Glow" layer): the quad maps onto box_px in the
// projectile's 2D local px space (+X = travel); a tapered gaussian band from streak.x (tail) to streak.y (head),
// streak.z half-thickness at the head, and a hot head of radius streak.w with a white-hot centre. The CPU keeps
// these at a minimum on-screen size, so thin authored missiles always read. mode 2 is a soft halo with a ring
// lift (objective halo cards: a wide falloff plus a faint rim so the bloom reads even with glow off).
// Colour maths in display space, then v3d_albedo (colour contract).
uniform vec3 color = vec3(1.0);
uniform float energy = 1.5;
uniform float alpha = 1.0;
uniform float falloff = 2.2;          // higher = tighter core
uniform bool billboard = false;
uniform float bias_m = 0.0;
uniform int mode = 0;                 // 0 radial blob, 1 missile streak, 2 objective halo
uniform vec4 box_px = vec4(-20.0, -10.0, 40.0, 20.0);   // mode 1: x, y, w, h of the quad in 2D local px
uniform vec4 streak = vec4(-16.0, 12.0, 4.0, 5.0);      // mode 1: tail x, head x, head half-thickness, head radius
uniform vec3 core_color = vec3(1.0, 0.98, 0.92);        // mode 1: white-hot centre of the head

void vertex() {
	if (billboard) {
		vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		VERTEX = centre + vec3(VERTEX.x * sx, VERTEX.y * sy, 0.0);
		VERTEX = v3d_ray_bias(VERTEX, bias_m);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		VERTEX = v3d_ray_bias((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, bias_m);
		NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (mode == 1) {
		// Same mapping as projectile_shape: UV (0, 0) is box_px.xy (the 2D top-left, tail side).
		vec2 p = box_px.xy + UV * box_px.zw;
		float len = max(streak.y - streak.x, 0.001);
		float k = clamp((p.x - streak.x) / len, 0.0, 1.0);          // 0 tail .. 1 head
		float hw = max(streak.z * mix(0.3, 1.0, k * k), 0.001);       // band tapers toward the tail
		float dx = p.x - clamp(p.x, streak.x, streak.y);
		float d2 = (dx * dx + p.y * p.y) / (hw * hw);
		float band = exp(-1.6 * d2) * mix(0.1, 0.85, smoothstep(0.0, 1.0, k));
		vec2 h = p - vec2(streak.y, 0.0);
		h.x *= p.x > streak.y ? 1.0 : 0.65;                          // head is a little elongated backwards
		float hr = max(streak.w, 0.001);
		float hd = dot(h, h) / (hr * hr);
		float head = exp(-1.4 * hd);
		float hot = exp(-6.0 * hd);
		vec3 c = color * (band + head) + core_color * hot * 1.4;
		float a = clamp(band + head + hot, 0.0, 1.0) * alpha;
		ALBEDO = v3d_albedo(min(c / max(band + head + hot, 0.001), vec3(1.0))) * energy;
		ALPHA = a;
	} else if (mode == 2) {
		float r = length(UV * 2.0 - 1.0);
		float soft = pow(clamp(1.0 - r, 0.0, 1.0), falloff);
		float rim = exp(-pow((r - 0.55) / 0.16, 2.0)) * 0.18;
		ALBEDO = v3d_albedo(color) * energy;
		ALPHA = clamp((soft + rim) * alpha, 0.0, 1.0);
	} else {
		float r = length(UV * 2.0 - 1.0);
		float k = pow(clamp(1.0 - r, 0.0, 1.0), falloff);
		ALBEDO = v3d_albedo(color) * energy;
		ALPHA = clamp(k * alpha, 0.0, 1.0);
	}
}
