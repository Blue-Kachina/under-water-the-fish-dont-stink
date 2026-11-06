shader_type spatial;
// The Marco! scan pulse (MarcoScan): `kind` 0 is the expanding shell, a thin
// rim glow plus a bright line wherever it cuts through the scenery (from the
// depth buffer); 2 is one particle of the torus field (marco_field.gdshader),
// a soft camera-facing dot sized by its particle's scale.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int kind = 0;
uniform vec4 color : source_color = vec4(0.4, 1.0, 0.75, 1.0);
// 0 at the call .. 1 when the whole arena's covered.
uniform float progress = 0.0;
uniform float glow = 1.0;
// How thick the line on the scenery is (m).
uniform float edge_width = 0.6;
uniform float line_count = 28.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void vertex() {
	if (kind == 2) {
		float scale = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		VERTEX *= scale;
	}
}

void fragment() {
	float fade = 1.0 - smoothstep(0.82, 1.0, progress);
	if (kind == 0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = pow(1.0 - facing, 4.0);
		float depth = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		float scene = -view.z / view.w;
		float edge = 1.0 - clamp(abs(scene - -VERTEX.z) / edge_width, 0.0, 1.0);
		edge = edge * edge;
		float bands = 0.5 + 0.5 * sin(UV.y * 180.0 - TIME * 6.0);
		ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.6);
		ALPHA = clamp((rim * 0.25 + 0.015 + bands * 0.012 + edge * 1.4) * fade * glow, 0.0, 1.0);
	} else {
		float d = length(UV - 0.5) * 2.0;
		float soft = 1.0 - smoothstep(0.0, 1.0, d);
		ALBEDO = COLOR.rgb;
		ALPHA = clamp(soft * soft * COLOR.a, 0.0, 1.0);
	}
}
