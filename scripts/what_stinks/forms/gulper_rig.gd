extends Node3D
## The Gulper's body on a Hunter's fish (a child of the fish's model): a SpineRig in the
## model's own space, bent by the fish's own motion instead of the boss's AI. Its swim
## reads from the controller: the undulation grows with speed and the body trails each turn
## (yaw and pitch of the fish, each segment lagging the one before). The bite's `open`
## (GulperJaw) gapes the pouch and draws the suction streaks in.

const MODEL := preload("res://scripts/what_stinks/forms/gulper_model.gd")
const JAW := preload("res://scripts/what_stinks/forms/gulper_jaw.gd")
const N := SpineRig.SPINE_N
## The belly's fullness at rest (the boss skin's own default).
const REST_FULLNESS := 0.3

## How hard each segment follows the one ahead of it (1/s): higher is a stiffer body.
@export_range(2.0, 200.0, 1.0, "or_greater") var follow_rate := 50.0
## The sideways swim wave at rest and at full speed (x the boss's amplitude).
@export_range(0.0, 3.0, 0.05, "or_greater") var wave_idle := 0.2
@export_range(0.0, 3.0, 0.05, "or_greater") var wave_swim := 1.0
## The speed the wave is full at (x the fish's top boost speed).
@export_range(0.1, 2.0, 0.05, "or_greater") var wave_full_speed := 0.6
## How wide the mouth rests (0 shut to 1.25 gaping).
@export_range(0.0, 1.25, 0.05) var gape_idle := 0.15

var fish: FishController
## The model is built in the boss's own girth unit (1: its skin shader has metres in it), and this node scales it down to the box.
var k := 1.0
var unit := 0.02
var rig := SpineRig.new()
var jaw: JAW
var skin: ShaderMaterial
## The head's z in the model's space (the body is centred on the box).
var head_z := 0.0
var gape := 0.15
var speed_frac := 0.0

var _lag_yaw := PackedFloat32Array()
var _lag_pitch := PackedFloat32Array()
var _turn := Vector2.ZERO
var _last_basis := Basis.IDENTITY
var _last_at := Vector3.ZERO
var _speed := 0.0
var _riders: Array = []
var _light: OmniLight3D
var _suction: CPUParticles3D
## Seconds the suction keeps streaming after a bite lands (the snap chomp opens and shuts too fast to draw it).
var _suck_left := 0.0
var _gape_hold := 0.0
var _bite: HunterBite
var _fresh := true


func setup(for_fish: FishController) -> void:
	name = "Gulper"
	fish = for_fish
	unit = FishCharacter.hitbox_size(FishCharacter.FishClass.MONSTER).z / MODEL.UNITS * 0.97
	scale = Vector3.ONE * unit
	head_z = -MODEL.UNITS * k * 0.5
	var look: Dictionary = MODEL.build(k)
	skin = look.skin
	rig.length = MODEL.UNITS * k
	rig.reach = 7.0 * k
	var node := MeshInstance3D.new()
	node.name = "GulperMesh"
	node.mesh = look.mesh
	node.material_override = skin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	rig.materials.append(skin)
	rig.instances.append(node)
	for eye: Array in look.eyes:
		_add_rider(eye[0], eye[1], eye[2])
	var lure: Array = look.lure
	_add_rider(lure[0], lure[1], Basis.IDENTITY)
	_light = (lure[0] as Node3D).get_node("LureLight") as OmniLight3D
	_suction = _suction_particles()
	add_child(_suction)
	jaw = JAW.new()
	jaw.mouth_at = Vector3(0.0, MODEL.RIM_Y * k * 0.8, head_z + 2.0 * k) * unit  # in the model's space, not ours
	_lag_yaw.resize(N)
	_lag_pitch.resize(N)
	_pose(0.0)


func _add_rider(node: Node3D, at: Vector3, basis: Basis) -> void:
	add_child(node)
	_riders.append([node, at, basis.scaled(node.scale)])


## Grit and water streaming into its mouth while the bite is open (the boss's suction, in model units).
func _suction_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Suction"
	p.emitting = false
	p.amount = 80
	p.lifetime = 0.8
	p.local_coords = true
	p.position = Vector3(0.0, MODEL.RIM_Y * k * 0.8, head_z + 1.0 * k)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 15.0 * k
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 2.0 * k
	p.radial_accel_min = -55.0 * k
	p.radial_accel_max = -40.0 * k
	p.gravity = Vector3.ZERO
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	var streak := BoxMesh.new()
	streak.size = Vector3(0.05, 0.9, 0.05) * k
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.albedo_color = Color(0.75, 0.85, 0.9, 0.35)
	streak.material = look
	p.mesh = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _straighten() -> void:
	_lag_yaw.fill(0.0)
	_lag_pitch.fill(0.0)
	_turn = Vector2.ZERO


