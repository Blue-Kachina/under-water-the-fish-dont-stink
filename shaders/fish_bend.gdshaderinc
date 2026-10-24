// The body's bend into its tail (FishModel._bend_body), shared by every shader a
// body or a fin on it is drawn with, so the tail never comes away from the body.
// Behind `bend_span.x` the spine curves in an even arc, turning by `bend_turn`
// by `bend_span.y` (where the tail pivot sits), and everything past that turns
// with it. Each slice of the body turns with the spine, so its shape holds.
// FishModel.bend_point() does the same sum (keep in step) to carry the tail
// pivot and anything riding the bend.
//
// Per mesh (instance uniforms, set by FishModel for the meshes it bends), so a
// material shared with the tail's own fins leaves them alone (their pivot
// already swings). Off (all 0) for a baked school or horde fish.
//
// Call fish_bend(VERTEX, NORMAL) in vertex() after keeping the rest shape.
//
// The indices are pinned (stride_cue.gdshaderinc takes 2-4): left to the
// compiler they follow include order, so a mesh drawn with fin_membrane (stride
// cue first) and a skin disagreed, and Godot warned on every material
// re-gather. A horde look re-gathers whenever its visible count changes.

instance uniform vec3 bend_turn : instance_index(0) = vec3(0.0);  // rad, a rotation vector: x the tail tip down, y toward +X
instance uniform vec2 bend_span : instance_index(1) = vec2(0.0);  // z the bend starts at and the z it ends at

vec3 bend_rotate(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void fish_bend(inout vec3 v, inout vec3 n) {
	float span = bend_span.y - bend_span.x;
	float angle = length(bend_turn);
	if (span <= 0.0 || angle < 1e-5 || v.z <= bend_span.x) {
		return;
	}
	vec3 axis = bend_turn / angle;
	float s = min(v.z - bend_span.x, span);
	float turn = angle * s / span;
	float curve = angle / span;
	vec3 side = cross(axis, vec3(0.0, 0.0, 1.0));
	vec3 spine = vec3(0.0, 0.0, bend_span.x + sin(turn) / curve) + side * (1.0 - cos(turn)) / curve;
	v = spine + bend_rotate(vec3(v.xy, v.z - bend_span.x - s), axis, turn);
	n = bend_rotate(n, axis, turn);
}
