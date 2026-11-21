class_name AttackExaggerate
extends RefCounted
## Reusable "make the Hunter's bite bold" tool (planning_new_hunters.md phase B). A rig owns one, calls the beats of
## the two-stage attack on it and reads back per-part scales every frame. Pure maths, no nodes, no timers: the rig drives
## it with tick(delta), so it is deterministic, probe-able and works on puppets (the host's beats) as well as the local fish.
##
##   press()            anticipation squash, then the swell toward the hold size
##   hold(charge)       call each tick while held: the swell target follows the 0..1 charge
##   release(charge)    the snap: every part kicks to its release size, then rings out and settles (overshoot)
##   contact(strength)  the bite landed: hit-stop on this rig only + the camera punch signal
##   abort()            let go with no snap (cancelled / denied): everything eases back to rest
##
## Parts are named channels: jaw, head, tail, limb, throat (add_channel() makes more). Each is a damped spring on a
## scale factor. The master multiplier `hunter_exaggeration` (0 off, 1 bold, 2 extreme) times the form's own multiplier
## scales how far every channel departs from rest (1.0): at 1 the peaks are 1.5-2.5x. 0 is exactly 1.0 always.
##
## Reading it (every frame, after tick):
##   scale_of(&"jaw")                 -> float, uniform scale
##   scale_basis(&"tail", Vector3.BACK) -> Basis stretching along that LOCAL axis, thinning across it (volume kept),
##                                       with a smear stretch that grows with how fast the part is changing
##   apply(node, &"head", axis)       -> sets node.scale for you (node.scale = scale_basis diagonal; for axis-aligned parts)
##   local_dt(delta)                  -> delta, or ~0 during hit-stop: feed the rig's OWN animation clock with it
##   peak_scale() / camera_margin(r)  -> current largest scale, and a collision radius padded for it (cameras)
##
## Example (a jaw rig):
##   var ex := AttackExaggerate.new(AttackExaggerate.params_from(settings, form_dict))
##   ex.camera_punch.connect(func(amount, dir): camera.punch(amount, dir))
##   # on press:  ex.press()          # each tick while held: ex.hold(bite.charge())
##   # on release: ex.release(bite.charge())    # on landed: ex.contact(share)
##   # every frame:
##   var dt := ex.tick(delta)         # advances springs, returns the hit-stop-aware delta for your own animation clock
##   jaw_node.scale = Vector3.ONE * ex.scale_of(&"jaw")
##   head_node.basis = base_basis * ex.scale_basis(&"head", Vector3.FORWARD)
##
## Every number lives in the params Dictionary (DEFAULTS below); pass only what you change, e.g.
## AttackExaggerate.new({"channels": {"jaw": {"hold_peak": 2.4}}, "antic_time": 0.18}).

## The camera should push in / shake by `amount` (0..~1.5, already scaled by exaggeration); `dir` is world-space or ZERO.
signal camera_punch(amount: float, dir: Vector3)
## Hit-stop began on this rig for `frames` ticks (rigs freeze their animation clock via local_dt()).
signal hit_stopped(frames: int)
## The release snap just started (the moment to fire one-shot effects tied to the pop).
signal snapped

enum Phase { IDLE, ANTICIPATE, HOLD, SNAP, SETTLE }

const CHANNELS: Array[StringName] = [&"jaw", &"head", &"tail", &"limb", &"throat"]
const STEP := 1.0 / 120.0
const EPS := 0.004

