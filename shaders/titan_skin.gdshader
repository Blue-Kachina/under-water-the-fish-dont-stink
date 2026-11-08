shader_type spatial;
// The Titans' hide (TitanModel, the adult whales): `albedo` (the colour
// set_body_color() tints) darkest along the back, lighter down the flanks
// (`flank_gain` times it), over the belly. Per species and skin: a ragged
// white belly with splashes (the humpback's), pale mottling (the blue's), the
// knobbly tubercles on a humpback's rostrum and jaw, throat pleats to the
// navel, barnacle clusters, rake and cookie-cutter scars, prune wrinkles (the
// sperm whale's), the orca's patches and saddle, the mouth line, the blowholes
// in their splashguard, and each small eye's sunk socket with its fold and
// lid. Grooves and bumps tilt the normal with a painted height; the fine ones
// fade with distance so they never shimmer.
//
// Everything is measured in the whale's standard length (`body_length`, m), so a
// pattern sits the same on any size of whale: q = rest / body_length. The body mesh
// carries UV = (distance back over the skin from the nose, arc round from the
// back) in m, UV2 = (arc as a share of the half round, 0 the back to 1 the
// belly; the half round in m). Painted from the resting shape, so nothing
// slides as the body bends.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.12, 0.13, 0.15, 1.0);
uniform vec3 flank_gain = vec3(1.5);
uniform vec4 belly_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float belly_s = 0.7;  // where the belly starts round the body, 0 back to 1 belly
uniform float belly_soft = 0.025;
uniform float belly_mottle = 0.0;  // ragged white splashes up the flanks (humpback)
uniform float mottle = 0.0;  // pale mottling over the back (blue whale)
uniform vec4 mottle_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float tubercles = 0.0;  // knobs on the rostrum and lower jaw (humpback)
uniform float wrinkle = 0.0;  // prune wrinkles (sperm whale; a little on a beluga's neck)
uniform float pleats = 0.0;  // throat grooves
uniform float pleat_s = 0.68;  // round the body they start
uniform float pleat_z = 0.0;  // m, where they end (the navel)
uniform float pleat_pitch = 0.12;  // m between grooves
uniform float barnacles = 0.0;  // clusters on the chin, throat and flanks
uniform float scars = 0.0;  // rake marks and cookie-cutter rings
uniform vec4 scar_color : source_color = vec4(0.78, 0.78, 0.76, 1.0);  // pale on dark hides, grey on a beluga
uniform float pattern_seed = 1.3;  // moves the scars and barnacles per skin
uniform float orca = 0.0;  // the orca's patches
uniform vec4 patch_color : source_color = vec4(0.96, 0.96, 0.95, 1.0);
uniform float saddle = 0.0;  // the grey saddle behind an orca's dorsal
uniform vec4 saddle_color : source_color = vec4(0.42, 0.43, 0.46, 1.0);
uniform vec3 saddle_at = vec3(0.56, 0.07, 0.22);  // along, half length (L), how far down round (s)
uniform vec4 eye_patch = vec4(0.19, 0.38, 0.05, 0.02);  // along, s, half length, half height (L)
uniform float eye_patch_tilt = 0.15;  // how far it rises toward its back end (L per L)
uniform vec4 orca_band = vec4(0.63, 0.9, 0.5, 0.62);  // the white's edge (s): chin, between the flippers, the flank lobe's peak; and where it peaks (along)
uniform float cape = 0.0;  // a dark cape over the back, the flanks paler (Antarctic type B)
uniform vec4 cape_color : source_color = vec4(0.31, 0.33, 0.36, 1.0);
uniform float roughness = 0.42;
uniform float clearcoat = 0.35;
uniform float sss = 0.0;  // light through the skin (the beluga's)
uniform float body_length = 10.0;  // the standard length, m
uniform float nose_z = -5.0;
uniform vec4 mouth_color : source_color = vec4(0.035, 0.03, 0.035, 1.0);
uniform float mouth_tip_s = 0.5;  // round the body the mouth line starts, at the snout
uniform float mouth_s = 0.62;  // ... and where its corner is
uniform float mouth_corner = 0.2;  // along the body (nose 0, notch 1)
uniform float mouth_arch = 0.05;  // the line bows up between (the baleen whales')
uniform float mouth_width = 0.016;  // m
uniform float pale_lips = 0.0;  // the sperm whale's white mouth edges
// A whale Hunter's hinged lower jaw (WhaleJaw; all 0/1 on a Marco Polo whale: the skin is untouched). jaw_cut 1 cuts the
// belly under the mouth line, back to the mouth's corner, out of the body; the jaw is a copy of that patch (jaw_part 1) hinged at
// jaw_hinge (y, z) and dropped jaw_angle rad, its length stretched by jaw_stretch (the cartoon gape).
uniform float jaw_cut = 0.0;
uniform float jaw_part = 0.0;
uniform vec2 jaw_hinge = vec2(0.0);
uniform float jaw_angle = 0.0;
uniform float jaw_stretch = 1.0;
// The throat balloons (a whale Hunter's mouth filling: WhaleJaw.fullness): the belly bulges out by throat_swell m, over the
// stretch of the body (along: nose 0, notch 1) throat_span says.
uniform float throat_swell = 0.0;
uniform vec2 throat_span = vec2(0.2, 0.5);
uniform vec3 eye_pos = vec3(1.0, 0.0, -3.0);  // the right eye, on the skin
uniform float eye_radius = 0.045;
uniform vec3 blow_pos = vec3(0.0, 1.0, -3.5);  // the blowhole on top of the head
uniform float blow_pair = 1.0;  // 1 a pair of slits, 0 one
uniform float splashguard = 1.0;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	if (throat_swell > 0.0 && jaw_part < 0.5) {
		float pouch = sin(PI * clamp(((VERTEX.z - nose_z) / body_length - throat_span.x) / max(throat_span.y - throat_span.x, 0.01), 0.0, 1.0));
		VERTEX += NORMAL * throat_swell * pouch * smoothstep(0.55, 0.85, UV2.x);
	}
	if (jaw_part > 0.5) {
		float c = cos(jaw_angle);
		float sn = sin(jaw_angle);
		vec2 d = VERTEX.yz - jaw_hinge;
		d.y *= jaw_stretch;
		VERTEX.yz = jaw_hinge + vec2(c * d.x - sn * d.y, sn * d.x + c * d.y);
		NORMAL.yz = vec2(c * NORMAL.y - sn * NORMAL.z, sn * NORMAL.y + c * NORMAL.z);
	}
	fish_bend(VERTEX, NORMAL);
}

