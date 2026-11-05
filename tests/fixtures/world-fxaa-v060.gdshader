shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world : hint_screen_texture, repeat_disable, filter_linear;
// Directional FXAA: skip flat regions and blend only along contrasting edges.
float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
 vec2 px = SCREEN_PIXEL_SIZE;
 vec2 uv = SCREEN_UV;
 vec3 center = texture(world, uv).rgb;
 vec3 nw = texture(world, uv + vec2(-1.0,-1.0)*px).rgb;
 vec3 ne = texture(world, uv + vec2(1.0,-1.0)*px).rgb;
 vec3 sw = texture(world, uv + vec2(-1.0,1.0)*px).rgb;
 vec3 se = texture(world, uv + vec2(1.0,1.0)*px).rgb;
 float m = luminance(center);
 float a = luminance(nw), b = luminance(ne), c = luminance(sw), d = luminance(se);
 float lo = min(m,min(min(a,b),min(c,d)));
 float hi = max(m,max(max(a,b),max(c,d)));
 vec3 result = center;
 if (hi-lo > max(0.0312, hi*0.125)) {
  vec2 direction = vec2(-(a+b-c-d), a+c-b-d);
  float reduce = max((a+b+c+d)*0.03125, 0.0078125);
  direction = clamp(direction/(min(abs(direction.x),abs(direction.y))+reduce),vec2(-8.0),vec2(8.0))*px;
  vec3 inner = 0.5*(texture(world,uv-direction/6.0).rgb+texture(world,uv+direction/6.0).rgb);
  vec3 outer = inner*0.5+0.25*(texture(world,uv-direction*0.5).rgb+texture(world,uv+direction*0.5).rgb);
  float l = luminance(outer);
  result = (l < lo || l > hi) ? inner : outer;
 }
 COLOR = vec4(result,1.0);
}
