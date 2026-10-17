shader_type spatial;
// A pearl's aura (Pearl): a soft glowing shell, brightest at its rim, that
// breathes slowly. Added on top of what's behind it, so it reads through the fog.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec4 glow : source_color = vec4(0.85, 0.95, 1.0, 1.0);
// 0..1, the pearl's fade (lifetime, absorbing).
uniform float strength = 1.0;
uniform float pulse_rate = 1.6;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float breathe = 0.75 + 0.25 * sin(TIME * pulse_rate * 6.2832);
	float glow_amount = (pow(rim, 1.6) * 0.9 + 0.15) * breathe * strength;
	ALBEDO = glow.rgb * glow_amount;
	ALPHA = glow_amount;
}
