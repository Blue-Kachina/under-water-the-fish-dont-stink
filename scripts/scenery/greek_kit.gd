class_name GreekKit
extends RefCounted
## Ancient Greek pieces for the seabed (planning_environment.md, Phase 3):
## fluted Doric column drums, capitals, blocks, round steps, pots, draped
## statues and their attributes, and a bronze brazier. Each is built once
## (MeshKit) and cached by its key, with LODs. Marble and bronze are
## shared materials (stone.gdshader, bronze.gdshader).
##
## Units are metres; pieces stand on y = 0, facing +Z.

const FLUTES := 20
## A Doric column's lower radius and height (m), as the shrines' are.
const COLUMN_RADIUS := 0.3
const COLUMN_HEIGHT := 3.6

static var _meshes := {}
static var _marble: ShaderMaterial
static var _bronze: ShaderMaterial
static var _rock: ShaderMaterial


static func marble() -> ShaderMaterial:
	if _marble == null:
		_marble = ShaderMaterial.new()
		_marble.shader = preload("res://shaders/stone.gdshader")
	return _marble


## Reef rock: the same stone shader, darker, no veins.
static func rock() -> ShaderMaterial:
	if _rock == null:
		_rock = ShaderMaterial.new()
		_rock.shader = preload("res://shaders/stone.gdshader")
		_rock.set_shader_parameter("base_color", Vector3(0.36, 0.33, 0.3))
		_rock.set_shader_parameter("base_color_b", Vector3(0.24, 0.23, 0.22))
		_rock.set_shader_parameter("vein_strength", 0.0)
		_rock.set_shader_parameter("pitting", 0.8)
		_rock.set_shader_parameter("roughness_base", 0.85)
		_rock.set_shader_parameter("algae", 0.7)
		_rock.set_shader_parameter("coralline", 0.35)
		_rock.set_shader_parameter("bump_strength", 0.45)
		_rock.set_shader_parameter("bump_scale", 1.6)
	return _rock


static func bronze() -> ShaderMaterial:
	if _bronze == null:
		_bronze = ShaderMaterial.new()
		_bronze.shader = preload("res://shaders/bronze.gdshader")
	return _bronze


## The mesh `key` (built by `build` the first time), with LODs and `material`.
static func cached(key: String, build: Callable, material: Material) -> ArrayMesh:
	if not _meshes.has(key):
		var kit: MeshKit = build.call()
		_meshes[key] = kit.mesh(true, material)
	return _meshes[key]


# --- Shapes ----------------------------------------------------------------

## A Doric flute round the way: 0 on an arris, 1 in a hollow's middle.
static func flute(angle: float, flutes := FLUTES) -> float:
	var t := fposmod(angle / TAU * flutes, 1.0) * 2.0 - 1.0
	return 1.0 - t * t


## A superellipse's radius scale at `angle` (power 2: a circle; 6+: a
## rounded square).
static func squarish(angle: float, power: float) -> float:
	var c := absf(cos(angle))
	var s := absf(sin(angle))
	return pow(pow(c, power) + pow(s, power), -1.0 / power)


## Smoothly between keyed values: `keys` is [[t, value], ...] sorted by t.
static func keyed(keys: Array, t: float) -> Variant:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var k := smoothstep(0.0, 1.0, (t - a[0]) / maxf(b[0] - a[0], 0.0001))
			return lerp(a[1], b[1], k)
	return keys[-1][1]


static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return noise


# --- Columns ---------------------------------------------------------------

## A column drum: fluted, tapering a little (entasis), `height` m tall.
## `broken`: its top is a jagged break (a fresh, pale face).
static func drum(height: float, radius := COLUMN_RADIUS, broken := false, seed_value := 0, kit: MeshKit = null) -> MeshKit:
	kit = kit if kit else MeshKit.new()
	var noise := _noise(seed_value, 1.8)
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var depth := radius * 0.07
	var tilt := dice.randf_range(0.0, TAU)
	kit.surface(FLUTES * 4, maxi(roundi(height * 3.0), 2), func(u: float, v: float) -> Array:
		var angle := u * TAU
		var top := height
		if broken:
			top = height * (0.82 + 0.12 * cos(angle - tilt)) + noise.get_noise_2d(cos(angle) * 3.0, sin(angle) * 3.0) * radius * 0.6
		var y := top * v
		var r := radius * (1.0 - 0.06 * y / COLUMN_HEIGHT) * (1.0 - depth / radius * flute(angle))
		r += noise.get_noise_3d(cos(angle) * 4.0, y * 2.0, sin(angle) * 4.0) * radius * 0.03  # weathered
		return [Vector3(cos(angle) * r, y, sin(angle) * r), flute(angle) * 0.5, 0.0],
			true, true, true, 0.85 if broken else 0.15)
	return kit


