shader_type spatial;
render_mode cull_disabled;
// A shark's stiff fin (SharkModel._fin): a solid blade with an airfoil's
// thickness, UV.x across it from its leading edge (0) to its trailing edge (1),
// UV.y from its root (0) out to its tip (1); UV2.x is which face (+ its top or
// right, - its underside), UV2.y the fin's kind (SharkModel.FIN_*). In the
// back's colour (`albedo`, tinted with the body), a little darker out toward
// the tip and along the trailing edge; a pectoral's underside is pale. Species
// marks: a blacktip's ink-dipped tips (with a pale band under the dorsal's), a
// great white's black pectoral tips underneath. One on the body's bending part
// bends with it (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.31, 0.35, 0.39, 1.0);
uniform vec4 belly_color : source_color = vec4(0.93, 0.94, 0.92, 1.0);
uniform vec4 tip_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float tips = 0.0;  // blacktip: ink-dipped tips on every fin
uniform float tip_size = 0.24;  // of the fin's height
uniform float band = 0.0;  // a pale band under the dorsal's black tip
uniform float under_tips = 0.0;  // great white: black pectoral tips underneath
uniform float edge_dark = 0.25;  // the trailing edge's darkening
uniform float metal = 0.0;

varying vec2 fin;
varying vec2 meta;
varying vec3 rest;

void vertex() {
	fin = UV;
	meta = UV2;
	rest = VERTEX;
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float kind = meta.y;
	bool pectoral = abs(kind - 1.0) < 0.5;
	bool dorsal = abs(kind) < 0.5;
	bool lower_lobe = abs(kind - 4.0) < 0.5;
	bool small_fin = abs(kind - 3.0) < 0.5;
	float underside = smoothstep(0.15, -0.15, meta.x);
	float out_part = fin.y;
	vec3 color = albedo.rgb * mix(0.95, 0.78, smoothstep(0.3, 1.0, out_part));
	color *= mix(0.94, 1.05, skin_fbm(vec3(fin * vec2(9.0, 7.0), kind)));
	// Pectorals (and the low small fins) are pale underneath, the back's
	// colour creeping in from the edges.
	if (pectoral || (small_fin && rest.y < 0.0) || lower_lobe) {
		float pale = underside * (1.0 - smoothstep(0.55, 0.95, max(fin.x, out_part)));
		if (lower_lobe) {
			pale = (1.0 - smoothstep(0.0, 0.5, out_part)) * 0.6;
		}
		color = mix(color, belly_color.rgb * 0.95, pale);
	}
	// A darker trailing edge.
	color *= 1.0 - edge_dark * smoothstep(0.75, 1.0, fin.x);
	// Black tips: the outer part past a wavering line, square across the fin.
	float wobble = (skin_noise(vec3(fin.x * 6.0, kind * 3.0, 1.0)) - 0.5) * 0.06;
	float tip_line = 1.0 - tip_size * (kind > 1.5 && kind < 2.5 || lower_lobe ? 1.5 : 1.0) + wobble;
	float aa = fwidth(out_part) * 1.5 + 0.004;
	float tipped = smoothstep(tip_line - aa, tip_line + aa, out_part);
	if (tips > 0.0) {
		if (dorsal && band > 0.0) {
			float pale = smoothstep(tip_line - 0.16 - aa, tip_line - 0.16 + aa, out_part) * (1.0 - tipped);
			color = mix(color, mix(color, belly_color.rgb, 0.6), pale * band);
		}
		// The caudal's trailing edge is inked too.
		float trailing = abs(kind - 2.0) < 0.5 ? smoothstep(0.88, 0.96, fin.x) * smoothstep(0.3, 0.6, out_part) : 0.0;
		color = mix(color, tip_color.rgb, max(tipped, trailing) * tips);
	}
	if (under_tips > 0.0 && pectoral) {
		float under_tip = smoothstep(0.62 - aa, 0.62 + aa, out_part + fin.x * 0.12) * underside;
		color = mix(color, tip_color.rgb, under_tip * under_tips);
	}
	ALBEDO = color;
	METALLIC = metal * (1.0 - underside);
	ROUGHNESS = 0.42;
	SPECULAR = 0.5;
	CLEARCOAT = 0.3;
	CLEARCOAT_ROUGHNESS = 0.35;
	BACKLIGHT = color * 0.15;
}
