// A zombie's death in Unnatural (KillPops, the Playability pass P3): a camera-facing
// burst where it died, in its rot colour (INSTANCE COLOR) warmed toward blood-orange. A white core that flashes
// and goes, a ring racing out, and sparks flying out along a few lanes. Per instance
// (INSTANCE_CUSTOM): r how far through its life (0 to 1), g elite (hotter, more
// sparks), b a seed (each burst's lanes differ). Additive and unshaded: it only
// ever brightens.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

varying vec4 custom;
varying vec4 tint;

void vertex() {
	custom = INSTANCE_CUSTOM;
	tint = COLOR;
	// Face the camera, keeping the instance's size.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float t = clamp(custom.r, 0.0, 1.0);
	float elite = custom.g;
	float seed = custom.b;
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fade = 1.0 - t;
	// The core: a flash at the start.
	float core = smoothstep(0.55, 0.0, r) * (1.0 - smoothstep(0.0, 0.3, t));
	// The ring, racing out and thinning.
	float ring_at = mix(0.12, 0.92, sqrt(t));
	float ring = smoothstep(0.1 * fade + 0.02, 0.0, abs(r - ring_at)) * fade * 0.8;
	// Sparks: dashes along a few lanes, each lane its own speed.
	float lanes = mix(7.0, 12.0, elite);
	float around = (atan(p.y, p.x) / 6.2831853 + 0.5) * lanes + seed * 13.0;
	float lane = floor(around);
	float thin = 1.0 - smoothstep(0.0, 0.16, abs(fract(around) - 0.5));
	float spark_at = mix(0.2, 1.0, t) * (0.65 + 0.35 * hash(lane + seed));
	float spark = thin * smoothstep(0.12, 0.0, abs(r - spark_at)) * fade * step(0.3, hash(lane * 3.7 + seed));
	// Its rot colour warmed toward blood-orange, so it reads against the red water.
	vec3 hot = mix(mix(tint.rgb * 1.5, vec3(1.0, 0.42, 0.22), 0.55), vec3(1.0, 0.78, 0.3), elite * 0.6) * 1.6;
	vec3 color = hot * (ring + spark * 1.4) + vec3(1.0, 0.95, 0.9) * core * 1.5;
	ALBEDO = color;
	ALPHA = clamp(core + ring + spark, 0.0, 1.0) * step(r, 1.0);
}
