// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Flora blades (planning_abyssal_look.md, flora pass): one curved ribbon (ROWS rows of two vertices; UV = (side -1/+1, row fraction))
// instanced thousands of times by FloraField. The instance transform carries the blade's data instead of a pose (the shader places
// the vertices itself and writes POSITION):
//   MODEL_MATRIX[3].xyz   root of the blade (world; the field's node must only be translated)
//   MODEL_MATRIX[0].xyz   length, yaw, tilt (from vertical)
//   MODEL_MATRIX[1].xyz   width, sway height (m above the ground for the sway), type + bend * 0.99
//   MODEL_MATRIX[2].xy    two random seeds
// The blade is a constant-curvature arc along `d` (bend sets the curvature, breathing over time), twisted along its length, with a
// travelling ruffle, a height-scaled sway (flora_sway) and per-type colour, translucency, sparkle band and iridescence. Close to the
// camera, or far away, the width fades to nothing, so blades never crowd the lens or pop at the draw distance.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/scenery.gdshaderinc"
#include "res://shaders/water_caustics.gdshaderinc"
#include "res://shaders/water_materials.gdshaderinc"
#include "res://shaders/flora_sway.gdshaderinc"

uniform float sway_amount = 1.0;
uniform float width_mul = 1.0;
uniform float length_mul = 1.0;
uniform float brightness = 2.0;
// Where blades have faded out completely (m): FloraField sets this to its draw distance.
uniform float far_dist = 150.0;
uniform float ruffle_near = 26.0;
uniform float ruffle_far = 40.0;

varying flat vec3 v_col;
varying flat vec4 v_pr;    // x on a sparkle band (0/1), y translucency, z iridescence, w emissive
varying flat vec3 v_spc;   // sparkle colour
varying flat vec2 v_seed;
varying vec3 v_wp;
varying vec3 v_wn;
varying vec2 v_uv;

