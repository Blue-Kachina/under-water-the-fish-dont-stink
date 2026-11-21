class_name WhipAttack
extends HunterAttack
## The Ember Octopus' style, "Tendril Lash" (planning_new_hunters.md C3): heat-seeking whips.
##
##   PRESS    the eight arms rear back and flare into a crown (a coiled, cocked shape), the suckers glow, a targeting aura sweeps the
##            view cone, and up to whip_arms targets are locked, nearest first (weighted by how square they are to the nose), one arm
##            each, with a spark per lock. The mantle squashes (anticipation).
##   HOLD     the locks track their targets (the cocked arms turn to follow), the arms coil tighter and the veins brighten with the
##            charge (charge buys reach, hit radius and the fish an arm takes). A lock whose target leaves the cone (or the range) is
##            dropped, free arms pick up new targets now and then: the approach angle matters.
##   RELEASE  the locks are checked once more (a target behind or out of the cone is dropped), then the arms whip out on bezier paths
##            that home on the live target, a crack wave running down each arm, a whip-crack at the tip. The arms go one after another
##            (whip_stagger_min .. whip_stagger_max s apart, nearest target first). Each arm that hits eats what it hit and credits
##            the bite; the octopus is pushed away by the sum of the arms' recoil (whip_recoil per hit arm, a share for a miss),
##            then the arms reel in and settle onto the rig's own pose.
##
## Judging. The nearest arm is the bite's own contact: the bite's STRIKE is held (its clock stalled) until that arm lands, then the
## contact tick judges it through catch_rule, so HunterBiteFx's landed feel plays for a hit or a miss as for any bite. Every later arm
## is judged the tick it lands through WhatStinksMatch.judge_drill (the host only, as the Lamprey's drill; a guest's Hunter is judged on the
## host from the puppet's own lash). Nothing is judged without a world (a probe): arm_hit is emitted instead.
##
## The class does not need a rig. Everything is worked out in the octopus' model space (-Z ahead) from the arm bases and lengths of an
## OctopusModel (found on the fish, or one given with attach_model()), or from a made-up ring of eight arms when there is none, so the
## targeting, timing, recoil and tip paths can be probed headless. With a model it poses the arms every tick (auto_pose), or a rig
## calls blend_pose() itself after its gait. See WhipAttack.Solver for joints -> bends.
##
## Settings are read through cfg(): tune (a probe's overrides), then the panel (WhatStinksSettings property of the same name), then
## DEFAULTS, so it works before the settings are registered (registrations in the C3 log).

## A hit: arm `arm` landed on a lock at `at` (world) and `fish` is what it took (probe/no world: 0).
signal arm_hit(arm: int, at: Vector3)
## An arm landed on nothing (the target left, or a whiff).
signal arm_missed(arm: int, at: Vector3)
## A target was locked / dropped (world position).
signal locked(arm: int, at: Vector3)
signal dropped(arm: int, at: Vector3)

enum Beat { IDLE, FLARE, HOLD, LASH, SETTLE }
enum ArmPhase { REST, COCKED, FLY, GLUE, RETRACT }

## Every value, with the panel id the settings take. Ranges are in the C3 registration list.
const DEFAULTS := {
	"whip_arms": 8.0,            # most targets (arms) at once
	"whip_range": 1.15,          # x the bite's reach (charge adds whip_charge_reach)
	"whip_cone": 75.0,           # half angle of the view cone (deg)
	"whip_cone_slack": 1.2,      # x cone/range a held lock may drift out to before it is dropped
	"whip_range_slack": 1.25,
	"whip_angle_weight": 0.6,    # how much squareness to the nose counts against distance when ranking targets
	"whip_refill_s": 0.25,       # seconds between looking for targets for free arms while held (0: only at the press)
	"whip_homing": 0.8,          # how much of the tip's path follows the live target (0: aimed at the release spot)
	"whip_fly_s": 0.14,          # an arm's flight to a target at the edge of the range (s); nearer is quicker
	"whip_stagger_min": 0.03,    # seconds between one arm's launch and the next
	"whip_stagger_max": 0.06,
	"whip_per_arm": 1.0,         # fish an arm takes at no charge
	"whip_charge_capacity": 2.0, # ... and at full charge
	"whip_charge_reach": 1.4,    # x range / hit radius reach at full charge
	"whip_tap_share": 0.5,       # share of the locks a tap (no charge) lashes; full charge lashes all
	"whip_hit_radius": 0.55,     # x bite radius: what an arm takes around its target
	"whip_recoil": 2.2,          # m/s the octopus is pushed back per hit arm
	"whip_miss_recoil": 0.35,    # share of that for an arm that missed
	"whip_recoil_cap": 7.0,      # m/s most one lash may push
	"whip_flare": 75.0,          # deg: how far from straight ahead the crown spreads
	"whip_sweep_min": 140.0,     # deg: the cocked arm's curl at no charge ...
	"whip_sweep_max": 290.0,     # ... and at full charge (tighter coil)
	"whip_stretch": 1.6,         # most an arm may stretch in a lash (1: never)
	"whip_wave": 0.07,           # crack wave amplitude (x arm length)
	"whip_flare_s": 0.2,         # seconds for the crown to open
	"whip_retract_s": 0.4,       # seconds to reel in after a hit
	"whip_miss_retract_s": 0.22, # ... after a miss
	"whip_whiff_arms": 4.0,      # arms that lash when nothing is locked
	"whip_stall_max": 0.45,      # most the strike waits for the first arm
	"whip_lunge": 0.0,           # HunterBite.lunge_gain while the whip is held (the recoil is the octopus' push)
	"whip_aura": 1.0,            # 1: show the targeting cone
}

## A probe's overrides (win over the panel).
var tune: Dictionary = {}
## Pose the model every tick (a rig that blends with its own gait sets this false and calls blend_pose()).
var auto_pose := true
## Drive the mantle squash / shader charge on the model (false: a rig does).
var drive_model_fx := true
## () -> Array of candidate dictionaries {"key": int, "pos": Vector3, "vel": Vector3} (a probe's targets); empty: the match's field.
var target_source := Callable()
## (impulse: Vector3) -> void: where the recoil goes (default FishController.apply_push).
var push_sink := Callable()
## (arm: int) -> PackedVector3Array: the rig's own joints for an arm (model space, 15), what the arms reel in to. Default: the model's rest.
var gait_provider := Callable()
## Probes: the rng seed of the stagger.
var seed_value := 11

var beat := Beat.IDLE
var locks: Array[Lock] = []
var charge_now := 0.0
## What the last lash did.
var hits_total := 0
var misses_total := 0
var recoil_total := Vector3.ZERO
var recoil_log: Array[Dictionary] = []
var lashes := 0
## The kit (squash, hit-stop, camera punch); a rig reads scale_of() channels from it.
var ex: AttackExaggerate
var fx: OctopusWhipFx
var info: Info
var arms: Array[Tendril] = []
## Seconds since the press / since the release.
var held_s := 0.0
var lash_s := 0.0

var _bite: HunterBite
var _wired: HunterBite
var _model: Node3D
var _model_wait := 0.0
var _rng := RandomNumberGenerator.new()
var _refill := 0.0
var _fire: Array[Tendril] = []
var _contact_at := 0.0
var _stall := false
var _first_judged := false
var _recoil_spent := 0.0
var _mantle := 0.0
var _mantle_v := 0.0
var _aura_sweep := 0.0
var _flash := 0.0
var _pending_hits := 0
var _dt := 0.0
var _clock := 0.0
var _last_origin := Vector3.ZERO
var _last_forward := Vector3(0.0, 0.0, -1.0)
var _has_origin := false


func _init() -> void:
	key = "whip"
	_rng.seed = seed_value
	info = Info.new()
	for a in 8:
		arms.append(Tendril.new(a))


## One lock: a target an arm is on.
class Lock extends RefCounted:
	var key := 0
	var school: School
	var index := -1
	var prey: FishController
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var arm := -1
	var age := 0.0
	var dist := 0.0
	var alive := true
	var fired := false
	var hit := false


