shader_type spatial;
// Waterlogged chest wood (planning_environment.md, Phase 6): planks running
// along x with dark seams between them, grain streaked along each plank,
// worn paler on edges. In the mesh's own space, so it moves with the chest.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 wood : source_color = vec3(0.34, 0.2, 0.1);
uniform vec3 wood_light : source_color = vec3(0.5, 0.32, 0.17);
uniform float plank = 0.16;

varying vec3 local;
varying vec3 local_normal;

void vertex() {
	local = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Planks stack up the sides and run front to back over the lid.
	float across = abs(local_normal.y) > 0.6 ? local.z : local.y;
	float row = floor(across / plank);
	float seam = smoothstep(0.0, 0.08, fract(across / plank)) * smoothstep(1.0, 0.92, fract(across / plank));
	float grain = sc_noise(vec3(local.x * 2.0, across * 40.0 + row * 7.0, row));
	vec3 color = mix(wood, wood_light, grain * 0.6 + sc_hash(vec3(row, 1.0, 2.0)) * 0.3);
	color *= mix(0.35, 1.0, seam);
	color = mix(color, color * 0.6 + vec3(0.05, 0.08, 0.05), smoothstep(0.55, 0.75, sc_fbm(local * 3.0)) * 0.4);
	ALBEDO = color;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
