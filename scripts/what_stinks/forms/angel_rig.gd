extends Node3D
## The Fallen Angel's body on a Hunter's fish (a child of the fish's model): a SpineRig in the model's own space,
## bent by the fish's own motion instead of the boss's AI (as GulperRig). The swim reads from the controller: the
## wings beat faster with speed and the glass body trails each turn (yaw and pitch of the fish, each segment lagging
## the one before). The bite's `open` (AngelJaw) opens the crown out of the top of its head, flushing it orange and
## closing a lock-on ring in on the end of the bite's cone; when the bite lands the tentacles lash out along it.
## In the lock style (LockAttack) the ring sits on the target instead, a thin line runs from the crown to it, the count
## a release would take ("x5") shows beside it and the fish that would go are ringed; a refused press flickers the crown.

const MODEL := preload("res://scripts/what_stinks/forms/angel_model.gd")
const JAW := preload("res://scripts/what_stinks/forms/angel_jaw.gd")
const N := SpineRig.SPINE_N
## How long a refused press flickers the crown (s).
const DENIED_TIME := 0.4
## Most fish ringed at once.
const MAX_MARKS := 16

## How hard each segment follows the one ahead of it (1/s): higher is a stiffer body.
@export_range(2.0, 200.0, 1.0, "or_greater") var follow_rate := 50.0
## The wingbeats a second at rest and at full speed.
@export_range(0.0, 8.0, 0.05, "or_greater") var beat_idle := 0.8
@export_range(0.0, 8.0, 0.05, "or_greater") var beat_swim := 2.4
## The sideways swim wave at rest and at full speed (x the boss's amplitude).
@export_range(0.0, 3.0, 0.05, "or_greater") var wave_idle := 0.2
@export_range(0.0, 3.0, 0.05, "or_greater") var wave_swim := 1.0
## The speed the wave and the beat are full at (x the fish's top boost speed).
@export_range(0.1, 2.0, 0.05, "or_greater") var wave_full_speed := 0.6
## How long the tentacles stay thrown out after the bite lands (s).
@export_range(0.0, 3.0, 0.05, "or_greater") var lash_time := 0.45

var fish: FishController
## The model is built at the boss's own height (its shaders are tuned to it) and this node scales it down to the box.
var unit := 0.03
var rig := SpineRig.new()
var jaw: JAW
var skin: ShaderMaterial
var organs: ShaderMaterial
## The head's z in the model's space (the body is centred on the box).
var head_z := 0.0
var speed_frac := 0.0
## How far the crown is open (0 closed to 1 splayed), and how hard it just lashed (1 on landing, fading to 0).
var crown_open := 0.0
var lash := 0.0
var beat_clock := 0.0
var halo: MeshInstance3D
## The lock's pieces: the line from the crown to the target, the count by the ring, the rings on the fish that would be taken.
var beam: MeshInstance3D
var count_label: Label3D

## Exaggeration (AttackExaggerate, planning_new_hunters.md B3). `ex` runs the bite's press / hold / release / contact and drives
## the crown's reach (jaw), the wings (limb), the lock ring and glow (throat) and the body's lunge (head); `ex_lash` is a second
## spring released when the bite lands, so the tentacles' lash snaps out at contact, not at the release before it.
## Presets live here (the form's own); the panel's hunter_exaggeration scales them (0 = rest).
const EXAGGERATE := {
	"channels": {
		"jaw": {"hold_peak": 1.9, "squash": 0.6, "release_peak": 1.5, "omega": 22.0, "zeta": 0.36, "volume": 0.0},
		"limb": {"hold_peak": 1.5, "squash": 0.7, "release_peak": 1.85, "omega": 22.0, "zeta": 0.34, "volume": 0.3},
		"throat": {"hold_peak": 1.15, "squash": 0.82, "release_peak": 2.3, "omega": 16.0, "zeta": 0.4, "volume": 0.0},
		"head": {"hold_peak": 1.08, "squash": 0.86, "release_peak": 1.28, "omega": 20.0, "zeta": 0.42, "volume": 0.5},
	},
}
const LASH_EXAGGERATE := {
	"channels": {"jaw": {"hold_peak": 1.0, "squash": 1.0, "release_peak": 1.9, "omega": 20.0, "zeta": 0.34, "volume": 0.0}},
	"snap_time": 0.09,
}
## Most the wings flare out over their rest angle at full exaggeration (rad per unit of scale above 1).
const WING_FLARE := 0.5
## Longest the lash throws a tentacle (x its rest length).
const LASH_REACH_MAX := 2.4
var ex: AttackExaggerate
var ex_lash: AttackExaggerate
var _form := {}
var _body_scale := Vector3.ONE
var _body_shift := 0.0

