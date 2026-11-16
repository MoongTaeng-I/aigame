shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float strength = 0.0;
uniform float width = 0.4;
void fragment() {
	float edge = smoothstep(1.0-width,1.0,length((UV-vec2(0.5))*2.0));
	COLOR = vec4(tint.rgb,edge*strength);
}
