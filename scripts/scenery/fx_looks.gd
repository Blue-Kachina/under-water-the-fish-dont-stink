class_name FxLooks
extends RefCounted
## Modelled looks for things that were plain shapes (planning_environment.md,
## Phase 6): the drops' tokens (a puffy heart, a horseshoe magnet, an
## hourglass, a lightning bolt), the treasure chest's body, lid and bands,
## and the bosses' spat bolts. Each built once (MeshKit) and cached.

static var _cache := {}


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var kit: MeshKit = build.call()
		_cache[key] = kit.mesh()
	return _cache[key]


# --- Drops ------------------------------------------------------------------

## A puffy heart about 0.6 m across, facing +Z.
static func heart() -> ArrayMesh:
	return _cached("heart", func() -> MeshKit:
		var kit := MeshKit.new()
		kit.surface(64, 16, func(u: float, v: float) -> Array:
			var t := u * TAU
			var hx := 16.0 * pow(sin(t), 3.0)
			var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			var phi := lerpf(-PI / 2.0, PI / 2.0, v)
			var k := cos(phi)
			var outline := Vector2(hx, hy + 2.0) * 0.018
			return [Vector3(outline.x * (0.25 + 0.75 * k), outline.y * (0.25 + 0.75 * k) + 0.02, sin(phi) * 0.13), 0.0, 0.0], true, false, false)
		return kit)


## A horseshoe magnet: [the red bend, the silver tips].
static func magnet() -> Array[ArrayMesh]:
	var bend := _cached("magnet_bend", func() -> MeshKit:
		var kit := MeshKit.new()
		var path := PackedVector3Array()
		for n in 17:
			var a := PI * n / 16.0
			path.append(Vector3(cos(a) * 0.22, sin(a) * 0.22 - 0.02, 0.0))
		path.insert(0, Vector3(0.22, -0.16, 0.0))
		path.append(Vector3(-0.22, -0.16, 0.0))
		kit.tube(path, PackedFloat32Array([0.075]), 14)
		return kit)
	var tips := _cached("magnet_tips", func() -> MeshKit:
		var kit := MeshKit.new()
		for side: float in [-1.0, 1.0]:
			kit.tube(PackedVector3Array([Vector3(side * 0.22, -0.16, 0.0), Vector3(side * 0.22, -0.3, 0.0)]), PackedFloat32Array([0.078]), 14)
		return kit)
	return [bend, tips]


## An hourglass: [the brass frame, the glass, the sand].
static func hourglass() -> Array[ArrayMesh]:
	var frame := _cached("hourglass_frame", func() -> MeshKit:
		var kit := MeshKit.new()
		for y: float in [-0.3, 0.27]:
			var cap := MeshKit.new()
			cap.lathe(PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.23, 0.01), Vector2(0.23, 0.025), Vector2(0.2, 0.035)]), 24)
			kit.merge(cap, Transform3D(Basis(), Vector3(0.0, y, 0.0)))
		for n in 3:
			var a := TAU * n / 3.0
			var x := Vector3(cos(a), 0.0, sin(a)) * 0.19
			kit.tube(PackedVector3Array([x + Vector3(0, -0.27, 0), x + Vector3(0, 0.0, 0) * 0.98, x + Vector3(0, 0.27, 0)]), PackedFloat32Array([0.014]), 8)
		return kit)
	var glass := _cached("hourglass_glass", func() -> MeshKit:
		var kit := MeshKit.new()
		var profile := PackedVector2Array()
		for n in 21:
			var t := n / 20.0
			var y := lerpf(-0.27, 0.27, t)
			profile.append(Vector2(0.025 + 0.13 * pow(absf(t * 2.0 - 1.0), 0.7), y))
		kit.lathe(profile, 24)
		return kit)
	var sand := _cached("hourglass_sand", func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.13, -0.26), Vector2(0.09, -0.19), Vector2(0.01, -0.13)]), 20)
		kit.lathe(PackedVector2Array([Vector2(0.02, 0.05), Vector2(0.08, 0.12), Vector2(0.11, 0.17)]), 20)
		return kit)
	return [frame, glass, sand]


## A lightning bolt: a bevelled zigzag, about 0.7 m tall, facing +Z.
static func bolt() -> ArrayMesh:
	return _cached("bolt", func() -> MeshKit:
		var outline := PackedVector2Array([Vector2(0.06, 0.36), Vector2(0.2, 0.36), Vector2(0.06, 0.06), Vector2(0.18, 0.06),
				Vector2(-0.14, -0.38), Vector2(-0.02, -0.04), Vector2(-0.14, -0.04)])
		var count := outline.size()
		var kit := MeshKit.new()
		# Round the outline: front face, bevel, back face (v), then caps.
		kit.surface(count * 6, 6, func(u: float, v: float) -> Array:
			var f := u * count
			var i := floori(f) % count
			var p := outline[i].lerp(outline[(i + 1) % count], f - floori(f))
			var phi := lerpf(-PI / 2.0, PI / 2.0, v)
			var inward := -p.normalized() * (1.0 - cos(phi)) * 0.03
			return [Vector3(p.x + inward.x, p.y + inward.y, sin(phi) * 0.06), 0.0, 0.0], true, true, true)
		return kit)


