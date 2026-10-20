// Shared by a lionfish's fin shaders (LionfishModel): its spines and fin rays
// (lionfish_spine.gdshader) and the webs between them (lionfish_web.gdshader).
// Each vertex carries UV2 = (m out along its ray from the root, which ray: 0,
// 1, 2... and in between on the web), so a ray and the web either side of it
// ripple alike and stay joined, and bands run across a fin as rings round its
// root, as a lionfish's do. A part on the body's bending part bends with it
// (fish_bend.gdshaderinc); fins on the pivots don't (its span stays 0).

#include "res://shaders/fish_bend.gdshaderinc"
#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.52, 0.09, 0.08, 1.0);  // the body's colour (set_body_color() tints it)
uniform vec4 band_fixed : source_color = vec4(0.52, 0.09, 0.08, 1.0);
uniform float band_tint = 1.0;  // the bands' colour: band_fixed (0) to albedo times band_shade (1)
uniform float band_shade = 1.0;
uniform vec4 pale : source_color = vec4(0.97, 0.92, 0.86, 1.0);  // between the bands
uniform float band_len = 0.05;  // m along a ray: one band and one gap; 0 for none
uniform float band_duty = 0.5;  // of band_len, the band
uniform vec2 band_range = vec2(0.0, 100.0);  // m along a ray the bands run
uniform float band_jitter = 0.35;  // how far the bands step from ray to ray, of band_len
uniform vec3 wave_normal = vec3(1.0, 0.0, 0.0);  // the fin's ripple, in its mesh's space
uniform float wave_amp = 0.02;  // m at ref_len out along a ray
uniform float ref_len = 0.4;  // m
uniform float waves = 1.0;  // along ref_len
uniform float tempo = 1.0;  // against the swim
uniform float coord_shift = 0.5;  // rad from one ray to the next, so the wave runs across the fan too
uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out

varying vec3 fin_rest;
varying vec2 fin_at;

// Call in vertex() after setting fin_rest = VERTEX and fin_at = UV2.
void fin_vertex(inout vec3 v, inout vec3 n, vec2 at) {
	float r = at.x / ref_len;
	float a = TAU * waves * r - phase * tempo + at.y * coord_shift;
	// Two waves: a slow sway of the whole fan and a quicker ripple out along it.
	float wave = sin(a) + 0.35 * sin(2.3 * a + 1.7 + at.y * 0.9);
	v += wave_normal * wave_amp * (1.0 + 1.3 * effort) * r * r * wave;
	fish_bend(v, n);
}

vec3 fin_band_color() {
	return mix(band_fixed.rgb, albedo.rgb * band_shade, band_tint);
}

// 1 on a band, 0 between.
float fin_band() {
	if (band_len <= 0.0) {
		return 0.0;
	}
	float p = fin_at.x / band_len + sin(fin_at.y * 1.7) * band_jitter;
	float d = abs(fract(p) - 0.5) - band_duty * 0.5;
	float aa = fwidth(p) * 0.75;
	float b = 1.0 - smoothstep(-aa, aa, d);
	float keep = smoothstep(band_range.x - 0.004, band_range.x + 0.004, fin_at.x) * (1.0 - smoothstep(band_range.y - 0.01, band_range.y + 0.01, fin_at.x));
	return b * keep;
}
