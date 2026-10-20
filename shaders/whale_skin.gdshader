shader_type spatial;
// The whale shark family's hide (WhaleSharkModel): `albedo` (the colour
// set_body_color() tints) darkest along the back, lighter down the flanks
// (`flank_gain` times it), over a pale belly. A whale shark's checkerboard:
// pale spots in columns between thin pale stripes down its flanks, smaller
// denser spots over its head, and pale crests along its flank ridges. A basking
// shark is mottled instead. Gill slits with a lifted rear flap, the mouth's
// groove and the eye sockets are shaded with a bump (the normal tilts with a
// painted height), so they read as cut into the skin.
//
// The body mesh carries its own paint coordinates: UV = (distance back over
// the skin from the nose, arc round from the dorsal midline) in metres, UV2 =
// (arc as a share of the half round, 0 the back to 1 the belly; the half round
// in metres). Everything is painted from the resting shape, so nothing slides
// as the body bends.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.165, 0.275, 0.392, 1.0);
uniform vec3 flank_gain = vec3(2.0);  // the flanks are albedo times this (linear)
uniform vec4 belly_color : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform float belly_s = 0.62;  // where the belly starts round the body, 0 back to 1 belly
uniform float belly_soft = 0.025;
uniform vec4 spot_color : source_color = vec4(0.91, 0.94, 0.96, 1.0);
uniform float spot_cell = 0.05;  // m between spot columns (and stripes)
uniform float spot_size = 0.22;  // a spot's radius, of a cell
uniform float spot_strength = 1.0;
uniform float head_spot = 0.5;  // the head's spot cells, of spot_cell
uniform vec4 stripe_color : source_color = vec4(0.81, 0.88, 0.92, 1.0);
uniform float stripes = 0.5;  // how strong the pale stripes are
uniform vec2 stripe_span = vec2(-0.3, 0.4);  // z the checkerboard runs from (behind the gills) to
uniform float mottle = 0.0;  // a basking shark's blotchy hide
uniform float nose_z = -0.65;
uniform float tail_z = 0.5;
uniform float ridge = 0.0;  // m, the flank ridges' crest (the mesh is shaped too)
uniform vec3 ridge_from = vec3(0.16, 0.27, 0.39);  // where the three ridges run round the body
uniform vec3 ridge_to = vec3(0.3, 0.4, 0.5);  // ... and where they end, on the tail stalk
uniform float ridge_light = 0.35;
uniform vec4 slit_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);
uniform float gill_z = -0.48;  // m, the first slit
uniform float gill_step = 0.028;  // m between slits
uniform int gill_count = 5;
uniform vec2 gill_s = vec2(0.24, 0.6);  // how far round the first slit runs, top to bottom
uniform float gill_shrink = 0.02;  // each slit after the first starts this much lower
uniform float gill_bow = 0.006;  // m the slits' ends curve back
uniform float gill_depth = 0.004;  // m
uniform vec4 mouth_color : source_color = vec4(0.05, 0.04, 0.05, 1.0);
uniform float mouth_s = 0.56;  // how far round the mouth line runs
uniform float mouth_corner_z = -0.57;  // m
uniform float mouth_front_z = -10.0;  // m; past the nose, the mouth runs from the nose
uniform bool mouth_under = false;  // a line round under the snout joins the sides
uniform float mouth_droop = 0.04;  // the corners turn down
uniform float mouth_width = 0.006;  // m
uniform vec3 eye_pos = vec3(0.2, 0.0, -0.55);  // the right eye
uniform float eye_radius = 0.017;

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

vec2 whale_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Round spots on a jittered grid of `cell` (m) at `p` (m), `size` (of a cell)
// across: 1 on a spot, 0 off it.
float whale_spots(vec2 p, vec2 cell, float size, float jitter, float seed) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float best = 1e3;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = whale_hash2(c + seed);
			if (h.x * h.y > 0.85) {
				continue;  // a gap now and then
			}
			vec2 centre = c + 0.5 + (h - 0.5) * jitter;
			float r = size * mix(0.7, 1.2, fract(h.x * 7.31 + h.y * 3.7)) * min(cell.x, cell.y);
			vec2 d = (q - centre) * cell;
			best = min(best, length(d) - r);
		}
	}
	float aa = clamp(fwidth(best), 1e-4, 0.004);
	return 1.0 - smoothstep(-aa, aa, best);
}

// The flank ridges' crests (0..1) at `along` (nose 0, tail 1), `s` round.
float whale_ridges(float along, float s, float half_round, float width) {
	float fade = smoothstep(0.17, 0.3, along) * (1.0 - smoothstep(0.86, 0.97, along));
	vec3 at = mix(ridge_from, ridge_to, smoothstep(0.55, 0.9, along));
	vec3 d = (vec3(s) - at) * half_round / width;
	vec3 e = exp(-d * d);
	return max(max(e.x, e.y), e.z) * fade;
}