vec2 titan_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Round knobs on a jittered grid of `cell` at `p` (any unit): their height 0..1.
float titan_knobs(vec2 p, float cell, float size, float seed) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float best = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = titan_hash2(c + seed);
			vec2 centre = c + 0.5 + (h - 0.5) * 0.7;
			float r = size * mix(0.7, 1.2, h.y);
			float d = length(q - centre) / r;
			best = max(best, sqrt(max(1.0 - d * d, 0.0)));
		}
	}
	return best;
}

// Barnacles in a cluster: little volcano cones with a dark hole, on a grid of
// `cell`: (height 0..1, how much is the hole).
vec2 titan_barnacles(vec2 p, float cell, float seed) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float height = 0.0;
	float hole = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = titan_hash2(c + seed * 3.1);
			vec2 centre = c + 0.5 + (h - 0.5) * 0.8;
			float r = mix(0.3, 0.55, h.x);
			float d = length(q - centre) / r;
			float cone = clamp(1.0 - d, 0.0, 1.0);
			float rim = smoothstep(0.0, 0.35, cone) * (1.0 - smoothstep(0.55, 0.75, cone));
			height = max(height, rim * mix(0.6, 1.0, h.y));
			hole = max(hole, smoothstep(0.62, 0.75, cone));
		}
	}
	return vec2(height, hole);
}

