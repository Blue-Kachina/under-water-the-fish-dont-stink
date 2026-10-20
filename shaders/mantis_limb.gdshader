shader_type spatial;
render_mode cull_back;
// A mantis shrimp's limbs and plates (MantisModel): claws, legs, antennae,
// antennal scales, uropods and swimmerets, painted by their vertex colours
// (glossy shell, a faint shimmer). With `flap` the swimmerets beat in a wave
// front to back (UV.x which pair, UV.y root to tip), quicker as it swims.
// Ones on the abdomen bend with it (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform float iridescence = 0.2;
uniform vec4 sheen_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float flap = 0.0;  // m at the tips
uniform float tempo = 1.0;
uniform float phase = 0.0;
uniform float effort = 0.0;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	if (flap > 0.0) {
		float beat = sin(phase * tempo * 2.2 - UV.x * TAU * 0.9);
		float reach = flap * (0.6 + 0.8 * effort) * UV.y * UV.y;
		VERTEX.z += reach * beat;
		VERTEX.y += reach * 0.35 * cos(phase * tempo * 2.2 - UV.x * TAU * 0.9);
	}
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	vec3 col = COLOR.rgb * (0.88 + 0.24 * skin_fbm(rest * 70.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	col += sheen_color.rgb * iridescence * fres * 0.25;
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 0.42;
	SPECULAR = 0.4;
	CLEARCOAT = 0.3;
	CLEARCOAT_ROUGHNESS = 0.2;
}
