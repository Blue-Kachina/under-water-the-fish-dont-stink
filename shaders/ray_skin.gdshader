shader_type spatial;
// The string ray's skin (FishModel._build_ray): one shape for the body and its
// wings, or (tail_mode) its whip tail. The wings are a thin membrane out past
// `hinge` that bends up and down with the fin pivots, sweeps back in a slide and
// ripples nose to tail as it swims; the tail ripples side to side. Spots,
// streaks and the white belly are painted from the resting shape, so they move
// with it.

uniform bool tail_mode = false;
uniform vec4 albedo : source_color = vec4(0.05, 0.17, 0.47, 1.0);
uniform vec4 belly_color : source_color = vec4(0.94, 0.93, 0.97, 1.0);
uniform vec4 spot_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float spot_glow = 0.25;
uniform float spot_cell = 0.07;  // m between spots, about

// The wings (m, rad).
uniform float hinge = 0.16;  // where the membrane starts bending, out from the middle
uniform float span = 0.54;  // the wingtips, out from the middle
uniform float rest_flap = 0.25;  // tips up a little even at rest
uniform float flap_left = 0.0;  // tips up, more
uniform float flap_right = 0.0;
uniform float sweep_left = 0.0;  // tips back
uniform float sweep_right = 0.0;
uniform float ripple = 0.015;  // how high the swimming wave lifts the tips
uniform float wave = 7.0;  // rad per m along the body
uniform float phase = 0.0;  // advances as it swims

// Pale streaks back over the head (z, m) and their spacing across.
uniform float streak_from = -0.35;
uniform float streak_to = -0.17;
uniform float streak_gap = 0.035;

// Underneath (z and x, m): five pairs of gill slits behind the mouth, and the
// nostrils in front of it.
uniform vec4 gill_color : source_color = vec4(0.62, 0.45, 0.52, 1.0);
uniform float gill_from = -0.3;
uniform float gill_to = -0.1;
uniform float gill_x = 0.09;  // out from the middle
uniform float gill_length = 0.022;  // half of the first slit
uniform float mouth_z = -0.42;
uniform float mouth_width = 0.04;  // half

// The tail (UV.x runs 0 at the base to 1 at the tip).
uniform float tail_length = 0.8;

#include "res://shaders/stride_cue.gdshaderinc"
uniform float tail_ripple = 0.08;

varying vec3 rest;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// 1 inside a spot at `p` (m on the skin, cells `cell` across), soft edged.
float spots(vec2 p, float cell) {
	vec2 base = floor(p / cell);
	float edge = length(fwidth(p));  // soft by a pixel (not per cell: they jump at the borders)
	float inside = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = base + vec2(float(i), float(j));
			vec2 h = hash2(c);
			if (h.y > 0.72) {
				continue;  // a gap
			}
			vec2 centre = (c + 0.2 + 0.6 * h) * cell;
			float radius = cell * mix(0.09, 0.22, fract(h.x * 7.31));
			vec2 d = (p - centre) * vec2(1.0, 0.8);  // a little longer than wide
			float dist = length(d);
			inside = max(inside, 1.0 - smoothstep(radius - edge, radius + edge, dist));
		}
	}
	return inside;
}

// 1 on a short slit running across (x) at `d` (m from its middle), `half_length`
// long each way and bowed back at its ends.
float slit(vec2 d, float half_length, float width) {
	float aa = length(fwidth(d));
	float across = 1.0 - smoothstep(half_length - aa, half_length + aa, abs(d.x));
	return across * (1.0 - smoothstep(width - aa, width + aa, abs(d.y - d.x * d.x * 6.0)));
}

void vertex() {
	rest = VERTEX;
	if (tail_mode) {
		float s = UV.x;
		float a = 9.0 * s - phase * 1.4;
		VERTEX.x += tail_ripple * s * s * sin(a);
		VERTEX.y += tail_ripple * 0.35 * s * s * cos(a * 0.7);
	} else {
		float side = sign(VERTEX.x);
		float reach = max(span - hinge, 0.001);
		float outward = clamp((abs(VERTEX.x) - hinge) / reach, 0.0, 1.0);
		float up = rest_flap + (side > 0.0 ? flap_right : flap_left);
		float back = side > 0.0 ? sweep_right : sweep_left;
		float a = wave * VERTEX.z - phase;
		// Bent progressively (the angle grows along the membrane): a height and a
		// shift back that grow with how far out squared, and their slopes for the normal.
		float lift = up * reach * outward * outward * 0.5 + ripple * outward * outward * sin(a);
		float lift_x = side * (up * outward + ripple * 2.0 * outward / reach * sin(a));
		float lift_z = ripple * outward * outward * wave * cos(a);
		float shift = back * reach * outward * outward * 0.5;
		float shift_x = side * back * outward;
		VERTEX.y += lift;
		VERTEX.z += shift;
		vec3 n = NORMAL;
		n = vec3(n.x - lift_x * n.y, n.y, n.z - lift_z * n.y);
		n = vec3(n.x - shift_x * n.z, n.y, n.z);
		NORMAL = normalize(n);
	}
}

void fragment() {
	vec3 color = albedo.rgb;
	float spot = 0.0;
	if (tail_mode) {
		// Along the top of the tail only.
		float around = 1.0 - abs(fract(UV.y + 0.25) - 0.5) * 2.0;  // 1 on top, 0 underneath
		spot = spots(vec2(UV.y * 0.08, UV.x * tail_length), 0.06) * step(0.55, around) * step(UV.x, 0.8);
	} else {
		// UV.y is 1 on the top surface, 0 on the belly.
		color = mix(belly_color.rgb, color, UV.y);
		spot = spots(rest.xz, spot_cell) * UV.y;
		for (int k = -1; k <= 1; k++) {
			float x = rest.x - float(k) * streak_gap;
			float along = (rest.z - streak_from) / (streak_to - streak_from);
			float width = 0.006 * (1.0 - abs(float(k)) * 0.3) * sin(clamp(along, 0.0, 1.0) * PI);
			float streak = 1.0 - smoothstep(width * 0.6, width, abs(x - 0.01 * along * float(k)));
			spot = max(spot, streak * step(0.0, along) * step(along, 1.0) * UV.y);
		}
		float marks = 0.0;
		for (int i = 0; i < 5; i++) {
			float t = float(i) / 4.0;
			float x = gill_x + 0.4 * gill_length * sin(t * PI);  // in a gentle arc
			vec2 d = vec2(abs(rest.x) - x, rest.z - mix(gill_from, gill_to, t));
			marks = max(marks, slit(d, gill_length * mix(1.0, 0.65, t), 0.0025));
		}
		marks = max(marks, slit(vec2(rest.x, rest.z - mouth_z), mouth_width, 0.003));
		vec2 nostril = vec2(abs(rest.x) - mouth_width * 0.55, (rest.z - mouth_z + mouth_width * 0.8) * 0.6);
		marks = max(marks, 1.0 - smoothstep(0.006, 0.0075, length(nostril)));
		color = mix(color, gill_color.rgb, marks * (1.0 - UV.y));
	}
	ALBEDO = mix(color, spot_color.rgb, spot);
	EMISSION = spot_color.rgb * spot * spot_glow;
	if (tail_mode) {
		EMISSION += stride_cue(UV.x);
	}
	ROUGHNESS = 0.45;
}
