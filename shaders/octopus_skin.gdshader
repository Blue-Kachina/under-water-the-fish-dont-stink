shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// The Ember Octopus's skin (scripts/what_stinks/forms/octopus_model.gd, octopus_contract.md).
// One shader for every part: mode 0 skin, 1 web, 2 sucker, 3 eye.
// Look (private_content/giant_glowing_octopus.png): deep wine / maroon-violet wet skin, wrinkled and studded with papillae, the
// glow a fine sparkle of ember photophores under the skin with a warm gold core in the mantle; pale-rimmed suckers; a small dark
// slit-pupil eye. The papillae and wrinkles are also pushed into the silhouette in vertex() (skin only).
// Vertex data: COLOR r = glow weight, g = cavity darkness (siphon inside) / sucker depth is in r for suckers,
// b = arm id / 7, a = oral (sucker side) mask. CUSTOM0 = rest position (design units) + body_u (0 mantle tip .. 1 arm tips).

uniform int mode = 0;
uniform float unit_m = 1.0;  // metres per design unit (set by the model)

group_uniforms palette;
uniform vec3 copper : source_color = vec3(0.36, 0.05, 0.08);  // the warm wine end of the skin (chroma_shift -1 pushes here)
uniform vec3 violet : source_color = vec3(0.22, 0.05, 0.17);  // maroon-violet (chroma_shift +1)
uniform vec3 deep_tone : source_color = vec3(0.07, 0.012, 0.04);
uniform vec3 belly_tone : source_color = vec3(0.62, 0.36, 0.40);
uniform vec3 vein_hot : source_color = vec3(1.0, 0.46, 0.12);   // ember
uniform vec3 vein_white : source_color = vec3(1.0, 0.84, 0.55); // gold-white, the hottest sparks
uniform vec3 core_gold : source_color = vec3(1.0, 0.5, 0.13);
group_uniforms;

group_uniforms skin;
uniform float chroma_speed : hint_range(0.0, 2.0) = 0.12;
uniform float chroma_scale = 5.5;
uniform float spot_scale = 34.0;
uniform float bump_amount : hint_range(0.0, 4.0) = 1.8;
uniform float roughness_base : hint_range(0.05, 1.0) = 0.38;
uniform float wrinkle_scale = 26.0;
uniform float papilla_scale = 62.0;
uniform float displace : hint_range(0.0, 0.03) = 0.007;  // design units the papillae and folds push the surface out
group_uniforms;

group_uniforms veins;
uniform float vein_scale = 9.0;
uniform float vein_width : hint_range(0.01, 0.5) = 0.05;
uniform float vein_energy = 0.16;
uniform float cell_scale = 24.0;
uniform float cell_energy = 0.0;
uniform float speck_scale = 58.0;
uniform float speck_energy = 3.2;
uniform float core_energy = 0.2;
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

// Folds: ridges stretched along the body (Z), so they ring the mantle and cross the trailing arms; deeper on the head and arm roots.
float folds(vec3 p, float u) {
	vec3 warp = vec3(vnoise(p * 7.0), vnoise(p * 7.0 + 13.0), 0.0) * 0.35;
	float r = ridge(vec3(p.x * wrinkle_scale * 0.6, p.y * wrinkle_scale * 0.6, p.z * wrinkle_scale * 1.25) + warp * 9.0);
	return pow(r, 3.0);
}

// Papillae: low round warts on a voronoi lattice; each fades out before its cell's edge (F2 - F1), so there are no seams.
float warts(vec3 p, float scale) {
	vec3 v = voronoi(p * scale);
	float r = 0.22 + 0.16 * fract(v.z * 7.0);
	float dome = 1.0 - smoothstep(0.0, r, v.x);
	return dome * dome * (3.0 - 2.0 * dome) * smoothstep(0.0, 0.18, v.y - v.x) * step(0.3, v.z);
}

