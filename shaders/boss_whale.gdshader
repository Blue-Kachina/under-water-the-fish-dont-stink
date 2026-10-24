shader_type spatial;
render_mode cull_disabled;
// The Whale Fall's carcass (WhaleFallBoss): a dead blue whale on its side,
// eaten hollow. Painted from its rest shape (BossMesh's channels; not bent: it
// drifts as one piece).
// - Skin: a blue whale's slate blue-grey, mottled paler, sloughing away in
//   sheets to pale grey-pink blubber; scavenger bites (dark round pits); the
//   throat's pleats running back under the jaw.
// - Holes right through: both eye sockets, the chest torn open on one flank,
//   a wound on the other, the blowhole. Their rims are ragged blubber; inside
//   (the far wall's back faces) is dark red meat.
// - Ribs and spine (BONE): yellowed. Baleen (EXTRA): dark bristle plates.
// flash, rage and dissolve come from the boss.

#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 skin : source_color = vec4(0.17, 0.2, 0.24, 1.0);
uniform vec4 blubber : source_color = vec4(0.78, 0.7, 0.66, 1.0);
uniform vec4 meat : source_color = vec4(0.3, 0.04, 0.04, 1.0);
uniform vec4 bone : source_color = vec4(0.84, 0.78, 0.62, 1.0);
uniform vec4 cavity = vec4(19.0, 0.0, 5.0, 2.6);  // the chest: z, y (m), half length, half height, on +x
uniform vec4 wound = vec4(28.0, 0.3, 2.2, 1.6);  // on -x
uniform vec3 eye = vec3(9.0, -0.3, 0.95);  // z, y, radius (both sides)
uniform vec3 blowhole = vec3(7.5, 0.0, 0.8);  // z, x, radius (on top)
uniform float length_m = 45.0;
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float rage = 0.0;

varying vec3 rest;
varying vec2 ring;
varying float part;

void vertex() {
	rest = VERTEX;
	ring = COLOR.rg * 2.0 - 1.0;
	part = UV2.x;
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// How far inside a ragged hole `rest` is (> 0 inside), and its rim's band.
float hole(vec2 q, vec2 size, float seed) {
	float n = (skin_fbm(vec3(q * 0.9, seed)) - 0.5) * 0.45;
	return 1.0 - length(q / size) + n;
}

void fragment() {
	bool inside = !FRONT_FACING;
	if (inside) {
		NORMAL = -NORMAL;
	}
	if (dissolve > 0.0 && skin_noise(rest * 0.5 + 2.0) < dissolve) {
		discard;
	}
	vec3 color;
	float rough = 0.55;
	vec3 emit = vec3(0.0);
	float up = ring.y;
	float s = sign(rest.x + 1e-5);
	if (part < 0.5 || (part > 0.5 && part < 1.5)) {
		// The holes, and how near each rim.
		float h = -1.0;
		if (s > 0.0) {
			h = max(h, hole(vec2(rest.z - cavity.x, rest.y - cavity.y), cavity.zw, 1.0));
		} else {
			h = max(h, hole(vec2(rest.z - wound.x, rest.y - wound.y), wound.zw, 2.0));
		}
		h = max(h, mix(-1.0, hole(vec2(rest.z - eye.x, rest.y - eye.y), vec2(eye.z), 3.0 + s), step(0.3, abs(ring.x))));
		h = max(h, mix(-1.0, hole(vec2(rest.z - blowhole.x, rest.x - blowhole.y), vec2(blowhole.z), 4.0), step(0.6, up)));
		if (h > 0.0 && part < 0.5) {
			discard;
		}
		// Slate blue-grey, mottled paler, belly a little lighter.
		float mott = skin_fbm(vec3(rest.z * 0.35, rest.y * 0.5, rest.x * 0.5));
		color = mix(skin.rgb * 0.7, skin.rgb * 1.2, smoothstep(0.42, 0.62, mott));
		color = mix(color, skin.rgb * 1.5, smoothstep(-0.3, -0.8, up) * 0.4);
		// The throat's pleats.
		float throat = (1.0 - smoothstep(0.32 * length_m, 0.45 * length_m, rest.z)) * smoothstep(-0.2, -0.6, up);
		float pleat = band(fract(atan(rest.x, -rest.y) * 9.0) - 0.5, 0.12);
		color = mix(color, color * 0.55, pleat * throat * 0.8);
		// Skin sloughing away to blubber.
		float rot = skin_fbm(vec3(rest.z * 0.34, rest.y * 0.6, rest.x * 0.6 + 5.0)) * 0.85 + skin_noise(rest * 1.7) * 0.15;
		float off = smoothstep(0.62, 0.64, rot);
		float edge = band(rot - 0.63, 0.01);
		vec3 fat = blubber.rgb * mix(0.8, 1.05, skin_fbm(rest * 1.6));
		fat = mix(fat, vec3(0.62, 0.48, 0.45), skin_noise(rest * 0.7) * 0.5);
		color = mix(color, fat, off);
		color = mix(color, vec3(0.92, 0.9, 0.86), edge * 0.7);
		rough = mix(0.45, 0.8, off);
		// Scavenger bites: dark round pits.
		vec2 cell = vec2(rest.z, atan(rest.x, rest.y) * 3.5) / 1.8;
		vec2 id = floor(cell);
		vec2 f = fract(cell) - 0.5;
		float pit = step(0.82, skin_hash(vec3(id, 1.0))) * (1.0 - smoothstep(0.12, 0.2, length(f)));
		color = mix(color, meat.rgb * 0.6, pit);
		// Ragged blubber round every hole.
		float rim = smoothstep(-0.25, 0.0, h);
		color = mix(color, mix(blubber.rgb, vec3(0.65, 0.25, 0.25), 0.4), rim * 0.85);
		// The mouth line.
		float mouth = band(rest.y - (-0.25 + 0.05 * sin(rest.z * 0.2)) * 1.0, 0.06) * (1.0 - smoothstep(0.24 * length_m, 0.28 * length_m, rest.z));
		color = mix(color, vec3(0.05, 0.04, 0.05), mouth * 0.8);
		if (inside) {
			// The far wall, seen through a hole: dark red meat, fibrous.
			color = meat.rgb * mix(0.5, 1.2, skin_fbm(vec3(rest.z * 0.8, rest.y * 2.5, rest.x)));
			color = mix(color, meat.rgb * 1.8, band(fract(rest.z * 1.3 + skin_noise(rest) * 0.5) - 0.5, 0.08) * 0.4);
			rough = 0.2;
		}
	} else if (part < 2.5) {
		color = bone.rgb * mix(0.75, 1.0, skin_fbm(rest * 3.0));
		color = mix(color, meat.rgb, smoothstep(0.55, 0.75, skin_noise(rest * 1.5)) * 0.5);  // shreds of meat still on it
		rough = 0.5;
	} else {
		// Baleen: dark bristle plates.
		color = mix(vec3(0.08, 0.08, 0.08), vec3(0.3, 0.28, 0.24), band(fract(UV.x * 120.0) - 0.5, 0.2)) * mix(0.8, 1.1, UV.y);
		rough = 0.6;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	EMISSION = emit + vec3(1.0, 0.4, 0.35) * flash * 0.5 + vec3(0.5, 0.02, 0.02) * rage * 0.2;
}