var _bite: HunterBite
var _bites_seen := 0
var _lag_yaw := PackedFloat32Array()
var _lag_pitch := PackedFloat32Array()
var _turn := Vector2.ZERO
var _last_basis := Basis.IDENTITY
var _last_at := Vector3.ZERO
var _speed := 0.0
var _wings: Array[MeshInstance3D] = []
var _tentacles: Array[MeshInstance3D] = []
var _tentacle_skins: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _halo_skin: StandardMaterial3D
var _beam_skin: StandardMaterial3D
var _marks: Array[MeshInstance3D] = []
var _fresh := true
var _age := 0.0


func setup(for_fish: FishController) -> void:
	name = "Angel"
	fish = for_fish
	var h := MODEL.H
	unit = FishCharacter.hitbox_size(FishCharacter.FishClass.MONSTER).z / h * 0.97
	scale = Vector3.ONE * unit
	head_z = -h * 0.5
	var look: Dictionary = MODEL.build()
	skin = look.skin
	organs = look.organ_skin
	rig.length = h
	rig.reach = h * 0.25
	var inside := MeshInstance3D.new()
	inside.name = "AngelOrgans"
	inside.mesh = look.organs
	inside.material_override = organs
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inside)
	var glass := MeshInstance3D.new()
	glass.name = "AngelMesh"
	glass.mesh = look.body
	glass.material_override = skin
	glass.sorting_offset = 1.0  # drawn over the organs inside it
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	rig.materials.append(skin)
	rig.materials.append(organs)
	rig.instances.append(glass)
	rig.instances.append(inside)
	for w in 2:
		var wing := MeshInstance3D.new()
		wing.name = "Wing"
		wing.mesh = look.wing
		wing.material_override = look.wing_skin
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.extra_cull_margin = h * 0.3
		add_child(wing)
		_wings.append(wing)
	_tentacle_skins = look.tentacle_skins
	for t in MODEL.TENTACLES:
		var node := MeshInstance3D.new()
		node.name = "Tentacle"
		node.mesh = look.tentacle
		node.material_override = _tentacle_skins[t]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = h * 0.5
		node.visible = false
		add_child(node)
		_tentacles.append(node)
	_light = OmniLight3D.new()
	_light.name = "CrownLight"
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.light_energy = 1.2
	_light.light_volumetric_fog_energy = 0.0
	_light.light_specular = 0.0  # its highlight drew a bright streak over its head
	add_child(_light)
	_build_halo()
	jaw = JAW.new()
	jaw.mouth_at = Vector3(0.0, h * 0.012, head_z - h * 0.06) * unit  # in the model's space, not ours: the crown's base, a little ahead of the hood
	_lag_yaw.resize(N)
	_lag_pitch.resize(N)
	_make_kits(HunterForms.sheet("fallen_angel"))
	_pose(0.0)


## The exaggeration kits for `form` (its sheet or the bite's): the panel's master and tuning over this form's presets.
func _make_kits(form: Dictionary) -> void:
	_form = form
	var settings := WhatStinksSettings.shared()
	var params := AttackExaggerate.params_from(settings, AttackExaggerate.merged(form, {"exaggerate": EXAGGERATE}))
	ex = AttackExaggerate.new(params)
	var lash_params := AttackExaggerate.merged(params, LASH_EXAGGERATE)
	ex_lash = AttackExaggerate.new(lash_params)
	ex.camera_punch.connect(_on_punch)
	# Parts that grow need room to be drawn: the culling box follows the most they can reach.
	var peak := maxf(ex.potential_peak(), ex_lash.potential_peak())
	for wing in _wings:
		wing.extra_cull_margin = MODEL.H * 0.3 * peak
	for node in _tentacles:
		node.extra_cull_margin = MODEL.H * 0.5 * peak


func _on_punch(amount: float, dir: Vector3) -> void:
	if not is_instance_valid(fish) or fish.puppet:
		return
	var cam := ChompKit.view_camera(fish)
	if cam != null and cam.has_method("punch"):
		cam.call("punch", amount, dir)


## The bite's beats into the kit (connected once, when the rig finds its bite).
func _wire_bite() -> void:
	_bite.opened.connect(func() -> void: ex.press())
	_bite.released.connect(func(charge: float) -> void: ex.release(charge))
	_bite.aborted.connect(func() -> void: ex.abort())
	_bite.landed.connect(_on_landed)
	if not _bite.form.is_empty() and str(_bite.form.get("key", "")) == str(_form.get("key", "")) and _bite.form.has("exaggeration"):
		ex.set_strength(float(ex.params["master"]), float(_bite.form["exaggeration"]))


