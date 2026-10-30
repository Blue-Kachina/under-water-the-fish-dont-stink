shader_type spatial;
render_mode cull_disabled;
// The King of Herrings (BloodLeviathan): a giant oarfish weeks dead. Painted
// from its rest shape (BossMesh's channels) and bent along its swim path
// (spine_bend.gdshaderinc).
// - Body: wet silver, a blue-grey back, the oarfish's oblique dark streaks and
//   spots, a pink-blue sheen at grazing angles. Skin peels away in patches
//   (dull grey-pink flesh under ragged pale edges), with round lamprey bite
//   scars, and three flayed wounds whose red flesh shows the ribs.
// - Fin and crest: torn crimson membrane with paler rays, filaments darker
//   toward their tips. Teeth: yellowed bone. The jaw: silver below, raw
//   mouth-flesh above.
// flash (hits), warn (winding up), rage (enraged) and dissolve (dying) come from the boss.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform vec4 back_color : source_color = vec4(0.22, 0.27, 0.33, 1.0);
uniform vec4 silver : source_color = vec4(0.78, 0.8, 0.82, 1.0);
uniform vec4 belly : source_color = vec4(0.9, 0.9, 0.88, 1.0);
uniform vec4 streak_color : source_color = vec4(0.12, 0.15, 0.2, 1.0);
uniform vec4 flesh : source_color = vec4(0.55, 0.36, 0.36, 1.0);
uniform vec4 wound : source_color = vec4(0.32, 0.03, 0.05, 1.0);
uniform vec4 fin_color : source_color = vec4(0.62, 0.05, 0.09, 1.0);
uniform vec4 bone : source_color = vec4(0.86, 0.8, 0.66, 1.0);
uniform float peel = 0.68;  // more: less skin peeled
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;
uniform float rage = 0.0;
uniform vec3 eye_at = vec3(1.0, 1.6, 3.0);  // m, the right eye (mirrored)
uniform float eye_ring = 1.1;
uniform float girth = 4.8;  // m, the deepest half height (scales the patterns)

varying vec3 rest;
varying vec2 ring;
varying float part;
varying float along;

