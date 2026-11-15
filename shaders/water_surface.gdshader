// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// The water's surface seen from below (planning_abyssal_look.md, phase 4). One big flat plane that
// puts itself under every camera (CAMERA_POSITION_WORLD is per view, so split-screen views each get
// their own and one mesh serves them all), at the surface height. Drawn in the transparent pass after
// the fog pass with full alpha: what is below it is already fogged, and it fogs itself.
//   - slope from three octaves of summed cosines (own wave table);
//   - Snell's window  k = 1 - 1.769 (1 - cos^2): inside it the sky above and the refracted sun;
//   - Fresnel  pow(1 - sqrt(k), 5): toward the rim and past it (total internal reflection) the
//     surface mirrors the water below, wf_in() along the reflected ray;
//   - then the same absorption and in-scatter along the camera's ray as the fog pass.
shader_type spatial;
render_mode unshaded, depth_test_default, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, blend_mix;

#include "res://shaders/water_fog.gdshaderinc"

uniform float ws_radius = 900.0;
uniform float ws_surface_y = 30.0;
uniform float ws_time = 0.0;
uniform vec2 ws_fade = vec2(150.0, 220.0);
uniform float ws_wave = 1.0;           // slope scale
uniform vec3 ws_sky = vec3(0.45, 0.65, 1.0);   // the sky above the water, looked at through the window
uniform vec3 ws_sun_col = vec3(1.7, 1.6, 1.45);
uniform vec3 ws_sun_dir = vec3(0.4, 0.84, 0.4);  // the disc seen through the window (the real sun, or Unnatural's moon)
uniform vec2 ws_glare = vec2(1.3, 12.0);  // sun disc halo and core strength
uniform float ws_far_calm = 90.0;      // slopes flatten with distance (no shimmer at the grazing rim)

varying vec3 world_pos;

// Three octaves: (direction x, z), frequency (rad / m), amplitude (m), speed (rad / s).
const vec4 WK0 = vec4(0.82, 0.57, 0.40, 0.30);
const vec4 WK1 = vec4(-0.45, 0.89, 1.15, 0.07);
const vec4 WK2 = vec4(0.28, -0.96, 2.90, 0.018);

vec2 ws_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	vec4 w[3] = vec4[3](WK0, WK1, WK2);
	float sp[3] = float[3](0.85, 1.3, 2.1);
	for (int i = 0; i < 3; i++) {
		vec2 dir = normalize(w[i].xy);
		float ph = dot(dir, p) * w[i].z + t * sp[i] * (0.6 + w[i].z * 0.5) + float(i) * 1.7;
		s += dir * (-sin(ph) * w[i].w * w[i].z);
	}
	return s;
}

void vertex() {
	vec3 w = vec3(CAMERA_POSITION_WORLD.x + VERTEX.x * ws_radius, ws_surface_y, CAMERA_POSITION_WORLD.z + VERTEX.z * ws_radius);
	world_pos = w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	if (cam.y > ws_surface_y - 0.3) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;  // above the water there is no underside to see
	} else {
		vec3 v = world_pos - cam;
		float d = length(v);
		vec3 rd = v / d;
		vec2 s = ws_slope(world_pos.xz, ws_time) * ws_wave / (1.0 + d / ws_far_calm);
		vec3 nd = normalize(vec3(s.x, -1.0, s.y));  // the underside's normal, pointing down into the water
		float c = clamp(dot(-rd, nd), 0.0, 1.0);
		float k = 1.0 - 1.769 * (1.0 - c * c);
		float ro_y = cam.y - ws_surface_y;

		// Looking out through Snell's window: the sky above and the refracted sun.
		vec3 t_dir = refract(rd, nd, 1.33);
		float sd = max(dot(normalize(t_dir + vec3(0.0, 1e-4, 0.0)), normalize(ws_sun_dir)), 0.0);
		vec3 window = ws_sky * mix(0.8, 1.35, clamp(1.0 - t_dir.y, 0.0, 1.0));
		window += ws_sun_col * (pow(sd, 60.0) * ws_glare.x + pow(sd, 500.0) * ws_glare.y);
		if (k <= 0.0) {
			window = vec3(0.0);
		}

		// Past the window's rim, and as the angle flattens, a mirror of the water below.
		vec3 rr = reflect(rd, nd);
		vec3 mirror = wf_in(-0.5, rr, ws_fade.y, wf_sig);
		float fres = k <= 0.0 ? 1.0 : 0.02 + 0.98 * pow(1.0 - sqrt(k), 5.0);
		vec3 col = mix(window, mirror, fres);

		// The camera's own water between it and the surface.
		vec3 scatter = wf_in(ro_y, rd, d, wf_sig);
		float far = smoothstep(ws_fade.x, max(ws_fade.y, ws_fade.x + 0.01), d);
		ALBEDO = mix(col * exp(-wf_sig * d) + scatter, scatter, far);
		ALPHA = 1.0;
	}
}
