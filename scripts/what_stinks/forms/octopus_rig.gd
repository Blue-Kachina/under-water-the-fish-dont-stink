class_name OctopusRig
extends Node3D
## The Ember Octopus as a Hunter's body (planning_new_hunters.md C2): wraps OctopusModel (C1) and gives it a gait, driven from the
## fish's velocity, throttle, stick, roll and the floor under it, never from AI. HYBRID design:
##   arms     8 chains of 14 bones. Each segment is a unit DIRECTION (model frame) on its own spring, with follow-the-leader lag (a
##            segment's offset from its target is passed on to the next), converted into the model's (pitch, yaw, twist) bends through the
##            rest bases (shortest arc from the rest direction: the twist is a pure function of the direction, so it cannot pop).
##            An FK travelling wave is added to the directions. The state is counter-rotated by the body's own rotation (inertia), so
##            arms swing wide in a turn and trail in an air roll; flow drag bends the tips back; a slack arm drapes with the water.
##   swim     the mantle leads (-Z) and the arms trail behind in a flat swept-back delta (the model's rest pose), the web between
##            their bases the wing (planning_hunter_refine.md: the video's motion, the photo's shape).
##   jet      a cycle driven by the throttle: POWER (the mantle squeezes, the delta narrows a little, the siphon under the head jets back
##            between the arms: an impulse along the siphon's vector with its torque about the centre, and a wave starts down the arms)
##            then RECOVERY (the mantle refills past rest, the delta re-spreads slightly and relaxes). Never a crown opening ahead.
##            The jet's thrust is applied in the fish's physics tick, so it is real: the siphon's aim (the stick) turns the fish and
##            asymmetric arm spread is a drag torque. Dash (boost) bundles the arms tight and pulses faster and harder.
##   scull    a gentle travelling undulation down the trailing arms at cruise; turns and rolls bank the delta like a wing.
##   crawl    near a surface: the arms facing it plant their tips (ray cast), alternating, body gliding over: foot positions are world
##            fixed while planted (no slip), swing along an arc, and are solved with FABRIK into the same direction targets, blended in by
##            distance with a rate limited weight (no pops).
## A child of the fish's visual (so it frees, hides and follows the bite pose with it). Not tied to the Lash attack: C3 takes arms over
## through `override_dirs` / `override_w` (and `charge`, `glow` for the shader).
## Probe use: `step(delta, ctx)` runs the whole thing on a bare rig (no fish): see `Ctx` keys below.

signal jet_fired(strength: float)
signal foot_planted(arm: int, at: Vector3)

const ARMS := 8
const SEGS := 14
## The model's siphon rests pointing back and a little down; the jet is trimmed level so thrust does not lift it (rad).
const SIPHON_TRIM := 0.2
## Settings are read tolerantly (they may not be registered yet): id -> default.
const DEFAULTS := {
	"octopus_jet_period": 1.1,
	"octopus_jet_power": 0.3,
	"octopus_jet_accel": 14.0,
	"octopus_dash_mult": 1.8,
	"octopus_jet_vector": 0.6,
	"octopus_jet_torque": 0.5,
	"octopus_flare_torque": 0.5,
	"octopus_arm_lag": 0.55,
	"octopus_arm_stiffness": 26.0,
	"octopus_arm_damping": 0.8,
	"octopus_inertia": 0.9,
	"octopus_drag_bend": 0.8,
	"octopus_scull_amp": 1.0,
	"octopus_scull_hz": 1.3,
	"octopus_idle_sway": 1.0,
	"octopus_droop": 0.35,
	"octopus_tip_curl": 0.3,
	"octopus_jet_narrow": 0.45,
	"octopus_jet_respread": 0.35,
	"octopus_jet_wave": 0.22,
	"octopus_bank": 0.45,
	"octopus_stride_sync": 1.0,
	"octopus_stride_pop": 1.0,
	"octopus_speed_tuck": 0.6,
	"octopus_crawl_range": 0.8,
	"octopus_crawl_step_time": 0.42,
	"octopus_crawl_step_len": 0.3,
	"octopus_crawl_lift": 0.4,
	"octopus_crawl_height": 0.3,
	"octopus_crawl_pull": 2.5,
	"octopus_crawl_blend_rate": 2.5,
	"octopus_glow": 1.0,
	"octopus_sucker_hi_range": 3.0,
	"octopus_sucker_range": 7.0,
}

var fish: FishController
var model: OctopusModel
var length := 6.0
## For probes: tick/step with this delta instead of the frame's (negative: off).
var fixed_delta := -1.0
## Scales the jet's thrust and torque (probes, tuning, a stunned octopus).
var thrust_scale := 1.0
## Running total of the velocity the jets have added (m/s, world), for probes.
var thrust_applied := Vector3.ZERO
## The Lash attack (C3) takes arms over here: per arm a PackedVector3Array of SEGS unit directions in the model's frame (empty: none),
## and how much of it (0..1, eased by the caller). Springs still smooth it.
var override_dirs: Array[PackedVector3Array] = []
var override_w := PackedFloat32Array()
## The Lash attack's charge (0..1) and an extra glow: straight to the shader.
var charge := 0.0
var glow_extra := 0.0
## The Tendril Lash (WhipAttack) that poses arms over the gait: set by its attach_model. Its blend_pose runs after every frame's gait.
var lash: Object
## How a gait step reads the floor: Callable(from: Vector3, to: Vector3) -> Dictionary({} for none, else {"pos", "normal"}); null: the physics world.
var floor_query := Callable()
## Probes: a stride to follow instead of the fish's Extra Swishy one ({"phase" (s, negative: none), "power", "peak", "fade", "strides"}); empty: the fish's.
var stride_override: Dictionary = {}

## What the gait is doing now (probes, HUD and audio read these).
var shown := {
	"jet_env": 0.0, "mantle": 0.0, "spread": 0.0, "crawl": 0.0, "scull": 0.0, "speed_t": 0.0, "jets": 0, "steps": 0,
	"jet_t": -1.0, "dash": false, "height": -1.0,
}
## Stride-style outputs, so the HUD and audio hooks that read a stride see the same thing: 0..1 through the pulse (-1: none), its push.
var stride_phase := -1.0
var stride_power := 0.0

