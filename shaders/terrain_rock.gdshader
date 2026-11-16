shader_type spatial;
// The procedural terrain's rock (planning_procedural_world.md, phase 3). World-space triplanar, so it never tiles and
// needs no UVs. Built from the seabed's own pieces so the rock matches the water look:
//   the baked detail map (wm_detail: height, slope, mottle, cracks) for tone, seams and relief;
//   strata beds (always, plus the Ocean modes' wm_strata), algae on faces that look up (wm_algae);
//   the rocky floor's violet/magenta, teal and ochre crust, thicker on exposed high faces, fluorescing like the corals;
//   sand settling on the low flats and wherever the rock meets the sand floor (the sand shader's colours);
//   the grotto zones (layout discs): a violet cast, more magenta crust and a faint glow;
//   ambient occlusion TerrainField bakes into COLOR.r, and the openness/skylight volume and sun shadow (phase 5).

#include "res://shaders/scenery.gdshaderinc"
#include "res://shaders/water_caustics.gdshaderinc"
#include "res://shaders/water_materials.gdshaderinc"
#include "res://shaders/water_openness.gdshaderinc"

render_mode cull_back;

uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float crust_amount : hint_range(0.0, 1.0) = 0.65;
uniform float crust_glow = 1.0;
uniform float sand_blend : hint_range(0.0, 1.0) = 1.0;
uniform float zone_tint : hint_range(0.0, 1.0) = 0.8;
uniform float brightness = 1.0;
// The sand floor's world height (the Seabed's y): the rock's height above it decides where sand settles.
uniform float base_y = 0.0;
// A little light of the rock's own (the blue water swamps dark stone; the reef has the same fill).
uniform float self_light = 0.1;
// Grotto zones: world x, z, radius, on.
uniform vec4 zones[4];
uniform vec3 rock_dark : source_color = vec3(0.24, 0.2, 0.26);
uniform vec3 rock_light : source_color = vec3(0.56, 0.48, 0.48);
uniform vec3 light_sand : source_color = vec3(0.62, 0.54, 0.42);
uniform vec3 dark_sand : source_color = vec3(0.36, 0.31, 0.25);

varying vec3 world_pos;
varying vec3 world_nrm;
varying float baked_ao;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	baked_ao = COLOR.r;
}

float zone_at(vec2 xz) {
	float z = 0.0;
	for (int i = 0; i < 4; i++) {
		if (zones[i].w > 0.0) {
			z = max(z, smoothstep(zones[i].z, zones[i].z * 0.45, distance(xz, zones[i].xy)));
		}
	}
	return z;
}

