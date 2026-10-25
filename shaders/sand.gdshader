shader_type spatial;
// Unnatural's sand (planning_environment.md, Phase 5): ripples the current
// combed into it (bent by noise, fading in patches), lighter and darker
// drifts, and shell grit. World-space, so it never tiles.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 light_sand : source_color = vec3(0.62, 0.54, 0.42);
uniform vec3 dark_sand : source_color = vec3(0.36, 0.31, 0.25);
uniform float ripple_size = 0.55;
uniform float ripple_strength = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float drift = sc_fbm(vec3(p * 0.05, 1.0));
	vec3 color = mix(dark_sand, light_sand, smoothstep(0.25, 0.75, drift));
	// Ripples: crests across the current, bent by noise, fading in patches;
	// the slope is worked out, not sampled (the sand covers half the view).
	vec2 across = vec2(0.8, 0.6) / ripple_size;
	float warp = sc_fbm(vec3(p * 0.08, 0.0)) * 9.0;
	float patchy = smoothstep(0.3, 0.6, sc_fbm(vec3(p * 0.03, 3.0)));
	float along = dot(p, across) + warp;
	float wave = 0.5 + 0.5 * sin(along * 6.2831);
	float h = pow(wave, 1.6) * patchy;
	float slope = 1.6 * pow(max(wave, 0.001), 0.6) * 0.5 * cos(along * 6.2831) * 6.2831 * patchy;
	vec2 grad = across * slope;
	vec3 n = normalize(vec3(-grad.x * ripple_strength * 0.1, 1.0, -grad.y * ripple_strength * 0.1));
	color *= 0.88 + h * 0.18;
	float grit = smoothstep(0.88, 0.94, sc_noise(vec3(p * 30.0, 0.0)));
	color = mix(color, vec3(0.8, 0.76, 0.68), grit * 0.3);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
