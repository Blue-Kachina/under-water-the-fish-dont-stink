shader_type spatial;
// A lionfish's body (LionfishModel): a ground colour with bands round it of
// varying width (curving forward in the middle of the flank and slanting down
// and back over the cheeks), thin lines between them, a dark bar through the
// eye, mottling, pale lines along the tail stalk (the clearfin), a paler belly,
// a mouth and gill-cover line, fine scales and a wet sheen. Painted from the
// resting shape, so it never slides as the body bends (fish_bend.gdshaderinc).
// Sizes in metres. On a lofted body (FishModel._loft_mesh), whose UV.y runs
// round it from the top of its back.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.52, 0.09, 0.08, 1.0);  // set_body_color() tints it
uniform vec4 ground : source_color = vec4(0.97, 0.92, 0.85, 1.0);
uniform float ground_tint = 0.0;  // the ground: `ground` (0) to albedo (1)
uniform vec4 band : source_color = vec4(0.52, 0.09, 0.08, 1.0);
uniform float band_tint = 1.0;  // the bands: `band` (0) to albedo times band_shade (1)
uniform float band_shade = 1.0;
uniform float band_strength = 1.0;
uniform float band_period = 0.085;  // m from band to band
uniform vec2 band_duty = vec2(0.35, 0.6);  // the narrowest and widest band, of the period
uniform float band_soft = 0.03;  // of the period, the bands' edges
uniform float band_bulge = 0.02;  // m the bands' middles sit ahead of their ends
uniform float thin_line = 0.0;  // a thin line between the bands, 0..1
uniform float mottle = 0.0;  // 0..1 dark blotches and pale flecks
uniform vec4 mottle_color : source_color = vec4(0.35, 0.16, 0.08, 1.0);
uniform vec4 fleck_color : source_color = vec4(0.95, 0.85, 0.75, 1.0);
uniform float stalk_lines = 0.0;  // 0..1: two pale lines along each side of the tail stalk
uniform float stalk_from = 0.15;  // m (z) they start at
uniform float belly_lift = 1.25;  // how much paler the belly is
uniform float head_z = -0.25;  // m: in front of here the bands slant down and back
uniform float head_slant = 0.35;
uniform vec3 eye_at = vec3(0.06, 0.06, -0.42);  // m, the right eye
uniform float eye_radius = 0.03;
uniform float eye_bar = 1.0;  // 0..1
uniform float nose_z = -0.56;
uniform float mouth_y = -0.03;  // m, the mouth's corner line at the nose
uniform float mouth_back = 0.07;  // m behind the nose its corner is
uniform float gill_z = -0.33;  // m, the gill cover's edge
uniform float girth = 0.15;  // m, about the body's radius
uniform float roughness = 0.34;

varying vec3 rest;
varying vec3 rest_normal;
varying float up;  // 1 the top of the back, -1 the belly

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	up = cos(TAU * UV.y);
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	vec3 ground_rgb = mix(ground.rgb, albedo.rgb, ground_tint);
	vec3 band_rgb = mix(band.rgb, albedo.rgb * band_shade, band_tint);
	float belly = smoothstep(0.0, -0.75, up);
	float back = smoothstep(0.3, 0.95, up);
	vec3 color = ground_rgb * mix(1.0, 0.82, back);
	color = mix(color, min(ground_rgb * belly_lift + vec3(0.06), vec3(1.0)), belly);
	// The bands: a coordinate along the body, curving forward mid-flank and
	// slanting over the head, cut into cells each holding one band.
	float head = smoothstep(head_z, head_z - 0.08, rest.z);
	float wobble = (skin_noise(rest * 18.0) - 0.5) * band_period * 0.18;
	float s = rest.z - band_bulge * (1.0 - up * up) + head_slant * head * (rest.y - eye_at.y) + wobble;
	float p = s / band_period;
	float cell = floor(p);
	float f = fract(p);
	float duty = mix(band_duty.x, band_duty.y, skin_hash(vec3(cell, 3.1, 7.7)));
	float aa = fwidth(p) * 0.8 + band_soft;
	float on_band = 1.0 - smoothstep(-aa, aa, abs(f - 0.5) - duty * 0.5);
	float gap = min(f, 1.0 - f);
	float thin = (1.0 - smoothstep(0.035 - aa * 0.5, 0.035 + aa * 0.5, gap)) * thin_line;
	float strength = band_strength * mix(1.0, 0.7, belly) * (1.0 - 0.75 * smoothstep(nose_z + 0.05, nose_z + 0.01, rest.z));
	color = mix(color, band_rgb * mix(1.0, 1.25, belly), on_band * strength);
	color = mix(color, mix(ground_rgb, band_rgb, 0.75), thin * strength);
	// The bar down through the eye, slanting back.
	vec2 from_eye = vec2(rest.z - eye_at.z, rest.y - eye_at.y);
	vec2 bar_dir = normalize(vec2(0.35, -1.0));
	float across = abs(dot(from_eye, vec2(-bar_dir.y, bar_dir.x)));
	float along = dot(from_eye, bar_dir);
	float bar = (1.0 - smoothstep(eye_radius * 0.75, eye_radius * 1.05, across)) * (1.0 - smoothstep(eye_radius * 2.2, eye_radius * 3.2, abs(along + eye_radius * 0.4)));
	color = mix(color, band_rgb * 0.8, bar * eye_bar * smoothstep(0.1, 0.4, abs(rest_normal.x)));
	// Mottling: dark blotches and pale flecks.
	if (mottle > 0.0) {
		float blotch = smoothstep(0.45, 0.7, skin_fbm(rest * 22.0 + 3.0));
		float fleck = smoothstep(0.6, 0.7, skin_fbm(rest * 55.0 + 9.0)) * smoothstep(0.35, 0.6, skin_noise(rest * 25.0 + 1.0));
		color = mix(color, mottle_color.rgb * mix(1.0, 1.4, belly), blotch * mottle * 0.65);
		color = mix(color, mix(fleck_color.rgb, ground_rgb, 0.3), fleck * mottle * 0.55);
	}
	// Two pale lines along each side of the tail stalk.
	if (stalk_lines > 0.0) {
		float line = 1.0 - smoothstep(0.05, 0.1, abs(abs(up) - 0.42));
		line *= smoothstep(stalk_from, stalk_from + 0.03, rest.z) * smoothstep(0.2, 0.5, abs(rest_normal.x));
		color = mix(color, band_rgb, line * stalk_lines);
	}
	// The mouth: a dark line back from the nose, sloping down; the gill cover's edge.
	float mouth_line = abs(rest.y - (mouth_y - (rest.z - nose_z) * 0.35));
	float mouth = (1.0 - smoothstep(0.0025, 0.005, mouth_line)) * (1.0 - smoothstep(nose_z + mouth_back - 0.01, nose_z + mouth_back, rest.z));
	color = mix(color, color * 0.25, mouth);
	float gill = abs(rest.z - gill_z - 0.025 * up * up);
	color *= 1.0 - 0.3 * (1.0 - smoothstep(0.002, 0.005, gill)) * smoothstep(0.85, 0.4, abs(up));
	color *= 1.0 - 0.06 * skin_scales(rest, 0.014, girth);
	color *= 0.94 + 0.12 * skin_noise(rest * 120.0);
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.55;
	RIM = 0.25;
	RIM_TINT = 0.5;
}
