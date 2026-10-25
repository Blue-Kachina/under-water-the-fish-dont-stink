class_name LampreyBoss
extends BloodLeviathan
## The Lamprey Queen, an alternate final boss: a giant sea lamprey, its mouth a
## sucking disc of hooked teeth round a rasping tongue, seven gill holes either
## side, its brood clamped to its flanks. It fights as the King does (circle,
## spit, fury), and:
## - every brood_every s one of its brood drops off as brood_count zombies;
## - spitting, its gills flare and pulse out clouds of blood (blood_cloud_damage);
## - in fury, a player its disc touches is latched onto and drained (hold());
## - its gill holes are weak points: hits on them do gill_bonus times the damage.

const LAMPREY_SKIN := preload("res://shaders/boss_lamprey.gdshader")
## Seconds between blood pulses while it spits, and how long a fallen brood takes to regrow.
const CLOUD_EVERY := 5.0
const BROOD_REGROW := 25.0

var _brood: Array = []  # [rider node, regrow s left]
var _brood_left := 0.0
var _cloud_left := 2.0
var _breath := 0.0
var _flare := 0.0
## The two gill proxies (weak points), after the body's.
var _gill_parts := PackedInt32Array()


func boss_title() -> String:
	return "THE LAMPREY QUEEN"


func boss_line() -> String:
	return "ALL TEETH, NO JAW"


func net_kind() -> String:
	return "lamprey"


func body_length() -> float:
	return settings.leviathan_segments * settings.leviathan_girth * 1.05


func radius() -> float:
	return settings.leviathan_girth * 0.62


func proxy_count() -> int:
	return settings.leviathan_segments + 2


func proxy_distance(n: int) -> float:
	if n >= settings.leviathan_segments:
		return gill_middle()
	return n * body_length() / float(settings.leviathan_segments)


func proxy_radius(n: int) -> float:
	if n >= settings.leviathan_segments:
		return radius() * 0.45
	var along := proxy_distance(n) / body_length()
	return radius() * lerpf(1.0, 0.3, clampf((along - 0.5) / 0.5, 0.0, 1.0)) * 1.1


## Where its gill rows' middles are (m back from the disc).
func gill_middle() -> float:
	return _gill_z() + 3.0 * radius() * 0.55


func _gill_z() -> float:
	return radius() * 1.35 * 2.4


func grabs() -> bool:
	return true


func mouth_point() -> Vector3:
	return rig.place(Vector3(0.0, 0.0, radius() * 0.3))


func hold_reach() -> float:
	return radius() * 1.5


func circle_radius() -> float:
	return 26.0 + body_length() * 0.06


func _ready() -> void:
	super()
	name = "LampreyQueen"
	for n in range(settings.leviathan_segments, parts.size()):
		_gill_parts.append(parts[n])
	_brood_left = settings.brood_every


## Hits on its gill holes do gill_bonus times the damage.
func take_part(index: int, amount: float, by: FishController, source: String) -> void:
	take(amount * (settings.gill_bonus if _gill_parts.has(index) else 1.0), by, source)


func _pose_parts() -> void:
	for n in parts.size():
		if n >= settings.leviathan_segments:
			var side := -1.0 if n == settings.leviathan_segments else 1.0
			var at := rig.place(Vector3(side * radius() * 0.95, radius() * 0.15, gill_middle()))
			run.horde.place(parts[n], at, -rig.frame_at(gill_middle()).basis.z)
		else:
			var frame := rig.frame_at(proxy_distance(n))
			run.horde.place(parts[n], frame.origin, -frame.basis.z)