func _on_landed(taken: int) -> void:
	var share := 1.0
	if _bite != null and taken >= 0:
		share = clampf(float(taken) / float(maxi(_bite.capacity(), 1)), 0.0, 1.0)
	ex.contact(share)
	ex_lash.release(1.0)


## The ring that shows the bite's lock-on: the end of the cone, closing in as the crown opens.
func _build_halo() -> void:
	halo = MeshInstance3D.new()
	halo.name = "LockHalo"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_halo_skin = StandardMaterial3D.new()
	_halo_skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_skin.no_depth_test = true
	_halo_skin.albedo_color = Color(1.0, 0.85, 0.7, 0.0)
	torus.material = _halo_skin
	halo.mesh = torus
	halo.top_level = true
	halo.visible = false
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(halo)
	beam = MeshInstance3D.new()
	beam.name = "LockBeam"
	var rod := CylinderMesh.new()
	rod.top_radius = 0.5
	rod.bottom_radius = 0.5
	rod.height = 1.0
	rod.radial_segments = 6
	rod.rings = 1
	_beam_skin = StandardMaterial3D.new()
	_beam_skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_skin.no_depth_test = true
	_beam_skin.albedo_color = Color(1.0, 0.6, 0.25, 0.0)
	rod.material = _beam_skin
	beam.mesh = rod
	beam.top_level = true
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(beam)
	count_label = Label3D.new()
	count_label.name = "LockCount"
	count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	count_label.no_depth_test = true
	count_label.fixed_size = true
	count_label.pixel_size = 0.0014
	count_label.font_size = 48
	count_label.outline_size = 10
	count_label.modulate = Color(1.0, 0.85, 0.5)
	count_label.top_level = true
	count_label.visible = false
	count_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(count_label)


func _straighten() -> void:
	_lag_yaw.fill(0.0)
	_lag_pitch.fill(0.0)
	_turn = Vector2.ZERO


func _find_bite() -> void:
	for child in fish.get_children():
		if child is HunterBite:
			_bite = child
			_bites_seen = _bite.bites
			_wire_bite()
			return


func _process(delta: float) -> void:
	if not is_instance_valid(fish) or delta <= 0.0 or not is_visible_in_tree():
		return
	if _bite == null or not is_instance_valid(_bite):
		_find_bite()
	var dt := _step_exaggeration(delta)
	_age += dt
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
	beat_clock += dt * lerpf(beat_idle, beat_swim, speed_frac)
	_pose(delta)
	_dress(dt)


## Advances the kits (the panel's master read live), returns the hit-stop-aware delta for the rig's own clocks, and lays the
## body's lunge: stretched along its length about the tail, so the head thrusts out and the tail stays put.
func _step_exaggeration(delta: float) -> float:
	var master: Variant = WhatStinksSettings.shared().get("hunter_exaggeration")
	var form_mult := float(ex.params["form_mult"])
	if master != null:
		ex.set_strength(float(master), form_mult)
		ex_lash.set_strength(float(master), form_mult)
	if _bite != null and is_instance_valid(_bite) and _bite.holding():
		ex.hold(_bite.charge())
	var dt := ex.tick(delta)
	ex_lash.tick(dt)
	var stretch := ex.scale_basis(&"head", Vector3.BACK)
	var along := stretch.z.length()
	var across := stretch.x.length()
	_body_scale = Vector3(across, across, along)
	scale = Vector3.ONE * unit * _body_scale
	position.z = MODEL.H * 0.5 * unit * (1.0 - along)  # pivot at the tail
	return dt


## The largest the body and its parts are drawn right now over rest: cameras pad their collision by it.
func camera_margin(radius: float) -> float:
	return radius * maxf(maxf(ex.peak_scale(), ex_lash.peak_scale()), _body_scale.z)


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
	_pose_wings()
	_pose_crown()
	_light.transform = Transform3D(Basis.IDENTITY, rig.place(Vector3(0.0, 0.0, MODEL.H * 0.1)))


