shader_type spatial;
render_mode cull_disabled;
// The Lantern Angler (AnglerModel): a deep-sea anglerfish painted from its rest shape (BossMesh's channels) and bent along its
// swim path (spine_bend.gdshaderinc). One shader for every part, told apart by UV2.x:
//   0 body and jaw skin  - dark teal, wrinkle ridges lifted by a derivative bump, pale crests, wet sheen, rows of cyan photophores,
//                          the mouth's inside (palate, jaw floor) dark crimson-black with pale ridges;
//   1 / 7 fins           - ragged, ray-lined membranes torn between the rays (7: the pectorals, which flap and fan in the shader);
//   2 teeth              - glassy needles, clear toward the tips (the translucent copy of this shader, see AnglerModel);
//   3 filaments          - the illicium (extra >= 0: follows the spring chain) and the hair-like tufts (extra < 0);
//   4 inside             - tongue and throat flesh;
//   5 esca bulb          - the lantern: emissive, brightness from esca_intensity.
// The lower jaw (and its teeth and tongue) carry hinge weight 1 (CUSTOM0.x): `hinge` (y, z, rad) turns them (spine_hinge).
// `//@alpha` below is replaced by the alpha write in the teeth's copy so only that material blends.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform float k = 1.0;  // the body's scale over the 6 m design: patterns are painted in design metres
uniform vec4 skin_dark : source_color = vec4(0.045, 0.075, 0.085, 1.0);
uniform vec4 skin_pale : source_color = vec4(0.36, 0.5, 0.52, 1.0);
uniform vec4 belly_tint : source_color = vec4(0.16, 0.2, 0.22, 1.0);
uniform vec4 flesh_dark : source_color = vec4(0.07, 0.012, 0.02, 1.0);
uniform vec4 flesh_lit : source_color = vec4(0.34, 0.07, 0.09, 1.0);
uniform vec4 fin_color : source_color = vec4(0.07, 0.1, 0.12, 1.0);
uniform vec4 tooth_color : source_color = vec4(0.62, 0.7, 0.66, 1.0);
uniform vec4 photo_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec4 esca_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float esca_intensity = 1.0;
uniform float bump_strength = 0.9;

uniform vec4 mouth_line = vec4(0.0, 0.25, -0.297, 2.3);  // design m: the mouth line's y at z0 (x: y, y: z0), its slope dy/dz, where the mouth ends (w)
uniform float tail_from = 4.7;  // m, where the tail snap starts (its own scale)
uniform float tail_bend = 0.0;  // rad at the tip
uniform float pect_flap_l = 0.0;
uniform float pect_flap_r = 0.0;
uniform float pect_sweep = 0.0;
uniform vec3 pect_root = vec3(1.55, -0.2, 2.75);  // design m, the right fin's root (mirrored)
uniform vec3 stalk_rest[6];
uniform vec3 stalk_now[6];

uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;
uniform float glint = 1.0;

varying vec3 rest;
varying vec2 ring;
varying float part;
varying float along;
varying float extra;
varying float jaw;

vec3 chain_at(vec3 pts[6], float t) {
	float tt = clamp(t, 0.0, 1.0) * 5.0;
	int i = min(int(floor(tt)), 4);
	float f = tt - float(i);
	vec3 p0 = pts[max(i - 1, 0)];
	vec3 p1 = pts[i];
	vec3 p2 = pts[i + 1];
	vec3 p3 = pts[min(i + 2, 5)];
	float f2 = f * f;
	float f3 = f2 * f;
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3);
}