## A Doric capital: the cushion (echinus) under a square slab (abacus).
static func capital(radius := COLUMN_RADIUS, seed_value := 0, kit: MeshKit = null) -> MeshKit:
	kit = kit if kit else MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var top := radius * 1.0
	var echinus := PackedVector2Array([Vector2(radius * 0.95, 0.0), Vector2(radius * 0.97, top * 0.12), Vector2(radius * 0.92, top * 0.16),
			Vector2(radius * 1.0, top * 0.22), Vector2(radius * 1.25, top * 0.42), Vector2(radius * 1.42, top * 0.56), Vector2(radius * 1.46, top * 0.62)])
	kit.lathe(echinus, 40, Callable(), true, false)
	var slab := radius * 1.5
	kit.lathe(PackedVector2Array([Vector2(slab, top * 0.62), Vector2(slab, top), ]), 40, func(angle: float, _v: float) -> float:
		return squarish(angle + PI / 4.0, 10.0), true, true)
	return kit


## A whole standing column (shaft and capital) `height` m tall.
static func column(height := COLUMN_HEIGHT, seed_value := 0) -> MeshKit:
	var kit := drum(height - COLUMN_RADIUS, COLUMN_RADIUS, false, seed_value)
	var cap := capital(COLUMN_RADIUS * 0.94, seed_value + 1)
	kit.merge(cap, Transform3D(Basis(), Vector3(0.0, height - COLUMN_RADIUS, 0.0)))
	return kit


