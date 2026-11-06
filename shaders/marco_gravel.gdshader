shader_type spatial;
// The Aquarium arena's coloured gravel (planning_marco_polo.md §12), painted in
// world space: rounded pebbles in a Voronoi pattern, each a shop-gravel colour,
// darker in the cracks between them.

uniform float pebble_size = 0.55;
uniform vec3 colour_a : source_color = vec3(0.15, 0.35, 0.85);
uniform vec3 colour_b : source_color = vec3(0.9, 0.35, 0.55);
uniform vec3 colour_c : source_color = vec3(0.92, 0.9, 0.85);
uniform vec3 colour_d : source_color = vec3(0.25, 0.7, 0.35);
uniform vec3 crack : source_color = vec3(0.06, 0.07, 0.05);
// How much the shop colours are calmed: 0 as above, 1 a grey-green gravel (the whale's
// silt shows the floor off, and loud pebbles read as noise at its distance).
uniform float calm : hint_range(0.0, 1.0) = 0.8;
uniform float dim = 0.72;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / pebble_size;
	vec2 cell = floor(p);
	float best = 8.0;
	float second = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 at = c + hash2(c);
			float d = length(p - at);
			if (d < best) { second = best; best = d; id = c; }
			else if (d < second) { second = d; }
		}
	}
	float pick = hash2(id + 17.0).x;
	vec3 colour = pick < 0.3 ? colour_a : (pick < 0.55 ? colour_b : (pick < 0.85 ? colour_c : colour_d));
	colour *= 0.75 + 0.35 * hash2(id + 3.0).y;
	float grey = dot(colour, vec3(0.3, 0.59, 0.11));
	colour = mix(colour, vec3(grey) * vec3(0.9, 1.0, 0.9), calm * 0.7) * mix(1.0, dim, calm);
	float edge = smoothstep(0.0, 0.18, second - best);
	ALBEDO = mix(crack, colour, edge);
	ROUGHNESS = mix(1.0, 0.45, edge);
	SPECULAR = 0.8;
}
