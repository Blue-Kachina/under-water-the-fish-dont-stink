shader_type spatial;
// The Alchemists (SeaHareModel), all of them: the body (part 0), the parapodia
// or mantle skirt (1, on hinges that roll with the fin pivots), the head's
// rhinophores and oral tentacles and the Tinctoria's gill plume (2), and the
// Ragged's jelly-coral growths (3). Soft slug skin painted from the resting
// shape in the model's own space (part_origin carries a hinge's place), so the
// pattern never slides as the body waves, the tail bends (fish_bend.gdshaderinc)
// or a flap beats. Wrinkles and tiny papillae are bumped into the normal; light
// scatters into the flesh and glows through the flaps and growths.
//
// The body wave: a wave runs down the body behind the head (side to side, and
// up and down, much more with each stride's push), and everything riding the
// body moves with it: flaps (turned into their hinge's roll), the plume and the
// growths. Head parts sit in their own space and set sway 0.
//
// pattern 0 (California): translucent red, dense dark maroon dots, sparse white
// sparkles. 1 (Spotted): pale cream with black rings (some big, paler inside)
// and a cracked dark network. 2 (Ragged): dark olive with pale granules and
// blue spots ringed dark. 3 (Tinctoria): a red net over white (dense white
// spots), darker red patches, a white underside. Sizes in metres.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.66, 0.2, 0.2, 1.0);  // set_body_color() tints it
uniform vec4 second_color : source_color = vec4(0.29, 0.05, 0.08, 1.0);
uniform vec4 third_color : source_color = vec4(0.94, 0.88, 0.78, 1.0);
uniform vec4 belly_color : source_color = vec4(0.72, 0.29, 0.27, 1.0);
uniform vec4 rim_color : source_color = vec4(0.88, 0.78, 0.69, 1.0);  // the flaps' free edge
uniform vec4 inner_color : source_color = vec4(0.48, 0.11, 0.13, 1.0);  // inside the flaps, and the back they cover
uniform vec4 horn_color : source_color = vec4(0.6, 0.16, 0.16, 1.0);
uniform vec4 base_color : source_color = vec4(1.0);  // a horn's stalk, up to base_len
uniform vec4 tip_color : source_color = vec4(0.9, 0.85, 0.6, 1.0);
uniform vec4 edge_color : source_color = vec4(0.7, 0.1, 0.1, 1.0);  // a flat horn's (the plume's) edges
uniform vec4 growth_color : source_color = vec4(0.55, 0.58, 0.41, 1.0);
uniform vec4 growth_spot : source_color = vec4(0.16, 0.16, 0.09, 1.0);
uniform int pattern = 0;
uniform float seed = 1.0;
uniform int part = 0;  // 0 body, 1 flap, 2 horn or plume, 3 growth
uniform vec3 part_origin = vec3(0.0);  // m, where the mesh sits in the model at rest
uniform float roughness = 0.5;
uniform float specular = 0.5;
uniform float clearcoat = 0.0;  // the wet sheen
uniform float bump = 1.0;  // the wrinkles' and papillae's depth, of the usual
uniform float knobs = 0.0;  // 0..1, how much the flaps' rim knobs take the rim colour
uniform float rim_from = 0.8;  // how far out the flaps' rim colour starts, 0..1
uniform float cover = 0.6;  // how deep the shade the flaps cast on the back
uniform float mantle = 0.0;  // 0..1, a pale band round the body's widest line (rim_color)
uniform float horn_mix = 0.55;  // the horns: the skin (0) to horn_color (1)
uniform float base_len = 0.0;  // of a horn's length, its stalk in base_color
uniform float lamellae = 0.0;  // ridges round a horn past its stalk
uniform float tip_mix = 0.0;  // how much its tip takes tip_color
uniform float edge_mix = 0.0;  // how much a flat horn's edges take edge_color
uniform float groove_shade = 0.45;  // how dark a rolled horn's slit is
uniform vec3 eye_at = vec3(0.15, 0.0, -0.47);  // m, the right eye
uniform float eye_radius = 0.018;  // 0 for no eyes
uniform float nose_z = -0.62;
uniform vec2 flap_span = vec2(0.0);  // z the flaps cover the back between
// The flaps' free edge ripples: a wave running back along it (part 1).
uniform float wave_amp = 0.012;  // m at the edge
uniform float waves = 1.5;  // along the flap
uniform float tempo = 1.0;  // against the swim
uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out
// The body wave (see above).
uniform float sway = 1.0;  // 1 rides it, 0 doesn't
uniform float wave_from = -0.35;  // m (z) it starts at, behind the head
uniform float wave_len = 0.95;  // m from there to the tail tip
uniform float sway_amp = 0.015;  // m side to side at the tail, idling
uniform float heave_amp = 0.02;  // m up and down at the tail, a stride's push
uniform float body_waves = 0.9;  // along the body
uniform float stride = 0.0;  // a stride's push now, 0..1
uniform float hinge_roll = 0.0;  // rad, a flap's hinge now
// A growth's jelly wobble (part 3): m at wobble_len out.
uniform float wobble = 0.01;
uniform float wobble_len = 0.12;

