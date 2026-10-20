shader_type spatial;
// A shark's skin (SharkModel): `albedo` (the colour set_body_color() tints) is
// its back, darkest along the spine and paler down the flank to a countershading
// line (ragged for a great white, crisp for a mako, soft for the rest) over a
// pale belly. Five gill slits either side (each a dark cut with a lit flap
// edge behind it), an underslung mouth line, nostrils under
// the snout, a dark rim round each eye, and the species' marks: a tiger's
// bars, a blacktip's pale flank band, a great white's dark armpit patch.
// Fine denticle grain in the light, a satin wet sheen, a mako's metallic
// back. Painted from the resting shape (UV.y and UV2.x are the slice's cos and
// sin round the body, top 0), so nothing slides as the body bends into the
// tail (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.31, 0.35, 0.39, 1.0);  // the back
uniform vec4 belly_color : source_color = vec4(0.93, 0.94, 0.92, 1.0);
uniform vec4 mark_color : source_color = vec4(0.12, 0.11, 0.08, 1.0);  // tiger bars, armpit patch
uniform vec4 slit_color : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform float flank_lift = 0.3;  // how much paler the flank is than the spine
uniform float belly_line = -0.05;  // the line's height round the body (cos: 1 top, -1 bottom)
uniform float line_soft = 0.015;
uniform float ragged = 0.15;  // how far the line wanders up and down
uniform float ragged_scale = 9.0;  // its wiggles per metre
uniform float metal = 0.0;  // the back's metallic sheen
uniform float pattern = 0.0;  // 0 none, 1 tiger bars, 2 blacktip flank band, 3 great white armpit
uniform float bar_step = 0.075;  // m between tiger bars
uniform float bar_strength = 0.7;
uniform float head_z = -0.4;  // m: tiger bars fade out ahead of here into spots
uniform vec2 band_span = vec2(0.0, 0.3);  // m, the blacktip band's ends
uniform vec3 axilla = vec3(0.2, -0.05, -0.2);  // m, the armpit patch (right side; mirrored)
uniform float axilla_size = 0.035;
uniform float gill_z = -0.35;  // m, the first slit
uniform float gill_step = 0.024;  // m between slits
uniform vec2 gill_up = vec2(-0.45, 0.5);  // the slits' bottom and top round the body
uniform float gill_slant = 0.012;  // m their bottoms lean back
uniform float mouth_z = -0.55;  // m, the front of the mouth's curve
uniform float mouth_width = 0.1;  // m, half its width
uniform float mouth_back = 0.07;  // m its corners sit behind its front
uniform vec2 nostril = vec2(0.05, -0.6);  // m: x either side, z
uniform vec3 eye_at = vec3(0.1, 0.05, -0.5);  // m, the right eye
uniform float eye_size = 0.018;  // m, its radius
uniform float grain = 0.35;  // denticle bump strength

varying vec3 rest;
varying vec2 ring;  // (sin, cos) round the slice, top (0, 1)

void vertex() {
	rest = VERTEX;
	ring = vec2(UV2.x, UV.y);
	fish_bend(VERTEX, NORMAL);
}

// A soft-edged line `width` m wide at `d` m off it.
float cut(float d, float width) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(width - aa, width + aa, abs(d));
}

