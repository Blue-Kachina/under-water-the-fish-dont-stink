class_name WornKit
extends RefCounted
## The looks powerups put on the fish (Powerup.make_worn; planning_environment.md,
## Phase 6), as smooth single meshes instead of stacked spheres, cones and tori:
## shells that really spiral, tubes that taper and curl, gems with facets.
## Each built once (MeshKit) and cached by its key. Sizes in metres, about
## what the old looks were, so each item's placement on the fish still fits.

static var _cache := {}


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var kit: MeshKit = build.call()
		_cache[key] = kit.mesh()
	return _cache[key]


static func _path(count: int, at: Callable) -> PackedVector3Array:
	var points := PackedVector3Array()
	for n in count:
		points.append(at.call(n / float(count - 1)))
	return points


static func _radii(count: int, at: Callable) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for n in count:
		values.append(at.call(n / float(count - 1)))
	return values


## A smooth ball `radius` m, centred.
static func ball(radius: float) -> ArrayMesh:
	return _cached("ball/%.3f" % radius, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(GreekKit._sphere_profile(radius, 10), 16, Callable(), false, false)
		kit.transform(0, Transform3D(Basis(), Vector3(0.0, -radius, 0.0)))
		return kit)


## A cut gem `radius` m: a faceted crown over a pointed pavilion, centred.
static func gem(radius: float) -> ArrayMesh:
	return _cached("gem/%.3f" % radius, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.001, -radius * 1.1), Vector2(radius, 0.0), Vector2(radius * 0.92, radius * 0.25),
				Vector2(radius * 0.55, radius * 0.45)]), 8, Callable(), false, true)
		return kit)


## A ring `radius` m round (in the x-z plane), `thick` m through.
static func ring(radius: float, thick: float) -> ArrayMesh:
	return _cached("ring/%.3f/%.3f" % [radius, thick], func() -> MeshKit:
		var kit := MeshKit.new()
		var path := _path(41, func(t: float) -> Vector3: return Vector3(cos(t * TAU), 0.0, sin(t * TAU)) * radius)
		kit.tube(path, PackedFloat32Array([thick * 0.5]), 8, false, false)
		return kit)


## A coiled shell (an ammonite, a nautilus): a tube spiralling out in the
## y-z plane, seen from the side, about `size` m across.
static func spiral_shell(size: float) -> ArrayMesh:
	return _cached("spiral/%.3f" % size, func() -> MeshKit:
		var kit := MeshKit.new()
		var turns := 2.6
		var path := _path(60, func(t: float) -> Vector3:
			var a := t * turns * TAU
			var r := size * 0.42 * exp((t - 1.0) * 2.2)
			return Vector3(0.0, sin(a) * r, cos(a) * r))
		var radii := _radii(60, func(t: float) -> float: return size * 0.2 * exp((t - 1.0) * 2.2) + 0.002)
		kit.tube(path, radii, 10, true, false)
		return kit)


## A tall conical spiral shell (a hermit crab's), its mouth at the bottom:
## a cone whose whorls bulge between a spiral suture.
static func cone_shell(size: float) -> ArrayMesh:
	return _cached("cone_shell/%.3f" % size, func() -> MeshKit:
		var kit := MeshKit.new()
		var profile := PackedVector2Array()
		for n in 25:
			var t := n / 24.0
			profile.append(Vector2(size * 0.32 * pow(1.0 - t, 0.9) + 0.002, t * size))
		kit.lathe(profile, 24, func(angle: float, v: float) -> float:
			var whorl := fposmod(angle / TAU + v * 4.0, 1.0)
			return 0.82 + 0.18 * sin(whorl * PI), true, false)
		return kit)


## A crystal: a hexagonal prism with a pointed tip, `tall` m, standing on y 0.
static func crystal(tall: float, width: float) -> ArrayMesh:
	return _cached("crystal/%.3f/%.3f" % [tall, width], func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(width * 0.8, 0.0), Vector2(width, tall * 0.15), Vector2(width, tall * 0.72),
				Vector2(0.001, tall)]), 6, Callable(), true, false)
		return kit)