void fragment() {
	float z = rest.z;
	float over = UV.x;  // m back over the skin from the nose
	float arc = UV.y;
	float s = UV2.x;
	float half_round = max(UV2.y, 1e-4);
	float along = (z - nose_z) / (tail_z - nose_z);
	float height = 0.0;  // m, for the bump
	float shade = 1.0;

	// Dark back to lighter flanks over a pale belly.
	vec3 flank = albedo.rgb * flank_gain;
	flank /= max(1.0, max(flank.r, max(flank.g, flank.b)));  // keep the hue of a bright tint
	vec3 tone = mix(albedo.rgb, flank, smoothstep(0.06, belly_s, s));
	tone *= mix(0.9, 1.08, skin_fbm(rest * 11.0));
	if (mottle > 0.0) {
		float blotch = skin_fbm(rest * 7.0 + 3.0);
		float fleck = skin_fbm(rest * 16.0 + 9.0);
		tone *= mix(1.0, mix(0.62, 1.3, smoothstep(0.4, 0.62, blotch)) * mix(0.9, 1.08, fleck), mottle);
	}
	float wobble = (skin_fbm(rest * 6.0 + 7.0) - 0.5) * 0.1;
	float belly = smoothstep(belly_s - belly_soft, belly_s + belly_soft, s + wobble);
	vec3 color = mix(tone, belly_color.rgb, belly);

	// The checkerboard: pale stripes between columns of spots behind the gills,
	// smaller scattered spots over the head.
	float body_zone = smoothstep(stripe_span.x - 0.14, stripe_span.x + 0.02, z);
	vec2 p = vec2(z - stripe_span.x, arc);
	if (spot_strength > 0.0) {
		float columns = whale_spots(p, vec2(spot_cell, spot_cell * 0.8), spot_size, 0.42, 1.0);
		float scatter = whale_spots(vec2(over - stripe_span.x, arc), vec2(spot_cell) * head_spot, spot_size * 0.95, 0.85, 7.0);
		float spot = mix(scatter, columns, body_zone) * (1.0 - belly) * spot_strength;
		spot *= smoothstep(-0.004, 0.0, along);  // not on the very tip
		if (stripes > 0.0) {
			float q = (z - stripe_span.x + 0.0015 * sin(arc * 40.0)) / spot_cell;
			float d = abs(q - round(q)) * spot_cell;
			float aa = fwidth(q) * spot_cell;
			float stripe = 1.0 - smoothstep(0.003, 0.003 + aa, d);
			stripe *= body_zone * (1.0 - smoothstep(stripe_span.y - 0.12, stripe_span.y, z));
			stripe *= smoothstep(0.08, 0.2, s) * (1.0 - belly);
			color = mix(color, stripe_color.rgb, stripe * stripes);
		}
		color = mix(color, spot_color.rgb, spot);
	}
	if (ridge > 0.0) {
		float crest = whale_ridges(along, s, half_round, 0.006);
		color = mix(color, stripe_color.rgb, crest * ridge_light * (1.0 - belly));
		height += ridge * 0.5 * crest;
	}

	// Gill slits: a dark groove with the skin behind it lifted into a flap.
	float slit_dark = 0.0;
	for (int k = 0; k < gill_count; k++) {
		vec2 span = gill_s + vec2(gill_shrink, -gill_shrink * 0.4) * float(k);
		float mid = (span.x + span.y) * 0.5;
		float reach = (span.y - span.x) * 0.5;
		float m = (s - mid) / reach;
		float shown = 1.0 - smoothstep(0.8, 1.0, abs(m));
		if (shown <= 0.0) {
			continue;
		}
		float dz = z - (gill_z + gill_step * float(k) + gill_bow * m * m);
		float groove = exp(-pow((dz + 0.002) / 0.0022, 2.0));
		float flap = smoothstep(-0.0012, 0.0, dz) * exp(-max(dz, 0.0) / 0.007);
		height += shown * gill_depth * (flap - groove);
		slit_dark = max(slit_dark, shown * groove);
		shade *= 1.0 - 0.25 * shown * exp(-pow((dz + 0.006) / 0.004, 2.0));  // shadow in front of the flap
	}
	color = mix(color, slit_color.rgb, slit_dark * 0.92);

	// The mouth: a dark line round the front (a whale shark's, right at the
	// nose) or under the snout (a basking shark's), its corners turned down.
	if (mouth_width > 0.0) {
		float corner = smoothstep(mouth_corner_z - 0.05, mouth_corner_z, z);
		float line_s = mouth_s + mouth_droop * corner;
		float thick = mouth_width * mix(1.0, 0.4, corner);
		float d = abs(s - line_s) * half_round;
		float on = step(z, mouth_corner_z + 0.002) * step(mouth_front_z, z);
		float mouth = 1.0e3;
		if (on > 0.0) {
			mouth = d - thick * 0.5;
		}
		if (mouth_under && s > line_s) {
			mouth = min(mouth, abs(z - mouth_front_z) - mouth_width * 0.5);
		}
		float aa = clamp(fwidth(mouth), 1e-4, 0.003);
		float line = 1.0 - smoothstep(-aa, aa, mouth);
		color = mix(color, mouth_color.rgb, line);
		shade *= 1.0 - 0.3 * exp(-pow(max(mouth, 0.0) / (mouth_width * 1.5), 2.0));
		height -= 0.003 * exp(-pow(max(mouth + mouth_width * 0.5, 0.0) / mouth_width, 2.0));
	}

	// Eye sockets: a dark ring round each eye.
	float eye_d = length(vec3(abs(rest.x), rest.y, rest.z) - eye_pos);
	shade *= mix(0.55, 1.0, smoothstep(eye_radius * 0.9, eye_radius * 2.0, eye_d));
	height += 0.002 * smoothstep(eye_radius * 2.6, eye_radius * 1.3, eye_d);

	// Fine denticles.
	height += 0.00008 * skin_noise(rest * 500.0);

	// Tilt the normal with the painted height.
	vec3 n = normalize(NORMAL);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);

	ALBEDO = color * shade;
	ROUGHNESS = mix(0.38, 0.5, belly);
	SPECULAR = 0.5;
	CLEARCOAT = 0.2;
	CLEARCOAT_ROUGHNESS = 0.3;
	RIM = 0.2;
	RIM_TINT = 0.6;
}
