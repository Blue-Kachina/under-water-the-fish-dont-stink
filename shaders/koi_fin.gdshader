shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// A koi's long flowing fin (KoiModel._fin), like fin_membrane but with the
// varieties' fin markings: a patch of colour at its base (Showa's black
// motoguro, Asagi's orange roots), dark rays out from the root (Showa's
// striped pectorals) and a metallic sheen (Ogon). UV.x runs along its root,
// UV.y from the root (0) out to its edge (1). It ripples out of its plane in
// two broad waves, more toward the edge and harder the faster the fish swims. One on
// the body's bending part bends with it (fish_bend.gdshaderinc).

#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);  // at the root
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float edge_shade = -1.0;  // 0 or more: the edge is albedo times this instead, so it follows a tint
uniform vec4 ray_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform float rays = 14.0;  // across the fin, 0 for none
uniform float root_alpha = 0.8;
uniform float edge_alpha = 0.3;
uniform vec4 base_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float base_len = 0.0;  // of the fin's depth: a patch of base_color at its root, 0 for none
uniform vec2 base_span = vec2(0.0, 1.0);  // along the root (UV.x) the patch covers
uniform vec4 stripe_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float stripe_len = 0.0;  // of the fin's depth: dark rays out to here, 0 for none
uniform float metallic = 0.0;
uniform float flutter = 0.02;  // m at the edge, idling
uniform float waves = 1.2;  // from the root out to the edge
uniform float tempo = 1.0;  // how fast it ripples, against the swim
uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out

void vertex() {
	float a = TAU * waves * UV.y + UV.x * 2.5 - phase * tempo;
	float b = TAU * waves * 0.6 * UV.y - UV.x * 3.0 - phase * tempo * 0.7;
	VERTEX += NORMAL * flutter * (1.0 + 1.5 * effort) * UV.y * UV.y * (sin(a) + 0.3 * sin(b));
	fish_bend(VERTEX, NORMAL);
}

float fin_hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float out_part = smoothstep(0.12, 1.0, UV.y);
	vec3 edge = edge_shade >= 0.0 ? albedo.rgb * edge_shade : edge_color.rgb;
	vec3 color = mix(albedo.rgb, edge, out_part);
	float across = UV.x * rays;
	float width = fwidth(across);
	float ray = 0.0;
	if (rays > 0.0) {
		ray = abs(fract(across + 0.5) - 0.5);  // 0 on a ray
		ray = 1.0 - smoothstep(0.035 + width, 0.1 + width * 2.0, ray);
		// Each ray branches toward the edge: a second, finer ray between.
		float fine = abs(fract(across) - 0.5);
		ray = max(ray, (1.0 - smoothstep(0.03 + width, 0.07 + width * 2.0, fine)) * smoothstep(0.45, 0.7, UV.y) * 0.6);
		color = mix(color, ray_color.rgb, ray * 0.5 * (1.0 - 0.5 * out_part));
	}
	float alpha = mix(root_alpha, edge_alpha, out_part);
	// Fine streaks along the rays, as a thin membrane shows.
	float streak = fin_hash(floor(UV.x * rays * 6.0));
	color *= 0.94 + 0.1 * streak;
	if (base_len > 0.0) {
		float in_span = smoothstep(base_span.x - 0.06, base_span.x + 0.06, UV.x) * (1.0 - smoothstep(base_span.y - 0.06, base_span.y + 0.06, UV.x));
		float reach = base_len * (0.75 + 0.5 * fin_hash(floor(across)) * 0.5) * in_span;
		float a = fwidth(UV.y) * 1.5;
		float base = 1.0 - smoothstep(reach - a - 0.04, reach + a, UV.y);
		color = mix(color, base_color.rgb, base * step(0.001, reach));
		alpha = mix(alpha, 0.96, base * step(0.001, reach));
	}
	if (stripe_len > 0.0 && rays > 0.0) {
		float s = ray * (1.0 - smoothstep(stripe_len * 0.6, stripe_len, UV.y));
		color = mix(color, stripe_color.rgb, s * 0.9);
		alpha = max(alpha, s * 0.9);
	}
	ALBEDO = color;
	ALPHA = alpha;
	METALLIC = metallic * (1.0 - out_part * 0.5);
	ROUGHNESS = mix(0.38, 0.18, metallic);
	SPECULAR = 0.5;
	BACKLIGHT = color * 0.55;
	RIM = 0.2;
	RIM_TINT = 0.5;
}
