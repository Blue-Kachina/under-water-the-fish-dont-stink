// Shared by the jellyfish shaders (JellyModel): the bell's pulsation. The bell
// (its apex at z = bell_apex, its rim bell_depth m behind it, nose -Z) takes
// the shape BellPulse gives it each frame: +1 contracted (the power stroke's
// tall, narrow dome, its rim drawn down and in), 0 as built, -1 expanded (the
// recovery stroke's wide, flat umbrella, its rim flaring out). The crown
// (`bell_crown`) and the margin (`bell_margin`) are shaped apart and blended
// down the bell, so its edge bends rather than the bell scaling, and the margin
// ripples as it moves (`bell_ripple`). Past the rim (the rim tentacles)
// everything moves as the rim does, spreading from a flared rim and bunching
// under a shut one.

uniform float phase = 0.0;  // advances as it swims
uniform float effort = 0.0;  // 0 idling to 1 flat out
uniform float bell_apex = -0.6;  // the bell's front, z (m)
uniform float bell_depth = 0.5;  // apex to rim (m)
uniform float bell_crown = 0.0;  // the crown's shape, -1 open .. +1 shut
uniform float bell_margin = 0.0;  // the margin's
uniform float bell_ripple = 0.0;  // 0..1, how hard the margin ripples
uniform float bell_ripple_phase = 0.0;  // rad, the ripple wave's travel
uniform float bell_squeeze = 1.0;  // how hard the shut shape is (Gait.bell_squeeze)
uniform float bell_flatten = 1.0;  // how wide the open one is (Gait.bell_flatten)

// `v` (model space, at rest) in the bell's shape now.
vec3 jelly_pulse(vec3 v) {
	float rim_z = bell_apex + bell_depth;
	float f = clamp((v.z - bell_apex) / bell_depth, 0.0, 1.0);  // apex 0 .. rim 1
	float beyond = min(max(v.z - rim_z, 0.0) / bell_depth, 1.5);
	float s = mix(bell_crown, bell_margin, smoothstep(0.2, 0.95, f));
	float shut = max(s, 0.0) * bell_squeeze;
	float open = max(-s, 0.0) * bell_flatten;
	float w = smoothstep(0.7, 1.0, f);  // the margin
	float w2 = w * w;
	float theta = atan(v.y, v.x + 1e-5);
	float wave = bell_ripple_phase - f * 9.0 + 0.6 * sin(theta * 4.0 + bell_ripple_phase * 0.37);
	// Narrower down the bell as it shuts, the margin tucking in; wider as it
	// opens, the margin flaring out.
	float scale = 1.0 - shut * (0.24 * pow(f, 1.3) + 0.12 * w2) + open * (0.2 * pow(f, 0.8) + 0.1 * w2);
	scale += bell_ripple * 0.035 * w * sin(wave);
	// Deeper as it shuts, the rim drawn back; flatter as it opens, the rim
	// lifting level with the crown.
	float dz = (min(v.z, rim_z) - bell_apex) * (0.3 * shut - 0.3 * open);
	dz += bell_depth * (0.05 * shut * w - 0.05 * open * w2);
	dz += bell_ripple * 0.05 * bell_depth * w * cos(wave);
	scale *= 1.0 + beyond * (0.22 * open - 0.15 * shut);
	v.xy *= max(scale, 0.2);
	v.z += dz;
	return v;
}

// The normal `n` at `v` (at rest) carried into the bell's shape now.
vec3 jelly_pulse_normal(vec3 v, vec3 n) {
	vec3 other = abs(n.z) < 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 t1 = normalize(cross(n, other));
	vec3 t2 = cross(n, t1);  // cross(t1, t2) is n, so the result faces as n did
	float e = 0.004;
	vec3 p = jelly_pulse(v);
	vec3 m = cross(jelly_pulse(v + t1 * e) - p, jelly_pulse(v + t2 * e) - p);
	return length(m) > 1e-9 ? normalize(m) : n;
}
