class_name ReefKit
extends RefCounted
## The living reef's pieces (planning_environment.md, Phase 5), each built
## once per variant with MeshKit and cached with its material: boulders and
## slabs, giant kelp, sea grass, staghorn, brain, table and fan corals, tube
## and barrel sponges, anemones, and small life (starfish, urchins, clams).
## Pieces stand on y = 0. Colours come from each copy's custom data (Scatter):
## r picks from its material's palette.

const VARIANTS := 3

static var _cache := {}
static var _materials := {}


## Variant `n` of piece `what` (see build()).
static func mesh(what: String, n: int) -> Mesh:
	var key := "%s/%d" % [what, n]
	if not _cache.has(key):
		var kit := build(what, 7000 + n * 131 + what.hash() % 1000)
		_cache[key] = kit.mesh(true, material(what))
	return _cache[key]


static func build(what: String, seed_value: int) -> MeshKit:
	match what:
		"boulder":
			return boulder(seed_value, false)
		"slab":
			return boulder(seed_value, true)
		"kelp":
			return kelp(seed_value)
		"seagrass":
			return seagrass(seed_value)
		"staghorn":
			return staghorn(seed_value)
		"brain":
			return brain(seed_value)
		"table":
			return table(seed_value)
		"fan":
			return fan(seed_value)
		"tube_sponge":
			return tube_sponge(seed_value)
		"barrel":
			return barrel(seed_value)
		"anemone":
			return anemone(seed_value)
		"starfish":
			return starfish(seed_value)
		"urchin":
			return urchin(seed_value)
		"clam":
			return clam(seed_value)
	return boulder(seed_value, false)


## The material a piece uses (shared by its variants).
static func material(what: String) -> Material:
	var key := what
	match what:
		"boulder", "slab":
			return GreekKit.rock()
		"kelp", "seagrass":
			key = what
		"fan":
			key = "fan"
		"anemone":
			key = "anemone"
		_:
			key = "reef_" + what
	if _materials.has(key):
		return _materials[key]
	var made := ShaderMaterial.new()
	match key:
		"kelp":
			made.shader = preload("res://shaders/kelp_plant.gdshader")
		"seagrass":
			made.shader = preload("res://shaders/kelp_plant.gdshader")
			made.set_shader_parameter("base", Vector3(0.12, 0.3, 0.1))
			made.set_shader_parameter("tip", Vector3(0.35, 0.5, 0.16))
			made.set_shader_parameter("sway", 0.18)
		"fan":
			made.shader = preload("res://shaders/fan_coral.gdshader")
		_:
			made.shader = preload("res://shaders/reef.gdshader")
			var pattern := 0
			var palette: Array = [Vector3(0.62, 0.22, 0.75), Vector3(0.95, 0.5, 0.18), Vector3(0.98, 0.82, 0.25), Vector3(0.95, 0.42, 0.6),
					Vector3(0.18, 0.72, 0.7), Vector3(0.35, 0.55, 0.95)]
			match what:
				"brain":
					pattern = 1
					palette = [Vector3(0.75, 0.62, 0.3), Vector3(0.55, 0.7, 0.35), Vector3(0.85, 0.55, 0.45), Vector3(0.62, 0.45, 0.7),
							Vector3(0.4, 0.62, 0.55), Vector3(0.9, 0.75, 0.45)]
				"tube_sponge", "barrel":
					pattern = 2
					palette = [Vector3(0.75, 0.3, 0.75), Vector3(0.95, 0.55, 0.2), Vector3(0.95, 0.85, 0.3), Vector3(0.45, 0.4, 0.85),
							Vector3(0.85, 0.35, 0.3), Vector3(0.3, 0.7, 0.85)]
				"anemone":
					pattern = 3
				"starfish", "urchin", "clam":
					pattern = 4
					palette = [Vector3(0.95, 0.4, 0.2), Vector3(0.85, 0.25, 0.4), Vector3(0.3, 0.2, 0.45), Vector3(0.95, 0.75, 0.4),
							Vector3(0.25, 0.3, 0.6), Vector3(0.8, 0.7, 0.6)]
			made.set_shader_parameter("pattern", pattern)
			for i in 6:
				made.set_shader_parameter("color_%d" % i, palette[i])
	_materials[key] = made
	return made