## A cluster of crystals (frost, a blood-moon shard) leaning out from a point.
static func crystals(count: int, tall: float, width: float, seed_value: int) -> ArrayMesh:
	return _cached("crystals/%d/%.3f/%.3f/%d" % [count, tall, width, seed_value], func() -> MeshKit:
		var kit := MeshKit.new()
		var dice := RandomNumberGenerator.new()
		dice.seed = seed_value
		for n in count:
			var piece := MeshKit.new()
			var h := tall * dice.randf_range(0.55, 1.0)
			piece.lathe(PackedVector2Array([Vector2(width * 0.8, 0.0), Vector2(width, h * 0.15), Vector2(width, h * 0.72), Vector2(0.001, h)]), 6,
					Callable(), true, false)
			var lean := Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, dice.randf_range(0.0, 0.6) if n > 0 else 0.0)
			kit.merge(piece, Transform3D(lean, Vector3(dice.randf_range(-1, 1), 0.0, dice.randf_range(-1, 1)) * width * 0.6))
		return kit)


## A tapering tentacle, `length` m, curling up and over from the origin.
static func tentacle(length: float, thick: float, curl := 2.5) -> ArrayMesh:
	return _cached("tentacle/%.3f/%.3f/%.2f" % [length, thick, curl], func() -> MeshKit:
		var kit := MeshKit.new()
		var path := _path(16, func(t: float) -> Vector3:
			return Vector3(sin(t * curl) * length * 0.4, t * length * 0.8, -(1.0 - cos(t * curl)) * length * 0.3))
		kit.tube(path, _radii(16, func(t: float) -> float: return thick * (1.0 - t * 0.85)), 8, false, true)
		return kit)


## A fish-like body (a ghost swordfish, a remora, a lamprey) along -Z (its
## nose), `length` m long, `girth` m at its widest; `bill`: a swordfish's bill.
static func fish_body(length: float, girth: float, bill := 0.0, sucker := false) -> ArrayMesh:
	return _cached("fish/%.3f/%.3f/%.3f/%s" % [length, girth, bill, sucker], func() -> MeshKit:
		var kit := MeshKit.new()
		var path := _path(14, func(t: float) -> Vector3: return Vector3(0.0, sin(t * PI) * girth * 0.15, lerpf(-length * 0.5, length * 0.5, t)))
		kit.tube(path, _radii(14, func(t: float) -> float:
				return girth * 0.5 * pow(sin(minf(t * 1.15, 1.0) * PI * 0.92 + 0.08), 0.8) + 0.002), 10, true, true)
		if bill > 0.0:
			kit.tube(PackedVector3Array([Vector3(0.0, 0.0, -length * 0.45), Vector3(0.0, 0.0, -length * 0.5 - bill)]),
					PackedFloat32Array([girth * 0.12, 0.002]), 6, false, false)
		# A forked tail.
		for side: float in [-1.0, 1.0]:
			kit.tube(PackedVector3Array([Vector3(0.0, 0.0, length * 0.45), Vector3(0.0, side * girth * 0.7, length * 0.5 + girth * 0.6)]),
					PackedFloat32Array([girth * 0.12, 0.004]), 6, false, false)
		if sucker:
			var disc := MeshKit.new()
			disc.lathe(PackedVector2Array([Vector2(girth * 0.45, 0.0), Vector2(girth * 0.4, girth * 0.08), Vector2(0.001, girth * 0.05)]), 14)
			kit.merge(disc, Transform3D(Basis(), Vector3(0.0, girth * 0.42, -length * 0.1)))
		return kit)


## A ribbon `length` m long and `width` wide waving along +Z (two-sided).
static func streamer(length: float, width: float) -> ArrayMesh:
	return _cached("streamer/%.3f/%.3f" % [length, width], func() -> MeshKit:
		var kit := MeshKit.new()
		kit.surface(2, 20, func(u: float, v: float) -> Array:
			var x := (u - 0.5) * width * (1.0 - v * 0.5)
			return [Vector3(x + sin(v * 9.0) * 0.04, cos(v * 7.0) * 0.03 * v, v * length), 0.0, 0.0], false, false, false)
		return kit)


## A bow of ribbon: two loops, a knot and two tails (two-sided).
static func bow() -> ArrayMesh:
	return _cached("bow", func() -> MeshKit:
		var kit := MeshKit.new()
		for side: float in [-1.0, 1.0]:
			kit.surface(1, 24, func(u: float, v: float) -> Array:
				var a := v * TAU
				var p := Vector3(side * (0.13 - cos(a) * 0.13), sin(a) * 0.07 + side * 0.0, (u - 0.5) * 0.09)
				p.y *= 1.0 + 0.3 * (1.0 - cos(a))
				return [p, 0.0, 0.0], false, false, false)
			kit.surface(1, 8, func(u: float, v: float) -> Array:
				return [Vector3(side * v * 0.08, -v * 0.14, (u - 0.5) * 0.07 * (1.0 - v * 0.3)), 0.0, 0.0], false, false, false)
		var knot := MeshKit.new()
		knot.lathe(GreekKit._sphere_profile(0.045, 6), 12, Callable(), false, false)
		kit.merge(knot, Transform3D(Basis().scaled(Vector3(1.0, 1.2, 0.8)), Vector3(0.0, -0.05, 0.0)))
		return kit)


