shader_type spatial;
// The baby whales' hide (WhaleModel): `albedo` (the colour set_body_color()
// tints) darkest along the back, lighter down the flanks (`flank_gain` times
// it), over the belly. Per species: the humpback's white-blotched belly and the
// knobbly tubercles on its rostrum and jaw; the orca calf's peachy patches (eye
// patch, chin and belly sweeping up into a flank lobe) and faint saddle; a
// blue whale's pale mottling; the sperm whale's prune-wrinkled skin and pale
// lips; throat pleats on the baleen whales; the blowhole (a pair of slits on
// the baleen whales, one crescent on the toothed ones, the sperm whale's
// S-shaped one forward on the left); the mouth line and the eye socket. Grooves
// and bumps tilt the normal with a painted height. Wet skin: a clearcoat over
// a smooth, slightly rubbery base, and a little light scattering through it.
//
// The body mesh carries its own paint coordinates: UV = (distance back over
// the skin from the nose, arc round from the dorsal midline) in metres, UV2 =
// (arc as a share of the half round, 0 the back to 1 the belly; the half round
// in metres). Everything is painted from the resting shape, so nothing slides
// as the body bends.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.14, 0.15, 0.17, 1.0);
uniform vec3 flank_gain = vec3(1.5);
uniform vec4 belly_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float belly_s = 0.66;  // where the belly starts round the body, 0 back to 1 belly
uniform float belly_soft = 0.03;
uniform float belly_mottle = 0.0;  // the humpback's ragged white blotches
uniform float mottle = 0.0;  // pale mottling over the back (blue whale)
uniform vec4 mottle_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float tubercles = 0.0;  // knobs on the rostrum and lower jaw (humpback)
uniform float wrinkle = 0.0;  // prune wrinkles (sperm whale; a little on a beluga's neck)
uniform float pleats = 0.0;  // throat grooves
uniform float pleat_s = 0.7;  // round the body they start
uniform float pleat_z = -0.2;  // m, where they end, back along the belly
uniform float orca = 0.0;  // the orca calf's patches
uniform vec4 patch_color : source_color = vec4(0.95, 0.77, 0.63, 1.0);
uniform float saddle = 0.0;  // the grey saddle behind an orca's dorsal
uniform float roughness = 0.4;
uniform float nose_z = -0.65;
uniform float tail_z = 0.4;
uniform vec4 mouth_color : source_color = vec4(0.04, 0.035, 0.04, 1.0);
uniform float mouth_tip_s = 0.5;  // round the body the mouth line starts, at the snout
uniform float mouth_s = 0.6;  // ... and where its corner is
uniform float mouth_corner = 0.2;  // along the body (nose 0, tail 1)
uniform float mouth_arch = 0.04;  // the line bows up between (the baleen whales')
uniform float mouth_width = 0.004;  // m
uniform float pale_lips = 0.0;  // the sperm whale's white mouth edges
uniform vec3 eye_pos = vec3(0.2, 0.0, -0.4);  // the right eye
uniform float eye_radius = 0.011;
uniform vec3 blow_pos = vec3(0.0, 0.16, -0.5);  // the blowhole on top of the head
uniform float blow_pair = 1.0;  // 1 a pair of slits, 0 one

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	fish_bend(VERTEX, NORMAL);
}

vec2 calf_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Round knobs on a jittered grid of `cell` (m) at `p` (m): their height 0..1.
float calf_knobs(vec2 p, float cell, float size) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float best = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = calf_hash2(c + 5.0);
			vec2 centre = c + 0.5 + (h - 0.5) * 0.7;
			float r = size * mix(0.7, 1.2, h.y);
			float d = length(q - centre) / r;
			best = max(best, sqrt(max(1.0 - d * d, 0.0)));
		}
	}
	return best;
}

// A soft ellipse in (along, s): 1 inside, fading over `soft`.
float calf_blob(vec2 p, vec2 centre, vec2 radius, float soft) {
	float d = length((p - centre) / radius);
	return 1.0 - smoothstep(1.0 - soft, 1.0 + soft, d);
}