vec3 rot_about(vec3 v, vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	rest = VERTEX;
	ring = COLOR.rg * 2.0 - 1.0;
	part = UV2.x;
	along = COLOR.b;
	extra = COLOR.a;
	jaw = CUSTOM0.x;
	spine_hinge(VERTEX, NORMAL, CUSTOM0.x);
	if (part > 6.5) {
		// A pectoral fin: its tip turns about the fore-aft line through the root (flap), and fans back (sweep).
		float side = VERTEX.x >= 0.0 ? 1.0 : -1.0;
		vec3 root = vec3(side * pect_root.x, pect_root.y, pect_root.z) * k;
		float flap = (side > 0.0 ? pect_flap_r : pect_flap_l) * side;
		vec3 d = VERTEX - root;
		d = rot_about(d, vec3(0.0, 0.0, 1.0), flap);
		d = rot_about(d, vec3(0.0, 1.0, 0.0), -pect_sweep * side);
		VERTEX = root + d;
		NORMAL = rot_about(rot_about(NORMAL, vec3(0.0, 0.0, 1.0), flap), vec3(0.0, 1.0, 0.0), -pect_sweep * side);
	}
	if (tail_bend != 0.0 && VERTEX.z > tail_from) {
		float span = max(spine_length - tail_from, 0.001);
		float s = (VERTEX.z - tail_from);
		VERTEX.x += tail_bend * s * s / (2.0 * span);
		float slope = tail_bend * s / span;
		NORMAL = normalize(vec3(NORMAL.x + slope * NORMAL.z, NORMAL.y, NORMAL.z - slope * NORMAL.x));
	}
	if ((part > 2.5 && part < 3.5 || part > 4.5 && part < 5.5) && extra >= 0.0) {
		VERTEX += chain_at(stalk_now, extra) - chain_at(stalk_rest, extra);
	}
	spine_bend(VERTEX, NORMAL, UV2.y);
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

float ridged(vec3 p) {
	float n = skin_noise(p) * 0.6 + skin_noise(p * 2.3) * 0.3 + skin_noise(p * 5.1) * 0.1;
	return 1.0 - abs(2.0 * n - 1.0);
}

// Bio-luminescent photophores: small discs scattered over the surface, a denser lateral row, pulsing slowly. 0..1.
float photophores(vec3 p, float rowy) {
	vec3 c = p * 7.0;
	vec3 id = floor(c);
	vec3 f = fract(c) - 0.5;
	vec3 jit = vec3(skin_hash(id + 1.3), skin_hash(id + 5.1), skin_hash(id + 9.7)) - 0.5;
	float on = step(0.86, skin_hash(id + 3.0));
	float d = length(f - jit * 0.55);
	float disc = (1.0 - smoothstep(0.07, 0.13, d)) * on;
	float lat = (fract(p.z * 4.5) - 0.5);
	float row = 1.0 - smoothstep(0.1, 0.17, length(vec2(lat, (p.y - rowy) * 4.5)));
	row *= step(0.25, skin_hash(vec3(floor(p.z * 4.5), 2.0, 7.0)));
	float pulse = 0.6 + 0.4 * sin(TIME * 1.4 + skin_hash(id) * 40.0 + p.z * 2.0);
	return clamp(disc + row, 0.0, 1.0) * pulse;
}

// Screen-space bump: perturbs `n` by the height `h`'s slope across the screen.
vec3 bump(vec3 n, vec3 pos, float h, float strength) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - grad * strength);
}