void fragment() {
	vec3 p = world_pos;
	vec3 n0 = normalize(world_nrm);
	float hl = p.y - base_y;
	// The detail map at two scales (fine for texture, coarse for lumps and patches): cheaper than noise per pixel.
	vec4 det = wm_detail(p * 0.9, n0);
	vec4 big = wm_detail(p * 0.22 + 7.0, n0);
	// Relief: the coarse map's lumps, then the fine map's slope across the face.
	vec3 tang = normalize(cross(n0, abs(n0.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 bit = cross(n0, tang);
	vec3 n = normalize(n0 + tang * ((det.y - 0.5) * 0.7 + (big.y - 0.5) * 0.6) + bit * ((det.x - 0.5) * 0.5 + (big.x - 0.5) * 0.6));

	// The stone: mottled two tones, dark cracks, beds of tint every few metres.
	vec3 rock = mix(rock_dark, rock_light, smoothstep(0.2, 0.85, det.z * 0.6 + big.z * 0.7));
	float bed = p.y * 1.31 + (det.x - 0.5) * 1.6 + big.x * 4.0;
	float bands = 0.5 + 0.5 * sin(bed);
	rock *= 0.82 + 0.3 * bands;
	rock = mix(rock, rock * vec3(1.15, 0.95, 0.8), smoothstep(0.6, 0.95, sin(bed * 0.37 + 1.3)) * 0.5);  // a warmer bed now and then
	rock *= 1.0 - det.w * 0.45;
	rock = mix(rock, wm_strata(rock, p, n, det, 0.3), 0.6);

	// Crust: violet / magenta, teal and ochre patches, thicker on high, exposed faces; magenta-heavy in a grotto zone.
	float zone = zone_at(p.xz) * zone_tint;
	float exposed = smoothstep(-0.3, 0.7, n.y) * 0.6 + 0.4;
	float cv = smoothstep(0.42, 0.66, sc_fbm(p * 0.13 + 11.0) + det.x * 0.3 + zone * 0.25);
	float ct = smoothstep(0.66, 0.86, big.z * 0.8 + det.x * 0.25);
	float co = smoothstep(0.64, 0.84, (1.0 - big.y) * 0.75 + (1.0 - det.z) * 0.2);
	float lump = det.z;
	vec3 crust_c = mix(vec3(0.42, 0.1, 0.56), vec3(0.78, 0.16, 0.56), lump);
	crust_c = mix(crust_c, vec3(0.1, 0.5, 0.46), ct * 0.8 * (1.0 - zone * 0.7));
	crust_c = mix(crust_c, vec3(0.78, 0.52, 0.14), co * (1.0 - zone * 0.8));
	float crust_k = clamp(cv * 0.8 + ct * 0.6 + co * 0.6, 0.0, 1.0) * (1.0 - det.w * 0.5) * exposed * crust_amount;
	crust_k = clamp(crust_k + zone * 0.25 * cv, 0.0, 1.0);
	vec3 color = mix(rock, crust_c, crust_k);

	// Algae on faces that look up (the Ocean modes' multiplier).
	float alg = wm_algae(n, det);
	color = mix(color, mix(vec3(0.12, 0.2, 0.08), vec3(0.28, 0.34, 0.1), det.z), alg * (1.0 - zone * 0.5));

	// Sand: on the low flats, on some high flats, and wherever the rock meets the sand floor (hides the seam).
	vec2 sp = p.xz;
	float drift = sc_fbm(vec3(sp * 0.05, 1.0));
	float drifts = smoothstep(0.5, 0.7, drift + (big.z - 0.5) * 0.3);
	vec3 sand = mix(dark_sand, light_sand, smoothstep(0.25, 0.75, drift));
	float flat_k = smoothstep(0.72, 0.93, n0.y);
	float low = 1.0 - smoothstep(0.3, 3.5, hl);
	float seam = 1.0 - smoothstep(-0.1, 0.7, hl);
	float sandy = clamp(flat_k * max(low, drifts * 0.7) + seam, 0.0, 1.0) * sand_blend;
	color = mix(color, wm_biome(sand, 1.0), sandy);
	crust_k *= 1.0 - sandy;

	// The grotto's violet cast, the biome tint.
	color = mix(color, color * vec3(0.75, 0.55, 1.15), zone * 0.6);
	color = wm_biome(color, 0.6) * brightness;

	float ao = mix(1.0, clamp(baked_ao * 1.15, 0.0, 1.0), ao_strength);
	float lit = wo_scene(p);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 rim = color * pow(1.0 - clamp(dot(n, vw), 0.0, 1.0), 2.5) * water_mat_rock.w * wm_light(p) * (1.0 - sandy);
	vec3 flu = wm_fluor(crust_c, p, max(water_mat_sand.z, 0.35) * crust_glow) * crust_k;
	vec3 glow = crust_c * crust_k * (0.03 + zone * 0.08) * crust_glow;  // crust glows faintly of its own, more in a grotto

	ALBEDO = color * lit * mix(1.0, ao, 0.6);
	ROUGHNESS = mix(0.9, 0.97, sandy);
	SPECULAR = 0.25;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = (flu + rim) * ao + glow + color * self_light * lit * ao + sc_bounce(color, n, 0.25) * lit * ao + color * lit * wc_caustics(p, n, length(VERTEX));
}