varying vec3 rest;
varying float up;  // 1 the top of the back, -1 the sole

vec3 body_wave(vec3 at) {
	float s = clamp((at.z - wave_from) / wave_len, 0.0, 1.0);
	float grow = smoothstep(0.0, 0.5, s) * (0.35 + 0.65 * s);
	float a = TAU * body_waves * s - phase;
	float side = sway_amp * (1.0 + 1.5 * effort + 1.5 * stride);
	float lift = heave_amp * (0.3 + 0.7 * effort + 3.0 * stride);
	return vec3(side * sin(a), lift * sin(a + 1.3), 0.0) * grow;
}

void vertex() {
	rest = VERTEX + part_origin;
	up = part == 0 ? cos(TAU * UV.y) : NORMAL.y;
	// Ride the body: its wave, then its bend into the tail (fish_bend, on the
	// meshes FishModel bends), as a shift from the resting place.
	vec3 moved = rest + body_wave(rest) * sway;
	vec3 n = NORMAL;
	fish_bend(moved, n);
	vec3 shift = moved - rest;
	if (part == 1) {
		// Into the hinge's roll. COLOR carries the flap sheet's normal (both faces
		// ripple together, so it keeps its thickness); UV2.x how far out, 0..1.
		float c = cos(hinge_roll);
		float s = sin(hinge_roll);
		shift = vec3(shift.x * c + shift.y * s, -shift.x * s + shift.y * c, shift.z);
		vec3 sheet = COLOR.rgb * 2.0 - 1.0;
		float v = UV2.x;
		float a = TAU * waves * UV.x - phase * tempo;
		VERTEX += sheet * wave_amp * (1.0 + 1.5 * effort) * v * v * (sin(a) + 0.3 * sin(2.7 * a + 1.3));
	} else if (part == 3) {
		// UV2.x is how far out along the growth (m): the further, the more it wobbles.
		float reach = UV2.x / wobble_len;
		float a = phase * 0.9 + rest.z * 18.0 + rest.x * 11.0;
		VERTEX += vec3(sin(a), 0.6 * sin(1.3 * a + 1.0), 0.4 * cos(a)) * wobble * (1.0 + effort) * reach * reach;
	}
	VERTEX += shift;
	NORMAL = n;
}

// The skin's relief (m): soft wrinkles running round the body, and papillae.
float relief(vec3 p) {
	float wrinkle = skin_fbm(p * vec3(24.0, 24.0, 58.0) + seed);
	float papillae = skin_noise(p * 150.0 + seed * 3.0);
	return wrinkle * 0.006 + papillae * 0.0014;
}

// Broken rings, each round its own scattered point and of its own size:
// (1 on a ring, 1 inside one).
vec2 rings(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec2 best = vec2(0.0);
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 c = vec3(skin_hash(i + o), skin_hash(i + o + 7.1), skin_hash(i + o + 13.7)) * 0.8 + 0.1;
		float r = mix(0.12, 0.38, pow(skin_hash(i + o + 19.3), 1.6));
		float d = length(o + c - f);
		float width = r * 0.26;
		best.x = max(best.x, 1.0 - smoothstep(width * 0.3, width, abs(d - r)));
		best.y = max(best.y, 1.0 - smoothstep(r * 0.7, r * 0.85, d));
	}
	return best;
}

// The nearest scattered spot: (its distance, its size), in cells.
vec2 spots(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec2 best = vec2(8.0, 0.0);
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 c = vec3(skin_hash(i + o + 3.3), skin_hash(i + o + 5.9), skin_hash(i + o + 11.1)) * 0.8 + 0.1;
		float d = length(o + c - f);
		if (d < best.x) {
			best = vec2(d, mix(0.07, 0.15, skin_hash(i + o + 17.9)));
		}
	}
	return best;
}

