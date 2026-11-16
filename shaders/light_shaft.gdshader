// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Light shafts (planning_abyssal_look.md, phase 6, option D4a): each shaft is a unit cylinder instance in one MultiMesh. The vertex
// shader stands it along the light's direction with its top on the surface and wraps it round each view's own camera (so split-screen
// views each get shafts round themselves). The fragment shader gives it abyssal-garden's shaft look without a raymarch: density
// from the caustic net (two scales, as their `pat` term), the sunlight left at that depth per colour, the water's extinction along the
// ray (the murk thins them), a phase of base + gain * mu^3 so they glow looking toward the light, and a soft cut where they meet geometry.
// Instance: the node's transform gives the cell (xz in 0..1 of the range) and the scale gives the radius.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/water_caustics.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 sh_dir = vec3(0.3, 0.9, 0.2);  // toward the light
uniform float sh_surface_y = 30.0;
uniform float sh_range = 110.0;
uniform float sh_len = 90.0;
uniform float sh_over = 6.0;
uniform float sh_widen = 2.5;
uniform vec3 sh_sig = vec3(0.03, 0.012, 0.0099);
uniform vec3 sh_kd = vec3(0.056, 0.0245, 0.017);  // sunlight lost per metre of depth, already divided by the light's height
uniform vec3 sh_color = vec3(0.3, 0.3, 0.35);     // colour times strength
uniform float sh_pattern = 0.8;
uniform float sh_pat_scale = 0.11;
uniform float sh_pat_speed = 1.0;
uniform float sh_soft = 3.0;
uniform vec2 sh_phase = vec2(0.2, 2.0);
uniform float sh_edge = 1.5;
uniform float sh_near = 4.0;
uniform float sh_foot = 0.4;

varying vec3 v_wp;
varying float v_h;
varying vec3 v_n;
varying float v_id;

void vertex() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 a = normalize(sh_dir);
	float r = length(MODEL_MATRIX[0].xyz);
	vec2 cell = MODEL_MATRIX[3].xz * sh_range;
	vec2 off = mod(cell - cam.xz + sh_range * 0.5, sh_range) - sh_range * 0.5;
	// The axis crosses the camera's own height at cam + off, then runs along the light up to the surface.
	float ay = max(a.y, 0.05);
	float rise = max(sh_surface_y - cam.y, 0.0) / ay;
	vec3 at_surface = vec3(cam.x + off.x, cam.y, cam.z + off.y) + a * rise;
	vec3 foot = at_surface - a * sh_len;
	vec3 top = at_surface + a * (sh_over / ay);
	float h = VERTEX.y + 0.5;
	vec3 axis_pt = mix(foot, top, h);
	vec3 u = normalize(cross(a, vec3(0.0, 0.0, 1.0)));
	vec3 v = cross(a, u);
	float rad = r * mix(sh_widen, 1.0, h);
	vec3 radial = u * VERTEX.x + v * VERTEX.z;
	vec3 wp = axis_pt + radial * rad;
	v_wp = wp;
	v_h = h;
	v_n = normalize(u * NORMAL.x + v * NORMAL.z);
	v_id = MODEL_MATRIX[3].x * 37.0 + MODEL_MATRIX[3].z * 11.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	vec3 wp = v_wp;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 rd = wp - cam;
	float dist = length(rd);
	rd /= max(dist, 0.001);
	vec3 a = normalize(sh_dir);
	float ay = max(a.y, 0.05);

	// Soft edge toward the camera across the tube, and no pop when you swim through one.
	float rim = pow(clamp(abs(dot(normalize(v_n), -rd)), 0.0, 1.0), sh_edge);
	float near = smoothstep(0.0, sh_near, dist);

	// Where the light's ray through this point meets the surface: the caustic net there makes the stripes.
	vec2 q = wp.xz - a.xz * (wp.y / ay);
	float t = water_time * sh_pat_speed * 0.5;
	float p1 = wc_turb(q * sh_pat_scale + v_id * 0.013, t);
	float p2 = wc_turb(q * sh_pat_scale * 2.4 + 0.37, t * 0.7);
	float net = min(pow(p1, 0.6) * 1.6 + pow(p2, 0.6) * 0.9, 2.2);
	float dens = mix(1.0, net, sh_pattern);

	// Soft cut against solid geometry.
	float sd = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 vv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, sd, 1.0);
	float scene_z = -vv.z / vv.w;
	float frag_z = -(VIEW_MATRIX * vec4(wp, 1.0)).z;
	float soft = clamp((scene_z - frag_z) / sh_soft, 0.0, 1.0);

	float depth_below = max(sh_surface_y - wp.y, 0.0);
	vec3 sunlight = exp(-sh_kd * depth_below);
	vec3 ext = exp(-sh_sig * dist);
	float mu = max(dot(rd, a), 0.0);
	float phase = sh_phase.x + sh_phase.y * mu * mu * mu;
	float foot_fade = smoothstep(0.0, sh_foot, v_h);
	float top_fade = 1.0 - smoothstep(0.92, 1.0, v_h);

	// Under the procedural terrain's rock the shaft is cut (its baked sun shadow), and it dims in covered water.
	float rock_cut = mix(1.0, wo_sun(wp) * mix(0.35, 1.0, wo_vol(wp).y), terrain_light2.w);
	ALBEDO = sh_color * sunlight * ext * (phase * dens * rim * near * soft * foot_fade * top_fade * rock_cut);
	ALPHA = 1.0;
}
