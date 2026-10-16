shader_type spatial;
// A swordfish's skin (FishModel._build_swordfish), body and sword in one: a
// deep `albedo` back (the colour set_body_color() tints) with a purple sheen,
// shading into a pale silver belly, a faint lateral line, and the sword in
// front of `bill_end` a dark, rough grey. Painted from the resting shape, so it
// never slides.

#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.12, 0.2, 0.5, 1.0);
uniform vec4 belly_color : source_color = vec4(0.78, 0.8, 0.84, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.45, 0.25, 0.6, 1.0);
uniform vec4 bill_color : source_color = vec4(0.22, 0.23, 0.27, 1.0);
uniform float bill_end = -0.4;  // z (m): the sword is in front of it
uniform float lateral_y = 0.02;  // m, the lateral line's height on the sides
uniform float girth = 0.15;  // m, about the body's radius

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
}

void fragment() {
	float wobble = (skin_fbm(rest * 7.0 + 2.0) - 0.5) * 0.2;
	float back = smoothstep(-0.3, 0.15, rest_normal.y + wobble);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 top = mix(albedo.rgb, sheen_color.rgb, rim * 0.45) * mix(1.0, 0.75, smoothstep(0.5, 1.0, rest_normal.y));
	vec3 color = mix(belly_color.rgb, top, back);
	// The lateral line: a thin pale stripe along the sides, following the back
	// down toward the tail.
	float side = smoothstep(0.4, 0.7, abs(rest_normal.x));
	float d = rest.y - lateral_y;
	float lat = (1.0 - smoothstep(0.002, 0.002 + fwidth(d) * 1.5, abs(d))) * side;
	color = mix(color, color * 1.35 + 0.05, lat * 0.5);
	color *= 1.0 - 0.06 * skin_scales(rest, 0.03, girth) * back;
	// The sword: dark and rough, blending into the head.
	float bill = smoothstep(bill_end + 0.03, bill_end - 0.02, rest.z);
	color = mix(color, bill_color.rgb * mix(0.85, 1.1, skin_noise(rest * 60.0)), bill);
	ALBEDO = color;
	METALLIC = mix(0.45, 0.2, back) * (1.0 - bill);
	ROUGHNESS = mix(0.32, 0.65, bill);
	SPECULAR = 0.6;
}