## A fallen column: drums lying offset along +X, as one piece.
static func fallen_column(drums := 4, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var x := 0.0
	for n in drums:
		var tall := dice.randf_range(0.7, 1.1)
		var piece := drum(tall, COLUMN_RADIUS * (1.0 - 0.02 * n), n == drums - 1, seed_value + n)
		var lay := Basis(Vector3.BACK, -PI / 2.0) * Basis(Vector3.UP, dice.randf() * TAU)
		lay = Basis(Vector3.UP, dice.randf_range(-0.15, 0.15)) * lay
		kit.merge(piece, Transform3D(lay, Vector3(x, COLUMN_RADIUS * 0.9, dice.randf_range(-0.15, 0.15))))
		x += tall + dice.randf_range(0.02, 0.25)
	return kit


# --- Blocks and steps --------------------------------------------------------

## A dressed block `size` (centred on x and z, standing on y 0), chipped at
## its edges; `grooves`: the Doric frieze's triglyph grooves on its front.
static func block(size: Vector3, seed_value := 0, grooves := false, kit: MeshKit = null) -> MeshKit:
	kit = kit if kit else MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var noise := _noise(seed_value, 2.2)
	var rows := 8
	# A rounded box as a lathe of a superellipse, stretched to `size`.
	kit.surface(48, rows, func(u: float, v: float) -> Array:
		var angle := u * TAU + PI / 4.0
		var y := v
		var round_off := 1.0 - pow(absf(v * 2.0 - 1.0), 8.0) * 0.06
		var r := squarish(angle, 12.0) * round_off
		var p := Vector3(cos(angle) * r * size.x * 0.5, y * size.y, sin(angle) * r * size.z * 0.5)
		var corner := pow(absf(cos(angle) * sin(angle)) * 2.0, 4.0) + pow(absf(v * 2.0 - 1.0), 6.0)
		var chip := minf(noise.get_noise_3d(p.x * 3.0, p.y * 3.0, p.z * 3.0) + 0.25, 0.0) * corner * 0.5
		var groove := 0.0
		if grooves and sin(angle) > 0.9:
			var across := fposmod(p.x / size.x * 6.0, 1.0)
			groove = smoothstep(0.35, 0.5, across) * smoothstep(0.65, 0.5, across) * smoothstep(0.1, 0.2, v) * smoothstep(0.9, 0.8, v)
		var inward := Vector3(p.x, 0.0, p.z).normalized()
		p += inward * (chip * minf(size.x, size.z) - groove * 0.05)
		return [p, groove * 0.8, clampf(-chip * 3.0, 0.0, 1.0)], true, true, true, 0.2)
	return kit


## Round steps (a tholos's stylobate): `steps` rings, the top `radius` m
## across, each `rise` m tall and `tread` m deep; worn and chipped.
static func round_steps(radius: float, steps := 3, rise := 0.28, tread := 0.45, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 1.4)
	kit.set_random(0.5)
	var profile := PackedVector2Array()
	for n in steps:
		var r := radius + tread * (steps - n)
		var y := rise * n
		profile.append(Vector2(r, y))
		profile.append(Vector2(r, y + rise * 0.92))
		profile.append(Vector2(r - tread * 0.08, y + rise))
	profile.append(Vector2(radius * 0.0 + 0.01, rise * steps))
	kit.lathe(profile, 96, func(angle: float, _v: float) -> float:
		return 1.0 + noise.get_noise_2d(cos(angle) * 6.0, sin(angle) * 6.0) * 0.012, false, false)
	return kit


## A curved architrave block: `span` radians of a ring of radius `radius`,
## `depth` m deep and `tall` m tall, broken at one end if `broken`.
static func ring_beam(radius: float, span: float, tall := 0.6, depth := 0.55, broken := false, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 2.5)
	kit.set_random(fposmod(seed_value * 0.37, 1.0))
	var section := PackedVector2Array([Vector2(-depth * 0.5, 0.0), Vector2(depth * 0.5, 0.0), Vector2(depth * 0.5, tall * 0.62),
			Vector2(depth * 0.56, tall * 0.68), Vector2(depth * 0.56, tall), Vector2(-depth * 0.56, tall), Vector2(-depth * 0.56, tall * 0.68),
			Vector2(-depth * 0.5, tall * 0.62)])
	var count := section.size()
	kit.surface(count, 24, func(u: float, v: float) -> Array:
		var i := clampi(roundi(u * count), 0, count - 1)
		var s := section[i % count]
		var along := v * span
		if broken and v > 0.8:
			along -= noise.get_noise_2d(s.x * 4.0, s.y * 4.0) * 0.1 * (v - 0.8) * 5.0
		var r := radius + s.x
		return [Vector3(cos(along) * r, s.y, sin(along) * r), 0.3 if s.y > tall * 0.6 and s.y < tall * 0.7 else 0.0, 0.0],
			true, true, true, 0.8 if broken else 0.2, true)
	return kit


# --- Pottery ------------------------------------------------------------------

## An amphora (`krater` false) or a wide krater, lying or standing; broken:
## its rim and a side are gone.
static func amphora(krater := false, broken := false, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 2.0)
	kit.set_random(fposmod(seed_value * 0.61, 1.0))
	var keys: Array
	if krater:
		keys = [[0.0, 0.14], [0.06, 0.12], [0.12, 0.2], [0.45, 0.32], [0.75, 0.3], [0.85, 0.34], [1.0, 0.36]]
	else:
		keys = [[0.0, 0.04], [0.06, 0.06], [0.3, 0.2], [0.55, 0.22], [0.75, 0.13], [0.86, 0.06], [0.97, 0.06], [1.0, 0.09]]
	var tall := 0.55 if krater else 0.9
	kit.surface(32, 24, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var r: float = keyed(keys, v)
		var y := v * tall
		if broken and v > 0.55:
			var bite := smoothstep(0.55, 0.8, v) * (0.5 + 0.5 * cos(angle - 1.0)) + noise.get_noise_2d(angle * 2.0, v * 6.0) * 0.3
			y = minf(y, tall * (0.9 - bite * 0.35))
		return [Vector3(cos(angle) * r, y, sin(angle) * r), 0.0, 0.6 if broken and v > 0.85 else 0.0], true, true, not broken, 0.0)
	if not krater:
		for side: float in [-1.0, 1.0]:
			var path := PackedVector3Array()
			for n in 9:
				var t := n / 8.0
				path.append(Vector3(side * (0.07 + sin(t * PI) * 0.1), tall * (0.85 - t * 0.28 + sin(t * PI) * 0.06), 0.0))
			kit.tube(path, PackedFloat32Array([0.018]), 8)
	return kit


# --- Statues -------------------------------------------------------------------

## A draped statue (a chiton to the feet, a himation over one shoulder),
## `who`: "poseidon", "tyche", "hades" or "aphrodite". Like most that survive,
## weathered and broken: arms gone (bar the one holding the attribute),
## faces worn smooth; Hades veiled. About 2.2 m tall, standing on y 0.
static func statue(who: String, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var male := who == "poseidon" or who == "hades"
	var veiled := who == "hades"
	var noise := _noise(seed_value + 7, 1.0)
	kit.set_random(fposmod(seed_value * 0.29, 1.0))
	var tall := 2.2
	# [height share, half-width x, half-depth z]
	var widths: Array = [[0.0, Vector2(0.36, 0.3)], [0.12, Vector2(0.32, 0.26)], [0.45, Vector2(0.26, 0.19)],
			[0.53, Vector2(0.23, 0.16) if male else Vector2(0.2, 0.15)], [0.63, Vector2(0.27, 0.17)],
			[0.71, Vector2(0.35, 0.16) if male else Vector2(0.31, 0.15)], [0.755, Vector2(0.24, 0.13)], [0.785, Vector2(0.08, 0.08)],
			[0.81, Vector2(0.095, 0.1)], [0.86, Vector2(0.105, 0.12)], [0.915, Vector2(0.098, 0.112)], [0.935, Vector2(0.088, 0.1)], [0.948, Vector2(0.07, 0.08)],
			[0.958, Vector2(0.045, 0.052)], [0.964, Vector2(0.0, 0.0)]]
	if veiled:
		# The veil falls from the crown to the shoulders: no neck.
		widths = widths.slice(0, 6) + [[0.76, Vector2(0.27, 0.16)], [0.8, Vector2(0.15, 0.15)], [0.86, Vector2(0.135, 0.15)],
				[0.93, Vector2(0.12, 0.13)], [0.965, Vector2(0.07, 0.08)], [0.985, Vector2(0.0, 0.0)]]
	var sway := 0.04
	kit.surface(72, 110, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var w: Vector2 = keyed(widths, v)
		var power := 2.0 if v > 0.77 else (2.8 if v > 0.66 else 2.3)
		var s := squarish(angle, power)
		var x := cos(angle) * w.x * s
		var z := sin(angle) * w.y * s
		var front := maxf(sin(angle), 0.0)  # +Z is the front
		var cavity := 0.0
		var y := v * tall
		# Folds: hanging below the waist, slanting across the chest.
		if v < 0.55 and not (v > 0.77):
			var folds := sin(angle * 9.0 + noise.get_noise_2d(angle * 2.0, v * 3.0) * 2.5)
			var deep := 0.025 * (1.0 - v / 0.55) + 0.006
			x += cos(angle) * folds * deep
			z += sin(angle) * folds * deep
			cavity = maxf(-folds, 0.0) * 0.6
		elif v < 0.74:
			var folds := sin(angle * 5.0 + v * 40.0 + noise.get_noise_2d(angle, v * 5.0) * 2.0)
			x += cos(angle) * folds * 0.012
			z += sin(angle) * folds * 0.012
			cavity = maxf(-folds, 0.0) * 0.4
		# The face, worn: a nose and brow; a beard for the gods.
		if v > 0.8 and v < 0.94 and not veiled:
			var nose := exp(-pow((angle - PI / 2.0) * 7.0, 2.0)) * exp(-pow((v - 0.862) * 40.0, 2.0)) * 0.035
			var brow := exp(-pow((angle - PI / 2.0) * 2.2, 2.0)) * exp(-pow((v - 0.885) * 55.0, 2.0)) * 0.012
			z += nose + brow
			if male:
				var beard := exp(-pow((angle - PI / 2.0) * 1.6, 2.0)) * exp(-pow((v - 0.82) * 18.0, 2.0)) * 0.045
				beard *= 1.0 + 0.4 * sin(angle * 18.0 + v * 60.0)
				z += beard
				cavity += beard * 3.0
			else:
				# Hair gathered into a bun behind.
				var bun := exp(-pow((angle + PI / 2.0) * 1.8, 2.0)) * exp(-pow((v - 0.9) * 30.0, 2.0)) * 0.06
				z -= bun
		if not male and v > 0.6 and v < 0.69:
			for side: float in [-1.0, 1.0]:
				var at := PI / 2.0 - side * 0.55
				z += exp(-pow((angle - at) * 3.2, 2.0)) * exp(-pow((v - 0.645) * 30.0, 2.0)) * 0.05
		# Contrapposto: the hips one way, the shoulders the other.
		x += sway * sin(v * PI * 1.6) * (1.0 if v < 0.6 else -0.5)
		# Weathering everywhere.
		var p := Vector3(x, y, z)
		p += Vector3(x, 0.0, z).normalized() * noise.get_noise_3d(x * 6.0, y * 6.0, z * 6.0) * 0.008
		return [p, cavity, 0.0], true, true, false)
	# Shoulder stumps where the arms broke off.
	for side: float in [-1.0, 1.0]:
		if _holds_with(who) == side:
			continue
		var from := Vector3(side * 0.3, tall * 0.715, 0.0)
		var path := PackedVector3Array([from, from + Vector3(side * 0.07, -0.05, 0.01), from + Vector3(side * 0.12, -0.12, 0.02)])
		kit.tube(path, PackedFloat32Array([0.07, 0.068, 0.064]), 14, false, true)
	# The arm that holds the attribute.
	var hold := _holds_with(who)
	if hold != 0.0:
		var shoulder := Vector3(hold * 0.29, tall * 0.715, 0.0)
		var elbow := shoulder + (Vector3(hold * 0.12, -0.28, 0.08) if who != "poseidon" else Vector3(hold * 0.16, 0.05, 0.04))
		var hand := hand_of(who)
		var path := PackedVector3Array()
		for n in 7:
			var t := n / 6.0
			path.append(shoulder * (1.0 - t) * (1.0 - t) + elbow * 2.0 * (1.0 - t) * t + hand * t * t)
		kit.tube(path, PackedFloat32Array([0.072, 0.066, 0.06, 0.056, 0.05, 0.047, 0.05]), 14, false, true)
	return kit


## Which hand holds the attribute (+1 right, -1 left, 0 none).
static func _holds_with(who: String) -> float:
	match who:
		"poseidon", "hades":
			return 1.0
		"tyche":
			return -1.0
		"aphrodite":
			return 1.0
	return 0.0


## Where the statue's holding hand is (m, statue space).
static func hand_of(who: String) -> Vector3:
	match who:
		"poseidon":
			return Vector3(0.52, 2.2 * 0.84, 0.1)
		"hades":
			return Vector3(0.48, 2.2 * 0.5, 0.2)
		"tyche":
			return Vector3(-0.46, 2.2 * 0.56, 0.22)
		"aphrodite":
			return Vector3(0.3, 2.2 * 0.62, 0.32)
	return Vector3.ZERO


## A trident (`prongs` 3) or bident (2), shaft along +Y from the origin.
static func trident(length := 2.7, prongs := 3) -> MeshKit:
	var kit := MeshKit.new()
	kit.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.0, length * 0.5, 0.0), Vector3(0.0, length * 0.82, 0.0)]),
			PackedFloat32Array([0.022, 0.024, 0.026]), 10)
	var base := length * 0.82
	kit.tube(PackedVector3Array([Vector3(-0.17, base, 0.0), Vector3(0.0, base - 0.04, 0.0), Vector3(0.17, base, 0.0)]),
			PackedFloat32Array([0.022]), 8)
	for n in prongs:
		var x := (n - (prongs - 1) * 0.5) * (0.17 if prongs == 3 else 0.2)
		var path := PackedVector3Array()
		for k in 6:
			var t := k / 5.0
			path.append(Vector3(x * (1.0 + 0.15 * t), base + t * length * 0.17, 0.0))
		kit.tube(path, PackedFloat32Array([0.02, 0.019, 0.017, 0.014, 0.01, 0.002]), 8, true, false)
		# A barb near the tip.
		var tip := path[3]
		kit.tube(PackedVector3Array([tip, tip + Vector3(signf(x + 0.001) * 0.04, -0.05, 0.0)]), PackedFloat32Array([0.012, 0.002]), 6, false, false)
	return kit


