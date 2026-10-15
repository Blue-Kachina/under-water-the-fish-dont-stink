shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

// See-through tank glass, as Rocket League's walls: a faint film with the same
// world-space grid as grid.gdshader stitched on, so the walls still read from
// either side when the camera ends up outside them. Thicker at grazing angles,
// like real glass, so a wall seen edge-on still shows where it is.

uniform vec4 base_color : source_color = vec4(0.12, 0.28, 0.34, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.75, 0.8, 1.0);
uniform float cell_size = 4.0;
uniform float line_width = 0.08;
// Opacity of the film between the lines, head-on and edge-on.
uniform float fill = 0.12;
uniform float edge_fill = 0.45;
uniform float line_alpha = 0.75;
uniform float line_glow = 0.35;

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
	// Project the grid onto whichever world plane the surface faces most (as grid.gdshader).
	vec3 n = abs(world_normal);
	vec2 plane = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float line = grid(plane);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float film = mix(edge_fill, fill, facing);
	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	EMISSION = line_color.rgb * line_glow * line;
	ROUGHNESS = 0.2;
	ALPHA = max(film, line * line_alpha);
}