func _process(delta: float) -> void:
	if not is_instance_valid(fish) or delta <= 0.0 or not is_visible_in_tree():
		return
	var basis := fish.global_basis.orthonormalized()
	var at := fish.global_position
	if _fresh or at.distance_to(_last_at) > 20.0 or (basis * _last_basis.inverse()).get_rotation_quaternion().get_angle() > 1.0:  # the first frame, or put somewhere new: nothing to trail
		_fresh = false
		_last_basis = basis
		_last_at = at
		_straighten()
	# What the fish just did: its turn about its own up and right, and its speed.
	var spin := (basis * _last_basis.inverse()).get_rotation_quaternion()
	var angle := spin.get_angle()
	var omega := Vector3.ZERO
	if angle > 0.0001:
		omega = spin.get_axis() * (angle if angle < PI else angle - TAU) / delta
	var turn := Vector2(omega.dot(basis.y), omega.dot(basis.x)).limit_length(8.0)
	_turn = _turn.lerp(turn, 1.0 - exp(-12.0 * delta))
	_speed = lerpf(_speed, at.distance_to(_last_at) / delta, 1.0 - exp(-8.0 * delta))
	_last_basis = basis
	_last_at = at
	speed_frac = clampf(_speed / maxf(fish.max_boost_speed * fish.top_speed_scale * wave_full_speed, 0.1), 0.0, 1.0)
	_pose(delta)
	_dress(delta)


## Lays the spine along the body's lag: each segment a little behind the turn the one before it made.
func _pose(delta: float) -> void:
	var rate := 1.0 - exp(-follow_rate * delta)
	for s in range(1, N):
		_lag_yaw[s] = clampf(_lag_yaw[s] - _turn.x * delta, -1.5, 1.5)
		_lag_pitch[s] = clampf(_lag_pitch[s] - _turn.y * delta, -1.0, 1.0)
		_lag_yaw[s] = lerpf(_lag_yaw[s], _lag_yaw[s - 1], rate)
		_lag_pitch[s] = lerpf(_lag_pitch[s], _lag_pitch[s - 1], rate)
	var step := rig.length / float(N - 1)
	rig.points[0] = Vector3(0.0, 0.0, head_z)
	for s in range(1, N):
		var dir := Basis(Vector3.RIGHT, _lag_pitch[s]) * (Basis(Vector3.UP, _lag_yaw[s]) * Vector3.BACK)
		rig.points[s] = rig.points[s - 1] + dir * step
	rig._frames()
	rig.apply()
	for rider: Array in _riders:
		var node: Node3D = rider[0]
		var rest: Vector3 = rider[1]
		var frame := rig.frame_at(rest.z)
		node.transform = Transform3D(frame.basis * (rider[2] as Basis), frame.origin + frame.basis.x * rest.x + frame.basis.y * rest.y)


## A snap chomp opens and shuts in a few ticks: the pouch balloons wide on the strike instead, and the suction streams a moment.
func _on_bite_landed() -> void:
	_suck_left = 0.3
	gape = 1.25
	_gape_hold = 0.15

## The look that follows the swim and the bite: the wave's size, the gape, the suction, the lure's light.
func _dress(delta: float) -> void:
	var open := jaw.opened
	var swim := lerpf(wave_idle, wave_swim, speed_frac)
	skin.set_shader_parameter("spine_wave", Vector4(0.9 * k * swim, 0.2 / k, 3.0, 0.3))
	_gape_hold = maxf(_gape_hold - delta, 0.0)
	if _gape_hold <= 0.0:
		gape = move_toward(gape, gape_idle + open * (1.25 - gape_idle), delta * 6.0)
	skin.set_shader_parameter("gape", gape)
	if _bite == null or not is_instance_valid(_bite):
		_bite = fish.get_node_or_null("HunterBite") as HunterBite
		if _bite:
			_bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: _on_bite_landed())
	var suction := _bite.attack as SuctionAttack if _bite != null else null
	if suction != null:  # the belly: full while fish crowd the mouth, a lump sliding down it after the snap
		skin.set_shader_parameter("fullness", lerpf(REST_FULLNESS, 1.0, suction.fullness))
		skin.set_shader_parameter("lump", suction.lump_vec(_bite, skin.get_shader_parameter("belly_span")))
	_suck_left = maxf(_suck_left - delta, 0.0)
	_suction.emitting = open > 0.3 or _suck_left > 0.0
	_light.omni_range = 0.3 * fish.hitbox_length
	_light.light_energy = 2.5 + sin(Time.get_ticks_msec() * 0.0031) * 0.8
