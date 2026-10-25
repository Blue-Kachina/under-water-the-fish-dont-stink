shader_type spatial;
render_mode cull_disabled;
// The living reef (planning_environment.md, Phase 5): corals, sponges,
// anemones and small life, coloured from a palette of six by each copy's
// INSTANCE_CUSTOM.r, so the reef is many colours from a few meshes.
// `pattern`: 0 polyps (staghorn, table), 1 brain meanders, 2 sponge pores,
// 3 anemone (swaying, glowing tips), 4 small life (speckled).
// A little self-light keeps its colours from drowning in the red murk.

#include "res://shaders/scenery.gdshaderinc"

uniform int pattern = 0;
uniform vec3 color_0 : source_color = vec3(0.62, 0.22, 0.75);
uniform vec3 color_1 : source_color = vec3(0.95, 0.5, 0.18);
uniform vec3 color_2 : source_color = vec3(0.98, 0.82, 0.25);
uniform vec3 color_3 : source_color = vec3(0.95, 0.42, 0.6);
uniform vec3 color_4 : source_color = vec3(0.18, 0.72, 0.7);
uniform vec3 color_5 : source_color = vec3(0.35, 0.55, 0.95);
uniform float glow = 0.12;
uniform float tip_glow = 1.6;

varying vec3 world_pos;
varying vec3 world_normal;
varying float up;
varying vec3 tint;
varying vec4 custom;

vec3 pick(float r) {
	int i = int(clamp(floor(r * 6.0), 0.0, 5.0));
	if (i == 0) return color_0;
	if (i == 1) return color_1;
	if (i == 2) return color_2;
	if (i == 3) return color_3;
	if (i == 4) return color_4;
	return color_5;
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	up = COLOR.a;
	tint = pick(INSTANCE_CUSTOM.r);
	if (pattern == 3) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float phase = root.x * 0.7 + root.z * 0.9 + INSTANCE_CUSTOM.g * 6.28;
		float bend = smoothstep(0.35, 1.0, up) * 0.06;
		VERTEX.x += sin(TIME * 1.3 + phase + VERTEX.z * 8.0) * bend;
		VERTEX.z += cos(TIME * 1.1 + phase + VERTEX.x * 8.0) * bend;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos + custom.g * 13.0;
	vec3 n = normalize(world_normal);
	vec3 color = tint;
	float rough = 0.7;
	float lit = glow;
	if (pattern == 0) {
		// Polyps: little pale cups all over.
		float cells = sc_noise(p * 28.0);
		float cup = smoothstep(0.62, 0.75, cells);
		color = mix(color, color * 1.4 + 0.15, cup * 0.6);
		color = mix(color * 0.7, color, smoothstep(0.0, 0.5, up));
		n = sc_bump(p, n, 22.0, 0.25);
	} else if (pattern == 1) {
		// Meandering ridges and valleys.
		float wave = sin((p.x + sc_fbm(p * 2.5) * 1.6) * 26.0) * sin((p.z + sc_fbm(p * 2.5 + 7.0) * 1.6) * 26.0);
		float ridge = smoothstep(-0.2, 0.4, wave);
		color = mix(color * 0.45, color * 1.15, ridge);
		n = sc_bump(p, n, 9.0, 0.5);
		rough = 0.8;
	} else if (pattern == 2) {
		// Sponge: pores, darker inside (cavity).
		float pores = smoothstep(0.7, 0.8, sc_noise(p * 35.0));
		color *= 1.0 - pores * 0.5;
		color *= mix(1.0, 0.35, COLOR.r);
		n = sc_bump(p, n, 14.0, 0.4);
		rough = 0.9;
	} else if (pattern == 3) {
		// Anemone: the column darker, the tentacles bright, their tips glowing.
		color = mix(color * 0.5, color * 1.2 + 0.1, smoothstep(0.3, 0.6, up));
		lit = glow + smoothstep(0.85, 1.0, up) * tip_glow * step(0.5, custom.b + 0.4);
		rough = 0.45;
	} else {
		float speck = smoothstep(0.65, 0.8, sc_noise(p * 40.0));
		color = mix(color, color * 0.4 + 0.5, speck * 0.5);
		n = sc_bump(p, n, 20.0, 0.3);
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	EMISSION = color * lit + sc_bounce(color, n, 0.3);
	BACKLIGHT = color * 0.25;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
