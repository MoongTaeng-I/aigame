shader_type canvas_item;
uniform sampler2D source_atlas : source_color, filter_linear;
uniform vec4 frame_uv = vec4(0.0,0.0,1.0,1.0);
uniform vec2 body_size = vec2(1.0);
uniform vec2 canvas_size = vec2(1.0);
uniform vec2 padding = vec2(0.0);
uniform float aura_px = 6.0;
uniform float flame_px = 14.0;
uniform float aura_alpha = 0.75;
uniform float flicker_hz = 2.5;
uniform float aura_time = 0.0;
uniform float noise_scale = 0.09;
uniform float core_spread_ratio = 0.5;
uniform float core_flame_ratio = 0.3;
uniform vec4 aura_color : source_color = vec4(0.478,0.361,1.0,1.0);
uniform vec4 core_color : source_color = vec4(0.788,0.722,1.0,1.0);

float source_alpha(vec2 point) {
	vec2 uv = point/body_size;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return 0.0; }
	vec2 inset = vec2(0.5)/vec2(textureSize(source_atlas,0));
	vec2 atlas_uv = clamp(frame_uv.xy+uv*frame_uv.zw,frame_uv.xy+inset,frame_uv.xy+frame_uv.zw-inset);
	return texture(source_atlas,atlas_uv).a;
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float b = fract(sin(dot(cell+vec2(1.0,0.0),vec2(127.1,311.7)))*43758.5453);
	float c = fract(sin(dot(cell+vec2(0.0,1.0),vec2(127.1,311.7)))*43758.5453);
	float d = fract(sin(dot(cell+vec2(1.0),vec2(127.1,311.7)))*43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void fragment() {
	vec2 point = UV*canvas_size-padding;
	float original = source_alpha(point);
	float flow = noise(point*noise_scale+vec2(0.0,aura_time*flicker_hz));
	float lift = flame_px*flow;
	float outer = 0.0;
	float core = 0.0;
	for (int i=0; i<16; i++) {
		float angle = 6.28318530718*float(i)/16.0;
		vec2 offset = vec2(cos(angle),sin(angle))*aura_px;
		outer = max(outer,source_alpha(point+offset));
		outer = max(outer,source_alpha(point+offset+vec2(0.0,lift)));
		core = max(core,source_alpha(point+offset*core_spread_ratio+vec2(0.0,lift*core_flame_ratio)));
	}
	vec3 color = mix(aura_color.rgb,core_color.rgb,core);
	COLOR = vec4(color,original>0.001 ? 0.0 : outer*aura_alpha);
}
