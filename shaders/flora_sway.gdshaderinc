// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Flora sway (planning_abyssal_look.md, flora pass): the current's push on a point `h` m above the ground, shared by the blades and
// the glints that ride on them. Two slow waves, the amplitude growing as h^1.25, so a 10 m strand swings metres while a 30 cm tuft
// barely moves. `amount` is the panel's sway multiplier.

vec2 flora_sway(vec2 p, float h, float t, float amount) {
	float ph = dot(p, vec2(0.031, 0.017));
	float a = 0.024 * pow(max(h, 0.0), 1.25) * amount;
	return a * (vec2(sin(t * 0.5 + ph + h * 0.09), cos(t * 0.37 + ph * 1.3 + h * 0.07))
			+ 0.35 * vec2(sin(t * 1.3 + ph * 3.0 + h * 0.3), cos(t * 1.1 + ph * 2.0 + h * 0.23)));
}
