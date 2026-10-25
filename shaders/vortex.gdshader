shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// A whirlpool's funnel (planning_environment.md, Phase 6): streaks of foam
// spiralling down and round it, faster near its throat, brightest where the
// wall turns away from the view (a fresnel rim), with a band of foam at its
// lip. Local space: the funnel stands on y 0, `tall` m high.

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 color : source_color = vec3(0.55, 0.9, 1.0);
uniform float tall = 40.0;
uniform float strength = 1.0;
uniform float spin = 1.2;

varying float angle;
varying float rise;

void vertex() {
	angle = atan(VERTEX.z, VERTEX.x);
	rise = clamp(VERTEX.y / tall, 0.0, 1.0);
}

void fragment() {
	float speed = spin * (2.0 - rise);
	float swirl = angle * 3.0 + rise * 14.0 + TIME * speed;
	float streak = pow(0.5 + 0.5 * sin(swirl + sc_noise(vec3(angle * 2.0, rise * 8.0, TIME * 0.3)) * 3.0), 6.0);
	float fine = pow(0.5 + 0.5 * sin(swirl * 3.7 + 1.3), 10.0) * 0.5;
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 2.0);
	float lip = smoothstep(0.9, 1.0, rise) * 0.6;
	float fade = smoothstep(0.0, 0.08, rise);
	float glow = (streak * 0.55 + fine + rim * 0.35 + lip) * fade * strength;
	ALBEDO = color * glow + vec3(streak * 0.15) * fade;
	ALPHA = clamp(glow, 0.0, 1.0);
}
