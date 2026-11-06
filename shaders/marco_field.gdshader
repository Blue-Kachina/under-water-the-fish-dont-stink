shader_type particles;
// The Marco! scan's torus field (MarcoScan): particles streaming along the
// field lines of a horn torus round the caller, a magnet's field. In through
// the pinched centre going up, out over the top, down round the outside and
// back in from below, fastest through the middle. Each particle keeps to one
// of `lines` field lines on one of three nested shells, so they read as
// flowing streams, not a cloud. Drawn by marco_scan.gdshader's kind 2.

uniform float size = 1.0;  // the torus's radius (m), grown with the scan
uniform float speed = 1.6;
uniform float lines = 40.0;
uniform float glow = 1.0;
uniform float fade = 1.0;
uniform float dot_size = 0.12;
uniform vec4 color : source_color = vec4(0.4, 1.0, 0.75, 1.0);

float hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void start() {
	uint seed = INDEX * 7919u + 17u;
	CUSTOM.x = (floor(hash(seed) * lines) + (hash(seed + 1u) - 0.5) * 0.08) / lines * TAU;
	CUSTOM.y = hash(seed + 2u) * TAU;
	CUSTOM.z = 0.4 + 0.3 * floor(hash(seed + 3u) * 3.0);
	CUSTOM.w = hash(seed + 4u);
}

void process() {
	// Horn torus: tube radius = ring radius, so the hole closes to a point.
	float r = 0.5 * CUSTOM.z;
	float ring = r + r * cos(CUSTOM.y);
	CUSTOM.y -= DELTA * speed * (0.3 / (ring + 0.1)) * (0.8 + 0.4 * CUSTOM.w);
	ring = r + r * cos(CUSTOM.y);
	vec3 at = vec3(ring * cos(CUSTOM.x), r * sin(CUSTOM.y), ring * sin(CUSTOM.x)) * size;
	float scale = dot_size * (0.6 + 0.8 * CUSTOM.w);
	TRANSFORM = mat4(vec4(scale, 0.0, 0.0, 0.0), vec4(0.0, scale, 0.0, 0.0), vec4(0.0, 0.0, scale, 0.0), vec4(at, 1.0));
	float core = 1.0 - smoothstep(0.0, 0.3, ring);
	COLOR = vec4(mix(color.rgb, vec3(1.0), core * 0.7), clamp((0.3 + 0.7 * core) * glow * fade, 0.0, 1.0));
}