# ---- gait state (physics side)
var _jet_t := -1.0
var _jet_amp := 1.0
var _jet_dash := false
var _thrust_env := 0.0
var _mantle_raw := 0.0
var _spread_raw := 0.0
var _vein_t := -1.0
var _jets := 0
var _throttle := 0.0
var _boost := false
var _stick := Vector2.ZERO
var _roll_in := 0.0
var _air_roll := false
var _roll_flare := 0.0
var _vel := Vector3.ZERO
var _phys_driven := false
var _last_stride_count := -1
var _last_stride_phase := -1.0
## Whether the current jet is a stride's (it follows the stride's own clock) rather than the free-running beat.
var _jet_stride := false
## The stride's Battletoads pop: a ringing spring on the mantle's swell (visual side), kicked by the physics side on each stride's input.
var _pop := 0.0
var _pop_v := 0.0
var _pop_impulse := 0.0
# ---- floor and feet
var _floor_hit := false
var _floor_pos := Vector3.ZERO
var _floor_n := Vector3.UP
var _floor_dist := 99.0
var _feet_plant: Array[Vector3] = []   # world; the planted position
var _feet_from: Array[Vector3] = []
var _feet_to: Array[Vector3] = []
var _feet_t := PackedFloat32Array()    # swing progress 0..1, <0 planted
var _feet_dur := PackedFloat32Array()
var _feet_ok := PackedFloat32Array()   # 0..1 how well the arm can stand on the floor now
var _feet_init := false
var _crawl_w := 0.0
var _steps := 0
var _phys_dt := 1.0 / 60.0
var _torque := Vector3.ZERO  # local, from asymmetric flare (physics tick applies it)
# ---- visual state
var _age := 0.0
var _speed_t := 0.0
var _scull_w := 0.0
var _scull_phase := 0.0
var _mantle := 0.0
var _mantle_v := 0.0
var _spread := 0.0
var _spread_v := 0.0
var _siphon := Vector2.ZERO
var _mbend := Vector2.ZERO
var _mbend_v := Vector2.ZERO
var _last_basis := Basis.IDENTITY
var _have_basis := false
var _flow_dir := Vector3.BACK
var _up_local := Vector3.UP
var _omega_local := Vector3.ZERO
var _turn_flare := Vector2.ZERO
var _dirs: Array[PackedVector3Array] = []     # spring state, model frame
var _vels: Array[PackedVector3Array] = []
var _rest_dirs: Array[PackedVector3Array] = []
var _bundle_dirs: Array[PackedVector3Array] = []
var _flare_dirs: Array[PackedVector3Array] = []
var _rest_gb: Array = []   # per arm Array[Basis]: global rest basis per bone
var _rest_lb: Array = []   # per arm Array[Basis]: local rest basis per bone
var _head_gb := Basis.IDENTITY
var _rest_pts: Array[PackedVector3Array] = []
var _seg_len: Array[PackedFloat32Array] = []
var _crawl_dirs: Array[PackedVector3Array] = []
var _tips_model: Array[Vector3] = []
var _front_z := 0.0
var _crown_local := Vector3.ZERO  # the arm bases' centre, model space (the crawl stands round it)
var _wave_age := 99.0  # seconds since the last jet started its wave down the arms


## A setting's value, or its default here while it is not registered.
static func opt(id: String) -> float:
	var got: Variant = WhatStinksSettings.shared().get(id)
	return float(got) if got != null else float(DEFAULTS[id])


func _init() -> void:
	name = "OctopusRig"
	process_priority = 5


## Builds the body for `with_fish` at its hitbox's length now.
func build(with_fish: FishController) -> void:
	fish = with_fish
	length = fish.hitbox_length
	_phys_driven = true
	build_model(length)
	if not fish.physics_tick.is_connected(_on_physics_tick):
		fish.physics_tick.connect(_on_physics_tick)


## Builds just the model and the solver tables (probes: no fish).
func build_model(length_m: float) -> void:
	length = length_m
	if model != null:
		model.queue_free()
	model = OctopusModel.build(length_m)
	add_child(model)
	_init_tables()
	apply_settings()
	_pose_rest()
	settle()
	position = Vector3(0.0, 0.0, -length * 0.5 - _front_z)
	scale = Vector3.ONE
	_sync_scale()
	_pose_rest()


func _exit_tree() -> void:
	if is_instance_valid(fish) and fish.physics_tick.is_connected(_on_physics_tick):
		fish.physics_tick.disconnect(_on_physics_tick)


## Pushes the LOD and glow settings to the model.
func apply_settings() -> void:
	if model == null:
		return
	model.sucker_hi_range_lengths = opt("octopus_sucker_hi_range")
	model.sucker_range_lengths = opt("octopus_sucker_range")
	model.set_glow(opt("octopus_glow"))


func _init_tables() -> void:
	_dirs.clear()
	_vels.clear()
	_rest_dirs.clear()
	_bundle_dirs.clear()
	_flare_dirs.clear()
	_rest_gb.clear()
	_rest_lb.clear()
	_rest_pts.clear()
	_seg_len.clear()
	_crawl_dirs.clear()
	_tips_model.clear()
	override_dirs.clear()
	override_w = PackedFloat32Array()
	override_w.resize(ARMS)
	_head_gb = model.skeleton.get_bone_global_rest(model.head_bone).basis.orthonormalized()
	_front_z = model.mantle_tip_local().z  # the mantle leads: the model's front
	_crown_local = Vector3.ZERO
	for a in ARMS:
		var rest := PackedVector3Array()
		var bundle := PackedVector3Array()
		var flare := PackedVector3Array()
		var gbs: Array[Basis] = []
		var lbs: Array[Basis] = []
		var lens := PackedFloat32Array()
		var pts := model.arm_rest_joints(a)
		var radial := OctopusModel.arm_radial(a)
		var tang := Vector3(-radial.y, radial.x, 0.0)
		for j in SEGS:
			var idx: int = model.arm_bones[a][j]
			var gb: Basis = model.skeleton.get_bone_global_rest(idx).basis.orthonormalized()
			var lb: Basis = model.skeleton.get_bone_rest(idx).basis.orthonormalized()
			gbs.append(gb)
			lbs.append(lb)
			var d := (-gb.z).normalized()
			rest.append(d)
			var s := float(j) / float(SEGS - 1)
			# bundled tight behind (a dash): streamlined along +Z, converging a touch, a slow spiral so the arms wrap rather than clump
			var b := Vector3(0.0, 0.0, 1.0) - Vector3(radial.x, radial.y * 0.5, 0.0) * (0.07 * s) + tang * 0.03 * s
			bundle.append(b.normalized())
			# spread: the delta widens in its own plane (sideways, hardly up or down); never forward
			flare.append((d + Vector3(radial.x, radial.y * 0.2, 0.0) * 0.5).normalized())
			lens.append(pts[j].distance_to(pts[j + 1]))
		_rest_dirs.append(rest)
		_bundle_dirs.append(bundle)
		_flare_dirs.append(flare)
		_rest_gb.append(gbs)
		_rest_lb.append(lbs)
		_rest_pts.append(pts)
		_seg_len.append(lens)
		_dirs.append(rest.duplicate())
		var zeros := PackedVector3Array()
		zeros.resize(SEGS)
		_vels.append(zeros)
		_crawl_dirs.append(rest.duplicate())
		override_dirs.append(PackedVector3Array())
		_tips_model.append(pts[SEGS])
		for p in pts:
			_front_z = minf(_front_z, p.z)
		_crown_local += pts[0] / float(ARMS)
	_feet_plant.clear()
	_feet_from.clear()
	_feet_to.clear()
	_feet_t = PackedFloat32Array()
	_feet_dur = PackedFloat32Array()
	_feet_ok = PackedFloat32Array()
	for a in ARMS:
		_feet_plant.append(Vector3.ZERO)
		_feet_from.append(Vector3.ZERO)
		_feet_to.append(Vector3.ZERO)
		_feet_t.append(-1.0)
		_feet_dur.append(0.4)
		_feet_ok.append(0.0)
	_feet_init = false
	_have_basis = false
	_jet_t = -1.0
	_crawl_w = 0.0
	_mantle = 0.0
	_spread = 0.0


