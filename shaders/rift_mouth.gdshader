shader_type spatial;
render_mode unshaded, cull_disabled;
// The boss rift's mouth (BossRift): a flat plate lying over the crevice's
// opening, painted as if it were the hole. Each pixel's view ray is followed
// down into an imagined slot (half_size across, `depth` deep, narrowing as it
// goes): rock walls in strata, darker with depth, lit red from far below, a
// red glow at the bottom, and slow fog drifting up through it. The seabed
// can't have a real hole, so this is the hole.

uniform vec2 half_size = vec2(2.4, 0.9);
uniform float depth = 16.0;
// How much narrower the slot is at the bottom (0: straight walls).
uniform float taper : hint_range(0.0, 0.9) = 0.55;
uniform vec3 rock_color : source_color = vec3(0.2, 0.17, 0.16);
uniform vec3 glow_color : source_color = vec3(1.0, 0.1, 0.04);
uniform vec3 fog_color : source_color = vec3(0.75, 0.07, 0.04);
uniform float glow_energy = 4.0;
uniform float fog_density = 0.07;
// 0..1: the flare when it erupts (UnnaturalRun.wake_rift).
uniform float flare = 0.0;
// 0: lit and smoky; 1: gone cold (it's woken, or the boss came anyway).
uniform float spent = 0.0;

varying vec3 local_pos;
varying vec3 local_cam;

void vertex() {
	local_pos = VERTEX;
	local_cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The slot's half width (x, z) at height y (0 at the mouth, -depth at the bottom).
vec2 width_at(float y) {
	return half_size * (1.0 - taper * clamp(-y / depth, 0.0, 1.0));
}

void fragment() {
	vec3 ray = normalize(local_pos - local_cam);
	vec3 p = vec3(local_pos.x, 0.0, local_pos.z);
	vec3 col = vec3(0.0);
	if (ray.y < -0.001) {
		// March down until the ray leaves the narrowing slot (or reaches its floor).
		float t = 0.0;
		float steps = 48.0;
		float step_len = depth / steps / max(-ray.y, 0.12);
		vec3 hit = p;
		bool wall = false;
		for (int n = 0; n < 48; n++) {
			vec3 q = p + ray * (t + step_len);
			vec2 w = width_at(q.y);
			if (abs(q.x) > w.x || abs(q.z) > w.y || q.y < -depth) {
				wall = q.y >= -depth;
				// Refine the crossing a little.
				float lo = t;
				float hi = t + step_len;
				for (int k = 0; k < 5; k++) {
					float mid = (lo + hi) * 0.5;
					vec3 m = p + ray * mid;
					vec2 wm = width_at(m.y);
					if (abs(m.x) > wm.x || abs(m.z) > wm.y || m.y < -depth) {
						hi = mid;
					} else {
						lo = mid;
					}
				}
				t = hi;
				break;
			}
			t += step_len;
		}
		hit = p + ray * t;
		float down = clamp(-hit.y / depth, 0.0, 1.0);
		// Rock: horizontal strata and lumps, darker into cracks.
		float strata = noise(vec3(hit.x * 0.6, hit.y * 3.5, hit.z * 0.6));
		float lumps = noise(hit * 2.3) * 0.6 + noise(hit * 6.1) * 0.4;
		vec3 rock = rock_color * (0.45 + 0.75 * lumps) * (0.75 + 0.5 * strata);
		// Daylight from the mouth fades fast; the red from below grows.
		float daylight = exp(-down * 6.0) * 0.9;
		float red = pow(down, 1.2) * glow_energy * (1.0 - spent * 0.9);
		col = rock * daylight + rock * glow_color * red * (wall ? 1.0 : 1.6);
		if (!wall) {
			col += glow_color * glow_energy * 0.6 * (0.6 + 0.4 * noise(vec3(hit.xz * 1.5, TIME * 0.4))) * (1.0 - spent * 0.9);
		}
		// Fog drifting up the slot: thicker deeper, slowly churning.
		float drift = noise(vec3(hit.x * 0.7, hit.y * 0.5 - TIME * 0.35, hit.z * 0.7 + TIME * 0.05));
		float fog = 1.0 - exp(-t * fog_density * (0.6 + 0.8 * drift));
		col = mix(col, fog_color * (0.3 + 0.9 * down) * (1.0 + flare * 3.0) * (1.0 - spent * 0.8), fog);
		col += glow_color * flare * 2.0 * down;
	}
	// The rim softly darkens (the lip's shadow over the edge).
	vec2 edge = abs(local_pos.xz) / half_size;
	float rim = smoothstep(0.75, 1.0, max(edge.x, edge.y));
	ALBEDO = col * (1.0 - rim * 0.6);
}
