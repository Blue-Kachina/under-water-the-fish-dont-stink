extends Node3D
## The Lantern Angler as a Hunter's body (planning_new_hunters.md D2). Wraps AnglerModel (D1: one spine-bent mesh, shader jaw, teeth,
## spring-chain lure stalk) and gives it an ambush swimmer's gait, driven from the fish's velocity, turn and roll, never from AI:
##   body     stiff: the trail of the head is straightened toward the fish's tailward line (angler_body_stiffness), so it
##            turns like a heavy block, with only a small slow tail sway
##   tail     `tail_bend` is the stride: a slow low sway while cruising plus a damped SPRING that rings after a lunge (the burst)
##            fired by a forward acceleration spike, a bite release or snap_tail(); alternating sides, no pop (the spring is
##            continuous in position and speed)
##   fins     pectorals scull slowly (a figure of eight: flap and sweep a quarter turn apart), big and slow when still, small and
##            swept back at speed, tucked on a burst; the turning side's fin is held out like a brake; roll tilts them
##   stalk    AnglerModel's 6-joint spring chain fed with the head's world acceleration plus the inertial push of the roll and
##            turn (alpha x r + omega x (omega x r)) at the esca, so it lags, whips and swings out in an air roll
## A child of the fish's visual (so it frees, hides and follows the bite's lift and saw with it). The body is top_level (the shader
## writes world positions), exactly like KingRig. Not a class_name: the form preloads it.

const AnglerModelScript := preload("res://scripts/what_stinks/forms/angler_model.gd")

## Settings read tolerantly (they may not be registered yet): id, default.
const DEFAULTS := {
	"angler_body_stiffness": 0.85,
	"angler_sway_deg": 9.0,
	"angler_tail_snap_deg": 40.0,
	"angler_tail_hz": 1.6,
	"angler_tail_zeta": 0.3,
	"angler_burst_accel": 9.0,
	"angler_pectoral_hz": 0.8,
	"angler_pectoral_deg": 28.0,
	"angler_stride_tail_deg": 55.0,
	"angler_stride_pop": 1.0,
	"angler_stalk_stiffness": 38.0,
	"angler_stalk_damping": 5.5,
	"angler_stalk_sway": 0.5,
	"angler_esca_light_cap": 6.0,
}

var fish: FishController
var model: AnglerModel
var rig: SpineRig
var length := 6.0
var jaw: LanternJaw
## Probe override of the stiffness (negative: the setting).
var stiffness_override := -1.0
## Frozen by a probe: tick with this delta instead of the frame's (negative: off).
var fixed_delta := -1.0
## Probes: a stride to follow instead of the fish's Extra Swishy one ({"swing": Vector2, "power", "phase", "flow" (0..1), "growth"}); empty: the fish's.
var stride_override: Dictionary = {}

## What the gait is doing now (probes read these).
var shown := {"sway": 0.0, "snap": 0.0, "tail": 0.0, "flap_l": 0.0, "flap_r": 0.0, "sweep": 0.0, "burst": 0.0, "flutter": 0.0,
	"speed_t": 0.0, "bursts": 0, "thrust": 0.0, "stride": 0.0, "stride_w": 0.0, "grow": 0.0}
