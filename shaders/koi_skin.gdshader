shader_type spatial;
// A koi's skin (FishModel._build_koi): white, with patches of `albedo` (the
// colour set_body_color() tints) mostly over its back, a few ink spots, and the
// faint edges of its scales. Painted from the resting shape, so it never slides.

uniform vec4 albedo : source_color = vec4(0.93, 0.3, 0.07, 1.0);
uniform vec4 base_color : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform vec4 ink_color : source_color = vec4(0.07, 0.07, 0.09, 1.0);
uniform float pattern_scale = 5.0;  // patches per m, about
uniform float seed = 3.0;
uniform float scale_size = 0.035;  // m
uniform float girth = 0.12;  // m, about the body's radius, to lay the scales round it
uniform float scales_from = -0.4;  // z (m): the head in front of it has none

varying vec3 rest;
varying vec3 rest_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.1) + 0.15 * noise(p * 4.3);
}

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
}

void fragment() {
	// Patches over the back, fading out down the sides; the belly stays white.
	float back = smoothstep(-0.45, 0.35, rest_normal.y);
	float n = fbm(rest * pattern_scale + seed) * mix(0.6, 1.08, back);
	float aa = fwidth(n);
	float patch = smoothstep(0.5 - aa, 0.5 + aa, n);
	float m = fbm(rest * pattern_scale * 2.6 + seed + 11.0);
	float ink = smoothstep(0.72 - fwidth(m), 0.72 + fwidth(m), m) * back;
	vec3 color = mix(mix(base_color.rgb, albedo.rgb, patch), ink_color.rgb, ink);
	// Scales: offset rows of round-ended cells along and round the body, each a
	// touch darker at its trailing edge.
	vec2 s = vec2(rest.z, atan(rest.x, rest.y) * girth) / scale_size;
	s.y += 0.5 * mod(floor(s.x), 2.0);
	vec2 f = fract(s);
	float edge = smoothstep(0.32, 0.5, length(vec2(f.x * 0.75, f.y - 0.5)));
	color *= 1.0 - 0.1 * edge * smoothstep(scales_from, scales_from + 0.06, rest.z);
	ALBEDO = color;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
}
