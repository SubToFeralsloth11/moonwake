shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float seed = 0.0;
uniform float sky_day = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.15;
	float n = fbm(uv * 3.0 + vec2(t, -t) + seed);
	float n2 = fbm(uv * 6.0 - vec2(t * 1.7, t) + seed * 2.0);
	vec3 deep = tint.rgb * 0.18;
	vec3 col = mix(deep, tint.rgb * 0.9, smoothstep(0.35, 0.8, n));
	// a glowing orb (sun or moon) in the art
	vec2 c = vec2(0.5 + sin(seed) * 0.2, 0.38);
	float d = length((uv - c) * vec2(1.0, 1.3));
	col += tint.rgb * smoothstep(0.22, 0.0, d) * 0.9 + vec3(1.0) * smoothstep(0.08, 0.0, d) * 0.6;
	// silhouette hills
	float h = 0.72 + 0.08 * sin(uv.x * 9.0 + seed * 3.0) + 0.05 * fbm(vec2(uv.x * 5.0, seed));
	col = mix(col, deep * 0.5, smoothstep(h, h + 0.01, uv.y));
	col += vec3(n2 * 0.12);
	ALBEDO = col;
}