void fragment() {
	vec2 rr = ring / max(length(ring), 1e-4);
	float up = rr.y;  // 1 the spine, -1 the belly
	float side = abs(rr.x);
	float s = sign(rest.x + 1e-5);
	vec3 p = vec3(abs(rest.x), rest.yz);  // mirrored, so both sides match
	// Countershading: the line wanders (a great white's in sharp jags).
	float wander = (skin_fbm(vec3(rest.z * ragged_scale, s * 3.1, 0.7)) - 0.5) * 2.0;
	wander += (skin_noise(vec3(rest.z * ragged_scale * 4.0, s * 5.3, 2.0)) - 0.5) * 0.6;
	float line = up - belly_line - ragged * wander;
	float back = smoothstep(-line_soft, line_soft, line);
	float spine = smoothstep(belly_line, 0.98, up);
	vec3 top = albedo.rgb * mix(1.0 + flank_lift, 0.78, spine);
	top *= mix(0.92, 1.06, skin_fbm(rest * 11.0));  // faint mottling
	vec3 under = belly_color.rgb * mix(0.94, 1.0, skin_fbm(rest * 7.0 + 3.0));
	// A little grey creeps under the line before the belly turns clean.
	under = mix(under, mix(under, top, 0.35), smoothstep(-0.35, 0.0, line) * (1.0 - back));
	vec3 color = mix(under, top, back);
	vec3 mark = mix(albedo.rgb * 0.32, mark_color.rgb, 0.55);
	// Tiger: dark bars slanting down the back and flanks, broken into spots,
	// fading to scattered spots on the head.
	if (pattern > 0.5 && pattern < 1.5) {
		float warp = (skin_fbm(vec3(rest.z * 8.0, rest.y * 6.0, s)) - 0.5) * 0.5;
		float zz = rest.z / bar_step + (1.0 - up) * 0.55 + warp;
		float bar = 1.0 - smoothstep(0.12, 0.26, abs(fract(zz) - 0.5));
		float broken = smoothstep(0.32, 0.55, skin_fbm(vec3(rest.z * 22.0, rest.y * 22.0, p.x * 22.0 + s)));
		float spots = smoothstep(0.62, 0.7, skin_noise(p * 55.0));
		float body = smoothstep(head_z, head_z + 0.12, rest.z);
		float on_back = smoothstep(belly_line + 0.05, belly_line + 0.3, up);
		float amount = mix(spots, bar * broken, body) * on_back * bar_strength;
		color = mix(color, mark, amount);
	}
	// Blacktip: a pale band sweeping up from the belly along the flank.
	if (pattern > 1.5 && pattern < 2.5) {
		float t = clamp((rest.z - band_span.x) / (band_span.y - band_span.x), 0.0, 1.0);
		float height = belly_line + 0.08 + 0.32 * sin(t * PI) * (1.0 - 0.4 * t);
		float in_band = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.85, 1.0, t));
		float band = (1.0 - smoothstep(height - 0.05, height + 0.03, up)) * smoothstep(belly_line - 0.1, belly_line, up) * in_band;
		color = mix(color, mix(under, top, 0.15), band * 0.85);
	}
	// Great white: a dark patch in the pectoral fin's armpit.
	if (pattern > 2.5) {
		float d = length((p - axilla) * vec3(1.0, 1.0, 0.6));
		float n = (skin_noise(p * 80.0) - 0.5) * axilla_size * 0.5;
		color = mix(color, mark * 0.7, (1.0 - smoothstep(axilla_size * 0.6, axilla_size + n, d)) * 0.85);
	}
	// Gill slits: five cuts down each side, leaning back at the bottom, each a
	// dark slit with its flap's lit edge just behind it.
	float on_side = smoothstep(gill_up.x - 0.05, gill_up.x + 0.12, up) * (1.0 - smoothstep(gill_up.y - 0.12, gill_up.y + 0.02, up));
	float mid = (gill_up.x + gill_up.y) * 0.5;
	float zg = rest.z - gill_z + gill_slant * (mid - up) / max(gill_up.y - gill_up.x, 0.1) * 2.0;
	float k = clamp(round(zg / gill_step), 0.0, 4.0);
	float shrink = 1.0 - 0.07 * k;
	float reach = (1.0 - smoothstep(shrink - 0.15, shrink, abs(up - mid) / max((gill_up.y - gill_up.x) * 0.5, 0.05)));
	float d_slit = zg - k * gill_step;
	float slit = cut(d_slit, 0.0022) * on_side * reach;
	float flap = (1.0 - smoothstep(0.0, 0.0045, abs(d_slit - 0.006))) * on_side * reach;
	color = mix(color, color * 1.12 + 0.02, flap * 0.5);
	color = mix(color, slit_color.rgb, slit * 0.9);
	// The mouth: an underslung crescent under the snout, the upper jaw's
	// overhang shading it.
	float below = 1.0 - smoothstep(-0.6, -0.3, up);
	float x = p.x / mouth_width;
	float curve = mouth_z + mouth_back * x * x;
	float in_width = 1.0 - smoothstep(0.95, 1.05, x);
	float mouth = cut(rest.z - curve, 0.0026) * in_width * below;
	float overhang = smoothstep(-0.025, 0.0, rest.z - curve) * (1.0 - smoothstep(0.0, 0.004, rest.z - curve)) * in_width * below;
	color *= 1.0 - 0.25 * overhang;
	color = mix(color, slit_color.rgb, mouth);
	// Nostrils: little slanted slots under the snout.
	vec2 nq = vec2(p.x - nostril.x, rest.z - nostril.y);
	nq = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * nq;
	float nose_hole = (1.0 - smoothstep(0.8, 1.0, length(nq / vec2(0.009, 0.0035)))) * below;
	color = mix(color, slit_color.rgb, nose_hole * 0.85);
	// A dark rim round each eye where the skin folds in.
	float eye_d = length(p - eye_at);
	color *= 1.0 - 0.45 * (1.0 - smoothstep(eye_size * 1.05, eye_size * 1.7, eye_d));
	// Denticle grain: the skin's sheen breaks up a little (its roughness, not
	// its normal, so it never sparkles at a distance).
	float grit = skin_fbm(rest * 90.0);
	ALBEDO = color;
	METALLIC = metal * back;
	ROUGHNESS = mix(0.5, mix(0.42, 0.28, metal), back) + grain * (grit - 0.5) * 0.3;
	SPECULAR = 0.5;
	CLEARCOAT = 0.35;
	CLEARCOAT_ROUGHNESS = 0.35;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
