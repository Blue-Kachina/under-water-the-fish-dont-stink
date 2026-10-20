// Shared by the jellyfish shaders (JellyModel): the bell's swim pulse. The
// bell (its apex at z = bell_apex, its rim bell_depth m behind it, nose -Z)
// squeezes in from the rim and relaxes again once a beat (`phase`, from the
// swim), harder the faster it swims (`effort`). The rim tentacles ride the rim
// with it: past the rim everything moves as the rim does.

uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out
uniform float bell_apex = -0.6;  // the bell's front, z (m)
uniform float bell_depth = 0.5;  // apex to rim (m)
uniform float pulse = 0.09;  // how far the rim squeezes in, of its radius

// How squeezed the bell is now, 0..pulse: a quick contraction, a slow relax.
float jelly_contraction() {
	float x = fract(phase / TAU);
	float c = x < 0.3 ? smoothstep(0.0, 0.3, x) : 1.0 - smoothstep(0.3, 1.0, x);
	return c * pulse * (0.55 + 0.9 * effort);
}

// `v` (model space, at rest) with the bell squeezed by `c`: the rim most, the apex
// not at all, and the rim drawn back a little as the bell deepens.
vec3 jelly_pulse(vec3 v, float c) {
	float f = clamp((v.z - bell_apex) / bell_depth, 0.0, 1.0);
	float squeeze = c * f * sqrt(f);
	v.xy *= 1.0 - squeeze;
	v.z += c * 0.3 * bell_depth * f * f;
	return v;
}
