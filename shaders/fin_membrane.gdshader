shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// A thin fin (FishModel._membrane): UV.x runs along its root, UV.y from the root
// (0) out to its edge (1). It ripples out of its plane, more toward the edge and
// harder the faster the fish swims, and goes see-through toward the edge with
// its rays showing. A tail's fin also shows the stride cue (stride_cue.gdshaderinc),
// root to edge.

#include "res://shaders/stride_cue.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);  // at the root
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float edge_shade = -1.0;  // 0 or more: the edge is albedo times this instead, so it follows a tint
uniform vec4 ray_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform float rays = 12.0;  // across the fin, 0 for none
uniform float edge_alpha = 0.45;
uniform vec4 margin_color : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform float margin = 0.0;  // of the fin's depth: a solid border round its edge, 0 for none
uniform float flutter = 0.02;  // m at the edge, idling
uniform float waves = 1.2;  // from the root out to the edge
uniform float tempo = 1.0;  // how fast it ripples, against the swim
uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out

void vertex() {
	float a = TAU * waves * UV.y + UV.x * 2.5 - phase * tempo;
	VERTEX += NORMAL * flutter * (1.0 + 1.5 * effort) * UV.y * UV.y * sin(a);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float out_part = smoothstep(0.15, 1.0, UV.y);
	vec3 edge = edge_shade >= 0.0 ? albedo.rgb * edge_shade : edge_color.rgb;
	vec3 color = mix(albedo.rgb, edge, out_part);
	if (rays > 0.0) {
		float across = UV.x * rays;
		float ray = abs(fract(across + 0.5) - 0.5);  // 0 on a ray
		float width = fwidth(across);
		ray = 1.0 - smoothstep(0.04 + width, 0.1 + width * 2.0, ray);
		color = mix(color, ray_color.rgb, ray * 0.55 * (1.0 - 0.6 * out_part));
	}
	ALPHA = mix(1.0, edge_alpha, out_part);
	if (margin > 0.0) {
		float aa = fwidth(UV.y);
		float border = smoothstep(1.0 - margin - aa, 1.0 - margin + aa, UV.y);
		color = mix(color, margin_color.rgb, border);
		ALPHA = mix(ALPHA, 0.95, border);
	}
	ALBEDO = color;
	ROUGHNESS = 0.35;
	BACKLIGHT = color * 0.5;
	// The lit part of a see-through fin firms up, so the cue reads on it too.
	vec3 cue = stride_cue(UV.y);
	EMISSION = cue * 1.5;
	ALPHA = max(ALPHA, min(length(cue), 1.0));
}
