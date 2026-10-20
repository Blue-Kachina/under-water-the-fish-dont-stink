shader_type spatial;
// A billfish's skin (SwordfishModel), body, bill and lower jaw in one: an
// `albedo` flank (the colour set_body_color() tints) darkening to a deep back
// with an iridescent `sheen_color` at grazing angles, over a mirror-silver
// belly. Vertical bars or stripes (`bar_*`, dashed for the sailfish), a fine
// skin texture (tiny embedded scales, or none for the scaleless swordfish), a
// painted gill cover and mouth line, a dark rough bill in front of `bill_end`
// and dark tail-stalk keels. Painted from the resting shape, so nothing slides
// as the body bends (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.42, 0.31, 0.38, 1.0);  // the flanks
uniform float back_shade = 0.45;  // the back's colour, of albedo
uniform vec4 belly_color : source_color = vec4(0.88, 0.87, 0.89, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.75, 0.5, 0.3, 1.0);  // the back's iridescence
uniform float sheen = 0.5;
uniform float countershade = -0.15;  // the resting normal's y where back meets belly
uniform vec4 bill_color : source_color = vec4(0.2, 0.18, 0.2, 1.0);
uniform float bill_end = -0.3;  // z (m): the bill is in front of it
uniform float gill_z = -0.2;  // z (m) of the gill cover's back edge, at mid-height
uniform float gill_curve = 0.08;  // m it sweeps back toward the throat
uniform float mouth_z = -0.25;  // z (m) the mouth line runs back to from the bill
uniform float mouth_y = 0.0;  // its height (m)
uniform float keel_z = 0.4;  // z (m): the tail stalk's keels behind it
uniform float girth = 0.16;  // m, about the body's radius
uniform float scales = 1.0;  // 0 scaleless (smooth hide), 1 fine embedded scales
uniform vec4 bar_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);
uniform float bar_strength = 0.0;  // 0 for no bars
uniform float bar_spacing = 0.07;  // m between bars
uniform float bar_width = 0.25;  // of the spacing
uniform float bar_slant = 0.12;  // m back per m up
uniform float bar_low = -0.4;  // resting normal y the bars reach down to
uniform float bar_dash = 0.0;  // m: the bars broken into dashes this long, 0 solid
uniform vec2 bar_span = vec2(-0.3, 0.35);  // z (m) the bars run between

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	vec3 n = normalize(rest_normal);
	float wobble = (skin_fbm(rest * vec3(9.0, 9.0, 3.0) + 2.0) - 0.5);
	// Countershading: a deep back through the flank colour to a silver belly,
	// the line between them softly ragged.
	float back = smoothstep(countershade - 0.16, countershade + 0.16, n.y + wobble * 0.12);
	vec3 top = mix(albedo.rgb, albedo.rgb * back_shade, smoothstep(0.05, 0.8, n.y));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	top = mix(top, sheen_color.rgb * max(max(albedo.r, albedo.g), albedo.b) * 1.3, rim * sheen * smoothstep(-0.2, 0.4, n.y));
	vec3 belly = belly_color.rgb * mix(0.82, 1.0, smoothstep(-0.1, -0.8, n.y));
	vec3 color = mix(belly, top, back);
	// Bars or stripes down the flanks.
	float bars = 0.0;
	if (bar_strength > 0.0) {
		float u = (rest.z - bar_slant * rest.y) / bar_spacing + wobble * 0.25;
		float d = abs(fract(u) - 0.5) * 2.0;  // 0 mid-bar
		float aa = fwidth(u) * 2.0;
		if (bar_dash > 0.0) {
			// Broken into soft oval spots, each a little different.
			float row = rest.y / bar_dash + floor(u) * 0.37;
			float size = 0.75 + 0.35 * skin_hash(vec3(floor(u), floor(row), 3.0));
			vec2 q = vec2(d / bar_width, (fract(row) - 0.5) * 2.0 / 0.55) / size;
			bars = 1.0 - smoothstep(0.7, 1.0 + aa / bar_width, length(q));
		} else {
			bars = 1.0 - smoothstep(bar_width - aa, bar_width + aa, d);
		}
		float band = smoothstep(bar_low - 0.12, bar_low + 0.12, n.y) * (1.0 - smoothstep(0.7, 0.95, n.y));
		float run = smoothstep(bar_span.x, bar_span.x + 0.06, rest.z) * (1.0 - smoothstep(bar_span.y - 0.1, bar_span.y, rest.z));
		bars *= band * run * bar_strength;
		color = mix(color, bar_color.rgb * mix(0.95, 1.0, back), bars);
	}
	// Fine skin: tiny scales set in the hide, or a smooth hide's faint mottling.
	float grain = skin_scales(rest, 0.012, girth);
	color *= 1.0 - 0.07 * grain * scales * back;
	color *= 0.94 + 0.12 * skin_fbm(rest * 40.0);
	// The gill cover's edge sweeping back toward the throat, and the mouth line.
	float side = smoothstep(0.25, 0.55, abs(n.x));
	// A ")" curve: the cover's edge bows back at mid-height and runs forward
	// to the throat below and the nape above.
	float yr = (rest.y - mouth_y) / girth;
	float g = rest.z - (gill_z - gill_curve * yr * yr - gill_curve * 0.5 * max(-yr, 0.0));
	float gaa = fwidth(g);
	float gill = (1.0 - smoothstep(0.0015, 0.003 + gaa, abs(g))) * side * (1.0 - smoothstep(0.45, 0.7, n.y));
	float cover = smoothstep(-0.05, 0.0, g) * (1.0 - smoothstep(0.0, 0.003, g)) * side;  // the cover's edge, lit then shadowed
	color *= 1.0 - 0.3 * gill;
	color = mix(color, color * 1.12 + 0.02, cover * 0.5 * back);
	float my = rest.y - mouth_y;
	float mouth = (1.0 - smoothstep(0.0015, 0.003 + fwidth(my), abs(my))) * side
			* smoothstep(bill_end - 0.02, bill_end + 0.01, rest.z) * (1.0 - smoothstep(mouth_z - 0.01, mouth_z, rest.z));
	color *= 1.0 - 0.6 * mouth;
	// The keels on the tail stalk: dark and hard.
	float keel = smoothstep(keel_z, keel_z + 0.04, rest.z) * smoothstep(0.5, 0.85, abs(n.x));
	color = mix(color, albedo.rgb * back_shade * 0.6, keel * 0.7);
	// The bill: dark, rough, finely streaked lengthwise, blending into the head.
	float bill = smoothstep(bill_end + 0.03, bill_end - 0.03, rest.z);
	float streak = skin_noise(vec3(rest.x * 400.0, rest.y * 400.0, rest.z * 12.0));
	vec3 bill_col = mix(bill_color.rgb, albedo.rgb * back_shade, 0.35) * mix(0.8, 1.15, streak);
	bill_col = mix(bill_col, belly_color.rgb * 0.55, smoothstep(0.0, -0.8, n.y) * 0.5);
	color = mix(color, bill_col, bill);
	ALBEDO = color;
	float silver = (1.0 - back) * (1.0 - bill);
	METALLIC = mix(0.15, 0.6, silver) * (1.0 - bars * 0.5);
	ROUGHNESS = mix(mix(0.3, 0.2, silver), 0.6, bill) + 0.08 * grain * scales;
	SPECULAR = 0.65;
	CLEARCOAT = 0.5 * (1.0 - bill);
	CLEARCOAT_ROUGHNESS = 0.15;
	// A silver flash along the belly at grazing angles.
	EMISSION = belly_color.rgb * rim * silver * 0.08;
}
