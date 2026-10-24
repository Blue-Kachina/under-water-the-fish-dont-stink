// A final boss's body bent along its swim path (SpineRig, the final bosses):
// the mesh is built straight, its head at z 0 and its tail at z spine_length,
// x to its right and y up. Each vertex is moved to the path's point at its z,
// across that point's frame (spine_right, spine_up; the tailward direction is
// their cross product), so one seamless body follows every curve. The mesh
// node sits at the world's origin, unrotated, so this writes world positions.
//
// spine_wave adds a swimming undulation sideways (x m, y rad/m, z rad/s),
// growing from `w` of the way along to the tail. A vertex's flutter weight
// (UV2.y) ripples it sideways too: fins, filaments, barbels.

const int SPINE_N = 48;

uniform vec3 spine_pos[48];
uniform vec3 spine_right[48];
uniform vec3 spine_up[48];
uniform float spine_length = 60.0;
uniform vec4 spine_wave = vec4(0.0, 0.3, 2.0, 0.3);
uniform vec3 flutter = vec3(0.0, 1.2, 4.0);  // m at weight 1, rad/m, rad/s
uniform float flutter_phase = 0.0;

// Bends `v` (and `n`) from the rest shape onto the path. `weight`: flutter.
void spine_bend(inout vec3 v, inout vec3 n, float weight) {
	float z = clamp(v.z, 0.0, spine_length);
	float t = z / max(spine_length, 0.001) * float(SPINE_N - 1);
	int i = min(int(floor(t)), SPINE_N - 2);
	float f = t - float(i);
	vec3 p = mix(spine_pos[i], spine_pos[i + 1], f);
	vec3 r = normalize(mix(spine_right[i], spine_right[i + 1], f) + vec3(1e-5, 0.0, 0.0));
	vec3 u = normalize(mix(spine_up[i], spine_up[i + 1], f) + vec3(0.0, 1e-5, 0.0));
	vec3 b = normalize(cross(r, u));
	u = cross(b, r);
	float along = z / max(spine_length, 0.001);
	float side = spine_wave.x * smoothstep(spine_wave.w, 1.0, along) * sin(z * spine_wave.y - TIME * spine_wave.z);
	side += flutter.x * weight * sin(z * flutter.y + v.y * 0.6 - TIME * flutter.z + flutter_phase);
	float over = v.z - z;  // past either end: carried on straight
	vec3 world = p + r * (v.x + side) + u * v.y + b * over;
	n = normalize(r * n.x + u * n.y + b * n.z);
	v = world;
}
