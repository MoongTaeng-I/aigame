shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 shake_uv = vec2(0.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(0.64,0.3,1.0,1.0);
void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV + shake_uv);
	COLOR = vec4(mix(source.rgb, flash_color.rgb, flash), source.a);
}
