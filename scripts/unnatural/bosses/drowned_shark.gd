class_name DrownedShark
extends Boss
## The mini-boss (planning_unnatural.md §3): a huge zombie shark, the Shark's
## model shark_size times over, rotten and red-eyed. It hunts the nearest
## player; every shark_charge_every seconds it glows red for shark_telegraph
## (time to get out of the way), then charges in a straight line; every
## shark_call_every seconds it calls a ring of sardines round its target.
## Killing it drops a chest and a big XP pearl (UnnaturalRun).

enum Mode { HUNT, TELEGRAPH, CHARGE }

## Its body as proxies: at least this many, spread along it (more as it grows).
const MIN_PARTS := 3
const ROT := Color(0.36, 0.42, 0.34)

var mode := Mode.HUNT
var charges := 0
var calls := 0

var _mode_left := 0.0
var _charge_left := 0.0
var _call_left := 0.0
var _charge_dir := Vector3.FORWARD
var _model: Node3D
var _glow := OmniLight3D.new()
var _length := 1.0


func _ready() -> void:
	super()
	title = "THE DROWNED SHARK"
	name = "DrownedShark"
	_charge_left = settings.shark_charge_every
	_call_left = settings.shark_call_every * 0.5
	_model = FishModel.build(FishCharacter.Family.DOMINUS)
	_model.scale = Vector3.ONE * settings.shark_size
	add_child(_model)
	if _model.has_method("set_body_color"):
		_model.call("set_body_color", ROT)
	# Already in metres: x across, y up, z nose to tail.
	var hitbox := FishCharacter.hitbox_size(FishCharacter.Family.DOMINUS)
	_length = hitbox.z * settings.shark_size
	var half_width := hitbox.x * 0.5 * settings.shark_size
	var half_height := hitbox.y * 0.5 * settings.shark_size
	# Red eyes over the model's own, wherever its head puts them.
	var model_eyes := _model.find_children("Eye", "Node3D", true, false)
	for side: float in [-1.0, 1.0]:
		var e := Boss.eye(0.09 * settings.shark_size)
		e.position = Vector3(side * half_width * 0.55, half_height * 0.3, -_length * 0.38)
		for node in model_eyes:
			var at := _model.transform * (node as Node3D).position
			if signf(at.x) == side:
				e.position = at
		add_child(e)
	_glow.light_color = Color(1.0, 0.1, 0.05)
	_glow.omni_range = _length * 1.5
	_glow.light_energy = 0.0
	add_child(_glow)
	# Enough proxies, each as thick as the body, to cover it nose to tail.
	var radius := (half_width + half_height) * 0.5
	var count := maxi(MIN_PARTS, ceili(_length * 0.7 / radius) + 1)
	for n in count:
		add_part(global_position, radius)
	_place_parts()


func contact() -> float:
	return settings.shark_contact * (1.6 if mode == Mode.CHARGE else 1.0) * settings.enemy_damage_scale


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
		Mode.TELEGRAPH:
			steer(toward.normalized() * speed * 0.25 if toward != Vector3.ZERO else Vector3.ZERO, 3.0, 20.0, delta)
			_charge_dir = toward.normalized() if toward != Vector3.ZERO else -global_basis.z
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.CHARGE
				charges += 1
				_mode_left = settings.shark_charge_time
				velocity = _charge_dir * settings.shark_charge_speed * maxf(settings.enemy_speed_scale, 0.0)
		Mode.CHARGE:
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.HUNT
				_charge_left = settings.shark_charge_every
	_call_left -= delta
	if _call_left <= 0.0 and prey and settings.shark_call_every > 0.0:
		_call_left = settings.shark_call_every
		_call(prey.global_position)
	global_position += velocity * delta
	if velocity.length_squared() > 0.25:
		face(velocity)
	_puppet_update(delta)
	_place_parts()


func _puppet_update(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(age * 30.0)
	_glow.light_energy = (6.0 * pulse if mode == Mode.TELEGRAPH else 0.0) + flash * 4.0


func _place_body() -> void:
	_place_parts()


func _net_mode() -> int:
	return mode


func _set_net_mode(net_mode: int) -> void:
	mode = net_mode as Mode


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
