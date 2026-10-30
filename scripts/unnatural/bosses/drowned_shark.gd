class_name DrownedShark
extends Boss
## The mini-boss (planning_unnatural.md §3): a huge zombie shark, the Shark's
## model shark_size times over, rotten and red-eyed. It hunts the nearest
## player; every shark_charge_every seconds it glows red for shark_telegraph
## (time to get out of the way), then charges in a straight line; every
## shark_call_every seconds it calls a ring of sardines round its target.
## It chomps: a player within shark_chomp_range ahead of its mouth makes its
## jaw drop open on its hinge (over shark_chomp_wind s, its upper jaw pushing
## forward, teeth bared) and snap shut, biting everyone at its mouth for
## shark_chomp_damage. Charging, its jaws hang wide and snap on the first
## player they reach (or at the charge's end, a clack on nothing).
## Killing it drops a chest and a big XP pearl (UnnaturalRun).

## Its jaws snapped shut at `at`, biting `bit` players.
signal chomped(at: Vector3, bit: int)

enum Mode { HUNT, TELEGRAPH, CHARGE }

## Its body as proxies: at least this many, spread along it (more as it grows).
const MIN_PARTS := 3
const ROT := Color(0.36, 0.42, 0.34)
## How far its jaw drops open (rad), and how far its upper jaw pushes forward
## then (of the mouth's length).
const GAPE := 0.95
const PROTRUDE := 0.25
const FLESH := Color(0.42, 0.07, 0.08)
const TOOTH := Color(0.86, 0.83, 0.72)

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
var _length := 1.0
var _chomp_wind := 0.0
var _snap_left := 0.0
var _chomp_cool := 1.0
var _bit_this_charge := false
var _puppet_jaw := 0
## The jaw rig (in the model's space): the hinge, the lower jaw on it, the
## upper teeth and palate, the cheeks between them, and the mouth's shape.
var _hinge: Node3D
var _upper: Node3D
var _palate: MeshInstance3D
var _cheeks: MeshInstance3D
var _cheek_mesh := ImmediateMesh.new()
var _flesh := StandardMaterial3D.new()
var _mouth := {}
var _shown_jaw := -1.0


func _ready() -> void:
	super()
	title = "THE DROWNED SHARK"
	name = "DrownedShark"
	_charge_left = settings.shark_charge_every
	_call_left = settings.shark_call_every * 0.5
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
	if _model is FishModel:
		_build_jaw(_model as FishModel)
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
				_chomp_wind = 0.0
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
					_snap()  # a clack on nothing
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
	_glow.light_energy = (6.0 * pulse * settings.telegraph_glow if mode == Mode.TELEGRAPH else 0.0) + flash * 4.0
	if puppet:
		var goal := 1.0 if _puppet_jaw > 0 or mode == Mode.CHARGE else 0.0
		jaw = move_toward(jaw, goal, delta * (12.0 if goal < jaw else 3.0))
	_pose_jaw()


func _place_body() -> void:
	_place_parts()


## Its mode, plus 4 while its jaw is open for a chomp and 8 as it snaps.
func _net_mode() -> int:
	return mode + (4 if _chomp_wind > 0.0 else 0) + (8 if _snap_left > 0.0 else 0)


func _set_net_mode(net_mode: int) -> void:
	mode = (net_mode & 3) as Mode
	_puppet_jaw = 1 if (net_mode & 4) != 0 else (-1 if (net_mode & 8) != 0 else 0)


# --- The chomp ----------------------------------------------------------------

## Where its mouth is now (the world), a little in front of its jaws.
func mouth_point() -> Vector3:
	if _mouth.is_empty():
		return global_position - global_basis.z * _length * 0.45
	var front: Vector3 = _mouth.front
	return _model.to_global(front + Vector3(0.0, -0.03, -0.05) * float(_mouth.length))


