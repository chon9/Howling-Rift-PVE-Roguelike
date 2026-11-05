shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Soft sunbeam crossing the arena: an additive card, brightest near the top, fading along its length and at both
// sides, slowly breathing. The clock comes from WorldBuilder3D so it freezes with the game.
uniform vec3 color = vec3(1.0, 0.82, 0.55);
uniform float alpha = 0.07;
uniform float shaft_time = 0.0;
uniform float phase = 0.0;

void fragment() {
	float across = sin(UV.x * 3.14159);
	float along = smoothstep(0.0, 0.2, UV.y) * (1.0 - smoothstep(0.35, 1.0, UV.y));
	float breathe = 0.72 + 0.28 * sin(shaft_time * 0.35 + phase);
	ALBEDO = v3d_albedo(color);
	ALPHA = across * across * along * alpha * breathe;
}
