shader_type spatial;
render_mode cull_back;
// A mantis shrimp's armour (MantisModel): the body, its telson and eye stalks.
// `albedo` is the main colour (set_body_color() tints it), darker over the back
// and paler underneath, with a dark seam and a glossy, lighter rear margin on
// every plate (`seams`, m along the body), the species' markings (`pattern`),
// a fine pitted texture and an iridescent sheen at grazing angles. Painted from
// the resting shape (plus `rest_offset` for parts on the tail pivot), so
// nothing slides as the abdomen bends (fish_bend.gdshaderinc).
// Vertex colour green below 1 paints `accent_color` (the telson's rim).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.23, 0.6, 0.24, 1.0);
uniform vec4 belly_color : source_color = vec4(0.66, 0.85, 0.47, 1.0);
uniform float belly_mix = 0.5;
uniform float top_shade = 0.6;  // the back, of albedo
uniform vec4 mark_color : source_color = vec4(0.05, 0.23, 0.08, 1.0);
uniform vec4 mark_color2 : source_color = vec4(0.05, 0.23, 0.08, 1.0);
uniform int pattern = 0;  // 0 leopard spots (peacock), 1 bands (zebra), 2 speckles (purple-spot), 3 fine freckles (pink-eared)
uniform float mark_size = 0.018;  // m, a spot's cell
uniform float band_width = 0.02;  // m, half a band
uniform vec4 accent_color : source_color = vec4(0.94, 0.54, 0.16, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float iridescence = 0.3;
uniform float margin_glow = 0.35;
uniform float seams[12];
uniform int seam_count = 0;
uniform vec2 carapace = vec2(-0.58, -0.28);  // its front and back (m)
uniform vec2 extra_bands = vec2(100.0);  // more bands' middles (m), zebra
uniform vec3 rest_offset = vec3(0.0);

varying vec3 rest;
varying vec3 rest_n;
varying float accent;

void vertex() {
	rest = VERTEX + rest_offset;
	rest_n = NORMAL;
	accent = 1.0 - COLOR.g;
	fish_bend(VERTEX, NORMAL);
}

// Distance (m) to the nearest round spot: cells `size` m, `fill` of them with a
// spot. Less than 0 inside one.
float spots(vec3 p, float size, float fill, float seed) {
	vec3 q = p / size;
	vec3 i = floor(q);
	vec3 f = fract(q);
	float d = 10.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 c = i + o + seed;
				if (skin_hash(c + 9.1) > fill) {
					continue;
				}
				vec3 at = o + vec3(skin_hash(c), skin_hash(c + 17.3), skin_hash(c + 31.7)) * 0.7 + 0.15;
				float r = mix(0.22, 0.42, skin_hash(c + 5.3));
				d = min(d, length(at - f) - r);
			}
		}
	}
	return d * size;
}

void fragment() {
	float up = rest_n.y;
	vec3 base = albedo.rgb;
	vec3 col = mix(base * 1.08, base * top_shade, smoothstep(0.05, 0.95, up));
	col = mix(col, mix(base, belly_color.rgb, belly_mix), smoothstep(-0.1, -0.7, up));
	float side = smoothstep(-0.65, -0.25, up);  // not the belly

	// Plates: a dark seam at each, and a raised, lighter margin just before it.
	float seam_d = 10.0;
	float margin = 0.0;
	for (int i = 1; i < seam_count; i++) {
		float d = rest.z - seams[i];
		seam_d = min(seam_d, abs(d));
		if (d < 0.0 && d > -0.03) {
			margin = max(margin, 1.0 + d / 0.03);
		}
	}
	margin *= margin;
	float aa = fwidth(rest.z) + 1e-4;
	col = mix(col, min(col * 1.4 + 0.05, vec3(1.0)), margin * margin_glow * side);

	// Markings.
	float zd = 10.0;
	if (pattern == 0) {
		float front = smoothstep(carapace.x + 0.75 * (carapace.y - carapace.x), carapace.x + 0.35 * (carapace.y - carapace.x), rest.z);
		float d = spots(rest, mark_size, 0.85, 0.0);
		float a2 = fwidth(d) + 1e-4;
		col = mix(col, mark_color.rgb, (1.0 - smoothstep(-a2, a2, d)) * front * smoothstep(-0.4, 0.1, up) * 0.9);
		float fine = spots(rest, mark_size * 0.6, 0.25, 3.0);
		col = mix(col, mark_color.rgb, (1.0 - smoothstep(-a2, a2, fine)) * (1.0 - front) * side * 0.45);
	} else if (pattern == 1) {
		float wob = (skin_fbm(rest * 30.0) - 0.5) * 0.016;
		for (int i = 1; i < seam_count; i++) {
			zd = min(zd, abs(rest.z - seams[i] + wob));
		}
		zd = min(zd, abs(rest.z - extra_bands.x + wob));
		zd = min(zd, abs(rest.z - extra_bands.y + wob));
		float band = 1.0 - smoothstep(band_width - aa, band_width + aa, zd);
		col = mix(col, mark_color.rgb, band * side * 0.95);
		float d = spots(rest, mark_size, 0.35, 7.0);
		float a2 = fwidth(d) + 1e-4;
		col = mix(col, mark_color.rgb, (1.0 - smoothstep(-a2, a2, d)) * side * 0.35);
	} else if (pattern == 2) {
		float d = spots(rest, mark_size, 0.55, 0.0);
		float a2 = fwidth(d) + 1e-4;
		col = mix(col, mark_color.rgb, (1.0 - smoothstep(-a2, a2, d)) * side * 0.28);
		float d2 = spots(rest, mark_size * 0.8, 0.5, 11.0);
		col = mix(col, mark_color2.rgb, (1.0 - smoothstep(-a2, a2, d2)) * side * 0.6);
		col *= mix(0.8, 1.15, skin_fbm(rest * 12.0));
	} else {
		float d = spots(rest, mark_size, 0.4, 0.0);
		float a2 = fwidth(d) + 1e-4;
		col = mix(col, mark_color.rgb, (1.0 - smoothstep(-a2, a2, d)) * side * 0.4);
	}
	// The seam line itself, over the markings.
	float line = 1.0 - smoothstep(0.0025, 0.0025 + aa * 1.5, seam_d);
	col = mix(col, col * 0.28, line * side);

	// Fine texture: mottling and pits.
	col *= 0.9 + 0.2 * skin_fbm(rest * 55.0);
	col *= 1.0 - 0.1 * smoothstep(0.62, 0.8, skin_noise(rest * 190.0));
	col = mix(col, accent_color.rgb, accent);

	// Iridescence: a thin-film shimmer at grazing angles, stronger on the margins.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 film = 0.5 + 0.5 * cos(TAU * (fres * 0.8 + rest.z * 2.5 + vec3(0.0, 0.33, 0.67)));
	vec3 sheen = mix(sheen_color.rgb, film, 0.5);
	col += sheen * iridescence * (fres * 0.5 + margin * 0.25 * side);

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = mix(0.32, 0.22, margin);
	SPECULAR = 0.6;
	CLEARCOAT = 0.8;
	CLEARCOAT_ROUGHNESS = 0.15;
}
