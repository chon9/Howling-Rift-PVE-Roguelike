shader_type spatial;
#include "res://assets/shaders/view3d/view3d_common.gdshaderinc"
// Faceted ice (W3 fix): base-to-tip colour gradient on the 1 m crystal mesh (local y 0..1), per-facet and
// per-instance tint from hashes (MultiMesh: the instance origin seeds it), internal frost streaks, a fresnel
// rim and an emission that glows mostly at the tips. Replaces the constant-colour StandardMaterial3D that
// made every crystal a flat blue cone. Colour maths in display space, then v3d_albedo (colour contract).
uniform vec3 deep_color = vec3(0.07, 0.16, 0.32);
uniform vec3 tip_color = vec3(0.55, 0.80, 1.0);
uniform vec3 rim_color = vec3(0.78, 0.93, 1.0);
uniform float glow = 0.35;           // tip emission strength
uniform float rim_strength = 0.55;
varying float h;
varying vec3 lpos;
varying float inst;
varying vec3 wnorm;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	h = clamp(VERTEX.y, 0.0, 1.0);
	lpos = VERTEX;
	inst = hash13(MODEL_MATRIX[3].xyz * 7.31);
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float facet = hash13(floor(wnorm * 6.0 + 6.5));
	vec3 c = mix(deep_color, tip_color, smoothstep(0.05, 1.0, h));
	c *= 0.78 + 0.34 * facet;
	c *= 0.88 + 0.24 * inst;
	// Frost streaks running up the crystal.
	float streak = 0.5 + 0.5 * sin(h * 19.0 + lpos.x * 11.0 + lpos.z * 7.0 + inst * 6.28);
	c += vec3(0.07, 0.1, 0.14) * streak * h;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c = mix(c, rim_color, fres * rim_strength);
	ALBEDO = v3d_albedo(c);
	ROUGHNESS = 0.15;
	SPECULAR = 0.75;
	EMISSION = v3d_albedo(tip_color * glow * (0.15 + 0.85 * h * h) * (0.65 + 0.35 * facet) + rim_color * fres * glow * 0.4);
}
