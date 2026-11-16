shader_type canvas_item;
uniform float sweep = -1.0;
uniform float width = 0.12;
uniform float strength = 0.6;
uniform float tilt = 0.15;
void fragment() {
	vec4 base = texture(TEXTURE,UV);
	float shine = max(0.0,1.0-abs(UV.x-UV.y*tilt-sweep)/width)*strength;
	COLOR *= vec4(base.rgb+vec3(shine),base.a);
}
