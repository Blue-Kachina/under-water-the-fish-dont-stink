shader_type spatial;
// A shark's skin (FishModel._build_shark): `albedo` (the colour set_body_color()
// tints) over its back with faint mottling, a white belly below a wavy line
// down its sides, five gill slits either side behind the head, and a crescent
// grin under its snout with a row of little teeth. Painted from the resting
// shape, so it never slides.

#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.45, 0.56, 0.7, 1.0);
uniform vec4 belly_color : source_color = vec4(0.95, 0.95, 0.93, 1.0);
uniform vec4 slit_color : source_color = vec4(0.12, 0.14, 0.2, 1.0);
uniform vec4 mouth_color : source_color = vec4(0.22, 0.06, 0.09, 1.0);
uniform float belly_line = -0.25;  // the belly's top, as the surface's normal.y
uniform float gill_z = -0.2;  // m, the first slit
uniform float gill_step = 0.035;  // m between slits
uniform float gill_height = 0.08;  // m, half the first slit's height
uniform float mouth_z = -0.55;  // m, the front of the grin
uniform float mouth_width = 0.12;  // m, half its width
uniform float mouth_back = 0.06;  // m its corners sit behind its front
uniform float tooth_width = 0.018;  // m

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
}

void fragment() {
	// Back over belly, the line between them wavering a little, the back
	// mottled and darkest along the spine.
	float wobble = (skin_fbm(rest * 9.0 + 4.0) - 0.5) * 0.3;
	float line = rest_normal.y - belly_line + wobble;
	float back = smoothstep(-0.04, 0.04, line);
	vec3 top = albedo.rgb * mix(0.88, 1.06, skin_fbm(rest * 14.0)) * mix(1.0, 0.82, smoothstep(0.6, 1.0, rest_normal.y));
	vec3 color = mix(belly_color.rgb, top, back);
	// Gill slits: five curved lines down the sides, each a little shorter than
	// the one before.
	float side = smoothstep(0.35, 0.6, abs(rest_normal.x));
	float zz = rest.z - gill_z - 0.4 * gill_height * pow(rest.y / gill_height, 2.0);
	float k = clamp(round(zz / gill_step), 0.0, 4.0);
	float d = zz - k * gill_step;
	float tall = gill_height * (1.0 - 0.1 * k);
	float span = 1.0 - smoothstep(tall * 0.8, tall, abs(rest.y + 0.1 * gill_height));
	float width = 0.0035 + fwidth(zz);  // not d, which jumps between slits
	float slit = (1.0 - smoothstep(0.0035, width, abs(d))) * side * span;
	color = mix(color, slit_color.rgb, slit);
	// The grin: a crescent under the snout, its corners curling back, with
	// teeth hanging from its front edge.
	float x = rest.x / mouth_width;
	float curve = mouth_z + mouth_back * x * x;
	float thick = 0.012 * (1.0 - 0.6 * x * x);
	float v = (rest.z - curve) / max(thick, 0.001);
	float under = smoothstep(0.0, -0.25, rest_normal.y) * (1.0 - smoothstep(0.92, 1.0, abs(x)));
	float aa = fwidth(v);
	float mouth = (1.0 - smoothstep(1.0 - aa, 1.0 + aa, abs(v))) * under;
	float tooth_x = abs(fract(rest.x / tooth_width) - 0.5) * 2.0;  // 0 at a tooth's point
	float reach = -1.0 + 1.1 * (1.0 - tooth_x);  // how far back a tooth hangs into the mouth
	float tooth = (1.0 - smoothstep(reach - aa, reach + aa, v)) * mouth;
	color = mix(color, mouth_color.rgb, mouth);
	color = mix(color, belly_color.rgb, tooth);
	ALBEDO = color;
	ROUGHNESS = mix(0.42, 0.55, back);
	SPECULAR = 0.55;
}