## The largest per-second change of the tail, left fin and sweep since the last reset (probes: continuity).
var peak_rate := {"tail": 0.0, "flap": 0.0, "sweep": 0.0}
var _prev_tail := 99.0
var _prev_flap := 0.0
var _prev_sweep := 0.0
var _still_for := 0.0
var _hinge_open := 0.0
var _age := 0.0
var _trail := PackedVector3Array()
var _offsets := PackedVector3Array()
var _dir := Vector3.ZERO
var _last_head := Vector3.ZERO
var _last_vel := Vector3.ZERO
var _have_vel := false
var _accel := Vector3.ZERO
var _last_omega := Vector3.ZERO
var _alpha := Vector3.ZERO
var _tail_phase := 0.0
var _pect_phase := 0.0
var _sway_amp := 0.0
var _pect_amp := 0.0
var _speed_t := 0.0
var _burst := 0.0
var _burst_s := 0.0  # _burst eased (it jumps on a snap); the fin channels read this one
var _snap := 0.0
var _snap_v := 0.0
var _snap_side := 1.0
var _refractory := 0.0
var _armed := true
var _flap_l := 0.0
var _flap_r := 0.0
var _sweep := 0.0
var _flutter := 0.5
var _turn := 0.0
var _roll := 0.0
var _bite: HunterBite
var _bound: HunterBite
var _bursts := 0
## Extra Swishy: 1 while the tail is being driven by strides (the free sway steps aside), the tail's stride sweep and its ring (a spring
## chasing the stick's sweep, underdamped so it whips past), and the Battletoads swell of the tail.
var _stride_w := 0.0
var _stride_tail := 0.0
var _stride_tail_v := 0.0
var _tail_grow := 0.0


## A setting's value, or its default here while it is not registered.
static func opt(id: String) -> float:
	var got: Variant = WhatStinksSettings.shared().get(id)
	return float(got) if got != null else float(DEFAULTS[id])


func _init() -> void:
	name = "LanternRig"
	process_priority = 5  # after the fish's own physics-frame work; the bite's pose on the visual is read each frame


## Builds the body for `with_fish` at its hitbox's length now.
func build(with_fish: FishController) -> void:
	fish = with_fish
	length = fish.hitbox_length
	if not fish.strode.is_connected(_on_strode):
		fish.strode.connect(_on_strode)
	if model != null:
		model.queue_free()
	model = AnglerModelScript.new()
	model.name = "AnglerModel"
	add_child(model)
	model.build(length)
	rig = model.rig
	_apply_tuning()
	jaw = LanternJaw.new()
	jaw.rig = self
	_trail.clear()
	_offsets.clear()
	_dir = Vector3.ZERO
	_have_vel = false
	_pose(0.0)


func _apply_tuning() -> void:
	if model == null:
		return
	model.stalk_stiffness = opt("angler_stalk_stiffness")
	model.stalk_damping = opt("angler_stalk_damping")
	model.stalk_sway = opt("angler_stalk_sway")
	AnglerModel.light_cap = int(opt("angler_esca_light_cap"))


## The jaw as open as the bite says (0 shut, 1 open; 0..2.4 for the exaggeration).
func set_open(open: float) -> void:
	_hinge_open = open
	if model != null:
		model.jaw_open = open


## A lunge: the tail snaps to the alternate side with `strength` (1 = the full angler_tail_snap_deg), the pectorals tuck, the esca
## whips back. Called by the acceleration spike, the bite's release and probes.
func snap_tail(strength := 1.0) -> void:
	var w := TAU * opt("angler_tail_hz")
	_snap_v += _snap_side * clampf(strength, 0.0, 1.5) * deg_to_rad(opt("angler_tail_snap_deg")) * w * 1.1
	_snap_side = -_snap_side
	_burst = minf(_burst + 0.6 + 0.4 * clampf(strength, 0.0, 1.0), 1.0)
	_refractory = 0.45
	_bursts += 1
	if model != null and fish != null and is_instance_valid(fish):
		model.kick_stalk(fish.global_basis.z * 3.0 * strength * model.k)


## The acceleration the body feels, from the physics ticks (the frame rate does not matter), smoothed so a tick's jitter does not drive the animation.
func _physics_process(delta: float) -> void:
	if not is_instance_valid(fish) or delta <= 0.0:
		return
	var vel := fish.linear_velocity
	var omega := fish.angular_velocity
	if _have_vel:
		_accel = _accel.lerp(((vel - _last_vel) / delta).limit_length(80.0), 1.0 - exp(-delta / 0.07))
		_alpha = _alpha.lerp(((omega - _last_omega) / delta).limit_length(60.0), 1.0 - exp(-delta / 0.1))
	_last_vel = vel
	_last_omega = omega
	_have_vel = true


