shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world : hint_screen_texture, repeat_disable, filter_linear;
uniform float smoothing : hint_range(0.0, 1.0) = 0.45;
uniform float sharpness : hint_range(0.0, 1.0) = 0.35;
float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
 // Explicit base-level samples and offsets in physical framebuffer pixels.
 vec2 px = SCREEN_PIXEL_SIZE;
 vec2 uv = SCREEN_UV;
 vec3 center = textureLod(world, uv, 0.0).rgb;
 vec3 north = textureLod(world, uv + vec2(0.0,-1.0)*px, 0.0).rgb;
 vec3 south = textureLod(world, uv + vec2(0.0,1.0)*px, 0.0).rgb;
 vec3 east = textureLod(world, uv + vec2(1.0,0.0)*px, 0.0).rgb;
 vec3 west = textureLod(world, uv + vec2(-1.0,0.0)*px, 0.0).rgb;
 float m = luminance(center);
 float n = luminance(north), s = luminance(south), e = luminance(east), w = luminance(west);
 float lo = min(m,min(min(n,s),min(e,w)));
 float hi = max(m,max(max(n,s),max(e,w)));
 float contrast = hi-lo;
 vec3 result = center;
 if (smoothing > 0.0 && contrast > max(0.06, hi*0.18)) {
  // Follow the local edge tangent. Never average across a broad eight-pixel span.
  vec2 tangent = vec2(n-s, e-w);
  float magnitude = max(abs(tangent.x),abs(tangent.y));
  if (magnitude > 0.001) {
   vec2 direction = tangent/magnitude*px;
   vec3 aa = 0.5*(textureLod(world,uv-direction*0.5,0.0).rgb+textureLod(world,uv+direction*0.5,0.0).rgb);
   result = mix(center,aa,smoothing);
  }
 }
 // Restrained unsharp detail: attenuate at strong edges and clamp to local colors.
 // No overshoot halos, enlarged render target, temporal history or upscaling.
 vec3 minimum = min(center,min(min(north,south),min(east,west)));
 vec3 maximum = max(center,max(max(north,south),max(east,west)));
 float strength = sharpness*(1.0-smoothstep(0.25,0.75,contrast));
 vec3 detail = center-(north+south+east+west)*0.25;
 result = clamp(result+detail*strength,minimum,maximum);
 COLOR = vec4(result,1.0);
}
