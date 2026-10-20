shader_type spatial;
// A boxfish's shell (BoxfishModel): `albedo` (the colour set_body_color()
// tints) armoured in hexagonal plates with sunken seams and raised centres (a
// bump on the normal), darker on the back and paler underneath, a wet clearcoat,
// and each species' markings on top:
//   0 a black-ringed white spot on every plate (yellow boxfish),
//   1 blue freckles (longhorn cowfish),
//   2 a white-dotted dark roof over gold-flecked flanks, a gold line between (spotted boxfish male),
//   3 blue scribbles (scrawled cowfish).
// The body mesh carries UV in metres (x along the surface, y round from the
// top) and COLOR (r plates, g lips, b fold: 0 the top to 1 the belly, a inside
// the mouth); all painted from the resting shape, so nothing slides as the tail
// stalk bends (fish_bend.gdshaderinc). `horn` draws a cowfish horn instead (a
// tube, UV.x root to tip).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.96, 0.8, 0.12, 1.0);
uniform bool horn = false;
uniform int pattern = 0;
uniform float plate_size = 0.09;  // m across a plate
uniform float back_shade = 0.8;  // the back's colour, of the flanks'
uniform vec4 belly_color : source_color = vec4(0.98, 0.88, 0.48, 1.0);
uniform float belly_mix = 0.6;
uniform vec4 seam_color : source_color = vec4(0.48, 0.35, 0.0, 1.0);
uniform float seam_strength = 0.45;
uniform vec4 mark_color : source_color = vec4(0.98, 0.98, 0.96, 1.0);
uniform vec4 mark_color2 : source_color = vec4(0.98, 0.98, 0.96, 1.0);
uniform vec4 ring_color : source_color = vec4(0.07, 0.07, 0.07, 1.0);
uniform vec4 lip_color : source_color = vec4(0.85, 0.54, 0.31, 1.0);
uniform float roof_line = 0.36;  // pattern 2: the fold the dark roof comes down to
uniform float plate_relief = 0.006;  // m, how far a plate's centre stands above its seams

varying vec2 sheet;
varying vec4 info;
varying vec3 rest;
varying float marks;  // 0 where the markings fade out (round the back of the shell)

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The hex plate `p` (in plates) is on: xy its offset from the plate's middle,
// z how far in from its edge (0 the seam, 0.5 the middle); `id` names it.
vec3 hex(vec2 p, out vec2 id) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	id = floor((p - gv) / h + 0.5);
	vec2 q = abs(gv);
	return vec3(gv, 0.5 - max(dot(q, normalize(r)), q.x));
}

// Round spots on a jittered grid of `cell` m, about `radius` of a cell across,
// one in a cell with `chance`: 0..1 coverage.
float dots(vec2 uv, float cell, float radius, float chance, float seed) {
	vec2 p = uv / cell;
	vec2 base = floor(p);
	float aa = length(fwidth(p)) * 0.7;
	float best = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 c = base + vec2(float(x), float(y));
			if (h21(c + seed) > chance) {
				continue;
			}
			vec2 centre = c + 0.5 + (vec2(h21(c + seed + 7.1), h21(c + seed + 3.3)) - 0.5) * 0.55;
			float r = radius * mix(0.7, 1.15, h21(c + seed + 1.7));
			best = max(best, 1.0 - smoothstep(r - aa, r + aa, length(p - centre)));
		}
	}
	return best;
}

// Wandering lines: where smooth noise crosses its middle, `width` thick.
float scribbles(vec2 uv, float scale, float width, float seed) {
	float n = skin_noise(vec3(uv / scale, seed)) * 0.75 + skin_noise(vec3(uv / scale * 2.3, seed + 5.0)) * 0.25;
	float d = abs(n - 0.5);
	float aa = fwidth(n);
	return 1.0 - smoothstep(width - aa, width + aa, d);
}