func _process(delta: float) -> void:
	if not is_instance_valid(fish) or model == null or not is_visible_in_tree():
		return
	if fixed_delta >= 0.0:
		delta = fixed_delta
	_pose(delta)


## The head's world point: the front of the hitbox, lifted and turned by the bite's pose on the visual.
func head_point() -> Vector3:
	var xf := fish.get_global_transform_interpolated()
	var visual: Node3D = get_parent()
	return xf * (Basis.from_euler(visual.rotation) * Vector3(0.0, 0.0, -length * 0.5))


func _pose(delta: float) -> void:
	_bind_bite()
	_age += delta
	var head := head_point()
	if not _trail.is_empty() and _trail[_trail.size() - 1].distance_to(head) > length * 0.5:
		_trail.clear()  # a respawn or a teleport: the body goes with the head
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
	_still_for = _still_for + delta if fish.linear_velocity.length() < 0.25 * maxf(length / 6.0, 0.3) else 0.0
	if _still_for > 0.8 and _trail.size() > 1:
		_trail = PackedVector3Array([head])  # at rest it forgets the way it came: the body relaxes straight (eased in _stiffen)
	var body := fish.get_global_transform_interpolated().basis
	rig.head_up = body.y  # the body rolls with the fish (an air roll), not held to the world's up
	rig.head_back = body.z
	rig.follow_trail(head, _trail, body.z)
	_stiffen(delta, head, body.z)
	rig.twist = (get_parent() as Node3D).rotation.y * 2.0
	_sense(delta, body)
	_gait(delta)
	model.update(delta, _stalk_accel(head, body))


## Acceleration comes from _physics_process (a rate independent of the frame rate). Velocity and turn, smoothed so a physics step's jitter does not drive the animation.
func _sense(delta: float, body: Basis) -> void:
	var vel := fish.linear_velocity
	var omega := fish.angular_velocity
	var local_omega := body.inverse() * omega
	_turn = lerpf(_turn, clampf(local_omega.y / 1.5, -1.0, 1.0), _rate(delta, 0.15))
	_roll = lerpf(_roll, clampf(local_omega.z / 2.5, -1.0, 1.0), _rate(delta, 0.15))
	var speed_t := clampf(vel.length() / maxf(length * 0.5, 1.0), 0.0, 1.0)
	_speed_t = lerpf(_speed_t, speed_t, _rate(delta, 0.4))


static func _rate(delta: float, tau: float) -> float:
	return 1.0 - exp(-maxf(delta, 0.0) / tau)


## What the stalk's frame feels: the head's acceleration, and the push of the body turning about the esca.
func _stalk_accel(head: Vector3, body: Basis) -> Vector3:
	var arm := model.esca_world() - head
	var omega := fish.angular_velocity
	var push := _alpha.cross(arm) + omega.cross(omega.cross(arm))
	return (_accel + (push * 0.35).limit_length(14.0)).limit_length(60.0)