static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	return noise


## A sphere-like surface: `radius(direction) -> float` from the middle.
static func _blob(kit: MeshKit, cols: int, rows: int, radius: Callable, centre := Vector3.ZERO) -> void:
	kit.surface(cols, rows, func(u: float, v: float) -> Array:
		var lat := lerpf(-PI / 2.0, PI / 2.0, v)
		var lon := u * TAU
		var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
		return [centre + d * float(radius.call(d)), 0.0, 0.0], true, false, false)


# --- Rock -----------------------------------------------------------------

## A rounded boulder, or a flat slab, about 1 m across, sunk a little.
static func boulder(seed_value: int, slab: bool) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 0.9)
	var fine := _noise(seed_value + 1, 3.5)
	kit.set_random(fposmod(seed_value * 0.37, 1.0))
	_blob(kit, 28, 16, func(d: Vector3) -> float:
		return 0.55 + noise.get_noise_3dv(d * 1.4) * 0.22 + fine.get_noise_3dv(d * 2.0) * 0.04)
	var squash := Vector3(1.0, 0.32 if slab else 0.62, 0.85 if slab else 1.0)
	kit.displace(0, func(p: Vector3) -> Vector3:
		var q := p * squash
		if slab:
			q.y = minf(q.y, 0.12 + fine.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.03)
		return q - p + Vector3(0.0, 0.12 if slab else 0.18, 0.0))
	return kit


# --- Kelp and grass ----------------------------------------------------------

