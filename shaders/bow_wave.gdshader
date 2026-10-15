shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// The bow wave (FishController.bow_wave): a shell of water pushed ahead of a
// fast fish, shaped like a torpedo's tip. Mostly clear: it bends what's behind
// it a little, brightens toward its edges (where you see through more of it),
// and has faint ripples streaming back from the tip. UV.x runs round it, UV.y
// from its open back (0) to the tip (1).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.72, 0.93, 1.0, 1.0);
uniform float amount = 0.0;  // its size, 0..1: fades in with it
uniform float flow = 0.0;  // advances with the distance swum

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float along = UV.y;
	float lanes = smoothstep(0.6, 1.0, 0.5 + 0.5 * sin(UV.x * TAU * 10.0 + 0.8 * sin(along * 9.0)));
	// Fading out toward the tip, where the lanes would bunch up into a star.
	float ripples = lanes * (0.5 + 0.5 * sin(along * 22.0 + flow)) * (1.0 - smoothstep(0.55, 0.9, along));
	vec2 bend = NORMAL.xy * 0.035 * amount;
	vec3 behind = textureLod(screen_texture, SCREEN_UV + bend, 0.0).rgb;
	float fade = smoothstep(0.0, 0.5, along) * amount;  // no hard edge at the open back
	ALBEDO = mix(behind, tint.rgb, clamp(rim * 0.6 + ripples * 0.1, 0.0, 1.0));
	ALPHA = clamp(fade * (0.15 + 0.65 * rim + 0.1 * ripples), 0.0, 1.0);
}