func _pose_rest() -> void:
	if model == null:
		return
	_apply_dirs(_dirs, 0.0)
	model.set_mantle_pulse(0.0)


# ===================================================================== physics side

func _on_physics_tick(state: PhysicsDirectBodyState3D) -> void:
	if fish == null or not is_instance_valid(fish) or fish.puppet or model == null:
		return
	_phys_dt = state.step
	_read_fish_inputs()
	var gb := model.global_basis.orthonormalized()
	var speed_ref := maxf(fish.max_speed, 1.0)
	tick(state.step, state.linear_velocity, gb)
	var thrust := thrust_dv(state.step, gb)
	if thrust != Vector3.ZERO:
		state.linear_velocity += thrust
		thrust_applied += thrust
		var mouth := model.global_transform * model.siphon_mouth_local()
		var r := mouth - fish.global_position
		var k := opt("octopus_jet_torque") / maxf(length * length * 0.09, 0.01)
		state.angular_velocity += r.cross(thrust) * k
	_crawl_assist(state)
	if _torque != Vector3.ZERO:
		var speed := minf(state.linear_velocity.length() / speed_ref, 1.5)
		state.angular_velocity += gb * (_torque * speed * opt("octopus_flare_torque") * state.step * 3.0)


## Settling toward a crawling height: with the crawl in and no throttle held, the body eases (never snaps) to a set height over the
## floor, so the arms spread out on it instead of the octopus hovering on stilts. Any throttle or a boost lets go of it.
func _crawl_assist(state: PhysicsDirectBodyState3D) -> void:
	var h := opt("octopus_crawl_height") * length
	var pull := opt("octopus_crawl_pull")
	if h <= 0.0 or pull <= 0.0 or not _floor_hit or _crawl_w < 0.3 or absf(_throttle) > 0.15 or _boost:
		return
	var n := _floor_n
	var err := h - _floor_dist
	var want := clampf(err * pull * 0.5, -length * 0.25, length * 0.25) * clampf((_crawl_w - 0.3) / 0.7, 0.0, 1.0)
	var vn := state.linear_velocity.dot(n)
	state.linear_velocity += n * ((want - vn) * minf(state.step * pull, 1.0))


func _read_fish_inputs() -> void:
	_throttle = fish.input_forward - fish.input_reverse
	_boost = fish.is_boosting
	_stick = fish.input_stick
	_roll_in = fish.input_roll
	_air_roll = fish.air_roll_held


## The physics side of the gait for one tick: the jet clock, the floor probe and the feet. `vel` is the world velocity, `gb` the
## model's world basis. Safe to call from a probe with no fish.
func tick(dt: float, vel: Vector3, gb: Basis) -> void:
	_vel = vel
	_phys_dt = dt
	_tick_jet(dt, vel, gb)
	_tick_floor(dt, vel, gb)


## The velocity change this tick's jet gives, in world space (zero outside a power stroke). Along minus the siphon's exhaust.
func thrust_dv(dt: float, gb: Basis) -> Vector3:
	if _thrust_env <= 0.0001 or model == null:
		return Vector3.ZERO
	var accel := thrust_scale * opt("octopus_jet_accel") * _thrust_env * _jet_amp * (opt("octopus_dash_mult") if _jet_dash else 1.0)
	var exhaust := gb * model.siphon_exhaust_dir()
	return -exhaust * accel * dt