void vertex() {
	sheet = UV;
	info = horn ? vec4(0.0, 0.0, 0.3, 0.0) : COLOR;
	rest = VERTEX;
	marks = horn ? 0.0 : UV2.x;
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	float plates_on = info.r;
	float fold = info.b;
	vec3 color = albedo.rgb;
	float height = 0.0;
	float gloss = 0.0;
	if (horn) {
		// Bony horns: the shell's colour, paler and glossier toward the tip, ridged.
		color *= mix(back_shade, 1.15, sheet.x);
		color = mix(color, belly_color.rgb, 0.3 * sheet.x);
		height = 0.0006 * skin_noise(rest * 300.0) + 0.0008 * sin(sheet.x * 40.0);
		gloss = 0.5;
	} else {
		// Countershading: a darker back, a paler belly.
		color *= mix(back_shade, 1.0, smoothstep(0.06, 0.5, fold));
		color = mix(color, belly_color.rgb, belly_mix * smoothstep(0.62, 0.95, fold));
		vec2 id;
		vec3 cell = hex(sheet / plate_size, id);
		vec2 gv = cell.xy;
		float inside = cell.z;
		float aa = length(fwidth(sheet / plate_size));
		float seam = 1.0 - smoothstep(0.012, 0.045 + aa, inside);
		float tone = h21(id);
		float centre = smoothstep(0.1, 0.5, inside);
		// Each plate a touch different, brighter toward its raised middle.
		color *= 1.0 + plates_on * (0.12 * (tone - 0.5) + 0.1 * centre);
		float underside = smoothstep(0.7, 0.92, fold);
		vec3 plain = color;
		if (pattern == 0) {
			// A white spot ringed in black in the middle of (nearly) every plate.
			float present = step(tone, 0.92) * (1.0 - underside);
			float r = mix(0.12, 0.17, h21(id + 4.1));
			float d = length(gv + (vec2(h21(id + 2.3), h21(id + 5.7)) - 0.5) * 0.06);
			float aa_d = fwidth(d) * 1.2;
			float ring = 1.0 - smoothstep(r + 0.06 - aa_d, r + 0.06 + aa_d, d);
			float white = 1.0 - smoothstep(r - aa_d, r + aa_d, d);
			color = mix(color, ring_color.rgb, ring * present);
			color = mix(color, mark_color.rgb, white * present);
		} else if (pattern == 1) {
			// Blue freckles, bigger and fewer on the flanks, fading underneath.
			float big = dots(sheet, 0.042, 0.24, 0.8, 3.0);
			float small = dots(sheet, 0.026, 0.2, 0.55, 11.0);
			float fade = 1.0 - 0.7 * underside;
			color = mix(color, ring_color.rgb, 0.35 * dots(sheet, 0.042, 0.3, 0.8, 3.0) * fade);
			color = mix(color, mark_color.rgb, big * fade);
			color = mix(color, mark_color2.rgb, small * 0.9 * fade);
		} else if (pattern == 2) {
			// Gold-flecked blue flanks under a dark roof dotted white, split by a gold line.
			float line = roof_line + 0.012 * sin(sheet.x * 18.0);
			float aa_f = fwidth(fold);
			float roof = 1.0 - smoothstep(line - aa_f, line + aa_f, fold);
			float gold = dots(sheet, 0.036, 0.24, 0.85, 5.0) * (1.0 - underside * 0.6);
			color = mix(color, mark_color2.rgb, gold * (1.0 - roof));
			vec3 roof_color = ring_color.rgb * (0.85 + 0.3 * tone * plates_on);
			color = mix(color, roof_color, roof);
			float white = dots(sheet, 0.021, 0.27, 0.95, 9.0);
			color = mix(color, mark_color.rgb, white * roof);
			float seam_line = 1.0 - smoothstep(0.009 - aa_f, 0.009 + aa_f, abs(fold - line - 0.004));
			color = mix(color, mark_color2.rgb, seam_line);
		} else {
			// Electric-blue scribbles over olive, thinning out underneath.
			float lines = max(scribbles(sheet, 0.06, 0.022, 1.0), scribbles(sheet + 0.31, 0.1, 0.017, 7.0));
			float fade = 1.0 - 0.6 * underside;
			color = mix(color, ring_color.rgb, 0.3 * scribbles(sheet, 0.06, 0.04, 1.0) * fade);
			color = mix(color, mark_color.rgb, lines * fade);
		}
		color = mix(plain, color, marks);
		color = mix(color, seam_color.rgb, seam * seam_strength * plates_on);
		// The lips, and dark inside the mouth.
		color = mix(color, lip_color.rgb, info.g);
		color = mix(color, vec3(0.1, 0.03, 0.03), info.a);
		// Raised plates over sunken seams, and a fine grain all over.
		height = plates_on * plate_relief * (0.55 * smoothstep(0.0, 0.14, inside) + 0.45 * smoothstep(0.1, 0.5, inside));
		height += 0.00035 * skin_noise(rest * 420.0);
		gloss = plates_on * centre;
	}
	// Bump the normal by `height` (m), from its screen-space slope.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(height);
	float dhdy = dFdy(height);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ALBEDO = color;
	ROUGHNESS = mix(0.5, 0.28, gloss);
	SPECULAR = 0.55;
	CLEARCOAT = 0.7;
	CLEARCOAT_ROUGHNESS = 0.18;
	RIM = 0.25;
	RIM_TINT = 0.6;
	AO = 1.0 - 0.35 * (horn ? 0.0 : plates_on * (1.0 - smoothstep(0.0, 0.1, height / max(plate_relief, 1e-5))));
}
