shader_type spatial;
// Sunken bronze (planning_environment.md): dark metal showing through a
// blue-green verdigris that gathers in hollows and on what faces up, and
// rubs away on edges. World-space, from MeshKit's vertex colour (r cavity).

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 metal : source_color = vec3(0.55, 0.36, 0.2);
uniform vec3 patina : source_color = vec3(0.2, 0.4, 0.35);
uniform float patina_amount : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos + COLOR.b * 19.0;
	vec3 n = sc_bump(p, normalize(world_normal), 6.0, 0.15);
	float green = smoothstep(0.35, 0.7, sc_fbm(p * 3.0) + COLOR.r * 0.6 + max(n.y, 0.0) * 0.3) * patina_amount;
	vec3 metal_tone = metal * (0.75 + 0.5 * sc_noise(p * 9.0));
	ALBEDO = mix(metal_tone, patina * (0.8 + 0.4 * sc_noise(p * 5.0)), green);
	METALLIC = mix(0.9, 0.0, green);
	ROUGHNESS = mix(0.38, 0.85, green);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
