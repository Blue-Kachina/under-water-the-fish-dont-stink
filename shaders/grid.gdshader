shader_type spatial;

// World-space grid so speed and orientation are readable on every surface.

uniform vec4 base_color : source_color = vec4(0.18, 0.32, 0.36, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.75, 0.8, 1.0);
uniform float cell_size = 4.0;
uniform float line_width = 0.08;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p) {
	vec2 cell = p / cell_size;
	vec2 dist = abs(fract(cell - 0.5) - 0.5);
	vec2 width = vec2(line_width / cell_size);
	vec2 lines = 1.0 - smoothstep(width, width + fwidth(cell), dist);
	return max(lines.x, lines.y);
}

void fragment() {
	// Project the grid onto whichever world plane the surface faces most.
	vec3 n = abs(world_normal);
	vec2 plane = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	ALBEDO = mix(base_color.rgb, line_color.rgb, grid(plane));
	ROUGHNESS = 0.85;
}