## Defaults for everything. "channels" merge per channel and per key; the rest replace.
const DEFAULTS := {
	# Master (the panel's hunter_exaggeration) and the form's own multiplier. 0 = everything stays exactly 1.0.
	"master": 1.0,
	"form_mult": 1.0,
	# Timing (seconds). antic_time: the squash dip before the swell. snap_time: how long the release target is held.
	"antic_time": 0.12,
	"snap_time": 0.07,
	# How much of the swell the hold keeps at zero charge (the rest comes with charge).
	"hold_floor": 0.45,
	# Anticipation depth multiplier (x each channel's squash departure). 0 = no squash.
	"squash_mult": 1.0,
	# Smear: extra stretch along the axis per unit of scale-speed (per second), and how much of it perpendicular thinning keeps.
	"smear": 0.05,
	"smear_max": 0.6,
	# Hit-stop on contact: frames (ticks of tick() at any rate), scaled by min(exaggeration, hit_stop_cap), and the
	# fraction of normal time that passes during it (0 = full freeze).
	"hit_stop_frames": 2.5,
	"hit_stop_time_scale": 0.05,
	"hit_stop_cap": 1.5,
	# Camera punch emitted on contact: base amount x (0.6 + 0.8 charge) x exaggeration; 0 disables.
	"camera_punch": 0.5,
	# Hard limits on any channel after the multiplier (camera safety / mesh sanity).
	"max_scale": 3.5,
	"min_scale": 0.35,
	# Per channel: hold_peak (size at full charge), squash (anticipation dip), release_peak (size at the snap),
	# omega (spring rad/s, settle), zeta (damping ratio < 1 rings = overshoot), volume (0..1 thinning across the axis).
	"channels": {
		"jaw": {"hold_peak": 2.2, "squash": 0.82, "release_peak": 0.82, "omega": 24.0, "zeta": 0.38, "volume": 0.2},
		"head": {"hold_peak": 1.5, "squash": 0.88, "release_peak": 1.5, "omega": 20.0, "zeta": 0.42, "volume": 0.5},
		"tail": {"hold_peak": 1.3, "squash": 0.9, "release_peak": 1.8, "omega": 18.0, "zeta": 0.35, "volume": 0.5},
		"limb": {"hold_peak": 1.4, "squash": 0.88, "release_peak": 1.6, "omega": 22.0, "zeta": 0.4, "volume": 0.4},
		"throat": {"hold_peak": 2.4, "squash": 0.85, "release_peak": 0.8, "omega": 16.0, "zeta": 0.45, "volume": 0.3},
	},
	# Spring stiffness while a snap target is held (rad/s, ratio).
	"snap_omega": 46.0,
	"snap_zeta": 0.75,
}


## One spring. x is the raw scale (1 = rest) before the multiplier.
class Channel extends RefCounted:
	var x := 1.0
	var v := 0.0
	var target := 1.0
	var omega := 20.0
	var zeta := 0.4
	var cfg: Dictionary = {}

	func step(dt: float) -> void:
		var w2 := omega * omega
		v += (-w2 * (x - target) - 2.0 * zeta * omega * v) * dt
		x += v * dt


var params: Dictionary
var phase: Phase = Phase.IDLE
var channels := {}
var charge := 0.0
## The multiplier in force (master x form_mult), kept so probes and cameras can read it.
var strength := 1.0
var _t := 0.0
var _stop_left := 0
var _stop_scale := 0.05
var _peak := 1.0


func _init(preset: Dictionary = {}) -> void:
	params = merged(DEFAULTS, preset)
	strength = maxf(0.0, float(params["master"]) * float(params["form_mult"]))
	for key in params["channels"]:
		add_channel(StringName(key), params["channels"][key])


## Params for a form: the panel's master and tuning (any object with those properties: WhatStinksSettings) and the form
## sheet's own `exaggeration` multiplier (default 1) over an optional per-form preset (`exaggerate` Dictionary).
static func params_from(settings: Object, form: Dictionary = {}) -> Dictionary:
	var out: Dictionary = merged({}, form.get("exaggerate", {}))
	out["master"] = _setting(settings, "hunter_exaggeration", 1.0)
	out["form_mult"] = float(form.get("exaggeration", 1.0))
	out["hit_stop_frames"] = _setting(settings, "hunter_hit_stop_frames", DEFAULTS["hit_stop_frames"])
	out["camera_punch"] = _setting(settings, "hunter_camera_punch", DEFAULTS["camera_punch"])
	out["squash_mult"] = _setting(settings, "hunter_exaggerate_squash", 1.0)
	out["smear"] = _setting(settings, "hunter_exaggerate_smear", DEFAULTS["smear"])
	out["max_scale"] = _setting(settings, "hunter_exaggerate_max_scale", DEFAULTS["max_scale"])
	return out


static func _setting(settings: Object, id: String, fallback: Variant) -> float:
	if settings != null:
		var got: Variant = settings.get(id)
		if got != null:
			return float(got)
	return float(fallback)


