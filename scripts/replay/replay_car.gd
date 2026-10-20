class_name ReplayCar
extends Node3D
## One replay player, drawn as the fish for its car's hitbox (FishModel) tinted
## in its team's colour, sized to that hitbox. Pure playback: no physics, set from ReplayData samples every
## rendered frame. Its origin is the hitbox centre, like the live fish's.
##
## A fish recorded in this game (a GoalRecorder clip) also carries its looks
## (ReplayData.FX_*): it then swings and grows its stride tail, lights its
## timing cue, pushes its bow wave and pours its stride bubbles as it did live.
## time_scale slows all of that (and its swimming) with slow-motion playback.
##
## It offers the same read-only fields the follow camera and the HUD's input
## display read from the live fish (on_surface, linear_velocity,
## is_flipping(), input_stick and so on), so either can follow it.

const BUBBLES_SCENE := preload("res://scenes/fish_bubbles.tscn")
## Closer than this (m) from the arena's surface to the hitbox centre counts as
## driving on it (RL's car rides with its hitbox centre about 0.38 m up).
const SURFACE_DISTANCE := 0.55

var player := {}
var team := 0
var hitbox_size := Vector3.ONE
var hitbox_offset := Vector3.ZERO
var show_hitbox := false:
	set(value):
		show_hitbox = value
		if _hitbox_view:
			_hitbox_view.visible = value
var show_name := true:
	set(value):
		show_name = value
		if _label:
			_label.visible = value

# Read like the live fish's (see the class description).
var linear_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var on_surface := false
var speed := 0.0
var boost_amount := 0.0
var is_boosting := false
var is_powersliding := false
var is_supersonic := false
var flags := 0
var input_forward := 0.0
var input_reverse := 0.0
var input_stick := Vector2.ZERO
var input_roll := 0.0
var boost_held := false
var air_roll_held := false
var direction_lock_held := false
## The clip's looks at this moment (ReplayData.FX_*), or empty.
var fx := PackedFloat32Array()
## Clip seconds per real second (GoalReplay's slow motion): the swimming,
## bow wave and bubbles keep pace with the playback.
var time_scale := 1.0

var _visual: FishModel
var _tail: Node3D
var _fin_left: Node3D
var _fin_right: Node3D
var _bubbles: CPUParticles3D
var _hitbox_view := MeshInstance3D.new()
var _label := Label3D.new()
var _burst := CPUParticles3D.new()
var _swim_phase := 0.0
var _bow_view := MeshInstance3D.new()
var _bow_material := ShaderMaterial.new()
var _bow_flow := 0.0
var _stream := StrideStream.new()


func setup(replay_player: Dictionary) -> void:
	player = replay_player
	team = player.team
	hitbox_size = player.hitbox_size
	hitbox_offset = player.hitbox_offset
	name = "Ghost%d" % player.index


## The skin a replay player's fish wears: its recorded "skin" key, or its
## family's first (RL replays and clips from before skins have none).
static func skin_of(replay_player: Dictionary) -> int:
	var family := FishCharacter.from_key(str(replay_player.get("hitbox_family", "octane")))
	return FishCharacter.skin_from_key(family, str(replay_player.get("skin", "")))


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved every rendered frame
	var color: Color = AquariumArena.TEAM_COLORS[team]

	# The fish the live game has for this car's hitbox, and its boost bubbles.
	var family := FishCharacter.from_key(player.get("hitbox_family", "octane"))
	_visual = FishModel.build(family, skin_of(player))
	add_child(_visual)
	_bubbles = BUBBLES_SCENE.instantiate()
	_bubbles.position = Vector3(0.0, 0.0, hitbox_size.z * 0.75)  # behind the tail, as on the fish
	add_child(_bubbles)
	_tail = _visual.tail
	_fin_left = _visual.fin_left
	_fin_right = _visual.fin_right
	_visual.scale = hitbox_size / FishCharacter.hitbox_size(family)
	_visual.set_body_color(color)
	_bubbles.emitting = false

	var box := BoxMesh.new()
	box.size = hitbox_size
	var hitbox_material := StandardMaterial3D.new()
	hitbox_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hitbox_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hitbox_material.albedo_color = Color(color, 0.3)
	hitbox_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hitbox_view.mesh = box
	_hitbox_view.material_override = hitbox_material
	_hitbox_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hitbox_view.visible = show_hitbox
	add_child(_hitbox_view)

	_label.text = player.name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.font_size = 28
	_label.outline_size = 8
	_label.modulate = color.lightened(0.4)
	_label.no_depth_test = true
	_label.position = Vector3(0.0, hitbox_size.y / 2.0 + 0.45, 0.0)
	_label.visible = show_name
	add_child(_label)

	_bow_view.name = "BowWave"
	_bow_view.mesh = FishController.bow_mesh()
	_bow_material.shader = FishController.BOW_SHADER
	_bow_view.material_override = _bow_material
	_bow_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_view.visible = false
	add_child(_bow_view)
	_stream.name = "StrideStream"
	add_child(_stream)

	_build_burst(color)


