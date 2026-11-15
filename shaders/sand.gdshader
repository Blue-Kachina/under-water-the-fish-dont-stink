shader_type spatial;
// Unnatural's sand (planning_environment.md, Phase 5): ripples the current
// combed into it (bent by noise, fading in patches), lighter and darker
// drifts, and shell grit. World-space, so it never tiles.

#include "res://shaders/scenery.gdshaderinc"
#include "res://shaders/water_caustics.gdshaderinc"
#include "res://shaders/water_materials.gdshaderinc"

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
	// Ocean modes (phase 7): encrusting magenta cover in patches (it fluoresces), then the run's biome tint.
	vec3 flu_add = vec3(0.0);
	if (water_mat_sand.x > 0.0) {
		float cover = smoothstep(0.58, 0.72, sc_fbm(vec3(p * 0.045, 9.0)) + (sc_noise(vec3(p * 3.0, 2.0)) - 0.5) * 0.12) * water_mat_sand.x;
		vec3 crust = mix(vec3(0.5, 0.16, 0.34), vec3(0.72, 0.3, 0.5), sc_noise(vec3(p * 9.0, 5.0)));
		color = mix(color, crust, cover * 0.75);
		flu_add = wm_fluor(crust, world_pos, 0.6) * cover;
		color = wm_biome(color, 1.0);
		// Rocky regions: big slow noise decides where the sand gives way to bare, cracked rock wearing violet/teal/ochre crust.
		float rocky = smoothstep(0.46, 0.53, sc_fbm(vec3(p * 0.021, 17.0)) + (sc_noise(vec3(p * 0.4, 4.0)) - 0.5) * 0.1) * water_mat_sand.y;
		if (rocky > 0.0) {
			vec4 det = wm_detail(vec3(p.x, 0.0, p.y) * 1.6, vec3(0.0, 1.0, 0.0));
			vec3 rock = mix(vec3(0.13, 0.11, 0.16), vec3(0.3, 0.26, 0.3), det.z);
			rock *= 1.0 - det.w * 0.35;  // dark cracks
			float lump = sc_fbm(vec3(p * 0.5, 6.0));
			// Crust: patches of violet / magenta, teal and ochre, thicker on the high parts of the relief. Like the corals it
			// fluoresces (water_mat_sand.z), or the blue water light swamps its colours and it reads as navy.
			float cv = smoothstep(0.4, 0.66, sc_fbm(vec3(p * 0.16, 11.0)) + det.x * 0.35);
			float ct = smoothstep(0.64, 0.84, sc_fbm(vec3(p * 0.11, 23.0)) + det.x * 0.2);
			float co = smoothstep(0.62, 0.8, sc_fbm(vec3(p * 0.13, 31.0)) + (1.0 - det.z) * 0.15);
			vec3 crust_c = mix(vec3(0.42, 0.1, 0.56), vec3(0.78, 0.16, 0.56), lump);
			crust_c = mix(crust_c, vec3(0.1, 0.5, 0.46), ct * 0.8);
			crust_c = mix(crust_c, vec3(0.78, 0.52, 0.14), co);
			float crust_k = clamp(cv * 0.8 + ct * 0.6 + co * 0.6, 0.0, 1.0) * (1.0 - det.w * 0.5);
			rock = mix(rock, crust_c, crust_k);
			// Relief: tilt the normal from the detail's height so the rock reads as lumpy, not flat.
			vec3 q = vec3(p.x, 0.0, p.y) * 1.6;
			float hx = wm_detail(q + vec3(0.08, 0.0, 0.0), vec3(0.0, 1.0, 0.0)).x - det.x;
			float hz = wm_detail(q + vec3(0.0, 0.0, 0.08), vec3(0.0, 1.0, 0.0)).x - det.x;
			n = normalize(mix(n, normalize(vec3(-hx * 2.5, 1.0, -hz * 2.5)), rocky));
			color = mix(color, wm_biome(rock, 0.5) * 0.5, rocky);
			flu_add = mix(flu_add, wm_fluor(crust_c, world_pos, water_mat_sand.z) * crust_k, rocky);
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	EMISSION = flu_add + color * wc_caustics(world_pos, n, length(VERTEX));
}