func _tick_jet(dt: float, vel: Vector3, gb: Basis) -> void:
	var forward := -gb.z
	var want := absf(_throttle) > 0.15 or _boost
	var period := opt("octopus_jet_period")
	var speed_t := clampf(vel.length() / maxf(length * 1.6, 3.0), 0.0, 1.0)
	period *= lerpf(1.0, 0.8, speed_t) * (0.62 if _boost else 1.0)
	# Extra Swishy: once the player strides, each stride is a jet on its own clock, so the mantle swells on the input instead of on the
	# free-running beat (which only runs between strides and when the setting is off)
	var st: Dictionary = _stride_info() if opt("octopus_stride_sync") > 0.5 else {}
	var stride_on := not st.is_empty() and float(st["phase"]) >= 0.0
	if not st.is_empty():
		var count := int(st["strides"])
		var phase := float(st["phase"])
		if stride_on and (_last_stride_phase < 0.0 or phase < _last_stride_phase - 0.0001 or count != _last_stride_count):
			_begin_jet(vel, forward)
			_jet_t = 0.0
			_pop_impulse += opt("octopus_stride_pop")
		_last_stride_phase = phase
		_last_stride_count = count
	else:
		_last_stride_phase = -1.0
	if stride_on:
		_jet_stride = true
		_stride_shape(st)
		return
	if _jet_stride:
		_jet_stride = false
		_jet_t = -1.0  # the stride ran out: the free-running beat starts afresh if the throttle is still held
	if _jet_t < 0.0:
		if want:
			_begin_jet(vel, forward)
	else:
		_jet_t += dt
		if _jet_t >= period:
			if want:
				_jet_t = fmod(_jet_t, period)
				_begin_jet(vel, forward)
			else:
				_jet_t = -1.0
	if _jet_t < 0.0:
		_thrust_env = 0.0
		_mantle_raw = 0.0
		_spread_raw = 0.0
		_vein_t = -1.0
		stride_phase = -1.0
		stride_power = 0.0
		return
	var u := clampf(_jet_t / period, 0.0, 1.0)
	var p0 := clampf(opt("octopus_jet_power"), 0.08, 0.8)
	var m := 0.0
	var s := 0.0
	var env := 0.0
	# the delta narrows a little on the power stroke and re-spreads a little on the recovery (a dash bundles it tight throughout)
	var narrow := opt("octopus_jet_narrow")
	var respread := opt("octopus_jet_respread")
	if u < p0:
		var x := u / p0
		m = sin(x * PI * 0.5)
		s = -narrow * smoothstep(0.0, 0.7, x)
		if _jet_dash:
			s = -lerpf(0.35, 1.0, smoothstep(0.0, 0.7, x))  # carries on from the last dash stroke
		env = sin(x * PI)
	else:
		var r := (u - p0) / (1.0 - p0)
		m = 1.0 - 1.35 * smoothstep(0.0, 0.35, r) if r < 0.35 else -0.35 * (1.0 - smoothstep(0.0, 1.0, (r - 0.35) / 0.65))
		s = -narrow + (narrow + respread) * smoothstep(0.0, 0.55, r) if r < 0.55 else lerpf(respread, 0.0, smoothstep(0.0, 1.0, (r - 0.55) / 0.45))
		if _jet_dash:
			s = lerpf(-1.0, -0.35, smoothstep(0.0, 1.0, r))  # a dash keeps the arms bundled the whole stroke
	_mantle_raw = m * clampf(_jet_amp, 0.0, 1.0)
	_spread_raw = s
	_thrust_env = env
	_vein_t = (_jet_t / 0.35) * 1.1 if _jet_t < 0.35 else -1.0
	stride_phase = u
	stride_power = env * _jet_amp


## The Extra Swishy stride the fish is in, for the jet to follow: {"phase" (s since it began, negative: none), "power", "peak", "fade",
## "strides"}; empty when the fish is not striding.
func _stride_info() -> Dictionary:
	if not stride_override.is_empty():
		return stride_override
	if fish == null or not is_instance_valid(fish) or fish.swim_style != FishController.SwimStyle.EXTRA_SWISHY or not fish.swim_strokes:
		return {}
	var sw: SwishySwim = fish.swishy
	if sw == null:
		return {}
	return {"phase": sw.phase, "power": sw.power, "peak": sw.peak_time(), "fade": sw.fade_time(), "strides": sw.strides}


## One stride as a jet, on the stride's own clock (its build to the peak, then its fade). On the input the mantle swells at once and the
## arms flare (the expansion); as the push builds to its peak the mantle squeezes and the delta bundles (the jet); then it refills and
## relaxes through the fade. The next stride cuts this off and starts it again.
func _stride_shape(st: Dictionary) -> void:
	var phase := float(st["phase"])
	var peak := maxf(float(st["peak"]), 0.05)
	var fade := maxf(float(st["fade"]), 0.05)
	var narrow := opt("octopus_jet_narrow")
	var respread := opt("octopus_jet_respread")
	var flare := clampf(0.55 * opt("octopus_stride_pop"), 0.0, 1.0)
	var inhale := peak * 0.22
	var m := 0.0
	var s := 0.0
	var env := 0.0
	var squeezed := -1.0 if _jet_dash else -narrow  # where the squeeze leaves the delta
	_jet_t = phase
	if phase < inhale:
		var x := phase / inhale
		m = -sin(x * PI * 0.5)
		s = flare * sin(x * PI * 0.5)
	elif phase < peak:
		var e := smoothstep(0.0, 1.0, (phase - inhale) / maxf(peak - inhale, 0.001))
		m = lerpf(-1.0, 1.0, e)
		s = lerpf(flare, squeezed, e)
		env = e
	else:
		var r := clampf((phase - peak) / fade, 0.0, 1.0)
		m = 1.0 - 1.35 * smoothstep(0.0, 0.35, r) if r < 0.35 else -0.35 * (1.0 - smoothstep(0.0, 1.0, (r - 0.35) / 0.65))
		if _jet_dash:
			s = lerpf(-1.0, -0.35, smoothstep(0.0, 1.0, r))
		else:
			s = -narrow + (narrow + respread) * smoothstep(0.0, 0.55, r) if r < 0.55 else lerpf(respread, 0.0, smoothstep(0.0, 1.0, (r - 0.55) / 0.45))
		env = 1.0 - smoothstep(0.0, 0.5, r)
	_mantle_raw = m * clampf(_jet_amp, 0.0, 1.0)
	_spread_raw = s
	_thrust_env = env
	_vein_t = (phase / 0.35) * 1.1 if phase < 0.35 else -1.0
	stride_phase = clampf(phase / (peak + fade), 0.0, 1.0)
	stride_power = env * _jet_amp


func _begin_jet(_vel_now: Vector3, _forward: Vector3) -> void:
	_jet_dash = _boost
	_jet_amp = lerpf(0.5, 1.0, clampf(absf(_throttle), 0.0, 1.0))
	if _throttle < -0.15:
		_jet_amp *= 0.5
	if _jet_t < 0.0:
		_jet_t = 0.0
	_wave_age = 0.0
	_jets += 1
	jet_fired.emit(_jet_amp)


func _tick_floor(dt: float, vel: Vector3, gb: Basis) -> void:
	var range_m := opt("octopus_crawl_range") * length
	_floor_hit = false
	if range_m <= 0.0 or model == null:
		_crawl_w = move_toward(_crawl_w, 0.0, dt * opt("octopus_crawl_blend_rate"))
		return
	var from := model.global_position
	var hit := _ray(from, from + Vector3.DOWN * range_m * 1.6)
	if not hit.is_empty():
		_floor_hit = true
		_floor_pos = hit["pos"]
		_floor_n = (hit["normal"] as Vector3).normalized()
		_floor_dist = (from - _floor_pos).dot(_floor_n)
	else:
		_floor_dist = 99.0
	var speed_t := clampf(vel.length() / maxf(length * 1.6, 3.0), 0.0, 1.0)
	var want := 0.0
	if _floor_hit:
		want = (1.0 - smoothstep(range_m * 0.55, range_m, _floor_dist)) * (1.0 - smoothstep(0.35, 0.75, speed_t))
		want *= 1.0 - smoothstep(0.3, 0.7, _jet_env_now())
	_crawl_w = move_toward(_crawl_w, want, dt * opt("octopus_crawl_blend_rate") * (1.0 if want > _crawl_w else 1.6))
	if _crawl_w > 0.001 and _floor_hit:
		_tick_feet(dt, vel, gb)
	else:
		_feet_init = false


