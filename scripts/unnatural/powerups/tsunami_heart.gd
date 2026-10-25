class_name TsunamiHeart
extends Powerup
## Tsunami Heart (planning_unnatural.md §7b, D14, legendary): a glowing heart.
## A battery sends a wave rolling along the fish's heading, width() m wide,
## tsunami_length m at tsunami_speed m/s. Every zombie it reaches takes
## damage() and is swept along (proc coefficient tsunami_proc), once a wave.
## At most one wave every tsunami_cooldown s.

## Waves sent and zombies they've hit so far, for the probes.
var waves := 0
var swept := 0
var _cool := 0.0


func width() -> float:
	return (settings.tsunami_width + settings.tsunami_width_per_stack * extra()) * size_scale()


func damage() -> float:
	return settings.tsunami_damage + settings.tsunami_damage_per_stack * extra()


func on_tick(delta: float) -> void:
	_cool = maxf(_cool - delta * rate_scale(), 0.0)


func on_battery(_index: int) -> void:
	if _cool > 0.0:
		return
	_cool = settings.tsunami_cooldown
	send(-fish.global_basis.z)


## A wave from the fish along `heading`.
func send(heading: Vector3) -> void:
	waves += 1
	var wave := Wave.new()
	wave.heart = self
	wave.heading = heading.normalized()
	wave.width = width()
	wave.reach = settings.tsunami_length
	wave.speed = settings.tsunami_speed
	run.add_child(wave)
	wave.global_position = fish.global_position
	Sfx.play_at("pw/tsunami_wave", fish.global_position)
	wave.look_at(fish.global_position + wave.heading, Vector3.UP if absf(wave.heading.y) < 0.98 else Vector3.BACK)


## A glowing heart on the chest.
func make_worn() -> Node3D:
	var heart := Node3D.new()
	heart.name = "Heart"
	heart.position = Vector3(0.0, -fish.hitbox_height * 0.2, -fish.hitbox_length * 0.3)
	var glow := worn_material(2.0)
	var shape := worn_mesh(FxLooks.heart(), glow, Vector3.ZERO)
	shape.scale = Vector3.ONE * 0.4
	heart.add_child(shape)
	heart.ready.connect(func() -> void:
		var beat := heart.create_tween().set_loops()
		beat.tween_property(glow, "emission_energy_multiplier", 4.0, 0.1)
		beat.tween_property(glow, "emission_energy_multiplier", 1.5, 0.15)
		beat.tween_property(glow, "emission_energy_multiplier", 3.2, 0.1)
		beat.tween_property(glow, "emission_energy_multiplier", 1.2, 0.55))
	return heart


## One wave: a curling wall of water rolling forward (its lip leading, -Z),
## hitting each zombie it reaches once (planning_environment.md, Phase 6:
## a breaking wave, foam at its lip, spray off it).
class Wave extends Node3D:
	var heart: TsunamiHeart
	var heading := Vector3.FORWARD
	var width := 6.0
	var reach := 24.0
	var speed := 30.0
	var _gone := 0.0
	var _hit := {}
	var _material := ShaderMaterial.new()
	var _wall := MeshInstance3D.new()
	var _spray := CPUParticles3D.new()

	## A breaking wave `width` m across: its back rising to a crest, the lip
	## curling over in front, tapering at both ends. COLOR.r: how far round.
	static func curl_mesh(across: float) -> ArrayMesh:
		var tall := across * 0.32
		var kit := MeshKit.new()
		kit.surface(28, 30, func(u: float, v: float) -> Array:
			var x := (u - 0.5) * across
			var taper := pow(sin(u * PI), 0.6)
			var z := 0.0
			var y := 0.0
			if v < 0.5:
				var s := v / 0.5
				z = lerpf(1.6, 0.0, s)
				y = pow(sin(s * PI * 0.5), 1.3)
			else:
				var phi := (v - 0.5) / 0.5 * PI * 1.25
				var r := 0.42 * (1.0 - 0.45 * phi / (PI * 1.25))
				z = -sin(phi) * r
				y = 0.58 + cos(phi) * r
			return [Vector3(x, y * tall * taper, z * tall * taper), v, 0.0], false, false, false)
		return kit.mesh()

	func _ready() -> void:
		_material.shader = preload("res://shaders/wave.gdshader")
		var tint := Powerup.color("tsunami_heart")
		_material.set_shader_parameter("color", Vector3(tint.r, tint.g, tint.b))
		_wall.mesh = curl_mesh(width)
		_wall.material_override = _material
		_wall.position.y = -width * 0.16
		_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_wall)
		var drop := QuadMesh.new()
		drop.size = Vector2.ONE * 0.22
		var shine := FxKit.glow(Color(0.9, 0.97, 1.0, 0.7), FxKit.dot(), true)
		shine.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		drop.material = shine
		_spray.mesh = drop
		_spray.amount = 40
		_spray.lifetime = 0.6
		_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_spray.emission_box_extents = Vector3(width * 0.4, 0.1, 0.1)
		_spray.position = Vector3(0.0, width * 0.32 * 0.85 - width * 0.16, -width * 0.32 * 0.3)
		_spray.direction = Vector3(0.0, 0.6, -1.0)
		_spray.spread = 35.0
		_spray.initial_velocity_min = 2.0
		_spray.initial_velocity_max = 5.0
		_spray.gravity = Vector3(0.0, -3.0, 0.0)
		_spray.scale_amount_min = 0.5
		_spray.scale_amount_max = 1.4
		_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_spray)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(heart) or not is_instance_valid(heart.run):
			queue_free()
			return
		var step := speed * delta
		_gone += step
		global_position += heading * step
		var run := heart.run
		var at := global_position
		var reached := PackedInt32Array()
		var pushes := PackedVector3Array()
		for i in run.horde.query_sphere(at, width * 0.5):
			if _hit.has(i):
				continue
			_hit[i] = true
			heart.swept += 1
			reached.append(i)
			pushes.append(heading * 3.0)
		run.hit_area(reached, heart.damage(), heart.fish, heart.id, Vector3.INF, 0.0, heart.settings.tsunami_proc, [heart.id], pushes)
		var t := _gone / reach
		_material.set_shader_parameter("fade", clampf((1.0 - t) * 1.6, 0.0, 1.0))
		if _gone >= reach:
			queue_free()
