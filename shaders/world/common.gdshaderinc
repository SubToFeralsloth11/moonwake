// Shared noise + bump helpers for the Moonwake world shaders.

float mw_hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 mw_hash22(vec2 p) {
	float n = mw_hash21(p);
	return vec2(n, mw_hash21(p + n + 17.0));
}

float mw_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mw_hash21(i);
	float b = mw_hash21(i + vec2(1.0, 0.0));
	float c = mw_hash21(i + vec2(0.0, 1.0));
	float d = mw_hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float mw_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * mw_vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Screen-space derivative bump mapping (no tangents needed). n and pos in view space.
vec3 mw_bump(vec3 n, vec3 pos, float h, float strength) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad * strength);
}