## One arm's state.
class Tendril extends RefCounted:
	var arm := 0
	var phase := ArmPhase.REST
	var t := 0.0
	var lock: Lock
	var from := PackedVector3Array()      # joints when the press began (model space)
	var cock0 := PackedVector3Array()     # the cocked joints when the lash began
	var ret0 := PackedVector3Array()      # the joints when the reel-in began
	var joints := PackedVector3Array()    # what the arm shows now
	var aim := 0.0                        # how far the cocked arm has turned to its target
	var aim_dir := Vector3.ZERO           # model space, unit
	var delay := 0.0                      # the crown opens a little after the one before
	var start := 0.0                      # seconds after the release that the lash goes
	var fly_s := 0.1
	var x_frozen := Vector3.ZERO          # model space target when the lash began
	var x_live := Vector3.ZERO
	var hit := false
	var cracked := false
	var judged := false
	var whiff := false
	var retract_s := 0.4
	var glow := 0.0
	var first := false
	var order := 0
	var world_tip := Vector3.ZERO
	var overshoot := 0.0

	func _init(index: int) -> void:
		arm = index

	func active() -> bool:
		return phase != ArmPhase.REST


## What the lash works from: the arm bases, lengths and the rest segment shares, in the model's space. Taken from an
## OctopusModel (refresh() each tick) or made up.
class Info extends RefCounted:
	var octo: Node3D
	var length := 6.0
	var bases: PackedVector3Array = PackedVector3Array()
	var radials: PackedVector3Array = PackedVector3Array()
	var arm_len: PackedFloat32Array = PackedFloat32Array()
	var fracs: Array[PackedFloat32Array] = []
	var mouth := Vector3.ZERO

	func _init() -> void:
		bases.resize(8)
		radials.resize(8)
		arm_len.resize(8)
		for a in 8:
			var ang := deg_to_rad(22.5 + 45.0 * a)
			radials[a] = Vector3(cos(ang), sin(ang), 0.0)
			fracs.append(PackedFloat32Array())
		synth(6.0)

	## Made-up arms for a given body length.
	func synth(body_length: float) -> void:
		octo = null
		length = body_length
		for a in 8:
			bases[a] = radials[a] * body_length * 0.055 + Vector3(0.0, 0.0, -body_length * 0.07)
			arm_len[a] = body_length * 0.5
			var f := PackedFloat32Array()
			for j in 15:
				f.append(float(j) / 14.0)
			fracs[a] = f
		mouth = Vector3(0.0, 0.0, -body_length * 0.1)

	## The real arms.
	func adopt(model: Node3D) -> void:
		octo = model
		length = float(model.get("length_m"))
		for a in 8:
			radials[a] = model.call("arm_radial", a)
			arm_len[a] = float(model.call("arm_length", a))
			var f := PackedFloat32Array()
			var total := 0.0
			var cum := PackedFloat32Array()
			cum.append(0.0)
			for j in 14:
				total += float(model.call("arm_segment_length", a, j))
				cum.append(total)
			var span := maxf(total, 0.0001)
			for j in 15:
				f.append(cum[j] / span)
			fracs[a] = f
			arm_len[a] = span
		refresh()

	## This tick's bases and mouth (the head may be posed).
	func refresh() -> void:
		if octo == null:
			return
		for a in 8:
			var t: Transform3D = octo.call("arm_bone_transform", a, 0)
			bases[a] = t.origin
		mouth = octo.call("mouth_local")


# ------------------------------------------------------------------------------ settings

static func cfg_of(settings: Object, tuned: Dictionary, id: String) -> float:
	if tuned.has(id):
		return float(tuned[id])
	if settings != null:
		var got: Variant = settings.get(id)
		if got != null:
			return float(got)
	return float(DEFAULTS[id])


func cfg(id: String) -> float:
	return cfg_of(_bite.settings if _bite != null else null, tune, id)


## Model for the shapes: an OctopusModel (anything with its pose/read-back methods). Without one the arms are made up.
func attach_model(model: Node3D) -> void:
	_model = model
	if model != null:
		info.adopt(model)
		var rig := model.get_parent()  # an OctopusRig: it owns the gait, so it runs blend_pose after its own pose and the arms reel in to its joints
		if rig != null and rig.has_method("gait_joints"):
			auto_pose = false
			gait_provider = Callable(rig, "gait_joints")
			rig.set("lash", self)
	else:
		info.synth(info.length)


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


# ------------------------------------------------------------------------------ bite hooks

func _wire(bite: HunterBite) -> void:
	_bite = bite
	if _wired == bite:
		return
	_wired = bite
	ex = AttackExaggerate.new(AttackExaggerate.params_from(bite.settings, bite.form))
	ex.camera_punch.connect(func(amount: float, dir: Vector3) -> void:
		if is_instance_valid(bite.fish):
			var camera: Object = ChompKit.view_camera(bite.fish)
			if camera != null:
				camera.call("punch", amount, dir))
	bite.released.connect(func(charge: float) -> void:
		if beat == Beat.IDLE and is_instance_valid(bite.fish):
			press(_origin_of(bite), _forward_of(bite), bite.fish.global_basis)  # a tap: no press hook ran
		release(charge))
	bite.aborted.connect(func() -> void: abort())
	bite.landed.connect(func(taken: int) -> void: _on_landed(taken))
	_find_model(bite)
	if fx == null:
		fx = OctopusWhipFx.new()
		fx.name = "OctopusWhipFx"
		bite.add_child(fx)
		fx.hb = bite


func _find_model(bite: HunterBite) -> void:
	if has_model() or not is_instance_valid(bite.fish):
		return
	var visual: Node = bite.fish.get("_visual")
	var found := _search(visual if visual != null else bite.fish)
	if found != null:
		attach_model(found)


static func _search(node: Node) -> Node3D:
	if node == null:
		return null
	if node.has_meta("hunter_octopus") and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _search(child)
		if found != null:
			return found
	return null


func reach_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, cfg_of(bite.settings, tune, "whip_charge_reach"), clampf(charge, 0.0, 1.0))


func capacity_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, cfg_of(bite.settings, tune, "whip_charge_capacity"), clampf(charge, 0.0, 1.0))


func on_open(bite: HunterBite) -> void:
	_wire(bite)
	_find_model(bite)
	bite.lunge_gain = cfg("whip_lunge")
	press(_origin_of(bite), _forward_of(bite), bite.fish.global_basis)


func on_hold(bite: HunterBite, _delta: float) -> void:
	_wire(bite)
	charge_now = bite.charge()
	if ex != null:
		ex.hold(charge_now)


func on_tick(bite: HunterBite, delta: float) -> void:
	_wire(bite)
	_bite = bite
	_find_model_retry(bite, delta)
	var origin := _origin_of(bite)
	var forward := _forward_of(bite)
	# Hold the strike until the first arm lands (the contact tick is that arm's).
	var b := bite.bite
	if _stall and b != null and b.phase == ChompKit.Phase.STRIKE and not b.landed:
		if lash_s >= _contact_at or lash_s >= cfg("whip_stall_max"):
			var strike := maxf(b.duration(ChompKit.Phase.STRIKE), 0.0001)
			var shut: float = 1.0 - b.settings.chomp_contact
			var share: float = sqrt(clampf(1.0 - shut / maxf(b.open, 0.001), 0.0, 1.0)) if b.open > shut else 0.0
			b.t = maxf(b.t, strike * share)
			_stall = false
		else:
			b.t -= delta  # update() adds it back: the strike stands still
	elif _stall and (b == null or b.phase != ChompKit.Phase.STRIKE):
		_stall = false
	var holding := bite.holding()
	if holding:
		charge_now = bite.charge()
	step(delta, origin, forward, holding, bite.fish.global_basis if is_instance_valid(bite.fish) else Basis.IDENTITY)
	if auto_pose and has_model():
		blend_pose(_model)


func _find_model_retry(bite: HunterBite, delta: float) -> void:
	if has_model():
		return
	_model_wait -= delta
	if _model_wait <= 0.0:
		_model_wait = 1.0
		_find_model(bite)


func on_landed(_bite_arg: HunterBite) -> void:
	pass


