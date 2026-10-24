// A warning lane in Unnatural (Telegraphs, the Playability pass P3): where a
// lunging zombie or a boss's charge is about to go, laid along its path as two
// crossed ribbons. UV.x runs across, UV.y from where it starts (0) to where it
// ends (1). Per instance (INSTANCE_CUSTOM): r how far through its wind-up (0 to
// 1): the lane fills from its start toward its end as it does, so the moment it
// reaches the end is the moment it comes; g a boss's (a hotter red). Chevrons
// run along it the way it'll come. Additive, unshaded, never in the fog's way of
// reading: it ignores the fog.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength = 1.0;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	float progress = clamp(custom.r, 0.0, 1.0);
	float boss = custom.g;
	float across = abs(UV.x - 0.5) * 2.0;  // 0 middle, 1 edge
	float along = UV.y;
	// Bright edges, a faint middle.
	float edge = smoothstep(0.6, 1.0, across) * (1.0 - smoothstep(0.92, 1.0, across)) + 0.12;
	// Chevrons running toward the end.
	float chevron = fract(along * 6.0 - across * 0.6 - TIME * 2.5);
	float arrows = smoothstep(0.75, 0.9, chevron) * (1.0 - smoothstep(0.92, 1.0, chevron)) * (1.0 - across * 0.5);
	// Filled up to how far through the wind-up it is.
	float filled = 1.0 - smoothstep(progress - 0.04, progress + 0.04, along);
	// Fades in at the start and out toward the end.
	float ends = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.85, 1.0, along));
	float pulse = 0.75 + 0.25 * sin(TIME * 24.0);
	vec3 red = mix(vec3(1.0, 0.08, 0.04), vec3(1.0, 0.25, 0.05), boss);
	float glow = (edge * (0.35 + 0.65 * filled) + arrows * 0.6 + filled * 0.18) * ends * pulse * strength;
	ALBEDO = red * (1.0 + boss * 0.5);
	ALPHA = clamp(glow, 0.0, 1.0);
}
