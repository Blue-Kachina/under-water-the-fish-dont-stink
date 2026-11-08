shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// The Ember Octopus's skin (scripts/what_stinks/forms/octopus_model.gd, octopus_contract.md).
// One shader for every part: mode 0 skin, 1 web, 2 sucker, 3 eye.
// Vertex data: COLOR r = vein weight, g = cavity darkness (siphon inside) / sucker depth is in r for suckers,
// b = arm id / 7, a = oral (sucker side) mask. CUSTOM0 = rest position (design units) + body_u (0 mantle tip .. 1 arm tips).

uniform int mode = 0;

group_uniforms palette;
uniform vec3 copper : source_color = vec3(0.58, 0.18, 0.07);
uniform vec3 violet : source_color = vec3(0.31, 0.10, 0.36);
uniform vec3 deep_tone : source_color = vec3(0.13, 0.035, 0.10);
uniform vec3 belly_tone : source_color = vec3(0.90, 0.52, 0.52);
uniform vec3 vein_hot : source_color = vec3(1.0, 0.50, 0.14);
uniform vec3 vein_white : source_color = vec3(1.0, 0.86, 0.62);
group_uniforms;

group_uniforms skin;
uniform float chroma_speed : hint_range(0.0, 2.0) = 0.16;
uniform float chroma_scale = 5.5;
uniform float spot_scale = 34.0;
uniform float bump_amount : hint_range(0.0, 4.0) = 0.4;
uniform float roughness_base : hint_range(0.05, 1.0) = 0.40;
group_uniforms;

group_uniforms veins;
uniform float vein_scale = 9.0;
uniform float vein_width : hint_range(0.01, 0.5) = 0.10;
uniform float vein_energy = 1.7;
uniform float cell_scale = 24.0;
uniform float cell_energy = 0.5;
group_uniforms;

group_uniforms drivers;
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform float mantle_pulse : hint_range(-1.0, 1.0) = 0.0;
uniform float stroke : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float vein_travel = -1.0;
uniform float vein_travel_gain = 1.4;
uniform vec4 arm_glow_a = vec4(0.0);
uniform vec4 arm_glow_b = vec4(0.0);
uniform float sucker_glow : hint_range(0.0, 3.0) = 0.15;
uniform float eye_glow : hint_range(0.0, 3.0) = 0.35;
uniform float chroma_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

varying vec4 rest;
varying vec4 reg;
varying vec3 view_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1, 0, 0));
	float c = hash13(i + vec3(0, 1, 0));
	float d = hash13(i + vec3(1, 1, 0));
	float e = hash13(i + vec3(0, 0, 1));
	float g = hash13(i + vec3(1, 0, 1));
	float h = hash13(i + vec3(0, 1, 1));
	float k = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(7.1, 3.7, 1.3);
		a *= 0.5;
	}
	return v / 0.875;
}

// x = F1, y = F2, z = a hash of the nearest cell
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 o = hash33(ip + g);
				float d = length(g + o - fp);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = o.x;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec3(f1, f2, id);
}

float ridge(vec3 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

vec3 bump_normal(vec3 n, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - k * grad);
}

float arm_glow_of(float id_f) {
	int id = int(floor(id_f * 7.0 + 0.5));
	float v = 0.0;
	if (id == 0) v = arm_glow_a.x;
	else if (id == 1) v = arm_glow_a.y;
	else if (id == 2) v = arm_glow_a.z;
	else if (id == 3) v = arm_glow_a.w;
	else if (id == 4) v = arm_glow_b.x;
	else if (id == 5) v = arm_glow_b.y;
	else if (id == 6) v = arm_glow_b.z;
	else v = arm_glow_b.w;
	return v;
}

void vertex() {
	rest = CUSTOM0;
	reg = COLOR;
}

