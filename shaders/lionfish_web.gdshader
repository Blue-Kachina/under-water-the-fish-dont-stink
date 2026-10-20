shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// The webs of a lionfish's fins (LionfishModel): thin see-through membrane
// between its spines and rays and the feathery flags along its free rays,
// banded or spotted, clearer toward the edge, rippling with the rays
// (lionfish_fin.gdshaderinc). UV.y runs 0 at the root to 1 at the web's edge.

#include "res://shaders/lionfish_fin.gdshaderinc"

uniform vec4 web_color : source_color = vec4(0.95, 0.88, 0.82, 1.0);
uniform float alpha_root = 0.7;
uniform float alpha_edge = 0.3;
uniform float band_strength = 0.8;
uniform float spots = 0.0;  // 0..1: dark eye spots over it
uniform float spot_size = 0.03;  // m apart
uniform vec4 spot_color : source_color = vec4(0.16, 0.05, 0.08, 1.0);

void vertex() {
	fin_rest = VERTEX;
	fin_at = UV2;
	fin_vertex(VERTEX, NORMAL, UV2);
}

// 1 inside a spot, a pale ring round it, from the fin's rest shape.
vec2 spot_at(vec3 p) {
	vec3 cell = floor(p);
	float best = 9.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 centre = c + vec3(skin_hash(c), skin_hash(c + 11.3), skin_hash(c + 27.1)) * 0.8 + 0.1;
				best = min(best, length(p - centre));
			}
		}
	}
	float aa = fwidth(best);
	float spot = 1.0 - smoothstep(0.28 - aa, 0.28 + aa, best);
	float ring = (1.0 - smoothstep(0.36 - aa, 0.42 + aa, best)) * (1.0 - spot);
	return vec2(spot, ring);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float out_part = smoothstep(0.1, 1.0, UV.y);
	vec3 color = web_color.rgb;
	float band = fin_band() * band_strength;
	color = mix(color, fin_band_color(), band);
	float alpha = mix(alpha_root, alpha_edge, out_part);
	alpha = mix(alpha, max(alpha, 0.92), band);
	if (spots > 0.0) {
		vec2 s = spot_at(fin_rest / spot_size);
		color = mix(color, vec3(1.0, 0.97, 0.94), s.y * spots * 0.6);
		color = mix(color, spot_color.rgb, s.x * spots);
		alpha = mix(alpha, 0.95, s.x * spots);
	}
	// Fine streaks in the membrane, so it reads as skin, not glass.
	color *= 1.0 - 0.08 * skin_noise(vec3(fin_at.x * 90.0, fin_at.y * 6.0, 0.0));
	ALBEDO = color;
	ALPHA = alpha;
	ROUGHNESS = 0.38;
	SPECULAR = 0.45;
	BACKLIGHT = color * 0.6;
}
