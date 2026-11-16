// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Caustics (planning_abyssal_look.md, phase 3): the sun's light, bent by the surface's ripples, drawn on whatever faces the sun.
// Evaluated inline (no SubViewport, so every split-screen view gets it): a 5-iteration sin turbulence looked up where the sun's
// ray through the point meets the surface, an RGB split (the colours bend a little differently) and a second rotated tap that
// breaks the pattern's tiling. Returns the light to ADD times the albedo (use it in EMISSION).
// The globals are set by WaterLook / Ocean every frame; strength 0 (any non-Ocean arena) returns at once.

#include "res://shaders/water_openness.gdshaderinc"

global uniform float water_time;
global uniform float water_caustic_strength;
global uniform float water_caustic_scale;
global uniform float water_caustic_speed;
global uniform float water_caustic_fade_start;
global uniform float water_caustic_fade_end;
global uniform float water_caustic_split;
global uniform float water_surface_y;
global uniform vec3 water_sun_dir;  // toward the sun
global uniform vec3 water_kd;       // sunlight lost per metre of depth, per colour, already divided by the sun's height

// The pattern: bright thin net lines on dark, 0..1 and a bit over.
float wc_turb(vec2 uv, float t) {
	vec2 p = mod(uv * TAU, TAU) - 250.0;
	vec2 i = p;
	float c = 1.0;
	const float inten = 0.005;
	for (int n = 0; n < 5; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 5.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

// `wp` world position, `n` world normal, `dist` metres from the camera.
vec3 wc_caustics(vec3 wp, vec3 n, float dist) {
	if (water_caustic_strength <= 0.0) {
		return vec3(0.0);
	}
	float fade = 1.0 - smoothstep(water_caustic_fade_start, max(water_caustic_fade_end, water_caustic_fade_start + 0.1), dist);
	float facing = smoothstep(0.1, 0.45, dot(n, water_sun_dir));
	float k = fade * facing;
	if (k <= 0.001) {
		return vec3(0.0);
	}
	float sy = max(water_sun_dir.y, 0.05);
	vec2 q = (wp.xz - water_sun_dir.xz * (wp.y / sy)) * water_caustic_scale;
	float t = water_time * water_caustic_speed * 0.5;
	vec3 a;
	if (water_caustic_split > 0.0) {
		a = vec3(wc_turb(q, t), wc_turb(q + vec2(0.004, 0.0025) * water_caustic_split, t), wc_turb(q + vec2(0.008, 0.005) * water_caustic_split, t));
	} else {
		a = vec3(wc_turb(q, t));
	}
	float b = wc_turb(q.yx / 6.9 + 0.37, t * 0.7);
	vec3 pat = min(pow(a, vec3(2.3)) * 5.0 * (0.45 + b * 1.3), vec3(4.0));
	float depth = max(water_surface_y - wp.y, 0.0);
	vec3 sun = exp(-water_kd * depth);  // the sunlight left at this depth, per colour
	return pat * sun * k * water_caustic_strength * wo_sun(wp);  // none under rock (procedural terrain's shadow)
}
