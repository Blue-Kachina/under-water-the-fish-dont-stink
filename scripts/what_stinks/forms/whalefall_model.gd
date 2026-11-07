extends RefCounted
## The Whale Fall as a Hunter's body (what_stinks.md section 2): WhaleFallBoss._build_look taken out of the
## boss (it welds to UnnaturalRun) and shrunk to a playable carcass. One rigid BossMesh of a dead whale on
## its side with the boss's own skin (boss_whale.gdshader: torn chest, flank wound, empty eye sockets,
## blowhole), the hagfish's rest mesh, and the holes the hagfish come out of. Built in the boss's own girth
## unit (k 1: its skin shader has metres in it); WhaleFallRig scales it down to the hitbox, and the
## controller's body_scale then scales that to the form's length like every other form.
## Head at z -LENGTH/2, tail at +LENGTH/2 once placed by `xf` (the boss faces -z).

const SKIN := preload("res://shaders/boss_whale.gdshader")
## The carcass's length (k 1: leviathan_girth 6 x 7.5, as the boss) and its roll onto its side (rad).
const LENGTH := 45.0
const ROLL := 1.75
## A hagfish's rope length and girth (the boss's hagfish_length is 22; a little longer here to reach the cone).
const HAG_LENGTH := 26.0
const HAG_RADIUS := HAG_LENGTH * 0.055


## The look: {mesh, skin, xf, exits: [[rest point, rest outward direction]] in the carcass's own space (apply xf), hag_mesh}.
static func build() -> Dictionary:
	var k := 1.0
	var length := LENGTH
	var xf := Transform3D(Basis(Vector3.BACK, ROLL), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -length * 0.5))
	var profile := func(a: float) -> Vector4:
		var t := BossMesh.taper(a, 0.3, 0.1, 0.35, false)
		var head := 1.0 - smoothstep(0.0, 0.3, a)
		var stock := smoothstep(0.75, 0.95, a)
		var hw := 3.7 * k * t * lerpf(1.0, 1.25, head) * lerpf(1.0, 0.55, stock)
		var hh := 3.3 * k * t * lerpf(1.0, 0.68, head) * lerpf(1.0, 1.3, stock)
		var close := sqrt(maxf(1.0 - pow(maxf(a - 0.97, 0.0) / 0.03, 2.0), 0.0))
		return Vector4(hw * close, hh * close, -hh * 0.08 * head, 2.0)
	var mesh := BossMesh.new(length)
	# Throat pleats under the jaw, and the bloat of a body weeks dead.
	var pleats := func(a: float, angle: float) -> float:
		var throat := smoothstep(0.65, 1.0, -cos(angle)) * (1.0 - smoothstep(0.34, 0.44, a))
		var groove := pow(0.5 + 0.5 * sin(angle * 30.0), 4.0)
		return 1.0 - 0.03 * groove * throat + 0.025 * sin(a * 37.0 + angle * 3.0) * sin(angle * 5.0 + a * 11.0)
	mesh.loft(0.0, length, profile, 200, 60, BossMesh.BODY, Callable(), 0.0, pleats)
	# The ribs, bared where its chest is torn open, and the spine behind them.
	for i in 7:
		var z := lerpf(0.37, 0.56, i / 6.0) * length
		var slice: Vector4 = profile.call(z / length)
		var reach := 0.6 if i == 2 else (0.9 if i == 5 else 1.25)
		var path := PackedVector3Array()
		for j in 16:
			var phi := lerpf(-1.25, reach, j / 15.0)
			path.append(Vector3(slice.x * 0.88 * cos(phi), slice.z + slice.y * 0.88 * sin(phi), z))
		mesh.tube(path, func(_t: float) -> float: return 0.3 * k, 7, BossMesh.BONE)
	var spine := PackedVector3Array()
	for j in 20:
		var z := lerpf(0.3, 0.66, j / 19.0) * length
		var slice: Vector4 = profile.call(z / length)
		spine.append(Vector3(0.0, slice.z + slice.y * 0.5, z))
	mesh.tube(spine, func(t: float) -> float: return (0.55 + 0.12 * sin(t * 60.0)) * k, 8, BossMesh.BONE)
	# Baleen along the upper jaw, hanging into the mouth.
	for side: float in [-1.0, 1.0]:
		mesh.membrane(func(u: float) -> Vector3:
				var z := lerpf(0.03, 0.24, u) * length
				var slice: Vector4 = profile.call(z / length)
				return Vector3(side * slice.x * 0.86, slice.z - slice.y * 0.18, z),
			func(u: float) -> Vector3: return Vector3(0.0, -1.3 * k * sin(u * PI * 0.9 + 0.1), 0.0),
			60, 3, Vector2.ZERO, BossMesh.EXTRA)
	# Flippers and flukes.
	for side: float in [-1.0, 1.0]:
		var slice: Vector4 = profile.call(0.27)
		mesh.blob(Vector3(side * slice.x * 0.96, slice.z - slice.y * 0.42, 0.27 * length), Vector3(2.5, 0.24, 0.7) * k,
				Basis(Vector3.UP, side * 0.5) * Basis(Vector3.BACK, -side * 0.45), 8, 14, BossMesh.FIN)
		mesh.blob(Vector3(side * 2.7 * k, 0.0, length - 0.9 * k), Vector3(3.7, 0.32, 1.4) * k, Basis(Vector3.UP, -side * 0.5), 8, 14, BossMesh.FIN)
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	var chest: Vector4 = profile.call(0.46)
	var eye_slice: Vector4 = profile.call(0.2)
	var eye_y := eye_slice.z - eye_slice.y * 0.1
	skin.set_shader_parameter("cavity", Vector4(0.46 * length, chest.z, 0.1 * length, chest.y * 0.55))
	skin.set_shader_parameter("wound", Vector4(0.62 * length, 0.3 * k, 2.3 * k, 1.7 * k))
	skin.set_shader_parameter("eye", Vector3(0.2 * length, eye_y, 0.95 * k))
	skin.set_shader_parameter("blowhole", Vector3(0.17 * length, 0.0, 0.8 * k))
	skin.set_shader_parameter("length_m", length)
	# Where the hagfish come out, each a little inside its hole: eye sockets, torn chest, flank wound, blowhole.
	var eye_x: float = eye_slice.x
	var c1: Vector4 = profile.call(0.43)
	var c2: Vector4 = profile.call(0.5)
	var w: Vector4 = profile.call(0.62)
	var b: Vector4 = profile.call(0.17)
	var exits := [
		[Vector3(eye_x * 0.75, eye_y, 0.2 * length), Vector3(1.0, 0.0, -0.2)],
		[Vector3(-eye_x * 0.75, eye_y, 0.2 * length), Vector3(-1.0, 0.0, -0.2)],
		[Vector3(c1.x * 0.5, c1.z + c1.y * 0.3, 0.43 * length), Vector3(1.0, 0.3, 0.0)],
		[Vector3(c2.x * 0.5, c2.z - c2.y * 0.25, 0.5 * length), Vector3(1.0, -0.15, 0.2)],
		[Vector3(-w.x * 0.7, 0.3 * k, 0.62 * length), Vector3(-1.0, 0.25, 0.1)],
		[Vector3(0.0, b.z + b.y * 0.8, 0.17 * length), Vector3(0.0, 1.0, -0.3)],
	]
	return {"mesh": mesh.commit(), "skin": skin, "xf": xf, "exits": exits, "hag_mesh": WhaleFallBoss._hagfish_mesh(HAG_LENGTH, HAG_RADIUS)}
