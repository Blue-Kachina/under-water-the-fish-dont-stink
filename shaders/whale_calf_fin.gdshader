shader_type spatial;
// The baby whales' fins, flippers and flukes (WhaleModel): in the body's
// `albedo` (tinted with it), pale underneath where they face down
// (`under_color`), with an `edge_color` rim. Flippers (`flipper`, lofted
// airfoils) carry UV2 = (out along them 0..1, across 0 the leading edge to 1
// the trailing) and can be white on top too (`white_top`, the humpback's long
// flippers); the blade fins (WhaleModel._fin) carry UV2 = (along the root 0..1,
// root 0 to edge 1). A fin on the body's bending part bends with it.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.14, 0.15, 0.17, 1.0);
uniform vec3 flank_gain = vec3(1.5);
uniform vec4 under_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float edge_width = 0.25;  // of the way out (blades) or across (flippers), 0 none
uniform float mottle = 0.0;
uniform vec4 mottle_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float roughness = 0.4;
uniform bool flipper = false;
uniform float white_top = 0.0;

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	vec3 flank = albedo.rgb * flank_gain;
	vec3 tone = mix(albedo.rgb, flank / max(1.0, max(flank.r, max(flank.g, flank.b))), 0.35);
	tone *= mix(0.92, 1.06, skin_fbm(rest * 10.0));
	if (mottle > 0.0) {
		float blotch = smoothstep(0.55, 0.72, skin_fbm(rest * 16.0 + 2.0));
		tone = mix(tone, mottle_color.rgb, blotch * 0.5 * mottle);
	}
	float under = smoothstep(-0.1, -0.5, rest_normal.y);
	float edge;
	if (flipper) {
		float out_part = UV2.x;
		float lead = 1.0 - smoothstep(0.0, edge_width * 0.6, UV2.y);
		float trail = smoothstep(1.0 - edge_width * 0.5, 1.0, UV2.y);
		edge = max(max(lead, trail), smoothstep(0.9, 0.98, out_part)) * step(0.001, edge_width);
		// A humpback's flippers are white over much of their top as well,
		// blotched toward the root.
		float white = white_top * smoothstep(0.25, 0.55, out_part + (skin_fbm(rest * 20.0) - 0.5) * 0.4);
		under = max(under, white);
	} else {
		edge = smoothstep(1.0 - edge_width, 1.0, UV2.y) * step(0.001, edge_width);
	}
	vec3 color = mix(tone, under_color.rgb * mix(0.94, 1.02, skin_fbm(rest * 22.0)), under);
	color = mix(color, edge_color.rgb, edge * 0.9);
	ALBEDO = color;
	ROUGHNESS = roughness + 0.05;
	SPECULAR = 0.5;
	CLEARCOAT = 0.35;
	CLEARCOAT_ROUGHNESS = 0.25;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