## A copper coil: a rod with a spring wound round it, `tall` m.
static func coil(tall: float) -> ArrayMesh:
	return _cached("coil/%.3f" % tall, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.0, tall, 0.0)]), PackedFloat32Array([0.02, 0.014]), 8)
		var helix := _path(60, func(t: float) -> Vector3:
			var a := t * 5.0 * TAU
			return Vector3(cos(a) * 0.045, tall * (0.15 + t * 0.6), sin(a) * 0.045))
		kit.tube(helix, PackedFloat32Array([0.008]), 6, true, true)
		return kit)


## An eel wound round the fish: a helix `radius` m round, over `length` m,
## tapering to its tail, its head a rounded end.
static func eel(radius: float, length: float) -> ArrayMesh:
	return _cached("eel/%.2f/%.2f" % [radius, length], func() -> MeshKit:
		var kit := MeshKit.new()
		var path := _path(70, func(t: float) -> Vector3:
			var a := t * 1.7 * TAU
			return Vector3(cos(a) * radius, sin(a) * radius, lerpf(-length * 0.5, length * 0.5, t)))
		kit.tube(path, _radii(70, func(t: float) -> float: return 0.045 * (1.0 - t * 0.8) * minf(1.0, 0.6 + t * 8.0)), 10, true, true)
		return kit)


## A ring of teeth: a dark band with cone teeth pointing in, `radius` m round, in the x-y plane.
static func toothed_ring(radius: float) -> ArrayMesh:
	return _cached("teeth/%.3f" % radius, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.tube(_path(41, func(t: float) -> Vector3: return Vector3(cos(t * TAU), sin(t * TAU), 0.0) * radius), PackedFloat32Array([0.025]), 8,
				false, false)
		for n in 14:
			var a := TAU * n / 14.0
			var out := Vector3(cos(a), sin(a), 0.0)
			kit.tube(PackedVector3Array([out * radius, out * (radius - 0.07) + Vector3(0, 0, -0.02)]), PackedFloat32Array([0.018, 0.001]), 5, false, false)
		return kit)


## A barnacle: a ridged volcano with a crater, `width` m round.
static func barnacle(width: float, tall: float) -> ArrayMesh:
	return _cached("barnacle/%.3f/%.3f" % [width, tall], func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(width, 0.0), Vector2(width * 0.75, tall * 0.6), Vector2(width * 0.45, tall),
				Vector2(width * 0.3, tall * 0.85), Vector2(0.001, tall * 0.55)]), 12,
				func(angle: float, _v: float) -> float: return 1.0 + 0.08 * absf(sin(angle * 3.0)), false, false)
		return kit)


## A seahorse: a curled-tail body with a crest, a long-snouted head, `tall` m.
static func seahorse(tall: float) -> ArrayMesh:
	return _cached("seahorse/%.3f" % tall, func() -> MeshKit:
		var kit := MeshKit.new()
		var body := _path(24, func(t: float) -> Vector3:
			if t < 0.35:  # the tail, curling forward under
				var a := (0.35 - t) / 0.35 * PI * 1.4
				return Vector3(0.0, -tall * 0.25 - sin(a) * tall * 0.15, cos(a) * tall * 0.12 - tall * 0.12)
			var s := (t - 0.35) / 0.65
			return Vector3(0.0, -tall * 0.25 + s * tall * 0.8, -sin(s * PI) * tall * 0.12))
		kit.tube(body, _radii(24, func(t: float) -> float: return tall * 0.11 * pow(sin(clampf(t * 1.05, 0.0, 1.0) * PI * 0.85 + 0.1), 1.2) + 0.003), 10,
				true, true)
		var head := body[23]
		kit.tube(PackedVector3Array([head, head + Vector3(0.0, -tall * 0.04, -tall * 0.28)]), PackedFloat32Array([tall * 0.06, tall * 0.025]), 8,
				false, true)
		return kit)