func _gait(delta: float) -> void:
	var settings_sway := deg_to_rad(opt("angler_sway_deg"))
	var snap_rad := deg_to_rad(opt("angler_tail_snap_deg"))
	var forward := -fish.global_basis.z
	var thrust := _accel.dot(forward)
	_refractory = maxf(_refractory - delta, 0.0)
	var thr := opt("angler_burst_accel") * sqrt(maxf(length, 0.5) / 6.0)  # the controller's accel grows with size, slower than linearly
	# A lunge is the rising edge of the thrust (re-armed once it falls back), so a sustained boost fires once, not continuously.
	if thrust < thr * 0.6:
		_armed = true
	if delta > 0.0 and thrust > thr and _refractory <= 0.0 and _armed and _stride_w < 0.3:  # a stride's own push is not a lunge
		_armed = false
		snap_tail(clampf(0.65 + 0.35 * (thrust / thr - 1.0), 0.65, 1.0))
	# The burst envelope: quick up (set by snap_tail), a slow ease down.
	_burst = move_toward(_burst, 0.0, delta * 1.1)
	_burst_s = lerpf(_burst_s, _burst, _rate(delta, 0.12))
	# The tail's spring: rings after a lunge. Substepped for stability at any frame time.
	var w := TAU * opt("angler_tail_hz")
	var zeta := opt("angler_tail_zeta")
	var steps := clampi(int(ceil(delta / 0.008)), 1, 8)
	var h := minf(delta, 0.1) / steps
	for i in steps:
		_snap_v += (-w * w * _snap - 2.0 * zeta * w * _snap_v) * h
		_snap += _snap_v * h
	_snap = clampf(_snap, -snap_rad * 1.3, snap_rad * 1.3)
	_gait_stride(delta)
	# The cruise sway: slow, low, a little bigger at speed, easing in and out.
	var sway_target := settings_sway * lerpf(0.5, 1.0, _speed_t) * (1.0 - 0.7 * _burst)
	_sway_amp = lerpf(_sway_amp, sway_target, _rate(delta, 0.5))
	_tail_phase = fmod(_tail_phase + delta * TAU * lerpf(0.3, 1.1, _speed_t), TAU)
	var sway := sin(_tail_phase) * _sway_amp * (1.0 - _stride_w)
	var tail := clampf(sway + _snap + _stride_tail, -1.4, 1.4)
	model.tail_bend = tail
	# Pectorals: the scull.
	var pect_hz := opt("angler_pectoral_hz") * lerpf(1.0, 1.7, _speed_t)
	_pect_phase = fmod(_pect_phase + delta * TAU * pect_hz, TAU)
	var big := deg_to_rad(opt("angler_pectoral_deg"))
	var amp_target := big * lerpf(1.0, 0.35, _speed_t) * (1.0 - 0.6 * _burst_s)
	_pect_amp = lerpf(_pect_amp, amp_target, _rate(delta, 0.4))
	var flap := sin(_pect_phase) * _pect_amp
	var sweep_target := lerpf(0.12, 0.38, _speed_t) +  0.4 * _burst_s
	var sweep := lerpf(_sweep, sweep_target + 0.16 * (1.0 - _speed_t) * cos(_pect_phase), _rate(delta, 0.12))
	# The turning side's fin is held out as a brake; a roll tilts them against each other.
	var brake := 0.32
	var want_l := flap + brake * maxf(_turn, 0.0) + 0.25 * _roll
	var want_r := flap + brake * maxf(-_turn, 0.0) - 0.25 * _roll
	_flap_l = lerpf(_flap_l, want_l, _rate(delta, 0.08))
	_flap_r = lerpf(_flap_r, want_r, _rate(delta, 0.08))
	_sweep = sweep
	model.set_pectoral_sides(_flap_l, _flap_r, _sweep)
	var flutter_target := 0.35 + 0.9 * _speed_t + 0.8 * _burst_s
	_flutter = lerpf(_flutter, flutter_target, _rate(delta, 0.3))
	model.fin_flutter = _flutter
	if delta > 0.001 and _prev_tail < 90.0:
		peak_rate["tail"] = maxf(peak_rate["tail"], absf(tail - _prev_tail) / delta)
		peak_rate["flap"] = maxf(peak_rate["flap"], absf(_flap_l - _prev_flap) / delta)
		peak_rate["sweep"] = maxf(peak_rate["sweep"], absf(_sweep - _prev_sweep) / delta)
	_prev_tail = tail
	_prev_flap = _flap_l
	_prev_sweep = _sweep
	shown = {"sway": sway, "snap": _snap, "tail": tail, "flap_l": _flap_l, "flap_r": _flap_r, "sweep": _sweep, "burst": _burst,
		"flutter": _flutter, "speed_t": _speed_t, "bursts": _bursts, "thrust": thrust, "dt": delta, "age": _age,
		"stride": _stride_tail, "stride_w": _stride_w, "grow": _tail_grow}


