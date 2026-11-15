// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Phase 6 option D4b bench (Look Tank only): a FogVolume whose density follows the caustic net along the sun, so Godot's volumetric
// fog (lit by the sun) makes shafts without the cylinders. Compare its GPU cost against light_shaft.gdshader.
// (The turbulence is repeated from water_caustics.gdshaderinc. Fog shaders name their function fog(), not fragment().)
shader_type fog;

global uniform float water_time;
global uniform vec3 water_sun_dir;

uniform float density = 0.06;
uniform float pat_scale = 0.11;
uniform vec3 albedo : source_color = vec3(0.7, 0.9, 1.0);

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

void fog() {
	vec3 wp = WORLD_POSITION;
	vec3 sun = normalize(water_sun_dir);
	vec2 q = (wp.xz - sun.xz * (wp.y / max(sun.y, 0.05))) * pat_scale;
	float t = water_time * 0.5;
	float net = min(pow(wc_turb(q, t), 0.6) * 1.6 + pow(wc_turb(q * 2.4 + 0.37, t * 0.7), 0.6) * 0.9, 2.2);
	DENSITY = density * net;
	ALBEDO = albedo;
}
