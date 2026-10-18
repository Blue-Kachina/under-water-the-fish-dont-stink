class_name BloodLeviathan
extends Boss
## The boss (planning_unnatural.md §3, D5): a giant serpent of
## leviathan_segments segments trailing its head, each a proxy. Beating it
## completes the stage. Its phases, by the hp it has left:
## 1. CIRCLE: it coils round the players at a distance, cutting in through them
##    now and then;
## 2. SPIT (from two thirds): as well, every leviathan_bolt_every s it spits a
##    fan of leviathan_bolts blood bolts at its target (they hurt players);
## 3. FURY (under a third): faster, it charges the target again and again.
## Not beaten leviathan_enrage s after it came, it enrages (enrage_scale on
## speed and contact damage; UnnaturalRun has the director escalate too).

signal enraged_now
signal phase_changed(phase: int)
## It spat bolts from `from`, along `directions` (online: the guests' puppets spit them too).
signal spat(from: Vector3, directions: PackedVector3Array)

enum Phase { CIRCLE, SPIT, FURY }

const BLOOD := Color(0.5, 0.03, 0.05)
const BOLT_SPEED := 18.0
const BOLT_LIFE := 3.5
## How far apart the segments trail (times their girth).
const SPACING := 1.3

var phase := Phase.CIRCLE
var bolts_fired := 0
var dives := 0

var _segments: Array[MeshInstance3D] = []
var _trail := PackedVector3Array()
var _bolt_left := 0.0
var _dive_left := 4.0
var _diving := 0.0
var _orbit := 1.0
var _material := StandardMaterial3D.new()
var _bolts: Array[Dictionary] = []
var _bolt_mesh := MultiMeshInstance3D.new()


func _ready() -> void:
	super()
	title = "THE BLOOD LEVIATHAN"
	name = "BloodLeviathan"
	_material.albedo_color = BLOOD
	_material.roughness = 0.4
	_material.metallic = 0.3
	_material.emission_enabled = true
	_material.emission = Color(0.6, 0.02, 0.02)
	_material.emission_energy_multiplier = 0.4
	var girth := settings.leviathan_girth
	for n in settings.leviathan_segments:
		var t := float(n) / maxf(settings.leviathan_segments - 1, 1)
		var radius := girth * lerpf(1.0, 0.35, t * t)
		var segment := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		sphere.material = _material
		segment.mesh = sphere
		segment.top_level = true
		segment.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(segment)
		_segments.append(segment)
		add_part(global_position, minf(radius, 2.5))
		if n == 0:
			# The head: longer, with jaws and red eyes.
			segment.scale = Vector3(0.9, 0.75, 1.5)
			for side: float in [-1.0, 1.0]:
				var e := Boss.eye(radius * 0.18)
				e.position = Vector3(side * radius * 0.55, radius * 0.4, -radius * 0.7)
				segment.add_child(e)
			var jaw := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(radius * 1.4, radius * 0.5, radius * 1.2)
			prism.material = _material
			jaw.mesh = prism
			jaw.position = Vector3(0.0, -radius * 0.55, -radius * 0.5)
			segment.add_child(jaw)
	# The bolts: glowing blobs, one MultiMesh.
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var blob := SphereMesh.new()
	blob.radius = 0.45
	blob.height = 0.9
	blob.radial_segments = 8
	blob.rings = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.15, 0.1)
	blob.material = glow
	multimesh.mesh = blob
	_bolt_mesh.multimesh = multimesh
	_bolt_mesh.top_level = true
	_bolt_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_bolt_mesh)
	_bolt_left = settings.leviathan_bolt_every
	velocity = Vector3.FORWARD * settings.leviathan_speed
	_trail.append(global_position)


func contact() -> float:
	return settings.leviathan_contact * (settings.enrage_scale if enraged else 1.0) * settings.enemy_damage_scale


func speed() -> float:
	var s := settings.leviathan_speed * settings.enemy_speed_scale
	if phase == Phase.FURY:
		s *= 1.35
	if enraged:
		s *= settings.enrage_scale
	return s


func take(amount: float, by: FishController, source: String) -> void:
	super(amount, by, source)
	var now := Phase.CIRCLE
	if share() <= 1.0 / 3.0:
		now = Phase.FURY
	elif share() <= 2.0 / 3.0:
		now = Phase.SPIT
	if now != phase and not dying:
		phase = now
		phase_changed.emit(phase)