// 1 on a crack: the edges between scattered cells (how much nearer the nearest
// point is than the next).
float cracks(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 c = vec3(skin_hash(i + o + 2.7), skin_hash(i + o + 8.3), skin_hash(i + o + 12.9));
		float d = length(o + c - f);
		if (d < first) {
			second = first;
			first = d;
		} else if (d < second) {
			second = d;
		}
	}
	float aa = fwidth(second - first) + 0.01;
	return 1.0 - smoothstep(0.06 - aa, 0.06 + aa, second - first);
}

// A round spot of `cells` per metre, `size` times the usual: 1 on it.
float dot_at(vec3 w, float cells, float size) {
	vec2 spot = spots(w * cells);
	float aa = fwidth(spot.x) + 0.01;
	return 1.0 - smoothstep(spot.y * size - aa, spot.y * size + aa, spot.x);
}

vec3 skin_color(vec3 p) {
	vec3 q = p + vec3(seed);
	vec3 warp = vec3(skin_noise(q * 5.0), skin_noise(q * 5.0 + 11.3), skin_noise(q * 5.0 + 23.1)) - 0.5;
	vec3 w = q + warp * 0.1;
	vec3 color = albedo.rgb;
	if (pattern == 1) {
		color = mix(color, color * 0.85, smoothstep(0.4, 0.72, skin_fbm(w * 8.0)));
		vec3 lumpy = vec3(skin_noise(w * 30.0), skin_noise(w * 30.0 + 4.7), skin_noise(w * 30.0 + 9.2)) - 0.5;
		vec2 ring = rings(w * 5.5 + lumpy * 0.4);
		color = mix(color, third_color.rgb, ring.y * 0.7);
		float crack = max(cracks(w * 32.0 + lumpy * 0.6), cracks(w * 70.0) * 0.6);
		color = mix(color, second_color.rgb, crack * 0.95 * smoothstep(0.05, 0.35, skin_noise(w * 9.0 + 3.0)) * (1.0 - ring.y * 0.5));
		color = mix(color, second_color.rgb, ring.x);
	} else if (pattern == 2) {
		color = mix(color, color * 0.6, smoothstep(0.5, 0.75, skin_fbm(w * 12.0 + 8.0)));
		color = mix(color, second_color.rgb, dot_at(w, 80.0, 1.3) * 0.75);
		vec2 spot = spots(w * 7.0);
		float aa = fwidth(spot.x) + 0.01;
		float dark = 1.0 - smoothstep(spot.y * 1.45 - aa, spot.y * 1.45 + aa, spot.x);
		float blue = 1.0 - smoothstep(spot.y - aa, spot.y + aa, spot.x);
		color = mix(color, vec3(0.03, 0.03, 0.025), dark * 0.85);
		color = mix(color, third_color.rgb * mix(0.75, 1.15, 1.0 - spot.x / spot.y), blue);
	} else if (pattern == 3) {
		color = mix(color, second_color.rgb, smoothstep(0.5, 0.75, skin_fbm(w * 6.0)) * 0.75);
		vec2 spot = spots(w * 55.0);
		float aa = fwidth(spot.x) + 0.02;
		float size = spot.y * mix(3.8, 5.0, skin_noise(w * 9.0));
		color = mix(color, third_color.rgb, 1.0 - smoothstep(size - aa, size + aa, spot.x));
	} else {
		color = mix(color, belly_color.rgb, smoothstep(0.45, 0.7, skin_fbm(w * 7.0)) * 0.6);
		color = mix(color, second_color.rgb, dot_at(w, 30.0, 1.5) * 0.95);
		color = mix(color, third_color.rgb, dot_at(w, 26.0, 0.6) * smoothstep(0.6, 0.75, skin_noise(w * 8.0 + 5.0)));
	}
	return color;
}

// A growth's colour (part 3) `t` of the way out along its branch and `away` m
// from the body: pale and spotted dark like a leopard, the body's colour where
// it leaves the body, paler toward the tips.
vec3 growth(vec3 p, float t, float away) {
	vec3 q = p + vec3(seed);
	vec3 color = growth_color.rgb * mix(0.75, 1.15, t);
	color = mix(color, growth_spot.rgb, dot_at(q, 70.0, 2.0) * 0.85);
	color = mix(color, growth_spot.rgb, smoothstep(0.55, 0.8, skin_fbm(q * 40.0)) * 0.5);
	return mix(albedo.rgb, color, smoothstep(0.0, 0.025, away));
}

