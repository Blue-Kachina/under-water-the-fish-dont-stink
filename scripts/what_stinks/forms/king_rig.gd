extends Node3D
## The King of Herrings as a Hunter's body (what_stinks.md section 2): BloodLeviathan's look (one seamless
## mesh bent by a SpineRig: oarfish skin, crest, oars, jaw, milky eyes, lampreys on its flanks) without the
## boss node, laid along the trail the fish's head leaves, so the body follows its swimming and turning.
## A child of the fish's visual (so it is freed with it, hides with it and follows its bite pose). The mesh is
## `length` m long (the hitbox's length) and `girth` m is its deepest half height scale (BloodLeviathan's 6).
## Not a class_name: the King form preloads it.

const SKIN := preload("res://shaders/boss_oarfish.gdshader")
const EYE_SHADER := preload("res://shaders/fish_eye.gdshader")
## The deepest half height over the length (the boss's is 6 / 109; a Hunter is stockier to fill its hitbox).
const GIRTH_OVER_LENGTH := 0.095
## The swim wave's amplitude (x k) at rest and at speed, and the turn's share of it.
const WAVE_REST := 0.12
const WAVE_SWIM := 0.5
const WAVE_TURN := 0.3

var fish: FishController
var length := 16.0
var girth := 1.5
var rig: SpineRig
var skin: ShaderMaterial
var _hinge := Vector2.ZERO
var _riders: Array = []
var _trail := PackedVector3Array()
var _age := 0.0
var _wave := 0.0
var _offsets := PackedVector3Array()
var _dir := Vector3.ZERO
var _last_head := Vector3.ZERO
## Probe/tooling override of the body_stiffness setting (negative: use the setting).
var stiffness_override := -1.0
## How tight the body is coiled now (0 to 1), eased toward what CoilAttack wants.
var _coil := 0.0
var _bite: HunterBite
## Msec until which the skin flashes after a bite lands (the snap chomp has no wind-up glow).
var _flash_until := 0


## Builds the body for `with_fish` at its hitbox's length now.
func build(with_fish: FishController) -> void:
	fish = with_fish
	length = fish.hitbox_length
	girth = length * GIRTH_OVER_LENGTH
	rig = SpineRig.new(length, girth * 1.6)
	_build_look()
	_pose()


## The jaw dropped `angle` rad (negative: shut tight).
func set_jaw(angle: float) -> void:
	if skin:
		skin.set_shader_parameter("hinge", Vector3(_hinge.x, _hinge.y, angle))


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


func _pose(delta := 0.0) -> void:
	var head := head_point()
	var coil := _coil_attack()
	if coil != null:
		# The whip: the head swings round a pivot behind the mouth (the sector's apex), cocked to one side while the coil is held.
		var swing := coil.sweep_at(_bite)
		if swing != 0.0:
			var xf := fish.get_global_transform_interpolated()
			var pivot := head + xf.basis.z.normalized() * coil.pivot_back(_bite)
			head = pivot + (head - pivot).rotated(xf.basis.y.normalized(), swing)
		var target := coil.coil_target(_bite)
		_coil = move_toward(_coil, target, delta * (2.5 if target > _coil else 9.0))
	elif _coil > 0.0:
		_coil = 0.0
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
	_curl()
	rig.twist = (get_parent() as Node3D).rotation.y * 2.0
	_swim_look()
	_pose_riders()
	rig.apply()


## The coil: the body behind the neck turns round the fish's up as the coil tightens (the spine's segments each turned a little
## more, the head's own stretch left straight), through coil_curl_deg at full. Held in `_coil` (0 straight to 1 fully curled).
func _curl() -> void:
	var total := deg_to_rad(WhatStinksSettings.shared().coil_curl_deg) * _coil
	if total <= 0.0001:
		return
	var axis := rig.head_up.normalized()
	var from := rig.points.duplicate()
	var first := int(SpineRig.SPINE_N * 0.12)
	var last := int(SpineRig.SPINE_N * 0.75)
	for s in range(1, SpineRig.SPINE_N):
		var turned := total * clampf(float(s - first) / float(last - first), 0.0, 1.0)
		rig.points[s] = rig.points[s - 1] + (from[s] - from[s - 1]).rotated(axis, turned)
	rig.call("_frames")


## The Coil style the bite wears, if it does.
func _coil_attack() -> CoilAttack:
	var bite := _find_bite()
	return bite.attack as CoilAttack if bite != null else null