void vertex() {
	rest = VERTEX;
	ring = COLOR.rg * 2.0 - 1.0;
	part = UV2.x;
	along = COLOR.b;
	spine_hinge(VERTEX, NORMAL, CUSTOM0.x);
	spine_bend(VERTEX, NORMAL, UV2.y);
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// A flayed wound centred (z, y) on side `s`, `size` (z, y half extents).
float gash(vec3 p, float s, vec2 at, vec2 size, float side) {
	if (s * side < 0.0) return 0.0;
	vec2 q = (vec2(p.z, p.y) - at) / size;
	float n = (skin_fbm(vec3(p.z * 0.9, p.y * 0.9, side * 4.0)) - 0.5) * 0.7;
	return 1.0 - smoothstep(0.85, 1.0, length(q) + n);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float noise_d = skin_noise(rest * 0.7 + 11.0);
	if (dissolve > 0.0 && noise_d < dissolve) {
		discard;
	}
	vec3 color;
	float rough = 0.3;
	float metal = 0.0;
	float glow = 0.0;
	vec3 glow_color = vec3(1.0, 0.1, 0.05);
	float s = sign(rest.x + 1e-5);
	vec3 p = vec3(abs(rest.x), rest.yz);
	float up = ring.y;
	if (part < 0.5) {
		// Silver body: a blue-grey back fading down the flank to a pale belly.
		float scale = girth / 4.8;
		float backness = smoothstep(0.45, 0.95, up);
		color = mix(silver.rgb, back_color.rgb, backness);
		color = mix(color, belly.rgb, smoothstep(-0.4, -0.9, up) * 0.6);
		// The oarfish's oblique wavy streaks and scattered dark spots.
		float warp = (skin_fbm(vec3(rest.z * 0.25, rest.y * 0.4, s * 2.0)) - 0.5) * 3.0;
		float streak = band(fract((rest.z * 0.55 + rest.y * 0.9 / scale + warp) * 0.5) - 0.5, 0.05);
		streak *= smoothstep(0.4, 0.7, skin_fbm(vec3(rest.z * 0.18, rest.y * 0.3, s * 7.0))) * smoothstep(-0.6, 0.2, up);
		float spots = smoothstep(0.7, 0.76, skin_noise(vec3(rest.z * 0.9, rest.y * 1.2, s * 9.0)));
		color = mix(color, streak_color.rgb, clamp(streak * 0.45 + spots * 0.4, 0.0, 1.0));
		color *= mix(0.94, 1.04, skin_fbm(rest * 1.7));
		metal = mix(0.75, 0.35, backness);
		rough = 0.22;
		// A pearly sheen at grazing angles.
		float graze = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		color += graze * mix(vec3(0.25, 0.1, 0.18), vec3(0.08, 0.18, 0.28), skin_noise(rest * 0.3)) * 0.6;
		// Rot: patches where the skin has peeled off, with pale curling edges.
		float rot = skin_fbm(vec3(rest.z * 0.32, rest.y * 0.7, rest.x * 0.7 + s * 3.0)) * 0.8 + skin_noise(rest * 1.9 + s) * 0.2;
		rot += smoothstep(0.55, 1.0, along) * 0.08;
		float peeled = smoothstep(peel, peel + 0.02, rot);
		float edge = band(rot - peel, 0.012);
		vec3 under = flesh.rgb * mix(0.7, 1.05, skin_fbm(rest * 2.3 + 4.0));
		under = mix(under, vec3(0.42, 0.4, 0.38), skin_noise(rest * 0.9) * 0.4);
		color = mix(color, under, peeled);
		color = mix(color, vec3(0.85, 0.82, 0.78), edge * 0.8);
		metal *= 1.0 - peeled;
		rough = mix(rough, 0.75, peeled);
		// Lamprey bite scars: pale rings round raw middles.
		vec2 cell = vec2(rest.z, rest.y * 1.3) / 2.6;
		vec2 id = floor(cell);
		float pick = skin_hash(vec3(id, s * 5.0));
		vec2 f = fract(cell) - 0.5 + (vec2(skin_hash(vec3(id, 1.0)), skin_hash(vec3(id, 2.0))) - 0.5) * 0.4;
		float r = length(f);
		float scar = step(0.86, pick) * smoothstep(0.1, 0.55, along);
		color = mix(color, vec3(0.88, 0.8, 0.76), scar * band(r - 0.17, 0.03));
		color = mix(color, wound.rgb * 1.4, scar * (1.0 - smoothstep(0.1, 0.14, r)));
		// Three flayed wounds: raw red flesh and the ribs through it.
		float g = max(gash(p, s, vec2(31.0, -0.15 * girth), vec2(5.0, 0.5 * girth), 1.0), gash(p, s, vec2(52.0, 0.05 * girth), vec2(3.5, 0.45 * girth), -1.0));
		g = max(g, gash(p, s, vec2(74.0, -0.1 * girth), vec2(2.8, 0.35 * girth), 1.0));
		if (g > 0.0) {
			float rib = band(fract(rest.z / 1.1) - 0.5, 0.11) * smoothstep(-0.95, -0.2, up) * (1.0 - smoothstep(0.6, 0.95, up));
			vec3 raw = mix(wound.rgb, wound.rgb * 2.2, skin_fbm(rest * 3.1));
			raw = mix(raw, bone.rgb * 0.9, rib * 0.85);
			color = mix(color, raw, g);
			rough = mix(rough, 0.12, g);
			metal *= 1.0 - g;
			color = mix(color, wound.rgb * 0.5, band(g - 0.08, 0.06) * 0.7);  // a dark rim
		}
		// A red line where the fin meets the back.
		color = mix(color, fin_color.rgb * 0.8, smoothstep(0.93, 0.99, up) * 0.8);
		// The eye socket: a dark sunken ring.
		float eye_d = length(vec2(p.z - eye_at.z, p.y - eye_at.y));
		color = mix(color, vec3(0.08, 0.05, 0.05), (1.0 - smoothstep(eye_ring * 0.9, eye_ring * 1.25, eye_d)) * smoothstep(0.0, 0.3, abs(ring.x)));
		// The mouth: the front of the head below the eye gapes dark.
		float mouth = (1.0 - smoothstep(1.0, 2.6, rest.z)) * smoothstep(0.1, -0.5, up);
		color = mix(color, vec3(0.12, 0.01, 0.02), mouth);
		glow += rage * 0.15;
	} else if (part < 1.5) {
		// Torn crimson membrane with paler rays.
		float ray = band(fract(UV.x * 160.0) - 0.5, 0.1);
		color = mix(fin_color.rgb, fin_color.rgb * 1.35 + vec3(0.06, 0.03, 0.03), ray * 0.3);
		color *= mix(0.75, 1.1, UV.y);
		float tear = skin_fbm(vec3(UV.x * 90.0, UV.y * 3.0, 1.0));
		if (UV.y > 0.82 && tear < (UV.y - 0.82) * 1.6) {
			discard;
		}
		rough = 0.45;
		glow = 0.12 + rage * 0.6;
		glow_color = fin_color.rgb;
	} else if (part < 2.5) {
		color = bone.rgb * mix(0.7, 1.0, UV.x);
		rough = 0.35;
	} else if (part < 3.5) {
		// Crest filaments: crimson, darkening to their tips.
		color = mix(fin_color.rgb * 1.3, fin_color.rgb * 0.45, UV.x);
		color *= mix(0.85, 1.1, skin_noise(vec3(UV.x * 40.0, UV.y * 6.0, 0.0)));
		rough = 0.4;
		glow = 0.25 + rage * 0.8;
		glow_color = fin_color.rgb;
	} else {
		// The jaw: raw flesh inside the mouth, silver underneath.
		float inside = smoothstep(-0.1, 0.4, up);
		color = mix(silver.rgb * 0.75, mix(vec3(0.2, 0.02, 0.03), vec3(0.45, 0.08, 0.1), skin_fbm(rest * 3.0)), inside);
		metal = (1.0 - inside) * 0.6;
		rough = mix(0.25, 0.15, inside);
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.6;
	EMISSION = glow_color * glow + vec3(1.0, 0.35, 0.3) * flash * 0.8 + vec3(1.0, 0.05, 0.02) * warn * 2.5;
}
