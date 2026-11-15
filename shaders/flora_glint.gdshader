// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Flora glints (planning_abyssal_look.md, flora pass): additive billboards riding on blade kelp, instanced by FloraField (the glint
// layer). Like kelp_glint.gdshader, but the point is the instance's own position and it sways with flora_sway, exactly as the
// blades at that height do:
//   MODEL_MATRIX[3].xyz   the glint's rest point (world)
//   MODEL_MATRIX[0].xyz   sway height (m above the ground), two randoms
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

#include "res://shaders/flora_sway.gdshaderinc"

uniform float size = 0.05;
uniform float min_px = 2.5;
uniform float peak = 4.0;
uniform float speed = 2.2;
uniform float density = 1.0;
uniform float far_a = 25.0;
uniform float far_b = 55.0;
uniform vec3 color = vec3(1.0, 0.95, 0.6);
uniform float sway_amount = 1.0;

varying float bright;
varying vec2 corner;

void vertex() {
	vec3 m0 = MODEL_MATRIX[0].xyz;
	float h = m0.x;
	float r1 = m0.y;
	float r2 = m0.z;
	vec3 c = MODEL_MATRIX[3].xyz;
	vec2 sw = flora_sway(c.xz, h, TIME, sway_amount);
	c.x += sw.x;
	c.z += sw.y;
	vec4 vp = VIEW_MATRIX * vec4(c, 1.0);
	float depth = max(-vp.z, 0.01);
	float px = 2.0 * depth / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float s = max(size, min_px * 0.5 * px);
	float energy = min((size * size) / (s * s), 1.0);
	float twinkle = 0.5 + 0.5 * sin(TIME * speed * (0.6 + r2) + r1 * 40.0);
	twinkle = pow(twinkle, 4.0);
	float shown = step(r1, density) * (1.0 - smoothstep(far_a, far_b, depth)) * smoothstep(0.2, 1.2, depth);
	bright = twinkle * energy * shown * peak;
	corner = UV * 2.0 - 1.0;
	vp.xy += corner * s;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float soft = clamp(1.0 - dot(corner, corner), 0.0, 1.0);
	ALBEDO = color * bright * soft * soft;
	ALPHA = 1.0;
}