func _special(delta: float, _prey: FishController) -> void:
	# The brood: one drops off now and then as a pack of zombies, and regrows.
	for entry: Array in _brood:
		if entry[1] > 0.0:
			entry[1] -= delta
			if entry[1] <= 0.0:
				(entry[0] as Node3D).visible = true
	_brood_left -= delta
	if _brood_left <= 0.0 and settings.brood_count > 0:
		_brood_left = settings.brood_every / (settings.enrage_scale if enraged else 1.0)
		var ready := _brood.filter(func(entry: Array) -> bool: return entry[1] <= 0.0)
		if not ready.is_empty():
			var entry: Array = ready[run.rng.randi_range(0, ready.size() - 1)]
			var node: Node3D = entry[0]
			node.visible = false
			entry[1] = BROOD_REGROW
			run.horde.spawn_pack(0, settings.brood_count, node.global_position, 2.0, velocity.normalized(), 0.0)
	# Spitting: the gills flare and pulse out blood.
	if phase != Phase.CIRCLE:
		_cloud_left -= delta
		if _cloud_left <= 0.0:
			_cloud_left = CLOUD_EVERY
			_flare = 1.0
			for side: float in [-1.0, 1.0]:
				for n in 3:
					var at := rig.place(Vector3(side * radius() * 1.3, radius() * 0.15, _gill_z() + n * radius() * 1.1))
					run._hazard(at, radius() * 0.9, 2.5, settings.blood_cloud_damage, Color(0.6, 0.02, 0.03, 0.4), "the Lamprey Queen's blood")


func _glow_now() -> void:
	super()
	_flare = maxf(_flare - get_physics_process_delta_time() * 0.8, 0.0)
	_breath = 0.12 + 0.1 * sin(age * 1.3) + _flare
	for material in skins:
		material.set_shader_parameter("breath", _breath)


