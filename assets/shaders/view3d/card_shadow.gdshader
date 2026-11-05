shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Sun shadow of a painted card: an upright SHADOWS_ONLY copy of the card, cut to the art's silhouette with an alpha
// scissor so the shadow on the ground matches the current animation frame. Uniform names match unit_card.
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform int exclusion_count = 0;
uniform vec2 atlas_pixel_size = vec2(0.0);
uniform vec4 excluded_rects[8];
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float max_lod = 1.25;

void fragment() {
	if (v3d_excluded(UV, exclusion_count, excluded_rects)) { discard; }
	ALBEDO = vec3(0.0);
	ALPHA = textureLod(tex, UV, 1.0).a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
