// Shared by the lofted fish skins (shark_skin, sword_skin, clown_skin): value
// noise for patterns painted from the resting shape, and faint scale rows.

float skin_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float skin_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(skin_hash(i), skin_hash(i + vec3(1, 0, 0)), f.x), mix(skin_hash(i + vec3(0, 1, 0)), skin_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(skin_hash(i + vec3(0, 0, 1)), skin_hash(i + vec3(1, 0, 1)), f.x), mix(skin_hash(i + vec3(0, 1, 1)), skin_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float skin_fbm(vec3 p) {
	return 0.55 * skin_noise(p) + 0.3 * skin_noise(p * 2.1) + 0.15 * skin_noise(p * 4.3);
}

// How much of a scale's trailing edge `rest` is on, 0..1: offset rows of
// round-ended cells `size` m along and round a body about `girth` m round.
float skin_scales(vec3 rest, float size, float girth) {
	vec2 s = vec2(rest.z, atan(rest.x, rest.y) * girth) / size;
	s.y += 0.5 * mod(floor(s.x), 2.0);
	vec2 f = fract(s);
	return smoothstep(0.32, 0.5, length(vec2(f.x * 0.75, f.y - 0.5)));
}
