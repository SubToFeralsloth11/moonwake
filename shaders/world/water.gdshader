shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Calm night ocean: gentle vertex swell, analytic ripple normals, depth tint,
// screen refraction and shoreline foam.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 deep_col : source_color = vec3(0.01, 0.035, 0.07);
uniform vec3 shallow_col : source_color = vec3(0.04, 0.16, 0.2);
uniform vec3 foam_col : source_color = vec3(0.75, 0.82, 0.9);
uniform float swell = 0.09;

varying vec3 wpos;

float hsh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1, 0)), f.x), mix(hsh(i + vec2(0, 1)), hsh(i + vec2(1, 1)), f.x), f.y);
}

// Sum of directional sines; returns height, writes slope (dh/dx, dh/dz).
float waves(vec2 p, float t, int count, out vec2 slope) {
	float h = 0.0;
	slope = vec2(0.0);
	float amp = 1.0;
	float freq = 0.32;
	float ang = 0.4;
	for (int i = 0; i < count; i++) {
		vec2 dir = vec2(cos(ang), sin(ang));
		float ph = dot(dir, p) * freq + t * sqrt(9.8 * freq) * 0.9;
		h += amp * sin(ph);
		slope += amp * freq * cos(ph) * dir;
		amp *= 0.62;
		freq *= 1.73;
		ang += 2.39;
	}
	return h;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 sl;
	float h = waves(wpos.xz, TIME, 4, sl);
	VERTEX.y += h * swell;
	wpos.y += h * swell;
}

void fragment() {
	vec2 sl;
	waves(wpos.xz, TIME, 9, sl);
	sl *= swell;
	vec2 rip = vec2(vn(wpos.xz * 1.8 + TIME * 0.35) - vn(wpos.xz * 1.8 + vec2(3.1, 1.7) - TIME * 0.3), vn(wpos.zx * 2.3 + TIME * 0.25) - vn(wpos.zx * 2.1 - TIME * 0.32));
	sl += rip * 0.06;
	vec3 nw = normalize(vec3(-sl.x, 1.0, -sl.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vp.xyz /= vp.w;
	float thick = max(0.0, -vp.z + VERTEX.z);

	vec2 ruv = SCREEN_UV + NORMAL.xz * 0.025 * clamp(thick, 0.0, 1.0);
	float rdepth = texture(depth_tex, ruv).r;
	vec4 rvp = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, rdepth, 1.0);
	rvp.xyz /= rvp.w;
	if (rvp.z > VERTEX.z) {
		ruv = SCREEN_UV;
	}
	vec3 refr = textureLod(screen_tex, ruv, 1.5).rgb;
	float trans = exp(-thick * 0.9);
	vec3 body = mix(deep_col, shallow_col, exp(-thick * 0.35));
	float edge = 1.0 - smoothstep(0.0, 0.55, thick);
	float foam_n = vn(wpos.xz * 4.0 + TIME * 0.4) * vn(wpos.xz * 9.0 - TIME * 0.3);
	float band = 0.5 + 0.5 * sin(thick * 18.0 - TIME * 2.2);
	float foam = clamp(edge * (0.55 + 0.6 * foam_n) * mix(0.6, 1.0, band), 0.0, 1.0);
	foam = smoothstep(0.25, 0.7, foam);

	ALBEDO = mix(body * (1.0 - trans), foam_col * 0.45, foam);
	EMISSION = refr * trans * shallow_col * 4.0 * (1.0 - foam);
	ROUGHNESS = mix(0.045, 0.8, foam);
	SPECULAR = 0.65;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
