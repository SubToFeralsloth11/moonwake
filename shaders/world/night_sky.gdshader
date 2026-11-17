shader_type sky;
// Night sky: gradient, two star layers, milky-way band and a large glowing moon
// placed at the first DirectionalLight3D (the moonlight).

uniform vec3 zenith : source_color = vec3(0.012, 0.02, 0.055);
uniform vec3 horizon : source_color = vec3(0.07, 0.1, 0.2);
uniform vec3 moon_tint : source_color = vec3(1.0, 0.97, 0.88);
uniform float moon_radius = 0.075;
uniform float star_power = 1.0;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h31(vec3(i, 1.0));
	float b = h31(vec3(i + vec2(1, 0), 1.0));
	float c = h31(vec3(i + vec2(0, 1), 1.0));
	float d = h31(vec3(i + vec2(1, 1), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float stars(vec3 d, float scale, float density, float t) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	float h = h31(id);
	if (h < density) {
		return 0.0;
	}
	vec3 o = vec3(h31(id + 1.3), h31(id + 2.7), h31(id + 4.1)) * 0.6 + 0.2;
	float dist = length(fract(p) - o);
	float tw = 0.65 + 0.35 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.09, 0.0, dist) * (h - density) / (1.0 - density) * tw;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	float up = clamp(y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.45));
	col = mix(col, horizon * 0.5, smoothstep(0.0, -0.2, y));
	vec3 md = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.5, 0.4, -0.7));
	float cosang = dot(d, md);
	float ang = acos(clamp(cosang, -1.0, 1.0));
	// moon glow (also in reflections)
	col += vec3(0.35, 0.45, 0.7) * exp(-ang * 3.5) * 0.35;
	col += vec3(0.6, 0.7, 0.9) * exp(-ang * 14.0) * 0.5;
	if (!AT_CUBEMAP_PASS) {
		float horizon_fade = smoothstep(-0.02, 0.18, y);
		// milky way band
		vec3 bn = normalize(vec3(0.3, 0.6, 0.75));
		float band = exp(-pow(dot(d, bn) * 4.0, 2.0));
		vec2 bp = vec2(atan(d.x, d.z) * 3.0, d.y * 6.0);
		float cloud = n2(bp * 2.0) * 0.6 + n2(bp * 5.0) * 0.4;
		col += vec3(0.25, 0.22, 0.4) * band * cloud * 0.22 * horizon_fade;
		float s = stars(d, 160.0, 0.93, TIME) * 0.9 + stars(d, 320.0, 0.88, TIME * 1.3) * 0.5 + band * cloud * stars(d, 520.0, 0.8, TIME) * 0.6;
		col += vec3(0.9, 0.93, 1.0) * s * 2.5 * star_power * horizon_fade * smoothstep(moon_radius * 1.5, moon_radius * 5.0, ang);
		// moon disc with maria
		float disc = smoothstep(moon_radius, moon_radius * 0.96, ang);
		if (disc > 0.0) {
			vec3 tx = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
			vec3 ty = cross(tx, md);
			vec2 mp = vec2(dot(d, tx), dot(d, ty)) / moon_radius;
			float maria = n2(mp * 2.2 + 3.0) * 0.6 + n2(mp * 5.0) * 0.3 + n2(mp * 11.0) * 0.1;
			float limb = sqrt(max(0.0, 1.0 - dot(mp, mp)));
			vec3 mc = moon_tint * mix(0.62, 1.0, smoothstep(0.35, 0.6, maria)) * (0.55 + 0.45 * limb);
			col = mix(col, mc * 5.0, disc);
		}
	} else {
		col += moon_tint * smoothstep(moon_radius, moon_radius * 0.9, ang) * 3.0;
	}
	COLOR = col;
}
