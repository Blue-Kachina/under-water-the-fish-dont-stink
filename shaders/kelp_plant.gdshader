shader_type spatial;
render_mode cull_disabled;
// Giant kelp and sea grass on Unnatural's seabed (planning_environment.md,
// Phase 5): swaying in the current, more the higher up (MeshKit's vertex
// colour a), each plant on its own phase; translucent olive-gold fronds lit
// from behind.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 base : source_color = vec3(0.2, 0.22, 0.06);
uniform vec3 tip : source_color = vec3(0.62, 0.5, 0.14);
uniform float sway = 0.9;
uniform float speed = 0.8;

varying float up;
varying vec3 world_pos;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	up = COLOR.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 0.11 + root.z * 0.13 + INSTANCE_CUSTOM.g * 6.28;
	float bend = up * up * sway;
	float scale = length(MODEL_MATRIX[1].xyz);
	VERTEX.x += (sin(TIME * speed + phase + up * 1.5) * bend) / max(scale, 0.01);
	VERTEX.z += (cos(TIME * speed * 0.8 + phase * 1.3 + up) * bend * 0.6) / max(scale, 0.01);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float streak = sc_noise(world_pos * vec3(6.0, 1.5, 6.0));
	vec3 color = mix(base, tip, smoothstep(0.0, 1.0, up * 0.8 + streak * 0.3));
	color *= 0.85 + 0.3 * custom.r;
	ALBEDO = color;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = color * 0.6;
}