void fragment() {
	vec3 p = rest;
	vec3 color = part == 3 ? growth(p, UV.x, UV2.x) : skin_color(p);
	// Bump the relief into the normal: its slope in the model's space, turned
	// into the view's.
	float h0 = relief(p);
	float e = 0.0015;
	vec3 slope = vec3(relief(p + vec3(e, 0.0, 0.0)), relief(p + vec3(0.0, e, 0.0)), relief(p + vec3(0.0, 0.0, e))) - h0;
	vec3 view_slope = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * (slope / e);
	NORMAL = normalize(NORMAL - bump * (view_slope - dot(view_slope, NORMAL) * NORMAL));
	float glow = 0.0;
	if (part == 0) {
		// The sole, a pale band at the widest line, the back in the flaps' shade,
		// a pale ring round each eye and the mouth's slit under the nose.
		color = mix(color, mix(belly_color.rgb, color, 0.2), smoothstep(-0.3, -0.85, up));
		color = mix(color, rim_color.rgb, mantle * (1.0 - smoothstep(0.1, 0.35, abs(up + 0.05))));
		float shade = smoothstep(flap_span.x, flap_span.x + 0.08, rest.z) * smoothstep(flap_span.y, flap_span.y - 0.08, rest.z) * smoothstep(0.15, 0.7, up);
		color = mix(color, mix(color, inner_color.rgb, 0.4) * 0.55, shade * cover);
		if (eye_radius > 0.0) {
			float d = length(vec3(abs(rest.x), rest.y, rest.z) - eye_at);
			color = mix(color, mix(color, third_color.rgb, 0.25), 1.0 - smoothstep(eye_radius * 1.3, eye_radius * 1.9, d));
			color *= mix(0.45, 1.0, smoothstep(eye_radius * 0.95, eye_radius * 1.35, d));
		}
		float slit = (1.0 - smoothstep(0.003, 0.008, abs(rest.x))) * smoothstep(nose_z + 0.08, nose_z + 0.02, rest.z) * smoothstep(-0.05, -0.45, up);
		color = mix(color, color * 0.25, slit);
	} else if (part == 1) {
		// UV.y runs round the flap: 0 the outside's root, 0.5 its rim, 1 the
		// inside's root. UV2.y is how much of a rim knob it's on.
		float inside = smoothstep(0.47, 0.53, UV.y);
		color = mix(color, mix(inner_color.rgb, color * 0.7, 0.2), inside);
		float rim_to = rim_from + 0.15 * (1.0 - rim_from) / 0.2;
		float rim = smoothstep(rim_from, rim_to, UV2.x + 0.08 * UV2.y * knobs);
		color = mix(color, rim_color.rgb * (0.85 + 0.3 * skin_noise(p * 60.0)), rim);
		color *= mix(0.55, 1.0, smoothstep(0.0, 0.22, UV2.x));  // shaded where it leaves the body
		glow = mix(0.35, 0.6, UV2.x);
	} else if (part == 2) {
		// UV.x runs out along the horn, UV.y round it (0.75 down its slit; 0 and
		// 0.5 a flat one's edges).
		color = mix(color, horn_color.rgb, horn_mix);
		if (base_len > 0.0) {
			color = mix(color, base_color.rgb, 1.0 - smoothstep(base_len - 0.04, base_len + 0.04, UV.x));
		}
		if (lamellae > 0.0) {
			float ridge = smoothstep(0.3, 1.0, sin(UV.x * lamellae * TAU)) * smoothstep(base_len, base_len + 0.08, UV.x);
			color = mix(color, color * 0.55, ridge);
		}
		color = mix(color, tip_color.rgb, tip_mix * smoothstep(0.6, 1.0, UV.x));
		color = mix(color, edge_color.rgb, edge_mix * pow(abs(cos(TAU * UV.y)), 6.0));
		float off = abs(fract(UV.y - 0.75 + 0.5) - 0.5);
		color *= 1.0 - groove_shade * exp(-off * off / 0.004) * smoothstep(0.12, 0.4, UV.x);
		glow = 0.35;
	} else {
		// Jelly: light passes through the thin edges more than the core.
		glow = 0.9;
		color *= mix(0.75, 1.1, pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5));
	}
	color *= 0.92 + 0.16 * skin_noise(p * 140.0);
	color *= mix(0.8, 1.0, smoothstep(0.0018, 0.0058, h0));  // the creases' shade
	ALBEDO = color;
	ROUGHNESS = clamp(roughness * mix(0.85, 1.15, skin_noise(p * 30.0)), 0.05, 1.0);
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.3;
	SSS_STRENGTH = part == 3 ? 0.5 : 0.25;
	BACKLIGHT = color * glow;
	RIM = 0.12;
	RIM_TINT = 0.6;
}