## A giant kelp: a slender stipe about 8 m tall, rippled fronds on little
## floats all the way up, a few streaming from the top.
static func kelp(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var tall := dice.randf_range(6.5, 9.5)
	var lean := Vector3(dice.randf_range(-0.6, 0.6), 0.0, dice.randf_range(-0.6, 0.6))
	var stipe := PackedVector3Array()
	for n in 12:
		var t := n / 11.0
		stipe.append(Vector3(0.0, t * tall, 0.0) + lean * t * t + Vector3(sin(t * 5.0), 0.0, cos(t * 4.0)) * 0.12 * t)
	kit.tube(stipe, PackedFloat32Array([0.035, 0.03, 0.026, 0.024, 0.022, 0.02, 0.019, 0.018, 0.017, 0.016, 0.015, 0.01]), 6)
	var y := 0.5
	var side := 1.0
	while y < tall:
		var t := y / tall
		var i := clampi(roundi(t * 11.0), 0, 11)
		var at := stipe[i]
		var out := Vector3(cos(dice.randf() * TAU), 0.0, sin(dice.randf() * TAU)) * side
		var direction := (out * 0.55 + Vector3.UP * 0.9).normalized()
		_frond(kit, at, direction, dice.randf_range(0.9, 1.5) * (1.0 if t < 0.85 else 1.4), dice.randf_range(0.12, 0.2), dice)
		var bladder := MeshKit.new()
		bladder.lathe(GreekKit._sphere_profile(0.045, 4), 6)
		kit.merge(bladder, Transform3D(Basis(), at + direction * 0.06 - Vector3.UP * 0.04))
		y += dice.randf_range(0.4, 0.7)
		side = -side
	return kit


## One frond: a tapering, ruffled blade from `root` along `direction`.
static func _frond(kit: MeshKit, root: Vector3, direction: Vector3, length: float, width: float, dice: RandomNumberGenerator) -> void:
	var across := direction.cross(Vector3.UP).normalized()
	if across.length_squared() < 0.01:
		across = Vector3.RIGHT
	var face := across.cross(direction).normalized()
	var curl := dice.randf_range(-0.3, 0.3)
	var phase := dice.randf() * TAU
	kit.surface(4, 10, func(u: float, v: float) -> Array:
		var s := u * 2.0 - 1.0
		var w := width * sin(minf(v * 1.15, 1.0) * PI * 0.92 + 0.12) * (1.0 - v * 0.35)
		var droop := Vector3.DOWN * v * v * length * 0.25
		var ruffle := face * sin(v * 22.0 + phase) * 0.035 * absf(s)
		var p := root + direction * v * length + droop + across * s * w + face * curl * s * s * w + ruffle
		return [p, 0.0, 0.0], false, false, false)


## A clump of sea grass: a dozen thin blades, 0.4-1 m, bending outward.
static func seagrass(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	for n in 14:
		var spot := Vector3(dice.randf_range(-0.25, 0.25), 0.0, dice.randf_range(-0.25, 0.25))
		var out := Vector3(spot.x, 0.0, spot.z).normalized() if spot.length_squared() > 0.001 else Vector3.RIGHT
		var tall := dice.randf_range(0.4, 1.0)
		var bend := dice.randf_range(0.1, 0.45)
		var across := out.cross(Vector3.UP).normalized()
		var width := dice.randf_range(0.012, 0.022)
		kit.surface(1, 6, func(u: float, v: float) -> Array:
			var p := spot + Vector3.UP * v * tall + out * v * v * bend + across * (u * 2.0 - 1.0) * width * (1.0 - v * 0.7)
			return [p, 0.0, 0.0], false, false, false)
	return kit


# --- Corals ------------------------------------------------------------------

## Staghorn coral: a branching tree of round-tipped tubes, about 1.2 m.
static func staghorn(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	for n in 3:
		var direction := (Vector3(dice.randf_range(-0.5, 0.5), 1.0, dice.randf_range(-0.5, 0.5))).normalized()
		_branch(kit, Vector3(dice.randf_range(-0.15, 0.15), 0.0, dice.randf_range(-0.15, 0.15)), direction, 0.45, 0.07, 3, dice)
	return kit


static func _branch(kit: MeshKit, from: Vector3, direction: Vector3, length: float, radius: float, depth: int, dice: RandomNumberGenerator) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var bend := Vector3(dice.randf_range(-0.2, 0.2), 0.0, dice.randf_range(-0.2, 0.2))
	for n in 5:
		var t := n / 4.0
		path.append(from + (direction + bend * t).normalized() * length * t)
		radii.append(radius * (1.0 - t * 0.3))
	var tip := path[4]
	var ahead := (path[4] - path[3]).normalized()
	if depth <= 0:
		path.append(tip + ahead * radius * 0.5)
		radii.append(radius * 0.35)
		kit.tube(path, radii, 8, false, true)
		return
	kit.tube(path, radii, 8, false, false)
	for n in 2 + (1 if dice.randf() < 0.4 else 0):
		var spread := Vector3(dice.randf_range(-0.8, 0.8), dice.randf_range(0.1, 0.5), dice.randf_range(-0.8, 0.8))
		_branch(kit, tip - ahead * radius * 0.3, (ahead + spread).normalized(), length * dice.randf_range(0.7, 0.9), radius * 0.72, depth - 1, dice)


## Brain coral: a low dome (the meanders are its shader's).
static func brain(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 1.2)
	kit.set_random(fposmod(seed_value * 0.41, 1.0))
	_blob(kit, 32, 14, func(d: Vector3) -> float:
		return 0.6 + noise.get_noise_3dv(d) * 0.08)
	kit.displace(0, func(p: Vector3) -> Vector3:
		return Vector3(0.0, maxf(p.y * 0.7, -0.1) - p.y + 0.08, 0.0))
	return kit


## Table coral: a broad wavy plate on a short stalk.
static func table(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 1.6)
	kit.set_random(fposmod(seed_value * 0.53, 1.0))
	var radius := 0.9
	var height := 0.45
	kit.lathe(PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.08, height * 0.5), Vector2(0.1, height)]), 10, Callable(), false, false)
	for face: float in [1.0, -1.0]:
		kit.surface(36, 8, func(u: float, v: float) -> Array:
			var angle := u * TAU
			var rim := 1.0 + noise.get_noise_1d(angle * 3.0) * 0.18
			var r := v * radius * rim
			var y := height + v * v * 0.12 + noise.get_noise_2d(cos(angle) * r * 2.0, sin(angle) * r * 2.0) * 0.05 * v
			y += 0.025 * face * (1.0 - v * 0.8)
			return [Vector3(cos(angle) * r, y, sin(angle) * r), 0.0, 0.0], true, false, false, 0.0, face > 0.0)
	return kit