## The Extra Swishy stride the fish is in, for the tail to follow: {"swing" (the tail's place in the stick's terms), "power", "phase" (s,
## negative: none), "flow" (0..1), "growth" (the fish's stride_tail_growth)}; empty when the fish is not striding.
func _stride_info() -> Dictionary:
	if not stride_override.is_empty():
		return stride_override
	if fish.swim_style != FishController.SwimStyle.EXTRA_SWISHY or not fish.swim_strokes or fish.swishy == null:
		return {}
	var sw: SwishySwim = fish.swishy
	return {"swing": sw.tail_swing, "power": sw.power, "phase": sw.phase, "flow": sw.flow / maxf(fish.stride_flow_max, 0.01),
		"growth": fish.stride_tail_growth}


static func _master() -> float:
	var got: Variant = WhatStinksSettings.shared().get("hunter_exaggeration")
	return float(got) if got != null else 1.0


## Extra Swishy: the tail rides the player's strides. It sweeps across to the side opposite each push (the stick's sweep), arriving at the
## stride's peak, on an underdamped spring so it whips past the sweep and rings; the free sway steps aside while it does. The tail also
## swells with flow, as every fish's does (Battletoads style), the caudal fan with it.
func _gait_stride(delta: float) -> void:
	var st := _stride_info()
	var pop := opt("angler_stride_pop") * _master()
	var goal := 0.0
	var grow_goal := 0.0
	var w_goal := 0.0
	if not st.is_empty():
		var swing: Vector2 = st["swing"]
		var lateral := swing.x if absf(swing.x) >= absf(swing.y) else swing.y
		goal = lateral * deg_to_rad(opt("angler_stride_tail_deg"))
		grow_goal = ((1.0 + float(st["growth"]) * float(st["flow"])) * (1.0 + 0.2 * float(st["power"])) - 1.0) * 0.75 * pop
		if float(st["phase"]) >= 0.0 or swing.length() > 0.03:
			w_goal = 1.0
	_stride_w = lerpf(_stride_w, w_goal, _rate(delta, 0.06 if w_goal > _stride_w else 0.3))
	var omega := TAU * 4.2
	var zeta := lerpf(0.85, 0.32, clampf(pop, 0.0, 1.0))
	var sub := clampi(int(ceil(delta / 0.008)), 1, 8)
	var h := minf(delta, 0.1) / sub
	for i in sub:
		_stride_tail_v += (-omega * omega * (_stride_tail - goal) - 2.0 * zeta * omega * _stride_tail_v) * h
		_stride_tail += _stride_tail_v * h
	_tail_grow = lerpf(_tail_grow, grow_goal, _rate(delta, 0.08))
	model.tail_grow = _tail_grow


## Each stride's input: the tail is flicked toward the side it is about to sweep to (so it whips past the sweep), the pectorals tuck and
## the esca whips, like a lunge in miniature.
func _on_strode(_timing: float, _flow: float) -> void:
	if model == null:
		return
	var pop := opt("angler_stride_pop") * _master()
	var side := -signf(_stride_tail) if absf(_stride_tail) > 0.05 else _snap_side
	_snap_side = -side
	_stride_tail_v += side * pop * deg_to_rad(opt("angler_stride_tail_deg")) * 9.0
	_burst = minf(_burst + 0.4 * clampf(pop, 0.0, 1.0), 1.0)
	if is_instance_valid(fish):
		model.kick_stalk(fish.global_basis.z * 2.2 * clampf(pop, 0.0, 1.5) * model.k)


func _exit_tree() -> void:
	if is_instance_valid(fish) and fish.strode.is_connected(_on_strode):
		fish.strode.disconnect(_on_strode)


