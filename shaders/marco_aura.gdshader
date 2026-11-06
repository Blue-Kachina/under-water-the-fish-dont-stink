shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

// Marco Polo's aura (planning_marco_polo.md §3): a hider who blundered glows in
// the seeker's colour. Like xray_outline.gdshader, its outline and a faint fill
// show through whatever hides it (murk and furniture); in plain view it's a soft
// rim glow. It pulses, and `strength` (0..1 through the aura band) sets how hard.
// A copy of the body drawn with this bends with the body (fish_bend.gdshaderinc).

#include "res://shaders/fish_bend.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float strength = 0.0;
uniform float edge_width = 0.5;
uniform float fill = 0.12;
uniform float rim_glow = 0.85;
uniform float pulse_rate = 6.0;  // rad/s
uniform float bias = 0.05;
uniform float inflate = 0.02;  // m out along the normal, so the glow sits round the body

void vertex() {
	vec3 v = VERTEX + NORMAL * inflate;
	vec3 n = NORMAL;
	fish_bend(v, n);
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_distance = -scene.z / scene.w;
	bool hidden = scene_distance < -VERTEX.z - bias;
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float beat = 0.7 + 0.3 * sin(TIME * pulse_rate);
	float a;
	if (hidden) {
		float outline = smoothstep(1.0 - edge_width, 1.0 - edge_width * 0.5, edge);
		a = max(outline, fill);
	} else {
		a = rim_glow * (0.18 + 0.82 * pow(edge, 1.6));
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * a * strength * beat, 0.0, 1.0);
}
