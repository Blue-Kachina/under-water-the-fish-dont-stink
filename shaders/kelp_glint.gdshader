// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Kelp glints (planning_abyssal_look.md, phase 5): additive billboards pinned to a kelp plant. Each plant's glint mesh (KelpGlints)
// has one quad per glint, at a point on a blade, with that blade's height fraction in COLOR.a and two randoms in COLOR.rg. The
// vertex shader sways the point exactly as kelp_plant.gdshader sways the blade, then billboards it. Twinkle pow(.5+.5 sin, 4),
// held to min_px pixels with the energy conserved.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float size = 0.05;
uniform float min_px = 2.5;
uniform float peak = 4.0;
uniform float speed = 2.2;
uniform float density = 1.0;
uniform float far_a = 25.0;
uniform float far_b = 55.0;
uniform vec3 color = vec3(1.0, 0.95, 0.6);
// The kelp material's own sway, so the glints follow the blade.
uniform float sway = 0.9;
uniform float sway_speed = 0.8;

varying float bright;
varying vec2 corner;

void vertex() {
	float up = COLOR.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 0.11 + root.z * 0.13 + INSTANCE_CUSTOM.g * 6.28;
	float bend = up * up * sway;
	float scale = max(length(MODEL_MATRIX[1].xyz), 0.01);
	vec3 c = VERTEX;
	c.x += (sin(TIME * sway_speed + phase + up * 1.5) * bend) / scale;
	c.z += (cos(TIME * sway_speed * 0.8 + phase * 1.3 + up) * bend * 0.6) / scale;
	vec4 vp = VIEW_MATRIX * (MODEL_MATRIX * vec4(c, 1.0));
	float depth = max(-vp.z, 0.01);
	float px = 2.0 * depth / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float s = max(size, min_px * 0.5 * px);
	float energy = min((size * size) / (s * s), 1.0);
	float twinkle = 0.5 + 0.5 * sin(TIME * speed * (0.6 + COLOR.g) + COLOR.r * 40.0);
	twinkle = pow(twinkle, 4.0);
	float shown = step(COLOR.r, density) * (1.0 - smoothstep(far_a, far_b, depth)) * smoothstep(0.2, 1.2, depth);
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
