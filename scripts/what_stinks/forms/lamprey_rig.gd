extends Node3D
## The Lamprey Queen as a Hunter's body (what_stinks.md section 2): LampreyBoss's look (one seamless mesh bent
## by a SpineRig: marbled sea lamprey skin, seven gill holes a side, an oral disc of hooked teeth round a
## rasping tongue, fins, her brood clamped to her flanks) without the boss node, laid along the trail the
## fish's head leaves, so the body follows its swimming and turning.
## A child of the fish's visual (so it is freed with it, hides with it and follows its bite pose). The mesh is
## `length` m long (the hitbox's length). The Corkscrew: the disc flares through the bite's wind-up, and when
## the bite lands the disc clamps and she rolls round her length (UnnaturalSettings.lamprey_spin rad/s) for
## `latch_time` s, then rights herself.
## Not a class_name: the Lamprey form preloads it.

const SKIN := preload("res://shaders/boss_lamprey.gdshader")
const EYE_SHADER := preload("res://shaders/fish_eye.gdshader")
## The body's radius over its length (the boss's is 3.72 / 88; a Hunter is stockier to fill its hitbox).
const RADIUS_OVER_LENGTH := 0.06
## The swim wave's amplitude (x k) at rest and at speed, and the turn's share of it.
const WAVE_REST := 0.12
const WAVE_SWIM := 0.5
const WAVE_TURN := 0.3
## How far the disc is clamped when she is latched on (negative: closed tight, as the boss).
const CLAMP := -0.3
## How far the held drill winds her body back against the roll at full charge (rad).
const WIND_BACK := 0.9

var fish: FishController
var length := 14.0
var radius := 0.84
var rig: SpineRig
var skin: ShaderMaterial
## How long she holds on and rolls after a bite lands (s: the sheet's "latch_s").
var latch_time := 1.1
## Her roll now (rad) and the latch's seconds left.
var spin := 0.0
var latch_left := 0.0
## The disc now (1 flared, negative clamped).
var disc := 0.0
var _riders: Array = []
var _trail := PackedVector3Array()
var _age := 0.0
var _wave := 0.0
var _offsets := PackedVector3Array()
var _dir := Vector3.ZERO
var _last_head := Vector3.ZERO
## Probe/tooling override of the body_stiffness setting (negative: use the setting).
var stiffness_override := -1.0
var _flare := 0.0
var _wind := 0.0
var _disc_want := 0.0
var _bite: HunterBite
## Msec until which the skin flashes after a bite lands (the snap chomp has no wind-up glow).
var _flash_until := 0


## Builds the body for `with_fish` at its hitbox's length now.
func build(with_fish: FishController) -> void:
	fish = with_fish
	length = fish.hitbox_length
	radius = length * RADIUS_OVER_LENGTH
	rig = SpineRig.new(length, radius * 2.2)
	_build_look()
	_pose(0.0)


## The disc flared `open` (0 closed, 1 wide; the bite's jaw).
func set_disc(open: float) -> void:
	_disc_want = open


## The disc's mouth, a little behind the lip, in world space.
func mouth_point() -> Vector3:
	return head_point()


func _process(delta: float) -> void:
	if not is_instance_valid(fish) or not is_visible_in_tree():
		return
	_age += delta
	_pose(delta)


## The head's world point: the front of the hitbox, lifted and turned by the bite's pose on the visual.
func head_point() -> Vector3:
	var xf := fish.get_global_transform_interpolated()
	var visual: Node3D = get_parent()
	return xf * (Basis.from_euler(visual.rotation) * Vector3(0.0, 0.0, -length * 0.5))


func _pose(delta: float) -> void:
	var head := head_point()
	if not _trail.is_empty() and _trail[_trail.size() - 1].distance_to(head) > length * 0.5:
		_trail.clear()  # a respawn or a teleport: the body goes with the head, not stretched back to where it was
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(head) > 0.25:
		_trail.append(head)
	var needed := length + 4.0
	var walked := 0.0
	var keep := _trail.size() - 1
	while keep > 0 and walked < needed:
		walked += _trail[keep].distance_to(_trail[keep - 1])
		keep -= 1
	if keep > 0:
		_trail = _trail.slice(keep)
	var body := fish.get_global_transform_interpolated().basis
	rig.head_up = body.y  # the body rolls with the fish (an air roll), not held to the world's up
	rig.head_back = body.z
	rig.follow_trail(head, _trail, body.z)
	_stiffen(delta, head, body.z)
	_corkscrew(delta)
	_swim_look()
	_pose_riders()
	rig.apply()


