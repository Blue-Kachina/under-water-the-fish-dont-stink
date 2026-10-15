shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
// The stride cue (stride_cue.gdshaderinc) over a plain tail part, as its
// material_overlay: how far along the tail a point is comes from where it sits
// in the tail pivot (FishModel._setup_tail_cue).

#include "res://shaders/stride_cue.gdshaderinc"

uniform mat4 to_pivot;  // the part's transform in the tail pivot
uniform float root = 0.0;  // the tail's front, z in the pivot (m)
uniform float tip = 0.3;  // the tail's back

varying float along;

void vertex() {
	float z = (to_pivot * vec4(VERTEX, 1.0)).z;
	along = (z - root) / max(tip - root, 0.001);
}

void fragment() {
	ALBEDO = stride_cue(along);
}
