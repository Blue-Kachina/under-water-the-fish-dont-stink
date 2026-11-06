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
// The Titans' bend (FishModel.titan_motion; all 0 for everyone else, who keep the
// one even arc above). The span is split into `bend_shape.x` equal segments,
// each its own arc: bend_turn the first, bend_turn2 and bend_turn3 the next
// two, chained, so a beat travels down the body as a wave. In front of the
// bend, the head bends the other way over `bend_shape.y` m (bend_head.xyz, a
// rotation vector: + x lifts the nose), and everything moves forward by
// bend_head.w m (the surge of a power stroke).
instance uniform vec3 bend_turn2 : instance_index(5) = vec3(0.0);
instance uniform vec3 bend_turn3 : instance_index(6) = vec3(0.0);
instance uniform vec4 bend_head : instance_index(7) = vec4(0.0);
instance uniform vec2 bend_shape : instance_index(8) = vec2(0.0);

vec3 bend_rotate(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// One arc of the chain: `s` m into an arc `len` m long turning by rotation
// vector `r` overall, heading along `dir`: how far its spine has come (`move`)
// and how it has turned (`axis`, `turn`).
void bend_arc(vec3 r, float len, float s, vec3 dir, out vec3 move, out vec3 axis, out float turn) {
	float angle = length(r);
	if (angle < 1e-5 || len <= 0.0) {
		move = dir * s;
		axis = vec3(1.0, 0.0, 0.0);
		turn = 0.0;
		return;
	}
	axis = r / angle;
	turn = angle * s / len;
	float curve = angle / len;
	move = dir * sin(turn) / curve + cross(axis, dir) * (1.0 - cos(turn)) / curve;
}

void fish_bend(inout vec3 v, inout vec3 n) {
	float span = bend_span.y - bend_span.x;
	if (bend_shape.x < 1.5 && bend_head == vec4(0.0)) {
		// Every fish but a Titan: one even arc.
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
		return;
	}
	// A Titan: the chain behind, the head's counter-bend in front, the surge.
	vec3 start = vec3(0.0, 0.0, bend_span.x);
	if (v.z > bend_span.x && span > 0.0) {
		int count = clamp(int(bend_shape.x + 0.5), 1, 3);
		float seg = span / float(count);
		float s_all = min(v.z - bend_span.x, span);
		vec3 spine = start;
		vec3 local = vec3(v.xy, v.z - bend_span.x - s_all);
		// Walk the segments, then turn the slice by every turn so far, last first.
		vec3 axes[3];
		float turns[3];
		int used = 0;
		for (int j = 0; j < count; j++) {
			float s = clamp(s_all - float(j) * seg, 0.0, seg);
			if (s <= 0.0) {
				break;
			}
			vec3 r = j == 0 ? bend_turn : (j == 1 ? bend_turn2 : bend_turn3);
			vec3 move;
			vec3 axis;
			float turn;
			bend_arc(r, seg, s, vec3(0.0, 0.0, 1.0), move, axis, turn);
			for (int k = used - 1; k >= 0; k--) {
				move = bend_rotate(move, axes[k], turns[k]);
			}
			spine += move;
			axes[j] = axis;
			turns[j] = turn;
			used = j + 1;
		}
		for (int k = used - 1; k >= 0; k--) {
			local = bend_rotate(local, axes[k], turns[k]);
			n = bend_rotate(n, axes[k], turns[k]);
		}
		v = spine + local;
	} else if (v.z < bend_span.x && bend_shape.y > 0.0) {
		vec3 move;
		vec3 axis;
		float turn;
		float s = min(bend_span.x - v.z, bend_shape.y);
		bend_arc(bend_head.xyz, bend_shape.y, s, vec3(0.0, 0.0, -1.0), move, axis, turn);
		v = start + move + bend_rotate(vec3(v.xy, v.z - bend_span.x + s), axis, turn);
		n = bend_rotate(n, axis, turn);
	}
	v.z -= bend_head.w;
}
