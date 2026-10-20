shader_type spatial;
// A koi's skin (KoiModel): one of four classic varieties painted on one body,
// from the rest shape so nothing slides as it bends. `albedo` (the colour
// set_body_color() tints) is each variety's main colour, so a tinted koi reads
// as its team's while its other markings stay:
//   0 Kohaku: snow white, crisp hi patches (albedo) over the back and a head patch;
//   1 Showa: sumi black, hi (albedo) and white patches, black wrapping the belly;
//   2 Yamabuki Ogon: metallic gold (albedo), every scale catching the light;
//   3 Asagi: blue-grey back (albedo) netted pale, orange cheeks and belly.
// The mesh (KoiModel._body_mesh) gives UV.x nose (0) to tail stalk (1), the
// mouth and lips below 0; UV.y round it from the belly (0, the back at 0.5);
// UV2 big overlapping scales: x scales back along it, y rows round it.

#include "res://shaders/fish_bend.gdshaderinc"
#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.85, 0.19, 0.12, 1.0);
uniform int variety = 0;
uniform vec4 base_color : source_color = vec4(0.965, 0.955, 0.93, 1.0);
uniform vec4 second_color : source_color = vec4(0.95, 0.94, 0.91, 1.0);
uniform vec4 third_color : source_color = vec4(0.05, 0.045, 0.04, 1.0);
uniform vec4 lip_color : source_color = vec4(0.97, 0.86, 0.8, 1.0);
uniform vec4 mouth_color : source_color = vec4(0.3, 0.08, 0.08, 1.0);
uniform float seed = 3.0;
uniform float gill_t = 0.215;  // UV.x of the gill cover's edge (at the top and bottom)
uniform float scales_t = 0.235;  // UV.x the scales start at
uniform float rows_around = 26.0;  // UV2.y round the whole body
uniform vec3 eye_at = vec3(0.06, 0.03, -0.5);  // the right eye's middle (m, at rest)
uniform float eye_radius = 0.025;
uniform vec3 nostril = vec3(0.045, 0.02, -0.56);  // the right nostril (m, at rest)

varying vec3 rest;
varying vec3 v_along;
varying vec3 v_around;

void vertex() {
	rest = VERTEX;
	float a = PI + TAU * UV.y;
	vec3 around = vec3(cos(a), -sin(a), 0.0);
	vec3 along = vec3(0.0, 0.0, 1.0);
	vec3 at = VERTEX;
	fish_bend(at, around);
	at = VERTEX;
	fish_bend(at, along);
	v_along = along;
	v_around = around;
	fish_bend(VERTEX, NORMAL);
}

// The scale on top at scale coordinates `p` (UV2): each scale's front is tucked
// under the free back edge of the one ahead of it. xy: the offset from its
// middle (of its radius); z: how far out (0 middle, 1 its edge); w: random.
vec4 koi_scale(vec2 p) {
	float radius = 0.72;
	float c0 = floor(p.x);
	for (int k = -1; k <= 0; k++) {
		float c = c0 + float(k);
		float off = 0.5 * mod(c, 2.0);
		float row = floor(p.y - off) + 0.5 + off;
		vec2 d = (p - vec2(c + 0.5, row)) / radius;
		if (k == 0 || dot(d, d) < 1.0) {
			return vec4(d, length(d), skin_hash(vec3(c * 1.37, mod(row, rows_around) * 2.11, 7.0)));
		}
	}
	return vec4(0.0);
}

// How far inside a patch spanning UV.x `a` to `b` above `low` (in `up`) a point
// is, in about metres: + inside, - outside.
float koi_window(float t, float up, float a, float b, float low) {
	return min(min(t - a, b - t), (up - low) * 0.25);
}

// How far inside an oval patch centred `c` along the body, `half_len` long
// either way, reaching `reach` down from the back (in `up`) a point is, in
// about metres: + inside.
float koi_blob(float t, float up, float c, float half_len, float reach) {
	return (1.0 - length(vec2((t - c) / half_len, (1.0 - up) / reach))) * half_len;
}

// A crisp edge on a field (+ inside), anti-aliased.
float koi_crisp(float f) {
	float a = max(fwidth(f), 1e-5);
	return smoothstep(-a, a, f);
}

