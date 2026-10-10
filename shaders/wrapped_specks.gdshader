shader_type spatial;
render_mode unshaded, world_vertex_coords;

// Floating specks for endless water. Each speck keeps a fixed spot in the
// world, but is wrapped into a box centred on `center` (the camera), so the
// same few thousand specks always surround the player wherever they swim.
// Wrapping happens at the box edge, far out in the fog, so it's never seen.

uniform vec3 center;
uniform float box_size = 120.0;
uniform vec4 color : source_color = vec4(0.7, 0.9, 1.0, 1.0);

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 offset = mod(origin - center + box_size * 0.5, box_size) - box_size * 0.5;
	// Shrink specks to nothing near the box edge so wrapping never pops.
	float edge = max(abs(offset.x), max(abs(offset.y), abs(offset.z))) / (box_size * 0.5);
	float fade = 1.0 - smoothstep(0.7, 1.0, edge);
	VERTEX = center + offset + (VERTEX - origin) * fade;
}

void fragment() {
	ALBEDO = color.rgb;
}