func on_cancel(_bite_arg: HunterBite) -> void:
	abort()


func on_close(_bite_arg: HunterBite, taken: Dictionary) -> void:
	_pending_hits += int(taken.get("school_fish", 0)) + (taken.get("fish", []) as Array).size()


func ring_count(bite: HunterBite) -> int:
	return locks.size() if bite.holding() else bite.capacity()


## The arm-0 judge at the contact tick: the nearest firing arm's lock, a ball round it.
func catch_rule(bite: HunterBite) -> Dictionary:
	_first_judged = true
	var first := _first_arm()
	var mouth := bite.mouth_point()
	if first == null or first.lock == null or not first.hit:
		return {"point": mouth, "capacity": 1, "only": null, "extra": [], "frustum": false, "inside": func(_at: Vector3) -> bool: return false}
	var centre := first.lock.pos
	var radius := _hit_radius(bite, bite.strike_charge())
	return {
		"point": centre, "capacity": _per_arm(bite, bite.strike_charge()), "only": null, "extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool: return at.distance_to(centre) <= radius,
	}


func net_catch_rule(bite: HunterBite, _mouth: Vector3, _forward: Vector3, charge: float, _extra: Dictionary) -> Dictionary:
	_first_judged = true
	var first := _first_arm()
	if first == null or first.lock == null or not first.hit:
		return {"point": bite.mouth_point(), "capacity": 1, "only": null, "extra": [], "frustum": false, "inside": func(_at: Vector3) -> bool: return false}
	var centre := first.lock.pos
	var radius := _hit_radius(bite, charge)
	return {
		"point": centre, "capacity": _per_arm(bite, charge), "only": null, "extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool: return at.distance_to(centre) <= radius,
	}


func _first_arm() -> Tendril:
	for t in _fire:
		if t.first:
			return t
	return null


func _hit_radius(bite: HunterBite, charge: float) -> float:
	return bite.radius() * cfg("whip_hit_radius") * lerpf(1.0, cfg("whip_charge_reach"), clampf(charge, 0.0, 1.0))


func _per_arm(bite: HunterBite, charge: float) -> int:
	return maxi(1, roundi(cfg("whip_per_arm") * lerpf(1.0, cfg("whip_charge_capacity"), clampf(charge, 0.0, 1.0))))


## The bot: open on a target in range ahead, let go once a few are locked and it has charged (or they are leaving).
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.3 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share * cfg("whip_range"), "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_open_gap * cfg("whip_range"), "hold": false}
	var want := mini(roundi(cfg("whip_arms")), 4)
	var enough := locks.size() >= want and bite.charge() >= settings.hunter_bot_charge * 0.6
	var spent := bite.charge() >= settings.hunter_bot_charge and not locks.is_empty()
	var nothing := locks.is_empty() and held_s > 0.9
	var release := enough or spent or nothing or held_s > 4.0
	if bot.stinker_blocks and not nothing:
		release = false
	return {"press": false, "hold": not release}


# ------------------------------------------------------------------------------ the beats (no HunterBite needed)

