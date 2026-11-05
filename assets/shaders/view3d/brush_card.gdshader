shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Upright crossed brush cards (W1-ARENA), one MultiMesh per BrushVision patch. Alpha scissor 0.5 keeps
// depth and shadows. The patch holding the local player swaps to brush_card_fade.gdshader (alpha blend).
#include "res://assets/shaders/view3d/brush_card.gdshaderinc"