## Fan coral (a gorgonian): a broad, thin, slightly cupped fan on a stalk;
## its lattice is cut by its shader.
static func fan(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 1.3)
	kit.set_random(fposmod(seed_value * 0.71, 1.0))
	var tall := 1.4
	kit.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.2, 0.0)]), PackedFloat32Array([0.04, 0.03]), 6)
	kit.surface(24, 12, func(u: float, v: float) -> Array:
		var angle := lerpf(-1.0, 1.0, u)
		var r := 0.15 + v * tall * (1.0 + noise.get_noise_1d(angle * 4.0) * 0.12)
		var cup := (1.0 - angle * angle) * v * 0.15
		return [Vector3(sin(angle) * r, 0.15 + cos(angle) * r * 0.85, cup + noise.get_noise_2d(angle * 3.0, v * 3.0) * 0.06), 0.0, 0.0],
			false, false, false)
	return kit


# --- Sponges -------------------------------------------------------------------

## A cluster of 3-5 open tube sponges, 0.3-1 m tall.
static func tube_sponge(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	for n in dice.randi_range(3, 5):
		var tall := dice.randf_range(0.3, 1.0)
		var r := dice.randf_range(0.06, 0.1)
		var piece := _open_vase(PackedVector2Array([Vector2(r * 0.8, 0.0), Vector2(r, tall * 0.5), Vector2(r * 1.15, tall)]), r * 0.18, 12)
		var at := Vector3(dice.randf_range(-0.18, 0.18), 0.0, dice.randf_range(-0.18, 0.18))
		kit.merge(piece, Transform3D(Basis(Vector3(at.z, 0.0, -at.x).normalized() if at.length() > 0.01 else Vector3.RIGHT, at.length() * 1.2), at))
	return kit


## A barrel sponge: a big ridged vase, about 0.9 m.
static func barrel(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	kit.set_random(fposmod(seed_value * 0.23, 1.0))
	var profile := PackedVector2Array([Vector2(0.25, 0.0), Vector2(0.38, 0.25), Vector2(0.44, 0.55), Vector2(0.42, 0.8), Vector2(0.36, 0.9)])
	kit.merge(_open_vase(profile, 0.07, 36, func(angle: float, _v: float) -> float: return 1.0 + 0.06 * absf(sin(angle * 8.0))))
	return kit


## A vase open at the top: an outside, a rim and an inside `wall` m thick.
static func _open_vase(profile: PackedVector2Array, wall: float, sides: int, shape := Callable()) -> MeshKit:
	var kit := MeshKit.new()
	var rows := profile.size() - 1
	var top := profile[rows]
	kit.surface(sides, rows + 2, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var step := roundi(v * (rows + 2))
		var p: Vector2
		var inside := 0.0
		if step <= rows:
			p = profile[step]
		elif step == rows + 1:
			p = Vector2(top.x - wall * 0.5, top.y + wall * 0.3)
		else:
			p = Vector2(top.x - wall, top.y - wall)
			inside = 1.0
		var s: float = shape.call(angle, v) if shape.is_valid() else 1.0
		return [Vector3(cos(angle) * p.x * s, p.y, sin(angle) * p.x * s), inside, 0.0], true, true, false)
	# The inside, down to a floor.
	kit.surface(sides, 2, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var r := lerpf(top.x - wall, profile[0].x * 0.5, v)
		var y := lerpf(top.y - wall, profile[0].y + wall + 0.05, v)
		var s: float = shape.call(angle, 1.0) if shape.is_valid() else 1.0
		return [Vector3(cos(angle) * r * s, y, sin(angle) * r * s), 1.0, 0.0], true, false, true, 0.0, true)
	return kit


# --- Anemones and small life ----------------------------------------------------

## An anemone: a short column, its crown of ~40 tentacles curling out and up.
static func anemone(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var tall := dice.randf_range(0.15, 0.3)
	var width := dice.randf_range(0.1, 0.16)
	kit.lathe(PackedVector2Array([Vector2(width * 1.2, 0.0), Vector2(width, tall * 0.5), Vector2(width * 1.1, tall), Vector2(width * 0.8, tall + 0.02),
			Vector2(0.01, tall)]), 16, Callable(), false, false)
	var count := 40
	for n in count:
		var ring := 0.45 + 0.55 * float(n % 3) / 2.0
		var angle := TAU * n / count + dice.randf_range(-0.05, 0.05)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var length := dice.randf_range(0.22, 0.38) * (1.3 - ring * 0.4)
		var lift := 1.2 - ring * 0.7
		var path := PackedVector3Array()
		for k in 6:
			var t := k / 5.0
			path.append(out * width * ring + Vector3.UP * tall + (out * (0.35 + t * 0.6) + Vector3.UP * lift * (1.0 - t * 0.6)).normalized() * length * t)
		kit.tube(path, PackedFloat32Array([0.012, 0.011, 0.01, 0.009, 0.007, 0.004]), 5, false, true)
	return kit


## A five-armed starfish, about 0.3 m across, lying flat.
static func starfish(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var size := dice.randf_range(0.12, 0.18)
	var twist := dice.randf() * TAU
	for face: float in [1.0, -1.0]:
		kit.surface(60, 6, func(u: float, v: float) -> Array:
			var angle := u * TAU + twist
			var arm := pow(0.5 + 0.5 * cos(angle * 5.0), 1.6)
			var r := v * size * (0.35 + 0.65 * arm)
			var y := face * (1.0 - v * v) * size * 0.25 * (0.5 + 0.5 * arm)
			return [Vector3(cos(angle) * r, maxf(y, 0.0) + 0.01, sin(angle) * r), 0.0, 0.0], true, false, false, 0.0, face > 0.0)
	return kit


## A sea urchin: a round test bristling with long spines.
static func urchin(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var r := dice.randf_range(0.07, 0.1)
	kit.lathe(GreekKit._sphere_profile(r, 8), 12)
	for n in 60:
		var d := Vector3(dice.randf_range(-1, 1), dice.randf_range(-0.1, 1), dice.randf_range(-1, 1)).normalized()
		var base := Vector3(0.0, r, 0.0) + d * r * 0.95
		kit.tube(PackedVector3Array([base, base + d * dice.randf_range(0.12, 0.2)]), PackedFloat32Array([0.006, 0.001]), 3, false, false)
	return kit


## A clam half buried, its shell ridged.
static func clam(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	kit.set_random(fposmod(seed_value * 0.19, 1.0))
	for face: float in [1.0, -1.0]:
		kit.surface(24, 8, func(u: float, v: float) -> Array:
			var angle := lerpf(-1.4, 1.4, u)
			var r := v * 0.16 * (1.0 + 0.04 * absf(sin(angle * 10.0)))
			var dome := (1.0 - v * v) * 0.06 * face
			return [Vector3(sin(angle) * r, maxf(dome, 0.0) + 0.005 * face, cos(angle) * r * 0.8 - 0.06), 0.0, 0.0], false, false, false, 0.0,
				face < 0.0)
	return kit
