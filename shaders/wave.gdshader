shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// The Tsunami Heart's wave (planning_environment.md, Phase 6): a curling wall
// of water, see-through, brightest where it turns from the view, foam
// streaming up its face and boiling at the lip. COLOR.r is how far round the
// curl a point is (0 the back's foot .. 1 the lip's tip).

#include "res://shaders/scenery.gdshaderinc"

uniform vec3 color : source_color = vec3(0.3, 0.75, 1.0);
uniform float fade = 1.0;

varying float curl;
varying vec3 local;

void vertex() {
	curl = COLOR.r;
	local = VERTEX;
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 1.6);
	float flow = sc_noise(vec3(local.x * 1.5, curl * 6.0 - TIME * 3.0, 0.0));
	float streaks = smoothstep(0.55, 0.8, flow) * smoothstep(0.2, 0.6, curl);
	float lip = smoothstep(0.55, 0.85, curl) * (0.6 + 0.4 * sc_noise(vec3(local.x * 4.0, TIME * 4.0, curl * 9.0)));
	float foam = clamp(streaks * 0.7 + lip, 0.0, 1.0);
	vec3 water = mix(color * 0.5, color, curl) + rim * 0.4;
	ALBEDO = mix(water, vec3(0.92, 0.98, 1.0), foam);
	ALPHA = clamp((0.28 + rim * 0.5 + foam * 0.6) * fade * smoothstep(0.0, 0.12, curl), 0.0, 1.0);
}