## A cornucopia: its mouth (at the origin, open upward) heaped with fruit,
## the horn curling down and round beneath it.
static func cornucopia() -> MeshKit:
	var kit := MeshKit.new()
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for n in 20:
		var t := n / 19.0
		path.append(Vector3(0.0, -0.55 * t + 0.1 * sin(t * PI), 0.22 * sin(t * PI * 1.25)))
		radii.append(lerpf(0.12, 0.008, pow(t, 0.75)))
	kit.tube(path, radii, 20, true, true)
	for n in 6:
		var fruit := MeshKit.new()
		fruit.lathe(_sphere_profile(0.045 + 0.015 * (n % 2)), 12)
		var spot := Vector3(cos(n * 1.9) * 0.06, 0.02 * (n % 3), sin(n * 1.9) * 0.06)
		kit.merge(fruit, Transform3D(Basis(), spot))
	return kit


## A scallop shell standing open, fan up: `radius` m.
static func scallop(radius := 0.9) -> MeshKit:
	var kit := MeshKit.new()
	kit.surface(48, 16, func(u: float, v: float) -> Array:
		var angle := lerpf(-1.25, 1.25, u)
		var ribs := absf(sin(angle * 9.0))
		var r := v * radius * (1.0 + 0.03 * ribs)
		var cup := (1.0 - pow(absf(angle) / 1.25, 2.0)) * v * radius * 0.25
		return [Vector3(sin(angle) * r, cos(angle) * r * 0.9, -cup + ribs * 0.02 * v), (1.0 - ribs) * 0.5, 0.0], false, false, false, 0.0, true)
	# Its back, so it isn't paper-thin from behind.
	kit.surface(48, 16, func(u: float, v: float) -> Array:
		var angle := lerpf(-1.25, 1.25, u)
		var r := v * radius
		var cup := (1.0 - pow(absf(angle) / 1.25, 2.0)) * v * radius * 0.25
		return [Vector3(sin(angle) * r, cos(angle) * r * 0.9, -cup - 0.04 * v), 0.0, 0.0], false, false, false)
	return kit


