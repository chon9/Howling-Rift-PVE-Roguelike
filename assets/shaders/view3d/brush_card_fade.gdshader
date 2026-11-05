shader_type spatial;
render_mode cull_disabled, depth_draw_never;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// See-through variant of brush_card.gdshader for the patch the local player stands in (WorldBuilder3D
// swaps material_override): smooth alpha blend at `fade`, no screen-door dither, no shadow casting.
#define BRUSH_FADED
#include "res://assets/shaders/view3d/brush_card.gdshaderinc"
