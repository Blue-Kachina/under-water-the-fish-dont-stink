shader_type spatial;
// The Alchemists' sea hare skin (SeaHareModel): soft, slightly glossy slug skin
// painted in the model's own space, so the pattern sits still on the body.
// pattern 0: mottled (California: reds, browns and greens blotched together,
// with pale flecks); 1: dark rings on a pale body (Spotted); 2: mottled brown
// with bright blue spots (Ragged). The belly fades to belly_color.

uniform vec4 albedo : source_color = vec4(0.45, 0.22, 0.2, 1.0);
uniform vec4 second_color : source_color = vec4(0.3, 0.32, 0.15, 1.0);
uniform vec4 third_color : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform vec4 belly_color : source_color = vec4(0.55, 0.4, 0.38, 1.0);
uniform int pattern = 0;
uniform float seed = 1.0;
// Pattern cells per metre.
uniform float scale = 9.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;

varying vec3 local;
varying float facing_up;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + seed * 0.1);
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
	return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
}

// Distance to the nearest scattered point (a cell's), for rings and spots.
float cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 jitter = vec3(hash(i + o), hash(i + o + 7.1), hash(i + o + 13.7)) * 0.8 + 0.1;
		best = min(best, length(o + jitter - f));
	}
	return best;
}

void vertex() {
	local = VERTEX;
	facing_up = NORMAL.y;
}

void fragment() {
	vec3 p = local * scale;
	float blotch = fbm(p * 0.7);
	vec3 color = albedo.rgb;
	if (pattern == 1) {
		float d = cells(p * 0.8);
		color = mix(color, color * 0.85, smoothstep(0.4, 0.7, blotch));
		color = mix(color, second_color.rgb, smoothstep(0.07, 0.0, abs(d - 0.3)));
	} else {
		color = mix(color, second_color.rgb, smoothstep(0.42, 0.62, blotch));
		if (pattern == 2) {
			float d = cells(p * 1.1);
			color = mix(color, third_color.rgb, smoothstep(0.16, 0.1, d));
		} else {
			color = mix(color, third_color.rgb, step(0.93, noise(p * 3.0)) * 0.8);
		}
	}
	color = mix(color, belly_color.rgb, smoothstep(-0.2, -0.75, facing_up));
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.55;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
