// Unnatural's seabed kelp (Seabed): long blades drawn through a MultiMesh,
// swaying in the current, more toward the tips. The mesh is centred: it runs
// from y = -height / 2 to height / 2.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.28, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.32, 0.42, 0.16, 1.0);
uniform float sway = 0.6;
uniform float height = 6.0;

varying float along;

void vertex() {
	along = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	vec3 base = MODEL_MATRIX[3].xyz;
	float phase = base.x * 0.13 + base.z * 0.11;
	float bend = along * along * sway;
	VERTEX.x += sin(TIME * 0.9 + phase) * bend;
	VERTEX.z += cos(TIME * 0.7 + phase * 1.3) * bend * 0.6;
}

void fragment() {
	ALBEDO = mix(color.rgb, tip_color.rgb, along);
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.15, 0.25, 0.05);
}
