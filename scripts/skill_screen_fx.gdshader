shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 shake_uv = vec2(0.0);
void fragment() { COLOR = texture(screen_texture, SCREEN_UV + shake_uv); }