func _build_look() -> void:
	var length := body_length()
	var k := settings.leviathan_girth / 6.0
	var r := radius()
	var rd := r * 1.35
	var mesh := BossMesh.new(length)
	var profile := func(along: float) -> Vector4:
		var z := along * length
		var flare := 1.0 - smoothstep(0.0, 1.6 * rd, z)
		var rad := lerpf(r, rd * 1.02, pow(flare, 1.5))
		var t := clampf((along - 0.55) / 0.45, 0.0, 1.0)
		rad *= lerpf(1.0, 0.12, pow(t, 1.4))
		rad *= sqrt(maxf(1.0 - pow(maxf(along - 0.985, 0.0) / 0.015, 2.0), 0.0))
		return Vector4(rad, rad * 0.96, 0.0, 2.0)
	mesh.loft(0.0, length, profile, 260, 32, BossMesh.BODY)
	# The oral disc: a concave cup of rasping flesh behind a fleshy lip.
	var depth := rd * 0.55
	mesh.loft(0.0, depth, func(a: float) -> Vector4:
		var rr := rd * 0.98 * pow(1.0 - a, 0.6)
		return Vector4(rr, rr, 0.0, 2.0), 14, 44, BossMesh.INSIDE)
	var lip := PackedVector3Array()
	for i in 65:
		var angle := TAU * i / 64.0
		lip.append(Vector3(cos(angle) * rd, sin(angle) * rd, 0.05 * k))
	mesh.tube(lip, func(_t: float) -> float: return 0.3 * k, 8, BossMesh.BODY)
	for i in 56:
		var angle := TAU * (i + 0.5) / 56.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		mesh.tooth(radial * rd * 1.04, (radial * 0.6 + Vector3(0.0, 0.0, -0.8)).normalized() * 0.45 * k, 0.1 * k, Vector3.ZERO, 5, BossMesh.INSIDE)
	# Rings of hooked teeth, curving in toward the throat.
	var rings := [[0.86, 26], [0.72, 22], [0.58, 18], [0.44, 14], [0.3, 10]]
	for i in rings.size():
		var f: float = rings[i][0]
		var n: int = rings[i][1]
		var a := 1.0 - pow(f / 0.98, 1.0 / 0.6)
		for j in n:
			var angle := TAU * (j + 0.5 * (i % 2)) / n
			var radial := Vector3(cos(angle), sin(angle), 0.0)
			var base := radial * f * rd + Vector3(0.0, 0.0, a * depth)
			var size := lerpf(1.0, 0.5, i / 4.0) * k
			mesh.tooth(base, (-radial * 0.45 + Vector3(0.0, 0.0, -1.0)).normalized() * size, 0.14 * size, -radial * 0.35)
	# The rasp: a tongue of tooth plates at the throat.
	mesh.blob(Vector3(0.0, 0.0, depth * 0.85), Vector3(0.9, 0.9, 1.3) * k, Basis.IDENTITY, 8, 12, BossMesh.INSIDE)
	for j in 7:
		var angle := TAU * j / 7.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		mesh.tooth(Vector3(0.0, 0.0, depth * 0.85 - 1.0 * k) + radial * 0.45 * k, (Vector3(0.0, 0.0, -1.0) + radial * 0.3).normalized() * 0.7 * k,
				0.14 * k, radial * 0.2)
	# Two dorsal fins toward the tail, and the tail fin round its end.
	var top := func(z: float) -> Vector3:
		var slice: Vector4 = profile.call(z / length)
		return Vector3(0.0, slice.y * 0.97, z)
	var bottom := func(z: float) -> Vector3:
		var slice: Vector4 = profile.call(z / length)
		return Vector3(0.0, -slice.y * 0.97, z)
	for fin: Array in [[0.6, 0.74, 0.35, 1.0], [0.77, 0.985, 0.5, 1.0], [0.86, 0.985, 0.4, -1.0]]:
		var from: float = fin[0] * length
		var to: float = fin[1] * length
		var tall: float = fin[2] * r
		var sign_y: float = fin[3]
		var root := top if sign_y > 0.0 else bottom
		mesh.membrane(func(u: float) -> Vector3: return root.call(lerpf(from, to, u)),
			func(u: float) -> Vector3:
				var h := tall * sin(u * PI) * lerpf(1.0, 0.6, u)
				return Vector3(0.0, h * sign_y, h * 0.35),
			60, 4, Vector2(0.0, 1.0), BossMesh.FIN)
	var skin := _spine_material(LAMPREY_SKIN)
	skin.set_shader_parameter("radius", r)
	skin.set_shader_parameter("gill_z", _gill_z())
	skin.set_shader_parameter("gill_step", r * 0.55)
	skin.set_shader_parameter("gill_size", r * 0.2)
	skin.set_shader_parameter("spine_wave", Vector4(0.7 * k, 0.1, 2.2, 0.18))
	skin.set_shader_parameter("flutter", Vector3(0.3 * k, 1.1, 5.0))
	rig.add_mesh(self, mesh.commit(), skin)
	# Small yellow eyes behind the disc.
	for side: float in [-1.0, 1.0]:
		var eye := _eye(0.6 * k, Color(0.62, 0.55, 0.22), Color(0.3, 0.25, 0.08), 0.45)
		_add_rider(eye, Vector3(side * r * 0.8, r * 0.45, 1.9 * rd), Basis.looking_at(Vector3(side, 0.25, -0.2), Vector3.UP))
	# Her brood, clamped on along her flanks.
	var young := _lamprey_mesh(4.6 * k, 0.42 * k)
	var young_skin := StandardMaterial3D.new()
	young_skin.albedo_color = Color(0.3, 0.26, 0.17)
	young_skin.roughness = 0.3
	young_skin.metallic_specular = 0.8
	var spots := [0.2, 0.26, 0.32, 0.39, 0.45, 0.5, 0.57, 0.63, 0.7]
	for n in spots.size():
		var along: float = spots[n]
		var side := 1.0 if n % 2 == 0 else -1.0
		var slice: Vector4 = profile.call(along)
		var up: float = [0.1, -0.3, 0.35, -0.1, 0.2, -0.4, 0.0, 0.3, -0.2][n]
		var node := MeshInstance3D.new()
		node.mesh = young
		node.material_override = young_skin
		var angle := asin(clampf(up, -1.0, 1.0))
		var at := Vector3(side * slice.x * cos(angle) * 0.97, slice.y * up, along * length)
		var hang := Basis.looking_at(Vector3(side * 0.45, -0.75, 0.5).normalized(), Vector3(side, 0.3, 0.0))
		_add_rider(node, at, hang * Basis(Vector3.UP, PI), 0.3)
		_brood.append([node, 0.0])


## Her bolts are clots of blood.
func _bolt_mesh_look() -> Mesh:
	var clot := FxLooks.gob(23).duplicate() as ArrayMesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.45, 0.02, 0.03)
	glow.roughness = 0.15
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.08, 0.05)
	glow.emission_energy_multiplier = 1.2
	glow.rim_enabled = true
	glow.clearcoat_enabled = true
	clot.surface_set_material(0, glow)
	return clot
