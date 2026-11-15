// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// The water model's in-scatter (planning_abyssal_look.md, phase 2), in closed form: how much of the
// water's own colour a ray gathers on its way. Used by the sky now and by the surface later; the
// per-camera pass (water_fog_pass.gdshader) carries the same maths for the opaque world.
// All heights are relative to the water's surface (negative below it).

uniform vec3 wf_sig;      // extinction per metre (red, green, blue), already scaled by the density
uniform vec3 wf_k;        // KD / sun.y: how fast sunlight loses each colour per metre of height
uniform vec3 wf_wcol;     // the water's colour (times the in-scatter gain)
uniform vec3 wf_sun_dir;  // toward the sun
uniform vec2 wf_phase;    // forward phase: base, and the extra toward the sun

// Light scattered into a ray from `ro_y` (m, <0: below the surface) going `rd` for `d` metres.
vec3 wf_in(float ro_y, vec3 rd, float d, vec3 sig) {
	ro_y = min(ro_y, -0.5);
	float dd = d;
	if (rd.y > 1e-4) {
		dd = min(d, -ro_y / rd.y);  // the water ends at the surface
	}
	vec3 a = sig - wf_k * rd.y;
	vec3 integral;
	for (int i = 0; i < 3; i++) {
		integral[i] = abs(a[i]) < 1e-5 ? dd : (1.0 - exp(-a[i] * dd)) / a[i];
	}
	float mu = max(dot(rd, wf_sun_dir), 0.0);
	float m2 = mu * mu;
	float phase = wf_phase.x + wf_phase.y * m2 * m2;
	return wf_wcol * sig * exp(wf_k * ro_y) * integral * phase;
}