void fragment() {
	float t = UV.x;
	float up = -cos(TAU * UV.y);  // -1 the belly, 1 the back
	vec4 sc = koi_scale(UV2);
	vec2 centre = UV2 - sc.xy * 0.72;
	float scaled = smoothstep(scales_t, scales_t + 0.03, t);
	float rim_aa = fwidth(sc.z);
	float rim = smoothstep(0.84 - rim_aa, 0.96 + rim_aa, sc.z) * scaled;  // a scale's free edge
	float under = (1.0 - smoothstep(-0.56, -0.15, sc.x)) * scaled;  // its front, in the shade of the one ahead
	float n1 = skin_fbm(rest * 5.0 + seed);
	float n2 = skin_fbm(rest * 8.0 + seed * 1.7 + 4.0);
	float n3 = skin_fbm(rest * 4.0 + seed * 0.6 + 21.0);
	float grain = skin_fbm(rest * 70.0);
	float warp = skin_fbm(rest * 2.2 + seed * 0.3 + 9.0) - 0.5;
	float tw = t + (n1 - 0.5) * 0.16 + warp * 0.14 * up;
	float uw = up + (n2 - 0.5) * 0.7 + warp * 0.6;
	float gill_edge = gill_t + 0.04 * (1.0 - up * up);
	float head = 1.0 - smoothstep(gill_edge - 0.004, gill_edge + 0.004, t);
	vec3 col;
	float metal = 0.0;
	float rough = 0.3;
	float dome = 0.13;
	vec2 sparkle = vec2(0.0);
	float rim_tint = 0.25;
	vec3 lips = lip_color.rgb;
	if (variety == 0) {
		// Kohaku: hi in steps along the back, never below the lateral line, a
		// clean white head with a round hi on its crown, and white before the tail.
		float f = max(koi_blob(tw, uw, 0.39, 0.15, 1.05), koi_blob(tw, uw, 0.715, 0.12, 0.85));
		f = min(f, (uw + 0.05) * 0.25);  // never below the lateral line
		f = min(f, t - 0.24);
		float crown = (1.0 - length(vec2((t + (n1 - 0.5) * 0.03 - 0.115) / 0.05, (1.0 - up - (n2 - 0.5) * 0.2) / 0.52))) * 0.05;
		f = max(f, crown);
		f += (0.6 - sc.z) * 0.018 * scaled;  // the patch's edge follows the scales (kiwa)
		float hi = koi_crisp(f);
		col = mix(base_color.rgb, albedo.rgb, hi);
		col *= mix(1.0, mix(0.93, 0.84, hi), rim);
		col *= mix(1.0, 0.95, under);
	} else if (variety == 1) {
		// Showa: sumi black, hi over the back and head, white patches on the
		// flanks, black wrapping round the body and the belly, and a black
		// lightning bolt across the face (menware).
		float white = (n3 - 0.5) * 0.22 + 0.012 - max(abs(uw + 0.05) - 0.55, 0.0) * 0.25;
		white = min(white, t - 0.25);
		float red = max(max(koi_window(tw, uw, 0.235, 0.5, -0.1), koi_window(tw, uw, 0.56, 0.8, 0.05)),
				koi_window(tw, uw, 0.02, gill_t, 0.05));
		float q = tw * 3.3 + uw * 0.2 + (n1 - 0.5) * 0.6;
		float wraps = (0.11 - abs(fract(q) - 0.5)) * 0.25;
		wraps = min(wraps, t - 0.24);
		float belly = (-0.5 - uw) * 0.25;
		float bolt = (0.016 - abs(tw - 0.05 - 0.075 * (1.0 - uw))) * step(-0.1, up);
		float snout = 0.035 - tw;
		float sumi = max(max(wraps, belly), max(bolt, snout));
		col = third_color.rgb;
		col = mix(col, second_color.rgb, koi_crisp(white));
		float hi = koi_crisp(red + (0.6 - sc.z) * 0.018 * scaled);
		col = mix(col, albedo.rgb, hi);
		float black = koi_crisp(sumi);
		col = mix(col, third_color.rgb, black);
		float dark = 1.0 - smoothstep(0.1, 0.3, dot(col, vec3(0.33)));
		col = mix(col * mix(1.0, 0.82, rim) * mix(1.0, 0.9, under), col + vec3(0.07, 0.075, 0.08) * rim, dark);
		lips = mix(lips, third_color.rgb * 2.0, 0.6);
	} else if (variety == 2) {
		// Yamabuki Ogon: all-over metallic gold, darker down the back and
		// palest high on the flank, every scale tilted to catch the light.
		vec3 gold = albedo.rgb;
		vec3 pale = mix(gold, vec3(1.0, 0.95, 0.72) * max(max(gold.r, gold.g), gold.b), 0.45);
		col = mix(gold * 0.66, gold, smoothstep(1.0, 0.5, up));
		col = mix(col, pale, smoothstep(0.5, 0.2, up) * smoothstep(-0.3, 0.0, up) * 0.7);
		col = mix(col, gold * 0.92, smoothstep(-0.45, -0.9, up));
		col = mix(col, pale, rim * 0.65);
		col *= mix(1.0, 0.8, under);
		metal = 0.4;
		rough = mix(0.16, 0.36, sc.w) * scaled + 0.22 * (1.0 - scaled);
		sparkle = (vec2(sc.w, fract(sc.w * 7.31)) - 0.5) * 0.3 * scaled;
		dome = 0.17;
		rim_tint = 0.9;
		lips = mix(gold, pale, 0.4);
	} else {
		// Asagi: a blue-grey back netted pale (each scale's edge), paling down
		// the flanks, a clean pale head, and orange cheeks and belly.
		vec3 blue = albedo.rgb;
		vec3 pale = third_color.rgb;
		col = mix(blue * 0.6, blue, smoothstep(1.0, 0.35, up));
		col = mix(col, pale, smoothstep(0.3, -0.25, uw));
		float net = smoothstep(0.66, 0.9, sc.z) * scaled * smoothstep(-0.45, 0.1, up);
		col *= mix(1.0, 1.12, 1.0 - sc.z);  // each scale a touch lighter in its middle
		col = mix(col, vec3(0.88, 0.92, 0.95), net * 0.75);
		col *= mix(1.0, 0.86, under);
		float clean = 1.0 - smoothstep(gill_edge - 0.01, gill_edge + 0.05 + (n1 - 0.5) * 0.06, t);
		col = mix(col, mix(pale, vec3(1.0), 0.3), clean * smoothstep(0.0, 0.4, up));
		float belly = (-0.38 - uw) * 0.25;
		float cheek = min(gill_edge - t, (0.25 - uw) * 0.25);
		cheek = min(cheek, t - 0.03);
		float orange = koi_crisp(max(belly, cheek) + (0.6 - sc.z) * 0.012 * scaled);
		col = mix(col, second_color.rgb * mix(1.0, 0.82, rim) * mix(1.0, 0.92, under), orange);
		lips = mix(lips, pale, 0.5);
	}
	// The head: no scales, wet smooth skin; the gill cover's edge and a fainter
	// line in front of it; the eye set in a soft socket; two nostrils.
	float gill_line = (1.0 - smoothstep(0.0, 0.006, abs(t - gill_edge + 0.002))) * smoothstep(0.78, 0.6, up) * smoothstep(-0.95, -0.8, up);
	float behind = smoothstep(0.0, 0.004, t - gill_edge) * (1.0 - smoothstep(0.004, 0.035, t - gill_edge)) * smoothstep(0.78, 0.6, up) * smoothstep(-0.95, -0.8, up);
	float pre_edge = gill_t - 0.05 + 0.02 * (1.0 - up * up);
	float pre_line = (1.0 - smoothstep(0.0, 0.004, abs(t - pre_edge))) * smoothstep(0.35, 0.1, up) * smoothstep(-0.8, -0.6, up);
	col *= 1.0 - 0.32 * gill_line - 0.06 * behind - 0.08 * pre_line;
	vec3 mirrored = vec3(abs(rest.x), rest.yz);
	float eye_d = length(mirrored - eye_at);
	col *= mix(0.72, 1.0, smoothstep(eye_radius * 0.9, eye_radius * 1.5, eye_d));
	float nose_d = min(length(mirrored - nostril), length(mirrored - nostril - vec3(-0.004, 0.006, 0.012)));
	col *= mix(0.25, 1.0, smoothstep(0.004, 0.0065, nose_d));
	// The lateral line: a pore on each scale along the middle of the flank.
	float lateral = min(abs(centre.y - rows_around * 0.25), abs(centre.y - rows_around * 0.75));
	float pore = (1.0 - smoothstep(0.12, 0.24, length(sc.xy))) * step(lateral, 0.5) * scaled * step(0.3, sc.w + 0.5);
	col *= 1.0 - 0.15 * pore;
	col *= 0.95 + 0.09 * grain;
	// The lips, and the mouth inside them.
	float lip = smoothstep(0.0, -0.03, t);
	col = mix(col, lips, lip);
	float inside = smoothstep(-0.25, -0.55, t);
	col = mix(col, mouth_color.rgb * mix(1.0, 0.25, smoothstep(-0.6, -1.0, t)), inside);
	metal *= 1.0 - inside;
	// Each scale bulges a little and lifts toward its free edge.
	vec3 tangent = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(v_along, 0.0)).xyz);
	vec3 binormal = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(v_around, 0.0)).xyz);
	vec2 tilt = (sc.xy * dome + vec2(-0.08, 0.0)) * scaled + sparkle;
	tilt.x += 0.16 * (1.0 - smoothstep(0.0, 0.012, gill_edge - t)) * head * smoothstep(0.78, 0.6, up) * smoothstep(-0.95, -0.8, up);
	tilt.x -= 0.06 * behind;
	tilt *= 1.0 - lip;
	NORMAL = normalize(NORMAL + tangent * tilt.x + binormal * tilt.y);
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = mix(rough, 0.45, inside);
	SPECULAR = 0.55;
	CLEARCOAT = 0.45 * (1.0 - inside);
	CLEARCOAT_ROUGHNESS = 0.2;
	RIM = 0.25;
	RIM_TINT = rim_tint;
}
