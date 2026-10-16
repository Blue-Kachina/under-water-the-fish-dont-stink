shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// A swirl of water shed by a stride (Swirl): a clear ring, brighter where you
// see through more of it (its edges), tinted gold for a perfect stride. Fades
// out with `fade` (per swirl).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
instance uniform vec4 tint = vec4(0.72, 0.93, 1.0, 1.0);
instance uniform float fade = 1.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 1.5);
	vec3 behind = textureLod(screen_texture, SCREEN_UV + NORMAL.xy * 0.03, 0.0).rgb;
	ALBEDO = mix(behind, tint.rgb, clamp(0.35 + rim * 0.6, 0.0, 1.0));
	ALPHA = clamp(fade * (0.25 + 0.7 * rim), 0.0, 1.0);
}
