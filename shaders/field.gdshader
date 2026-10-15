shader_type spatial;

// The match tank's floor: grid.gdshader's grid with pitch markings painted on
// in world space (x across, z along): the halfway line, centre circle and
// spot, goal lines, each end's goal area and penalty box, and the kickoff
// spots. Team colours appear only inside the
// centre circle (each half in the team whose half it is) and in each goal
// area (its goal's team). Team 0 defends +z, team 1 -z. Sizes and spots come
// from AquariumArena.

uniform vec4 base_color : source_color = vec4(0.45, 0.4, 0.3, 1.0);
uniform vec4 line_color : source_color = vec4(0.6, 0.55, 0.45, 1.0);
uniform float cell_size = 4.0;
uniform float line_width = 0.08;

uniform vec4 marking_color : source_color = vec4(0.95, 0.95, 0.9, 1.0);
uniform float marking_width = 0.3;
uniform float marking_glow = 0.25;
uniform vec4 team_0_color : source_color = vec4(0.25, 0.55, 1.0, 1.0);
uniform vec4 team_1_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
// How strongly the team-coloured areas take their team's colour.
uniform float team_fill = 0.35;
uniform float half_length = 51.2;  // centre to goal line
uniform float half_width = 40.96;  // centre to side wall
uniform float goal_half_width = 8.96;
uniform float centre_radius = 9.2;
uniform float spot_radius = 0.5;
uniform vec2 goal_area = vec2(28.0, 6.0);  // full width, depth from the goal line
uniform vec2 penalty_area = vec2(48.0, 16.0);
// Kickoff spots on team 0's half (x, z); team 1's are the same through the centre.
uniform vec2 kickoff_spots[5];
uniform float kickoff_radius = 0.4;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p) {
	vec2 cell = p / cell_size;
	vec2 dist = abs(fract(cell - 0.5) - 0.5);
	vec2 width = vec2(line_width / cell_size);
	vec2 lines = 1.0 - smoothstep(width, width + fwidth(cell), dist);
	return max(lines.x, lines.y);
}

// Coverage of a painted line of `width` along where `d` (a distance in
// metres) is zero, antialiased.
float stroke(float d, float width) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, abs(d));
}

// Coverage of the area where `d` (a signed distance in metres) is negative.
float fill(float d) {
	return 1.0 - smoothstep(0.0, fwidth(d), d);
}

// Signed distance from `p` to a box of half size `b` centred on the origin.
float box(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 team = p.y >= 0.0 ? team_0_color.rgb : team_1_color.rgb;  // whose half this is
	vec3 albedo = mix(base_color.rgb, line_color.rgb, grid(p));

	// Team colour inside the centre circle and each goal area.
	vec2 from_line = vec2(p.x, half_length - abs(p.y));  // y: distance in from this end's goal line
	float team_area = fill(length(p) - centre_radius);
	team_area = max(team_area, fill(box(from_line - vec2(0.0, goal_area.y * 0.5), goal_area * 0.5)));
	albedo = mix(albedo, team, team_fill * team_area);

	// Markings: halfway line, centre circle and spot, each end's boxes (open
	// at the goal line, which they stand on) and goal line.
	float paint = stroke(p.y, marking_width) * step(abs(p.x), half_width);
	paint = max(paint, stroke(length(p) - centre_radius, marking_width));
	paint = max(paint, fill(length(p) - spot_radius));
	for (int i = 0; i < 2; i++) {
		vec2 size = i == 0 ? goal_area : penalty_area;
		float d = box(from_line - vec2(0.0, size.y * 0.5), size * 0.5);
		paint = max(paint, stroke(d, marking_width) * step(0.01, from_line.y));
	}
	// The goal line across each mouth, painted just in front of it (the floor
	// ends at the line; the goal has its own).
	float goal_width = marking_width * 2.5;
	paint = max(paint, stroke(from_line.y - goal_width * 0.5, goal_width) * step(abs(p.x), goal_half_width));

	// Kickoff spots: dots, on both halves.
	vec2 mirrored = p.y >= 0.0 ? p : -p;
	for (int i = 0; i < 5; i++) {
		paint = max(paint, fill(length(mirrored - kickoff_spots[i]) - kickoff_radius));
	}

	ALBEDO = mix(albedo, marking_color.rgb, paint);
	EMISSION = marking_color.rgb * marking_glow * paint;
	ROUGHNESS = 0.85;
}
