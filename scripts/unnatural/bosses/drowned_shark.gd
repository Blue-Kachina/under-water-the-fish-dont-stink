class_name DrownedShark
extends Boss
## The mini-boss (planning_unnatural.md §3): a huge zombie shark, the Shark's
## model shark_size times over, rotten and red-eyed. It hunts the nearest
## player; every shark_charge_every seconds it glows red for shark_telegraph
## (time to get out of the way), then charges in a straight line; every
## shark_call_every seconds it calls a ring of sardines round its target.
## It chomps (ChompKit): a player within shark_chomp_range ahead of its mouth
## makes it wind up over shark_chomp_wind s (its head pulls back and its snout
## lifts, its jaw drops open on its hinge, its upper jaw pushing forward, teeth
## bared, and holds wide), then lunge as its jaws slam shut, biting everyone
## at its mouth then for shark_chomp_damage, and saw its head side to side.
## Charging, its jaws hang wide and snap on the first player they reach (or
## at the charge's end, a clack on nothing).
## Killing it drops a chest and a big XP pearl (UnnaturalRun).

## Its jaws snapped shut at `at`, biting `bit` players.
signal chomped(at: Vector3, bit: int)
## A beat of its chomp's animation (ChompKit.CUES: anticipate, gape, hold, strike, contact,
## shake, recover, rest) at its mouth `at`: the hook for sounds and anything else that should
## land on the beat (a puppet's too: it plays the host's beats).
signal chomp_cue(cue: StringName, at: Vector3)

enum Mode { HUNT, TELEGRAPH, CHARGE }

## Its body as proxies: at least this many, spread along it (more as it grows).
const MIN_PARTS := 3
const ROT := Color(0.36, 0.42, 0.34)
## Its eyes' red: dark, nearly dried blood, so they smoulder rather than shine.
const EYE_RED := Color(0.26, 0.012, 0.01)

var mode := Mode.HUNT
var charges := 0
var calls := 0
## Its chomp: how far its jaw is open (0 shut to 1 gaping), and the counts.
var jaw := 0.0
var chomps := 0
var chomp_hits := 0

var _mode_left := 0.0
var _charge_left := 0.0
var _call_left := 0.0
var _charge_dir := Vector3.FORWARD
var _model: Node3D
var _glow := OmniLight3D.new()
var _eyes: Array[ShaderMaterial] = []
var _length := 1.0
var _chomp_cool := 1.0
var _bit_this_charge := false
## Its chomp's beats (ChompKit), and a puppet's: the host's phase index.
var _bite: ChompKit.Bite
var _net_bite := 0
## The jaw rig (HunterJaw, in the model's space: the body's own underside lifted
## off as the lower jaw, and the mouth's shape).
var _jaw := HunterJaw.new()
var _mouth := {}