static func _sphere_profile(radius: float, rows := 8) -> PackedVector2Array:
	var profile := PackedVector2Array()
	for n in rows + 1:
		var a := -PI / 2.0 + PI * n / rows
		profile.append(Vector2(cos(a) * radius + 0.0001, sin(a) * radius + radius))
	return profile


## A pearl, `radius` m, sitting on y 0.
static func pearl(radius := 0.07) -> MeshKit:
	var kit := MeshKit.new()
	kit.lathe(_sphere_profile(radius, 12), 20, Callable(), false, false)
	return kit


## A bronze brazier: a shallow bowl on three curving legs, its rim `height` m up.
static func brazier(height := 1.05, bowl := 0.38) -> MeshKit:
	var kit := MeshKit.new()
	var profile := PackedVector2Array([Vector2(0.06, height - 0.2), Vector2(bowl * 0.5, height - 0.16), Vector2(bowl * 0.85, height - 0.08),
			Vector2(bowl, height), Vector2(bowl * 1.06, height + 0.02), Vector2(bowl * 0.94, height + 0.015), Vector2(bowl * 0.8, height - 0.05),
			Vector2(0.02, height - 0.1)])
	kit.lathe(profile, 36, Callable(), true, false)
	for n in 3:
		var a := TAU * n / 3.0
		var out := Vector3(cos(a), 0.0, sin(a))
		var path := PackedVector3Array()
		for k in 8:
			var t := k / 7.0
			path.append(out * (bowl * 0.55 + sin(t * PI) * 0.12 + t * 0.1) + Vector3(0.0, height - 0.12 - t * (height - 0.12), 0.0))
		kit.tube(path, PackedFloat32Array([0.025, 0.024, 0.022, 0.022, 0.022, 0.024, 0.03, 0.04]), 8)
	return kit
