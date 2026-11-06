class_name TempleKit
extends RefCounted
## The Sunken Temple's own pieces (planning_marco_polo.md §12), beside
## GreekKit's: cheap ashlar blocks for the long walls (thousands of them, so
## few polygons each), a wall slab with a round hole through it (a porthole's
## surround), a pediment's gable, and low sand drifts. Built with MeshKit, so
## they take the stone shader like GreekKit's pieces do; cache them with
## GreekKit.cached().
##
## Units are metres; pieces stand on y = 0, facing +Z.

static var _sand: ShaderMaterial
static var _wall: ShaderMaterial


## Sand: the stone shader, pale and grainy, no veins.
static func sand() -> ShaderMaterial:
	if _sand == null:
		_sand = ShaderMaterial.new()
		_sand.shader = preload("res://shaders/stone.gdshader")
		_sand.set_shader_parameter("base_color", Vector3(0.62, 0.57, 0.45))
		_sand.set_shader_parameter("base_color_b", Vector3(0.52, 0.48, 0.38))
		_sand.set_shader_parameter("vein_strength", 0.0)
		_sand.set_shader_parameter("pitting", 0.2)
		_sand.set_shader_parameter("roughness_base", 0.95)
		_sand.set_shader_parameter("algae", 0.15)
		_sand.set_shader_parameter("coralline", 0.0)
		_sand.set_shader_parameter("bump_strength", 0.15)
		_sand.set_shader_parameter("bump_scale", 3.0)
	return _sand


## The walls' stone: marble gone grey-green with age, more algae.
static func wall_stone() -> ShaderMaterial:
	if _wall == null:
		_wall = ShaderMaterial.new()
		_wall.shader = preload("res://shaders/stone.gdshader")
		_wall.set_shader_parameter("base_color", Vector3(0.64, 0.64, 0.58))
		_wall.set_shader_parameter("base_color_b", Vector3(0.5, 0.52, 0.47))
		_wall.set_shader_parameter("vein_strength", 0.15)
		_wall.set_shader_parameter("pitting", 0.6)
		_wall.set_shader_parameter("roughness_base", 0.8)
		_wall.set_shader_parameter("algae", 0.6)
		_wall.set_shader_parameter("coralline", 0.3)
		_wall.set_shader_parameter("bump_strength", 0.35)
	return _wall


static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return noise


## An ashlar block `size` (centred on x and z, standing on y 0): GreekKit.block's
## rounded, chipped box with a fraction of its polygons.
static func ashlar(size: Vector3, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var noise := _noise(seed_value, 1.6)
	kit.surface(12, 2, func(u: float, v: float) -> Array:
		var angle := u * TAU + PI / 4.0
		var r := GreekKit.squarish(angle, 24.0) * (1.0 - pow(absf(v * 2.0 - 1.0), 6.0) * 0.04)
		var p := Vector3(cos(angle) * r * size.x * 0.5, v * size.y, sin(angle) * r * size.z * 0.5)
		var corner := pow(absf(cos(angle) * sin(angle)) * 2.0, 4.0) + pow(absf(v * 2.0 - 1.0), 6.0)
		var chip := minf(noise.get_noise_3d(p.x * 2.0, p.y * 2.0, p.z * 2.0) + 0.2, 0.0) * corner * 0.15
		p += Vector3(p.x, 0.0, p.z).normalized() * chip * minf(size.x, size.z)
		return [p, 0.0, clampf(-chip * 3.0, 0.0, 1.0)], true, true, true, 0.15)
	return kit


## A wall slab `width` x `height` x `thick` (centred on x and z, standing on y
## 0) with a round hole `radius` m through it, its middle at the slab's: a
## porthole's surround. The hole runs along z.
static func holed_slab(width: float, height: float, thick: float, radius: float, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	kit.set_random(dice.randf())
	var noise := _noise(seed_value, 2.0)
	var middle := Vector2(0.0, height * 0.5)
	var hw := width * 0.5
	var hh := height * 0.5
	var edge := func(angle: float) -> Vector2:
		var c := cos(angle)
		var s := sin(angle)
		var reach := 1.0 / maxf(absf(c) / hw, absf(s) / hh)
		return Vector2(c, s) * reach
	for face: float in [1.0, -1.0]:
		kit.surface(40, 3, func(u: float, v: float) -> Array:
			var angle := u * TAU
			var inner := Vector2(cos(angle), sin(angle)) * radius
			var outer: Vector2 = edge.call(angle)
			var q := inner.lerp(outer, v)
			var bump := noise.get_noise_2d(q.x * 3.0, q.y * 3.0) * 0.03 * v
			return [Vector3(q.x, q.y + middle.y, face * (thick * 0.5 + bump)), (1.0 - v) * 0.4, 0.0], true, false, false, 0.0, face < 0.0)
	# The hole's lining.
	kit.surface(40, 2, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var r := radius * (1.0 + noise.get_noise_2d(angle * 3.0, v * 4.0) * 0.04)
		return [Vector3(cos(angle) * r, sin(angle) * r + middle.y, lerpf(thick * 0.5, -thick * 0.5, v)), 0.8, 0.3], true, false, false, 0.0, true)
	return kit


## A pediment's gable: a low triangle `width` across and `height` tall, `depth`
## m deep, with a projecting cornice along its rakes; broken off at one end if
## `broken` (the far end's corner gone).
static func pediment(width: float, height: float, depth: float, broken := false, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 1.5)
	kit.set_random(fposmod(seed_value * 0.43, 1.0))
	var lip := 0.35
	var section := PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0), Vector2(width * 0.5 + lip, 0.0),
			Vector2(width * 0.5 + lip, lip * 0.6), Vector2(0.0, height + lip), Vector2(-width * 0.5 - lip, lip * 0.6), Vector2(-width * 0.5 - lip, 0.0)])
	var count := section.size()
	kit.surface(count, 4, func(u: float, v: float) -> Array:
		var i := clampi(roundi(u * count), 0, count - 1)
		var s := section[i % count]
		if broken and s.x > width * 0.2:
			s.y = minf(s.y, height * 0.25 + noise.get_noise_2d(s.x, v * 3.0) * 0.6)
		return [Vector3(s.x, s.y, lerpf(depth * 0.5, -depth * 0.5, v)), 0.0, 0.7 if broken and s.x > width * 0.2 else 0.0],
			true, true, true, 0.2)
	return kit


## A low sand drift: a soft mound `radius` m round and `tall` m high, stretched
## `stretch` along x.
static func mound(radius: float, tall: float, stretch := 1.0, seed_value := 0) -> MeshKit:
	var kit := MeshKit.new()
	var noise := _noise(seed_value, 0.8)
	kit.set_random(0.3)
	kit.surface(32, 6, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var r := radius * (1.0 - v) * (1.0 + noise.get_noise_2d(cos(angle) * 2.0, sin(angle) * 2.0) * 0.25)
		var y := tall * (1.0 - pow(1.0 - v, 2.0)) * (1.0 - v * 0.15) - 0.05
		return [Vector3(cos(angle) * r * stretch, y, sin(angle) * r), 0.0, 0.0], true, false, true, 0.0)
	return kit
