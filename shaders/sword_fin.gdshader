shader_type spatial;
render_mode cull_disabled;
// A billfish's stiff fins (SwordfishModel._fin): opaque and dark, the body's
// `albedo` (tinted with it) shaded from `root_shade` at the root to
// `edge_shade` at the edge, with paler rays. UV.x counts the rays along the
// root (one per unit), UV.y runs root (0) to edge (1). The sailfish's sail adds
// dark `spots` and a gentle ripple. Fins on the body's bending part bend with
// it (fish_bend.gdshaderinc).

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.42, 0.31, 0.38, 1.0);
uniform float root_shade = 0.55;
uniform float edge_shade = 0.4;
uniform vec4 ray_color : source_color = vec4(0.8, 0.85, 1.0, 1.0);
uniform float ray_strength = 0.2;
uniform vec4 spot_color : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform float spots = 0.0;  // how dark the spots are, 0 for none
uniform float spot_spacing = 0.045;  // m
uniform float sheen = 0.25;  // metallic at the root
uniform float flutter = 0.0;  // m at the edge, sideways (x)
uniform float phase = 0.0;
uniform float effort = 0.0;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	float a = TAU * UV.y - rest.z * 14.0 - phase;
	VERTEX.x += flutter * (1.0 + effort) * UV.y * UV.y * sin(a);
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 color = albedo.rgb * mix(root_shade, edge_shade, smoothstep(0.1, 1.0, UV.y));
	float d = abs(fract(UV.x) - 0.5) * 2.0;  // 1 on a ray
	float aa = fwidth(UV.x) * 2.0;
	float ray = smoothstep(0.82 - aa, 0.95, d);
	color = mix(color, color * 0.5 + ray_color.rgb * 0.25, ray * ray_strength * (1.0 - 0.5 * UV.y));
	if (spots > 0.0) {
		vec2 cell = rest.zy / spot_spacing;
		vec2 id = floor(cell);
		vec2 jitter = vec2(skin_hash(vec3(id, 1.0)), skin_hash(vec3(id, 7.0))) * 0.5 + 0.25;
		float r = length(fract(cell) - jitter);
		float spot = 1.0 - smoothstep(0.18, 0.18 + fwidth(cell.x) * 1.5 + 0.04, r);
		color = mix(color, spot_color.rgb, spot * spots * smoothstep(0.05, 0.25, UV.y));
	}
	color *= 0.92 + 0.12 * skin_noise(rest * 120.0);
	ALBEDO = color;
	METALLIC = sheen * (1.0 - UV.y);
	ROUGHNESS = 0.38;
	SPECULAR = 0.55;
	BACKLIGHT = color * 0.5;
}