func _ready() -> void:
	super()
	title = "THE DROWNED SHARK"
	name = "DrownedShark"
	_charge_left = settings.shark_charge_every
	_call_left = settings.shark_call_every * 0.5
	_bite = ChompKit.Bite.new(settings)
	_bite.cue.connect(_on_cue)
	_model = FishModel.build(FishCharacter.FishClass.HUNTER)
	_model.scale = Vector3.ONE * settings.shark_size
	add_child(_model)
	if _model.has_method("set_body_color"):
		_model.call("set_body_color", ROT)
	# Already in metres: x across, y up, z nose to tail.
	var hitbox := FishCharacter.hitbox_size(FishCharacter.FishClass.HUNTER)
	_length = hitbox.z * settings.shark_size
	var half_width := hitbox.x * 0.5 * settings.shark_size
	var half_height := hitbox.y * 0.5 * settings.shark_size
	# Its own eyes gone red: a red iris round a thin dark slit, glowing like an ember.
	for node in _model.find_children("Eye*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material and material.shader == FishModel.FISH_EYE:
			material.set_shader_parameter("iris", EYE_RED)
			material.set_shader_parameter("iris_inner", EYE_RED.darkened(0.6))
			material.set_shader_parameter("sheen", 0.1)
			material.set_shader_parameter("pupil", 0.5)
			material.set_shader_parameter("pupil_stretch", 0.3)
			_eyes.append(material)
	_glow.light_color = Color(1.0, 0.1, 0.05)
	_glow.omni_range = _length * 1.5
	_glow.light_energy = 0.0
	add_child(_glow)
	if _model is FishModel:
		_jaw.build(_model as FishModel, ROT)
		_mouth = _jaw.mouth
	# Enough proxies, each as thick as the body, to cover it nose to tail.
	var radius := (half_width + half_height) * 0.5
	var count := maxi(MIN_PARTS, ceili(_length * 0.7 / radius) + 1)
	for n in count:
		add_part(global_position, radius)
	_place_parts()


func contact() -> float:
	return settings.shark_contact * (1.6 if mode == Mode.CHARGE else 1.0) * settings.enemy_damage_scale


## While it glows: its charge's lane, as long as the charge will go.
func telegraph() -> Dictionary:
	if mode != Mode.TELEGRAPH:
		return {}
	var dir := -global_basis.z if puppet else _charge_dir
	var progress := 0.6 if puppet else 1.0 - _mode_left / maxf(settings.shark_telegraph, 0.01)
	return {"from": global_position, "dir": dir, "length": settings.shark_charge_speed * settings.shark_charge_time + _length * 0.5,
			"width": _length * 0.25, "progress": progress}


func _move(delta: float) -> void:
	var prey := target()
	var toward := Vector3.ZERO
	if prey:
		toward = prey.global_position - global_position
	var speed := settings.shark_speed * settings.enemy_speed_scale
	match mode:
		Mode.HUNT:
			steer(toward.normalized() * speed if toward != Vector3.ZERO else velocity * 0.98, 1.6, 12.0, delta)
			_charge_left -= delta
			if _charge_left <= 0.0 and prey and settings.shark_charge_speed > 0.0:
				mode = Mode.TELEGRAPH
				_mode_left = settings.shark_telegraph
				_bite.cancel()
		Mode.TELEGRAPH:
			steer(toward.normalized() * speed * 0.25 if toward != Vector3.ZERO else Vector3.ZERO, 3.0, 20.0, delta)
			_charge_dir = toward.normalized() if toward != Vector3.ZERO else -global_basis.z
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.CHARGE
				charges += 1
				_bit_this_charge = false
				_mode_left = settings.shark_charge_time
				velocity = _charge_dir * settings.shark_charge_speed * maxf(settings.enemy_speed_scale, 0.0)
		Mode.CHARGE:
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.HUNT
				_charge_left = settings.shark_charge_every
				if not _bit_this_charge and jaw > 0.5:
					_bit_this_charge = true
					_bite.strike_now(settings.shark_chomp_reach)  # a clack on nothing
	_call_left -= delta
	if _call_left <= 0.0 and prey and settings.shark_call_every > 0.0:
		_call_left = settings.shark_call_every
		_call(prey.global_position)
	_update_chomp(delta, prey)
	global_position += velocity * delta
	if velocity.length_squared() > 0.25:
		face(velocity)
	_puppet_update(delta)
	_place_parts()


func _puppet_update(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(age * 30.0)
	var warn := mode == Mode.TELEGRAPH or (_bite and _bite.winding())  # a charge's or a chomp's wind-up
	_glow.light_energy = (6.0 * pulse * settings.telegraph_glow if warn else 0.0) + flash * 4.0
	# Its eyes smoulder, and flare with the wind-up.
	var eye_glow := settings.shark_eye_glow * (1.0 + settings.shark_eye_flare * pulse if warn else 1.0)
	for material in _eyes:
		material.set_shader_parameter("glow", eye_glow)
	if puppet:
		# The host's chomp phase, played here: its bite lands on our own players.
		_bite.sync(_net_bite)
		if not _bite.busy() and mode == Mode.CHARGE:
			_bite.open = move_toward(_bite.open, 1.0, delta * 5.0)
		if _bite.update(delta):
			_snap()
		jaw = _bite.open
	_pose_head()
	_pose_jaw()


func _place_body() -> void:
	_place_parts()


## Its mode, plus its chomp's phase index (ChompKit.Phase) times 4.
func _net_mode() -> int:
	return mode + (_bite.index() << 2)


func _set_net_mode(net_mode: int) -> void:
	mode = (net_mode & 3) as Mode
	_net_bite = (net_mode >> 2) & 7


# --- The chomp ----------------------------------------------------------------

## Where its mouth is now (the world), a little in front of its jaws.
func mouth_point() -> Vector3:
	if _mouth.is_empty():
		return global_position - global_basis.z * _length * 0.45
	var front: Vector3 = _mouth.front
	return _model.to_global(front + Vector3(0.0, -0.03, -0.05) * float(_mouth.length))


## Its chomp each tick: a bite's beats (ChompKit.Bite: its head lunging with
## the strike, the bite landing as the jaws shut), or, charging, jaws wide for
## whoever it reaches.
func _update_chomp(delta: float, prey: FishController) -> void:
	_chomp_cool -= delta
	if not _bite.busy() and mode == Mode.CHARGE:
		jaw = move_toward(jaw, 1.0, delta * 5.0)
		_bite.open = jaw
		_bite.smear = ChompKit.POSE_WIND.lerp(ChompKit.POSE_LUNGE, 0.5).lerp(Vector3.ONE, 1.0 - jaw)  # a charge runs long
		if not _bit_this_charge and _reaching() > 0:
			_bit_this_charge = true
			_bite.strike_now(settings.shark_chomp_reach)
		return
	var landed := _bite.update(delta)
	jaw = _bite.open
	global_position += -global_basis.z * _bite.step  # pulling back, then the lunge
	if landed:
		_snap()
	if not _bite.busy() and prey and mode == Mode.HUNT and _chomp_cool <= 0.0 and settings.shark_chomp_range > 0.0:
		var off := prey.global_position - mouth_point()
		if off.length() <= settings.shark_chomp_range and off.dot(-global_basis.z) > off.length() * 0.3:
			_bite.start(settings.shark_chomp_wind, settings.shark_chomp_reach)


## Winding up a chomp (its jaws opening or held wide).
func chomp_winding() -> bool:
	return _bite.winding()


## Its head with the bite: the snout lifting as it winds up and dropping as it
## strikes, and sawing side to side once its jaws are shut (the model turns). The
## chomp's stylised smear (ChompKit.Bite.smear) squashes and stretches the whole
## body about its middle: swelling as it winds up, wrung long in the lunge, slammed
## flat on impact.
func _pose_head() -> void:
	if _model:
		_model.rotation = Vector3(_bite.lift * settings.chomp_lift, _bite.saw * settings.chomp_saw, 0.0)
		_model.scale = Vector3.ONE * settings.shark_size * (Vector3.ONE.lerp(_bite.smear, settings.chomp_smear))


## How many players are at its mouth, in its bite.
func _reaching() -> int:
	var mouth := mouth_point()
	var count := 0
	for fish in run.players:
		if not fish.puppet and run.is_up(fish) and fish.global_position.distance_to(mouth) <= settings.shark_chomp_reach + UnnaturalRun.PLAYER_RADIUS:
			count += 1
	return count


## Its jaws are shut (the contact frame): it bites everyone at its mouth now
## (our own players: a puppet's bite lands on the guest's), with the impact;
## nobody there, it's a heavy clack on nothing.
func _snap() -> void:
	_chomp_cool = settings.shark_chomp_every
	_bit_this_charge = true
	chomps += 1
	var mouth := mouth_point()
	var bit := 0
	for fish in run.players:
		if fish.puppet or not run.is_up(fish):
			continue
		if fish.global_position.distance_to(mouth) <= settings.shark_chomp_reach + UnnaturalRun.PLAYER_RADIUS:
			ChompKit.bite_player(run, fish, mouth, settings.shark_chomp_damage * settings.enemy_damage_scale * run.stage_damage(), title.capitalize(), self)
			bit += 1
	chomp_hits += bit
	if bit == 0:
		ChompKit.miss(run, mouth, settings.shark_chomp_reach)
	chomped.emit(mouth, bit)


# --- The jaw ------------------------------------------------------------------

## Its jaw as open as the chomp says (HunterJaw), flung past wide on the gape's overshoot.
func _pose_jaw() -> void:
	_jaw.set_overshoot(_bite.over)
	_jaw.pose(jaw)


## A beat of its chomp (ChompKit.CUES): the pad's growl and thumps for the players near
## (chomp_cue_rumble), then chomp_cue for sounds and the like. The landing's own impact
## (camera, hit-stop, rumble, blood) is _snap's.
func _on_cue(beat: StringName) -> void:
	if not is_instance_valid(run) or _model == null:
		return
	var at := mouth_point()
	var pad := settings.chomp_cue_rumble
	var near := maxf(settings.shark_chomp_range, 1.0) * 2.5
	match beat:
		&"anticipate":
			ChompKit.rumble_near(run, at, near, 0.25 * pad, _bite.duration(ChompKit.Phase.ANTICIPATE) + 0.1)  # the growl begins
		&"gape":
			ChompKit.rumble_near(run, at, near, 0.6 * pad, 0.12)  # the jaw cracks open
		&"hold":
			ChompKit.rumble_near(run, at, near, 0.4 * pad, _bite.duration(ChompKit.Phase.HOLD) + 0.05)  # held, shuddering
		&"shake":
			ChompKit.rumble_near(run, at, near, 0.7 * pad, settings.chomp_shake)  # it saws at what it caught
	chomp_cue.emit(beat, at)


## A ring of sardines round `around`.
func _call(around: Vector3) -> void:
	calls += 1
	var count := settings.shark_call_count
	for n in count:
		var angle := TAU * n / maxf(count, 1)
		var at := around + Vector3(cos(angle), 0.0, sin(angle)) * 12.0
		run.horde.spawn(0, at, (around - at).normalized())


func _place_parts() -> void:
	var forward := -global_basis.z
	for n in parts.size():
		var along := lerpf(0.35, -0.35, float(n) / maxf(parts.size() - 1, 1)) * _length
		run.horde.place(parts[n], global_position + forward * along, forward)
