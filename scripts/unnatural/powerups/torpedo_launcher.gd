class_name TorpedoLauncher
extends Powerup
## Torpedo Launcher (planning_unnatural.md §7): any hit has a chance to fire
## heat-seeking torpedoes from the fish (1, and another every
## torpedo_stacks_per_extra stacks), each after its own nearest zombie. One
## explodes on impact (or when its time's up): torpedo_damage to every zombie
## in the blast (proc coefficient torpedo_proc, so it can start lightning but
## never torpedoes again). More stacks: more chance, more torpedoes, a bigger blast.

## Torpedoes fired and blasts so far, for the probes.
var fired := 0
var blasts := 0


func chance() -> float:
	return settings.torpedo_chance + settings.torpedo_chance_per_stack * (stacks - 1)


func count() -> int:
	return 1 + (stacks - 1) / maxi(settings.torpedo_stacks_per_extra, 1)


func blast() -> float:
	return settings.torpedo_blast + settings.torpedo_blast_per_stack * (stacks - 1)


func on_hit(_index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	if roll(chance() * proc):
		launch(chain)


## count() torpedoes from the fish, at its nearest zombies.
func launch(chain: Array) -> void:
	var from := fish.global_position
	var near := run.horde.query_sphere(from, 40.0)
	var sorted := Array(near)
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return run.horde.enemy_position(a).distance_squared_to(from) < run.horde.enemy_position(b).distance_squared_to(from))
	for n in count():
		var torpedo := Torpedo.new()
		torpedo.launcher = self
		torpedo.chain = chain + [id]
		torpedo.target = sorted[n % sorted.size()] if not sorted.is_empty() else -1
		var spread := Vector3(run.rng.randf_range(-1, 1), run.rng.randf_range(0.2, 1.0), run.rng.randf_range(-1, 1)).normalized()
		torpedo.velocity = (-fish.global_basis.z * 0.6 + spread * 0.4).normalized() * settings.torpedo_speed * 0.5
		torpedo.position = from + spread * 0.6
		run.add_child(torpedo)
		fired += 1


## A torpedo's blast at `at`.
func explode(at: Vector3, chain: Array) -> void:
	blasts += 1
	var reach := blast()
	Explosion.spawn(run.ocean, at, Powerup.color(id), reach, 0.0, 0.25)
	for i in run.horde.query_sphere(at, reach):
		var push := run.horde.enemy_position(i) - at
		run.hit(i, settings.torpedo_damage, fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP,
				run.powerup_settings.torpedo_proc, chain)


## One heat-seeking torpedo.
class Torpedo extends Node3D:
	const TURN := 6.0
	var launcher: TorpedoLauncher
	var chain: Array = []
	var target := -1
	var velocity := Vector3.ZERO
	var age := 0.0

	func _ready() -> void:
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.12
		capsule.height = 0.7
		capsule.radial_segments = 8
		capsule.rings = 2
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.5, 0.52, 0.55)
		metal.metallic = 0.7
		metal.emission_enabled = true
		metal.emission = Powerup.color("torpedo")
		metal.emission_energy_multiplier = 0.8
		capsule.material = metal
		body.mesh = capsule
		body.rotation.x = PI / 2.0  # along -z
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)

	func _physics_process(delta: float) -> void:
		age += delta
		var horde := launcher.run.horde
		var settings := launcher.settings
		if not horde.is_alive(target):
			target = horde.nearest_in_cone(global_position, Vector3.FORWARD, 30.0, -1.0)
		var speed := settings.torpedo_speed
		if target >= 0:
			var to := horde.enemy_position(target) - global_position
			if to.length() <= horde.enemy_radius(target) + 0.4:
				_boom()
				return
			velocity = velocity.lerp(to.normalized() * speed, 1.0 - exp(-TURN * delta))
		velocity = velocity.normalized() * minf(velocity.length() + speed * 2.0 * delta, speed)
		global_position += velocity * delta
		if velocity.length_squared() > 0.01:
			look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.BACK)
		if age >= settings.torpedo_life:
			_boom()

	func _boom() -> void:
		launcher.explode(global_position, chain)
		queue_free()
