shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

// Drawn as a next pass over a target (the ball, the next hoop): where something
// opaque hides it, its outline shows through, with a faint fill; where it's in
// plain view, nothing. Depth testing is off so the hidden parts draw at all;
// the scene's depth decides which parts are hidden.

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
// How much of the silhouette's edge counts as outline (0..1, of 1 - facing).
uniform float edge_width = 0.45;
uniform float fill = 0.07;
// Hidden only behind something at least this much closer (m): the target's own
// surface isn't hiding itself.
uniform float bias = 0.05;
// The bubble's stretch along its travel (see bubble.gdshader), so the outline
// keeps its shape. Zero for anything that doesn't stretch.
uniform vec3 stretch_dir = vec3(0.0, 1.0, 0.0);
uniform float stretch = 0.0;

void vertex() {
	if (stretch > 0.0) {
		vec3 p = VERTEX;
		vec3 dir = normalize((inverse(MODEL_MATRIX) * vec4(stretch_dir, 0.0)).xyz);
		float along = dot(p, dir);
		p += dir * along * stretch - (p - dir * along) * stretch * 0.5;
		VERTEX = p;
	}
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_distance = -scene.z / scene.w;
	if (scene_distance > -VERTEX.z - bias) {
		discard;  // in view
	}
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float outline = smoothstep(1.0 - edge_width, 1.0 - edge_width * 0.5, edge);
	ALBEDO = color.rgb;
	ALPHA = color.a * max(outline, fill);
}
