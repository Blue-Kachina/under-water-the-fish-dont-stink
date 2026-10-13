shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// A thin fin (FishModel._membrane): UV.x runs along its root, UV.y from the root
// (0) out to its edge (1). It ripples out of its plane, more toward the edge and
// harder the faster the fish swims, and goes see-through toward the edge with
// its rays showing.

uniform vec4 albedo : source_color = vec4(1.0);  // at the root
uniform vec4 edge_color : source_color = vec4(1.0);
uniform vec4 ray_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform float rays = 12.0;  // across the fin
uniform float edge_alpha = 0.45;
uniform float flutter = 0.02;  // m at the edge, idling
uniform float waves = 1.2;  // from the root out to the edge
uniform float tempo = 1.0;  // how fast it ripples, against the swim
uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out

void vertex() {
	float a = TAU * waves * UV.y + UV.x * 2.5 - phase * tempo;
	VERTEX += NORMAL * flutter * (1.0 + 1.5 * effort) * UV.y * UV.y * sin(a);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float out_part = smoothstep(0.15, 1.0, UV.y);
	vec3 color = mix(albedo.rgb, edge_color.rgb, out_part);
	float across = UV.x * rays;
	float ray = abs(fract(across + 0.5) - 0.5);  // 0 on a ray
	float width = fwidth(across);
	ray = 1.0 - smoothstep(0.04 + width, 0.1 + width * 2.0, ray);
	color = mix(color, ray_color.rgb, ray * 0.55 * (1.0 - 0.6 * out_part));
	ALBEDO = color;
	ALPHA = mix(1.0, edge_alpha, out_part);
	ROUGHNESS = 0.35;
	BACKLIGHT = color * 0.5;
}