void fragment() {
	vec3 P = rest.xyz;
	float u = rest.w;
	float ag = arm_glow_of(reg.b);
	float pulse_pos = max(mantle_pulse, 0.0);
	float lum_hurt = 1.0 - hurt * 0.5;

	if (mode == 3) {
		// Eye: rest.xyz is the unit sphere position, +Z is the front.
		vec3 q = normalize(P);
		vec2 d = q.xy;
		float rad = length(d);
		float front = smoothstep(-0.05, 0.1, q.z);
		vec2 pp = vec2(d.x / 0.56, d.y / 0.17);
		float pup = 1.0 - smoothstep(0.86, 1.0, length(pp));
		float iris_mask = (1.0 - smoothstep(0.80, 0.88, rad)) * front;
		float ang = atan(d.y, d.x);
		float fib = 0.5 + 0.5 * sin(ang * 21.0 + vnoise(vec3(ang * 2.0, rad * 7.0, 1.0)) * 5.0);
		float inner = 1.0 - smoothstep(0.1, 0.8, rad);
		vec3 iris = mix(vec3(0.42, 0.14, 0.04), vec3(0.98, 0.62, 0.16), fib * 0.35 + inner * 0.55);
		iris = mix(iris, vec3(0.13, 0.04, 0.02), smoothstep(0.64, 0.82, rad));
		vec3 outer = mix(vec3(0.19, 0.07, 0.07), vec3(0.34, 0.13, 0.17), vnoise(P * 9.0));
		ALBEDO = mix(outer, iris, iris_mask) * (1.0 - pup);
		ROUGHNESS = mix(0.45, 0.04, iris_mask);
		SPECULAR = 0.9;
		CLEARCOAT = iris_mask;
		CLEARCOAT_ROUGHNESS = 0.03;
		float glint = (1.0 + charge * 2.2 + flash * 2.0);
		EMISSION = vec3(1.0, 0.52, 0.12) * eye_glow * glint * iris_mask * (1.0 - pup) * (0.35 + 0.65 * inner) * glow * lum_hurt;
	} else if (mode == 2) {
		// Sucker: pale wet cup, darker in the pit, warm when the arm lights.
		float depth = reg.r;
		vec3 pale = vec3(0.64, 0.36, 0.32);
		vec3 pit = vec3(0.42, 0.12, 0.16);
		ALBEDO = mix(pale, pit, smoothstep(0.1, 0.9, depth));
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.75, 0.8, 1.0), chroma_shift * 0.3);
		ROUGHNESS = 0.5 + 0.15 * (1.0 - depth);
		SPECULAR = 0.3;
		RIM = 0.25;
		RIM_TINT = 0.8;
		float breathe = 0.7 + 0.3 * sin(TIME * 1.4 + u * 9.0 + reg.b * 6.0);
		float e = sucker_glow * breathe + charge * 0.55 + flash * 0.7 + ag * 0.8;
		float tp = vein_travel >= 0.0 && vein_travel <= 1.3 ? exp(-pow((u - vein_travel) * 6.0, 2.0)) * vein_travel_gain : 0.0;
		EMISSION = mix(vein_hot, vein_white, clamp(charge * 0.6 + flash, 0.0, 1.0)) * (e + tp) * (0.35 + 0.65 * depth) * glow * lum_hurt * 0.55;
	} else {
	// ---- skin (0) and web (1)
	bool web = mode == 1;
	float mantle_w = 1.0 - smoothstep(0.2, 0.4, u);
	// chromatophores: colour drifting along the body, speckle that swells and shrinks
	float drift = fbm(P * chroma_scale + vec3(0.0, 0.0, TIME * chroma_speed));
	float tcol = clamp(u * 1.25 - 0.1 + (drift - 0.5) * 0.7 + chroma_shift * 0.5, 0.0, 1.0);
	vec3 base = mix(copper, violet, smoothstep(0.22, 0.88, tcol));
	base = mix(base, deep_tone, smoothstep(0.55, 1.0, fbm(P * 3.0 + 4.0)) * 0.45);
	vec3 vor = voronoi(P * spot_scale);
	float breathe_spot = 0.20 + 0.07 * sin(TIME * 0.7 + vor.z * 6.283 + chroma_shift * 3.0);
	float spot = 1.0 - smoothstep(breathe_spot - 0.06, breathe_spot + 0.05, vor.x);
	float oral = reg.a;
	base = mix(base, vec3(0.30, 0.05, 0.05), spot * 0.40 * (1.0 - oral));
	base = mix(base, belly_tone, oral * 0.55);
	// a pearly sheen at grazing angles
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	base = mix(base, base * vec3(0.8, 0.85, 1.3), fres * 0.15);
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(lum) * vec3(1.1, 0.95, 0.95), hurt * 0.6);
	ALBEDO = base * lum_hurt;
	ROUGHNESS = clamp(roughness_base + 0.22 * (drift - 0.5) - 0.1 * spot, 0.1, 0.9);
	SPECULAR = 0.55;
	RIM = 0.45;
	RIM_TINT = 0.55;

	// fine skin bump from the spots and a pore noise
	float h = vor.x * 0.6 + vnoise(P * 120.0) * 0.4;
	NORMAL = bump_normal(NORMAL, VERTEX, h, 0.0016 * bump_amount);

	// ---- the emissive vein network
	vec3 warp = (vec3(vnoise(P * 5.0), vnoise(P * 5.0 + 11.0), vnoise(P * 5.0 + 23.0)) - 0.5) * 0.32;
	float w = vein_width * (1.0 + charge * 0.55 + stroke * 0.25 + pulse_pos * 0.2);
	float v1 = ridge(P * vein_scale + warp * vein_scale);
	float v2 = ridge(P * vein_scale * 3.1 + warp * 9.0 + 5.0);
	float line = max(smoothstep(1.0 - w, 1.0, v1), smoothstep(1.0 - w * 0.8, 1.0, v2) * 0.55);
	float halo = smoothstep(1.0 - w * 3.6, 1.0, v1) * 0.16;
	float flow = 0.5 + 0.5 * sin(TIME * (1.4 + stroke * 2.6 + charge * 5.0) - u * 9.0 + vnoise(P * 4.0) * 4.0);
	float idle = 0.55 + 0.45 * sin(TIME * 1.1 + u * 6.0 + vnoise(P * 3.0) * 5.0);
	float vein_level = mix(idle, flow, clamp(0.25 + stroke * 0.6 + charge * 0.5, 0.0, 1.0));
	float tp = vein_travel >= 0.0 && vein_travel <= 1.3 ? exp(-pow((u - vein_travel) * 6.5, 2.0)) * vein_travel_gain : 0.0;
	float weight = reg.r * (web ? 0.55 : 1.0);
	float drive = 1.0 + stroke * 0.8 + charge * 0.45 + pulse_pos * 0.8 + tp * 1.6 + ag * 0.9 + flash * 1.0;
	vec3 vcol = mix(vein_hot, vein_white, clamp(charge * 0.25 + flash * 0.7 + tp * 0.35 + pulse_pos * 0.2, 0.0, 1.0));
	vec3 emit = vcol * (line * (0.5 + 0.5 * vein_level) + halo) * vein_energy * weight * drive;

	// mantle cells: glowing rings like the cells in the reference's mantle
	if (mantle_w > 0.02 && !web) {
		vec3 cv = voronoi(P * cell_scale + vec3(0.0, 0.0, 3.0));
		float ring = 1.0 - smoothstep(0.0, 0.06, abs(cv.x - 0.30 - 0.03 * sin(TIME * 0.9 + cv.z * 6.0)));
		float edge = 1.0 - smoothstep(0.0, 0.10, cv.y - cv.x);
		float cells = (ring * 0.25 + edge * 0.1) * mantle_w * cell_energy;
		emit += mix(vein_hot, vein_white, 0.25 + charge * 0.3) * cells * (0.5 + 0.5 * vein_level) * (1.0 + stroke * 0.6 + charge * 0.35 + pulse_pos * 0.6 + tp * 1.2) * (1.0 - oral);
		// the mantle glows from within, brightest high up
		emit += vein_hot * 0.07 * mantle_w * (0.6 + 0.4 * idle) * (1.0 + charge * 0.7);
	}
	emit += vec3(0.28, 0.10, 0.55) * fres * 0.12;
	EMISSION = emit * glow * lum_hurt;

	// translucent flesh: light through the thin mantle and webs
	BACKLIGHT = vec3(0.45, 0.16, 0.07) * (web ? 1.4 : 0.55 * mantle_w + 0.2);
	// siphon interior and other cavities
	if (reg.g > 0.01) {
		ALBEDO = mix(ALBEDO, deep_tone * 0.5, reg.g);
		EMISSION *= 1.0 - reg.g;
	}
	}
}
