class_name TankKit
extends RefCounted
## The Aquarium arena's furnishings (planning_marco_polo.md §12), the shop-bought
## ornaments of a home fish tank at fish scale: a sunken ship's hull, a ceramic
## skull, plastic plants, an arched bridge. Built with MeshKit (no UVs; plain
## materials), cached by key like GreekKit's.
##
## Units are metres; pieces stand on y = 0, facing +Z.

static var _meshes := {}


static func cached(key: String, build: Callable, material: Material) -> ArrayMesh:
	if not _meshes.has(key):
		var kit: MeshKit = build.call()
		_meshes[key] = kit.mesh(true, material)
	return _meshes[key]


## A wooden hull `length` m long along z (the bow at +z), `beam` m across and
## `depth` m from keel to deck, the deck flat on top, sheer rising to bow and
## stern; its origin at the keel's middle.
static func hull(length: float, beam: float, depth: float) -> MeshKit:
	var kit := MeshKit.new()
	kit.set_random(0.4)
	var widths := [[0.0, 0.8], [0.15, 0.97], [0.5, 1.0], [0.8, 0.8], [0.95, 0.35], [1.0, 0.05]]
	kit.surface(28, 28, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var half: float = GreekKit.keyed(widths, v) * beam * 0.5
		var s := sin(angle)
		var c := cos(angle)
		var sheer := depth * 0.18 * pow(v * 2.0 - 1.0, 2.0)
		var y := depth * 0.5 + (s * depth * 0.5 if s < 0.0 else s * depth * 0.06) + (sheer if s > -0.2 else 0.0)
		var x := c * half * (1.0 if s > -0.3 else lerpf(1.0, 0.7, -s))
		# Planks: shallow grooves along the hull.
		var plank := 0.5 + 0.5 * sin(y / depth * 30.0)
		return [Vector3(x, y, (v - 0.5) * length), plank * 0.4, 0.0], true, true, true, 0.0, true)
	return kit


## A ceramic skull `radius` m round the cranium, sitting on y 0, facing +Z:
## the cranium, cheekbones, a jaw; the eye sockets and nose are hollows.
static func skull(radius: float) -> MeshKit:
	var kit := MeshKit.new()
	kit.set_random(0.7)
	kit.surface(36, 24, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var lat := lerpf(-PI / 2.0, PI / 2.0, v)
		var dir := Vector3(cos(lat) * cos(angle), sin(lat), cos(lat) * sin(angle))
		var r := radius
		# Narrower lower face, a longer back of the head.
		if dir.y < 0.0:
			r *= 1.0 - 0.25 * (-dir.y) * maxf(dir.z, 0.0)
		r *= 1.0 + 0.15 * maxf(-dir.z, 0.0)
		var hollow := 0.0
		for side: float in [-1.0, 1.0]:
			var eye := Vector3(side * 0.42, -0.05, 0.9).normalized()
			hollow = maxf(hollow, smoothstep(0.93, 0.985, dir.dot(eye)))
		var nose := smoothstep(0.965, 0.99, dir.dot(Vector3(0.0, -0.35, 0.94).normalized()))
		hollow = maxf(hollow, nose)
		r *= 1.0 - hollow * 0.3
		return [dir * r + Vector3(0.0, radius * 0.95, 0.0), hollow, 0.0], true, false, false)
	# The jaw: a horseshoe under the front.
	var path := PackedVector3Array()
	for n in 9:
		var a := lerpf(-1.1, 1.1, n / 8.0)
		path.append(Vector3(sin(a) * radius * 0.62, radius * 0.18, cos(a) * radius * 0.55 + radius * 0.2))
	kit.tube(path, PackedFloat32Array([radius * 0.16]), 10)
	return kit


## A plastic plant: `blades` long ribbons `tall` m high fanning out of a clump,
## each curving over. Draw it two-sided.
static func plant(blades: int, tall: float, seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	for n in blades:
		var heading := dice.randf() * TAU
		var lean := dice.randf_range(0.15, 0.6)
		var length := tall * dice.randf_range(0.6, 1.0)
		var width := dice.randf_range(0.35, 0.7)
		var root := Vector3(dice.randf_range(-0.4, 0.4), 0.0, dice.randf_range(-0.4, 0.4))
		var out := Vector3(cos(heading), 0.0, sin(heading))
		var across := Vector3(-out.z, 0.0, out.x)
		kit.set_random(dice.randf())
		kit.surface(2, 12, func(u: float, v: float) -> Array:
			var bend := lean * v * v
			var spine := root + out * sin(bend) * length * v + Vector3.UP * cos(bend) * length * v
			var w := width * sin(PI * minf(v * 1.1 + 0.08, 1.0))
			return [spine + across * (u - 0.5) * w, 0.0, 0.0], false, false, false)
	return kit


## An arched bridge `length` m long along x, `width` m across, its deck rising
## `rise` m in the middle, `thick` m deep, with a low rail each side.
static func bridge(length: float, width: float, rise: float, thick := 0.6) -> MeshKit:
	var kit := MeshKit.new()
	kit.set_random(0.2)
	var section := PackedVector2Array([Vector2(-width * 0.5, -thick), Vector2(width * 0.5, -thick), Vector2(width * 0.5, 0.0),
			Vector2(width * 0.5 - 0.25, 0.0), Vector2(width * 0.5 - 0.25, 0.7), Vector2(width * 0.5, 0.7), Vector2(width * 0.5, 0.9),
			Vector2(-width * 0.5, 0.9), Vector2(-width * 0.5, 0.7), Vector2(-width * 0.5 + 0.25, 0.7), Vector2(-width * 0.5 + 0.25, 0.0),
			Vector2(-width * 0.5, 0.0)])
	var count := section.size()
	kit.surface(count, 24, func(u: float, v: float) -> Array:
		var i := clampi(roundi(u * count), 0, count - 1)
		var s := section[i % count]
		var x := (v - 0.5) * length
		var y := rise * sin(PI * v) + thick
		return [Vector3(x, y + s.y, s.x), 0.0, 0.0], true, true, true, 0.0)
	return kit