## Show the car as `sample` has it (a ReplayData.Sample from sample_car).
func apply(sample: ReplayData.Sample) -> void:
	visible = sample.present
	fx = sample.fx
	if not sample.present:
		_bubbles.emitting = false
		return
	var basis := Basis(sample.rotation)
	global_transform = Transform3D(basis, sample.position + basis * hitbox_offset)
	linear_velocity = sample.velocity
	angular_velocity = sample.angular_velocity
	speed = sample.velocity.length()
	flags = sample.flags
	boost_amount = sample.boost
	is_boosting = flags & ReplayData.FLAG_BOOST != 0
	is_powersliding = flags & ReplayData.FLAG_POWERSLIDE != 0
	is_supersonic = flags & ReplayData.FLAG_SUPERSONIC != 0
	boost_held = is_boosting
	input_forward = maxf(sample.throttle, 0.0)
	input_reverse = maxf(-sample.throttle, 0.0)
	input_stick = Vector2(sample.steer, 0.0)
	var jumping := flags & (ReplayData.FLAG_JUMP | ReplayData.FLAG_DOUBLE_JUMP | ReplayData.FLAG_DODGE) != 0
	on_surface = not jumping and AquariumArena.distance_outside(global_position) > -SURFACE_DISTANCE
	_bubbles.emitting = is_boosting


func is_flipping() -> bool:
	return flags & ReplayData.FLAG_DODGE != 0


## The burst where the car was: an RL demo, or in a goal replay of ours a battery.
func explode() -> void:
	_burst.global_position = global_position
	_burst.restart()


func _process(real_delta: float) -> void:
	if not visible:
		_bow_view.visible = false
		return
	var delta := real_delta * time_scale
	# The live fish's swimming animation, driven by the replay's inputs.
	var effort := maxf(input_forward, 1.0 if is_boosting else 0.0)
	_swim_phase += delta * lerpf(4.0, 18.0, effort)
	var slide := 1.0 if is_powersliding else 0.0
	var recorded := fx.size() == ReplayData.FX_SIZE
	if recorded:
		_tail.rotation = Vector3(fx[ReplayData.FX_TAIL_PITCH], fx[ReplayData.FX_TAIL_YAW], 0.0)
		_tail.scale = Vector3.ONE * maxf(fx[ReplayData.FX_TAIL_SCALE], 0.01)
	else:
		_tail.rotation.y = sin(_swim_phase) * lerpf(0.15, 0.45, effort) - input_stick.x * 0.6 * slide
		_tail.rotation.x = 0.0
	_fin_left.rotation.y = lerpf(_fin_left.rotation.y, 0.9 * slide, 1.0 - exp(-15.0 * delta))
	_fin_right.rotation.y = -_fin_left.rotation.y
	var flutter := sin(Time.get_ticks_msec() * 0.05) * 0.7 * input_reverse
	_fin_left.rotation.z = flutter
	_fin_right.rotation.z = -flutter
	_visual.grounded = on_surface
	if recorded:
		_visual.stride_swing = Vector2(fx[ReplayData.FX_SWING_X], fx[ReplayData.FX_SWING_Y])
		_visual.stride_power = fx[ReplayData.FX_POWER]
		_visual.set_stride_cue(fx[ReplayData.FX_CUE_FILL], fx[ReplayData.FX_CUE_GLOW], fx[ReplayData.FX_CUE_SWEET])
	_visual.react(delta, linear_velocity)
	_show_bow(delta, recorded)
	if recorded and fx[ReplayData.FX_POUR] > 0.0:
		_pour(delta)


## The bow wave as recorded.
func _show_bow(delta: float, recorded: bool) -> void:
	_bow_view.visible = recorded and fx[ReplayData.FX_BOW] > 0.005
	if not _bow_view.visible:
		return
	_bow_view.scale = Vector3(fx[ReplayData.FX_BOW_X], fx[ReplayData.FX_BOW_Y], fx[ReplayData.FX_BOW_Z])
	_bow_flow += delta * speed * 0.8
	_bow_material.set_shader_parameter("amount", fx[ReplayData.FX_BOW])
	_bow_material.set_shader_parameter("flow", _bow_flow)


## The stride bubbles as poured live (FishController._pour_bubbles): from the
## tail's tip, back and out to the side it swings from.
func _pour(delta: float) -> void:
	var tip := _tail.global_transform * _visual.tail_tip()
	var body := global_basis.orthonormalized()
	var swing := Vector2(fx[ReplayData.FX_SWING_X], fx[ReplayData.FX_SWING_Y])
	var side := body.x * swing.x - body.y * swing.y
	var jet := (body.z + side * 0.4).normalized()
	var color := Color(fx[ReplayData.FX_POUR_R], fx[ReplayData.FX_POUR_G], fx[ReplayData.FX_POUR_B], fx[ReplayData.FX_POUR_A])
	_stream.pour(delta, tip, jet, linear_velocity * 0.75, 0.025 * _tail.scale.x, fx[ReplayData.FX_POUR], color)
	_stream.time_scale = time_scale


func _build_burst(color: Color) -> void:
	var bubble := SphereMesh.new()
	bubble.radius = 0.1
	bubble.height = 0.2
	bubble.radial_segments = 8
	bubble.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.lightened(0.5), 0.7)
	bubble.material = material
	_burst.mesh = bubble
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.amount = 80
	_burst.lifetime = 1.5
	_burst.local_coords = false
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_burst.emission_sphere_radius = 0.6
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.gravity = Vector3(0, 2.0, 0)
	_burst.initial_velocity_min = 3.0
	_burst.initial_velocity_max = 9.0
	_burst.damping_min = 4.0
	_burst.damping_max = 8.0
	_burst.name = "%sBurst" % name
	# Beside the car, not under it: the car is hidden once it's demolished.
	get_parent().add_child.call_deferred(_burst)