void vertex() {
	rest = CUSTOM0;
	reg = COLOR;
	if (mode == 0 && reg.g < 0.01) {
		// coarse papillae and folds into the silhouette (fine ones are in the normal)
		float u = rest.w;
		float taper = mix(1.0, 0.35, smoothstep(0.45, 1.0, u));
		float h = warts(rest.xyz, 17.0) + 0.3 * vnoise(rest.xyz * 9.0);
		h *= taper * (1.0 - 0.6 * reg.a);  // the sucker side is smooth
		VERTEX += NORMAL * (h * displace * unit_m);
	}
}

void fragment() {
	vec3 P = rest.xyz;
	float u = rest.w;
	float ag = arm_glow_of(reg.b);
	float pulse_pos = max(mantle_pulse, 0.0);
	float lum_hurt = 1.0 - hurt * 0.5;
	float tp = vein_travel >= 0.0 && vein_travel <= 1.3 ? exp(-pow((u - vein_travel) * 6.5, 2.0)) * vein_travel_gain : 0.0;

	if (mode == 3) {
		// Eye: rest.xyz is the unit sphere position, +Z is the front. Small and dark: a bronze iris, a black horizontal slit.
		vec3 q = normalize(P);
		vec2 d = q.xy;
		float rad = length(d);
		float front = smoothstep(-0.05, 0.1, q.z);
		vec2 pp = vec2(d.x / 0.62, d.y / 0.12);
		float pup = 1.0 - smoothstep(0.8, 1.0, length(pp));
		float iris_mask = (1.0 - smoothstep(0.78, 0.9, rad)) * front;
		float ang = atan(d.y, d.x);
		float fib = 0.5 + 0.5 * sin(ang * 23.0 + vnoise(vec3(ang * 2.0, rad * 7.0, 1.0)) * 5.0);
		float inner = 1.0 - smoothstep(0.1, 0.75, rad);
		vec3 iris = mix(vec3(0.025, 0.012, 0.006), vec3(0.09, 0.045, 0.014), fib * 0.4 + inner * 0.2);
		iris = mix(iris, vec3(0.05, 0.015, 0.01), smoothstep(0.6, 0.82, rad));
		vec3 outer = mix(vec3(0.07, 0.02, 0.03), vec3(0.14, 0.04, 0.07), vnoise(P * 9.0));
		ALBEDO = mix(outer, iris, iris_mask) * (1.0 - pup);
		ROUGHNESS = mix(0.4, 0.03, iris_mask);
		SPECULAR = 0.9;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.02;
		float glint = (1.0 + charge * 2.5 + flash * 2.0);
		EMISSION = vec3(1.0, 0.4, 0.08) * eye_glow * 0.25 * glint * iris_mask * (1.0 - pup) * (0.3 + 0.7 * fib * inner) * glow * lum_hurt;
	} else if (mode == 2) {
		// Sucker: a pale, wet, fleshy rim, the cup darkening to a deep maroon pit; embers at the rim when the arm lights.
		float depth = reg.r;
		vec3 rim_c = vec3(0.7, 0.5, 0.47);
		vec3 wall = vec3(0.42, 0.2, 0.23);
		vec3 pit = vec3(0.16, 0.03, 0.06);
		vec3 c = mix(rim_c, wall, smoothstep(0.0, 0.25, depth));
		c = mix(c, pit, smoothstep(0.35, 1.0, depth));
		c *= 0.85 + 0.3 * vnoise(P * 140.0);
		ALBEDO = mix(c, c * vec3(0.8, 0.8, 1.0), chroma_shift * 0.3) * lum_hurt;
		ROUGHNESS = 0.22 + 0.25 * depth;
		SPECULAR = 0.6;
		CLEARCOAT = 0.6;
		CLEARCOAT_ROUGHNESS = 0.1;
		RIM = 0.2;
		RIM_TINT = 0.8;
		float breathe = 0.7 + 0.3 * sin(TIME * 1.4 + u * 9.0 + reg.b * 6.0);
		float e = sucker_glow * breathe + charge * 0.55 + flash * 0.7 + ag * 0.8;
		float rim_glow = 1.0 - smoothstep(0.0, 0.5, depth);
		EMISSION = mix(vein_hot, vein_white, clamp(charge * 0.6 + flash, 0.0, 1.0)) * (e + tp) * (0.25 + 0.75 * rim_glow) * glow * lum_hurt * 0.45;
	} else {
	// ---- skin (0) and web (1)
	bool web = mode == 1;
	float mantle_w = 1.0 - smoothstep(0.2, 0.42, u);
	float on_arm = smoothstep(0.43, 0.5, u);
	float oral = reg.a;
	// colour: wine to maroon-violet, mottled, darker in the folds, the papilla tips catching a paler pink
	float drift = fbm(P * chroma_scale + vec3(0.0, 0.0, TIME * chroma_speed));
	float tcol = clamp(0.35 + u * 0.35 + (drift - 0.5) * 0.9 + chroma_shift * 0.5, 0.0, 1.0);
	vec3 base = mix(copper, violet, smoothstep(0.15, 0.9, tcol));
	base = mix(base, deep_tone, smoothstep(0.5, 1.0, fbm(P * 3.0 + 4.0)) * 0.55);
	float fold = folds(P, u);
	float wart = warts(P, papilla_scale * mix(1.0, 1.6, on_arm));
	float wart_big = warts(P, 17.0);
	vec3 vor = voronoi(P * spot_scale);
	float breathe_spot = 0.18 + 0.06 * sin(TIME * 0.7 + vor.z * 6.283 + chroma_shift * 3.0);
	float spot = 1.0 - smoothstep(breathe_spot - 0.06, breathe_spot + 0.05, vor.x);
	base = mix(base, deep_tone, spot * 0.25 * (1.0 - oral));
	base *= 0.72 + 0.28 * (1.0 - fold * 0.9);                          // creases darker
	base = mix(base, base * vec3(1.6, 1.25, 1.3) + vec3(0.03, 0.0, 0.01), (wart * 0.4 + wart_big * 0.25) * (1.0 - oral));
	base = mix(base, belly_tone, oral * (web ? 0.25 : 0.5));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	base = mix(base, base * vec3(0.85, 0.85, 1.3), fres * 0.2);
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(lum) * vec3(1.1, 0.95, 0.95), hurt * 0.6);
	ALBEDO = base * lum_hurt;
	// wet: glossy with a thin clear film; the folds hold less shine
	ROUGHNESS = clamp(roughness_base + 0.18 * (drift - 0.5) + 0.12 * fold - 0.08 * wart, 0.08, 0.85);
	SPECULAR = 0.6;
	CLEARCOAT = web ? 0.15 : 0.3;
	CLEARCOAT_ROUGHNESS = 0.18;
	RIM = 0.35;
	RIM_TINT = 0.6;

	// relief: papillae, folds, pores
	float h = wart * 0.3 + wart_big * 0.5 + fold * 0.7 + vnoise(P * 170.0) * 0.18;
	h *= 1.0 - 0.6 * oral;
	NORMAL = bump_normal(NORMAL, VERTEX, h, 0.0016 * bump_amount);

	// ---- the glow: ember photophores sparkling under the skin, a gold core in the mantle, faint threads between
	float weight = reg.r * (web ? 0.7 : 1.0);
	float drive = 1.0 + stroke * 0.9 + charge * 0.8 + pulse_pos * 0.7 + tp * 2.2 + ag * 1.2 + flash * 1.0;
	// sparks: two voronoi layers; each cell's spark has its own size and twinkle
	float density = mix(0.52, 0.3, mantle_w) - 0.12 * on_arm * (1.0 - smoothstep(0.1, 0.6, oral)) + 0.15 * oral;
	vec3 s1 = voronoi(P * speck_scale + vec3(0.0, 0.0, 1.7));
	float r1 = (0.1 + 0.12 * fract(s1.z * 13.7)) * (1.0 + charge * 0.6 + stroke * 0.25);
	float tw1 = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * (1.2 + 3.0 * fract(s1.z * 7.3)) + s1.z * 40.0), 3.0);
	float sp1 = (1.0 - smoothstep(r1 * 0.35, r1, s1.x)) * step(density, s1.z) * tw1;
	vec3 s2 = voronoi(P * speck_scale * 2.3 + vec3(3.1, 0.0, 0.0));
	float r2 = 0.13 + 0.08 * fract(s2.z * 5.1);
	float tw2 = 0.4 + 0.6 * (0.5 + 0.5 * sin(TIME * (2.0 + 4.0 * fract(s2.z * 3.9)) + s2.z * 25.0));
	float sp2 = (1.0 - smoothstep(r2 * 0.3, r2, s2.x)) * step(density + 0.12, s2.z) * tw2 * 0.55;
	float sparks = (sp1 + sp2) * (1.0 - 0.6 * fold) * (1.0 - 0.5 * oral);
	vec3 spark_col = mix(vein_hot, vein_white, clamp(sp1 * 0.6 + charge * 0.4 + flash * 0.7 + tp * 0.4, 0.0, 1.0));
	vec3 emit = spark_col * sparks * speck_energy * weight * drive * (0.75 + 0.25 * (1.0 - fres));
	// faint glowing threads (what is left of the vein network): only really show on a stroke, the charge, a pulse
	vec3 warp = (vec3(vnoise(P * 5.0), vnoise(P * 5.0 + 11.0), vnoise(P * 5.0 + 23.0)) - 0.5) * 0.32;
	float w = vein_width * (1.0 + charge * 0.8 + stroke * 0.3 + pulse_pos * 0.2);
	float v1 = ridge(P * vein_scale + warp * vein_scale);
	float line = smoothstep(1.0 - w, 1.0, v1);
	float idle = 0.55 + 0.45 * sin(TIME * 1.1 + u * 6.0 + vnoise(P * 3.0) * 5.0);
	emit += vein_hot * line * vein_energy * weight * (0.4 + 0.6 * idle) * (0.3 + stroke * 0.9 + charge * 1.2 + tp * 1.5 + ag * 0.8 + pulse_pos * 0.5);

	// the mantle's gold core: glowing from within, strongest through the thick middle of the mantle, cells showing in it
	if (mantle_w > 0.02 && !web) {
		float thick = 1.0 - fres;
		float mottle = smoothstep(0.3, 0.85, fbm(P * 7.0 + vec3(0.0, TIME * 0.05, 0.0))) * 0.8 + 0.2;
		// brightest through the swollen middle of the mantle, fading to the head and the tip
		float mid = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.26, 0.42, u));
		float core_mask = mid * thick * thick * (1.0 - oral * 0.6);
		vec3 core = core_gold * core_energy * core_mask * mottle * (0.75 + 0.25 * idle) * (1.0 + stroke * 0.7 + pulse_pos * 0.9 + charge * 0.6 + tp * 0.8);
		vec3 cv = voronoi(P * cell_scale + vec3(0.0, 0.0, 3.0));
		float edge = 1.0 - smoothstep(0.0, 0.07, cv.y - cv.x);
		float cells = edge * core_mask * cell_energy * (0.6 + 0.4 * idle);
		emit += core + mix(core_gold, vein_white, 0.3) * cells * (1.0 + stroke * 0.6 + pulse_pos * 0.6 + charge * 0.4);
		emit *= 1.0 - 0.5 * fold;
	}
	emit += vec3(0.22, 0.06, 0.32) * fres * 0.08;
	EMISSION = emit * glow * lum_hurt;

	// translucent flesh: light through the thin webs and the mantle
	BACKLIGHT = vec3(0.4, 0.1, 0.08) * (web ? 1.3 : 0.5 * mantle_w + 0.15);
	// siphon interior and other cavities
	if (reg.g > 0.01) {
		ALBEDO = mix(ALBEDO, deep_tone * 0.5, reg.g);
		EMISSION *= 1.0 - reg.g;
	}
	}
}
