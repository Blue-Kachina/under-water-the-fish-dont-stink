shader_type spatial;
render_mode cull_disabled;
// The Gulper Mother (GulperBoss): a giant gulper eel, almost all mouth. Painted
// from its rest shape (BossMesh's channels), bent along its swim path
// (spine_bend.gdshaderinc), its mouth opening by `gape`.
// - Body: velvet black with a faint violet sheen, scattered pale photophores
//   along its flanks. Behind the head its belly is stretched thin: dark red,
//   lit from within, veined, and the shapes of what it swallowed press out of
//   it (more as it fills: `fullness`), twitching.
// - The pouch (EXTRA): black skin wrinkled across, raw throat-flesh inside.
// - Jaws (EXTRA2): black. Teeth (BONE): glassy needles. The tail (FILAMENT):
//   black, its photophores reddening to the lure.
// flash, warn, rage and dissolve come from the boss.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform vec4 skin : source_color = vec4(0.03, 0.028, 0.035, 1.0);
uniform vec4 sheen : source_color = vec4(0.16, 0.1, 0.24, 1.0);
uniform vec4 throat : source_color = vec4(0.32, 0.03, 0.06, 1.0);
uniform vec4 belly_glow : source_color = vec4(0.55, 0.06, 0.12, 1.0);
uniform float mouth_len = 17.0;  // m, the pouch's length (the hinge)
uniform float rim_y = -3.2;  // m, the mouth's middle at its rim, and at the hinge
uniform float hinge_y = 0.0;
uniform float gape = 0.0;  // 0 shut-ish, 1 wide open
uniform vec2 belly_span = vec2(17.0, 35.0);  // m along the body
uniform float fullness = 0.3;
// A swallowed player: a lump at rest z lump.x (m), lump.y m long, pressing out
// by lump.z (of the girth there); 0: none.
uniform vec3 lump = vec3(0.0, 4.0, 0.0);
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;
uniform float rage = 0.0;

varying vec3 rest;
varying vec2 ring;
varying float part;
varying float along;