// Scars in the cell grid at `p` (along, round; L): rake marks (2 to 4 thin
// parallel scratches) and cookie-cutter rings, in some cells. 0..1.
float titan_scars(vec2 p, float seed) {
	vec2 cell = vec2(0.17, 0.11);
	vec2 q = p / cell;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	vec2 h = titan_hash2(id + seed * 7.7);
	float mark = 0.0;
	if (h.x > 0.8) {
		// A rake: two or three long, thin scratches side by side, slanting and
		// gently curved, broken up and faded at the ends.
		float angle = mix(-0.5, 0.5, h.y);
		vec2 r = vec2(cos(angle) * f.x - sin(angle) * f.y, sin(angle) * f.x + cos(angle) * f.y);
		r.y += 0.25 * r.x * r.x * (h.y - 0.5);
		float spacing = 0.035;
		float k = clamp(floor(r.y / spacing + 0.5), -1.0, 1.0);
		float line = abs(r.y - k * spacing);
		float width = 0.0035 * (1.0 + 0.25 * sin(r.x * 23.0 + h.y * 10.0 + k));
		float aa = max(fwidth(line), 1e-4);
		float broken = smoothstep(0.3, 0.55, skin_noise(vec3(r.x * 14.0, k * 3.0, seed + h.y * 9.0)));
		mark = (1.0 - smoothstep(width - aa, width + aa, line)) * (1.0 - smoothstep(0.22, 0.42, abs(r.x))) * mix(0.35, 1.0, broken);
	} else if (h.x < 0.035) {
		// A cookie-cutter bite healed into a pale oval.
		float d = length(f * vec2(1.0, 1.6) - (h - 0.5) * 0.3);
		mark = (1.0 - smoothstep(0.01, 0.025, abs(d - 0.05))) * 0.8 + (1.0 - smoothstep(0.0, 0.05, d)) * 0.3;
	}
	return mark;
}

