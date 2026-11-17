shader_type spatial;
render_mode cull_back, diffuse_burley;
// Lit window pane: COLOR.rgb is the interior glow (black = dark window). UV 0..1 per pane.
uniform float energy = 3.0;
uniform vec3 glass_tint : source_color = vec3(0.05, 0.07, 0.1);

void fragment() {
	vec2 uv = UV;
	float bar = max(1.0 - smoothstep(0.02, 0.05, abs(uv.x - 0.5)), 1.0 - smoothstep(0.02, 0.05, abs(uv.y - 0.45)));
	float rim = 1.0 - smoothstep(0.0, 0.06, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float grad = mix(1.0, 0.55, uv.y) * (0.85 + 0.15 * sin(TIME * 1.3 + COLOR.a * 40.0));
	float curtain = smoothstep(0.18, 0.1, uv.x) + smoothstep(0.82, 0.9, uv.x);
	float lit = (1.0 - bar) * (1.0 - rim * 0.6);
	vec3 glow = COLOR.rgb * grad * mix(1.0, 0.45, clamp(curtain, 0.0, 1.0));
	ALBEDO = mix(glass_tint, vec3(0.12, 0.08, 0.05), bar);
	EMISSION = glow * lit * energy;
	ROUGHNESS = mix(0.08, 0.7, bar);
	SPECULAR = 0.7;
}
