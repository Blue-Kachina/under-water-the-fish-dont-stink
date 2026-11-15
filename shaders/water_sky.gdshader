// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// The Ocean modes' sky (planning_abyssal_look.md, phase 2): the water model looked through
// `ws_distance` m along the view ray, so up is bright, down is dark, and it matches the per-camera
// fog on the geometry exactly (no seam where the fog ends and the sky begins).
shader_type sky;

#include "res://shaders/water_fog.gdshaderinc"

uniform vec3 ws_sig = vec3(0.03, 0.012, 0.0099);  // the extinction the sky sees (the density scale may be thinner here: murk_sky)
uniform float ws_distance = 240.0;
uniform float ws_gain = 1.0;
uniform float ws_surface_y = 40.0;
uniform float ws_ref_depth = 28.0;  // the depth the reflection cubemap is made at (it has no camera)

void sky() {
	float ro_y = AT_CUBEMAP_PASS ? -ws_ref_depth : POSITION.y - ws_surface_y;
	COLOR = wf_in(ro_y, EYEDIR, ws_distance, ws_sig) * ws_gain;
}
