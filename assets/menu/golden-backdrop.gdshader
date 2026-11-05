shader_type canvas_item;
void fragment() {
 // Retain the entire splash on ultrawide displays; fade its side edges into navy.
 COLOR.a *= smoothstep(0.0,0.04,UV.x)*smoothstep(0.0,0.04,1.0-UV.x);
}