## A lantern: a brass base and cap with a hoop over it: [the brass, the glass].
static func lantern() -> Array[ArrayMesh]:
	var brass := _cached("lantern_brass", func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.09, -0.07), Vector2(0.095, -0.05), Vector2(0.075, -0.03)]), 16)
		kit.lathe(PackedVector2Array([Vector2(0.08, 0.17), Vector2(0.09, 0.18), Vector2(0.05, 0.23), Vector2(0.015, 0.25)]), 16)
		kit.tube(_path(16, func(t: float) -> Vector3: return Vector3(cos(t * PI) * 0.045, 0.25 + sin(t * PI) * 0.06, 0.0)), PackedFloat32Array([0.008]),
				6, false, false)
		for n in 4:
			var a := TAU * n / 4.0 + PI / 4.0
			var x := Vector3(cos(a), 0.0, sin(a)) * 0.075
			kit.tube(PackedVector3Array([x + Vector3(0, -0.03, 0), x + Vector3(0, 0.17, 0)]), PackedFloat32Array([0.007]), 5, false, false)
		return kit)
	var glass := _cached("lantern_glass", func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.065, -0.03), Vector2(0.075, 0.07), Vector2(0.065, 0.17)]), 16)
		return kit)
	return [brass, glass]


## A sonar dish on a stalk: a shallow bowl and its receiver.
static func dish() -> ArrayMesh:
	return _cached("dish", func() -> MeshKit:
		var kit := MeshKit.new()
		kit.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.14, 0.0)]), PackedFloat32Array([0.014, 0.011]), 6)
		var bowl := MeshKit.new()
		bowl.surface(20, 6, func(u: float, v: float) -> Array:
			var a := u * TAU
			var r := v * 0.1
			return [Vector3(cos(a) * r, r * r * 4.0, sin(a) * r), 0.0, 0.0], true, false, false)
		bowl.tube(PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.07, 0.0)]), PackedFloat32Array([0.006, 0.004]), 5, false, true)
		kit.merge(bowl, Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(0.0, 0.15, -0.02)))
		return kit)


## A rolled map tied with a cord, along x, `long` m.
static func scroll(long: float) -> ArrayMesh:
	return _cached("scroll/%.3f" % long, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.035, -long * 0.5), Vector2(0.05, -long * 0.48), Vector2(0.045, -long * 0.4),
				Vector2(0.045, long * 0.4), Vector2(0.05, long * 0.48), Vector2(0.035, long * 0.5)]), 14,
				func(angle: float, _v: float) -> float: return 1.0 + 0.12 * fposmod(angle / TAU * 3.0, 1.0), true, true)
		kit.transform(0, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))
		kit.tube(_path(14, func(t: float) -> Vector3: return Vector3(0.0, cos(t * TAU) * 0.052, sin(t * TAU) * 0.052)), PackedFloat32Array([0.006]), 5,
				false, false)
		return kit)


## A conch shell: a spiral cone with knobs, its mouth at the origin, along +Y.
static func conch(tall: float) -> ArrayMesh:
	return _cached("conch/%.3f" % tall, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.005, -tall * 0.1), Vector2(tall * 0.3, tall * 0.1), Vector2(tall * 0.34, tall * 0.4),
				Vector2(tall * 0.2, tall * 0.75), Vector2(0.004, tall)]), 16,
				func(angle: float, v: float) -> float: return 1.0 + 0.18 * maxf(sin(angle * 6.0 + v * 9.0), 0.0) * v, true, false)
		return kit)


## A torpedo tube: an open barrel with a rim, along +Y, `long` m.
static func barrel_tube(long: float, radius: float) -> ArrayMesh:
	return _cached("barrel/%.3f/%.3f" % [long, radius], func() -> MeshKit:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(radius * 0.9, -long * 0.5), Vector2(radius, -long * 0.45), Vector2(radius, long * 0.4),
				Vector2(radius * 1.15, long * 0.44), Vector2(radius * 1.15, long * 0.5), Vector2(radius * 0.8, long * 0.5),
				Vector2(radius * 0.8, long * 0.3)]), 16, Callable(), true, true)
		return kit)


## A shark's tooth: a flat, serrated triangle, its point down, `tall` m.
static func tooth(tall: float) -> ArrayMesh:
	return _cached("tooth/%.3f" % tall, func() -> MeshKit:
		var kit := MeshKit.new()
		kit.surface(30, 6, func(u: float, v: float) -> Array:
			var a := u * TAU
			var x := sin(a) * tall * 0.38 * (0.55 + 0.45 * cos(a))
			var y := -cos(a) * tall * 0.5 + tall * 0.1
			var serrate := 1.0 + 0.04 * sin(a * 40.0)
			var phi := lerpf(-PI / 2.0, PI / 2.0, v)
			return [Vector3(x * serrate * (0.3 + 0.7 * cos(phi)), y * (0.6 + 0.4 * cos(phi)), sin(phi) * tall * 0.07), 0.0, 0.0], true, false, false, 0.0, true)  # its outline runs the other way to the heart's
		return kit)