## The press. `origin` and `forward` are the mouth and nose (world).
func press(origin: Vector3, forward: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	_rng.seed = seed_value + lashes * 131
	var carry: Array[PackedVector3Array] = []
	for t in arms:
		carry.append(t.joints.duplicate())
	_reset_state()
	for t in arms:
		t.joints = carry[t.arm]  # a press during a reel-in starts from where the arm is
	_last_origin = origin
	_last_forward = forward.normalized()
	_xf_basis = basis
	if has_model():
		info.refresh()
	if ex == null:
		ex = AttackExaggerate.new()
	ex.press()
	charge_now = 0.0
	beat = Beat.FLARE
	held_s = 0.0
	_snapshot_from()
	for t in arms:
		t.phase = ArmPhase.COCKED
		t.t = 0.0
		t.delay = 0.012 * float(t.arm)
	_acquire(origin, forward, true)
	_mantle_v += 6.0  # the squash kick
	if fx != null:
		fx.flare(origin, forward)
		fx.play(&"flare", origin)
	_refill = cfg("whip_refill_s")


## The release at `charge`. Works out who is lashed, in what order and when.
func release(charge: float) -> void:
	if beat != Beat.FLARE and beat != Beat.HOLD:
		return
	charge_now = clampf(charge, 0.0, 1.0)
	if ex != null:
		ex.release(charge_now)
	var origin := _last_origin
	var forward := _last_forward
	_validate_locks(origin, forward, charge_now, true)
	_fire.clear()
	_recoil_spent = 0.0
	recoil_total = Vector3.ZERO
	recoil_log.clear()
	hits_total = 0
	misses_total = 0
	_pending_hits = 0
	_first_judged = false
	lashes += 1
	var by_dist: Array[Lock] = locks.duplicate()
	by_dist.sort_custom(func(a: Lock, b: Lock) -> bool: return a.dist < b.dist)
	var count := by_dist.size()
	var firing := count
	if count > 0:
		firing = clampi(roundi(lerpf(cfg("whip_tap_share"), 1.0, charge_now) * count), 1, count)
	var stretch_cap := maxf(cfg("whip_stretch"), 1.0)
	var t_acc := 0.0
	var order := 0
	for i in firing:
		var lock: Lock = by_dist[i]
		var tendril: Tendril = arms[lock.arm]
		_arm_for_fire(tendril, lock, origin, order, t_acc, charge_now)
		_fire.append(tendril)
		t_acc += _rng.randf_range(cfg("whip_stagger_min"), maxf(cfg("whip_stagger_max"), cfg("whip_stagger_min")))
		order += 1
	if count == 0:
		var whiff_arms: Array[int] = [1, 2, 0, 3, 7, 4, 6, 5]
		var n := clampi(roundi(cfg("whip_whiff_arms")), 1, 8)
		for i in n:
			var tendril: Tendril = arms[whiff_arms[i]]
			var span := _span(charge_now)
			var spread := Vector3(info.radials[tendril.arm].x, info.radials[tendril.arm].y, 0.0) * span * 0.18
			var x_world := origin + forward * span * 0.8 + _from_model_dir(spread)
			_arm_for_fire(tendril, null, origin, order, t_acc, charge_now, x_world)
			_fire.append(tendril)
			t_acc += _rng.randf_range(cfg("whip_stagger_min"), maxf(cfg("whip_stagger_max"), cfg("whip_stagger_min")))
			order += 1
	# Arms not lashed relax a beat after the lash begins.
	var relax_n := 0
	for t in arms:
		if _fire.has(t):
			continue
		t.start = 0.12 + 0.02 * float(relax_n)
		t.first = false
		t.retract_s = cfg("whip_retract_s")
		t.whiff = false
		relax_n += 1
	_contact_at = 0.08
	if not _fire.is_empty():
		_fire[0].first = true
		_contact_at = _fire[0].start + _fire[0].fly_s
	_stall = true
	beat = Beat.LASH
	lash_s = 0.0
	_mantle_v -= 16.0  # the pop on release
	_mantle = minf(_mantle, 0.2)
	if fx != null:
		fx.play(&"lash", origin)
		fx.aura_off()
	for l in locks:
		l.fired = false
	for t in _fire:
		if t.lock != null:
			t.lock.fired = true


## Called off with no lash: the arms ease back.
func abort() -> void:
	if beat == Beat.IDLE:
		return
	if ex != null:
		ex.abort()
	for t in arms:
		if t.phase != ArmPhase.REST:
			_begin_retract(t, 0.3)
	if fx != null:
		fx.aura_off()
	locks.clear()
	_stall = false
	beat = Beat.SETTLE


func reset() -> void:
	_reset_state()
	if has_model():
		_restore_model(_model)
	if ex != null:
		ex.reset()


func _reset_state() -> void:
	locks.clear()
	_fire.clear()
	_stall = false
	for t in arms:
		t.phase = ArmPhase.REST
		t.lock = null
		t.t = 0.0
		t.aim = 0.0
		t.hit = false
		t.cracked = false
		t.judged = false
		t.first = false
		t.glow = 0.0
		t.joints = PackedVector3Array()
	beat = Beat.IDLE
	charge_now = 0.0


## Advance everything by `delta` (the hit-stop aware dt comes from the kit). `basis` is the octopus body's orientation (world).
func step(delta: float, origin: Vector3, forward: Vector3, holding: bool, basis: Basis = Basis.IDENTITY) -> void:
	_dt = ex.tick(delta) if ex != null else delta
	var dt := _dt
	_clock += dt
	_last_origin = origin
	_last_forward = forward.normalized() if forward.length_squared() > 0.0001 else _last_forward
	_has_origin = true
	_xf_basis = basis
	if has_model():
		info.refresh()
	_flash = maxf(_flash - dt * 5.0, 0.0)
	# The mantle is a spring: squashed while held (more with charge), popped on release.
	var want := 0.0
	if beat == Beat.FLARE or beat == Beat.HOLD:
		want = 0.45 + 0.5 * charge_now
	_mantle_v += (want - _mantle) * 160.0 * dt
	_mantle_v *= exp(-11.0 * dt)
	_mantle += _mantle_v * dt
	match beat:
		Beat.FLARE, Beat.HOLD:
			held_s += dt
			if beat == Beat.FLARE and held_s > cfg("whip_flare_s"):
				beat = Beat.HOLD
			if holding:
				_track(dt, origin, forward)
			_aura_sweep = fmod(_aura_sweep + dt * (1.1 + 1.6 * charge_now), 1.0)
		Beat.LASH, Beat.SETTLE:
			lash_s += dt
	_advance_arms(dt)
	if fx != null:
		_update_fx(origin, forward)
	if beat == Beat.LASH or beat == Beat.SETTLE:
		var live := false
		for t in arms:
			if t.phase != ArmPhase.REST:
				live = true
				break
		if not live and lash_s > 0.05:
			beat = Beat.IDLE
			_fire.clear()
			locks.clear()
			if fx != null:
				fx.aura_off()


var _xf_basis := Basis.IDENTITY
var _fx_dirty := false


# ------------------------------------------------------------------------------ targets

func _origin_of(bite: HunterBite) -> Vector3:
	return bite.mouth_point()


func _forward_of(bite: HunterBite) -> Vector3:
	return -bite.fish.global_basis.z.normalized() if is_instance_valid(bite.fish) else Vector3(0.0, 0.0, -1.0)


## The range of a lash at `charge` (m): the bite's reach (with the charge's share), or a made-up one.
func _span(charge: float) -> float:
	if _bite == null or not is_instance_valid(_bite.fish):
		return info.length * 0.5 * cfg("whip_range") * lerpf(1.0, cfg("whip_charge_reach"), clampf(charge, 0.0, 1.0))
	return cfg("whip_range") * _bite.reach_at(charge)


## Candidates {"key", "pos", "vel", + "school"/"index" or "prey"} in range of `origin`.
func _candidates(origin: Vector3, span: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if target_source.is_valid():
		for item: Variant in target_source.call():
			if item is Dictionary:
				out.append(item)
		return out
	var bite := _bite
	if bite == null or bite.world == null or not is_instance_valid(bite.world):
		return out
	var world := bite.world
	var field: WhatStinksField = world.get("field")
	if field != null:
		for school in field.schools:
			if not is_instance_valid(school) or school.alive_count() == 0 or school.middle().distance_to(origin) > span + school.radius() * 2.0:
				continue
			for i in school.fish_count():
				if not school.is_alive(i) or school.is_claimed(i):
					continue
				var at := school.fish_position(i)
				if at.distance_to(origin) <= span * 1.3:
					out.append({"key": school.get_instance_id() * 4096 + i, "pos": at, "vel": school.fish_velocity(i), "school": school, "index": i})
	if bite.settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if prey == bite.fish or not is_instance_valid(prey):
				continue
			var gap := prey.global_position.distance_to(origin)
			if gap <= span * 1.3:
				out.append({"key": prey.get_instance_id(), "pos": prey.global_position, "vel": prey.swim_velocity(), "prey": prey})
	return out


## Picks targets for free arms: nearest first (distance weighted by how far off the nose), within the cone.
func _acquire(origin: Vector3, forward: Vector3, announce: bool) -> void:
	var cap := clampi(roundi(cfg("whip_arms")), 0, 8)
	if cap <= locks.size():
		return
	var span := _span(charge_now)
	var cone_cos := cos(deg_to_rad(clampf(cfg("whip_cone"), 1.0, 180.0)))
	var weight := cfg("whip_angle_weight")
	var taken := {}
	for l in locks:
		taken[l.key] = true
	var scored: Array[Array] = []
	for c: Dictionary in _candidates(origin, span):
		var ckey := int(c.get("key", 0))
		if taken.has(ckey):
			continue
		var pos: Vector3 = c["pos"]
		var off := pos - origin
		var dist := off.length()
		if dist > span or dist < 0.0001:
			continue
		var cos_a := forward.dot(off / dist)
		if cos_a < cone_cos:
			continue
		scored.append([dist * (1.0 + weight * (1.0 - cos_a) * 0.5), c, dist])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for entry in scored:
		if locks.size() >= cap:
			break
		var arm := _free_arm_for((entry[1] as Dictionary)["pos"], origin)
		if arm < 0:
			break
		var lock := _make_lock(entry[1] as Dictionary, float(entry[2]), arm)
		locks.append(lock)
		arms[arm].lock = lock
		if announce:
			locked.emit(arm, lock.pos)
			if fx != null:
				fx.lock_on(arm, lock.pos)
				fx.play(&"lock", lock.pos, locks.size())


func _make_lock(c: Dictionary, dist: float, arm: int) -> Lock:
	var lock := Lock.new()
	lock.key = int(c.get("key", 0))
	lock.school = c.get("school") as School
	lock.index = int(c.get("index", -1))
	lock.prey = c.get("prey") as FishController
	lock.pos = c["pos"]
	lock.vel = c.get("vel", Vector3.ZERO)
	lock.dist = dist
	lock.arm = arm
	return lock


## The free arm whose ring direction best matches where the target sits across the nose (so arms do not cross), or -1.
func _free_arm_for(world_pos: Vector3, origin: Vector3) -> int:
	var local := _to_model_dir(world_pos - origin)
	var lateral := Vector2(local.x, local.y)
	var best := -1
	var best_score := -INF
	for a in 8:
		if arms[a].lock != null:
			continue
		var radial := info.radials[a]
		var score := 0.0
		if lateral.length() > 0.001:
			score = radial.x * lateral.normalized().x + radial.y * lateral.normalized().y
			score *= clampf(lateral.length() / maxf(local.length(), 0.001) * 2.0, 0.0, 1.0)
		# Straight ahead: the upper arms (the front pair) first, then outward.
		score += 0.05 * radial.y + 0.001 * float(7 - a)
		if score > best_score:
			best_score = score
			best = a
	return best


## Positions follow the targets; those that left the cone/range or are gone are dropped (with a spark).
func _track(dt: float, origin: Vector3, forward: Vector3) -> void:
	_validate_locks(origin, forward, charge_now, false)
	_refill -= dt
	var every := cfg("whip_refill_s")
	if every > 0.0 and _refill <= 0.0 and held_s > 0.15:
		_refill = every
		_acquire(origin, forward, true)
	for l in locks:
		l.age += dt


func _refresh_lock(l: Lock) -> bool:
	if l.prey != null:
		if not is_instance_valid(l.prey) or l.prey.battered:
			return false
		if _bite != null and _bite.world != null and is_instance_valid(_bite.world) and not bool(_bite.world.call("is_live_prey", l.prey)):
			return false
		l.pos = l.prey.global_position
		l.vel = l.prey.swim_velocity()
		return true
	if l.school != null:
		if not is_instance_valid(l.school) or not l.school.is_alive(l.index) or l.school.is_claimed(l.index):
			return false
		l.pos = l.school.fish_position(l.index)
		l.vel = l.school.fish_velocity(l.index)
		return true
	if target_source.is_valid():
		for item: Variant in target_source.call():
			if item is Dictionary and int((item as Dictionary).get("key", -1)) == l.key:
				l.pos = (item as Dictionary)["pos"]
				l.vel = (item as Dictionary).get("vel", Vector3.ZERO)
				return true
		return false
	return true


## Drops what is gone, behind, or out of range; `strict` (the release) uses the cone and range exactly, a hold the slack.
func _validate_locks(origin: Vector3, forward: Vector3, charge: float, strict: bool) -> void:
	var span := _span(charge)
	var cone := deg_to_rad(clampf(cfg("whip_cone"), 1.0, 180.0))
	var slack_cone := 1.0 if strict else cfg("whip_cone_slack")
	var slack_range := 1.0 if strict else cfg("whip_range_slack")
	var keep: Array[Lock] = []
	for l in locks:
		var ok := _refresh_lock(l)
		var off := l.pos - origin
		l.dist = off.length()
		if ok:
			if l.dist > span * slack_range or l.dist < 0.0001:
				ok = false
			elif forward.angle_to(off / l.dist) > minf(cone * slack_cone, PI):
				ok = false
		if ok:
			keep.append(l)
		else:
			l.alive = false
			arms[l.arm].lock = null
			dropped.emit(l.arm, l.pos)
			if fx != null:
				fx.drop_lock(l.arm, l.pos)
				fx.play(&"lost", l.pos)
	locks = keep


# ------------------------------------------------------------------------------ frames

func _to_model_dir(world_dir: Vector3) -> Vector3:
	return _xf_basis.inverse() * world_dir if not has_model() else (_model.global_basis.inverse() * world_dir)


func _from_model_dir(local_dir: Vector3) -> Vector3:
	return _xf_basis * local_dir if not has_model() else (_model.global_basis * local_dir)


## World <-> model for points. With no model the model sits at the nose origin ahead of the body (identity at the origin the step got).
func to_model(p: Vector3) -> Vector3:
	if has_model():
		return _model.global_transform.affine_inverse() * p
	return _xf_basis.inverse() * (p - _body_origin())


func to_world(p: Vector3) -> Vector3:
	if has_model():
		return _model.global_transform * p
	return _body_origin() + _xf_basis * p


func _body_origin() -> Vector3:
	# The made-up model's origin is the head centre: the mouth minus the mouth offset.
	return _last_origin - _xf_basis * info.mouth


func _arm_order(arm: int) -> int:
	return arm


func _snapshot_from() -> void:
	for t in arms:
		if t.joints.size() == 15:
			t.from = t.joints.duplicate()
		elif has_model():
			t.from = _model.call("arm_joints", t.arm)
		else:
			t.from = _rest_shape(t.arm)
		t.joints = t.from.duplicate()
		t.aim = 0.0
		t.lock = null
		t.hit = false
		t.cracked = false
		t.judged = false
		t.first = false
		t.glow = 0.0


## The rig's own joints (what a settled arm rests on).
func _gait_joints(arm: int) -> PackedVector3Array:
	if gait_provider.is_valid():
		return gait_provider.call(arm)
	if has_model():
		return _model.call("arm_rest_joints", arm)
	return _rest_shape(arm)


## The made-up arm at rest: a lazy flare ahead.
func _rest_shape(arm: int) -> PackedVector3Array:
	var base := info.bases[arm]
	var radial := info.radials[arm]
	var length := info.arm_len[arm]
	var dir := (Vector3(0.0, 0.0, -1.0) * cos(0.45) + radial * sin(0.45)).normalized()
	var out := PackedVector3Array()
	for j in 15:
		out.append(base + dir * length * info.fracs[arm][j])
	return out


func _arm_for_fire(t: Tendril, lock: Lock, origin: Vector3, order: int, start: float, charge: float, x_world := Vector3.INF) -> void:
	t.lock = lock
	t.order = order
	t.start = start
	t.first = false
	t.whiff = lock == null
	var target_world := lock.pos if lock != null else x_world
	t.x_frozen = to_model(target_world)
	t.x_live = t.x_frozen
	var span := _span(charge)
	var dist := target_world.distance_to(origin)
	t.fly_s = cfg("whip_fly_s") * lerpf(0.7, 1.0, clampf(dist / maxf(span, 0.001), 0.0, 1.0))
	t.hit = lock != null
	t.cracked = false
	t.judged = false
	t.retract_s = cfg("whip_retract_s") if lock != null else cfg("whip_miss_retract_s")
	t.cock0 = t.joints.duplicate()
	t.phase = ArmPhase.COCKED


func _begin_retract(t: Tendril, seconds: float) -> void:
	t.ret0 = t.joints.duplicate() if not t.joints.is_empty() else _gait_joints(t.arm)
	t.phase = ArmPhase.RETRACT
	t.t = 0.0
	t.retract_s = maxf(seconds, 0.05)


func _advance_arms(dt: float) -> void:
	var charge := charge_now
	for t in arms:
		if t.phase == ArmPhase.REST:
			continue
		t.t += dt
		match t.phase:
			ArmPhase.COCKED:
				_cocked_step(t, dt, charge)
			ArmPhase.FLY:
				_fly_step(t, dt)
			ArmPhase.GLUE:
				_glue_step(t, dt)
			ArmPhase.RETRACT:
				_retract_step(t, dt)
		t.glow = move_toward(t.glow, _glow_target(t), dt * 8.0)


func _glow_target(t: Tendril) -> float:
	match t.phase:
		ArmPhase.COCKED:
			return (0.5 + 0.55 * charge_now) if t.lock != null else 0.25 + 0.3 * charge_now
		ArmPhase.FLY:
			return 1.6
		ArmPhase.GLUE:
			return 2.0 if t.hit else 0.8
	return 0.0


func _cocked_step(t: Tendril, dt: float, charge: float) -> void:
	var releasing := beat == Beat.LASH or beat == Beat.SETTLE
	var winding := 0.0
	if releasing:
		if _fire.has(t):
			if lash_s >= t.start:
				_begin_fly(t)
				_fly_step(t, 0.0)
				return
			winding = smoothstep(t.start - 0.05, t.start, lash_s)
		else:
			if lash_s >= t.start:
				_begin_retract(t, cfg("whip_retract_s") * 0.8)
				_retract_step(t, 0.0)
				return
	# Aim at the live target while held.
	if t.lock != null and not releasing:
		var to_t := to_model(t.lock.pos) - info.bases[t.arm]
		if to_t.length() > 0.001:
			t.aim_dir = to_t.normalized()
		t.aim = move_toward(t.aim, 0.85, dt * 3.0)
	elif not releasing:
		t.aim = move_toward(t.aim, 0.0, dt * 3.0)
	var open_t := clampf((t.t - t.delay) / maxf(cfg("whip_flare_s"), 0.001), 0.0, 1.0)
	var e := _ease_out_back(open_t)
	var c := clampf(charge + winding * (1.0 - charge) * 0.8, 0.0, 1.0)
	var cocked := _cocked_shape(t.arm, c, t.aim_dir if t.aim > 0.0 else Vector3.ZERO, t.aim, _clock, 0.012 * c)
	var out := PackedVector3Array()
	out.resize(15)
	for j in 15:
		out[j] = t.from[j].lerp(cocked[j], e)
	t.joints = out
	t.cock0 = out


func _begin_fly(t: Tendril) -> void:
	t.phase = ArmPhase.FLY
	t.t = 0.0
	t.cock0 = t.joints.duplicate()
	t.cracked = false
	if fx != null:
		fx.play(&"whoosh", to_world(info.bases[t.arm]), 1)


func _fly_step(t: Tendril, dt: float) -> void:
	var x := clampf(t.t / maxf(t.fly_s, 0.001), 0.0, 1.0)
	# The live target pulls the lash in (heat-seeking): the share grows as the arm closes.
	if t.lock != null:
		if _refresh_lock(t.lock):
			var homing := cfg("whip_homing")
			var live_model := to_model(t.lock.pos + t.lock.vel * (t.fly_s * (1.0 - x)))
			t.x_live = t.x_frozen.lerp(live_model, homing * smoothstep(0.0, 0.6, x))
		else:
			t.x_live = t.x_frozen
	else:
		t.x_live = t.x_frozen
	# The tip starts leaving at front = reach (not 1): the lash spreads over the whole flight instead of snapping in its last ticks.
	var w := 0.75
	var reach := 0.45
	var front := (reach + w) * pow(x, 1.3)
	var lash := _lash_shape(t.arm, t.x_live, t.t)
	var out := PackedVector3Array()
	out.resize(15)
	var fr: PackedFloat32Array = info.fracs[t.arm]
	for j in 15:
		var v := fr[j]
		var a := smoothstep(0.0, 1.0, clampf((front - v * reach) / w, 0.0, 1.0))
		out[j] = t.cock0[j].lerp(lash[j], a)
	_add_wave(out, t, t.t, 1.0 if x < 1.0 else 0.0)
	t.joints = out
	t.world_tip = to_world(out[14])
	if x >= 1.0 and not t.cracked:
		t.cracked = true
		t.phase = ArmPhase.GLUE
		t.t = 0.0
		t.ret0 = out.duplicate()
		_arrive(t)


func _glue_step(t: Tendril, dt: float) -> void:
	# A beat on the target: the tip rides it, the crack wave rings out, then the reel-in.
	var lash := _lash_shape(t.arm, t.x_live, 1.0)
	var out := PackedVector3Array()
	out.resize(15)
	for j in 15:
		out[j] = lash[j]
	_add_wave(out, t, cfg("whip_fly_s") + t.t, 0.0)
	t.joints = out
	t.world_tip = to_world(out[14])
	var hold_s := 0.06 if t.hit else 0.02
	if t.t >= hold_s:
		_begin_retract(t, t.retract_s)


func _retract_step(t: Tendril, dt: float) -> void:
	var x := clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0)
	var tgt := _gait_joints(t.arm)
	var w := 0.4
	var front := (1.0 + w) * (1.0 - pow(1.0 - x, 2.2))
	var fr: PackedFloat32Array = info.fracs[t.arm]
	var out := PackedVector3Array()
	out.resize(15)
	var ring := exp(-9.0 * x) * sin(x * 26.0) * 0.045 * info.arm_len[t.arm]
	var side := _side_dir(t.arm, tgt[14] - info.bases[t.arm])
	for j in 15:
		var v := fr[j]
		var b := smoothstep(0.0, 1.0, clampf((front - v) / w, 0.0, 1.0))
		var p := t.ret0[j].lerp(tgt[j], b)
		p += side * ring * v
		out[j] = p
	t.joints = out
	if x >= 1.0:
		t.phase = ArmPhase.REST
		t.joints = PackedVector3Array()
		t.lock = null
		if has_model():
			_restore_arm(_model, t.arm)


## The tip arrived: the crack, the judging and the recoil for this arm.
func _arrive(t: Tendril) -> void:
	var world_tip := to_world(t.joints[14])
	var from_world := to_world(info.bases[t.arm])
	var dir := (world_tip - from_world).normalized()
	var at := world_tip
	var hit := t.lock != null and t.hit
	if hit:
		hit = _refresh_lock(t.lock)  # eaten by an earlier arm's splash: it lands on the spot, a miss
	t.hit = hit
	if t.first:
		# The bite's own contact tick follows (the strike was let go this tick).
		pass
	elif hit:
		_judge_arm(t)
	# Recoil: summed over the arms, capped for the lash.
	var mag := cfg("whip_recoil") * (1.0 if hit else cfg("whip_miss_recoil")) * lerpf(0.65, 1.0, charge_now)
	var impulse := -dir * mag
	var cap := cfg("whip_recoil_cap")
	var room := maxf(cap - _recoil_spent, 0.0)
	if impulse.length() > room:
		impulse = impulse.limit_length(room)
	_recoil_spent += impulse.length()
	var scaled := impulse
	if _bite != null and is_instance_valid(_bite.fish):
		scaled *= pow(_bite.size.size_of(_bite.fish), _bite.size.speed_exp)
	recoil_total += scaled
	recoil_log.append({"arm": t.arm, "impulse": scaled, "hit": hit, "t": lash_s})
	if push_sink.is_valid():
		push_sink.call(scaled)
	elif _bite != null and is_instance_valid(_bite.fish) and not _bite.fish.puppet:
		_bite.fish.apply_push(scaled)
	if hit:
		hits_total += 1
		_flash = 1.0
		arm_hit.emit(t.arm, at)
	else:
		misses_total += 1
		arm_missed.emit(t.arm, at)
	if fx != null:
		fx.crack(at, dir, lerpf(0.7, 1.4, charge_now) * (1.0 if hit else 0.6), hit)
		fx.play(&"crack", at, hits_total)
		if hit:
			fx.play(&"hit", at, hits_total)
		else:
			fx.play(&"miss", at)
	if ex != null and t.first:
		ex.contact(clampf(float(_fire.size()) / 8.0 + 0.2, 0.2, 1.0) if hit else 0.25)


## Arms after the first take their fish when they land: the host judges (as the drill), nothing without a world.
func _judge_arm(t: Tendril) -> void:
	t.judged = true
	var bite := _bite
	if bite == null or bite.world == null or not is_instance_valid(bite.world) or t.lock == null:
		return
	var world := bite.world
	if not bool(world.get("authority")) or world.get("phase") != WhatStinksMatch.Phase.LIVE:
		return
	var centre := t.lock.pos
	var radius := _hit_radius(bite, charge_now)
	var inside := func(at: Vector3) -> bool: return at.distance_to(centre) <= radius
	world.call("judge_drill", bite.fish, bite, centre, _per_arm(bite, charge_now), inside)


func _on_landed(_taken: int) -> void:
	# The nearest arm's contact is done: nothing else to do (its recoil/crack ran when it landed).
	_stall = false


## Whether the nearest arm has landed and the bite's contact is due (a probe without a bite reads this).
func contact_due() -> bool:
	return beat == Beat.LASH and lash_s >= _contact_at


# ------------------------------------------------------------------------------ shapes (model space)

static func _ease_out_back(x: float) -> float:
	var c1 := 1.4
	var c3 := c1 + 1.0
	var u := x - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


## The unit plane-side vector for crack waves and ring-down: perpendicular to `toward` and the arm's ring tangent.
func _side_dir(arm: int, toward: Vector3) -> Vector3:
	var radial := info.radials[arm]
	var tangent := Vector3(-radial.y, radial.x, 0.0)
	var n := toward.cross(radial)
	if n.length_squared() < 0.0004:
		n = tangent
	return n.normalized()


func _add_wave(pts: PackedVector3Array, t: Tendril, tau: float, live: float) -> void:
	var amp := cfg("whip_wave") * info.arm_len[t.arm]
	if amp <= 0.0:
		return
	var fr: PackedFloat32Array = info.fracs[t.arm]
	var toward := pts[14] - pts[0]
	var side := _side_dir(t.arm, toward)
	var env := smoothstep(0.0, 0.25, tau / maxf(t.fly_s, 0.001)) * (1.0 if live > 0.0 else exp(-12.0 * maxf(tau - t.fly_s, 0.0)))
	for j in 15:
		var v := fr[j]
		pts[j] += side * amp * env * v * sin(TAU * (2.0 * v - 7.0 * tau))


## The cocked arm: a spiral that opens from the head out to the flare, coiling back toward the body; tighter with charge, and turned
## toward `aim_dir` by `aim`. 15 joints.
func _cocked_shape(arm: int, charge: float, aim_dir: Vector3, aim: float, time: float, tremble: float) -> PackedVector3Array:
	var base := info.bases[arm]
	var radial := info.radials[arm]
	var length := info.arm_len[arm]
	var forward := Vector3(0.0, 0.0, -1.0)
	var flare := deg_to_rad(cfg("whip_flare"))
	var d := (forward * cos(flare) + radial * sin(flare)).normalized()
	var tangent := Vector3(-radial.y, radial.x, 0.0)
	# Curl toward +Z (the coil cocks back): the sign of the rotation about the tangent.
	var probe := Basis(tangent, 0.1) * d
	var turn_sign := 1.0 if probe.z > d.z else -1.0
	var sweep := deg_to_rad(lerpf(cfg("whip_sweep_min"), cfg("whip_sweep_max"), clampf(charge, 0.0, 1.0)))
	var k := 1.0 + 0.06 * clampf(charge, 0.0, 1.0) + (ex.scale_of(&"limb") - 1.0) * 0.12 if ex != null else 1.0
	var steps := 28
	var ds := length * k / float(steps)
	var dense := PackedVector3Array()
	dense.append(base)
	var p := base
	var dir := d
	var prev_angle := 0.0
	for i in steps:
		var s := (float(i) + 0.5) / float(steps)
		var angle := sweep * pow(float(i + 1) / float(steps), 1.6) + tremble * sin(time * 38.0 + float(arm) * 1.7 + s * 5.0) * s
		var da := (angle - prev_angle) * turn_sign
		prev_angle = angle
		dir = (Basis(tangent, da) * dir).normalized()
		p += dir * ds
		dense.append(p)
	if aim > 0.0 and aim_dir.length_squared() > 0.5:
		var chord := (dense[steps] - base)
		if chord.length_squared() > 1e-6:
			var q := Quaternion(chord.normalized(), aim_dir.normalized())
			var turned := Quaternion.IDENTITY.slerp(q, clampf(aim, 0.0, 1.0))
			for i in dense.size():
				dense[i] = base + turned * (dense[i] - base)
	return _resample(dense, info.fracs[arm])


## The lash: a bezier from the base to the tip's goal `x` curving round toward it (swirling in), bowed when the goal is nearer than the
## arm is long, stretched (up to whip_stretch) when it is further. 15 joints.
func _lash_shape(arm: int, x: Vector3, _tau: float) -> PackedVector3Array:
	var base := info.bases[arm]
	var radial := info.radials[arm]
	var length := info.arm_len[arm]
	var to_x := x - base
	var dist := maxf(to_x.length(), 0.0001)
	var dir_x := to_x / dist
	var forward := Vector3(0.0, 0.0, -1.0)
	var start_dir := (forward * cos(deg_to_rad(cfg("whip_flare"))) + radial * sin(deg_to_rad(cfg("whip_flare")))).normalized()
	var d0 := start_dir.slerp(dir_x, 0.45).normalized()
	var swirl := _side_dir(arm, dir_x) * (0.16 * dist) * float(info.radials[arm].x if absf(info.radials[arm].x) > 0.1 else 1.0 > 0.0 and 1.0 or -1.0)
	var p0 := base
	var p1 := base + d0 * dist * 0.34 + swirl
	var p2 := x - dir_x * dist * 0.30 + swirl * 0.4
	var p3 := x
	var n := 40
	var dense := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var iu := 1.0 - u
		dense.append(p0 * iu * iu * iu + p1 * 3.0 * iu * iu * u + p2 * 3.0 * iu * u * u + p3 * u * u * u)
	var len_c := _poly_length(dense)
	var kmax := maxf(cfg("whip_stretch"), 1.0)
	if len_c < length:
		# Slack: bow the arm sideways (sin profile) so its length is kept.
		var h := (2.0 / PI) * sqrt(maxf(dist * (length - len_c), 0.0))
		var side := _side_dir(arm, dir_x)
		for i in dense.size():
			var u2 := float(i) / float(n)
			dense[i] += side * h * sin(PI * u2) * 0.9
		len_c = _poly_length(dense)
	var out := _resample(dense, info.fracs[arm], minf(len_c, kmax * length))
	return out


static func _poly_length(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


## `count` points at the cumulative shares `fracs` of a polyline's length (or of `use_length` of it from the start).
static func _resample(poly: PackedVector3Array, fracs: PackedFloat32Array, use_length := -1.0) -> PackedVector3Array:
	var total := _poly_length(poly)
	var span := total if use_length < 0.0 else minf(use_length, total)
	var out := PackedVector3Array()
	var seg := 1
	var walked := 0.0
	var seg_len := poly[1].distance_to(poly[0]) if poly.size() > 1 else 0.0
	for j in fracs.size():
		var want := fracs[j] * span
		while seg < poly.size() - 1 and walked + seg_len < want:
			walked += seg_len
			seg += 1
			seg_len = poly[seg].distance_to(poly[seg - 1])
		var u := clampf((want - walked) / maxf(seg_len, 0.000001), 0.0, 1.0)
		out.append(poly[seg - 1].lerp(poly[seg], u))
	return out


# ------------------------------------------------------------------------------ posing the model

## Poses every arm the lash owns on `octo` (an OctopusModel), blending with the rig: `gait` maps arm -> the rig's joints isn't needed
## since arms reel in to gait_provider. Returns the arms it drove (a rig leaves those alone).
func blend_pose(octo: Node3D) -> Array[int]:
	var driven: Array[int] = []
	for t in arms:
		if t.phase == ArmPhase.REST or t.joints.size() != 15:
			continue
		driven.append(t.arm)
		var result: Dictionary = Solver.solve(octo, t.arm, t.joints)
		octo.call("set_arm_pose", t.arm, result["bends"])
		Solver.apply_stretch(octo, t.arm, result["stretch"])
		if drive_model_fx and octo.has_method("set_arm_glow"):
			octo.call("set_arm_glow", t.arm, t.glow)
	if drive_model_fx and (beat != Beat.IDLE or _fx_dirty):
		_model_fx(octo)
		_fx_dirty = beat != Beat.IDLE
	return driven


func _model_fx(octo: Node3D) -> void:
	if octo.has_method("set_mantle_pulse"):
		octo.call("set_mantle_pulse", clampf(_mantle, -1.0, 1.0))
	var vis := charge_now if (beat == Beat.FLARE or beat == Beat.HOLD) else (0.0 if beat == Beat.IDLE else maxf(charge_now - lash_s * 2.0, 0.0))
	octo.call("set_charge", vis * 0.7)
	octo.call("set_sucker_glow", 0.15 + 1.0 * (vis if beat != Beat.IDLE else 0.0) + (0.5 if beat == Beat.FLARE else 0.0))
	octo.call("set_eye_glow", 0.35 + 0.9 * vis)
	octo.call("set_flash", _flash * 0.6)
	if beat == Beat.IDLE:
		octo.call("set_charge", 0.0)


func _restore_model(octo: Node3D) -> void:
	for a in 8:
		_restore_arm(octo, a)


func _restore_arm(octo: Node3D, arm: int) -> void:
	Solver.apply_stretch(octo, arm, PackedFloat32Array())
	if octo.has_method("set_arm_glow"):
		octo.call("set_arm_glow", arm, 0.0)


## The arms the lash is posing now.
func driven_arms() -> Array[int]:
	var out: Array[int] = []
	for t in arms:
		if t.phase != ArmPhase.REST:
			out.append(t.arm)
	return out


func arm_weight(arm: int) -> float:
	var t: Tendril = arms[arm]
	if t.phase == ArmPhase.REST:
		return 0.0
	if t.phase == ArmPhase.RETRACT:
		return 1.0 - smoothstep(0.85, 1.0, clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0))
	return 1.0


## Where arm `arm`'s tip is now (world).
func tip_world(arm: int) -> Vector3:
	var t: Tendril = arms[arm]
	if t.joints.size() == 15:
		return to_world(t.joints[14])
	return Vector3.INF


func joints_of(arm: int) -> PackedVector3Array:
	return (arms[arm] as Tendril).joints


## The mantle's squash (-1 .. 1 as OctopusModel.set_mantle_pulse), for a rig that drives it itself.
func mantle_pulse() -> float:
	return clampf(_mantle, -1.0, 1.0)


## Seconds into the lash when the last arm lands (0 before a release).
func lash_length() -> float:
	var latest := 0.0
	for t in _fire:
		latest = maxf(latest, t.start + t.fly_s)
	return latest


## True while any arm is out of its rest (the rig keeps its hands off those).
func busy() -> bool:
	for t in arms:
		if t.phase != ArmPhase.REST:
			return true
	return false


func _update_fx(origin: Vector3, forward: Vector3) -> void:
	if cfg("whip_aura") > 0.0 and (beat == Beat.FLARE or beat == Beat.HOLD):
		fx.aura(origin, forward, _span(charge_now), cfg("whip_cone"), _aura_sweep, charge_now)
	for l in locks:
		fx.set_lock(l.arm, l.pos, charge_now)
	if beat != Beat.FLARE and beat != Beat.HOLD:
		for a in 8:
			if not locks.any(func(l: Lock) -> bool: return l.arm == a):
				fx.hide_lock(a)
	for t in arms:
		if t.phase == ArmPhase.FLY and t.joints.size() == 15:
			var pts := PackedVector3Array()
			for j in 15:
				pts.append(to_world(t.joints[j]))
			fx.trail(t.arm, pts, 1.0)
		elif t.phase == ArmPhase.GLUE and t.joints.size() == 15:
			var pts2 := PackedVector3Array()
			for j in 15:
				pts2.append(to_world(t.joints[j]))
			fx.trail(t.arm, pts2, 0.6)
		else:
			fx.trail_off(t.arm)


## Wires an FX node (made by the rig or by tools).
func attach_fx(node: OctopusWhipFx) -> void:
	fx = node


# ------------------------------------------------------------------------------ joints -> bends

## Turns 15 model-space joints of an arm into the OctopusModel's per-segment bends (pitch, yaw, twist) and per-bone stretch.
## Each bone is rotated by the minimal rotation that points its child at the next joint, then twisted about the arm so the
## sucker side (+Y) faces the inside of the curve. Lengths come from the chords (the stretch), clamped.
class Solver extends RefCounted:
	const TWIST_STEP := 0.7  # rad per segment the sucker side may turn toward the inside
	const KMIN := 0.4
	const KMAX := 4.0

	static func solve(octo: Node3D, arm: int, joints: PackedVector3Array) -> Dictionary:
		var skeleton: Skeleton3D = octo.get("skeleton")
		var bones: PackedInt32Array = (octo.get("arm_bones") as Array)[arm]
		var head: int = int(octo.get("head_bone"))
		var parent_g: Transform3D = skeleton.get_bone_global_pose(head)
		var bends := PackedVector3Array()
		var stretch := PackedFloat32Array()
		bends.resize(14)
		stretch.resize(15)  # 14 bone offsets, then the last bone's own length (its scale along the arm)
		stretch[0] = 1.0
		stretch[14] = 1.0
		# Twist (sucker side inward) only as far as the shape departs from the rest curl: rest stays the identity, and a flipped inside at an
		# inflection turns gradually (rate-limited per segment) instead of pinching one bone by half a turn.
		var rest_pts: PackedVector3Array = octo.call("arm_rest_joints", arm)
		var dev := 0.0
		for jj in mini(joints.size(), rest_pts.size()):
			dev = maxf(dev, joints[jj].distance_to(rest_pts[jj]))
		var twist_gain := smoothstep(0.04, 0.30, dev / maxf(float(octo.call("arm_length", arm)), 0.001))
		var prev_ref := Vector3.ZERO
		var s_here := 1.0
		for j in 14:
			var rest: Transform3D = skeleton.get_bone_rest(bones[j])
			var rest_q := rest.basis.get_rotation_quaternion()
			var pre := Transform3D(parent_g.basis.orthonormalized() * Basis(rest_q), parent_g * (rest.origin * s_here))
			# The child's rest offset in this bone's (rest-rotated) frame.
			var child_local := _child_offset(skeleton, bones, j, octo, arm)
			var rest_len := maxf(child_local.length(), 0.00001)
			var origin := pre.origin
			var want := joints[j + 1] - origin
			var chord := joints[j + 1].distance_to(joints[j])
			if want.length_squared() < 1e-10:
				want = pre.basis * child_local
			var d := want.normalized()
			var local_dir := pre.basis.orthonormalized().inverse() * d
			var c_hat := child_local / rest_len
			var r := Quaternion(c_hat, local_dir.normalized())
			# Twist about the arm so +Y faces the curve's inside.
			var ref := prev_ref
			if j + 2 < joints.size():
				var d_next := (joints[j + 2] - joints[j + 1])
				if d_next.length_squared() > 1e-10:
					var turn := d_next.normalized() - d
					if turn.length() > 0.02:
						ref = turn.normalized()
			if ref.length_squared() > 0.0:
				var basis_now := pre.basis.orthonormalized() * Basis(r)
				var axis := basis_now * c_hat
				var y_now := basis_now.y
				var ref_p := (ref - axis * ref.dot(axis))
				if ref_p.length_squared() > 1e-6 and (y_now - axis * y_now.dot(axis)).length_squared() > 1e-6:
					var tw := (y_now - axis * y_now.dot(axis)).normalized().signed_angle_to(ref_p.normalized(), axis)
					r = r * Quaternion(c_hat, clampf(tw * twist_gain, -TWIST_STEP, TWIST_STEP))
			prev_ref = ref
			var e := Basis(r).get_euler(EULER_ORDER_YXZ)
			bends[j] = Vector3(e.x, e.y, e.z)
			var k := clampf(chord / rest_len, KMIN, KMAX)
			stretch[j + 1] = k
			var here := Transform3D(pre.basis.orthonormalized() * Basis(r), origin)
			parent_g = here
			s_here = k
		return {"bends": bends, "stretch": stretch}

	## Bone j's child offset (child origin in the bone's own rest frame): the next bone's rest origin, or for the last the rest tip.
	static func _child_offset(skeleton: Skeleton3D, bones: PackedInt32Array, j: int, octo: Node3D, arm: int) -> Vector3:
		if j + 1 < 14:
			return skeleton.get_bone_rest(bones[j + 1]).origin
		var rest_joints: PackedVector3Array = octo.call("arm_rest_joints", arm)
		var g_rest: Transform3D = skeleton.get_bone_global_rest(bones[j])
		return g_rest.basis.orthonormalized().inverse() * (rest_joints[14] - rest_joints[13])

	## Writes the stretch as bone positions (empty: back to rest).
	static func apply_stretch(octo: Node3D, arm: int, stretch: PackedFloat32Array) -> void:
		var skeleton: Skeleton3D = octo.get("skeleton")
		var bones: PackedInt32Array = (octo.get("arm_bones") as Array)[arm]
		for j in range(1, 14):
			var rest: Transform3D = skeleton.get_bone_rest(bones[j])
			var s := 1.0 if stretch.is_empty() else stretch[j]
			skeleton.set_bone_pose_position(bones[j], rest.origin * s)
		var tip_k := 1.0 if stretch.size() < 15 else clampf(stretch[14], 0.4, KMAX)
		skeleton.set_bone_pose_scale(bones[13], Vector3(1.0, 1.0, tip_k))

	## The joints the model's chain gives for these bends and stretches (the solver's inverse; for probes).
	static func forward(octo: Node3D, arm: int, bends: PackedVector3Array, stretch: PackedFloat32Array) -> PackedVector3Array:
		var skeleton: Skeleton3D = octo.get("skeleton")
		var bones: PackedInt32Array = (octo.get("arm_bones") as Array)[arm]
		var head: int = int(octo.get("head_bone"))
		var g: Transform3D = skeleton.get_bone_global_pose(head)
		var out := PackedVector3Array()
		for j in 14:
			var rest: Transform3D = skeleton.get_bone_rest(bones[j])
			var s := 1.0 if j == 0 or stretch.is_empty() else stretch[j]
			var rest_q := rest.basis.get_rotation_quaternion()
			var q := Quaternion(Vector3.UP, bends[j].y) * Quaternion(Vector3.RIGHT, bends[j].x) * Quaternion(Vector3.BACK, bends[j].z)
			g = Transform3D(g.basis.orthonormalized() * Basis(rest_q * q), g * (rest.origin * s))
			out.append(g.origin)
		var rest_joints: PackedVector3Array = octo.call("arm_rest_joints", arm)
		var g_rest: Transform3D = skeleton.get_bone_global_rest(bones[13])
		out.append(g * (g_rest.basis.orthonormalized().inverse() * (rest_joints[14] - rest_joints[13])))
		return out
