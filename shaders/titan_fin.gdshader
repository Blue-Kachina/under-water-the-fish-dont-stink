shader_type spatial;
// The Titans' fins (TitanModel): in the body's `albedo` (tinted with it), pale
// underneath where they face down (`under_color`), with an `edge_color` rim.
// `part` says which: 0 a blade (the dorsal, UV2 = along its root 0..1, root 0
// to edge 1), 1 a flipper (UV2 = out along it 0..1, across 0 the leading edge
// to 1 the trailing; white over its top too by `white_top`, the humpback's,
// barnacles on the tubercles of its leading edge and at its tip), 2 the flukes
// (UV2 = -1 left tip to 1 right tip, across 0 leading to 1 trailing; the
// underside's black-and-white pattern, unique per skin through
// `pattern_seed` and `fluke_white`, a dark trailing rim, scars and tip
// barnacles), 3 the sperm whale's lower jaw (white along its top). Measured in
// the standard length (`body_length`). A fin on the
// body's bending part bends with it.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.12, 0.13, 0.15, 1.0);
uniform vec3 flank_gain = vec3(1.5);
uniform vec4 under_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float edge_width = 0.2;  // of the way out (blades) or across (flippers), 0 none
uniform float mottle = 0.0;
uniform vec4 mottle_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float roughness = 0.42;
uniform float clearcoat = 0.35;
uniform int part = 0;
uniform float white_top = 0.0;
uniform float fluke_white = 0.0;  // how much of the flukes' underside is white
uniform float fluke_plain = 0.0;  // 1: the underside's white is one clean field inside a dark margin (the orca's)
uniform float barnacles = 0.0;
uniform float scars = 0.0;
uniform float pattern_seed = 1.3;
uniform float body_length = 10.0;

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

vec2 fin_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Barnacle cones with a dark hole on a grid of `cell`: (height, hole).
vec2 fin_barnacles(vec2 p, float cell, float seed) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float height = 0.0;
	float hole = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = fin_hash2(c + seed * 3.1);
			vec2 centre = c + 0.5 + (h - 0.5) * 0.8;
			float d = length(q - centre) / mix(0.3, 0.55, h.x);
			float cone = clamp(1.0 - d, 0.0, 1.0);
			height = max(height, smoothstep(0.0, 0.35, cone) * (1.0 - smoothstep(0.55, 0.75, cone)));
			hole = max(hole, smoothstep(0.62, 0.75, cone));
		}
	}
	return vec2(height, hole);
}