## The latch: while it lasts the disc is clamped and she rolls; after it she rights herself.
func _corkscrew(delta: float) -> void:
	var spin_rate := UnnaturalSettings.shared().lamprey_spin
	var drill := _drill()
	if drill != null and drill.consume_latch():
		latch_left = latch_time  # the disc met its prey at the dash's end: she rolls on it
		disc = 1.0
		_flare = 1.0
	# The drill: held, the rasp speeds up and the body winds back against the roll; released, it unwinds into the corkscrew dash.
	_wind = move_toward(_wind, drill.wind_now(_bite) if drill != null else 0.0, delta * 3.0)
	if latch_left > 0.0:
		latch_left -= delta
		spin += spin_rate * delta
		disc = move_toward(disc, CLAMP, delta * 6.0)
	elif drill != null and drill.active():
		spin += spin_rate * delta
		disc = move_toward(disc, 1.0, delta * 8.0)
	else:
		spin = lerp_angle(spin, 0.0, 1.0 - exp(-2.5 * delta))
		disc = move_toward(disc, _disc_want, delta * 3.0)
	rig.twist = spin - _wind * WIND_BACK + (get_parent() as Node3D).rotation.y * 2.0
	_flare = maxf(_flare - delta * 0.8, 0.0)
	skin.set_shader_parameter("disc", disc)
	skin.set_shader_parameter("disc_len", radius * 1.35 * 1.7)
	skin.set_shader_parameter("breath", 0.12 + 0.1 * sin(_age * 1.3) + _flare + 0.2 * _wind * sin(_age * (14.0 + 50.0 * _wind)))


## The Drill style the bite wears, if it does.
func _drill() -> DrillAttack:
	var bite := _find_bite()
	return bite.attack as DrillAttack if bite != null else null


## The swim: a wave down the body that grows with the speed and the turn (the bend itself is the trail's).
func _swim_look() -> void:
	var k := radius / 3.72
	var speed := fish.linear_velocity.length()
	var t := clampf(speed / maxf(length * 0.5, 1.0), 0.0, 1.0)
	var turn := clampf(absf(fish.angular_velocity.y) / 1.5, 0.0, 1.0)
	var amp := k * (WAVE_REST + WAVE_SWIM * t + WAVE_TURN * turn) * 5.0 * _flex()
	_wave = lerpf(_wave, amp, 0.1)
	skin.set_shader_parameter("spine_wave", Vector4(_wave, 0.1 * 88.2 / length, 2.2, 0.18))
	var warn := 0.0
	var bite := _find_bite()
	if bite and bite.bite and bite.bite.winding():
		warn = (0.5 + 0.5 * sin(_age * 26.0)) * UnnaturalSettings.shared().telegraph_glow
	# the snap chomp has no wind-up: the strike flashes the skin instead (impact)
	warn = maxf(warn, clampf(float(_flash_until - Time.get_ticks_msec()) / 220.0, 0.0, 1.0) * UnnaturalSettings.shared().telegraph_glow)
	skin.set_shader_parameter("warn", warn)


func _find_bite() -> HunterBite:
	if _bite == null or not is_instance_valid(_bite):
		_bite = fish.get_node_or_null("HunterBite") as HunterBite
		if _bite and not _bite.has_meta("lamprey_latch"):
			_bite.set_meta("lamprey_latch", true)
			_bite.chomped.connect(_on_chomped)
	return _bite


## The disc lands: it clamps and she corkscrews; the gills pulse.
func _on_chomped(_mouth: Vector3, _reach: float, _radius: float, _capacity: int) -> void:
	_flash_until = Time.get_ticks_msec() + 220
	var drill := _drill()
	if drill != null and drill.active():
		return  # the drill's run is her corkscrew: she rolls through it, and latches only on prey at its end
	latch_left = latch_time
	disc = 1.0  # the disc flares wide as it lands (a snap chomp never opened it), then clamps
	_flare = 1.0


func _pose_riders() -> void:
	for rider: Array in _riders:
		var node: Node3D = rider[0]
		var at: Vector3 = rider[1]
		var frame := rig.frame_at(at.z)
		var basis: Basis = rider[2]
		var sway: float = rider[3]
		if sway > 0.0:
			basis = Basis(Vector3.RIGHT, sin(_age * 1.7 + at.z) * sway) * basis
		node.global_transform = Transform3D(frame.basis * basis, frame.origin + frame.basis.x * at.x + frame.basis.y * at.y)


func _add_rider(node: Node3D, at: Vector3, basis: Basis, sway := 0.0) -> void:
	node.top_level = true
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_riders.append([node, at, basis.scaled(node.scale), sway])