void vertex() {
	rest = VERTEX;
	ring = COLOR.rg * 2.0 - 1.0;
	part = UV2.x;
	along = COLOR.b;
	vec3 v = VERTEX;
	// The mouth opens: the pouch, its jaws and their teeth spread from the hinge.
	bool opens = (part > 1.5 && part < 2.5) || (part > 3.5 && part < 4.5) || part > 5.5;
	if (opens && v.z < mouth_len) {
		float m = 1.0 - clamp(v.z / mouth_len, 0.0, 1.0);
		float cy = mix(rim_y, hinge_y, v.z / mouth_len);
		v.x *= 1.0 + gape * 0.45 * m;
		v.y = cy + (v.y - cy) * (1.0 + gape * 0.55 * m);
		v.y += gape * m * m * -1.5;
	}
	if (lump.z > 0.0 && part < 0.5) {
		float d = (v.z - lump.x) / max(lump.y, 0.01);
		float b = lump.z * exp(-d * d * 2.0);
		v.x *= 1.0 + b;
		v.y *= 1.0 + b * 1.2;
	}
	VERTEX = v;
	spine_bend(VERTEX, NORMAL, UV2.y);
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// A swallowed fish's shape pressing out of the belly, in (along, round) m.
float swallowed(vec2 q, float size) {
	float body = length(q / vec2(size, size * 0.38)) - 1.0;
	vec2 t = q - vec2(size * 1.15, 0.0);
	float tail = max(abs(t.y) - (t.x + 0.1) * 0.7, abs(t.x) - size * 0.35);
	return min(body * size * 0.38, tail);
}

void fragment() {
	bool inside = !FRONT_FACING;
	if (inside) {
		NORMAL = -NORMAL;
	}
	if (dissolve > 0.0 && skin_noise(rest * 0.7 + 5.0) < dissolve) {
		discard;
	}
	vec3 color = skin.rgb;
	float rough = 0.8;
	vec3 emit = vec3(0.0);
	float up = ring.y;
	float graze = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	if (part < 0.5 || part > 4.5) {
		color = skin.rgb * mix(0.8, 1.2, skin_fbm(rest * 1.3));
		color += sheen.rgb * graze * 0.6;
		// Pale photophores scattered along the flanks.
		vec2 cell = vec2(rest.z, atan(rest.x, rest.y) * 2.5) / 1.4;
		vec2 id = floor(cell);
		vec2 f = fract(cell) - 0.5;
		float dot_on = step(0.8, skin_hash(vec3(id, 3.0))) * (1.0 - smoothstep(0.05, 0.1, length(f)));
		dot_on *= smoothstep(0.7, 0.2, abs(up));
		emit += vec3(0.6, 0.85, 1.0) * dot_on * 1.4;
		// The stretched belly: thin, lit from within, the swallowed pressing out.
		float in_belly = smoothstep(belly_span.x, belly_span.x + 3.0, rest.z) * (1.0 - smoothstep(belly_span.y - 3.0, belly_span.y, rest.z));
		in_belly *= smoothstep(0.35, -0.1, up);
		if (in_belly > 0.0) {
			vec2 q = vec2(rest.z, atan(rest.x, -rest.y) * 3.2);
			float vein = band(skin_fbm(vec3(q * 0.45, 1.0)) - 0.5, 0.02);
			vec3 thin = mix(throat.rgb * 0.45, belly_glow.rgb * 0.7, 0.3 + 0.3 * skin_fbm(vec3(q * 0.3, 2.0)));
			float shapes = 0.0;
			float bones = 0.0;
			for (int n = 0; n < 6; n++) {
				float fn = float(n);
				if (fn > fullness * 6.0 + 0.5) break;
				vec2 at = vec2(mix(belly_span.x + 3.0, belly_span.y - 3.0, skin_hash(vec3(fn, 1.0, 2.0))), (skin_hash(vec3(fn, 4.0, 1.0)) - 0.5) * 6.0);
				at += vec2(sin(TIME * 0.7 + fn * 2.0), cos(TIME * 1.1 + fn)) * 0.25;
				float ang = (skin_hash(vec3(fn, 9.0, 3.0)) - 0.5) * 1.2;
				vec2 d = q - at;
				d = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * d;
				float size = mix(1.4, 2.6, skin_hash(vec3(fn, 2.0, 7.0)));
				float sd = swallowed(d, size);
				shapes = max(shapes, 1.0 - smoothstep(-0.05, 0.25, sd));
				bones = max(bones, band(d.y, 0.05) * step(sd, 0.0) + band(fract(d.x * 1.6) - 0.5, 0.06) * step(sd, -0.1));
			}
			thin = mix(thin, thin * 0.25, shapes);
			thin = mix(thin, vec3(0.75, 0.62, 0.55), bones * 0.6);
			thin = mix(thin, throat.rgb * 0.3, vein * 0.8);
			color = mix(color, thin, in_belly);
			emit += belly_glow.rgb * in_belly * (0.1 + 0.08 * (1.0 - shapes)) * (1.0 + fullness);
			rough = mix(rough, 0.15, in_belly);
		}
	} else if (part < 1.5) {
		color = skin.rgb * 1.6;
		rough = 0.6;
	} else if (part < 2.5) {
		color = vec3(0.82, 0.84, 0.82);
		rough = 0.12;
		emit = vec3(0.8, 0.9, 1.0) * 0.08;
	} else if (part < 3.5) {
		color = skin.rgb;
		float tip = smoothstep(0.85, 1.0, along);
		vec2 cell = vec2(rest.z * 1.5, 0.0);
		float dot_on = step(0.6, skin_hash(vec3(floor(cell), 5.0))) * band(fract(cell.x) - 0.5, 0.12);
		emit = vec3(1.0, 0.25, 0.4) * dot_on * 1.6 * tip;
	} else if (part < 4.5) {
		// The pouch: wrinkled black skin outside, raw throat inside.
		float wrinkle = band(fract(rest.z * 1.2 + skin_noise(rest * 0.8) * 0.8) - 0.5, 0.12);
		color = mix(skin.rgb * 1.3, skin.rgb * 0.6, wrinkle);
		color += sheen.rgb * graze * 0.5;
		if (inside) {
			color = mix(throat.rgb, throat.rgb * 0.25, smoothstep(0.0, 1.0, UV.x)) * mix(0.7, 1.15, skin_fbm(rest * 2.0));
			color = mix(color, throat.rgb * 1.8, band(fract(UV.y * 18.0) - 0.5, 0.06) * 0.4);
			rough = 0.12;
			emit = throat.rgb * 0.1;
		}
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
	EMISSION = emit + vec3(1.0, 0.4, 0.35) * flash * 0.8 + vec3(1.0, 0.05, 0.05) * warn * 2.5 + vec3(0.6, 0.02, 0.1) * rage * 0.3;
}