## Recursive Dictionary merge (b over a), returning a new one.
static func merged(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b:
		if out.has(key) and out[key] is Dictionary and b[key] is Dictionary:
			out[key] = merged(out[key], b[key])
		else:
			out[key] = b[key].duplicate(true) if (b[key] is Dictionary or b[key] is Array) else b[key]
	return out


## Add (or replace) a named channel; `cfg` as in DEFAULTS["channels"] (missing keys come from the head channel's).
func add_channel(id: StringName, cfg: Dictionary = {}) -> void:
	var base: Dictionary = DEFAULTS["channels"]["head"]
	var c := Channel.new()
	c.cfg = merged(base, cfg)
	c.omega = float(c.cfg["omega"])
	c.zeta = float(c.cfg["zeta"])
	channels[id] = c


func set_strength(master: float, form_mult := 1.0) -> void:
	strength = maxf(0.0, master * form_mult)
	params["master"] = master
	params["form_mult"] = form_mult


## The press: anticipation squash, then the swell.
func press() -> void:
	phase = Phase.ANTICIPATE
	_t = 0.0
	charge = 0.0
	var squash := float(params["squash_mult"])
	for id in channels:
		var c: Channel = channels[id]
		c.target = 1.0 + (float(c.cfg["squash"]) - 1.0) * squash
		_use_settle(c)
	# The dip is a quick move: stiffen the springs so it lands within antic_time.
	for id in channels:
		var c2: Channel = channels[id]
		c2.omega = maxf(c2.omega, 30.0)


## While held: the swell follows the charge (0..1). Safe to call every tick in any phase; only acts in ANTICIPATE/HOLD.
func hold(with_charge: float) -> void:
	charge = clampf(with_charge, 0.0, 1.0)
	if phase == Phase.ANTICIPATE or phase == Phase.HOLD:
		if phase == Phase.HOLD:
			_hold_targets()


## The release: every channel snaps to its release size, then rings out to rest. `with_charge` (0..1) scales the pop.
func release(with_charge := 1.0) -> void:
	charge = clampf(with_charge, 0.0, 1.0)
	phase = Phase.SNAP
	_t = 0.0
	var pop := lerpf(0.55, 1.0, charge)
	for id in channels:
		var c: Channel = channels[id]
		c.target = 1.0 + (float(c.cfg["release_peak"]) - 1.0) * pop
		c.omega = float(params["snap_omega"])
		c.zeta = float(params["snap_zeta"])
	snapped.emit()


## The bite landed: hit-stop on this rig (frames scaled by exaggeration, capped) and the camera punch.
## `share` is 0..1 (how much was caught); a miss passes a small one.
func contact(share := 1.0) -> void:
	var frames := float(params["hit_stop_frames"]) * minf(strength, float(params["hit_stop_cap"]))
	var count := int(roundf(frames))
	if strength > 0.0 and count > 0:
		_stop_left = count
		_stop_scale = float(params["hit_stop_time_scale"])
		hit_stopped.emit(count)
	var amount := float(params["camera_punch"]) * strength * (0.6 + 0.8 * clampf(charge, 0.0, 1.0)) * (0.5 + 0.5 * clampf(share, 0.0, 1.0))
	if amount > 0.0:
		camera_punch.emit(amount, Vector3.ZERO)


## Cancelled / denied: no snap, everything eases back to rest.
func abort() -> void:
	phase = Phase.SETTLE
	for id in channels:
		var c: Channel = channels[id]
		c.target = 1.0
		_use_settle(c)
	charge = 0.0


## Back to rest at once (a respawn, a form swap).
func reset() -> void:
	phase = Phase.IDLE
	charge = 0.0
	_stop_left = 0
	for id in channels:
		var c: Channel = channels[id]
		c.x = 1.0
		c.v = 0.0
		c.target = 1.0
		_use_settle(c)
	_peak = 1.0


## Advance by `delta` (real seconds). Returns the hit-stop-aware delta the rig should use for its own animation clock.
func tick(delta: float) -> float:
	var dt := local_dt(delta)
	if _stop_left > 0:
		_stop_left -= 1
	_advance_phase(dt)
	var left := dt
	while left > 0.0:
		var h := minf(left, STEP)
		for id in channels:
			(channels[id] as Channel).step(h)
		left -= h
	_peak = _compute_peak()
	if phase == Phase.SETTLE and _at_rest():
		phase = Phase.IDLE
	return dt


## `delta`, or the hit-stop's fraction of it while a hit-stop is running. Does not advance the stop.
func local_dt(delta: float) -> float:
	return delta * _stop_scale if _stop_left > 0 else delta


func in_hit_stop() -> bool:
	return _stop_left > 0


func hit_stop_left() -> int:
	return _stop_left


## The scale of a channel after the multipliers and limits (1.0 for an unknown channel).
func scale_of(id: StringName) -> float:
	if not channels.has(id):
		return 1.0
	return _out((channels[id] as Channel).x)


## How fast the channel's scale is changing now, per second (after the multiplier).
func speed_of(id: StringName) -> float:
	if not channels.has(id):
		return 0.0
	return absf((channels[id] as Channel).v) * strength


## Stretch of a channel along `axis` (a LOCAL unit vector): a symmetric Basis. The part grows by scale_of() along the
## axis (plus a smear stretch while it is moving fast) and thins across it by scale^-volume/2 so the mass reads as kept.
func scale_basis(id: StringName, axis: Vector3) -> Basis:
	if not channels.has(id):
		return Basis.IDENTITY
	var c: Channel = channels[id]
	var s := _out(c.x)
	var smear := minf(float(params["smear"]) * absf(c.v) * strength, float(params["smear_max"]))
	var along := s * (1.0 + smear)
	var across := pow(maxf(s, 0.05), -0.5 * float(c.cfg["volume"])) * (1.0 - 0.5 * smear / (1.0 + smear))
	var a := axis.normalized()
	# M = across * I + (along - across) * a aT  (a aT has columns a * a_i)
	var k := along - across
	return Basis(
		Vector3(across, 0, 0) + a * (a.x * k),
		Vector3(0, across, 0) + a * (a.y * k),
		Vector3(0, 0, across) + a * (a.z * k))


## Sets `node.scale` from the channel for a part whose stretch axis is one of its own local axes.
func apply(node: Node3D, id: StringName, axis: Vector3 = Vector3.ONE) -> void:
	if axis == Vector3.ONE:
		node.scale = Vector3.ONE * scale_of(id)
		return
	var b := scale_basis(id, axis)
	node.scale = Vector3(b.x.length(), b.y.length(), b.z.length())


## Largest scale any channel has right now (>= 1 visually; cameras use it).
func peak_scale() -> float:
	return _peak


## The largest scale this setup can ever show (all channels at their peaks, clamped): the worst-case collision margin.
func potential_peak() -> float:
	var best := 1.0
	for id in channels:
		var c: Channel = channels[id]
		best = maxf(best, _out(maxf(float(c.cfg["hold_peak"]), float(c.cfg["release_peak"]))))
	return best


## A camera collision radius padded for the exaggeration now (`peak_scale()` x radius), never below the radius.
func camera_margin(radius: float) -> float:
	return radius * maxf(1.0, _peak)


func idle() -> bool:
	return phase == Phase.IDLE


func _out(raw: float) -> float:
	return clampf(1.0 + (raw - 1.0) * strength, float(params["min_scale"]), float(params["max_scale"]))


func _use_settle(c: Channel) -> void:
	c.omega = float(c.cfg["omega"])
	c.zeta = float(c.cfg["zeta"])


func _hold_targets() -> void:
	var floor_share := float(params["hold_floor"])
	for id in channels:
		var c: Channel = channels[id]
		c.target = 1.0 + (float(c.cfg["hold_peak"]) - 1.0) * lerpf(floor_share, 1.0, charge)


func _advance_phase(dt: float) -> void:
	_t += dt
	match phase:
		Phase.ANTICIPATE:
			if _t >= float(params["antic_time"]):
				phase = Phase.HOLD
				for id in channels:
					_use_settle(channels[id] as Channel)
				_hold_targets()
		Phase.SNAP:
			if _t >= float(params["snap_time"]):
				phase = Phase.SETTLE
				for id in channels:
					var c: Channel = channels[id]
					c.target = 1.0
					_use_settle(c)


func _at_rest() -> bool:
	for id in channels:
		var c: Channel = channels[id]
		if absf(c.x - 1.0) > EPS or absf(c.v) > EPS * 4.0:
			return false
	return true


func _compute_peak() -> float:
	var best := 1.0
	for id in channels:
		best = maxf(best, _out((channels[id] as Channel).x))
	return best
