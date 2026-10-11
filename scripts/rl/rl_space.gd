class_name RLSpace
## Rocket League's space <-> Godot's. RL: uu (1 uu = 1 cm), +X left, +Y toward
## the orange goal, +Z up, left-handed. Godot: metres, Y up, right-handed.
##
## Swapping Y and Z converts between them. It's a reflection, which turns RL's
## left-handed frame right-handed without mirroring the arena: facing +Z in
## Godot, +X is on your left, as in RL. Angular velocity is a pseudovector, so
## it also changes sign. Blue defends RL -Y, which is Godot -Z (the opposite of
## the Aquarium, where Blue defends +Z; replay playback turns the replay round,
## see ReplayData). Same mapping as tests/physics_parity_probe.gd.

const M_PER_UU := 0.01


static func length(uu: float) -> float:
	return uu * M_PER_UU


## A position, velocity or acceleration.
static func pos(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, v.y) * M_PER_UU


## A direction (no change of units).
static func dir(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, v.y)


static func ang_vel(w: Vector3) -> Vector3:
	return -Vector3(w.x, w.z, w.y)


## The fish's basis for a car with RL rotation `q` (xyzw, as replays store it),
## which turns RL's car frame (X forward, Y right, Z up) into the arena. The
## fish's +X is its right, +Y its up and -Z its nose.
static func fish_basis(q: Quaternion) -> Basis:
	q = q.normalized()
	var forward := dir(q * Vector3(1.0, 0.0, 0.0))
	var right := dir(q * Vector3(0.0, 1.0, 0.0))
	var up := dir(q * Vector3(0.0, 0.0, 1.0))
	return Basis(right, up, -forward)


## An offset in RL's car frame (forward, right, up; uu), in the fish's local frame (m).
static func car_offset(v: Vector3) -> Vector3:
	return Vector3(v.y, v.z, -v.x) * M_PER_UU


static func to_rl_pos(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, p.y) / M_PER_UU


static func to_rl_ang_vel(w: Vector3) -> Vector3:
	return -Vector3(w.x, w.z, w.y)
