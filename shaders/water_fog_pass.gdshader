// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// The water look's fog pass (planning_abyssal_look.md, phase 2), one full-screen quad per camera
// drawn first in the transparent pass. It reads the opaque picture and the depth buffer, rebuilds
// each pixel's world position, and replaces the Environment's one-colour fog with the water model:
// per-colour absorption  c * exp(-SIG * d)  plus the water's own colour scattered in along the ray
// (water_fog.gdshaderinc), fading to pure water between fade_start and fade_end. The Environment's
// own fog (kept on, thinner, for see-through things drawn after this) is undone first so the opaque
// world is not fogged twice. Everything camera-specific comes from the built-ins, so split-screen
// views each fog from their own camera. (The plan's first choice, a CompositorEffect, could not
// change the picture under MSAA: its resolved copy is made again after the transparent pass.)
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/water_fog.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 wq_env_fog = vec4(0.0);   // xyz the Environment's fog colour (linear), w its density
uniform vec2 wq_fade = vec2(150.0, 220.0);
uniform float wq_surface_y = 30.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);  // the whole screen, at the near plane (reversed depth)
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec3 src = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (depth <= 0.0) {
		ALBEDO = src;  // the sky draws its own water
		ALPHA = 1.0;
	} else {
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		view.xyz /= view.w;
		float d = length(view.xyz);
		vec3 rd = normalize((INV_VIEW_MATRIX * vec4(view.xyz, 0.0)).xyz);
		float ro_y = CAMERA_POSITION_WORLD.y - wq_surface_y;

		// Undo the Environment's fog (exp, by distance), leaving the surface's own colour.
		float te = exp(-wq_env_fog.w * d);
		vec3 c = max((src - wq_env_fog.rgb * (1.0 - te)) / te, vec3(0.0));

		vec3 scatter = wf_in(ro_y, rd, d, wf_sig);
		float far = smoothstep(wq_fade.x, max(wq_fade.y, wq_fade.x + 0.01), d);
		ALBEDO = mix(c * exp(-wf_sig * d) + scatter, scatter, far);
		ALPHA = 1.0;
	}
}
