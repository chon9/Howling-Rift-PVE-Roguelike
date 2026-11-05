shader_type canvas_item;
uniform bool red_team = false;
uniform float hit_whiten = 0.0;
uniform int exclusion_count = 0;
uniform vec2 atlas_pixel_size = vec2(0.0);
uniform vec4 excluded_rects[8];
void fragment() {
 // Atlas mapping rejects fragments belonging to a neighboring action frame.
 if (distance(TEXTURE_PIXEL_SIZE,atlas_pixel_size)<0.000001) {
 for (int i=0; i<exclusion_count; i++) {
  vec4 r=excluded_rects[i];
  if (UV.x>=r.x && UV.y>=r.y && UV.x<=r.z && UV.y<=r.w) { discard; }
 }
 }
 vec4 tex = COLOR;
 // Recolor saturated blue cloth; retain the painted steel, leather and fur.
 float mask = smoothstep(0.06,0.22,tex.b-tex.r) * smoothstep(0.0,0.08,tex.b-tex.g);
 float light = max(tex.b, tex.g);
 vec3 red = vec3(light, light*0.20, light*0.16);
 vec3 painted=mix(tex.rgb, red, red_team ? mask : 0.0);
 COLOR = vec4(mix(painted,vec3(1.0,0.95,0.87),hit_whiten), tex.a);
}
