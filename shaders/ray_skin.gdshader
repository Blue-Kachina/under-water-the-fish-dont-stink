shader_type spatial;
// Plank's ray skins (RayModel, scripts/fish_models/ray_model.gd): one shape for
// the body and its wings, or (tail_mode) its tail. The wings are a thin
// membrane out past `hinge` that bends up and down with the fin pivots, sweeps
// back in a slide and ripples nose to tail as it swims (FishModel._swim sets
// those); the tail bends along its links (FishModel._bend_whip) and ripples.
// Every marking is painted from the resting shape, so nothing slides.
//
// `pattern` picks the species: 0 reef manta, 1 spotted eagle ray, 2 southern
// stingray, 3 blue-spotted ribbontail. `albedo` is the back's main colour (the
// team tint replaces it); the markings and the pale belly stay.
//
// Mesh channels (RayModel): body UV = (along nose 0 to tail 1, 1 on the back /
// 0 on the belly), UV2 = (out from the middle 0 to the rim 1, 0; -1 in y on
// add-on parts: no painted markings). Tail UV = (root 0 to tip 1, round it:
// 0.25 on top), UV2.x = 0 tail, 1 the barb, 2 the ribbon fold.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/stride_cue.gdshaderinc"

uniform bool tail_mode = false;
uniform int pattern = 0;
uniform vec4 albedo : source_color = vec4(0.1, 0.11, 0.13, 1.0);
uniform vec4 belly_color : source_color = vec4(0.93, 0.93, 0.9, 1.0);
uniform vec4 mark_color : source_color = vec4(0.93, 0.94, 0.9, 1.0);  // patches, spots
uniform vec4 mark_color2 : source_color = vec4(0.12, 0.13, 0.15, 1.0);  // belly spots, ring centres, margins
uniform float mark_glow = 0.0;  // a little glow on the markings (the ribbontail's blue)
uniform float spot_cell = 0.06;  // m between spots, about
uniform vec2 spot_size = vec2(0.12, 0.24);  // spot radius range, of a cell
uniform float spot_gap = 0.25;  // share of cells left empty
uniform float ring_share = 0.0;  // share of spots that are rings
uniform float mottle = 0.15;  // blotchy light and dark over the back
uniform float rim_shade = 0.35;  // the back darker toward its rim
uniform float bumpiness = 0.4;  // fine skin texture (denticles)
uniform float denticle = 260.0;  // its scale, per m
uniform float wetness = 0.6;  // 0 matt to 1 glossy

// Manta shoulder patches: from `patch_a` (x, z m, near the middle) to
// `patch_b` (out on the wing), `patch_w` half wide at each end.
uniform vec2 patch_a = vec2(0.06, -0.3);
uniform vec2 patch_b = vec2(0.36, -0.1);
uniform vec2 patch_w = vec2(0.04, 0.01);
// A darker ridge down the middle of the back from z `ridge.x` to `ridge.y`.
uniform vec2 ridge = vec2(-0.2, 0.25);
uniform float ridge_width = 0.03;
// Spiracles behind the eyes (x, z m, radius).
uniform vec3 spiracle = vec3(0.07, -0.25, 0.0);

// The wings (m, rad).
uniform float hinge = 0.16;  // where the membrane starts bending, out from the middle
uniform float span = 0.54;  // the wingtips, out from the middle
uniform float rest_flap = 0.25;  // tips up a little even at rest
uniform float flap_left = 0.0;  // tips up, more
uniform float flap_right = 0.0;
uniform float sweep_left = 0.0;  // tips back
uniform float sweep_right = 0.0;
uniform float ripple = 0.015;  // how high the swimming wave lifts the tips
uniform float ripple_bias = 0.0;  // + the right wing's wave deeper and the left's shallower, - the reverse
uniform float wave = 7.0;  // rad per m along the body
// The wave grows as it runs back over the disc, from half at the nose (z, m) to
// one and a half at the tail, as a ray's does.
uniform float wave_from = -0.5;
uniform float wave_to = 0.3;
uniform float phase = 0.0;  // advances as it swims