float fl_hs(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

vec3 fl_pal(float h) {
	if (h < 0.3) { return vec3(1.0, 0.62, 0.08); }
	if (h < 0.6) { return vec3(0.12, 1.0, 0.22); }
	if (h < 0.8) { return vec3(0.2, 0.85, 1.0); }
	return vec3(1.0, 0.3, 0.8);
}

void vertex() {
	float u = UV.x;
	float v = UV.y;
	vec3 m0 = MODEL_MATRIX[0].xyz;
	vec3 m1 = MODEL_MATRIX[1].xyz;
	vec3 m2 = MODEL_MATRIX[2].xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float len = m0.x * length_mul;
	float yaw = m0.y;
	float tilt = m0.z;
	float width = m1.x * width_mul;
	float hA = m1.y;
	float ty = floor(m1.z + 0.001);
	float bend = clamp((m1.z - ty) / 0.99, 0.0, 1.0);
	float s1 = m2.x;
	float s2 = m2.y;
	float t = TIME;

	float cy = cos(yaw);
	float sy = sin(yaw);
	float ct = cos(tilt);
	float st = sin(tilt);
	vec3 d = vec3(st * cy, ct, st * sy);
	vec3 pe = vec3(ct * cy, -st, ct * sy);
	vec3 sd = vec3(-sy, 0.0, cy);

	// Per type: colour, (sparkle probability, translucency, iridescence, emissive), sparkle colour, shape exponents, wave, flutter.
	vec3 col = vec3(0.0);
	vec4 pr = vec4(0.0);
	vec3 spc = vec3(0.0);
	vec2 shp = vec2(0.75, 0.7);
	float wav = 1.0;
	float fls = 1.0;
	float hsel = fl_hs(s1 * 13.7 + s2 * 71.3);
	int ti = int(ty);
	if (ti == 0) { // olive kelp
		col = mix(vec3(0.10, 0.20, 0.045), vec3(0.04, 0.13, 0.06), s1);
		col = mix(col, vec3(0.20, 0.07, 0.34), step(0.62, s2));  // violet leaves
		col = mix(col, vec3(0.42, 0.34, 0.04), step(0.86, fract(s2 * 7.3 + s1)));  // yellow-ochre leaves
		pr = vec4(0.24, 0.9, 0.0, 0.0);
		spc = fl_pal(hsel * 0.72);
		shp = vec2(0.5, 0.32);
		wav = 1.9;
	} else if (ti == 1) { // dark stipe leaf
		col = vec3(0.10, 0.11, 0.035);
		pr = vec4(0.0, 0.2, 0.0, 0.0);
		shp = vec2(0.05, 0.1);
		wav = 0.3;
		fls = 0.3;
	} else if (ti == 2) { // teal grass
		col = mix(vec3(0.05, 0.20, 0.16), vec3(0.12, 0.26, 0.22), s1);
		col = mix(col, vec3(0.30, 0.14, 0.24), step(0.85, s2));
		pr = vec4(0.05, 1.0, 0.25, 0.0);
		spc = vec3(0.6, 1.0, 0.9);
		shp = vec2(0.45, 0.35);
		wav = 2.2;
	} else if (ti == 3) { // violet-dark kelp
		col = mix(vec3(0.02, 0.05, 0.065), vec3(0.05, 0.03, 0.08), s1);
		col = mix(col, vec3(0.09, 0.03, 0.09), step(0.8, s2));
		pr = vec4(0.2, 0.85, 0.55, 0.02);
		spc = mix(vec3(0.5, 0.35, 1.0), vec3(0.2, 1.0, 0.7), step(0.6, hsel));
		shp = vec2(0.7, 0.6);
		wav = 2.4;
	} else if (ti == 4) { // amber
		col = mix(vec3(0.30, 0.15, 0.02), vec3(0.42, 0.25, 0.04), s1);
		pr = vec4(0.2, 1.0, 0.1, 0.0);
		spc = vec3(1.0, 0.85, 0.5);
		shp = vec2(0.5, 0.4);
		wav = 1.8;
	} else if (ti == 5) { // magenta cover
		col = mix(vec3(0.85, 0.05, 0.40), vec3(0.60, 0.10, 0.80), step(0.7, s1));
		col = mix(col, vec3(0.95, 0.25, 0.55), step(0.75, s2));
		pr = vec4(0.22, 0.8, 0.0, 0.30);
		spc = vec3(1.0, 0.35, 0.8);
		shp = vec2(0.6, 0.6);
		fls = 2.0;
	} else if (ti == 6) { // red frond
		col = mix(vec3(0.80, 0.16, 0.16), vec3(0.92, 0.36, 0.42), s1);
		pr = vec4(0.06, 1.0, 0.0, 0.10);
		spc = vec3(1.0, 0.5, 0.5);
		shp = vec2(0.4, 0.3);
		wav = 2.0;
	} else { // cyan reef grass
		col = mix(vec3(0.05, 0.40, 0.36), vec3(0.10, 0.52, 0.58), s1);
		pr = vec4(0.1, 0.9, 0.2, 0.04);
		spc = vec3(0.3, 1.0, 0.9);
		shp = vec2(0.6, 0.5);
	}
	// water_mat_kelp2.w is the share of blades on a sparkle band (0.24 is what the table above was written for).
	pr.x = step(fl_hs(s1 * 91.7 + s2 * 37.1 + yaw), pr.x * water_mat_kelp2.w / 0.24);

	// Constant-curvature arc, breathing over time, plus a travelling wave.
	float k = (bend - 0.3) * 2.0 + sin(t * (0.8 + s1) * fls + s2 * 40.0 + hA * 0.25) * 0.10 * fls;
	float wph = v * (3.0 + 5.0 * s2) + s1 * 30.0 + t * 1.1;
	float wv = sin(wph) * 0.12 * wav;
	float kq = k * 1.7;
	float ka = abs(kq) < 0.06 ? 0.06 : kq;
	float sK = sin(ka * v);
	float cK = cos(ka * v);
	vec3 c = origin + len * (d * (sK / ka) + pe * ((1.0 - cK) / ka + wv * v));
	float sl = sK + wv + cos(wph) * 0.10 * wav * v * (3.0 + 5.0 * s2);
	vec3 N = normalize(pe * cK - d * sl);
	vec3 T0 = normalize(d * cK + pe * sl);
	// Twist about the blade's own axis.
	float tw = (s1 - 0.5) * 2.4 * v + sin(t * 0.9 + s2 * 20.0) * 0.25 * v;
	vec3 S = sd * cos(tw) + N * sin(tw);
	vec3 N2 = N * cos(tw) - sd * sin(tw);
	float shape = pow(max(sin(3.14159 * pow(v, shp.x)), 0.0), shp.y);

	vec3 cam = CAMERA_POSITION_WORLD;
	float cd = distance(origin, cam);
	float nearK = 1.0 - smoothstep(ruffle_near, ruffle_far, cd);
	float farK = (1.0 - smoothstep(far_dist * 0.8, far_dist, cd))
			* smoothstep(0.6, 2.2, distance(c, cam))
			* smoothstep(len * 1.1 + 0.5, len * 2.2 + 1.2, distance(origin + d * (len * 0.5), cam));
	float ruf = sin(v * 10.0 + s2 * 30.0 + t * 0.6) * width * 0.36 * u * sin(3.14159 * clamp(v, 0.0, 1.0)) * nearK;
	vec3 p = c + S * (u * farK * (width * 0.5 * shape));
	p += N2 * ruf;
	vec2 sw = flora_sway(origin.xz, hA + (p.y - origin.y), t, sway_amount);
	p.x += sw.x;
	p.z += sw.y;

	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	v_wp = p;
	v_wn = normalize(N2 + S * u * 0.55 - T0 * cos(v * 10.0 + s2 * 30.0 + t * 0.6) * u * 0.7 * nearK);
	v_uv = vec2(u, v);
	v_col = col * brightness;
	v_pr = pr;
	v_spc = spc;
	v_seed = vec2(s1, s2);
}

void fragment() {
	vec3 wn = normalize(v_wn);
	if (!FRONT_FACING) {
		wn = -wn;
	}
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float along = v_uv.y;
	vec3 color = v_col * mix(0.55, 1.15, smoothstep(0.0, 1.0, along));
	// Veins: fine stripes along the blade and a darker midrib.
	float vein = 1.0 - smoothstep(0.0, 0.12, abs(sin(v_uv.x * 7.0 + v_seed.y * 6.0)));
	float rib = 1.0 - smoothstep(0.0, 0.12, abs(v_uv.x));
	color *= 1.0 - (vein * 0.5 + rib * 0.35) * water_mat_kelp.z;
	vec3 extra = vec3(0.0);
	float ndv = abs(dot(wn, vw));
	// Thin-film iridescence.
	vec3 film = 0.5 + 0.5 * cos(6.2832 * (ndv * 1.6 + along * 0.7 + v_seed.x + vec3(0.0, 0.33, 0.67)));
	color = mix(color, color * (0.6 + film * 0.9), clamp(water_mat_kelp.y * v_pr.z * 3.0, 0.0, 1.0) * (1.0 - ndv * 0.5));
	vec3 light = wm_light(v_wp);
	// Warm translucency when the sun is behind the blade.
	float back = pow(clamp(dot(-vw, water_sun_dir), 0.0, 1.0), 3.0);
	extra += color * water_mat_kelp2.rgb * back * water_mat_kelp.x * v_pr.y * light;
	// A sparkle band travelling up some blades.
	float travel = fract(TIME * 0.12 + fl_hs(v_seed.x * 53.0 + v_seed.y * 17.0));
	extra += v_spc * v_pr.x * smoothstep(0.09, 0.0, abs(along - travel)) * water_mat_kelp.w * light;
	extra += color * v_pr.w;
	ALBEDO = color;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = color * v_pr.y * 0.6;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	EMISSION = extra + color * wc_caustics(v_wp, wn, length(VERTEX));
}
