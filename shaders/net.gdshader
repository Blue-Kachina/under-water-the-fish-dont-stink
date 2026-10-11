shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

// See-through goal netting: a diamond mesh of glowing cords in world space, so
// it lines up across a goal's faces. Projected along all three axes and blended
// by the normal, so it stays seamless round the net's curves.

uniform vec4 net_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float cell_size = 0.8;
uniform float cord_width = 0.05;
uniform float glow = 0.8;
// Faint film between cords so the inside of the goal reads as enclosed.
uniform float fill = 0.08;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Cord coverage (0..1) of the diamond pattern on one projection plane.
float cords(vec2 plane) {
	// Rotate 45 degrees for diamonds.
	vec2 cell = vec2(plane.x + plane.y, plane.x - plane.y) * 0.7071 / cell_size;
	vec2 dist = abs(fract(cell - 0.5) - 0.5);
	vec2 width = vec2(cord_width / cell_size);
	vec2 lines = 1.0 - smoothstep(width, width + fwidth(cell), dist);
	return max(lines.x, lines.y);
}

void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	float cord = cords(world_pos.zy) * weights.x + cords(world_pos.xz) * weights.y + cords(world_pos.xy) * weights.z;

	ALBEDO = net_color.rgb * 0.4;
	EMISSION = net_color.rgb * glow * cord;
	ROUGHNESS = 0.7;
	ALPHA = max(cord, fill);
}