# --- Chests -------------------------------------------------------------------

## A chest's body `size` (open-topped box of planks, standing on y 0).
static func chest_body(size: Vector3) -> ArrayMesh:
	return _cached("chest_body_%s" % size, func() -> MeshKit:
		var kit := GreekKit.block(Vector3(size.x, size.y * 0.6, size.z), 77)
		return kit)


## A chest's barrel lid: half a cylinder along x, `size.x` long, `size.z`
## deep, hinged at its back edge (origin), lying closed along +Z.
static func chest_lid(size: Vector3) -> ArrayMesh:
	return _cached("chest_lid_%s" % size, func() -> MeshKit:
		var kit := MeshKit.new()
		var r := size.z * 0.5
		kit.surface(32, 2, func(u: float, v: float) -> Array:
			var a := u * TAU
			var x := lerpf(-size.x * 0.5, size.x * 0.5, v)
			var round_y := maxf(sin(a), 0.0) * size.y * 0.7 + 0.01
			return [Vector3(x, round_y, r - cos(a) * r), 0.0, 0.0], true, true, true, 0.0, true)  # round x, the other way to a lathe
		return kit)


## The chest's metal: two bands over the body and lid, studs and a lock plate.
static func chest_trim(size: Vector3) -> ArrayMesh:
	return _cached("chest_trim_%s" % size, func() -> MeshKit:
		var kit := MeshKit.new()
		for x: float in [-0.32, 0.32]:
			kit.merge(GreekKit.block(Vector3(0.08, size.y * 0.62, size.z + 0.04), 80), Transform3D(Basis(), Vector3(x * size.x, -0.005, 0.0)))
			for corner: float in [-1.0, 1.0]:
				var stud := MeshKit.new()
				stud.lathe(GreekKit._sphere_profile(0.025, 4), 8)
				kit.merge(stud, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x * size.x, size.y * 0.45, corner * (size.z * 0.5 + 0.02))))
		for corner: float in [-1.0, 1.0]:
			kit.merge(GreekKit.block(Vector3(0.06, size.y * 0.62, 0.06), 81), Transform3D(Basis(), Vector3(corner * size.x * 0.5, -0.005, size.z * 0.5)))
			kit.merge(GreekKit.block(Vector3(0.06, size.y * 0.62, 0.06), 82), Transform3D(Basis(), Vector3(corner * size.x * 0.5, -0.005, -size.z * 0.5)))
		return kit)


## The lid's bands and lock plate (moving with the lid; lid space).
static func chest_lid_trim(size: Vector3) -> ArrayMesh:
	return _cached("chest_lid_trim_%s" % size, func() -> MeshKit:
		var kit := MeshKit.new()
		var r := size.z * 0.5 + 0.02
		for x: float in [-0.32, 0.32]:
			# A band over the lid's curve only.
			kit.surface(24, 1, func(u: float, v: float) -> Array:
				var a := u * PI
				var px := x * size.x + (v - 0.5) * 0.08
				return [Vector3(px, sin(a) * size.y * 0.72 + 0.012, r - 0.02 - cos(a) * r), 0.0, 0.0], false, false, false, 0.0, true)
		var lock := GreekKit.block(Vector3(0.2, 0.22, 0.05), 83)
		kit.merge(lock, Transform3D(Basis(), Vector3(0.0, -0.1, size.z + 0.02)))
		return kit)


# --- Boss bolts ------------------------------------------------------------------

## A shard of rotting scale, about 1 m: a curved, pointed, ridged leaf.
static func scale_shard() -> ArrayMesh:
	return _cached("scale_shard", func() -> MeshKit:
		var kit := MeshKit.new()
		for face: float in [1.0, -1.0]:
			kit.surface(16, 10, func(u: float, v: float) -> Array:
				var w := sin(v * PI) * (1.0 - v * 0.4) * 0.45
				var x := (u * 2.0 - 1.0) * w
				var bow := (1.0 - pow(u * 2.0 - 1.0, 2.0)) * 0.12 + v * v * 0.15
				var ridge := 0.02 * absf(sin(u * 18.0))
				return [Vector3(x, (v - 0.5) * 1.1, bow + ridge * face + face * 0.025), 0.0, 0.0], false, false, false, 0.0, face > 0.0)
		return kit)


## A lumpy gob (bile, a blood clot): a noisy blob about 1 m across.
static func gob(seed_value: int) -> ArrayMesh:
	return _cached("gob_%d" % seed_value, func() -> MeshKit:
		var kit := MeshKit.new()
		var noise := FastNoiseLite.new()
		noise.seed = seed_value
		noise.frequency = 1.6
		kit.surface(24, 14, func(u: float, v: float) -> Array:
			var lat := lerpf(-PI / 2.0, PI / 2.0, v)
			var d := Vector3(cos(lat) * cos(u * TAU), sin(lat), cos(lat) * sin(u * TAU))
			var r := 0.5 + noise.get_noise_3dv(d * 1.2) * 0.18
			return [d * r, 0.0, 0.0], true, false, false)
		return kit)
