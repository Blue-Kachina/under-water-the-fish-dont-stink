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
	return (settings.tsunami_width + settings.tsunami_width_per_stack * (stacks - 1)) * size_scale()


func damage() -> float:
	return settings.tsunami_damage + settings.tsunami_damage_per_stack * (stacks - 1)


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
	var lobe := SphereMesh.new()
	lobe.radius = 0.07
	lobe.height = 0.14
	lobe.radial_segments = 8
	lobe.rings = 4
	for side: float in [-1.0, 1.0]:
		heart.add_child(worn_mesh(lobe, glow, Vector3(side * 0.055, 0.04, 0.0)))
	var tip := CylinderMesh.new()
	tip.top_radius = 0.1
	tip.bottom_radius = 0.0
	tip.height = 0.14
	tip.radial_segments = 8
	tip.rings = 1
	heart.add_child(worn_mesh(tip, glow, Vector3(0.0, -0.04, 0.0)))
	heart.ready.connect(func() -> void:
		var beat := heart.create_tween().set_loops()
		beat.tween_property(glow, "emission_energy_multiplier", 4.0, 0.1)
		beat.tween_property(glow, "emission_energy_multiplier", 1.5, 0.15)
		beat.tween_property(glow, "emission_energy_multiplier", 3.2, 0.1)
		beat.tween_property(glow, "emission_energy_multiplier", 1.2, 0.55))
	return heart


## One wave: a curling wall of water rolling forward, hitting each zombie it
## reaches once.
class Wave extends Node3D:
	var heart: TsunamiHeart
	var heading := Vector3.FORWARD
	var width := 6.0
	var reach := 24.0
	var speed := 30.0
	var _gone := 0.0
	var _hit := {}
	var _material := StandardMaterial3D.new()
	var _wall := MeshInstance3D.new()

	func _ready() -> void:
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.albedo_color = Color(Powerup.color("tsunami_heart"), 0.6)
		var curl := CylinderMesh.new()
		curl.top_radius = 1.0
		curl.bottom_radius = 1.0
		curl.height = 1.0
		curl.radial_segments = 16
		curl.rings = 1
		curl.cap_top = false
		curl.cap_bottom = false
		curl.material = _material
		_wall.mesh = curl
		# Lying across the way it goes: a half-pipe curl, `width` across.
		_wall.rotation = Vector3(0.0, 0.0, PI / 2.0)
		_wall.scale = Vector3(width * 0.25, width, width * 0.12)
		_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_wall)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(heart) or not is_instance_valid(heart.run):
			queue_free()
			return
		var step := speed * delta
		_gone += step
		global_position += heading * step
		var run := heart.run
		var at := global_position
		for i in run.horde.query_sphere(at, width * 0.5):
			if _hit.has(i):
				continue
			_hit[i] = true
			heart.swept += 1
			run.hit(i, heart.damage(), heart.fish, heart.id, heading * 3.0, heart.settings.tsunami_proc, [heart.id])
		var t := _gone / reach
		_material.albedo_color.a = 0.6 * (1.0 - t)
		if _gone >= reach:
			queue_free()
