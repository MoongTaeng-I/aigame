shader_type canvas_item;
uniform float blur_px = 0.0;
uniform float brightness = 1.0;
uniform float grayscale = 0.0;
void fragment() {
	vec2 d = TEXTURE_PIXEL_SIZE*blur_px;
	vec4 c = (texture(TEXTURE,UV)+texture(TEXTURE,UV+vec2(d.x,d.y))+texture(TEXTURE,UV-vec2(d.x,d.y))+texture(TEXTURE,UV+vec2(d.x,-d.y))+texture(TEXTURE,UV+vec2(-d.x,d.y)))/5.0;
	c.rgb = mix(c.rgb,vec3(dot(c.rgb,vec3(0.299,0.587,0.114))),grayscale)*brightness;
	COLOR *= c;
}