func _bind_bite() -> void:
	var found := fish.get_node_or_null("HunterBite") as HunterBite
	if found == _bound:
		return
	_bound = found
	_bite = found
	if found != null and not found.released.is_connected(_on_released):
		found.released.connect(_on_released)


func _on_released(charge: float) -> void:
	snap_tail(clampf(0.5 + 0.5 * charge, 0.5, 1.0))


## body_stiffness: 0 floppy, 1 a rigid bar.
func _stiffness() -> float:
	if stiffness_override >= 0.0:
		return clampf(stiffness_override, 0.0, 1.0)
	return clampf(opt("angler_body_stiffness"), 0.0, 1.0)


## Stiffens the bend the trail made: each spine point is drawn toward the straight line tailward from the head (more so down the
## body), re-spaced to the segment length, then eased in time so the body trails the head in a stiff, calm curve (KingRig's way).
func _stiffen(delta: float, head: Vector3, back: Vector3) -> void:
	var stiff := _stiffness()
	if _last_head.distance_to(head) > rig.length * 0.5:
		_offsets.clear()  # a respawn or a teleport: no easing across it
		_dir = Vector3.ZERO
	_last_head = head
	if stiff <= 0.001:
		_offsets.clear()
		_dir = Vector3.ZERO
		rig.call("_frames")
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
		# The globe skull and shoulders are rigid (the straight line); the tail half lets the trail bend it while it swims, and relaxes straight at rest.
		var pull := (1.0 - (1.0 - stiff) * (1.0 - stiff)) * 0.97 * (1.0 - 0.45 * smoothstep(0.4, 0.85, along) * clampf(_speed_t * 3.0, 0.0, 1.0))
		var want: Vector3 = raw[s].lerp(straight, pull)
		var off: Vector3 = _offsets[s].lerp(want - straight, k)
		_offsets[s] = off
		curve[s] = straight + off
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
	# A few 1-2-1 passes round the tail half take the corners a tight loop leaves in the trail out of it.
	for _pass in 3:
		var prev: Vector3 = rig.points[5]
		for s in range(6, n - 1):
			var here: Vector3 = rig.points[s]
			rig.points[s] = prev * 0.25 + here * 0.5 + rig.points[s + 1] * 0.25
			prev = here
	rig.call("_frames")


## The Lantern Angler's mouth for HunterBite: the lower jaw is part of the one spine-bent mesh, hinged by the shader, so pose(open)
## only turns that. `ex` is the exaggeration kit (set by the form if it has one): the gape swells past 1 with the charge.
class LanternJaw extends HunterJaw:
	var rig: Node3D  # lantern_rig.gd
	var ex: AttackExaggerate
	var gape_mult := 1.0
	var _shown_open := -1.0
	var _shown_angle := -999.0

	## Where prey are taken, in the model's space (the fish's visual): between the jaws about a metre behind the snout.
	func mouth_local() -> Vector3:
		if rig == null or not is_instance_valid(rig.fish) or rig.model == null:
			return Vector3.ZERO
		var rest: Vector3 = rig.model.mouth_rest()
		var at := Vector3(rest.x, rest.y, -rig.fish.hitbox_length * 0.5 + rest.z)
		var visual: Node3D = rig.get_parent()
		var s := visual.scale
		return Vector3(at.x / s.x, at.y / s.y, at.z / s.z)

	func pose(open: float) -> void:
		_shown_open = open
		refresh()

	## Re-applies the last pose (the kit rings the gape out between the bite's ticks).
	func refresh() -> void:
		if rig == null or _shown_open < 0.0:
			return
		var angle := (_shown_open + overshoot) * gape_mult * (ex.scale_of(&"jaw") if ex != null else 1.0)
		if is_equal_approx(angle, _shown_angle):
			return
		_shown_angle = angle
		rig.set_open(angle)
