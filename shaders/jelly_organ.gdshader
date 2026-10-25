shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// A jellyfish's gonads (JellyModel), set in the bell's jelly: soft, milky,
// a little mottled, brighter at their edges, pulsing with the bell
// (jelly_pulse.gdshaderinc). Drawn between the bell's inner and outer surfaces.

#include "res://shaders/jelly_pulse.gdshaderinc"
#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 color : source_color = vec4(0.8, 0.6, 0.9, 1.0);
uniform float opacity = 0.8;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	NORMAL = jelly_pulse_normal(VERTEX, NORMAL);
	VERTEX = jelly_pulse(VERTEX);
}

void fragment() {
	float mottle = skin_fbm(rest * 70.0);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color.rgb * (0.85 + 0.3 * mottle);
	ALPHA = opacity * mix(1.0, 0.55, facing) * (0.8 + 0.4 * mottle);
	ROUGHNESS = 0.3;
	SPECULAR = 0.5;
	BACKLIGHT = color.rgb * 0.6;
	EMISSION = color.rgb * 0.08;
}
