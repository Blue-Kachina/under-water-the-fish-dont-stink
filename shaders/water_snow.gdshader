// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Marine snow (planning_abyssal_look.md, phase 5): camera-facing quads, each keeping a fixed spot in a unit cube that is wrapped into a
// box round the camera, so the same few thousand flakes always surround whoever is looking. The camera is the view's own
// (CAMERA_POSITION_WORLD), so every split-screen view gets snow round itself. Fades in close and out far, never draws smaller than
// min_px pixels (it gets dimmer instead, so the light is conserved and nothing shimmers), and is additive with an HDR peak.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float box_size = 44.0;
uniform float size = 0.03;
uniform float min_px = 1.6;
uniform float near_a = 0.6;
uniform float near_b = 2.5;
uniform float far_a = 14.0;
uniform float far_b = 22.0;
uniform float peak = 2.2;
uniform vec3 color = vec3(0.7, 0.9, 1.0);
uniform vec3 drift = vec3(0.22, 0.05, 0.13);

varying float bright;
varying vec2 corner;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz * box_size;  // the instances sit in a unit cube
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 off = mod(origin + drift * TIME - cam + box_size * 0.5, box_size) - box_size * 0.5;
	vec3 wp = cam + off;
	float d = length(off);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	float depth = max(-vp.z, 0.01);
	float px = 2.0 * depth / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);  // metres per pixel here
	float r = size * length(MODEL_MATRIX[0].xyz);
	float s = max(r, min_px * 0.5 * px);
	float energy = min((r * r) / (s * s), 1.0);
	float fade = smoothstep(near_a, near_b, d) * (1.0 - smoothstep(far_a, far_b, d));
	bright = energy * fade * peak;
	corner = VERTEX.xy * 2.0;
	vp.xy += corner * s;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float soft = clamp(1.0 - dot(corner, corner), 0.0, 1.0);
	ALBEDO = color * bright * soft * soft * 1.6;
	ALPHA = 1.0;
}
