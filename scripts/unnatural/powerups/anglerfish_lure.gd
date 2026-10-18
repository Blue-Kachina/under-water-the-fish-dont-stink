class_name AnglerfishLure
extends Powerup
## Anglerfish Lure (planning_unnatural.md §7b, D14, rare): a lantern on a
## stalk. Every interval() s it drops a glowing decoy where the fish is; the
## horde chases it (UnnaturalRun.decoys: lure_pull, so it wins over a player up
## to that many times nearer) for lure_life s, then it bursts: damage() to
## every zombie within lure_blast m (proc coefficient lure_proc).
## Online, a decoy draws only the zombies on the machine that dropped it.

## Lures dropped and burst so far, for the probes.
var dropped := 0
var burst := 0
var lures: Array[Lure] = []
var _next := 0.0


func interval() -> float:
	return settings.lure_interval * pow(1.0 - settings.lure_interval_per_stack, stacks - 1)


func damage() -> float:
	return settings.lure_damage + settings.lure_damage_per_stack * (stacks - 1)


func on_stacks_changed() -> void:
	if dropped == 0:
		_next = minf(_next, 1.0)  # the first one soon after it's got


func on_tick(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = interval()
		drop()
	for k in range(lures.size() - 1, -1, -1):
		var lure := lures[k]
		if not is_instance_valid(lure):
			lures.remove_at(k)
			continue
		lure.age += delta
		if lure.age >= settings.lure_life:
			lures.remove_at(k)
			pop(lure.global_position)
			lure.queue_free()


## A decoy where the fish is, now.
func drop() -> void:
	var lure := Lure.new()
	lure.tint = color(id)
	lure.pull = settings.lure_pull
	run.add_child(lure)
	lure.global_position = fish.global_position
	lures.append(lure)
	run.decoys.append(lure)
	dropped += 1


func pop(at: Vector3) -> void:
	burst += 1
	Explosion.spawn(run.ocean, at, color(id), settings.lure_blast, 0.0, 0.3)
	for i in run.horde.query_sphere(at, settings.lure_blast):
		var push := run.horde.enemy_position(i) - at
		run.hit(i, damage(), fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP, settings.lure_proc, [id])


func on_removed() -> void:
	for lure in lures:
		if is_instance_valid(lure):
			lure.queue_free()
	lures.clear()


## A stalk arching forward off the head, a glowing bulb on its end.
func make_worn() -> Node3D:
	var rod := Node3D.new()
	rod.name = "Lure"
	rod.position = Vector3(0.0, fish.hitbox_height * 0.5, -fish.hitbox_length * 0.25)
	var stalk_material := StandardMaterial3D.new()
	stalk_material.albedo_color = Color(0.3, 0.25, 0.22)
	stalk_material.roughness = 0.7
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.012
	stalk.bottom_radius = 0.025
	stalk.height = 0.4
	stalk.radial_segments = 6
	stalk.rings = 1
	rod.add_child(worn_mesh(stalk, stalk_material, Vector3(0.0, 0.17, -0.08), Vector3(-0.45, 0.0, 0.0)))
	var bulb := SphereMesh.new()
	bulb.radius = 0.07
	bulb.height = 0.14
	bulb.radial_segments = 8
	bulb.rings = 4
	var glow := worn_material(3.0)
	rod.add_child(worn_mesh(bulb, glow, Vector3(0.0, 0.36, -0.2)))
	rod.ready.connect(func() -> void:
		var pulse := rod.create_tween().set_loops()
		pulse.tween_property(glow, "emission_energy_multiplier", 4.5, 0.5)
		pulse.tween_property(glow, "emission_energy_multiplier", 2.0, 0.5))
	return rod


## A decoy: a white-hot bulb inside a membrane glowing at its rim, a soft halo
## round it and motes of light drifting off, with a light; it throbs, faster
## and bigger as it nears its burst. Fades near the camera.
class Lure extends Node3D:
	var age := 0.0
	var pull := 3.0
	var tint := Color.WHITE
	var _glow := StandardMaterial3D.new()
	var _ball := MeshInstance3D.new()
	var _skin := MeshInstance3D.new()
	var _halo := MeshInstance3D.new()
	var _halo_material: StandardMaterial3D

	func _ready() -> void:
		_glow.albedo_color = tint.lerp(Color.WHITE, 0.6)
		_glow.emission_enabled = true
		_glow.emission = tint.lerp(Color.WHITE, 0.4)
		_glow.emission_energy_multiplier = 3.0
		FxKit.fade_near(_glow)
		var core := SphereMesh.new()
		core.radius = 0.22
		core.height = 0.44
		core.radial_segments = 12
		core.rings = 6
		core.material = _glow
		_ball.mesh = core
		_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ball)
		var skin := SphereMesh.new()
		skin.radius = 0.5
		skin.height = 1.0
		skin.radial_segments = 16
		skin.rings = 8
		skin.material = FxKit.rim(Color(tint, 0.9), 0.1, 0.5, true)
		_skin.mesh = skin
		_skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_skin)
		var quad := QuadMesh.new()
		quad.size = Vector2(2.6, 2.6)
		_halo_material = FxKit.glow(Color(tint, 0.5), FxKit.dot(), true)
		_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo_material.billboard_keep_scale = true
		_halo.mesh = quad
		_halo.material_override = _halo_material
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)
		var motes := CPUParticles3D.new()
		var mote := QuadMesh.new()
		mote.size = Vector2(0.14, 0.14)
		var mote_material := FxKit.glow(tint.lerp(Color.WHITE, 0.3), FxKit.dot(), true)
		mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mote.material = mote_material
		motes.mesh = mote
		motes.amount = 8
		motes.lifetime = 1.6
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = 0.4
		motes.direction = Vector3.UP
		motes.spread = 60.0
		motes.initial_velocity_min = 0.2
		motes.initial_velocity_max = 0.6
		motes.gravity = Vector3(0, 0.3, 0)
		motes.local_coords = false
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(motes)
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 2.0
		light.omni_range = 7.0
		add_child(light)

	func _process(_delta: float) -> void:
		# Quicker and bigger toward the burst.
		var urgency := clampf(age / maxf(PowerupSettings.shared().lure_life, 0.1), 0.0, 1.0)
		var beat := sin(age * lerpf(7.0, 18.0, urgency))
		var throb := 1.0 + 0.12 * beat + urgency * 0.35
		_ball.scale = Vector3.ONE * throb
		_skin.scale = Vector3.ONE * (throb * 0.95 + 0.05)
		_halo.scale = Vector3.ONE * (0.9 + 0.2 * beat + urgency * 0.5)
		_halo_material.albedo_color.a = 0.4 + 0.15 * beat + urgency * 0.2
		_glow.emission_energy_multiplier = 2.5 + 1.5 * beat