## The swim: a wave down the body that grows with the speed and the turn (the bend itself is the trail's).
func _swim_look() -> void:
	var k := girth / 6.0
	var speed := fish.linear_velocity.length()
	var t := clampf(speed / maxf(length * 0.5, 1.0), 0.0, 1.0)
	var turn := clampf(absf(fish.angular_velocity.y) / 1.5, 0.0, 1.0)
	var amp := k * (WAVE_REST + WAVE_SWIM * t + WAVE_TURN * turn) * 2.5 * _flex()
	_wave = lerpf(_wave, amp, 0.1)
	skin.set_shader_parameter("spine_wave", Vector4(_wave, 0.12 * 109.0 / length, 1.6, 0.15))
	var warn := 0.0
	var bite := _find_bite()
	if bite and bite.bite and bite.bite.winding():
		warn = (0.5 + 0.5 * sin(_age * 26.0)) * UnnaturalSettings.shared().telegraph_glow
		if bite.holding():
			warn *= lerpf(0.4, 1.0, bite.charge())  # the skin burns brighter as the coil tightens
	# the snap chomp has no wind-up: the strike flashes the skin instead (impact)
	warn = maxf(warn, clampf(float(_flash_until - Time.get_ticks_msec()) / 220.0, 0.0, 1.0) * UnnaturalSettings.shared().telegraph_glow)
	skin.set_shader_parameter("warn", warn)


func _find_bite() -> HunterBite:
	if _bite == null or not is_instance_valid(_bite):
		_bite = fish.get_node_or_null("HunterBite") as HunterBite
		if _bite and not _bite.has_meta("king_flash"):
			_bite.set_meta("king_flash", true)
			_bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: _flash_until = Time.get_ticks_msec() + 220)
	return _bite


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


