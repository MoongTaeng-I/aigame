shader_type canvas_item;

uniform float hit_flash = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), hit_flash);
}