## The wings row at the shoulders, down hard on the power stroke (the boss's own stroke).
func _pose_wings() -> void:
	var stroke := fposmod(beat_clock, 1.0)
	var flap := sin(stroke * TAU) * 0.75 - 0.1
	var h := MODEL.H
	var frame := rig.frame_at(h * 0.24)
	# The wings flare: wide on the swell, folded in on the press, thrown out on the release (spread angle and span).
	var flare := (ex.scale_of(&"limb") - 1.0) * WING_FLARE
	var spread := ex.scale_basis(&"limb", Vector3.RIGHT)
	for w in _wings.size():
		var sign_x := -1.0 if w == 0 else 1.0
		var root := frame.origin + frame.basis.x * sign_x * h * 0.095 + frame.basis.y * h * 0.01
		var turn := Basis(frame.basis.z, sign_x * (flap * 0.6 + flare)) * Basis(frame.basis.y, -flap * 0.5 * sign_x)
		_wings[w].transform = Transform3D(turn * frame.basis * Basis.from_scale(Vector3(sign_x, 1.0, 1.0)) * spread, root)


## The crown: six tentacles out of the top of the head, folded inside it when closed, splayed into a starburst as it
## opens, thrown out along the nose when the bite lands (the boss's crown, with the head's forward as its up).
func _pose_crown() -> void:
	var h := MODEL.H
	var head := rig.frame_at(0.0)
	var up := -head.basis.z  # tailward is back: ahead of the head is its crown's way
	var front := head.basis.y
	var right := up.cross(front).normalized()
	var base := rig.place(Vector3(0.0, h * 0.012, h * 0.03))  # out of the top of the hood
	var length := h * 0.36
	var grow := ex.scale_of(&"jaw")  # the crown's reach: curled in on the press, thrown wide on the swell
	var lash_grow := ex_lash.scale_of(&"jaw")
	for t in _tentacles.size():
		var around := TAU * t / MODEL.TENTACLES + 0.3
		var radial := (front * cos(around) + right * sin(around)).normalized()
		var root := base + radial * h * 0.05 * crown_open * grow  # round the opened crown's rim
		var splay := clampf(lerpf(0.05, 1.25, crown_open) + (grow - 1.0) * 0.35 * crown_open, 0.0, 1.5)
		var dir := (up * cos(splay) + radial * sin(splay)).normalized()
		var reach := lerpf(0.04, 1.0, smoothstep(0.0, 0.6, crown_open)) * grow
		var bend := lerpf(0.0, -1.1, crown_open)  # curling back at the tips
		if lash > 0.0:
			dir = dir.slerp(up, lash).normalized()
			reach = lerpf(reach, minf(lash_grow * grow, LASH_REACH_MAX), minf(lash * 3.0, 1.0))
			bend = lerpf(bend, 0.4, lash)
		var tentacle := _tentacles[t]
		tentacle.visible = crown_open > 0.02 or lash > 0.0
		var curl_axis := dir.cross(up).normalized() if absf(dir.dot(up)) < 0.98 else right
		var y := curl_axis.cross(dir).normalized()
		tentacle.transform = Transform3D(Basis(curl_axis, y, dir), root)
		var skin_t := _tentacle_skins[t]
		skin_t.set_shader_parameter("length", length * reach)
		skin_t.set_shader_parameter("curl", bend + sin(_age * 3.0 + t) * 0.15 * crown_open)


## The look that follows the bite: the crown's opening and flush, the glow, the ring on the cone's far end.
func _dress(delta: float) -> void:
	var open := jaw.opened
	crown_open = move_toward(crown_open, open, delta * 6.0)
	var lock := _lock()
	if lock != null and lock.denied_age < DENIED_TIME:
		crown_open = maxf(crown_open, 0.55 * absf(sin(lock.denied_age * 40.0)) * (1.0 - lock.denied_age / DENIED_TIME))  # a refused press: the crown flickers
	if _bite != null and is_instance_valid(_bite) and _bite.bites != _bites_seen:
		_bites_seen = _bite.bites
		lash = 1.0
		crown_open = 1.0  # snap chomp: the crown and lock-on ring flash shut on the strike (no wind-up opened them)
	lash = maxf(lash - delta / maxf(lash_time, 0.01), 0.0)
	var swim := lerpf(wave_idle, wave_swim, speed_frac)
	skin.set_shader_parameter("spine_wave", Vector4(MODEL.H * 0.01 * swim, 0.4, 2.2, 0.55))
	var warn := (0.5 + 0.5 * sin(_age * 26.0)) * 0.6 * crown_open if open > 0.05 else 0.0
	skin.set_shader_parameter("warn", warn)
	var pulse := ex.scale_of(&"throat") - 1.0  # the ring and the glow swell with the charge, burst on the release
	organs.set_shader_parameter("glow", maxf(0.6 + crown_open * 0.9 + lash * 0.6 + pulse * 0.9, 0.2))
	for material in _tentacle_skins:
		material.set_shader_parameter("flush", crown_open)
	_light.omni_range = 0.6 * fish.hitbox_length * (1.0 + maxf(pulse, 0.0) * 0.4)
	_light.light_energy = maxf(1.2 + crown_open * 3.0 + lash * 2.0 + pulse * 3.0, 0.2)
	_pose_halo()