void fragment() {
	vec3 q = rest / body_length;
	vec2 plan = UV / body_length;
	float pixel = length(fwidth(rest)) / body_length;
	float fine = 1.0 - smoothstep(0.0015, 0.004, pixel);
	float height = 0.0;
	vec3 flank = albedo.rgb * flank_gain;
	vec3 tone = mix(albedo.rgb, flank / max(1.0, max(flank.r, max(flank.g, flank.b))), 0.3);
	tone *= mix(0.9, 1.06, skin_fbm(q * 10.0));
	if (mottle > 0.0) {
		float blotch = smoothstep(0.55, 0.72, skin_fbm(q * 16.0 + 2.0));
		tone = mix(tone, mottle_color.rgb, blotch * 0.5 * mottle);
	}
	float under = smoothstep(-0.1, -0.5, rest_normal.y);
	float edge;
	float crust = 0.0;  // where barnacles grow
	vec3 white = under_color.rgb * mix(0.93, 1.02, skin_fbm(q * 22.0));
	vec3 color;
	if (part == 1) {
		float out_part = UV2.x;
		float lead = 1.0 - smoothstep(0.0, edge_width * 0.5, UV2.y);
		edge = max(lead, smoothstep(0.93, 0.99, out_part)) * step(0.001, edge_width);
		// A humpback's flippers are white over much of their top as well,
		// blotched toward the root.
		float top_white = white_top * smoothstep(0.2, 0.55, out_part + (skin_fbm(q * 20.0) - 0.5) * 0.45);
		under = max(under, top_white);
		color = mix(tone, white, under);
		color = mix(color, edge_color.rgb, edge * 0.85);
		// Barnacles along the leading edge's knobs and at the tip.
		crust = (1.0 - smoothstep(0.08, 0.2, UV2.y)) * smoothstep(0.3, 0.45, out_part) + smoothstep(0.88, 0.97, out_part) * 0.7;
	} else if (part == 2) {
		float span = abs(UV2.x);
		// The underside's pattern: white blotches on black, set per skin, the
		// share of white `fluke_white`, never quite touching the trailing rim.
		// Crisp-edged like a photo-ID fluke: bold shapes with streaky, ragged
		// edges and small black flecks inside the white, antialiased by slope.
		float pattern = skin_fbm(vec3(plan * vec2(10.0, 13.0), pattern_seed)) + 0.22 * skin_noise(vec3(plan * vec2(60.0, 30.0), pattern_seed * 2.0));
		float lobe = (span < 0.12 ? 0.35 : 1.0) * (1.0 - 0.35 * smoothstep(0.6, 1.0, span));
		float pd = pattern - mix(0.3, 0.8, fluke_white) * lobe;
		float spots = 1.0 - smoothstep(-1.0, 1.0, pd / max(fwidth(pd), 1e-4));
		float fleck = skin_noise(vec3(plan * 90.0, pattern_seed + 3.0));
		spots *= 1.0 - smoothstep(0.72, 0.78, fleck) * (1.0 - fluke_plain);
		spots *= 1.0 - smoothstep(0.82, 0.93, UV2.y);  // the dark trailing margin
		float wobble = 0.04 * (skin_fbm(vec3(plan * 12.0, pattern_seed)) - 0.5);
		float field = smoothstep(0.1, 0.14, UV2.y + wobble) * (1.0 - smoothstep(0.76, 0.8, UV2.y + wobble))
				* (1.0 - smoothstep(0.84, 0.88, span + wobble));
		spots = mix(spots, field, fluke_plain);
		float underside = smoothstep(-0.02, -0.15, rest_normal.y);
		color = mix(tone, white, spots * underside * step(0.001, fluke_white));
		// Scratches on the underside, pale.
		float scratch = (1.0 - smoothstep(0.02, 0.06, abs(fract((plan.x * 1.3 + plan.y * 3.0) * 30.0 + sin(plan.x * 80.0 + pattern_seed)) - 0.5)))
				* smoothstep(0.7, 0.8, skin_noise(vec3(plan * 14.0, pattern_seed + 4.0))) * underside * scars;
		color = mix(color, vec3(0.8, 0.8, 0.78), scratch * 0.7);
		edge = smoothstep(0.9, 1.0, UV2.y) * 0.4;
		color = mix(color, color * 0.55, edge);
		crust = smoothstep(0.8, 0.95, span) + (1.0 - smoothstep(0.0, 0.1, UV2.y)) * smoothstep(0.5, 0.7, span) * 0.5;
	} else if (part == 3) {
		// The sperm whale's lower jaw: dark below, its upper edges (the lips)
		// and the gum between them white.
		edge = 0.0;
		float lips = smoothstep(0.45, 0.8, rest_normal.y);
		color = mix(tone, vec3(0.84, 0.84, 0.82) * mix(0.94, 1.02, skin_fbm(q * 30.0)), lips);
		crust = 0.0;
	} else {
		edge = 0.0;
		color = tone;
		crust = 0.0;
	}
	if (barnacles > 0.0 && crust > 0.0) {
		float clump = smoothstep(0.5, 0.65, skin_fbm(q * 30.0 + pattern_seed)) * clamp(crust, 0.0, 1.0) * barnacles;
		vec2 b = fin_barnacles(plan, 0.005, pattern_seed);
		color = mix(color, vec3(0.76, 0.73, 0.66), clump * smoothstep(0.0, 0.3, b.x) * mix(0.5, 1.0, fine));
		color = mix(color, vec3(0.05, 0.045, 0.04), clump * b.y * fine);
		height += 0.0014 * clump * (b.x - b.y * 0.8);
	}
	height *= body_length;
	vec3 n = normalize(NORMAL);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);
	ALBEDO = color;
	ROUGHNESS = roughness + 0.05;
	SPECULAR = 0.5;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.28;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