// Underneath (z and x, m): five pairs of gill slits behind the mouth, and the
// nostrils in front of it.
uniform vec4 gill_color : source_color = vec4(0.55, 0.42, 0.46, 1.0);
uniform float gill_from = -0.3;
uniform float gill_to = -0.1;
uniform float gill_x = 0.09;  // out from the middle
uniform float gill_length = 0.022;  // half of the first slit
uniform float mouth_z = -0.42;
uniform float mouth_width = 0.04;  // half
uniform bool front_mouth = false;  // the manta's: across the front of the head
uniform float belly_margin = 0.0;  // a dark band round the belly's rim

// The tail (UV.x runs 0 at the base to 1 at the tip).
uniform float tail_length = 0.8;
uniform float tail_ripple = 0.08;
// How far (rad) the tail bends off its root at the end of each of its four
// links (FishModel._bend_whip): yaw (tip toward +X) and pitch (tip down).
uniform vec4 bend_yaw = vec4(0.0);
uniform vec4 bend_pitch = vec4(0.0);
uniform vec4 stripe_color : source_color = vec4(0.16, 0.55, 0.95, 1.0);  // the ribbontail's tail stripes

varying vec3 rest;

// The tail's bend (yaw, pitch) `s` along it: 0 at the root, straight between
// the links' ends (FishModel._whip_bend_at).
vec2 bend_at(float s) {
	float at = clamp(s, 0.0, 1.0) * 4.0;
	int i = min(int(floor(at)), 3);
	vec2 from = i > 0 ? vec2(bend_yaw[i - 1], bend_pitch[i - 1]) : vec2(0.0);
	return mix(from, vec2(bend_yaw[i], bend_pitch[i]), at - float(i));
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Spots at `p` (m on the skin, cells `cell` across), soft edged: x = inside a
// spot, y = inside a ring's hole (rings: ring_share of them).
vec2 spots(vec2 p, float cell) {
	vec2 base = floor(p / cell);
	float edge = length(fwidth(p)) * 0.8 + cell * 0.01;
	vec2 inside = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = base + vec2(float(i), float(j));
			vec2 h = hash2(c);
			if (h.y < spot_gap) {
				continue;  // a gap
			}
			vec2 centre = (c + 0.2 + 0.6 * h) * cell;
			float radius = cell * mix(spot_size.x, spot_size.y, fract(h.x * 7.31));
			float dist = length((p - centre) * vec2(1.0, 0.9));
			float spot = 1.0 - smoothstep(radius - edge, radius + edge, dist);
			bool ring = fract(h.x * 13.7 + h.y * 3.1) < ring_share;
			float hole = ring ? 1.0 - smoothstep(radius * 0.55 - edge, radius * 0.55 + edge, dist) : 0.0;
			if (spot > inside.x) {
				inside = vec2(spot, hole);
			}
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

// How far `p` is inside a stroke from a to b, half wide wa to wb (1 in, 0 out).
float stroke(vec2 p, vec2 a, vec2 b, vec2 widths, float soft) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	float width = mix(widths.x, widths.y, t);
	float d = length(p - a - ab * t);
	return 1.0 - smoothstep(width - soft, width + soft, d);
}

void vertex() {
	rest = VERTEX;
	if (tail_mode) {
		float s = UV.x;
		// Bent along its length: walk the middle out from the root, each bit
		// turned by the bend there (FishModel._whip_offset, keep in step).
		vec3 offset = vec3(0.0);
		float h = s / 12.0;
		for (int k = 0; k < 12; k++) {
			vec2 b = bend_at((float(k) + 0.5) * h);
			offset += vec3(sin(b.x), -sin(b.y), cos(b.x) + cos(b.y) - 2.0) * h;
		}
		VERTEX += offset * tail_length;
		vec2 b = bend_at(s);
		NORMAL = normalize(vec3(NORMAL.x * cos(b.x) + NORMAL.z * sin(b.x), NORMAL.y, -NORMAL.x * sin(b.x) + NORMAL.z * cos(b.x)));
		// The ripple, in step with the tail's length (a short tail barely ripples).
		float a = 9.0 * s - phase * 1.4;
		float r = tail_ripple * clamp(tail_length / 1.0, 0.0, 1.0);
		VERTEX.x += r * s * s * sin(a);
		VERTEX.y += r * 0.35 * s * s * cos(a * 0.7);
	} else {
		float side = sign(VERTEX.x);
		float reach = max(span - hinge, 0.001);
		float outward = clamp((abs(VERTEX.x) - hinge) / reach, 0.0, 1.0);
		float up = rest_flap + (side > 0.0 ? flap_right : flap_left);
		float back = side > 0.0 ? sweep_right : sweep_left;
		float a = wave * VERTEX.z - phase;
		float swell = ripple * (1.0 + ripple_bias * side) * mix(0.5, 1.5, smoothstep(wave_from, wave_to, VERTEX.z));
		// Bent progressively (the angle grows along the membrane): a height and a
		// shift back that grow with how far out squared, and their slopes for the normal.
		float lift = up * reach * outward * outward * 0.5 + swell * outward * outward * sin(a);
		float lift_x = side * (up * outward + swell * 2.0 * outward / reach * sin(a));
		float lift_z = swell * outward * outward * wave * cos(a);
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

// The back's markings at rest point `p` (x, z m); returns the colour.
vec3 back_color(vec3 base, vec2 p, float rim, out float glow) {
	glow = 0.0;
	vec3 color = base;
	float n = skin_fbm(vec3(p * 9.0, 1.3));
	// Lighter over the middle, darker toward the rim, blotchy.
	color *= mix(1.18, 1.0 - rim_shade, smoothstep(0.0, 1.0, rim));
	color *= 1.0 + mottle * (n - 0.5) * 2.0;
	// The ridge down the middle.
	float on_ridge = (1.0 - smoothstep(ridge_width * 0.5, ridge_width, abs(p.x)))
			* smoothstep(ridge.x, ridge.x + 0.06, p.y) * (1.0 - smoothstep(ridge.y - 0.06, ridge.y, p.y));
	color *= 1.0 - 0.3 * on_ridge;
	if (pattern == 0) {
		// Manta: white shoulder patches either side, frayed at the edges, and a
		// grey cast toward the wing tips.
		vec2 q = vec2(abs(p.x), p.y);
		float soft = 0.006 + 0.012 * skin_noise(vec3(p * 60.0, 2.0));
		float wobble = (skin_noise(vec3(p * 22.0, 4.0)) - 0.5) * 0.02;
		float patch = stroke(q + vec2(0.0, wobble), patch_a, patch_b, patch_w, soft);
		// A softer grey tail to each patch, back along the wing.
		float smudge = stroke(q, patch_b, patch_b + vec2(0.08, 0.1), vec2(patch_w.y * 1.4, 0.0), 0.02) * 0.2;
		color = mix(color, mark_color.rgb, max(patch, smudge) * 0.95);
	} else if (pattern == 1 || pattern == 3) {
		// Eagle ray: white spots and rings; ribbontail: electric blue spots.
		vec2 s = spots(p, spot_cell);
		float spot = s.x * (1.0 - s.y);
		float bright = pattern == 3 ? 1.0 + 0.25 * skin_noise(vec3(p * 40.0, 7.0)) : 1.0;
		color = mix(color, mark_color.rgb * bright, spot);
		color = mix(color, mark_color2.rgb, s.y * 0.6);
		glow = spot;
	} else if (pattern == 2) {
		// Southern stingray: sandy, mottled with paler and darker clouds.
		float clouds = skin_fbm(vec3(p * 7.0, 8.0));
		color = mix(color, color * 1.4, smoothstep(0.5, 0.7, clouds) * 0.75);
		color = mix(color, color * 0.62, smoothstep(0.45, 0.25, clouds) * 0.6);
		// A row of thorns down the middle of the back.
		vec2 thorn = vec2(p.x, (fract(p.y * 38.0) - 0.5) / 38.0);
		float row = (1.0 - smoothstep(0.0035, 0.006, length(thorn * vec2(1.0, 0.8))))
				* smoothstep(ridge.x + 0.12, ridge.x + 0.2, p.y) * (1.0 - smoothstep(ridge.y - 0.12, ridge.y - 0.05, p.y));
		color = mix(color, mark_color.rgb, row * 0.4);
	}
	// Spiracles: dark holes just behind the eyes, with a pale lip.
	if (spiracle.z > 0.0) {
		vec2 d = vec2(abs(p.x) - spiracle.x, (p.y - spiracle.y) * 0.75);
		float r = length(d);
		color = mix(color, color * 1.3, 1.0 - smoothstep(spiracle.z * 1.1, spiracle.z * 1.5, r));
		color = mix(color, vec3(0.03, 0.025, 0.02), 1.0 - smoothstep(spiracle.z * 0.7, spiracle.z, r));
	}
	return color;
}

vec3 belly_paint(vec2 p, float rim) {
	vec3 color = belly_color.rgb;
	color *= 0.96 + 0.06 * skin_noise(vec3(p * 14.0, 3.0));
	// A dusky margin round the rim.
	color = mix(color, mark_color2.rgb, smoothstep(1.0 - belly_margin, 1.0, rim) * step(0.001, belly_margin) * 0.85);
	if (pattern == 0) {
		// Manta: a scatter of dark spots on the belly, between and behind the gills.
		float zone = smoothstep(gill_from - 0.02, gill_from + 0.04, p.y) * (1.0 - smoothstep(gill_to + 0.06, gill_to + 0.2, p.y))
				* (1.0 - smoothstep(gill_x * 0.9, gill_x * 1.6, abs(p.x)));
		float cell = 0.035;
		vec2 base = floor(p / cell);
		float spot = 0.0;
		for (int i = -1; i <= 1; i++) {
			for (int j = -1; j <= 1; j++) {
				vec2 c = base + vec2(float(i), float(j));
				vec2 h = hash2(c + 17.0);
				if (h.y < 0.55) {
					continue;
				}
				vec2 centre = (c + 0.2 + 0.6 * h) * cell;
				float radius = cell * mix(0.12, 0.3, h.x);
				spot = max(spot, 1.0 - smoothstep(radius * 0.8, radius, length(p - centre)));
			}
		}
		color = mix(color, mark_color2.rgb, spot * zone);
	}
	// Gills, mouth and nostrils.
	float marks = 0.0;
	for (int i = 0; i < 5; i++) {
		float t = float(i) / 4.0;
		float x = gill_x + 0.4 * gill_length * sin(t * PI);  // in a gentle arc
		vec2 d = vec2(abs(p.x) - x, p.y - mix(gill_from, gill_to, t));
		marks = max(marks, slit(d, gill_length * mix(1.0, 0.65, t), 0.0025));
	}
	if (!front_mouth) {
		marks = max(marks, slit(vec2(p.x, p.y - mouth_z), mouth_width, 0.003));
		vec2 nostril = vec2(abs(p.x) - mouth_width * 0.55, (p.y - mouth_z + mouth_width * 0.8) * 0.6);
		marks = max(marks, 1.0 - smoothstep(0.005, 0.0065, length(nostril)));
	}
	return mix(color, gill_color.rgb, marks);
}

void fragment() {
	vec3 color;
	float glow = 0.0;
	float bump_scale = denticle;
	if (tail_mode) {
		float around = 1.0 - abs(fract(UV.y + 0.25) - 0.5) * 2.0;  // 1 on top, 0 underneath
		float top = smoothstep(0.35, 0.65, around);
		vec3 back = albedo.rgb * (1.0 + mottle * (skin_noise(vec3(UV.x * tail_length * 30.0, UV.y * 6.0, 0.0)) - 0.5) * 2.0);
		color = mix(mix(belly_color.rgb * 0.85, back, 0.35), back, top);
		if (pattern == 0) {
			color = mix(belly_color.rgb * 0.8, back, smoothstep(0.2, 0.5, around));
		} else if (pattern == 1) {
			// A few white spots near the base, fading out down the whip.
			vec2 s = spots(vec2(UV.y * 0.09, UV.x * tail_length), 0.045);
			color = mix(color, mark_color.rgb, s.x * step(0.5, around) * (1.0 - smoothstep(0.1, 0.25, UV.x)));
			color = mix(color, albedo.rgb * 0.6, smoothstep(0.3, 0.8, UV.x));
		} else if (pattern == 3) {
			// Blue stripes along each side of the tail; its tip and fold go dark.
			float u = fract(UV.y);
			float d = min(abs(u - 0.09), abs(u - 0.41));  // just above each side
			float stripe = (1.0 - smoothstep(0.02, 0.035, d)) * (1.0 - smoothstep(0.75, 0.85, UV.x));
			color = mix(color, stripe_color.rgb, stripe);
			glow = stripe * 0.5;
			color = mix(color, albedo.rgb * 0.45, smoothstep(0.6, 0.9, UV.x));
		}
		if (UV2.x > 1.5) {
			color = mix(albedo.rgb * 0.35, vec3(0.05, 0.06, 0.08), 0.5);  // the ribbon fold: dusky
		} else if (UV2.x > 0.5) {
			color = mark_color.rgb;  // the barb: pale bone
			bump_scale = 0.0;
		}
	} else if (UV2.y < 0.0) {
		// Add-on parts (head lobes, dorsal fin): the back's colour outside, the
		// belly's inside.
		vec3 back = albedo.rgb * (1.0 + mottle * (skin_noise(vec3(rest * 30.0)) - 0.5) * 2.0);
		color = mix(belly_color.rgb * 0.9, back, UV.y);
	} else {
		float rim = UV2.x;
		float g;
		vec3 back = back_color(albedo.rgb, rest.xz, rim, g);
		vec3 belly = belly_paint(rest.xz, rim);
		float top = smoothstep(0.3, 0.7, UV.y);
		color = mix(belly, back, top);
		glow = g * top;
		if (front_mouth) {
			// The manta's wide mouth: a dark gape right across the front of the head.
			float gape = (1.0 - smoothstep(mouth_width * 0.9, mouth_width, abs(rest.x)))
					* (1.0 - smoothstep(mouth_z, mouth_z + 0.012, rest.z))
					* (1.0 - smoothstep(0.35, 0.75, UV.y));
			color = mix(color, vec3(0.06, 0.05, 0.06), gape);
		}
	}
	ALBEDO = color;
	EMISSION = mark_color.rgb * glow * mark_glow;
	if (tail_mode) {
		EMISSION += stride_cue(UV.x);
	}
	// Fine denticles: bump the normal from a noise height (screen-space derivatives).
	if (bumpiness > 0.0 && bump_scale > 0.0) {
		float height = skin_noise(rest * bump_scale) * 0.6 + skin_noise(rest * bump_scale * 0.31) * 0.4;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhdx = dFdx(height);
		float dhdy = dFdy(height);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2) * bumpiness * 0.0006;
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}
	ROUGHNESS = mix(0.75, 0.22, wetness) + 0.08 * skin_noise(rest * 50.0);
	SPECULAR = 0.5;
	// A wet sheen at grazing angles.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION += vec3(0.6, 0.75, 0.85) * fres * 0.06 * wetness;
}