## Its chomp each tick: winding up (jaw dropping open), snapping shut, or,
## charging, jaws wide for whoever it reaches.
func _update_chomp(delta: float, prey: FishController) -> void:
	_chomp_cool -= delta
	if _snap_left > 0.0:
		_snap_left -= delta
		jaw = move_toward(jaw, 0.0, delta * 12.0)
		return
	if mode == Mode.CHARGE:
		jaw = move_toward(jaw, 1.0, delta * 5.0)
		if not _bit_this_charge and _reaching() > 0:
			_snap()
		return
	if _chomp_wind > 0.0:
		_chomp_wind -= delta
		jaw = move_toward(jaw, 1.0, delta * 1.25 / maxf(settings.shark_chomp_wind, 0.05))
		if _chomp_wind <= 0.0:
			_snap()
		return
	jaw = move_toward(jaw, 0.0, delta * 2.0)
	if prey and mode == Mode.HUNT and _chomp_cool <= 0.0 and settings.shark_chomp_range > 0.0:
		var off := prey.global_position - mouth_point()
		if off.length() <= settings.shark_chomp_range and off.dot(-global_basis.z) > off.length() * 0.3:
			_chomp_wind = settings.shark_chomp_wind
			velocity += -global_basis.z * settings.shark_speed * 0.5  # a surge in at them


## How many players are at its mouth, in its bite.
func _reaching() -> int:
	var mouth := mouth_point()
	var count := 0
	for fish in run.players:
		if not fish.puppet and run.is_up(fish) and fish.global_position.distance_to(mouth) <= settings.shark_chomp_reach + UnnaturalRun.PLAYER_RADIUS:
			count += 1
	return count


## Snap: its jaws shut, biting everyone at its mouth.
func _snap() -> void:
	_snap_left = 0.25
	_chomp_wind = 0.0
	_chomp_cool = settings.shark_chomp_every
	_bit_this_charge = true
	chomps += 1
	var mouth := mouth_point()
	var bit := 0
	for fish in run.players:
		if fish.puppet or not run.is_up(fish):
			continue
		if fish.global_position.distance_to(mouth) <= settings.shark_chomp_reach + UnnaturalRun.PLAYER_RADIUS:
			run.hurt(fish, settings.shark_chomp_damage * settings.enemy_damage_scale * run.stage_damage(), -1, title.capitalize())
			bit += 1
	chomp_hits += bit
	chomped.emit(mouth, bit)


# --- The jaw ------------------------------------------------------------------

## Its jaw, hinged at the mouth's corners under its head (the model's space, so
## it grows and moves with it): the lower jaw (skin under, raw flesh over, a
## row of teeth), the upper teeth and palate it bares, and cheeks of flesh
## stretched between as it opens.
func _build_jaw(model: FishModel) -> void:
	_mouth = SharkModel.mouth_geometry(model)
	var front: Vector3 = _mouth.front
	var back: Vector3 = _mouth.back
	var width: float = _mouth.width
	var length: float = _mouth.length
	_flesh.albedo_color = FLESH
	_flesh.roughness = 0.35
	_flesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	var skin := StandardMaterial3D.new()
	skin.albedo_color = ROT.darkened(0.15)
	skin.roughness = 0.6
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tooth := StandardMaterial3D.new()
	tooth.albedo_color = TOOTH
	tooth.roughness = 0.25
	_hinge = Node3D.new()
	_hinge.name = "Jaw"
	_hinge.position = Vector3(0.0, back.y, back.z)
	model.add_child(_hinge)
	var thick := length * 0.012
	# The lower jaw: a U-shaped plate under the head, raw flesh on top.
	var floor_top := _plate(front - back, width, 0.0, true)
	var under := _plate(front - back, width, -thick, false)
	for pair: Array in [[floor_top, _flesh], [under, skin]]:
		var node := MeshInstance3D.new()
		node.mesh = pair[0]
		node.material_override = pair[1]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hinge.add_child(node)
	# Its teeth: triangles along the rim, pointing up (lower) and down (upper).
	_upper = Node3D.new()
	_upper.name = "UpperTeeth"
	_upper.position = _hinge.position
	model.add_child(_upper)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = length * 0.006
	spike.height = length * 0.022
	spike.radial_segments = 4
	spike.rings = 1
	spike.material = tooth
	var count := 15
	for n in count:
		var u := lerpf(-0.88, 0.88, n / float(count - 1))
		var at := _rim(front - back, width, u)
		var low := MeshInstance3D.new()
		low.mesh = spike
		low.position = at * Vector3(0.94, 1.0, 0.94) + Vector3(0.0, spike.height * 0.45, 0.0)
		low.rotation.z = -u * 0.25
		_hinge.add_child(low)
		var high := MeshInstance3D.new()
		high.mesh = spike
		high.position = at * Vector3(0.96, 1.0, 0.96) + Vector3(0.0, -spike.height * 0.4, 0.0)
		high.rotation = Vector3(PI, 0.0, u * 0.25)
		high.scale = Vector3.ONE * lerpf(1.15, 0.8, absf(u))
		_upper.add_child(high)
	# The roof of its mouth, bared when it opens.
	_palate = MeshInstance3D.new()
	_palate.mesh = _plate(front - back, width * 0.97, -length * 0.002, false)
	_palate.material_override = _flesh
	_palate.position = _hinge.position
	_palate.visible = false
	model.add_child(_palate)
	_cheeks = MeshInstance3D.new()
	_cheeks.mesh = _cheek_mesh
	var cheek := StandardMaterial3D.new()  # rebuilt each opening without normals: unshaded, darker
	cheek.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cheek.albedo_color = FLESH.darkened(0.45)
	cheek.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cheeks.material_override = cheek
	_cheeks.position = _hinge.position
	_cheeks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_cheeks)
	_pose_jaw()