func _jet_env_now() -> float:
	return _thrust_env if _jet_t >= 0.0 else 0.0


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if floor_query.is_valid():
		return floor_query.call(from, to) as Dictionary
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if fish != null and is_instance_valid(fish):
		query.exclude = [fish.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit["collider"] is RigidBody3D:
		return {}  # other fish are not floor
	return {"pos": hit["position"], "normal": hit["normal"]}


## Whether arm `a` can stand on the floor from where the model is, and where its foot belongs (world).
func _home(a: int, gb: Basis) -> Dictionary:
	var n := _floor_n
	var radial := gb * OctopusModel.arm_radial(a)
	var out_t := (radial - n * radial.dot(n))
	var fwd := -gb.z
	var fwd_t := (fwd - n * fwd.dot(n))
	fwd_t = fwd_t.normalized() if fwd_t.length() > 0.05 else Vector3.ZERO
	var reach := model.arm_length(a)
	var on_floor_side := -radial.dot(n)   # 1: radial straight down
	# the arms stand round the crown (behind the head; the mantle leads), spread out and a little back
	var crown := model.global_transform * _crown_local
	var under := crown - n * ((crown - _floor_pos).dot(n))
	var spread := out_t.limit_length(1.0)
	var home := under + spread * reach * 0.5 - fwd_t * reach * 0.2
	var hit := _ray(home + n * reach * 0.7, home - n * reach * 1.1)
	if not hit.is_empty():
		home = hit["pos"]
	else:
		home = home - n * ((home - _floor_pos).dot(n))
	var dist := (model.global_transform * _rest_pts[a][0]).distance_to(home)
	# arms facing away from the floor do not stand on it; ones that cannot reach it do not either
	var ok := smoothstep(-0.45, 0.15, on_floor_side + 0.35) * (1.0 - smoothstep(0.82, 1.0, dist / maxf(reach, 0.01)))
	return {"home": home, "ok": ok}


func _tick_feet(dt: float, vel: Vector3, gb: Basis) -> void:
	var swinging := 0
	var homes: Array[Dictionary] = []
	for a in ARMS:
		homes.append(_home(a, gb))
		if _feet_t[a] >= 0.0:
			swinging += 1
	if not _feet_init:
		for a in ARMS:
			_feet_plant[a] = homes[a]["home"]
			_feet_t[a] = -1.0
		_feet_init = true
		swinging = 0
	var step_time := opt("octopus_crawl_step_time") / (1.0 + clampf(vel.length() / maxf(length, 1.0), 0.0, 3.0))
	var step_len := opt("octopus_crawl_step_len")
	var order: Array[int] = []
	for a in ARMS:
		order.append(a)
	# the arm farthest from its home goes first
	order.sort_custom(func(x: int, y: int) -> bool:
		return _foot_error(x, homes[x]["home"]) > _foot_error(y, homes[y]["home"]))
	for a in ARMS:
		_feet_ok[a] = move_toward(_feet_ok[a], homes[a]["ok"], dt * 4.0)
		if _feet_t[a] >= 0.0:
			_feet_t[a] += dt / maxf(_feet_dur[a], 0.05)
			if _feet_t[a] >= 1.0:
				_feet_t[a] = -1.0
				_feet_plant[a] = _feet_to[a]
				_steps += 1
				foot_planted.emit(a, _feet_plant[a])
	var max_swing := 3
	swinging = 0
	for a in ARMS:
		if _feet_t[a] >= 0.0:
			swinging += 1
	for a: int in order:
		if swinging >= max_swing or _feet_t[a] >= 0.0:
			continue
		var reach := model.arm_length(a)
		var home: Vector3 = homes[a]["home"]
		var err := _foot_error(a, home)
		var base_w := model.global_transform * _rest_pts[a][0]
		var overstretch := base_w.distance_to(_feet_plant[a]) > reach * 0.96
		if err > step_len * reach or overstretch:
			var l: int = (a + 7) % ARMS
			var r: int = (a + 1) % ARMS
			if _feet_t[l] >= 0.0 or _feet_t[r] >= 0.0:
				continue  # neighbours in the ring take turns
			_feet_from[a] = _feet_plant[a]
			var lead := vel.limit_length(length * 1.5) * step_time * 0.55
			var target := home + (lead - _floor_n * lead.dot(_floor_n))
			var tray := _ray(target + _floor_n * reach * 0.6, target - _floor_n * reach * 0.8)
			_feet_to[a] = tray["pos"] if not tray.is_empty() else target
			_feet_dur[a] = step_time
			_feet_t[a] = 0.0
			swinging += 1


func _foot_error(a: int, home: Vector3) -> float:
	var f := _feet_plant[a] if _feet_t[a] < 0.0 else _feet_to[a]
	return f.distance_to(home)


# ===================================================================== visual side

func _process(delta: float) -> void:
	if fish == null or not is_instance_valid(fish) or model == null or not is_visible_in_tree():
		return
	step(delta, {})


## The visual side for one frame. `ctx` (all optional) overrides what is read from the fish: "vel" (world velocity), "throttle",
## "boost", "stick", "roll". With no fish this also runs the physics side (tick) with the same delta, so a bare rig animates.
func step(delta: float, ctx: Dictionary) -> void:
	if model == null:
		return
	if fixed_delta > 0.0:
		delta = fixed_delta
	delta = clampf(delta, 0.0, 0.1)
	if delta <= 0.0:
		return
	_sync_scale()
	_age += delta
	_wave_age = minf(_wave_age + delta, 99.0)
	var gb := model.global_basis.orthonormalized()
	if ctx.has("throttle"):
		_throttle = float(ctx["throttle"])
	if ctx.has("boost"):
		_boost = bool(ctx["boost"])
	if ctx.has("stick"):
		_stick = ctx["stick"]
	if ctx.has("roll"):
		_roll_in = float(ctx["roll"])
	if ctx.has("air_roll"):
		_air_roll = bool(ctx["air_roll"])
	if ctx.has("vel"):
		_vel = ctx["vel"]
	elif fish != null and is_instance_valid(fish):
		_vel = fish.swim_velocity()
	# a frozen body (the card's preview, a Hunter held for the countdown) gets no physics ticks: the jet clock runs here, on the frame
	var frozen := fish != null and is_instance_valid(fish) and fish.freeze
	if frozen and not ctx.has("throttle"):
		_read_fish_inputs()
	if not _phys_driven or frozen:
		tick(delta, _vel, gb)
	# the body's own rotation since last frame, as a rotation of model-local vectors
	var counter := Basis.IDENTITY
	if _have_basis:
		counter = gb.inverse() * _last_basis
		var dq := counter.get_rotation_quaternion()
		var axis := dq.get_axis() if dq.get_angle() > 0.00001 else Vector3.UP
		_omega_local = -axis * dq.get_angle() / delta
	_last_basis = gb
	_have_basis = true
	var vel_local := gb.inverse() * _vel
	var speed := vel_local.length()
	var speed_ref := length * 1.6
	if fish != null and is_instance_valid(fish):
		speed_ref = maxf(fish.max_speed * 0.8, 1.0)
	var speed_t := clampf(speed / speed_ref, 0.0, 1.0)
	_speed_t = lerpf(_speed_t, speed_t, 1.0 - exp(-6.0 * delta))
	_flow_dir = (-vel_local / speed) if speed > 0.05 else _flow_dir
	_up_local = (gb.inverse() * Vector3.UP).normalized()
	# jet shape: critically damped chase of the physics side's raw values (no step edges)
	var w := 38.0
	_mantle = _damp(_mantle, _mantle_raw, w, delta, true)
	_spread = _damp(_spread, _spread_raw, 22.0, delta, false)
	var jet_on := _jet_t >= 0.0
	# idle breath and the cruise scull
	var breath := 0.12 * sin(_age * 1.5) * (1.0 - float(jet_on))
	var scull_target := 0.0
	if not jet_on:
		scull_target = clampf(0.25 + 0.75 * _speed_t + 0.5 * absf(_throttle), 0.0, 1.0) if (absf(_throttle) > 0.05 or speed > 0.5) else 0.0
	_scull_w = lerpf(_scull_w, scull_target, 1.0 - exp(-3.0 * delta))
	_scull_phase += delta * TAU * opt("octopus_scull_hz") * (1.0 + _speed_t)
	# turning flare (asymmetric drag) and the torque it makes
	# air roll held: the stick's x is a roll, not a yaw (the controller does the same), so the siphon stays on the axis and the arms
	# flare asymmetrically to show the roll
	var roll_cmd := clampf(_roll_in + (_stick.x if _air_roll else 0.0), -1.0, 1.0)
	_roll_flare = lerpf(_roll_flare, roll_cmd, 1.0 - exp(-8.0 * delta))
	var tf := Vector2(0.0 if _air_roll else _stick.x, _stick.y)
	_turn_flare = _turn_flare.lerp(tf, 1.0 - exp(-8.0 * delta))
	# the mantle trails the head when it turns or climbs; the siphon vectors against the turn
	var want_bend := Vector2(clampf(_omega_local.y * 0.22, -0.7, 0.7), clampf(_omega_local.x * 0.22, -0.5, 0.5))
	_mbend = _mbend.lerp(want_bend, 1.0 - exp(-7.0 * delta))
	var vec_max := opt("octopus_jet_vector")
	var siphon_yaw := (0.0 if _air_roll else -_stick.x) * vec_max
	var siphon_pitch := -_stick.y * vec_max * 0.8 - SIPHON_TRIM
	if _throttle < -0.15:
		siphon_yaw = PI * 0.88 * clampf(-_throttle * 2.0, 0.0, 1.0)  # backing off: the jet points ahead, under the arms
		siphon_pitch = 0.0
	_siphon = _siphon.lerp(Vector2(siphon_yaw, siphon_pitch), 1.0 - exp(-9.0 * delta))
	_solve_arms(delta, counter, vel_local, gb)
	_step_pop(delta)
	model.set_mantle_pop(_pop)
	model.set_mantle_pulse(clampf(_mantle + breath, -1.0, 1.0))
	model.set_mantle_bend(_mbend.x, _mbend.y)
	model.set_siphon_aim(_siphon.x, _siphon.y)
	_shader(delta, jet_on)
	if lash != null and is_instance_valid(lash):
		lash.call("blend_pose", model)
	shown["jet_env"] = _thrust_env
	shown["mantle"] = _mantle
	shown["spread"] = _spread
	shown["crawl"] = _crawl_w
	shown["scull"] = _scull_w
	shown["speed_t"] = _speed_t
	shown["jets"] = _jets
	shown["steps"] = _steps
	shown["jet_t"] = _jet_t
	shown["dash"] = _jet_dash and jet_on
	shown["height"] = _floor_dist if _floor_hit else -1.0


## The 15 model-space joints arm `arm` has now (the gait's own pose): what a lashing arm reels in to, so it ends without a pop.
func gait_joints(arm: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p: Vector3 = (_rest_pts[arm] as PackedVector3Array)[0]
	pts.append(p)
	var dirs: PackedVector3Array = _dirs[arm]
	var lens: PackedFloat32Array = _seg_len[arm]
	for j in SEGS:
		p += dirs[j] * lens[j]
		pts.append(p)
	return pts


## The stride's pop: each stride's input kicks the mantle's swell, and it rings out on an underdamped spring (a Battletoads overshoot:
## it swells past the jet's own inflation, then dips thin and settles). `hunter_exaggeration` scales the kick.
func _step_pop(delta: float) -> void:
	if _pop_impulse > 0.0:
		var master: Variant = WhatStinksSettings.shared().get("hunter_exaggeration")
		_pop_v += 40.0 * _pop_impulse * (float(master) if master != null else 1.0)
		_pop_impulse = 0.0
	var steps := maxi(1, ceili(delta / 0.008))
	var h := delta / float(steps)
	for i in steps:
		_pop_v += (-24.0 * 24.0 * _pop - 2.0 * 0.28 * 24.0 * _pop_v) * h
		_pop += _pop_v * h
	_pop = clampf(_pop, -1.0, 1.0)


## Critically damped chase with an optional overshoot-free clamp; returns the new value.
func _damp(x: float, target: float, omega: float, dt: float, mantle_channel: bool) -> float:
	# the same semi-implicit spring for every channel, substepped for stability
	var steps := maxi(1, ceili(dt * omega / 0.5))
	var h := dt / float(steps)
	var v := _mantle_v if mantle_channel else _spread_v
	for i in steps:
		v += (omega * omega * (target - x) - 2.0 * omega * v) * h
		x += v * h
	if mantle_channel:
		_mantle_v = v
	else:
		_spread_v = v
	return x


func _shader(delta: float, jet_on: bool) -> void:
	var stroke := clampf(_thrust_env * _jet_amp, 0.0, 1.0) if jet_on else clampf(_scull_w * 0.25, 0.0, 0.4)
	model.set_stroke(stroke)
	model.set_vein_travel(_vein_t)
	model.set_charge(charge)
	model.set_glow(opt("octopus_glow") + glow_extra)
	model.set_eye_glow(0.35 + 0.35 * _speed_t + 0.8 * charge + 0.5 * maxf(_pop, 0.0))
	model.set_sucker_glow(0.15 + 0.5 * _crawl_w + 0.8 * charge)


# ------------------------------------------------------------------- the arm solver

func _solve_arms(delta: float, counter: Basis, vel_local: Vector3, gb: Basis) -> void:
	var stiffness := opt("octopus_arm_stiffness")
	var zeta := opt("octopus_arm_damping")
	var lag := opt("octopus_arm_lag")
	var inertia := opt("octopus_inertia")
	var drag_bend := opt("octopus_drag_bend")
	var droop := opt("octopus_droop") * (1.0 - clampf(_speed_t * 3.5, 0.0, 1.0)) * (1.0 - _crawl_w)  # the swimming arms stream straight
	# speed pulls the arms into a tighter, streamlined bundle (and calms their undulation); a crawl is not a swim, so it lets go
	var tuck := opt("octopus_speed_tuck") * _speed_t * (1.0 - _crawl_w)
	var scull_amp := opt("octopus_scull_amp") * (1.0 - 0.35 * _speed_t)
	var sway := opt("octopus_idle_sway")
	var substeps := maxi(1, ceili(delta / (1.0 / 90.0)))
	var h := delta / float(substeps)
	var inv := gb.inverse()
	var tip_world_inv := global_transform.affine_inverse()
	var torque := Vector3.ZERO
	var down_local := -_up_local
	# a turn (or a roll) banks the delta like a wing: the arms' targets turn about the body's axis, the outside of the turn rising
	var bank_angle := (-_turn_flare.x + _roll_flare * 0.5) * opt("octopus_bank") * (0.4 + 0.6 * _speed_t)
	var bank := Basis(Vector3.BACK, bank_angle)
	var wave_up := bank * Vector3.UP
	# the jet's wave: one travelling undulation down the arms after each jet, easing in and dying away
	var jet_wave := 0.0
	if _wave_age < 6.0:
		jet_wave = opt("octopus_jet_wave") * clampf(_jet_amp, 0.0, 1.2) * smoothstep(0.0, 0.15, _wave_age) * exp(-_wave_age / 0.8)
	for a in ARMS:
		var radial := OctopusModel.arm_radial(a)
		var dirs: PackedVector3Array = _dirs[a]
		var vels: PackedVector3Array = _vels[a]
		var rest: PackedVector3Array = _rest_dirs[a]
		var bundle: PackedVector3Array = _bundle_dirs[a]
		var flare: PackedVector3Array = _flare_dirs[a]
		# the spread of this arm: the jet's, plus the turn's asymmetric flare
		var asym := (_turn_flare.x * radial.x - _turn_flare.y * radial.y) * 0.4 + _roll_flare * radial.y * 0.45
		var spread := clampf(_spread + asym * (0.5 + 0.5 * absf(_throttle)) - tuck, -1.0, 1.4)
		torque += Vector3(radial.y, -radial.x, 0.0) * maxf(spread, 0.0)
		# crawl: where this arm's tip wants to be, solved into directions
		var crawl_w := _crawl_w * _feet_ok[a] if _feet_init else 0.0
		if crawl_w > 0.001:
			_crawl_solve(a, tip_world_inv, gb)
		var ov: PackedVector3Array = override_dirs[a]
		var ow := override_w[a] if ov.size() == SEGS else 0.0
		var prev_offset := Vector3.ZERO
		var phase_a := float(a) * 0.83
		var d_target := PackedVector3Array()
		d_target.resize(SEGS)
		for j in SEGS:
			var s := float(j) / float(SEGS - 1)
			var t := rest[j]
			t = t.slerp(bundle[j], -spread) if spread < 0.0 else t.slerp(flare[j], minf(spread, 1.0))
			t = bank * t
			var tip_w := pow(s, 1.2) * 0.9 + 0.1
			# the water bends the tips back along the flow, and a slack arm drapes
			t += _flow_dir * (drag_bend * _speed_t * tip_w * 0.9)
			t += down_local * (droop * tip_w)
			# the tips keep a curl toward the sucker side (a flared arm is not a stick); it opens a little in a bundle
			var gbc: Basis = (_rest_gb[a] as Array)[j]
			t += gbc.y * (opt("octopus_tip_curl") * pow(s, 1.6) * (1.0 + 0.8 * maxf(spread, 0.0)) * (1.0 - 0.6 * maxf(-spread, 0.0)))
			t = t.normalized()
			if crawl_w > 0.001:
				t = t.slerp((_crawl_dirs[a] as PackedVector3Array)[j], crawl_w)
			if ow > 0.001:
				t = t.slerp(ov[j], ow)
			# FK wave: lazy sway at rest, a gentle undulation at cruise (mostly up and down, the delta rippling like a wing), both
			# travelling tip-ward; and the jet's wave on top
			var amp := (0.05 * sway * (1.0 - _scull_w) + 0.12 * scull_amp * _scull_w) * (0.3 + tip_w) * (1.0 - crawl_w * 0.6)
			var ph := _age * 1.05 * (1.0 - _scull_w) + _scull_phase * _scull_w - float(j) * 0.55 + phase_a * (1.0 - 0.6 * _scull_w)
			var gbj: Basis = (_rest_gb[a] as Array)[j]
			var lat := gbj.x * (1.0 - _scull_w * 0.65) + wave_up * (_scull_w * 0.9)
			var orl := gbj.y * (1.0 - _scull_w * 0.6)
			t += lat * (amp * sin(ph)) + orl * (amp * 0.7 * sin(ph + 1.3 + _scull_w))
			if jet_wave > 0.0005:
				t += wave_up * (jet_wave * (0.2 + tip_w) * sin(s * TAU * 0.9 - _wave_age * TAU * 1.4 + float(a % 4) * 0.25)) * (1.0 - crawl_w)
			t = t.normalized()
			d_target[j] = t
		# inertia: the state does not turn with the body (more at the tips)
		if inertia > 0.0 and counter != Basis.IDENTITY:
			for j in SEGS:
				var wgt := clampf(inertia * (0.12 + 0.88 * float(j) / float(SEGS - 1)), 0.0, 1.0)
				dirs[j] = dirs[j].lerp(counter * dirs[j], wgt).normalized()
				vels[j] = vels[j].lerp(counter * vels[j], wgt)
		for step_i in substeps:
			prev_offset = Vector3.ZERO
			for j in SEGS:
				var s := float(j) / float(SEGS - 1)
				var omega := stiffness * (1.0 - 0.55 * s)
				var target := (d_target[j] + prev_offset * lag).normalized()
				var d := dirs[j]
				var v := vels[j]
				v += (omega * omega * (target - d) - 2.0 * zeta * omega * v) * h
				d = (d + v * h).normalized()
				v -= d * v.dot(d)
				# an arm does not fold back on itself: the bend between neighbours is capped
				if j > 0:
					var prev := dirs[j - 1]
					var ang := prev.angle_to(d)
					var cap := 0.85 + 0.25 * crawl_w
					if ang > cap:
						d = prev.slerp(d, cap / ang).normalized()
				dirs[j] = d
				vels[j] = v
				prev_offset = d - d_target[j]
	# commit
	_torque = torque * 0.18
	_apply_dirs(_dirs, delta)


## Direction states -> the model's bends, down each chain through the rest bases.
func _apply_dirs(dirs_all: Array[PackedVector3Array], _delta: float) -> void:
	var bends := PackedVector3Array()
	bends.resize(SEGS)
	for a in ARMS:
		var dirs: PackedVector3Array = dirs_all[a]
		var rest: PackedVector3Array = _rest_dirs[a]
		var gbs: Array = _rest_gb[a]
		var lbs: Array = _rest_lb[a]
		var parent := _head_gb
		for j in SEGS:
			var arc := Quaternion(rest[j], dirs[j])
			var want := Basis(arc) * (gbs[j] as Basis)
			var local := parent.transposed() * want
			var bend: Basis = (lbs[j] as Basis).transposed() * local
			var e := bend.orthonormalized().get_euler(EULER_ORDER_YXZ)
			bends[j] = Vector3(e.x, e.y, e.z)
			parent = want
		model.set_arm_pose(a, bends)


# ------------------------------------------------------------------- crawl IK

## FABRIK for arm `a` toward its foot (the planted position or the swing's arc), into `_crawl_dirs[a]`.
func _crawl_solve(a: int, to_model: Transform3D, gb: Basis) -> void:
	var foot := _foot_world(a)
	var target_m := to_model * foot
	var pts: PackedVector3Array = _rest_pts[a]
	var lens: PackedFloat32Array = _seg_len[a]
	var base := pts[0]
	var dirs: PackedVector3Array = _dirs[a]
	var chain := PackedVector3Array()
	chain.resize(SEGS + 1)
	chain[0] = base
	for j in SEGS:
		chain[j + 1] = chain[j] + dirs[j] * lens[j]
	var total := 0.0
	for l in lens:
		total += l
	var lift_dir := _up_local
	var to_t := target_m - base
	if to_t.length() >= total * 0.999:
		var dn := to_t.normalized()
		for j in SEGS:
			chain[j + 1] = chain[j] + dn * lens[j]
	else:
		var lift := opt("octopus_crawl_lift") * 0.12
		for it in 4:
			chain[SEGS] = target_m
			for i in range(SEGS - 1, 0, -1):
				chain[i] = chain[i + 1] + (chain[i] - chain[i + 1]).normalized() * lens[i]
			chain[0] = base
			for i in range(1, SEGS + 1):
				chain[i] = chain[i - 1] + (chain[i] - chain[i - 1]).normalized() * lens[i - 1]
			if it == 0:
				# an elbow: the middle of the arm arches away from the floor
				for i in range(1, SEGS):
					chain[i] += lift_dir * (lift * sin(PI * float(i) / float(SEGS)) * total * 0.25)
	var out: PackedVector3Array = _crawl_dirs[a]
	for j in SEGS:
		var d := chain[j + 1] - chain[j]
		out[j] = d.normalized() if d.length() > 0.00001 else dirs[j]


## Where arm `a`'s foot is now in the world: the plant, or along the swing's arc (advanced by the fraction of the physics tick).
func _foot_world(a: int) -> Vector3:
	if _feet_t[a] < 0.0:
		return _feet_plant[a]
	var t := clampf(_feet_t[a] + Engine.get_physics_interpolation_fraction() * _phys_dt / maxf(_feet_dur[a], 0.05), 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var lift := opt("octopus_crawl_lift") * model.arm_length(a) * 0.5
	return _feet_from[a].lerp(_feet_to[a], e) + _floor_n * (lift * sin(PI * t))


## Where arm `a`'s tip is now in the world (probes: foot-plant slip).
func foot_world(a: int) -> Vector3:
	return _foot_world(a)


func foot_swinging(a: int) -> bool:
	return _feet_t[a] >= 0.0


## Forces the cycle: a jet now (probes, the bite's recoil, an escape).
func jet_now(strength := 1.0, dash := false) -> void:
	_jet_dash = dash
	_jet_amp = clampf(strength, 0.1, 1.5)
	_jet_t = 0.0
	_wave_age = 0.0
	_jets += 1
	jet_fired.emit(_jet_amp)


## Lets the springs reach the resting pose (droop, sway) so the first frames do not move: run at build, for a rig in the tree.
func settle() -> void:
	if model == null or not is_inside_tree():
		return
	var saved_throttle := _throttle
	var saved_boost := _boost
	for i in 45:
		step(1.0 / 60.0, {"throttle": 0.0, "boost": false, "vel": Vector3.ZERO, "stick": Vector2.ZERO, "roll": 0.0})
	_throttle = saved_throttle
	_boost = saved_boost
	_have_basis = false
	_age = 0.0


## The fish's visual is scaled to the hitbox (body_scale); the octopus is built in metres, so this undoes the parent's scale and
## keeps the head where the box's front puts it.
func _sync_scale() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var s := parent.global_basis.get_scale()
	if s.x < 0.00001 or s.y < 0.00001 or s.z < 0.00001:
		return
	var inv := Vector3(1.0 / s.x, 1.0 / s.y, 1.0 / s.z)
	if not scale.is_equal_approx(inv) or not is_equal_approx(position.z, (-length * 0.5 - _front_z) * inv.z):
		scale = inv
		position = Vector3(0.0, 0.0, -length * 0.5 - _front_z) * inv
