// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// A bubble (planning_abyssal_look.md, phase 5): a wobbly bright rim (it wobbles round the edge, each bubble on its own phase),
// two highlight dots, and the water's colour reflected in it (no cubemap: the reflection direction picks a darker or brighter water).
// Used by the stride stream (colour and alpha per bubble from the MultiMesh, tone_from_color 1) and the bubble columns (tint).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

global uniform vec3 water_bubble_color;
global uniform vec3 water_bubble_look;  // x: look on (0: the old plain rim), y: wobble, z: highlight strength

uniform vec3 tint : source_color = vec3(0.85, 0.97, 1.0);
uniform float tone_from_color = 0.0;
uniform float base_alpha = 0.3;
uniform float rim_alpha = 0.6;

varying vec4 tone;
varying float seed;

void vertex() {
	tone = tone_from_color > 0.5 ? COLOR : vec4(tint, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	seed = fract(sin(dot(o, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 1.8);
	if (water_bubble_look.x < 0.5) {
		ALBEDO = mix(tone.rgb * 1.4, vec3(1.0), rim * 0.3);
		ALPHA = tone.a * (base_alpha + rim_alpha * rim);
	} else {
		float a = atan(NORMAL.y, NORMAL.x);
		float wob = 1.0 + water_bubble_look.y * sin(a * 5.0 + TIME * 3.0 + seed * 6.28) * sin(a * 3.0 - TIME * 2.1 + seed * 17.0);
		rim = clamp(rim * wob, 0.0, 1.5);
		vec3 r_view = reflect(-VIEW, NORMAL);
		vec3 r_world = (INV_VIEW_MATRIX * vec4(r_view, 0.0)).xyz;
		vec3 refl = water_bubble_color * (0.45 + 0.9 * (r_world.y * 0.5 + 0.5));
		float s1 = pow(max(dot(NORMAL, normalize(vec3(-0.42, 0.52, 0.74))), 0.0), 90.0);
		float s2 = pow(max(dot(NORMAL, normalize(vec3(0.38, -0.36, 0.85))), 0.0), 140.0) * 0.6;
		vec3 spec = vec3(1.0) * (s1 + s2) * water_bubble_look.z;
		vec3 rim_col = mix(tone.rgb * 1.4, vec3(1.0), rim * 0.3);
		vec3 body = refl + tone.rgb * 0.15;
		ALBEDO = mix(body, rim_col, clamp(rim, 0.0, 1.0)) + spec;
		ALPHA = clamp(tone.a * (base_alpha + rim_alpha * rim) + (s1 + s2) * tone.a, 0.0, 1.0);
	}
}
