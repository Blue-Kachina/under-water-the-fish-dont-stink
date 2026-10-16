shader_type canvas_item;
// Extra Swishy's arcade vignette (ArcadeFx): the screen's edges darken and close
// in as flow builds, warming to gold at the corners near full flow, with faint
// speed streaks rushing outward when you're flying. `flash` brightens the rim
// for a moment on a perfect stride.

uniform float strength = 0.0;  // 0..1: how far in and how dark
uniform float heat = 0.0;  // 0 cool to 1 gold at the corners
uniform float streaks = 0.0;  // 0..1
uniform float flash = 0.0;  // 0..1
uniform float aspect = 1.7778;
uniform vec4 cool : source_color = vec4(0.0, 0.04, 0.1, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.72, 0.25, 1.0);

void fragment() {
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(c) / length(vec2(aspect, 1.0) * 0.5);  // 0 centre, 1 corner
	float edge = smoothstep(mix(0.9, 0.5, strength), 1.1, r);
	vec3 color = mix(cool.rgb, hot.rgb, heat * smoothstep(0.55, 1.0, r));
	float alpha = edge * (0.2 + 0.6 * strength);

	// Speed streaks: thin rays, a few lanes lit, dashes running outward.
	float lanes = atan(c.y, c.x) / TAU * 140.0;
	float lane = floor(lanes);
	float pick = fract(sin(lane * 12.9898) * 43758.5453);
	float thin = 1.0 - smoothstep(0.0, 0.18, abs(fract(lanes) - 0.5));
	float dash = smoothstep(0.55, 1.0, fract(r * 1.6 - TIME * (1.2 + pick) + pick * 7.0));
	float streak = thin * dash * step(0.86, pick) * smoothstep(0.45, 0.85, r) * streaks;

	color = mix(color, vec3(1.0), streak * 0.7 + flash * 0.4 * edge);
	COLOR = vec4(color, clamp(alpha + streak * 0.35 + flash * 0.25 * edge, 0.0, 1.0));
}
