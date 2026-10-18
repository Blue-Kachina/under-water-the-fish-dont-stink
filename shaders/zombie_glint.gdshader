shader_type spatial;
// A zombie's eyes in the murk (planning_murk.md §5): a pair of soft red dots
// facing the camera, drawn additive and past the fog, so a wave out in the dark
// shows where it's coming from. Horde draws them through one MultiMesh; each
// instance's scale is the eyes' size and INSTANCE_CUSTOM.r their brightness.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.06, 1.0);

varying float glow;

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale,
			INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	glow = INSTANCE_CUSTOM.r;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float dot_shape = smoothstep(1.0, 0.15, d);
	ALBEDO = tint.rgb * dot_shape * glow * 2.5;
}
