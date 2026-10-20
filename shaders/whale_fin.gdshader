shader_type spatial;
// The whale shark family's fins (WhaleSharkModel._fin): thick, stiff and
// opaque, in the body's `albedo` (tinted with it), darker toward the edge,
// spotted like the body (or mottled), and pale underneath where they face down
// (pectoral and pelvic fins). UV is the fin's own plane in metres (along its
// root, out from it) and UV2 (along its root 0..1, root 0 to edge 1). A fin on
// the body's bending part bends with it (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.165, 0.275, 0.392, 1.0);
uniform vec3 flank_gain = vec3(2.0);
uniform vec4 belly_color : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform vec4 spot_color : source_color = vec4(0.91, 0.94, 0.96, 1.0);
uniform float spot_cell = 0.04;  // m
uniform float spot_size = 0.22;
uniform float spot_strength = 1.0;
uniform float mottle = 0.0;
uniform float edge_dark = 0.65;

varying vec3 rest;
varying vec3 rest_normal;

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	fish_bend(VERTEX, NORMAL);
}

vec2 fin_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float fin_spots(vec2 p, float cell, float size) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	float best = 1e3;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = id + vec2(float(i), float(j));
			vec2 h = fin_hash2(c + 3.0);
			vec2 centre = c + 0.5 + (h - 0.5) * 0.8;
			float r = size * mix(0.7, 1.2, h.y) * cell;
			best = min(best, length((q - centre) * cell) - r);
		}
	}
	float aa = clamp(fwidth(best), 1e-4, 0.004);
	return 1.0 - smoothstep(-aa, aa, best);
}

void fragment() {
	float out_part = UV2.y;
	vec3 flank = albedo.rgb * flank_gain;
	vec3 tone = mix(albedo.rgb, flank / max(1.0, max(flank.r, max(flank.g, flank.b))), 0.3);
	tone *= mix(0.9, 1.08, skin_fbm(rest * 11.0));
	if (mottle > 0.0) {
		tone *= mix(1.0, mix(0.7, 1.2, smoothstep(0.3, 0.72, skin_fbm(rest * 4.5 + 3.0))), mottle);
	}
	float edge = smoothstep(0.55, 1.0, out_part);
	vec3 color = tone * mix(1.0, edge_dark, edge);
	float under = smoothstep(-0.25, -0.6, rest_normal.y) * (1.0 - smoothstep(0.72, 0.95, out_part));
	float spot = fin_spots(UV, spot_cell, spot_size) * spot_strength * (1.0 - under) * (1.0 - smoothstep(0.8, 0.97, out_part));
	color = mix(color, spot_color.rgb, spot);
	color = mix(color, belly_color.rgb * 0.95, under);
	ALBEDO = color;
	ROUGHNESS = 0.42;
	SPECULAR = 0.5;
	CLEARCOAT = 0.25;
	CLEARCOAT_ROUGHNESS = 0.3;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