func _eye(radius: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = EYE_SHADER
	material.set_shader_parameter("iris", Color(0.8, 0.82, 0.83))
	material.set_shader_parameter("iris_inner", Color(0.68, 0.7, 0.71))
	material.set_shader_parameter("pupil", 0.3)
	material.set_shader_parameter("sheen", 0.15)
	material.set_shader_parameter("glow", 0.8)  # pale, so they read in the murk
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var eye := MeshInstance3D.new()
	eye.mesh = sphere
	eye.material_override = material
	eye.scale = Vector3.ONE * radius * 2.0
	return eye


## BloodLeviathan._build_look, at this girth and length.
func _build_look() -> void:
	var g := girth
	var k := g / 6.0
	var deep := g * 0.8
	var mesh := BossMesh.new(length)
	var profile := func(along: float) -> Vector4:
		var h := deep * BossMesh.taper(along, 0.065, 0.05, 0.42)
		var head := 1.0 - smoothstep(0.0, 0.1, along)
		return Vector4(h * lerpf(0.22, 0.42, head), h, -h * 0.08 * head, 1.6)
	mesh.loft(0.0, length, profile, 280, 30, BossMesh.BODY)
	var top := func(z: float) -> Vector3:
		var slice: Vector4 = profile.call(z / length)
		return Vector3(0.0, slice.z + slice.y * 0.96, z)
	var fin_from := 5.5 * k
	var fin_to := length * 0.985
	mesh.membrane(func(u: float) -> Vector3: return top.call(lerpf(fin_from, fin_to, u)),
		func(u: float) -> Vector3:
			var a := lerpf(fin_from, fin_to, u) / length
			var h := deep * 0.42 * lerpf(1.0, 0.45, a) * (1.0 - pow(maxf(a - 0.9, 0.0) / 0.1, 2.0))
			return Vector3(0.0, h, h * 0.3),
		320, 4, Vector2(0.0, 1.0), BossMesh.FIN)
	var crest_from := 1.2 * k
	var crest_to := 5.5 * k
	mesh.membrane(func(u: float) -> Vector3: return top.call(lerpf(crest_from, crest_to, u)),
		func(u: float) -> Vector3: return Vector3(0.0, lerpf(2.8, 1.6, u) * k, lerpf(0.6, 1.4, u) * k),
		40, 4, Vector2(0.1, 0.9), BossMesh.FIN)
	for n in 11:
		var t := n / 10.0
		var base: Vector3 = top.call(lerpf(crest_from, crest_to, t))
		var rise := lerpf(6.0, 2.6, t) * k
		var back := lerpf(19.0, 9.0, t) * k
		var lean := (0.3 + 0.9 * t) * k * (1.0 if n % 2 == 0 else -1.0)
		var path := PackedVector3Array()
		for i in 28:
			var s := i / 27.0
			var y := base.y + rise * sin(minf(s * 1.4, 1.0) * PI * 0.5) - rise * 0.35 * maxf(s - 0.6, 0.0) + 0.5 * k * sin(s * 6.0 + n) * s
			path.append(Vector3(lean * s, y, base.z + back * pow(s, 1.25)))
		mesh.tube(path, func(s: float) -> float: return lerpf(0.24, 0.035, s) * k, 7, BossMesh.FILAMENT, Vector2(0.1, 1.0))
	for side: float in [-1.0, 1.0]:
		var z0 := 8.0 * k
		var slice: Vector4 = profile.call(z0 / length)
		var base := Vector3(side * slice.x * 0.4, slice.z - slice.y * 0.85, z0)
		var path := PackedVector3Array()
		for i in 22:
			var s := i / 21.0
			path.append(base + Vector3(side * (0.5 + 1.6 * s) * k, -8.0 * k * s, 6.0 * k * s * s))
		mesh.tube(path, func(s: float) -> float: return lerpf(0.16, 0.08, s) * k, 7, BossMesh.FILAMENT, Vector2(0.05, 0.8))
		var tip := path[path.size() - 1]
		mesh.blob(tip + Vector3(0.0, -0.7 * k, 0.3 * k), Vector3(0.14, 0.95, 0.5) * k, Basis(Vector3.RIGHT, 0.3), 8, 12, BossMesh.FILAMENT)
	var jaw_from := -1.0 * k
	var jaw_to := 4.4 * k
	var jaw_profile := func(along: float) -> Vector4:
		var grow := pow(sin(minf(along * 1.5, 1.0) * PI * 0.5), 0.6)
		var drop := lerpf(-deep * 0.55 - 2.2 * k, -deep * 0.32, along)
		return Vector4(1.15 * k * grow, 0.42 * k * grow, drop, 1.8)
	_hinge = Vector2(-deep * 0.32, jaw_to)
	mesh.hinge = 1.0
	mesh.loft(jaw_from, jaw_to, jaw_profile, 24, 16, BossMesh.INSIDE)
	for side: float in [-1.0, 1.0]:
		mesh.hinge = 1.0
		for n in 13:
			var t := lerpf(0.08, 0.75, n / 12.0)
			var slice: Vector4 = jaw_profile.call(t)
			var z := lerpf(jaw_from, jaw_to, t)
			mesh.tooth(Vector3(side * slice.x * 0.75, slice.z + slice.y * 0.75, z), Vector3(-side * 0.12, 1.0, 0.2).normalized() * lerpf(0.75, 0.4, t) * k,
					0.1 * k, Vector3(0.0, 0.0, 0.35))
		mesh.hinge = 0.0
		for n in 11:
			var z := lerpf(0.2, 3.4, n / 10.0) * k
			var slice: Vector4 = profile.call(z / length)
			mesh.tooth(Vector3(side * slice.x * 0.8, slice.z - slice.y * 0.72, z), Vector3(side * 0.05, -1.0, 0.15).normalized() * lerpf(0.7, 0.35, n / 10.0) * k,
					0.09 * k, Vector3(0.0, 0.0, 0.3))
	skin = ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("girth", deep)
	var eye_z := 3.3 * k
	var eye_slice: Vector4 = profile.call(eye_z / length)
	var eye_rest := Vector3(eye_slice.x * 0.86, eye_slice.z + eye_slice.y * 0.36, eye_z)
	skin.set_shader_parameter("eye_at", eye_rest)
	skin.set_shader_parameter("eye_ring", 1.15 * k)
	skin.set_shader_parameter("spine_wave", Vector4(0.35 * k, 0.12 * 109.0 / length, 1.6, 0.15))
	skin.set_shader_parameter("flutter", Vector3(0.45 * k, 0.45 / maxf(k, 0.05), 4.5))
	rig.add_mesh(self, mesh.commit(), skin)
	for side: float in [-1.0, 1.0]:
		var eye := _eye(0.85 * k)
		_add_rider(eye, Vector3(side * eye_rest.x, eye_rest.y, eye_rest.z), Basis.looking_at(Vector3(side, 0.1, -0.15), Vector3.UP))
	var lamprey := _lamprey_mesh(3.6 * k, 0.32 * k)
	var lamprey_skin := StandardMaterial3D.new()
	lamprey_skin.albedo_color = Color(0.24, 0.21, 0.15)
	lamprey_skin.roughness = 0.45
	lamprey_skin.metallic_specular = 0.7
	var spots := [[0.17, 1.0, 0.1], [0.26, -1.0, -0.2], [0.37, 1.0, -0.35], [0.44, -1.0, 0.25], [0.56, 1.0, 0.0], [0.65, -1.0, -0.3], [0.79, 1.0, 0.15]]
	for spot: Array in spots:
		var z: float = spot[0] * length
		var side: float = spot[1]
		var slice: Vector4 = profile.call(spot[0])
		var y: float = slice.z + slice.y * float(spot[2])
		var node := MeshInstance3D.new()
		node.mesh = lamprey
		node.material_override = lamprey_skin
		var hang := Basis.looking_at(Vector3(side * 0.35, -0.85, 0.4).normalized(), Vector3(side, 0.3, 0.0))
		_add_rider(node, Vector3(side * slice.x * 0.95, y, z), hang * Basis(Vector3.UP, PI), 0.25)


static func _lamprey_mesh(span: float, radius: float) -> ArrayMesh:
	var mesh := BossMesh.new(span)
	mesh.loft(0.0, span, func(along: float) -> Vector4:
		var r := radius * BossMesh.taper(along, 0.08, 0.25, 0.25)
		return Vector4(r, r, 0.0, 2.0), 20, 10)
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
