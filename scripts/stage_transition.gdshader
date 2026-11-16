shader_type canvas_item;
// threshold 0 = clear, 1 = fully covered. Edges cover first and the centre clears first.
uniform float threshold = 0.0;
uniform vec4 shade_color : source_color = vec4(0.043, 0.024, 0.094, 1.0);
uniform vec4 glow_color : source_color = vec4(0.478, 0.361, 1.0, 1.0);
uniform float band = 0.08;
uniform float noise_scale = 6.0;
uniform float noise_mix = 0.35;
uniform vec2 aspect = vec2(1.7778, 1.0);

// sin-based hashes lose precision on large cell ids and leave square seams; keep magnitudes small.
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.03) * 0.3 + noise(p * 4.01) * 0.2; }

void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	float radial = 1.0 - length(p) / length(0.5 * aspect);
	float field = mix(radial, fbm(UV * aspect * noise_scale), noise_mix);
	float cut = mix(-band, 1.0 + band, threshold);
	float edge = 1.0 - smoothstep(0.0, band, abs(field - cut));
	if (field < cut) {
		COLOR = vec4(mix(shade_color.rgb, glow_color.rgb, edge * 0.6), 1.0);
	} else {
		COLOR = vec4(glow_color.rgb, glow_color.a * edge);
	}
}