## A point on the mouth's rim `u` round it (-1 one corner, 0 the front, 1 the
## other), from the hinge: `reach` from the hinge to the front (model space).
static func _rim(reach: Vector3, width: float, u: float) -> Vector3:
	var a := u * PI * 0.5
	return Vector3(width * sin(a), reach.y * cos(a), reach.z * cos(a))


## The mouth's floor (or roof): a fan from the hinge's middle out to the rim,
## `drop` m below it, facing up (`up`) or down.
static func _plate(reach: Vector3, width: float, drop: float, up: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 20
	var middle := Vector3(0.0, drop, 0.0)
	for n in steps:
		var a := _rim(reach, width, lerpf(-1.0, 1.0, n / float(steps))) + Vector3(0.0, drop, 0.0)
		var b := _rim(reach, width, lerpf(-1.0, 1.0, (n + 1) / float(steps))) + Vector3(0.0, drop, 0.0)
		for corner: Vector3 in ([middle, b, a] if up else [middle, a, b]):
			tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()


## The jaw as open as `jaw` says: the lower jaw dropped on its hinge, the upper
## teeth pushed forward and bared, the cheeks stretched between.
func _pose_jaw() -> void:
	if _hinge == null or is_equal_approx(jaw, _shown_jaw):
		return
	_shown_jaw = jaw
	var open := smoothstep(0.0, 1.0, jaw)
	var angle := -GAPE * open
	_hinge.rotation.x = angle
	var front: Vector3 = _mouth.front
	var back: Vector3 = _mouth.back
	var reach := front - back
	_upper.position = Vector3(0.0, back.y, back.z) + Vector3(0.0, reach.z * 0.1, reach.z * PROTRUDE) * open
	_upper.scale = Vector3(1.0, maxf(open, 0.02), 1.0)
	_upper.visible = open > 0.03
	for node in _hinge.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is CylinderMesh:
			(node as Node3D).scale = Vector3(1.0, maxf(open, 0.02), 1.0)
	_palate.visible = open > 0.03
	# The cheeks: flesh fanned from the upper rim down to the dropped jaw, along
	# the back of each side.
	_cheek_mesh.clear_surfaces()
	if open <= 0.03:
		return
	var width: float = _mouth.width
	_cheek_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	for side: float in [-1.0, 1.0]:
		var cols := 6
		for c in cols:
			var u0 := side * lerpf(1.0, 0.45, c / float(cols))
			var u1 := side * lerpf(1.0, 0.45, (c + 1) / float(cols))
			for r in rows:
				var a0 := angle * r / float(rows)
				var a1 := angle * (r + 1) / float(rows)
				var p00 := _rim(reach, width, u0).rotated(Vector3.RIGHT, a0)
				var p01 := _rim(reach, width, u0).rotated(Vector3.RIGHT, a1)
				var p10 := _rim(reach, width, u1).rotated(Vector3.RIGHT, a0)
				var p11 := _rim(reach, width, u1).rotated(Vector3.RIGHT, a1)
				for corner: Vector3 in [p00, p10, p01, p10, p11, p01]:
					_cheek_mesh.surface_add_vertex(corner)
	_cheek_mesh.surface_end()


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
