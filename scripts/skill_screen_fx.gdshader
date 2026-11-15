shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 shake_uv = vec2(0.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(0.64,0.3,1.0,1.0);
uniform float slash_dim = 0.0;
uniform vec4 dim_color : source_color = vec4(0.086,0.149,0.353,1.0);
uniform float white_flash = 0.0;
uniform float fear_vignette = 0.0;
uniform float vignette_width = 0.4;
void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV + shake_uv);
	vec3 rgb = mix(source.rgb, dim_color.rgb, slash_dim);
	rgb = mix(rgb, flash_color.rgb, flash);
	rgb = mix(rgb, vec3(1.0), white_flash);
	float edge = smoothstep(1.0-vignette_width,1.0,length((SCREEN_UV-vec2(0.5))*2.0));
	rgb = mix(rgb, flash_color.rgb, edge*fear_vignette);
	COLOR = vec4(rgb, source.a);
}
