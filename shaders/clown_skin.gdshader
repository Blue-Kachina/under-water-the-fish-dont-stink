shader_type spatial;
// A clownfish's skin (FishModel._build_clownfish): `albedo` (the colour
// set_body_color() tints), paler toward the belly, with three white bands edged
// in black: one curving round behind the head, one bulging forward in the
// middle, and a thin one round the tail stalk. Faint scales over it all.
// Painted from the resting shape, so it never slides.

#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 0.45, 0.06, 1.0);
uniform vec4 band_color : source_color = vec4(0.98, 0.98, 0.96, 1.0);
uniform vec4 rim_color : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform vec3 band_z = vec3(-0.2, 0.05, 0.4);  // m, each band's middle
uniform vec3 band_width = vec3(0.05, 0.055, 0.025);  // m, half of each band
uniform vec3 band_bulge = vec3(-0.03, -0.05, 0.0);  // m each band's middle sits behind (+) its top and bottom
uniform float rim = 0.009;  // m, the black edging
uniform float height = 0.2;  // m, the body's half height, to shape the bands
uniform float girth = 0.15;  // m, about the body's radius

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
}

// How far `rest` is outside band i's white (m; less than 0 inside it).
float band(int i) {
	float y = clamp(rest.y / height, -1.0, 1.0);
	float wobble = (skin_noise(rest * 22.0 + float(i) * 7.0) - 0.5) * 0.012;
	float middle = band_z[i] + band_bulge[i] * (1.0 - y * y);
	return abs(rest.z - middle + wobble) - band_width[i];
}

void fragment() {
	vec3 color = albedo.rgb * mix(1.15, 0.92, smoothstep(-0.6, 0.6, rest_normal.y));
	color = mix(color, color * 0.85, smoothstep(0.4, 0.9, rest_normal.y));
	float outside = min(min(band(0), band(1)), band(2));
	float aa = fwidth(outside);
	float white = 1.0 - smoothstep(-aa, aa, outside);
	float black = 1.0 - smoothstep(rim - aa, rim + aa, outside);
	color = mix(color, rim_color.rgb, black);
	color = mix(color, band_color.rgb, white);
	color *= 1.0 - 0.05 * skin_scales(rest, 0.022, girth);
	ALBEDO = color;
	ROUGHNESS = 0.32;
	SPECULAR = 0.6;
}
