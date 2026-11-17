shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Procedural surface for all baked world geometry. Base colour comes from vertex colour,
// COLOR.a is a per-prop seed. UVs are in metres.
// pattern: 0 plain, 1 wood, 2 stone blocks, 3 cobblestones (world XZ), 4 roof tiles,
//          5 plaster, 6 terrain, 7 metal, 8 rough rock (world space), 9 cloth/felt

#include "res://shaders/world/common.gdshaderinc"

uniform int pattern = 0;
uniform float roughness_base = 0.85;
uniform float metallic_base = 0.0;
uniform float bump_strength = 1.0;
uniform float brick_w = 0.48;
uniform float brick_h = 0.24;
uniform vec3 moss_color : source_color = vec3(0.16, 0.22, 0.12);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float seed = COLOR.a * 97.0;
	float h = 0.0;
	float rough = roughness_base;
	float metal = metallic_base;
	float ao = 1.0;
	vec2 uv = UV;
	if (pattern == 1) {
		// Wood: grain runs along U.
		float streak = mw_fbm(vec2(uv.x * 1.2 + seed, uv.y * 38.0 + seed * 3.1));
		float rings = sin(uv.y * 55.0 + mw_fbm(uv * vec2(0.8, 9.0) + seed) * 9.0) * 0.5 + 0.5;
		float plank = mw_vnoise(vec2(seed * 3.0, floor(uv.y * 5.0)));
		base *= mix(0.7, 1.12, streak) * mix(0.9, 1.05, rings) * mix(0.88, 1.1, plank);
		h = streak * 0.7 + rings * 0.3;
		rough = roughness_base - streak * 0.1;
	} else if (pattern == 2) {
		// Dressed stone blocks with mortar.
		vec2 b = uv / vec2(brick_w, brick_h);
		float row = floor(b.y);
		b.x += mod(row, 2.0) * 0.5 + mw_hash21(vec2(row, seed)) * 0.35;
		vec2 id = floor(b);
		vec2 f = fract(b);
		vec2 e = min(f, 1.0 - f) * vec2(brick_w, brick_h);
		float edge = min(e.x, e.y);
		float mortar = smoothstep(0.008, 0.03, edge);
		float v = mw_hash21(id + seed);
		float n = mw_fbm(uv * 5.0 + seed);
		base *= mix(0.42, 1.0, mortar) * mix(0.72, 1.18, v) * (0.8 + 0.4 * n);
		float mossy = smoothstep(0.55, 0.85, mw_fbm(uv * 1.3 + seed + 4.0)) * smoothstep(0.3, -0.2, wnrm.y + uv.y * 0.0);
		base = mix(base, moss_color * (0.7 + 0.5 * n), mossy * (1.0 - mortar * 0.3) * 0.6);
		h = mortar * (0.7 + 0.3 * smoothstep(0.0, 0.06, edge)) + n * 0.25;
		ao = mix(0.7, 1.0, mortar);
	} else if (pattern == 3) {
		// Cobblestones: voronoi in world XZ.
		vec2 p = wpos.xz / 0.34;
		vec2 ip = floor(p);
		vec2 fp = fract(p);
		float d1 = 8.0;
		float d2 = 8.0;
		vec2 cid = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 g = vec2(float(x), float(y));
				vec2 o = mw_hash22(ip + g) * 0.8 + 0.1;
				vec2 r = g + o - fp;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					cid = ip + g;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
		float edge = sqrt(d2) - sqrt(d1);
		float stone = smoothstep(0.04, 0.22, edge);
		float v = mw_hash21(cid);
		float n = mw_fbm(wpos.xz * 3.0);
		vec3 sc = base * mix(0.7, 1.2, v) * (0.85 + 0.3 * n);
		sc = mix(sc, sc * vec3(1.08, 0.98, 0.9), step(0.7, mw_hash21(cid + 3.1)));
		vec3 gap = mix(base * 0.3, moss_color * 0.6, smoothstep(0.4, 0.7, mw_fbm(wpos.xz * 0.6)));
		base = mix(gap, sc, stone);
		h = sqrt(clamp(edge * 2.0, 0.0, 1.0)) + n * 0.15;
		rough = mix(0.95, 0.62 + v * 0.2, stone);
		ao = mix(0.55, 1.0, stone);
	} else if (pattern == 4) {
		// Barrel roof tiles: U across the eave, V down the slope, rows every 0.3 m.
		float row = floor(uv.y / 0.3);
		float cx = uv.x / 0.21 + mod(row, 2.0) * 0.5;
		float col = floor(cx);
		float fx = fract(cx);
		float fy = fract(uv.y / 0.3);
		float barrel = sin(fx * 3.14159);
		float v = mw_hash21(vec2(col, row) + seed);
		base *= mix(0.55, 1.0, barrel) * mix(0.75, 1.2, v) * (0.85 + 0.3 * mw_fbm(uv * 3.0 + seed));
		base *= mix(0.65, 1.0, smoothstep(0.0, 0.25, fy));
		float mossy = smoothstep(0.6, 0.9, mw_fbm(uv * 0.9 + seed));
		base = mix(base, moss_color, mossy * 0.5);
		h = barrel * 0.8 + smoothstep(0.0, 0.25, fy) * 0.5;
		rough = 0.6 + v * 0.25;
	} else if (pattern == 5) {
		// Lime plaster.
		float n = mw_fbm(uv * 1.2 + seed);
		float fine = mw_vnoise(uv * 25.0);
		base *= (0.82 + 0.3 * n) * (0.95 + 0.08 * fine);
		float grime = smoothstep(0.9, 0.0, uv.y * -1.0 + 0.0) * 0.0;
		base *= 1.0 - grime;
		h = n * 0.6 + fine * 0.15;
	} else if (pattern == 6) {
		// Terrain: vertex colour blend + noise.
		float n = mw_fbm(wpos.xz * 0.35);
		float fine = mw_fbm(wpos.xz * 4.0);
		base *= (0.75 + 0.5 * n) * (0.85 + 0.3 * fine);
		h = fine;
		rough = 0.95;
	} else if (pattern == 7) {
		float n = mw_fbm(uv * 6.0 + seed);
		base *= 0.8 + 0.4 * n;
		h = n * 0.2;
		rough = roughness_base + n * 0.2;
	} else if (pattern == 8) {
		// Rock: triplanar-ish world noise.
		vec3 an = abs(wnrm);
		float n = mw_fbm(wpos.xz * 0.9) * an.y + mw_fbm(wpos.xy * 0.9) * an.z + mw_fbm(wpos.zy * 0.9) * an.x;
		float cr = mw_fbm(wpos.xz * 3.0 + wpos.y * 2.0);
		base *= (0.6 + 0.7 * n) * (0.85 + 0.3 * cr);
		base = mix(base, moss_color, smoothstep(0.55, 0.9, wnrm.y) * smoothstep(0.45, 0.7, n) * 0.7);
		h = n * 1.5 + cr * 0.5;
		rough = 0.92;
	} else if (pattern == 9) {
		float weave = (sin(uv.x * 900.0) * sin(uv.y * 900.0)) * 0.5 + 0.5;
		float n = mw_fbm(uv * 4.0 + seed);
		base *= (0.85 + 0.25 * n) * (0.95 + 0.05 * weave);
		h = n * 0.3;
		rough = 0.97;
	} else {
		float n = mw_fbm(uv * 3.0 + seed);
		base *= 0.88 + 0.24 * n;
		h = n * 0.2;
	}
	ALBEDO = base;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL = mw_bump(NORMAL, VERTEX, h, 0.012 * bump_strength);
}