## The bite's lock style, if it has one.
func _lock() -> LockAttack:
	if _bite == null or not is_instance_valid(_bite):
		return null
	return _bite.attack as LockAttack


## The lock-on ring: at the far end of the bite's cone, as wide as its edge there, closing in as the crown opens. In the
## lock style it moves onto the target, tightening with the charge, with the line, the count and the marks.
func _pose_halo() -> void:
	var lock := _lock()
	var at_target := lock.ring_at(lash_time) if lock != null else Vector3.INF
	var locked := at_target.is_finite()
	_pose_lock_extras(lock, locked, at_target)
	var live := (crown_open > 0.03 or lash > 0.0 or locked) and _bite != null and is_instance_valid(_bite)
	halo.visible = live
	if not live:
		return
	var forward := -fish.global_basis.z.normalized()
	var reach := _bite.reach()
	var radius := _bite.radius()
	var at := _bite.mouth_point() + forward * reach
	var size := radius * lerpf(1.6, 1.0, smoothstep(0.0, 1.0, crown_open)) * (1.0 + 0.05 * sin(_age * 9.0))
	var fade := 1.0 if lash <= 0.0 else lash
	if locked:
		var from := _bite.mouth_point()
		var line := at_target - from
		forward = line.normalized() if line.length_squared() > 0.0001 else forward
		at = at_target
		var charge := _bite.charge() if lock.active() else 1.0
		size = _bite.radius() * lerpf(0.9, 0.35, charge) * (1.0 + 0.05 * sin(_age * 9.0))
		if not lock.active() and lock.lost_age < 0.4:  # the lock snapped: the ring bursts outward and fades
			size *= 1.0 + 1.5 * lock.lost_age / 0.4
			fade = 1.0 - lock.lost_age / 0.4
	var burst := ex.scale_of(&"throat")  # the ring flares on the release and ticks in tight on the press
	size *= burst
	var up := forward.cross(fish.global_basis.x.normalized())
	if up.length_squared() < 0.0001:
		up = fish.global_basis.y.normalized()
	var across := up.cross(forward).normalized()
	halo.global_transform = Transform3D(Basis(across, forward, across.cross(forward).normalized()) * Basis.from_scale(Vector3.ONE * size), at)
	var color := Color(1.0, 0.88, 0.75).lerp(Color(1.0, 0.45, 0.1), crown_open)
	color.a = clampf(lerpf(0.2, 0.85, crown_open) * (0.75 + 0.25 * sin(_age * 10.0)) * fade * maxf(burst, 0.6), 0.0, 1.0)
	_halo_skin.albedo_color = color


## The line from the crown to the target, the "x5" by the ring and a small ring on each fish that would go with it.
func _pose_lock_extras(lock: LockAttack, locked: bool, at_target: Vector3) -> void:
	var held := lock != null and lock.active() and _bite.holding()
	beam.visible = held
	count_label.visible = held
	var want := lock.mates_at.size() if held else 0
	while _marks.size() < want and _marks.size() < MAX_MARKS:
		var mark := MeshInstance3D.new()
		mark.name = "LockMark"
		mark.mesh = halo.mesh
		mark.top_level = true
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mark)
		_marks.append(mark)
	for i in _marks.size():
		_marks[i].visible = i < want
		if i < want:
			var spot := lock.mates_at[i]
			_marks[i].global_transform = Transform3D(Basis.from_scale(Vector3.ONE * _bite.radius() * 0.14 * (1.0 + 0.2 * sin(_age * 8.0 + i))), spot)
	if not held:
		return
	var from := _bite.mouth_point()
	var line := at_target - from
	var length := line.length()
	if length > 0.01:
		var along := line / length
		var side := along.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var thick := _bite.radius() * 0.03 * (1.0 + _bite.charge())
		beam.global_transform = Transform3D(Basis(side, along, side.cross(along).normalized()) * Basis.from_scale(Vector3(thick, length, thick)), from + line * 0.5)
	_beam_skin.albedo_color = Color(1.0, 0.6, 0.25, lerpf(0.25, 0.7, _bite.charge()))
	count_label.global_position = at_target + Vector3.UP * _bite.radius() * 0.5
	count_label.text = "x%d" % lock.count_now
