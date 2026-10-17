class_name Boss
extends Node3D
## A boss in Unnatural (planning_unnatural.md §3): a real node with its own
## model and moves, not a Horde zombie. Its body is a few Horde proxies
## (Horde.spawn_proxy) it moves along with itself every tick, so attacks,
## batteries and powerups find it through the grid like any zombie;
## UnnaturalRun.hit() hands their damage to take(). Touching a proxy hurts a
## player by contact() (UnnaturalRun._touch_zombies).
##
## A subclass builds its look in _ready() (after calling super), adds its
## proxies with add_part() and moves them in _move() (and _place_body()). At 0
## hp it's defeated: its proxies go, it sinks and fades, then frees itself.
##
## Online, the host's boss is the real one; a guest's is a `puppet` that
## follows its net state (net_state() / set_net_state()), its proxies with the
## host's net ids (part_ids, set before adding it), and hurts nobody's hp but
## shows the hits; UnnaturalNet tells it when it's beaten.

signal defeated(boss: Boss, by: FishController)

## Time to sink away once beaten (s).
const DEATH_TIME := 2.5

var run: UnnaturalRun
var settings: UnnaturalSettings
var title := "BOSS"
var hp := 1.0
var max_hp := 1.0
## Enraged (the Leviathan, when it's out too long).
var enraged := false
## Seconds since it came.
var age := 0.0
## Its velocity (m/s).
var velocity := Vector3.ZERO
## Its proxies, with each one's radius.
var parts := PackedInt32Array()
var part_radius := PackedFloat32Array()
var dying := false
## The red flash when hit (1 fades to 0).
var flash := 0.0

## Online: the host's id for it, and whether it's a guest's puppet.
var boss_id := 0
var puppet := false
## A puppet's proxies' net ids (the host's), in add_part() order.
var part_ids := PackedInt32Array()

var _death_left := 0.0
var _net_at := Vector3.ZERO
var _net_velocity := Vector3.ZERO
var _net_age := -1.0


func _ready() -> void:
	settings = run.settings
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


## A proxy `radius` m round at `at`.
func add_part(at: Vector3, radius: float) -> int:
	var given := part_ids[parts.size()] if parts.size() < part_ids.size() else 0
	var index := run.horde.spawn_proxy(at, radius, given)
	if index >= 0:
		parts.append(index)
		part_radius.append(radius)
	return index


func owns(index: int) -> bool:
	return parts.has(index)


## Contact damage on a player now.
func contact() -> float:
	return 0.0


func share() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


## Hurt by `amount` (after the player's stats) from `by`.
func take(amount: float, by: FishController, _source: String) -> void:
	if dying or amount <= 0.0:
		return
	flash = 1.0
	if puppet:
		return  # the host's hp counts; ours follows it
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_die(by)


## The player it goes after: the nearest one who's up (null: none).
func target() -> FishController:
	var best: FishController = null
	var best_gap := INF
	for fish in run.players:
		if not run.is_up(fish) or run.is_picking(fish):
			continue
		var gap := fish.global_position.distance_squared_to(global_position)
		if gap < best_gap:
			best_gap = gap
			best = fish
	return best


func _physics_process(delta: float) -> void:
	if dying:
		_death_left -= delta
		global_position += Vector3.DOWN * 3.0 * delta
		scale = Vector3.ONE * maxf(_death_left / DEATH_TIME, 0.01)
		if _death_left <= 0.0:
			queue_free()
		return
	if run.is_over:
		return
	age += delta
	flash = maxf(flash - delta * 4.0, 0.0)
	if puppet:
		_follow_net(delta)
		return
	_move(delta)
	_keep_in_arena()


## Its proxies (and any trailing body) where it is now.
func _place_body() -> void:
	pass


## The parts of its look a puppet keeps up itself (glows, bolts).
func _puppet_update(_delta: float) -> void:
	pass


## The host's state for it: [position, velocity, hp, mode, enraged].
func net_state() -> Array:
	return [global_position, velocity, hp, _net_mode(), enraged]


## A puppet's state from the host's (`age` s old).
func set_net_state(state: Array, age_s: float) -> void:
	_net_at = state[0]
	_net_velocity = state[1]
	hp = state[2]
	_set_net_mode(state[3])
	if state[4] and not enraged:
		_enrage_now()
	_net_age = age_s
	if not is_inside_tree():
		position = _net_at


func _net_mode() -> int:
	return 0


func _set_net_mode(_mode: int) -> void:
	pass


func _enrage_now() -> void:
	enraged = true


func _follow_net(delta: float) -> void:
	if _net_age < 0.0:
		_place_body()
		return
	_net_age += delta
	var goal := _net_at + _net_velocity * minf(_net_age, 0.5)
	var off := goal - global_position
	global_position = goal if off.length() > 8.0 else global_position + off * minf(10.0 * delta, 1.0)
	velocity = _net_velocity
	if velocity.length_squared() > 0.25:
		face(velocity)
	_puppet_update(delta)
	_place_body()


func _move(_delta: float) -> void:
	pass


## Turns `velocity` toward `wanted` at `turn` (1/s), keeping speed changes to `accel` (m/s²).
func steer(wanted: Vector3, turn: float, accel: float, delta: float) -> void:
	var speed := move_toward(velocity.length(), wanted.length(), accel * delta)
	var heading := velocity.normalized() if velocity.length_squared() > 0.01 else wanted.normalized()
	if wanted.length_squared() > 0.0001:
		heading = heading.slerp(wanted.normalized(), 1.0 - exp(-turn * delta)).normalized()
	velocity = heading * speed


## Faces the way it swims.
func face(forward: Vector3) -> void:
	if forward.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(forward.normalized().y) < 0.98 else Vector3.BACK
	global_basis = Basis.looking_at(forward, up).scaled(scale)


func _keep_in_arena() -> void:
	var centre := run.centre
	var offset := global_position - centre
	var flat := Vector2(offset.x, offset.z)
	var reach := settings.arena_radius - 5.0
	if flat.length() > reach:
		flat = flat.normalized() * reach
	var y := clampf(offset.y, settings.arena_floor + 3.0, settings.arena_ceiling)
	global_position = centre + Vector3(flat.x, y, flat.y)


## Beaten (a puppet: the host says so).
func defeat(by: FishController) -> void:
	if not dying:
		_die(by)


func _die(by: FishController) -> void:
	dying = true
	_death_left = DEATH_TIME
	for index in parts:
		run.horde.remove(index)
	parts.clear()
	defeated.emit(self, by)


## Its proxies gone (the run's start clears the horde too).
func _exit_tree() -> void:
	if is_instance_valid(run) and is_instance_valid(run.horde):
		for index in parts:
			if run.horde.is_proxy(index):
				run.horde.remove(index)
	parts.clear()


## A glowing red eye.
static func eye(radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.1, 0.05)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.1, 0.05)
	glow.emission_energy_multiplier = 4.0
	mesh.material = glow
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