void fragment() {
	bool inside_face = !FRONT_FACING;
	if (inside_face) {
		NORMAL = -NORMAL;
	}
	vec3 p = rest / k;
	if (dissolve > 0.0 && skin_noise(p * 3.0 + 5.0) < dissolve) {
		discard;
	}
	vec3 color = skin_dark.rgb;
	float rough = 0.6;
	float spec = 0.5;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	float ta = 1.0;
	float graze = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float height = 0.0;
	float clear = 0.0;
	float sss = 0.0;

	if (part < 0.5) {
		// Skin: dark, wrinkled, pale along the crests of the wrinkles and under the chin.
		float ridge = ridged(p * vec3(4.2, 5.0, 4.2) + vec3(1.0, 2.0, 3.0));
		float ridge2 = ridged(p * vec3(7.0, 6.0, 7.0) + 4.0);
		float broad = skin_fbm(p * 1.2);
		height = ridge * 0.55 + ridge2 * 0.25 + skin_fbm(p * 14.0) * 0.12;
		float crest = smoothstep(0.78, 0.99, ridge) * (0.35 + 0.65 * skin_noise(p * 2.5));
		color = skin_dark.rgb * mix(0.9, 1.2, broad);
		color = mix(color, skin_pale.rgb * 0.75, crest * 0.22);
		color = mix(color, belly_tint.rgb, smoothstep(0.1, -0.9, ring.y) * 0.65);
		// Warts and pale scars scattered on the head.
		float wart = smoothstep(0.9, 0.97, skin_noise(p * 11.0 + 2.0));
		color = mix(color, skin_pale.rgb * 0.8, wart * 0.35);
		height += wart * 0.6;
		rough = mix(0.5, 0.82, ridge) - 0.12 * (1.0 - broad);
		clear = 0.2;
		sss = 0.12;
		// Inside the mouth: the skull's underside above the mouth line and the jaw's floor (up-facing, near its lip).
		float line_y = mouth_line.x + (p.z - mouth_line.y) * mouth_line.z;
		float in_mouth = 1.0 - smoothstep(mouth_line.w - 0.35, mouth_line.w + 0.25, p.z);
		float palate = smoothstep(-0.3, -0.72, ring.y) * step(jaw, 0.5);
		float floor_m = smoothstep(0.55, 0.85, ring.y) * step(0.5, jaw);
		float inner = max(palate, floor_m) * in_mouth;
		if (inner > 0.0) {
			float fold = ridged(vec3(p.x * 3.0, p.z * 5.0, p.y * 2.0) + 7.0);
			vec3 fl = mix(flesh_dark.rgb, flesh_lit.rgb, smoothstep(0.5, 0.95, fold) * 0.9);
			fl *= mix(0.6, 1.2, skin_fbm(p * 4.0));
			color = mix(color, fl, inner);
			height = mix(height, fold * 0.7, inner);
			rough = mix(rough, 0.28, inner);
			sss = mix(sss, 0.4, inner);
			clear = mix(clear, 0.45, inner);
		}
		// The lips: a pale band along the mouth's edge.
		float lip = band(p.y - line_y, 0.09) * in_mouth * (1.0 - inner);
		color = mix(color, skin_pale.rgb, lip * 0.5);
		// Photophores along the lateral line and the chin.
		float ph = photophores(p, 0.1 + 0.15 * smoothstep(1.5, 3.5, p.z));
		ph *= (1.0 - inner) * smoothstep(0.1, 0.5, p.z);
		emit += photo_color.rgb * ph * 1.4;
		color = mix(color, photo_color.rgb * 0.5, ph * 0.5);
	} else if (part < 1.5 || part > 6.5) {
		// Fin membrane torn between the rays.
		float rays = part > 6.5 ? 15.0 : 22.0;
		float u = UV.x;
		float v = UV.y;
		float idx = floor(u * rays);
		float ray_len = 0.45 + 0.55 * skin_hash(vec3(idx, part, 3.0));
		float between = abs(fract(u * rays) - 0.5) * 2.0;
		float notch = smoothstep(0.55, 0.8, skin_noise(vec3(u * 5.5, 3.0, part))) * 0.5;
		float edge = ray_len * (0.86 + 0.14 * (1.0 - pow(between, 2.0))) * (1.0 - notch) + (skin_noise(vec3(u * 30.0, v * 6.0, part)) - 0.5) * 0.14;
		if (v > edge) {
			discard;
		}
		float ray = band(fract(u * rays) - 0.5, 0.09) * (0.55 + 0.45 * skin_noise(vec3(u * 9.0, v * 3.0, part)));
		float thin = smoothstep(0.5, 1.0, v / max(edge, 0.05));
		color = fin_color.rgb * mix(0.8, 1.6, skin_fbm(p * 3.0 + 1.0));
		color = mix(color, skin_pale.rgb * 0.9, ray * 0.6);
		emit += skin_pale.rgb * (0.04 + 0.06 * ray) * (1.0 - thin * 0.5);
		height = ray * 0.35;
		rough = 0.5;
		sss = 0.3;
		if (v < 0.04) {
			color = skin_dark.rgb;
		}
	} else if (part < 2.5) {
		// Needle teeth: glassy ivory, clear toward the tip, a cold glow in them.
		float tip = smoothstep(0.35, 1.0, along);
		float tt = UV.x;
		color = mix(tooth_color.rgb * 0.8, tooth_color.rgb, 0.5 + 0.5 * skin_noise(p * 40.0));
		ta = mix(0.95, 0.3, smoothstep(0.1, 1.0, tt));
		emit += photo_color.rgb * 0.05 * smoothstep(0.3, 1.0, tt) + vec3(0.4, 0.6, 0.6) * graze * 0.12;
		rough = 0.12;
		spec = 0.9;
		clear = 0.6;
		sss = 0.5;
	} else if (part < 3.5) {
		float t = UV.x;
		if (extra >= 0.0) {
			// The illicium: a gristly rod, paler and glowing toward the lantern.
			color = skin_dark.rgb * 1.5;
			color = mix(color, skin_pale.rgb * 0.8, smoothstep(0.55, 1.0, t) * 0.6);
			emit += esca_color.rgb * esca_intensity * smoothstep(0.65, 1.0, extra) * 0.35;
			rough = 0.4;
			clear = 0.4;
			float beads = band(fract(extra * 9.0 + skin_noise(vec3(extra * 20.0, 1.0, 2.0)) * 0.8) - 0.5, 0.05) * smoothstep(0.35, 0.8, skin_noise(vec3(extra * 11.0, 5.0, 1.0)));
			emit += photo_color.rgb * beads * 0.18 * (0.4 + 0.6 * esca_intensity);
		} else {
			// Hair-like tufts.
			color = mix(skin_dark.rgb * 2.4, skin_pale.rgb * 1.1, smoothstep(0.1, 1.0, t) * 0.85);
			emit += skin_pale.rgb * 0.05;
			rough = 0.55;
		}
	} else if (part < 4.5) {
		color = flesh_dark.rgb * mix(0.8, 2.0, skin_fbm(p * 5.0));
		color = mix(color, flesh_lit.rgb, 0.5 * skin_fbm(p * 9.0 + 3.0));
		height = skin_fbm(p * 12.0) * 0.4;
		rough = 0.25;
		clear = 0.5;
		sss = 0.45;
	} else {
		// The lantern: a translucent bulb lit from inside.
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float core = mix(0.7, 1.7, facing);
		float flick = 1.0 + 0.06 * sin(TIME * 7.0) + 0.04 * sin(TIME * 11.3);
		color = esca_color.rgb * 0.3 + vec3(0.1);
		emit = (esca_color.rgb * core + vec3(0.5) * graze) * esca_intensity * flick * 1.8;
		rough = 0.2;
		sss = 0.0;
	}

	if (part < 4.5 || (part > 5.5 && part < 6.5)) {
		vec3 n = NORMAL;
		if (bump_strength > 0.0 && height != 0.0) {
			n = bump(NORMAL, VERTEX, height * 0.05 * k, bump_strength);
		}
		NORMAL = n;
	}
	emit += skin_pale.rgb * graze * 0.07;
	color = mix(color, vec3(1.0, 0.3, 0.2), warn * 0.18);
	emit += vec3(1.0, 0.4, 0.3) * warn * 0.25 + vec3(flash);
	// The eyes' cold glint comes from the eye nodes; `glint` here only warms the rim a touch for the press flare.
	emit += photo_color.rgb * graze * (glint - 1.0) * 0.2;

	ALBEDO = color;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emit;
	CLEARCOAT = clear;
	CLEARCOAT_ROUGHNESS = 0.25;
	SSS_STRENGTH = sss;
	//@alpha
}
