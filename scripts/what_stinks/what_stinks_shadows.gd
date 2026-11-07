class_name WhatStinksShadows
extends Node3D
## The echo shadows of What Stinks? (what_stinks.md section 4b and 8): kelp
## stands and rock arches placed once per round in the open ocean (Marco Polo's
## Hideaway pattern: a spot is a name, a position and a radius, here without the
## hide-by-swimming-in rules). A prey inside a spot's sphere is in shadow, where
## the Hunter's echo builds at shadow_mult of its rate (WhatStinksEcho), so a
## loner has somewhere worth being. Spots are in the node group "ws_echo_shadow"
## (a Marker each, radius in `radius`) so a reach probe can find them.
##
## Everything random comes from the seed, so the same ocean has the same shadows.

class Marker extends Node3D:
	var radius := 0.0
	var spot_name := ""
	var kind := ""
	var index := -1


const KELP_PER_STAND := 7
const ARCH_SPAN := 0.55  # the pillars' spacing, as a share of the radius

var settings := WhatStinksSettings.shared()
## [{name, kind, position (world), radius}].
var spots: Array[Dictionary] = []

var _markers: Array[Marker] = []


## Places `shadow_count` spots (replacing any there) inside 80% of the arena.
func build(middle: Vector3, rng_seed: int) -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in settings.shadow_count:
		var flat := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * settings.arena_radius * 0.8
		var at := middle + Vector3(flat.x, rng.randf_range(-5.0, 5.0), flat.y)
		var kind := "kelp" if i % 2 == 0 else "arch"
		add_spot(at, settings.shadow_radius, kind, rng.randi() & 0x7fffffff)


## One spot ("kelp" or "arch") at `at`, with its meshes.
func add_spot(at: Vector3, radius: float, kind: String, seed_value: int) -> void:
	var marker := Marker.new()
	marker.index = spots.size()
	marker.kind = kind
	marker.spot_name = "%s %d" % ["Kelp stand" if kind == "kelp" else "Rock arch", marker.index + 1]
	marker.radius = radius
	marker.name = "Shadow%d" % marker.index
	marker.add_to_group("ws_echo_shadow")
	add_child(marker)
	marker.global_position = at
	_markers.append(marker)
	spots.append({"name": marker.spot_name, "kind": kind, "position": at, "radius": radius})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if kind == "kelp":
		_kelp_stand(marker, radius, rng)
	else:
		_rock_arch(marker, radius, rng)


func clear() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
	spots.clear()


func count() -> int:
	return spots.size()


## The index of the spot whose sphere holds `point`, nearest middle first; -1 for none.
func spot_at(point: Vector3) -> int:
	var best := -1
	var best_gap := INF
	for i in spots.size():
		var gap := point.distance_to(spots[i]["position"] as Vector3)
		if gap <= float(spots[i]["radius"]) and gap < best_gap:
			best_gap = gap
			best = i
	return best


func in_shadow(point: Vector3) -> bool:
	return spot_at(point) >= 0


## A stand of giant kelp on a rock, about the spot's size.
func _kelp_stand(marker: Marker, radius: float, rng: RandomNumberGenerator) -> void:
	var base_y := -radius * 0.6
	_piece(marker, ReefKit.mesh("boulder", rng.randi_range(0, ReefKit.VARIANTS - 1)), Vector3(0.0, base_y, 0.0), Vector3.ONE * radius * 0.5, rng.randf() * TAU)
	for n in KELP_PER_STAND:
		var flat := Vector2.from_angle(rng.randf() * TAU) * radius * 0.5 * sqrt(rng.randf())
		var tall := radius * rng.randf_range(0.22, 0.3)  # the kelp is about 8 m at scale 1
		_piece(marker, ReefKit.mesh("kelp", rng.randi_range(0, ReefKit.VARIANTS - 1)), Vector3(flat.x, base_y + radius * 0.1, flat.y), Vector3.ONE * tall, rng.randf() * TAU)


## Two rock pillars with a slab across, the gap between them big enough for a loner.
func _rock_arch(marker: Marker, radius: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	var across := Basis(Vector3.UP, yaw).x
	var base_y := -radius * 0.6
	for side in [-1.0, 1.0]:
		var at: Vector3 = across * radius * ARCH_SPAN * side
		_piece(marker, ReefKit.mesh("boulder", rng.randi_range(0, ReefKit.VARIANTS - 1)), at + Vector3(0.0, base_y + radius * 0.35, 0.0), Vector3(radius * 0.42, radius * 0.9, radius * 0.42), rng.randf() * TAU)
	_piece(marker, ReefKit.mesh("slab", rng.randi_range(0, ReefKit.VARIANTS - 1)), Vector3(0.0, base_y + radius * 0.95, 0.0), Vector3(radius * 1.5, radius * 1.1, radius * 0.8), yaw)


func _piece(marker: Marker, mesh: Mesh, at: Vector3, scale_by: Vector3, yaw: float) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.basis = Basis(Vector3.UP, yaw).scaled(scale_by)
	marker.add_child(part)
