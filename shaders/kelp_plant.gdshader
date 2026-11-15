shader_type spatial;
render_mode cull_disabled;
// Giant kelp and sea grass on Unnatural's seabed (planning_environment.md,
// Phase 5): swaying in the current, more the higher up (MeshKit's vertex
// colour a), each plant on its own phase; translucent olive-gold fronds lit
// from behind.

#include "res://shaders/scenery.gdshaderinc"
#include "res://shaders/water_caustics.gdshaderinc"
#include "res://shaders/water_materials.gdshaderinc"

uniform vec3 base : source_color = vec3(0.2, 0.22, 0.06);
uniform vec3 tip : source_color = vec3(0.62, 0.5, 0.14);
uniform float sway = 0.9;
uniform float speed = 0.8;

varying float up;
varying vec3 world_pos;
varying vec4 custom;
varying vec3 lpos;

void vertex() {
	custom = INSTANCE_CUSTOM;
	lpos = VERTEX;
	up = COLOR.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 0.11 + root.z * 0.13 + INSTANCE_CUSTOM.g * 6.28;
	float bend = up * up * sway;
	float scale = length(MODEL_MATRIX[1].xyz);
	VERTEX.x += (sin(TIME * speed + phase + up * 1.5) * bend) / max(scale, 0.01);
	VERTEX.z += (cos(TIME * speed * 0.8 + phase * 1.3 + up) * bend * 0.6) / max(scale, 0.01);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float streak = sc_noise(world_pos * vec3(6.0, 1.5, 6.0));
	vec3 color = mix(base, tip, smoothstep(0.0, 1.0, up * 0.8 + streak * 0.3));
	color *= 0.85 + 0.3 * custom.r;
	// Ocean modes (phase 7): vein stripes, thin-film iridescence, warm translucency lit from behind, a sparkle band on some blades.
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 extra = vec3(0.0);
	if (water_mat_kelp.x + water_mat_kelp.y + water_mat_kelp.z + water_mat_kelp.w > 0.0) {
		float vein = 1.0 - smoothstep(0.0, 0.12, abs(sin((lpos.x + lpos.z) * 38.0 + streak * 2.0)));
		color *= 1.0 - vein * water_mat_kelp.z * 0.5;
		float ndv = abs(dot(wn, vw));
		vec3 film = 0.5 + 0.5 * cos(6.2832 * (ndv * 1.6 + up * 0.7 + custom.g + vec3(0.0, 0.33, 0.67)));
		color = mix(color, color * (0.6 + film * 0.9), water_mat_kelp.y * (1.0 - ndv * 0.5));
		float back = pow(clamp(dot(-vw, water_sun_dir), 0.0, 1.0), 3.0);
		extra += color * water_mat_kelp2.rgb * back * water_mat_kelp.x * wm_light(world_pos);
		float blade = floor(lpos.x * 9.0 + lpos.z * 9.0 + custom.g * 40.0);
		float chosen = step(sc_hash(vec3(blade, 3.0, 1.0)), water_mat_kelp2.w);
		float travel = fract(TIME * 0.12 + sc_hash(vec3(blade, 7.0, 2.0)));
		extra += vec3(1.0, 0.95, 0.6) * chosen * smoothstep(0.09, 0.0, abs(up - travel)) * water_mat_kelp.w * wm_light(world_pos);
	}
	ALBEDO = color;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = color * 0.6;
	EMISSION = extra + color * wc_caustics(world_pos, normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), length(VERTEX));
}