func _move(delta: float) -> void:
	if not enraged and settings.leviathan_enrage > 0.0 and age >= settings.leviathan_enrage:
		_enrage_now()
	var prey := target()
	var middle := run.centre
	if prey:
		middle = prey.global_position
	var wanted: Vector3
	var to_prey := middle - global_position
	_dive_left -= delta
	if phase == Phase.FURY or _diving > 0.0:
		# Straight through the target.
		wanted = to_prey.normalized() * speed() * 1.4
		_diving -= delta
		if _diving <= 0.0 and phase != Phase.FURY:
			_dive_left = 5.0
	else:
		# Coil round it at about 22 m, a little up and down.
		var flat := Vector3(to_prey.x, 0.0, to_prey.z)
		var gap := flat.length()
		var round_dir := Vector3.UP.cross(flat.normalized()) * _orbit if gap > 0.01 else Vector3.FORWARD
		var inward := flat.normalized() * clampf((gap - 22.0) / 10.0, -1.0, 1.0) if gap > 0.01 else Vector3.ZERO
		wanted = (round_dir + inward + Vector3.UP * sin(age * 0.7) * 0.3).normalized() * speed()
		if _dive_left <= 0.0 and prey:
			_diving = 2.2
			dives += 1
			_orbit = -_orbit
	steer(wanted, 1.4 if phase != Phase.FURY else 2.2, 10.0, delta)
	global_position += velocity * delta
	face(velocity)
	if phase != Phase.CIRCLE and prey and settings.leviathan_bolts > 0 and settings.leviathan_bolt_every > 0.0:
		_bolt_left -= delta
		if _bolt_left <= 0.0:
			_bolt_left = settings.leviathan_bolt_every / (settings.enrage_scale if enraged else 1.0)
			_spit(prey.global_position)
	_update_bolts(delta)
	_trail_body()
	_material.emission_energy_multiplier = (1.5 if enraged else 0.4) + flash * 2.0


func _enrage_now() -> void:
	enraged = true
	_material.emission_energy_multiplier = 1.5
	enraged_now.emit()


func _net_mode() -> int:
	return phase


func _set_net_mode(net_mode: int) -> void:
	if net_mode != phase:
		phase = net_mode as Phase
		phase_changed.emit(phase)


func _place_body() -> void:
	_trail_body()


func _puppet_update(delta: float) -> void:
	_update_bolts(delta)
	_material.emission_energy_multiplier = (1.5 if enraged else 0.4) + flash * 2.0


## A fan of blood bolts at `at`.
func _spit(at: Vector3) -> void:
	var from := global_position
	var aim := (at - from).normalized()
	var count := settings.leviathan_bolts
	var side := aim.cross(Vector3.UP).normalized()
	var directions := PackedVector3Array()
	for n in count:
		var offset := (n - (count - 1) * 0.5) * 0.14
		directions.append((aim + side * offset).normalized())
	add_bolts(from, directions)
	spat.emit(from, directions)


## Bolts from `from` along each of `directions`.
func add_bolts(from: Vector3, directions: PackedVector3Array) -> void:
	for direction in directions:
		_bolts.append({"at": from + direction * settings.leviathan_girth, "velocity": direction * BOLT_SPEED, "life": BOLT_LIFE})
		bolts_fired += 1


func _update_bolts(delta: float) -> void:
	var i := 0
	while i < _bolts.size():
		var bolt: Dictionary = _bolts[i]
		bolt.life -= delta
		bolt.at += bolt.velocity * delta
		var spent: bool = bolt.life <= 0.0
		if not spent:
			for fish in run.players:
				if not fish.puppet and run.is_up(fish) and fish.global_position.distance_to(bolt.at) <= UnnaturalRun.PLAYER_RADIUS + 0.45:
					run.hurt(fish, settings.leviathan_bolt_damage * settings.enemy_damage_scale, -1, "the Leviathan's bolt")
					spent = true
					break
		if spent:
			_bolts.remove_at(i)
		else:
			i += 1
	var multimesh := _bolt_mesh.multimesh
	if multimesh.instance_count < _bolts.size():
		multimesh.instance_count = maxi(_bolts.size(), 16)
	multimesh.visible_instance_count = _bolts.size()
	for b in _bolts.size():
		multimesh.set_instance_transform(b, Transform3D(Basis.IDENTITY, _bolts[b].at))


## The segments follow the head's path, SPACING girths apart.
func _trail_body() -> void:
	var head := global_position
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(head) > 0.25:
		_trail.append(head)
	var spacing := settings.leviathan_girth * SPACING
	var needed := spacing * _segments.size() + 2.0
	# Trim the trail to what the body needs.
	var length := 0.0
	var keep := _trail.size() - 1
	while keep > 0 and length < needed:
		length += _trail[keep].distance_to(_trail[keep - 1])
		keep -= 1
	if keep > 0:
		_trail = _trail.slice(keep)
	var walked := 0.0
	var index := _trail.size() - 1
	var point := head
	var previous := head + velocity.normalized() * 0.1
	for s in _segments.size():
		var want := s * spacing
		while walked < want and index > 0:
			var step := _trail[index].distance_to(_trail[index - 1])
			if walked + step >= want:
				point = _trail[index].lerp(_trail[index - 1], (want - walked) / maxf(step, 0.0001))
				walked = want
				break
			walked += step
			index -= 1
			point = _trail[index]
		var forward := (previous - point)
		if forward.length_squared() < 0.0001:
			forward = -global_basis.z
		var up := Vector3.UP if absf(forward.normalized().y) < 0.98 else Vector3.BACK
		var segment := _segments[s]
		segment.global_transform = Transform3D(Basis.looking_at(forward, up) * Basis.from_scale(segment.scale), point)
		if s < parts.size():
			run.horde.place(parts[s], point, forward)
		previous = point


## Beaten: the body sinks and shrinks with the head; the bolts go.
func _process(delta: float) -> void:
	if not dying:
		return
	_bolts.clear()
	_bolt_mesh.multimesh.visible_instance_count = 0
	var shrink := exp(-1.5 * delta)
	for segment in _segments:
		segment.global_transform = Transform3D(segment.global_basis.scaled(Vector3.ONE * shrink), segment.global_position + Vector3.DOWN * 3.0 * delta)
