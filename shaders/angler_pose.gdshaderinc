// Shared by the Lantern Angler's skin (angler_skin.gdshader) and fins (angler_fin.gdshader): the shader-driven "bones" that turn
// parts of the rest shape before spine_bend lays it on the swim path (AnglerModel, angler_contract.md):
//   tail snap  `tail_bend` (rad at the tail's tip) turns everything behind `tail_from` about the vertical, eased in;
//   pectorals  each pectoral turns about the fore-aft line through its root (flap, + raises the tips) and fans back (sweep).
// Include after spine_bend.gdshaderinc (it needs spine_length).

uniform float k = 1.0;  // the body's scale over the design: patterns are painted in design metres
uniform float tail_from = 4.7;  // m, where the tail snap starts (its own scale)
uniform float tail_bend = 0.0;  // rad at the tip
uniform float tail_grow = 0.0;  // the stride's Battletoads swell: the tail's girth and the caudal fan grow by up to this much at the tip
uniform float pect_flap_l = 0.0;
uniform float pect_flap_r = 0.0;
uniform float pect_sweep = 0.0;
uniform vec3 pect_root = vec3(1.55, -0.2, 2.75);  // design m, the right fin's root (mirrored)

vec3 rot_about(vec3 v, vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void angler_pectoral(inout vec3 v, inout vec3 n) {
	float side = v.x >= 0.0 ? 1.0 : -1.0;
	vec3 root = vec3(side * pect_root.x, pect_root.y, pect_root.z) * k;
	float flap = (side > 0.0 ? pect_flap_r : pect_flap_l) * side;
	vec3 d = v - root;
	d = rot_about(d, vec3(0.0, 0.0, 1.0), flap);
	d = rot_about(d, vec3(0.0, 1.0, 0.0), -pect_sweep * side);
	v = root + d;
	n = rot_about(rot_about(n, vec3(0.0, 0.0, 1.0), flap), vec3(0.0, 1.0, 0.0), -pect_sweep * side);
}

void angler_tail(inout vec3 v, inout vec3 n) {
	if (tail_grow != 0.0 && v.z > tail_from) {
		float along = smoothstep(0.0, 1.0, (v.z - tail_from) / max(spine_length - tail_from, 0.001));
		v.xy *= 1.0 + tail_grow * along;
	}
	if (tail_bend != 0.0 && v.z > tail_from) {
		float span = max(spine_length - tail_from, 0.001);
		float s = v.z - tail_from;
		v.x += tail_bend * s * s / (2.0 * span);
		float slope = tail_bend * s / span;
		n = normalize(vec3(n.x + slope * n.z, n.y, n.z - slope * n.x));
	}
}
