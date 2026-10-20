shader_type spatial;
// A clownfish's skin (ClownfishModel): `albedo` (the colour set_body_color()
// tints) shaded dark on the back and paler toward the belly, with up to three
// bands (`band_on`) edged in `rim_color`: one curving round behind the head, one
// bulging forward in the middle, and a thin one round the tail stalk. Per skin:
// an orange face (black percula), a dark flank blotch (tomato), gold bands with a
// sheen (maroon). A painted mouth and gill cover, fine scale rows that catch the
// light, and a wet sheen. Painted from the resting shape, so nothing slides as
// the body bends into its tail (fish_bend.gdshaderinc). Sizes in metres.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.94, 0.48, 0.12, 1.0);
uniform float back_shade = 0.62;  // the back is albedo times this
uniform vec4 belly_color : source_color = vec4(0.97, 0.69, 0.4, 1.0);
uniform float belly_mix = 0.5;  // how far the belly goes to belly_color
uniform vec4 band_color : source_color = vec4(0.98, 0.98, 0.97, 1.0);
uniform vec4 rim_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform float rim_alpha = 1.0;
uniform vec3 band_on = vec3(1.0);  // which bands show
uniform vec3 band_z = vec3(-0.4, -0.05, 0.3);  // each band's middle at its top and bottom
uniform vec3 band_width = vec3(0.035, 0.035, 0.017);  // half of each band
uniform vec3 band_bulge = vec3(-0.035, -0.05, 0.0);  // how far each band's middle sits behind (+) its top and bottom
uniform float rim = 0.01;  // the edging round the bands
uniform float band_sheen = 0.0;  // metallic bands (gold)
uniform float height = 0.18;  // the body's half height, to shape the bands
uniform float girth = 0.16;  // about the body's radius, for the scale rows
uniform vec4 face_color : source_color = vec4(0.9, 0.44, 0.1, 1.0);
uniform float face_on = 0.0;
uniform vec2 face_span = vec2(-0.45, -0.4);  // z the face is full to, and gone by
uniform vec4 blotch_color : source_color = vec4(0.16, 0.03, 0.02, 1.0);
uniform float blotch_on = 0.0;
uniform vec2 blotch_at = vec2(0.0, 0.0);  // z, y of its middle
uniform vec2 blotch_size = vec2(0.3, 0.12);  // its half length, half height
uniform vec4 lip_color : source_color = vec4(0.2, 0.06, 0.03, 1.0);
uniform float nose_z = -0.58;
uniform float mouth_y = -0.02;  // the mouth line's height at the nose
uniform float mouth_length = 0.06;
uniform float gill_z = -0.42;  // the gill cover's edge, its top and bottom
uniform float gill_bulge = 0.02;  // its middle sits this far behind
uniform float scale_size = 0.016;
uniform float scale_shade = 0.07;
uniform float scale_bump = 0.00025;  // m, how much the scale edges stand up

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

// How far `rest` is outside band i's colour (m; less than 0 inside it).
float band(int i, float up) {
	if (band_on[i] < 0.5) {
		return 1.0;
	}
	float wobble = (skin_noise(rest * 26.0 + float(i) * 7.0) - 0.5) * 0.01;
	float y = clamp(up, -1.0, 1.0);
	float bow = 1.0 - y * y;
	float middle = band_z[i] + band_bulge[i] * bow * (i == 1 ? bow : 1.0);
	return abs(rest.z - middle + wobble) - band_width[i];
}

void fragment() {
	float up = rest.y / height;
	vec3 mottle = vec3(0.93 + 0.14 * skin_fbm(rest * 34.0));
	// The ground colour, the face over it, then shaded dark back to pale belly.
	vec3 base = albedo.rgb;
	float face = face_on * (1.0 - smoothstep(face_span.x, face_span.y, rest.z + (skin_noise(rest * 18.0) - 0.5) * 0.02));
	base = mix(base, face_color.rgb, face);
	vec3 color = mix(base, mix(base, belly_color.rgb, belly_mix), 1.0 - smoothstep(-0.95, 0.0, up));
	color = mix(color, base * back_shade, smoothstep(0.05, 0.95, up));
	// The flank blotch (tomato adults).
	vec2 b = (vec2(rest.z, rest.y) - blotch_at) / blotch_size;
	float blotch = blotch_on * (1.0 - smoothstep(0.35, 1.0, length(b))) * (0.75 + 0.35 * skin_fbm(rest * 14.0));
	color = mix(color, blotch_color.rgb, clamp(blotch, 0.0, 0.9));
	color *= mottle;
	// The bands, with their edging.
	float outside = min(min(band(0, up), band(1, up)), band(2, up));
	float aa = fwidth(outside);
	float white = 1.0 - smoothstep(-aa, aa, outside);
	float edge = (1.0 - smoothstep(rim - aa, rim + aa, outside)) * step(0.0001, rim);
	color = mix(color, rim_color.rgb, edge * rim_alpha);
	vec3 band_shaded = band_color.rgb * mix(1.0, 0.82, smoothstep(0.2, 1.0, up)) * (0.96 + 0.06 * mottle.r);
	color = mix(color, band_shaded, white);
	// The gill cover's edge: a fine dark line curving behind the eye.
	float gill = gill_z + gill_bulge * (1.0 - up * up);
	float gill_w = 0.0035;
	float gill_line = (1.0 - smoothstep(gill_w, gill_w + fwidth(rest.z) * 1.5, abs(rest.z - gill)))
			* (1.0 - smoothstep(0.55, 0.8, abs(up)));
	color *= 1.0 - 0.38 * gill_line;
	color *= 1.0 - 0.12 * smoothstep(0.0, 0.025, rest.z - gill) * (1.0 - smoothstep(0.025, 0.06, rest.z - gill)) * (1.0 - smoothstep(0.5, 0.8, abs(up)));
	// The mouth: a dark lip line round the front of the snout, curving up a little.
	float along_mouth = (rest.z - nose_z) / mouth_length;
	float lip_y = mouth_y - 0.06 * mouth_length * along_mouth * along_mouth;
	float lip_d = abs(rest.y - lip_y);
	float lip_w = 0.0026 * (1.0 - 0.5 * along_mouth);
	float lip = (1.0 - smoothstep(lip_w, lip_w + fwidth(rest.y) * 1.5, lip_d)) * (1.0 - smoothstep(0.85, 1.0, along_mouth));
	color = mix(color, color * 1.15 + 0.04, (1.0 - smoothstep(0.004, 0.012, lip_d)) * (1.0 - smoothstep(0.6, 1.0, along_mouth)) * 0.6);
	color = mix(color, lip_color.rgb, lip);
	// Fine scale rows, fading out once they're too small to see.
	float rows = skin_scales(rest, scale_size, girth);
	float fade = 1.0 - smoothstep(0.25, 0.6, fwidth(rest.z) / scale_size + fwidth(rest.y) / scale_size);
	float on_scales = rows * fade * (1.0 - smoothstep(-0.02, 0.03, nose_z + 0.07 - rest.z));
	color *= 1.0 - scale_shade * on_scales;
	// Raise the scale edges a touch (a bump from the screen-space slope).
	float bump = on_scales * scale_bump;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(bump) * r1 + dFdy(bump) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ALBEDO = color;
	METALLIC = band_sheen * white;
	ROUGHNESS = mix(0.3, 0.42, on_scales) - 0.12 * band_sheen * white;
	SPECULAR = 0.55;
	CLEARCOAT = 0.55;
	CLEARCOAT_ROUGHNESS = 0.18;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