func _eye(size: float, iris: Color, inner: Color, pupil: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = EYE_SHADER
	material.set_shader_parameter("iris", iris)
	material.set_shader_parameter("iris_inner", inner)
	material.set_shader_parameter("pupil", pupil)
	material.set_shader_parameter("sheen", 0.15)
	material.set_shader_parameter("glow", 0.5)  # so the small yellow eyes read in the murk
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var eye := MeshInstance3D.new()
	eye.mesh = sphere
	eye.material_override = material
	eye.scale = Vector3.ONE * size * 2.0
	return eye


## LampreyBoss._build_look, at this radius and length.
func _build_look() -> void:
	var r := radius
	var k := r / 3.72
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
	skin = ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("radius", r)
	skin.set_shader_parameter("gill_z", r * 1.35 * 2.4)
	skin.set_shader_parameter("gill_step", r * 0.55)
	skin.set_shader_parameter("gill_size", r * 0.2)
	skin.set_shader_parameter("spine_wave", Vector4(0.7 * k, 0.1 * 88.2 / length, 2.2, 0.18))
	skin.set_shader_parameter("flutter", Vector3(0.3 * k, 1.1 * 88.2 / length, 5.0))
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


static func _lamprey_mesh(span: float, radius_m: float) -> ArrayMesh:
	var mesh := BossMesh.new(span)
	mesh.loft(0.0, span, func(along: float) -> Vector4:
		var rr := radius_m * BossMesh.taper(along, 0.08, 0.25, 0.25)
		return Vector4(rr, rr, 0.0, 2.0), 20, 10)
	return mesh.commit()


## body_stiffness (a WhatStinksSettings knob; 0 = the old floppy body, 1 = a rigid bar), read tolerantly so the body still builds
## before the setting is registered. Default 0.4, i.e. 0.6 of the old flex.
func _stiffness() -> float:
	if stiffness_override >= 0.0:
		return clampf(stiffness_override, 0.0, 1.0)
	var value: Variant = WhatStinksSettings.shared().get("body_stiffness")
	return clampf(float(value) if value != null else 0.4, 0.0, 1.0)


## The share of the old flex left (1 at no stiffness).
func _flex() -> float:
	return 1.0 - _stiffness()


## Stiffens the bend the trail made: each spine point is drawn toward the straight line tailward from the head (more so
## down the body), re-spaced to the segment length, then eased in time (higher stiffness: damped harder) so the
## body trails the head in a stiffer, calmer curve. The head's own points and the stride wave are left alone.
func _stiffen(delta: float, head: Vector3, back: Vector3) -> void:
	var stiff := _stiffness()
	if _last_head.distance_to(head) > rig.length * 0.5:
		_offsets.clear()  # a respawn or a teleport: no easing across it
		_dir = Vector3.ZERO
	_last_head = head
	if stiff <= 0.001:
		_offsets.clear()
		_dir = Vector3.ZERO
		return
	var n := SpineRig.SPINE_N
	var step := rig.length / float(n - 1)
	var dir := back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
	var ease_rate := lerpf(30.0, 8.0, stiff)
	var k := 1.0 if delta <= 0.0 or _offsets.size() != n or _dir == Vector3.ZERO else 1.0 - exp(-ease_rate * delta)
	dir = dir if _dir == Vector3.ZERO else _dir.slerp(dir, k).normalized()
	_dir = dir
	var raw := rig.points.duplicate()
	if _offsets.size() != n:
		_offsets.resize(n)
		_offsets.fill(Vector3.ZERO)
	var curve := PackedVector3Array()
	curve.resize(n)
	curve[0] = head
	for s in range(1, n):
		var along := float(s) / float(n - 1)
		var straight := head + dir * (s * step)
		var pull := (1.0 - (1.0 - stiff) * (1.0 - stiff)) * 0.8 * smoothstep(0.0, 0.35, along)
		var want: Vector3 = raw[s].lerp(straight, pull)
		var off: Vector3 = _offsets[s].lerp(want - straight, k)
		_offsets[s] = off
		curve[s] = straight + off
	# Resampled evenly by length along that curve (the blend shortens it a little: it runs on straight past its end).
	var tail_run := (curve[n - 1] - curve[n - 2]).normalized() if curve[n - 1].distance_squared_to(curve[n - 2]) > 0.000001 else dir
	curve.append(curve[n - 1] + tail_run * rig.length)
	var at := 1
	var walked := 0.0
	for s in range(1, n):
		var want_d := s * step
		while at < n and walked + curve[at].distance_to(curve[at - 1]) < want_d:
			walked += curve[at].distance_to(curve[at - 1])
			at += 1
		var a := curve[at - 1]
		var b := curve[at]
		rig.points[s] = a.lerp(b, (want_d - walked) / maxf(a.distance_to(b), 0.0001))
	rig.call("_frames")
