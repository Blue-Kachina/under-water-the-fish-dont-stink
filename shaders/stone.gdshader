shader_type spatial;
// Weathered stone for the seabed's ruins and rocks (planning_environment.md):
// marble (veins, pitting, pale fresh breaks) or reef rock (veins 0), with
// algae on top and a coralline crust low down. Painted in world space from
// MeshKit's vertex colour: r cavity, g wear, b per-piece random, a height up
// the piece.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.86, 0.84, 0.79);
uniform vec3 base_color_b : source_color = vec3(0.74, 0.72, 0.68);
uniform float vein_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vein_scale = 0.9;
uniform float pitting : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.55;
uniform float algae : hint_range(0.0, 1.0) = 0.35;
uniform float coralline : hint_range(0.0, 1.0) = 0.22;
uniform float bump_strength = 0.3;
uniform float bounce = 0.35;
uniform float bump_scale = 2.4;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float cavity = COLOR.r;
	float wear = COLOR.g;
	float variant = COLOR.b;
	vec3 p = world_pos + variant * 37.0;
	vec3 n = sc_bump(p, normalize(world_normal), bump_scale, bump_strength * (1.0 + wear));
	// The stone: two tones drifting, veins, pits.
	float drift = sc_fbm(p * 0.35);
	vec3 color = mix(base_color, base_color_b, clamp(drift * 1.3 - 0.2 + (variant - 0.5) * 0.4, 0.0, 1.0));
	float wave = sin(dot(p, vec3(0.7, 0.45, 0.55)) * vein_scale * 3.0 + sc_fbm(p * 0.8) * 9.0);
	float vein = (1.0 - smoothstep(0.0, 0.09, abs(wave))) * vein_strength;
	color = mix(color, vec3(0.42, 0.42, 0.44), vein);
	float pits = smoothstep(0.58, 0.72, sc_fbm(p * 5.0)) * pitting;
	color *= 1.0 - pits * 0.35;
	// Fresh breaks are paler and creamier; hollows hold grime.
	color = mix(color, vec3(0.93, 0.9, 0.82), wear * 0.5);
	color *= mix(1.0, 0.45, clamp(cavity, 0.0, 1.0));
	color = mix(color, vec3(0.2, 0.2, 0.12), clamp(cavity, 0.0, 1.0) * 0.3);
	// Growth.
	vec4 growth = sc_growth(p, n, COLOR.a, algae * (1.0 - wear * 0.8), coralline * (1.0 - wear * 0.8));
	color = mix(color, growth.rgb, growth.a);
	ALBEDO = color;
	ROUGHNESS = clamp(roughness_base + pits * 0.3 + growth.a * 0.3 + wear * 0.15, 0.0, 1.0);
	SPECULAR = 0.4;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	EMISSION = sc_bounce(color, n, bounce);
	AO = 1.0 - cavity * 0.6;
	AO_LIGHT_AFFECT = 0.3;
}
