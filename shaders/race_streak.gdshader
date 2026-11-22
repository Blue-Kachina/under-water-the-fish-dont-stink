// A slipstream streak (planning_race.md section 8): a thin additive line that fades out along its length and over the
// particle's life. `glow` below zero is the plain wake (faint, white-blue); above it the drafting wake (brighter, warm).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float glow = 0.0;

void fragment() {
	float along = abs(UV.y - 0.5) * 2.0;
	float fade = (1.0 - along) * COLOR.a;
	vec3 plain = vec3(0.55, 0.85, 1.0) * 0.9;
	vec3 hot = vec3(1.0, 0.9, 0.5) * 2.4;
	ALBEDO = glow < 0.0 ? plain : mix(plain, hot, clamp(glow, 0.0, 1.0));
	ALPHA = fade * (glow < 0.0 ? 0.35 : 0.2 + 0.7 * clamp(glow, 0.0, 1.0));
}