void fragment() {
	vec3 q = rest / body_length;
	float over = UV.x / body_length;
	float arc = UV.y / body_length;
	float s = UV2.x;
	float half_round = max(UV2.y, 1e-4) / body_length;
	float along = (rest.z - nose_z) / body_length;
	if (jaw_cut > 0.5 && jaw_part < 0.5 && along < mouth_corner) {
		// The belly under the mouth line is the open jaw's: gone from the body.
		float jt = clamp(along / max(mouth_corner, 0.01), 0.0, 1.0);
		float jaw_line = mix(mouth_tip_s, mouth_s, jt) - mouth_arch * sin(PI * jt) + 0.025 * smoothstep(0.88, 1.0, jt);
		if (s > jaw_line) {
			discard;
		}
	}
	float height = 0.0;  // in L
	float shade = 1.0;
	// How big a pixel is here (L): fine detail fades out before it can shimmer.
	float pixel = length(fwidth(rest)) / body_length;
	float fine = 1.0 - smoothstep(0.0015, 0.004, pixel);
	float medium = 1.0 - smoothstep(0.004, 0.01, pixel);

	// Dark back to lighter flanks over the belly.
	vec3 flank = albedo.rgb * flank_gain;
	flank /= max(1.0, max(flank.r, max(flank.g, flank.b)));
	vec3 tone = mix(albedo.rgb, flank, smoothstep(0.1, belly_s, s));
	tone *= mix(0.9, 1.06, skin_fbm(q * 9.0));
	tone *= mix(0.96, 1.03, skin_fbm(q * 40.0 + 3.0));
	if (mottle > 0.0) {
		// Dappled: many small pale flecks, gathered into looser clouds.
		// Soft-edged at every scale, with a second, finer dapple (faded out
		// with distance before it can shimmer).
		float blotch = smoothstep(0.45, 0.75, skin_fbm(q * 18.0 + 2.0));
		float fleck = smoothstep(0.5, 0.7, skin_fbm(q * 70.0 + 11.0));
		float fine_dapple = smoothstep(0.5, 0.68, skin_fbm(q * 160.0 + 23.0)) * medium;
		float pale = blotch * 0.18 + fleck * mix(0.2, 0.5, blotch) + fine_dapple * mix(0.12, 0.3, blotch);
		tone = mix(tone, mottle_color.rgb, clamp(pale, 0.0, 1.0) * mottle);
	}
	float wobble = (skin_fbm(q * 5.0 + 7.0) - 0.5) * 0.12;
	float ragged = belly_mottle * (skin_fbm(q * 18.0 + 4.0 + pattern_seed) - 0.5) * 0.35;
	float belly = smoothstep(belly_s - belly_soft, belly_s + belly_soft, s + wobble + ragged);
	if (belly_mottle > 0.0) {
		// White splashes up the flanks, dark flecks down in the white.
		float splash = smoothstep(0.64, 0.72, skin_fbm(q * 17.0 + 1.5 + pattern_seed)) * smoothstep(belly_s - 0.22, belly_s, s);
		float fleck = smoothstep(0.66, 0.74, skin_fbm(q * 26.0 + 8.0)) * belly;
		belly = clamp(belly + splash * belly_mottle - fleck * 0.7 * belly_mottle, 0.0, 1.0);
	}
	vec3 belly_tone = belly_color.rgb * mix(0.93, 1.02, skin_fbm(q * 20.0));
	vec3 color = mix(tone, belly_tone, belly);

	// The orca's patches (white eye patch, chin and belly sweeping up into a
	// flank lobe) and grey saddle.
	if (orca > 0.0) {
		// A grey cape: the flanks pale below a wavy line, the back dark.
		if (cape > 0.0) {
			float line = 0.3 + 0.05 * sin(along * 11.0 + 0.6) + 0.04 * (skin_fbm(q * 8.0) - 0.5);
			float pale = smoothstep(line - 0.015, line + 0.015, s);
			color = mix(color, cape_color.rgb * mix(0.94, 1.04, skin_fbm(q * 18.0)), pale * cape);
		}
		// The saddle behind the dorsal: soft-edged, slanting back as it goes down.
		vec2 sp = vec2(along - saddle_at.x + s * 0.12, s) / vec2(saddle_at.y, saddle_at.z);
		float sad = (1.0 - smoothstep(0.85, 1.1, length(sp) + 0.15 * (skin_fbm(q * 20.0) - 0.5))) * saddle;
		color = mix(color, saddle_color.rgb * mix(0.92, 1.05, skin_fbm(q * 24.0)), sad);
		// The white, crisp-edged (each edge antialiased by its own slope): the
		// eye patch, an oval rising a little toward the back...
		vec2 ep = vec2(along - eye_patch.x, (s - eye_patch.y) * half_round + (along - eye_patch.x) * eye_patch_tilt);
		float ed = length(ep / eye_patch.zw) - 1.0 + 0.06 * (skin_fbm(q * 30.0) - 0.5);
		float eye_white = 1.0 - smoothstep(-1.0, 1.0, ed / max(fwidth(ed), 1e-4));
		// ...and the chin, throat and belly: white below an edge that drops
		// toward the belly between the flippers, sweeps up the flank into a lobe
		// and cuts back down behind it.
		float edge = mix(orca_band.x, orca_band.y, smoothstep(0.1, 0.26, along));
		edge = mix(edge, orca_band.z, smoothstep(orca_band.w - 0.11, orca_band.w, along));
		edge = mix(edge, 1.3, pow(smoothstep(orca_band.w, orca_band.w + 0.16, along), 0.7));
		edge += 0.012 * (skin_fbm(q * 22.0) - 0.5);
		float bd = (s - edge) * half_round;
		float band = smoothstep(-1.0, 1.0, bd / max(fwidth(bd), 1e-4));
		float patches = max(eye_white, band) * orca;
		color = mix(color, patch_color.rgb * mix(0.95, 1.02, skin_fbm(q * 16.0)), patches);
		belly = max(belly, band * orca);
	}

	// The mouth line: from the snout round to its corner, bowing up between.
	float line_s = 2.0;
	if (mouth_width > 0.0) {
		float t = clamp(along / max(mouth_corner, 0.01), 0.0, 1.0);
		line_s = mix(mouth_tip_s, mouth_s, t) - mouth_arch * sin(PI * t) + 0.025 * smoothstep(0.88, 1.0, t);
		float d = abs(s - line_s) * half_round * body_length - mouth_width * mix(0.7, 0.35, t);
		d = along > mouth_corner ? 1.0e3 : d;
		float aa = clamp(fwidth(d), 1e-4, mouth_width);
		float line = 1.0 - smoothstep(-aa, aa, d);
		color = mix(color, mouth_color.rgb, line);
		if (pale_lips > 0.0) {
			float lips = (1.0 - smoothstep(0.0, mouth_width * 3.0, abs(d + mouth_width * 0.5))) * (1.0 - line);
			color = mix(color, vec3(0.86, 0.86, 0.84), lips * pale_lips * 0.85);
		}
		// The lip: the upper jaw's edge stands a little proud of the lower.
		height -= 0.0012 * exp(-pow(max(d, 0.0) / (mouth_width * 2.0), 2.0)) * step(along, mouth_corner);
	}

	// Tubercles: knobs in rows on the rostrum (either side of its midline) and
	// along the lower jaw under the mouth line, each with a hair pit.
	if (tubercles > 0.0) {
		float zone = (1.0 - smoothstep(0.15, 0.2, along)) * smoothstep(0.004, 0.02, along);
		float top_zone = (1.0 - smoothstep(0.045, 0.06, arc)) * zone;
		float jaw_zone = smoothstep(line_s + 0.015, line_s + 0.04, s) * (1.0 - smoothstep(line_s + 0.16, line_s + 0.22, s)) * zone;
		float knob = titan_knobs(vec2(over, arc), 0.011, 0.3, 5.0) * (top_zone + jaw_zone * 0.85) * tubercles;
		height += 0.0024 * knob * medium;
		color = mix(color, color * 0.78, knob * 0.35);
		color = mix(color, vec3(0.02), smoothstep(0.85, 0.97, knob) * 0.6 * fine);
	}

	// Throat pleats: long grooves along the belly from the chin to the navel,
	// pale-pink in their depths.
	if (pleats > 0.0) {
		float from_belly = half_round - arc;
		// Closer together toward the chin, where the throat narrows; nearly
		// straight, with a slight, slow wander.
		float pitch = pleat_pitch / body_length * clamp(half_round / 0.3, 0.45, 1.0);
		float qp = from_belly / pitch + 0.12 * sin(over * 9.0 + from_belly * 12.0);
		float groove = pow(abs(sin(qp * PI)), 8.0);
		float pz = (pleat_z - nose_z) / body_length;
		float zone = smoothstep(pleat_s - 0.04, pleat_s + 0.03, s) * smoothstep(0.02, 0.06, along) * (1.0 - smoothstep(pz - 0.06, pz, along));
		float g = groove * zone * pleats;
		height -= 0.0014 * g * medium;
		shade *= 1.0 - 0.25 * g * medium;
		color = mix(color, color * vec3(1.0, 0.86, 0.84), g * belly * 0.5);
	}

	// Wrinkles: prune-skin ridges round the body, crossed with finer creases.
	if (wrinkle > 0.0) {
		float creases;
		float zone;
		if (wrinkle >= 0.99) {
			// The sperm whale's prune skin: furrows running mostly along the
			// body, wandering and breaking off, crossed by short creases.
			float wander = 2.2 * skin_fbm(q * vec3(5.0, 9.0, 3.0)) + 1.2 * skin_fbm(q * vec3(9.0, 16.0, 9.0) + 6.0);
			float furrow = abs(fract(arc / 0.013 + wander) - 0.5);
			float broken = smoothstep(0.35, 0.6, skin_fbm(q * vec3(14.0, 14.0, 7.0) + 2.0));
			float cross_line = abs(fract(over / 0.02 + 2.0 * skin_fbm(q * 11.0 + 4.0)) - 0.5);
			float cross_on = smoothstep(0.55, 0.7, skin_fbm(q * 16.0 + 9.0));
			creases = (1.0 - smoothstep(0.04, 0.2, furrow)) * broken + (1.0 - smoothstep(0.03, 0.12, cross_line)) * cross_on * 0.6;
			zone = smoothstep(0.24, 0.34, along);
		} else {
			float big = abs(skin_fbm(q * vec3(16.0, 20.0, 9.0)) - 0.5);
			float small = abs(skin_fbm(q * vec3(38.0, 44.0, 24.0) + 5.0) - 0.5);
			creases = (1.0 - smoothstep(0.0, 0.045, big)) * 0.8 + (1.0 - smoothstep(0.0, 0.04, small)) * 0.4 * fine;
			zone = exp(-pow((along - 0.19) / 0.05, 2.0));
		}
		height -= 0.0014 * creases * zone * wrinkle * medium;
		shade *= 1.0 - 0.1 * creases * zone * wrinkle;
	}

	// Barnacles: tight clusters on the chin and along the lower jaw (and a
	// few on the throat's edge by the navel).
	if (barnacles > 0.0) {
		float chin = (1.0 - smoothstep(0.05, 0.1, along)) * smoothstep(0.5, 0.62, s);
		float jaw = (1.0 - smoothstep(0.16, 0.22, along)) * smoothstep(line_s + 0.02, line_s + 0.05, s) * (1.0 - smoothstep(0.8, 0.9, s));
		float navel = exp(-pow((along - 0.52) / 0.03, 2.0)) * smoothstep(0.9, 0.97, s) * 0.8;
		float zone = max(max(chin, jaw), navel);
		float clump = smoothstep(0.6, 0.72, skin_fbm(q * 26.0 + pattern_seed * 2.0)) * zone * barnacles;
		vec2 b = titan_barnacles(vec2(over, arc), 0.0055, pattern_seed);
		float on = clump * step(0.01, b.x + b.y);
		vec3 shell = vec3(0.76, 0.73, 0.66) * mix(0.8, 1.05, skin_fbm(q * 300.0));
		color = mix(color, shell, clump * smoothstep(0.0, 0.3, b.x) * mix(0.5, 1.0, fine));
		color = mix(color, vec3(0.05, 0.045, 0.04), clump * b.y * fine);
		// A cream crust of old barnacle scars round each clump.
		color = mix(color, vec3(0.62, 0.6, 0.55), smoothstep(0.52, 0.6, skin_fbm(q * 26.0 + pattern_seed * 2.0)) * zone * barnacles * 0.3 * (1.0 - on));
		height += 0.0016 * clump * (b.x - b.y * 0.8) * medium;
	}

	// Scars: pale rake marks and cookie-cutter rings over the flanks and back.
	if (scars > 0.0) {
		float zone = smoothstep(0.12, 0.25, along) * (1.0 - smoothstep(0.85, 0.95, along));
		float mark = titan_scars(vec2(along, s * half_round), pattern_seed) * zone * scars;
		color = mix(color, mix(color, scar_color.rgb, 0.7), mark * mix(0.5, 1.0, medium));
		height += 0.0004 * mark * fine;
	}

	// The eye: a sunk socket with a dark rim, a soft lid round it, a heavy fold
	// above (wrinkled), and creases fanning back from its corner.
	vec3 eye_off = vec3(abs(rest.x), rest.y, rest.z) - eye_pos;
	float eye_d = length(eye_off) / eye_radius;
	float above = smoothstep(-0.2, 0.8, eye_off.y / eye_radius);
	shade *= mix(0.55, 1.0, smoothstep(0.95, 1.6, eye_d));
	float lid = exp(-pow((eye_d - 1.25) / 0.3, 2.0));
	float fold = exp(-pow((eye_d - 2.3) / 0.7, 2.0)) * above;
	height += (0.0011 * lid + 0.0016 * fold) * eye_radius / body_length / 0.0045;
	float creases = abs(sin(atan(eye_off.y, eye_off.z) * 7.0)) * smoothstep(1.5, 2.2, eye_d) * (1.0 - smoothstep(3.0, 4.5, eye_d));
	height -= 0.0003 * creases * fine;
	color = mix(color, color * 0.72, lid * 0.4);

	// The blowhole: slits on top of the head, in a raised splashguard.
	vec2 bh = vec2(rest.x - blow_pos.x, rest.z - blow_pos.z) / body_length;
	float on_top = smoothstep(blow_pos.y / body_length - 0.012, blow_pos.y / body_length - 0.004, q.y);
	float slit;
	if (blow_pair > 0.5) {
		vec2 p = vec2(abs(bh.x) - 0.006 + bh.y * 0.25, bh.y);
		slit = length(p / vec2(0.0016, 0.009));
	} else if (blow_pos.x < -0.001) {
		vec2 p = vec2(bh.x + 0.003 * sin(bh.y * 400.0), bh.y);
		slit = length(p / vec2(0.0018, 0.009));
	} else {
		vec2 p = vec2(bh.x, bh.y + 40.0 * bh.x * bh.x);
		slit = length(p / vec2(0.009, 0.0022));
	}
	float hole = (1.0 - smoothstep(0.7, 1.0, slit)) * on_top;
	float guard = exp(-pow(length(bh + vec2(0.0, 0.01)) / 0.016, 2.0)) * on_top * splashguard;
	height += 0.0022 * guard - 0.0025 * hole;
	color = mix(color, vec3(0.025), hole * 0.9);

	// Fine skin grain.
	height += 0.00004 * skin_noise(q * 900.0) * fine;

	// The painted height (L) tilts the normal.
	height *= body_length;
	vec3 n = normalize(NORMAL);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * n - grad);

	ALBEDO = color * shade;
	ROUGHNESS = clamp(roughness + 0.08 * belly + 0.1 * wrinkle * (1.0 - shade) - 0.05 * (1.0 - belly) * skin_fbm(q * 14.0), 0.05, 1.0);
	SPECULAR = 0.5;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.25;
	BACKLIGHT = vec3(0.05, 0.04, 0.04) + vec3(0.25, 0.2, 0.18) * sss;
	SSS_STRENGTH = sss;
	RIM = 0.2;
	RIM_TINT = 0.6;
}
