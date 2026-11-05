shader_type canvas_item;
void fragment(){
 vec4 pixel=texture(TEXTURE,UV);
 pixel.a*=1.0-smoothstep(0.60,1.0,UV.x);
 COLOR=pixel*COLOR;
}
