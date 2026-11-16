// Light that rock blocks (planning_procedural_world.md, phase 5). Two textures baked once per stage from the terrain's
// distance field (TerrainLight sets them, in world space):
//   terrain_vol      RG8 3D, 1.5 m: R openness (distance to rock / reach), G skylight swept down from the top and
//                    blurred, so grottoes, overhangs and canyon floors go dark and the gaps stay bright.
//   terrain_shadow   RH 2D: per (x, z) on the terrain's base plane, the height of the first rock along the sun's line;
//                    a point is in the rock's shadow when that rock is above it.
// With no terrain (terrain_light.w 0) every function returns "open and lit", so other modes look as before.
#ifndef WATER_OPENNESS_INC
#define WATER_OPENNESS_INC

global uniform sampler3D terrain_vol : filter_linear, repeat_disable;
global uniform vec4 terrain_vol_origin;   // xyz world origin of the volume, w 1/reach (unused here)
global uniform vec4 terrain_vol_size;     // xyz world extent (m)
global uniform sampler2D terrain_shadow : filter_linear, repeat_disable;
global uniform vec4 terrain_shadow_rect;  // world x0, z0, extent x, extent z
global uniform vec4 terrain_shadow_sun;   // the bake's direction toward the sun (xyz), w the base plane's world y
global uniform vec4 terrain_light;        // x skylight strength, y shadow strength, z darkest a grotto gets, w on (0/1)
global uniform vec4 terrain_light2;       // x shadow softness (m), y openness AO strength, z fog darkening, w shaft cut

// RG at `wp`: (openness 0..1, skylight 0..1). (1, 1) outside the volume or with no terrain.
vec2 wo_vol(vec3 wp) {
	if (terrain_light.w <= 0.0) {
		return vec2(1.0);
	}
	vec3 uvw = (wp - terrain_vol_origin.xyz) / terrain_vol_size.xyz;
	if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) {
		return vec2(1.0);
	}
	return textureLod(terrain_vol, uvw, 0.0).rg;
}

// 1 lit by the sun, 0 in the rock's shadow (a few taps, softened by terrain_light2.x).
float wo_sun(vec3 wp) {
	if (terrain_light.w <= 0.0 || terrain_light.y <= 0.0) {
		return 1.0;
	}
	vec3 L = terrain_shadow_sun.xyz;
	float h = wp.y - terrain_shadow_sun.w;
	vec2 p0 = wp.xz - L.xz * (h / max(L.y, 0.05));
	vec2 uv = (p0 - terrain_shadow_rect.xy) / terrain_shadow_rect.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 1.0;
	}
	float soft = max(terrain_light2.x, 0.01);
	vec2 texel = vec2(soft) / terrain_shadow_rect.zw;
	float lit = 0.0;
	lit += step(textureLod(terrain_shadow, uv, 0.0).r, h + 0.6);
	lit += step(textureLod(terrain_shadow, uv + vec2(texel.x, 0.0), 0.0).r, h + 0.6);
	lit += step(textureLod(terrain_shadow, uv - vec2(texel.x, 0.0), 0.0).r, h + 0.6);
	lit += step(textureLod(terrain_shadow, uv + vec2(0.0, texel.y), 0.0).r, h + 0.6);
	lit += step(textureLod(terrain_shadow, uv - vec2(0.0, texel.y), 0.0).r, h + 0.6);
	return mix(1.0, lit * 0.2, terrain_light.y);
}

// How much light reaches a surface at `wp` (0..1): skylight (grottoes dark), the sun's shadow, and a little AO from
// nearby rock. Multiply the albedo (it scales both the ambient and the direct light).
float wo_scene(vec3 wp) {
	if (terrain_light.w <= 0.0) {
		return 1.0;
	}
	vec2 v = wo_vol(wp);
	float sky = mix(terrain_light.z, 1.0, smoothstep(0.0, 0.85, v.y));
	float k = mix(1.0, sky, terrain_light.x);
	k *= mix(1.0, 0.65 + 0.35 * wo_sun(wp), terrain_light.y);
	k *= mix(1.0, 0.6 + 0.4 * smoothstep(0.0, 0.5, v.x), terrain_light2.y);
	return k;
}

// The skylight averaged along a ray from `ro` for `d` m (four taps, the first 80 m): the fog's in-scatter darkens with it.
float wo_ray_sky(vec3 ro, vec3 rd, float d) {
	if (terrain_light.w <= 0.0 || terrain_light2.z <= 0.0) {
		return 1.0;
	}
	float dd = min(d, 80.0);
	float s = wo_vol(ro + rd * dd * 0.1).y + wo_vol(ro + rd * dd * 0.35).y + wo_vol(ro + rd * dd * 0.65).y + wo_vol(ro + rd * dd).y;
	float sky = mix(terrain_light.z, 1.0, smoothstep(0.0, 0.85, s * 0.25));
	return mix(1.0, sky, terrain_light2.z);
}

#endif
