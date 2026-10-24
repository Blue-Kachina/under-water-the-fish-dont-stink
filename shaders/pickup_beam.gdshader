// A drop's beam of light in Unnatural (Pickup, the Playability pass P3): a soft
// column of its colour standing up from it, which ignores the fog so you can
// spot a heart or a bolt through the murk. Brightest at its foot, it fades out past `far` m from the camera and when the camera's right
// on top of it.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float strength = 0.6;
uniform float far = 110.0;
// The column's height (m): its mesh is centred on its middle.
uniform float height = 6.0;

varying float rise_at;

void vertex() {
	rise_at = VERTEX.y / max(height, 0.01) + 0.5;
}

void fragment() {
	float up = clamp(rise_at, 0.0, 1.0);
	float d = length(VERTEX);
	float rise = pow(1.0 - up, 1.6);
	// Brighter at its edges seen side on: a tube of light, not a solid rod.
	float rim = 0.45 + 0.55 * pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float shimmer = 0.85 + 0.15 * sin(TIME * 3.0 + up * 9.0);
	float reach = (1.0 - smoothstep(far * 0.6, far, d)) * smoothstep(1.5, 5.0, d);
	ALBEDO = color.rgb;
	ALPHA = clamp(strength * rise * rim * shimmer * reach, 0.0, 1.0);
}