void fragment() {
	float z = rest.z;
	float over = UV.x;
	float arc = UV.y;
	float s = UV2.x;
	float half_round = max(UV2.y, 1e-4);
	float along = (z - nose_z) / (tail_z - nose_z);
	float height = 0.0;
	float shade = 1.0;
	vec2 at = vec2(along, s);

	// Dark back to lighter flanks over the belly.
	vec3 flank = albedo.rgb * flank_gain;
	flank /= max(1.0, max(flank.r, max(flank.g, flank.b)));
	vec3 tone = mix(albedo.rgb, flank, smoothstep(0.1, belly_s, s));
	tone *= mix(0.92, 1.06, skin_fbm(rest * 9.0));
	if (mottle > 0.0) {
		float blotch = smoothstep(0.56, 0.72, skin_fbm(rest * 26.0 + 2.0));
		float fleck = smoothstep(0.6, 0.72, skin_fbm(rest * 60.0 + 11.0));
		tone = mix(tone, mottle_color.rgb, clamp(blotch * 0.4 + fleck * 0.3, 0.0, 1.0) * mottle);
	}
	float wobble = (skin_fbm(rest * 5.0 + 7.0) - 0.5) * 0.12;
	float ragged = belly_mottle * (skin_fbm(rest * 18.0 + 4.0) - 0.5) * 0.35;
	float belly = smoothstep(belly_s - belly_soft, belly_s + belly_soft, s + wobble + ragged);
	if (belly_mottle > 0.0) {
		// White splashes up the flanks, dark flecks down in the white.
		float splash = smoothstep(0.62, 0.72, skin_fbm(rest * 12.0 + 1.5)) * smoothstep(belly_s - 0.25, belly_s, s);
		float fleck = smoothstep(0.66, 0.74, skin_fbm(rest * 26.0 + 8.0)) * belly;
		belly = clamp(belly + splash * belly_mottle - fleck * 0.8 * belly_mottle, 0.0, 1.0);
	}
	vec3 color = mix(tone, belly_color.rgb * mix(0.94, 1.02, skin_fbm(rest * 20.0)), belly);

	// The orca calf: patches in peach, the saddle a faint grey.
	if (orca > 0.0) {
		float eye_patch = calf_blob(at + vec2(0.0, (along - 0.22) * 0.5), vec2(0.225, 0.36), vec2(0.06, 0.055), 0.25);
		float chin = smoothstep(0.62, 0.68, s) * (1.0 - smoothstep(0.62, 0.72, along));
		float lobe = calf_blob(at + vec2(0.0, (along - 0.62) * 0.9), vec2(0.66, 0.6), vec2(0.13, 0.2), 0.2) * smoothstep(0.5, 0.58, along);
		float patches = max(max(eye_patch, chin), lobe) * orca;
		color = mix(color, patch_color.rgb * mix(0.94, 1.03, skin_fbm(rest * 16.0)), patches);
		float sad = calf_blob(at + vec2(s * 0.12, 0.0), vec2(0.64, 0.0), vec2(0.09, 0.2), 0.6) * saddle;
		color = mix(color, mix(color, vec3(0.42, 0.43, 0.46), 0.8), sad * (1.0 - patches));
	}

	// The humpback's tubercles: knobs on the top of the rostrum and its lower jaw.
	if (tubercles > 0.0) {
		float zone = (1.0 - smoothstep(0.14, 0.2, along)) * smoothstep(0.0, 0.03, along);
		float top_zone = (1.0 - smoothstep(0.1, 0.17, s)) * zone;
		float jaw_zone = smoothstep(0.62, 0.7, s) * (1.0 - smoothstep(0.86, 0.92, s)) * zone;
		float knob = calf_knobs(vec2(over, arc), 0.03, 0.24) * (top_zone + jaw_zone) * tubercles;
		height += 0.0035 * knob;
		color = mix(color, color * 0.8, knob * 0.3);
	}

	// Throat pleats: grooves along the belly from the chin back.
	if (pleats > 0.0) {
		float from_belly = half_round - arc;
		float q = from_belly / 0.011 + 0.6 * sin(over * 12.0);
		float groove = pow(abs(sin(q * PI)), 10.0);
		float zone = smoothstep(pleat_s - 0.04, pleat_s + 0.04, s) * smoothstep(0.03, 0.08, along) * (1.0 - smoothstep(pleat_z - 0.06, pleat_z, z));
		height -= 0.0022 * groove * zone * pleats;
		shade *= 1.0 - 0.28 * groove * zone * pleats;
	}

	// Wrinkles: prune-skin ridges round the body, crossed with finer creases.
	if (wrinkle > 0.0) {
		// Ridged noise: the contour lines of two noise fields, stretched round
		// the body, make an uneven network of creases.
		float big = abs(skin_fbm(rest * vec3(16.0, 20.0, 9.0)) - 0.5);
		float small = abs(skin_fbm(rest * vec3(38.0, 44.0, 24.0) + 5.0) - 0.5);
		float creases = (1.0 - smoothstep(0.0, 0.045, big)) * 0.8 + (1.0 - smoothstep(0.0, 0.04, small)) * 0.4;
		float zone = wrinkle >= 0.99 ? smoothstep(0.06, 0.2, along) : exp(-pow((along - 0.235) / 0.06, 2.0));
		height -= 0.0016 * creases * zone * wrinkle;
		shade *= 1.0 - 0.08 * creases * zone * wrinkle;
	}

	// The mouth line: from the snout round to its corner, bowing up between.
	if (mouth_width > 0.0) {
		float t = clamp(along / max(mouth_corner, 0.01), 0.0, 1.0);
		float line_s = mix(mouth_tip_s, mouth_s, t) - mouth_arch * sin(PI * t) + 0.03 * smoothstep(0.85, 1.0, t);
		float d = abs(s - line_s) * half_round - mouth_width * mix(0.6, 0.35, t);
		d = along > mouth_corner ? 1.0e3 : d;
		float aa = clamp(fwidth(d), 1e-4, 0.003);
		float line = 1.0 - smoothstep(-aa, aa, d);
		color = mix(color, mouth_color.rgb, line);
		if (pale_lips > 0.0) {
			float lips = (1.0 - smoothstep(0.0, 0.012, abs(d + mouth_width * 0.5))) * (1.0 - line);
			color = mix(color, vec3(0.86, 0.86, 0.84), lips * pale_lips * 0.85);
		}
		height -= 0.0025 * exp(-pow(max(d, 0.0) / (mouth_width * 1.5), 2.0)) * step(along, mouth_corner);
	}

	// The eye socket: a dark ring and a soft lid round each eye.
	float eye_d = length(vec3(abs(rest.x), rest.y, rest.z) - eye_pos);
	shade *= mix(0.6, 1.0, smoothstep(eye_radius * 0.9, eye_radius * 2.0, eye_d));
	height += 0.0018 * smoothstep(eye_radius * 2.8, eye_radius * 1.4, eye_d);

	// The blowhole: slits on top of the head, in a raised splash guard.
	vec2 b = vec2(rest.x - blow_pos.x, rest.z - blow_pos.z);
	float on_top = smoothstep(blow_pos.y - 0.04, blow_pos.y - 0.015, rest.y);
	float slit;
	if (blow_pair > 0.5) {
		vec2 p = vec2(abs(b.x) - 0.009 + b.y * 0.25, b.y);
		slit = length(p / vec2(0.0025, 0.011));
	} else if (blow_pos.x < -0.001) {
		vec2 p = vec2(b.x + 0.004 * sin(b.y * 300.0), b.y);
		slit = length(p / vec2(0.0025, 0.012));
	} else {
		vec2 p = vec2(b.x, b.y + 30.0 * b.x * b.x);
		slit = length(p / vec2(0.012, 0.003));
	}
	float hole = (1.0 - smoothstep(0.7, 1.0, slit)) * on_top;
	float guard = exp(-pow(length(b) / 0.02, 2.0)) * on_top;
	height += 0.002 * guard - 0.003 * hole;
	color = mix(color, vec3(0.03), hole * 0.9);

	// Fine skin grain.
	height += 0.00006 * skin_noise(rest * 420.0);

	vec3 n = normalize(NORMAL);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);

	ALBEDO = color * shade;
	ROUGHNESS = clamp(roughness + 0.08 * belly + 0.1 * wrinkle * (1.0 - shade), 0.05, 1.0);
	SPECULAR = 0.5;
	CLEARCOAT = 0.4;
	CLEARCOAT_ROUGHNESS = 0.22;
	BACKLIGHT = vec3(0.06, 0.05, 0.05);
	RIM = 0.2;
	RIM_TINT = 0.6;
}
