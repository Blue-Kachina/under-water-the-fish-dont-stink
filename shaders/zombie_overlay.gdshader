// Unnatural's zombie look (Horde): an overlay pass over each fish's baked
// SchoolLook mesh. Rot (a tint mixed over its own colours), red glowing eyes
// toward the head and a red rim, and per instance (INSTANCE_CUSTOM): r the hit
// flash (times hit_flash, so it can pass 1), g how far through dying it is (it
// fades), b elite (a hot glow), a a lunge's telegraph (a pulsing red, times
// telegraph_glow). `frozen` (0..1, the whole horde: the Hourglass)
// turns them icy.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

uniform vec4 rot_color : source_color = vec4(0.35, 0.45, 0.3, 1.0);
uniform float rot = 0.5;
uniform float eye_glow = 2.0;
uniform float frozen = 0.0;

varying vec4 custom;
varying float head;

void vertex() {
	custom = INSTANCE_CUSTOM;
	// A hair outside the fish's own surface, so the pass always wins the depth test.
	VERTEX += NORMAL * 0.015;
	// The nose is -z, the model about 1.2 m long: the front third glows.
	head = smoothstep(0.2, 0.55, -VERTEX.z) * step(0.0, VERTEX.y);
}

void fragment() {
	float glare = custom.r;  // the hit flash times hit_flash (may pass 1: a brighter glow)
	float flash = min(glare, 1.0);
	float dead = custom.g;
	float elite = custom.b;
	float warn = custom.a;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 red = vec3(1.0, 0.06, 0.03);
	vec3 ice = vec3(0.55, 0.85, 1.0);
	ALBEDO = mix(mix(rot_color.rgb, ice, frozen * 0.8), vec3(1.0), flash);
	ROUGHNESS = 0.9;
	EMISSION = red * eye_glow * (head * 0.8 + rim * 0.25)
			+ vec3(1.0, 0.85, 0.8) * glare * 2.5
			+ vec3(1.0, 0.35, 0.1) * elite * (0.4 + rim) * 1.5
			+ vec3(1.0, 0.05, 0.02) * warn * 4.0 * (1.0 - frozen)
			+ ice * frozen * (0.25 + rim * 1.5);
	ALPHA = clamp(rot + flash + warn + head * 0.5 + rim * 0.3 + frozen * 0.6, 0.0, 1.0) * (1.0 - dead);
}
