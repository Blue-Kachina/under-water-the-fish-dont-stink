shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// The Fallen Angel's insides (FallenAngelBoss), seen through its glass body:
// the folded crown and brain in its hood (bright orange) and the long gut below
// the wings (a browner orange, built with COLOR.a 1), glowing (`glow`, brighter
// as the crown opens and as it lashes), the gut darkening with what it has
// eaten (`fed`). Soft at the edges so they read as lit from within, not as
// solid balls. Bent along its spine with the body.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform float height = 40.0;
uniform vec4 head_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec4 gut_color : source_color = vec4(0.72, 0.38, 0.15, 1.0);
uniform vec4 eaten_color : source_color = vec4(0.25, 0.26, 0.18, 1.0);
uniform float glow = 0.8;
uniform float fed = 0.0;
uniform float dissolve = 0.0;
uniform float flash = 0.0;

varying vec3 rest;
varying float gut;

void vertex() {
	rest = VERTEX;
	gut = COLOR.a;
	spine_bend(VERTEX, NORMAL, 0.0);
}

void fragment() {
	vec3 p = rest / max(height, 1.0) * 40.0;
	if (dissolve > 0.0 && skin_noise(p * 0.7 + 3.0) < dissolve) {
		discard;
	}
	float mottle = skin_fbm(p * 0.9);
	vec3 color = mix(head_color.rgb, gut_color.rgb, gut);
	color *= mix(0.65, 1.2, mottle);
	// Fine dark speckles (the folded cones' tips, the gut's lining).
	color *= 1.0 - smoothstep(0.72, 0.8, skin_noise(p * 4.0)) * 0.4;
	// What it ate shows in its gut as dark lumps.
	float lumps = smoothstep(0.55, 0.7, skin_fbm(p * 0.45 + 5.0)) * fed * gut;
	color = mix(color, eaten_color.rgb, lumps);
	float face = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color;
	// Soft edges: it fades out toward its outline, a glow in the jelly, not a solid lump.
	ALPHA = smoothstep(0.05, 0.75, face) * mix(0.95, 0.6, gut) * mix(1.0, 0.8 + 0.2 * mottle, gut);
	ROUGHNESS = 0.35;
	SPECULAR = 0.4;
	EMISSION = color * glow * 1.6 * mix(0.35, 1.0, mottle) * mix(1.0, 0.6, gut) * (1.0 - lumps * 0.7) + vec3(1.0, 0.4, 0.3) * flash * 0.5;
}
