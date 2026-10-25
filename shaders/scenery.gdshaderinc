// Shared by the seabed's scenery (planning_environment.md): world-space value
// noise, fbm and a bump from its gradient, so pieces need no UVs and copies
// never repeat.

float sc_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float sc_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(sc_hash(i), sc_hash(i + vec3(1, 0, 0)), f.x), mix(sc_hash(i + vec3(0, 1, 0)), sc_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(sc_hash(i + vec3(0, 0, 1)), sc_hash(i + vec3(1, 0, 1)), f.x), mix(sc_hash(i + vec3(0, 1, 1)), sc_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float sc_fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += sc_noise(p) * amp;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return sum;
}

// A bumped world normal: `n` tilted down the gradient of fbm(p * scale).
vec3 sc_bump(vec3 p, vec3 n, float scale, float strength) {
	float e = 0.35 / scale;
	float h = sc_fbm(p * scale);
	vec3 g = vec3(sc_fbm((p + vec3(e, 0, 0)) * scale) - h, sc_fbm((p + vec3(0, e, 0)) * scale) - h,
			sc_fbm((p + vec3(0, 0, e)) * scale) - h) / (e * scale);  // the noise's own slope, whatever its scale
	g -= n * dot(g, n);
	return normalize(n - g * strength);
}

// Growth on scenery: algae on what faces up, a pink coralline crust low down
// and in patches. Returns the mix (rgb) and how much grew (a).
vec4 sc_growth(vec3 p, vec3 n, float low, float algae, float coralline) {
	float up = smoothstep(0.25, 0.85, n.y);
	float patchy = smoothstep(0.38, 0.62, sc_fbm(p * 0.45 + 4.0));
	float green = up * patchy * algae;
	vec3 algae_color = mix(vec3(0.14, 0.24, 0.09), vec3(0.3, 0.36, 0.12), sc_noise(p * 3.0));
	float crust = clamp((1.0 - smoothstep(0.0, 0.25, low)) * 0.7 + smoothstep(0.66, 0.76, sc_fbm(p * 0.8 + 11.0)) * 0.5, 0.0, 1.0);
	crust *= coralline * smoothstep(0.3, 0.6, sc_noise(p * 2.2 + 3.0));
	vec3 crust_color = mix(vec3(0.58, 0.42, 0.44), vec3(0.72, 0.56, 0.58), sc_noise(p * 6.0));
	vec3 color = mix(algae_color, crust_color, crust / max(crust + green, 0.001));
	return vec4(color, clamp(green + crust, 0.0, 1.0));
}

// Light bounced up off the sand onto what faces down or sideways: warm, so
// undersides aren't lit only by the blood moon's red ambient.
vec3 sc_bounce(vec3 albedo, vec3 n, float amount) {
	return albedo * vec3(0.5, 0.42, 0.32) * amount * clamp(0.6 - n.y * 0.6, 0.0, 1.0);
}
