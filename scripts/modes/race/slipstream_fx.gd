class_name SlipstreamFx
extends Node3D
## The slipstream's look (planning_race.md section 8): a racer swimming fast trails thin streaks of bubbles from its tail,
## and a racer sitting in another's wake (the cone RaceMatch tests: `slip_length` body lengths behind, `slip_angle`
## wide) makes that leader's streaks thicker and brighter, so the draft reads from both sides. RaceMatch applies the
## speed (race.slip); this is only the picture, and finds the racers itself (the fish group), so it needs no calls.

const STREAK_SHADER := preload("res://shaders/race_streak.gdshader")
## Streaks start above this speed (m/s), and the draft's glow eases in and out at this rate (per second).
const MIN_SPEED := 7.0
const GLOW_RATE := 4.0

var settings: RaceSettings

var _emitters := {}  # FishController -> {"base": CPUParticles3D, "draft": CPUParticles3D, "glow": float}
var _mesh: Mesh


func _process(delta: float) -> void:
	if settings == null:
		return
	var fishes: Array[FishController] = []
	for node in get_tree().get_nodes_in_group(FishController.GROUP):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var fish := node as FishController
		if fish != null and fish.is_visible_in_tree() and not fish.freeze:
			fishes.append(fish)
	for key: Variant in _emitters.keys():  # untyped: a freed fish can't be assigned to a typed variable
		if not is_instance_valid(key):
			_drop(key)
		elif not fishes.has(key):
			_drop(key)
	for fish in fishes:
		var entry: Dictionary = _emitters.get(fish, {})
		if entry.is_empty():
			entry = _make(fish)
		var base: CPUParticles3D = entry["base"]
		var draft: CPUParticles3D = entry["draft"]
		var heading := -fish.global_basis.z
		var tail := fish.global_position - heading * fish.hitbox_length * 0.5
		var fast := fish.linear_velocity.length() > MIN_SPEED and settings.slipstream
		var drafting := fast and _someone_in_wake(fish, fishes, heading)
		entry["glow"] = move_toward(float(entry["glow"]), 1.0 if drafting else 0.0, GLOW_RATE * delta)
		var look := Basis.looking_at(-heading, Vector3.UP)
		base.global_transform = Transform3D(look, tail)
		draft.global_transform = Transform3D(look, tail)
		base.emitting = fast
		draft.emitting = fast and float(entry["glow"]) > 0.05
		(draft.mesh.material as ShaderMaterial).set_shader_parameter("glow", float(entry["glow"]))


## Whether any other racer is in `leader`'s wake cone.
func _someone_in_wake(leader: FishController, fishes: Array[FishController], heading: Vector3) -> bool:
	var reach := settings.slip_length * maxf(leader.hitbox_length, 0.5)
	var cone := cos(deg_to_rad(settings.slip_angle))
	for other in fishes:
		if other == leader:
			continue
		var behind := other.global_position - leader.global_position
		var length := behind.length()
		if length < 0.5 or length > reach:
			continue
		if (-heading).dot(behind / length) >= cone:
			return true
	return false


func _make(fish: FishController) -> Dictionary:
	var size := maxf(fish.hitbox_length, 0.5)
	var entry := {"glow": 0.0}
	for kind in ["base", "draft"]:
		var particles := CPUParticles3D.new()
		particles.name = "%s_%s" % [kind, fish.get_instance_id()]
		var streak := CylinderMesh.new()
		streak.top_radius = 0.012 * size
		streak.bottom_radius = 0.012 * size
		streak.height = size * (1.4 if kind == "base" else 2.4)
		streak.radial_segments = 4
		streak.rings = 1
		streak.cap_top = false
		streak.cap_bottom = false
		var material := ShaderMaterial.new()
		material.shader = STREAK_SHADER
		material.set_shader_parameter("glow", 0.0 if kind == "draft" else -1.0)
		streak.material = material
		particles.mesh = streak
		particles.amount = 24 if kind == "base" else 40
		particles.lifetime = 0.7 if kind == "base" else 0.9
		particles.local_coords = false
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = size * (0.35 if kind == "base" else 0.55)
		particles.direction = Vector3(0.0, 0.0, -1.0)  # back along the racer (the emitter's -Z points aft)
		particles.spread = 6.0 if kind == "base" else 10.0
		particles.gravity = Vector3.ZERO
		particles.initial_velocity_min = 0.5
		particles.initial_velocity_max = 2.0
		particles.particle_flag_align_y = true
		particles.scale_amount_min = 0.7
		particles.scale_amount_max = 1.3
		particles.emitting = false
		add_child(particles)
		entry[kind] = particles
	_emitters[fish] = entry
	return entry


func _drop(fish: Variant) -> void:
	var entry: Dictionary = _emitters.get(fish, {})
	for kind in ["base", "draft"]:
		if entry.has(kind) and is_instance_valid(entry[kind]):
			(entry[kind] as Node).queue_free()
	_emitters.erase(fish)
