shader_type spatial;
render_mode cull_disabled;
// Fan coral (a gorgonian) on Unnatural's seabed (planning_environment.md,
// Phase 5): a thin fan whose lattice of branching twigs is cut out of it, so
// the water shows through; it sways a little at its edge.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.85, 0.2, 0.35);
uniform vec3 color_b : source_color = vec3(0.95, 0.55, 0.15);
uniform vec3 color_c : source_color = vec3(0.6, 0.25, 0.8);

varying vec3 local;
varying float up;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	local = VERTEX;
	up = COLOR.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	float bend = up * up * 0.08;
	VERTEX.z += sin(TIME * 0.9 + root.x * 0.3 + root.z * 0.2) * bend;
}

void fragment() {
	// Branches fanning out from the stalk, forking (more of them further out),
	// joined by a fine web of cross-links.
	vec2 q = local.xy - vec2(0.0, 0.15);
	float r = length(q);
	float ang = atan(q.x, q.y);
	float wobble = sc_noise(local * 4.0) * 0.6;
	float forks = 6.0 + floor(r * 8.0);
	float ray = abs(fract(ang / 2.2 * forks + wobble) - 0.5);
	float branch = smoothstep(0.5 - 0.09 / max(r, 0.3), 0.5, 0.5 - ray);
	vec2 web = local.xy * 34.0 + vec2(sc_noise(local * 9.0), sc_noise(local * 9.0 + 3.0)) * 1.2;
	float link = max(smoothstep(0.42, 0.48, 0.5 - abs(fract(web.x + web.y * 0.5) - 0.5)),
			smoothstep(0.42, 0.48, 0.5 - abs(fract(web.y - web.x * 0.5) - 0.5))) * 0.9;
	float twig = max(branch, link * step(0.25, r));
	float edge = smoothstep(0.0, 0.1, up);
	float pick = custom.r;
	vec3 color = pick < 0.33 ? color_a : (pick < 0.66 ? color_b : color_c);
	ALBEDO = color * (0.8 + 0.3 * sc_noise(local * 20.0));
	ALPHA = max(twig, 1.0 - edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.75;
	EMISSION = color * 0.12;
	BACKLIGHT = color * 0.4;
}
