shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Soft additive light shaft (lighthouse beam). Fades out toward the far end (UV.y = 1).
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.7);
uniform float intensity = 0.6;
uniform float falloff = 1.6;

void fragment() {
	float along = 1.0 - pow(clamp(UV.y, 0.0, 1.0), 0.6);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = color * intensity * along * edge;
}
