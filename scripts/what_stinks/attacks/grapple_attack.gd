class_name GrappleAttack
extends HunterAttack
## The Ember Octopus' style, "grapple" (planning_hunter_refine.md, user decision 2): grab, get towed, reel in.
##
##   PRESS    one arm shoots out and latches on the nearest fish in reach (a school fish or a prey player). Reach is a sphere round
##            the beak biased forward: grapple_reach arm lengths ahead, grapple_behind of that straight behind; nearer and squarer
##            to the nose ranks first (grapple_front_bias). Nothing in reach: the arm waits, the hold keeps looking.
##   HOLD     the octopus is towed behind what it holds. The fish are never touched: the octopus' own FishController is steered
##            each physics tick (a rope: slack inside grapple_tow_slack x the tow length, taut beyond it, pulling toward a weighted
##            blend of the fish held, matching their speed), its jet scaled down (grapple_tow_thrust) so its own swim only adds a
##            little steering. While the button stays down a free arm grabs another fish in reach every grapple_regrab_s, up to
##            grapple_arms. A fish further than grapple_max_stretch arm lengths from its arm's base tears loose (the arm snaps back).
##            A prey player tears the arm off with a dash (boost), or by turning hard for a moment (grapple_break_turn deg/s for
##            grapple_break_steer_s), or by leaving its school when joined; it is then immune for a beat.
##   RELEASE  every held arm yanks taut (grapple_yank_s: the strike waits for it), then the beak takes everything held at once
##            (one bite, judged through the bite's own contact tick: catch_rule takes exactly the held fish, grapple_per_arm each),
##            the arms reel the catch in to the beak and settle onto the rig's gait. A tap with nothing held whiffs: one arm flicks
##            out and back.
##
## The core (press / step / release / contact) works without a HunterBite or a model, in the octopus' model space (-Z ahead, the
## arm bases and lengths from an OctopusModel, else a made-up ring: WhipAttack.Info), so it can be probed headless. With a model the
## arm shapes are posed through WhipAttack.Solver (joints -> bends + bone stretch), blended over the rig's gait the way the lash is
## (the rig calls blend_pose after its own pose; arms reel in to its gait_joints). Shapes are built from the arms' actual bases and
## gait joints, never assuming which way the arms rest.
##
## Online: the machine that owns the Hunter grabs, tows and judges (its release's net_extra names what it held; the host judges a
## guest's from that). Others show a puppet that follows the owner's grips (net_state / apply_net_state, sent by WhatStinksNet).
## Every value is read through cfg(): tune (a probe's), then the panel (WhatStinksSettings, same name), then DEFAULTS.

## An arm closed on a fish (world position).
signal grabbed(arm: int, at: Vector3)
## An arm let go of its fish: `why` is "torn" (the prey broke free), "stretch" (too far), "gone" (eaten or out of play) or "net".
signal let_go(arm: int, at: Vector3, why: String)
## The beak took `count` held fish (the contact).
signal ate(count: int)
## A tap with nothing held: an arm flicked at nothing.
signal whiffed(arm: int, at: Vector3)

enum Beat { IDLE, HOLD, REEL }
enum ArmPhase { REST, REACH, LATCHED, YANK, REEL, RETRACT }

## Every value, with the panel id the settings take.
const DEFAULTS := {
	"grapple_arms": 8.0,             # most fish held at once (one per arm)
	"grapple_reach": 1.35,           # x an arm's length: how far ahead of the beak a free arm reaches for a fish
	"grapple_behind": 0.45,          # share of that reach left straight behind the beak (the sphere sits forward)
	"grapple_front_bias": 0.6,       # how much squareness to the nose counts against distance when picking (0: nearest wins)
	"grapple_latch_s": 0.16,         # seconds for an arm to shoot out to a fish at full reach (nearer is quicker)
	"grapple_regrab_s": 0.3,         # seconds between grabs while held
	"grapple_tow_length": 0.9,       # x arm length: the rope's length, the gap the octopus trails at
	"grapple_tow_slack": 0.6,        # share of the tow length inside which the rope is slack (no tow)
	"grapple_tow_stiffness": 4.0,    # 1/s: how hard a taut rope closes a stretch past the tow length (m/s per m)
	"grapple_tow_follow": 0.9,       # share of the fish's sideways speed a taut rope matches
	"grapple_tow_response": 10.0,    # 1/s: how fast the tow brings the octopus' velocity round
	"grapple_tow_thrust": 0.35,      # x the octopus' own jet while it holds a fish
	"grapple_max_stretch": 2.2,      # x arm length: a fish further than this from its arm's base tears loose
	"grapple_prey_weight": 2.0,      # a prey player's weight in the tow blend (a school fish is 1)
	"grapple_break_dash": 1.0,       # 1: a prey's dash (boost) tears the arm off (0: it does not)
	"grapple_break_rel": 9.0,        # m/s: a prey on another machine dashes when it pulls away this much faster than the octopus
	"grapple_break_turn": 120.0,     # deg/s: a prey turning at least this fast is counter-steering...
	"grapple_break_steer_s": 0.5,    # ...and tears free after this long of it (0: steering never frees it)
	"grapple_break_immune_s": 1.2,   # s a prey that tore free cannot be grabbed again
	"grapple_per_arm": 1.0,          # fish each held arm eats on the release
	"grapple_eat_radius": 0.0,       # x bite radius round each held fish its arm also takes from (with grapple_per_arm > 1)
	"grapple_yank_s": 0.1,           # s from the release to the beak's snap (the arms yank taut first)
	"grapple_stall_max": 0.35,       # most the snap waits for an arm still reaching
	"grapple_reel_s": 0.32,          # s an arm takes to reel its catch in to the beak
	"grapple_retract_s": 0.3,        # s an arm takes to settle back after letting go
	"grapple_whiff_s": 0.3,          # s a whiffing arm takes out and back
	"grapple_sag": 0.55,             # how much a slack arm sags (1: it keeps its length)
	"grapple_tremble": 0.025,        # a taut arm's tremble (x arm length)
	"grapple_lunge": 0.0,            # HunterBite.lunge_gain while grappling
	"grapple_bot_want": 4.0,         # a Hunter bot lets go once it holds this many...
	"grapple_bot_hold_s": 2.5,       # ...or has held something this long
	"grapple_bot_break": 0.65,       # chance a grabbed prey bot tries to tear free
	"grapple_bot_react_s": 0.4,      # s before it does
}
## Seconds a prey's grabbed cue takes to fade after the arm lets go.
const CUE_FADE_S := 0.4

## A probe's overrides (win over the panel).
var tune: Dictionary = {}
## Pose the model every tick (a rig that blends with its own gait sets this false and calls blend_pose()).
var auto_pose := true
## Drive the sucker / eye / flash glow on the model.
var drive_model_fx := true
## () -> Array of candidate dictionaries {"key": int, "pos": Vector3, "vel": Vector3, + "prey": FishController} (a probe's); empty: the match.
var target_source := Callable()
## (arm: int) -> PackedVector3Array: the rig's own joints for an arm (model space, 15). Default: the model's current or rest joints.
var gait_provider := Callable()
## A puppet following the owner's grips (set by apply_net_state): it grabs nothing itself and judges no break.
var net_driven := false
## Goes up whenever what the arms hold changes (WhatStinksNet sends net_state then).
var net_version := 0

var beat := Beat.IDLE
var arms: Array[Tentacle] = []
var info: WhipAttack.Info
var ex: AttackExaggerate
var fx: OctopusGrappleFx
## Seconds since the press / since the release.
var held_s := 0.0
var reel_t := 0.0
## Running totals (probes, HUD).
var grabs_total := 0
var eaten_total := 0
var tears_total := 0
var snaps_total := 0
var whiffs := 0
## The tow this tick: the velocity change put on the octopus, and how taut the rope is (0 slack .. 1).
var tow_push := Vector3.ZERO
var tow_taut := 0.0
var tow_anchor := Vector3.INF

## Prey instance id -> [physics frame last held, the Hunter's beak (world)] (the HUD's cue and the prey bot's struggle).
static var _cues := {}

var _bite: HunterBite
var _wired: HunterBite
var _model: Node3D
var _model_wait := 0.0
var _regrab := 0.0
var _immune := {}
var _clock := 0.0
var _dt := 0.0
var _stall := false
var _contact_at := 0.0
var _contact_taken := false
var _taken: Array[Grip] = []
var _beaked := false
var _flash := 0.0
var _xf_basis := Basis.IDENTITY
var _last_origin := Vector3.ZERO
var _last_forward := Vector3(0.0, 0.0, -1.0)
var _raised := 1.0
var _thrust_mult := 1.0
var _thrust_rig: Object
var _fx_dirty := false


func _init() -> void:
	key = "grapple"
	info = WhipAttack.Info.new()
	for a in 8:
		arms.append(Tentacle.new(a))


## What one arm holds.
class Grip extends RefCounted:
	var key := 0
	var school: School
	var index := -1
	var prey: FishController
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	## A prey that was in a school when grabbed (leaving it is its dash).
	var joined := false
	## Seconds it has been counter-steering, and its nose last tick (the turn rate).
	var steer_s := 0.0
	var heading := Vector3.ZERO


## One arm's state.
class Tentacle extends RefCounted:
	var arm := 0
	var phase := ArmPhase.REST
	var t := 0.0
	var grip: Grip
	var from := PackedVector3Array()   # the joints when the reach began (model space)
	var ret0 := PackedVector3Array()   # the joints when the retract began
	var joints := PackedVector3Array() # what the arm shows now
	var reach_s := 0.15
	var goal := Vector3.ZERO           # world: a whiff's point
	var goal_m := Vector3.ZERO         # model space: where the catch was taken (the reel starts there)
	var whiff := false
	var taut := 0.0
	var glow := 0.0
	var retract_s := 0.3

	func _init(index: int) -> void:
		arm = index


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


# ------------------------------------------------------------------------------ the prey's side (static: the HUD and bots ask)

## 0..1 how grabbed `fish` is now (1 while an arm holds it, fading out after): the HUD's cue.
static func grip_level(fish: Object) -> float:
	if fish == null or not is_instance_valid(fish):
		return 0.0
	var entry: Array = _cues.get(fish.get_instance_id(), [])
	if entry.is_empty():
		return 0.0
	var age := float(Engine.get_physics_frames() - int(entry[0])) / maxf(float(Engine.physics_ticks_per_second), 1.0)
	return clampf(1.0 - maxf(age - 0.05, 0.0) / CUE_FADE_S, 0.0, 1.0)


## Whether an arm holds `fish` this tick.
static func gripped_now(fish: Object) -> bool:
	if fish == null or not is_instance_valid(fish):
		return false
	var entry: Array = _cues.get(fish.get_instance_id(), [])
	return not entry.is_empty() and Engine.get_physics_frames() - int(entry[0]) <= 2


## Where the beak holding `fish` is (world), INF when nothing does.
static func grip_from(fish: Object) -> Vector3:
	if not gripped_now(fish):
		return Vector3.INF
	return (_cues[fish.get_instance_id()] as Array)[1]


static func reset_cues() -> void:
	_cues.clear()


# ------------------------------------------------------------------------------ model

func attach_model(model: Node3D) -> void:
	_model = model
	if model != null:
		info.adopt(model)
		var rig := model.get_parent()  # an OctopusRig: it owns the gait, runs blend_pose after its own pose, the arms settle on its joints
		if rig != null and rig.has_method("gait_joints"):
			auto_pose = false
			gait_provider = Callable(rig, "gait_joints")
			rig.set("lash", self)
	else:
		info.synth(info.length)


func has_model() -> bool:
	return _model != null and is_instance_valid(_model) and _model.is_inside_tree()


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
		if beat != Beat.HOLD and is_instance_valid(bite.fish):
			press(bite.mouth_point(), _forward_of(bite), bite.fish.global_basis)  # a tap: no press hook ran
		release(charge))
	bite.aborted.connect(func() -> void: abort())
	if not has_model() and is_instance_valid(bite.fish):
		info.synth(bite.fish.hitbox_length)
	_find_model(bite)
	if fx == null:
		fx = OctopusGrappleFx.new()
		fx.name = "OctopusGrappleFx"
		bite.add_child(fx)
		fx.hb = bite


func _find_model(bite: HunterBite) -> void:
	if has_model() or not is_instance_valid(bite.fish):
		return
	var visual: Node = bite.fish.get("_visual")
	var found := WhipAttack._search(visual if visual != null else bite.fish)
	if found != null:
		attach_model(found)


func _forward_of(bite: HunterBite) -> Vector3:
	return -bite.fish.global_basis.z.normalized() if is_instance_valid(bite.fish) else Vector3(0.0, 0.0, -1.0)


# ------------------------------------------------------------------------------ bite hooks

func on_open(bite: HunterBite) -> void:
	_wire(bite)
	_find_model(bite)
	bite.lunge_gain = cfg("grapple_lunge")
	press(bite.mouth_point(), _forward_of(bite), bite.fish.global_basis)


func on_hold(bite: HunterBite, _delta: float) -> void:
	_wire(bite)
	if ex != null:
		ex.hold(bite.charge())


func on_tick(bite: HunterBite, delta: float) -> void:
	_wire(bite)
	if not has_model():
		_model_wait -= delta
		if _model_wait <= 0.0:
			_model_wait = 1.0
			_find_model(bite)
	# Hold the strike until the arms have yanked (the contact tick is the beak's snap on everything held).
	var b := bite.bite
	if _stall and b != null and b.phase == ChompKit.Phase.STRIKE and not b.landed:
		if reel_t >= minf(_contact_at, cfg("grapple_stall_max")):
			var strike := maxf(b.duration(ChompKit.Phase.STRIKE), 0.0001)
			var shut: float = 1.0 - b.settings.chomp_contact
			var share: float = sqrt(clampf(1.0 - shut / maxf(b.open, 0.001), 0.0, 1.0)) if b.open > shut else 0.0
			b.t = maxf(b.t, strike * share)
			_stall = false
		else:
			b.t -= delta  # update() adds it back: the strike stands still
	elif _stall and (b == null or b.phase != ChompKit.Phase.STRIKE):
		_stall = false
	var fish := bite.fish
	var basis := fish.global_basis if is_instance_valid(fish) else Basis.IDENTITY
	step(delta, bite.mouth_point(), _forward_of(bite), bite.holding(), basis)
	_tow(bite, delta)
	if auto_pose and has_model():
		blend_pose(_model)


func on_landed(_bite_arg: HunterBite) -> void:
	_take_contact()  # a puppet's (or a guest's own) landing is not judged here: the arms reel in all the same


func on_cancel(bite: HunterBite) -> void:
	abort()
	_end_tow(bite.fish if bite != null and is_instance_valid(bite.fish) else null)


func on_close(_bite_arg: HunterBite, taken: Dictionary) -> void:
	eaten_total += int(taken.get("school_fish", 0)) + (taken.get("fish", []) as Array).size()


func ring_count(bite: HunterBite) -> int:
	return held_count() if bite.holding() else held_count() + reaching_count()


## While the arms hold fish the body ram is off (the octopus is towed onto its own catch: the arms are the weapon then).
func suppresses_ram(_bite_arg: HunterBite) -> bool:
	return beat == Beat.HOLD and held_count() > 0


func reach_mult_at(_bite_arg: HunterBite, _charge: float) -> float:
	return 1.0


func capacity_mult_at(_bite_arg: HunterBite, _charge: float) -> float:
	return 1.0


## The contact: exactly the fish the arms hold (the beak takes them all at once, grapple_per_arm each).
func catch_rule(bite: HunterBite) -> Dictionary:
	return _rule_for(bite, _take_contact())


## The host judging a guest's Hunter: what the guest's release said it held (school places by id and index, prey by where they were).
func net_catch_rule(bite: HunterBite, mouth: Vector3, _forward: Vector3, _charge: float, extra: Dictionary) -> Dictionary:
	var grips: Array[Grip] = []
	var world := bite.world
	var field: WhatStinksField = world.get("field") if world != null and is_instance_valid(world) else null
	var span := reach_m() * maxf(cfg("grapple_max_stretch"), 1.0) * 1.5 + bite.fish.hitbox_length
	if field != null:
		var places: PackedInt32Array = extra.get("school", PackedInt32Array())
		for i in range(0, places.size() - 1, 2):
			var school := field.school_by_id(places[i])
			var index := places[i + 1]
			if school != null and index >= 0 and index < school.fish_count() and school.is_alive(index) and not school.is_claimed(index):
				var g := Grip.new()
				g.school = school
				g.index = index
				g.pos = school.fish_position(index)
				if g.pos.distance_to(mouth) <= span:
					grips.append(g)
		var spots: Array = extra.get("prey_at", [])
		for at: Variant in spots:
			if not (at is Vector3):
				continue
			var best: FishController
			var best_gap := 4.0
			for victim: FishController in world.call("live_prey"):
				var gap := victim.global_position.distance_to(at as Vector3)
				if victim != bite.fish and gap < best_gap and victim.global_position.distance_to(mouth) <= span:
					best = victim
					best_gap = gap
			if best != null:
				var g2 := Grip.new()
				g2.prey = best
				g2.pos = best.global_position
				grips.append(g2)
	return _rule_for(bite, grips)


## What a guest's release held, for the host to judge (net_catch_rule).
func net_extra(_bite_arg: HunterBite) -> Dictionary:
	var places := PackedInt32Array()
	var spots: Array = []
	for g in _take_contact():
		if g.school != null and is_instance_valid(g.school):
			places.append(g.school.id)
			places.append(g.index)
		elif g.prey != null and is_instance_valid(g.prey):
			spots.append(g.prey.global_position)
	return {"school": places, "prey_at": spots}


func _rule_for(bite: HunterBite, grips: Array[Grip]) -> Dictionary:
	var mouth := bite.mouth_point()
	if grips.is_empty():
		return {"point": mouth, "capacity": 1, "only": null, "extra": [], "frustum": false, "inside": func(_at: Vector3) -> bool: return false}
	var spots := PackedVector3Array()
	for g in grips:
		spots.append(g.prey.global_position if g.prey != null and is_instance_valid(g.prey) else g.pos)
	var eps := maxf(0.05, cfg("grapple_eat_radius") * bite.radius())
	var eps2 := eps * eps
	var per := maxi(1, roundi(cfg("grapple_per_arm")))
	return {
		"point": mouth, "capacity": grips.size() * per, "only": null, "extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool:
			for p in spots:
				if at.distance_squared_to(p) <= eps2:
					return true
			return false,
	}


## The Hunter bot: press with a fish in reach, keep holding while more come in, let go when it holds enough or has held a while.
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var reach := reach_m()
	var ready := bite.cooldown <= 0.0 and not bite.busy() and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and bot.target_gap <= reach * 0.8, "hold": false}
	if not bite.holding():
		return {"press": ready and bot.target_gap <= reach * 0.9, "hold": false}
	var held := held_count() + reaching_count()
	var cap := clampi(roundi(cfg("grapple_arms")), 1, 8)
	var full := held >= mini(maxi(roundi(cfg("grapple_bot_want")), 1), cap)
	var long := held > 0 and held_s >= cfg("grapple_bot_hold_s")
	var nothing := held == 0 and held_s > 1.0
	var release := full or long or nothing or held_s > cfg("grapple_bot_hold_s") + 3.0
	if bot.stinker_blocks and not nothing:
		release = false
	return {"press": false, "hold": not release}


# ------------------------------------------------------------------------------ the beats (no HunterBite needed)

## The press. `origin` and `forward` are the beak and nose (world); `basis` the body's orientation.
func press(origin: Vector3, forward: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	_last_origin = origin
	_last_forward = forward.normalized() if forward.length_squared() > 0.0001 else _last_forward
	_xf_basis = basis
	if has_model():
		info.refresh()
	if ex == null:
		ex = AttackExaggerate.new()
	ex.press()
	beat = Beat.HOLD
	held_s = 0.0
	reel_t = 0.0
	_stall = false
	_contact_taken = false
	_taken.clear()
	_beaked = false
	_regrab = 0.0
	if fx != null:
		fx.flare(origin, forward)
		fx.say(&"flare", origin)
	if not net_driven:
		if _try_grab(origin, _last_forward):
			_regrab = cfg("grapple_regrab_s")


## The release at `charge`: held arms yank, a reaching arm still counts if it latches before the snap, nothing held whiffs.
func release(charge: float) -> void:
	if beat != Beat.HOLD:
		return
	if ex != null:
		ex.release(clampf(charge, 0.0, 1.0))
	beat = Beat.REEL
	reel_t = 0.0
	_contact_taken = false
	_taken.clear()
	_beaked = false
	var any := false
	var reaching_left := 0.0
	for t in arms:
		match t.phase:
			ArmPhase.LATCHED:
				t.phase = ArmPhase.YANK
				t.t = 0.0
				any = true
			ArmPhase.REACH:
				if not t.whiff:
					any = true
					reaching_left = maxf(reaching_left, t.reach_s - t.t)
	if not any:
		_whiff()
	_contact_at = cfg("grapple_yank_s") + reaching_left
	_stall = true
	if fx != null:
		fx.hum_off()
		if any:
			fx.say(&"yank", _last_origin)


## Called off with no snap: everything lets go and settles.
func abort() -> void:
	if beat == Beat.IDLE:
		return
	if ex != null:
		ex.abort()
	for t in arms:
		if t.phase != ArmPhase.REST and t.phase != ArmPhase.RETRACT:
			_let_go(t, "net" if net_driven else "gone", false)
	_stall = false
	_contact_taken = true
	beat = Beat.REEL
	if fx != null:
		fx.hum_off()


func reset() -> void:
	for t in arms:
		t.phase = ArmPhase.REST
		t.grip = null
		t.joints = PackedVector3Array()
		t.glow = 0.0
		if has_model():
			_restore_arm(_model, t.arm)
	beat = Beat.IDLE
	_stall = false
	_taken.clear()
	_contact_taken = false
	if ex != null:
		ex.reset()


## Whether the snap is due (a probe without a bite calls contact() then).
func contact_due() -> bool:
	return beat == Beat.REEL and not _contact_taken and reel_t >= minf(_contact_at, cfg("grapple_stall_max"))


## The snap: what the beak takes (the fish the yanking arms hold), once per release. The arms then reel the catch in.
func contact() -> Array[Grip]:
	return _take_contact()


func _take_contact() -> Array[Grip]:
	if _contact_taken or beat != Beat.REEL:
		return _taken
	_contact_taken = true
	_stall = false
	_taken.clear()
	for t in arms:
		if t.phase == ArmPhase.YANK and t.grip != null and _refresh(t.grip):
			_taken.append(t.grip)
			t.goal_m = to_model(t.grip.pos)
			t.phase = ArmPhase.REEL
			t.t = 0.0
			t.retract_s = maxf(cfg("grapple_reel_s"), 0.05)
		elif t.phase == ArmPhase.YANK or (t.phase == ArmPhase.REACH and not t.whiff):
			_let_go(t, "gone", false)  # still reaching at the snap: it comes back empty
	if ex != null:
		ex.contact(clampf(float(_taken.size()) / 8.0 + 0.25, 0.25, 1.0) if not _taken.is_empty() else 0.2)
	_flash = 1.0 if not _taken.is_empty() else 0.0
	net_version += 1
	ate.emit(_taken.size())
	return _taken


## Advance everything by `delta`. `origin`/`forward`: the beak and nose (world); `basis`: the body's orientation.
func step(delta: float, origin: Vector3, forward: Vector3, holding: bool, basis: Basis = Basis.IDENTITY) -> void:
	_dt = ex.tick(delta) if ex != null else delta
	var dt := _dt
	_clock += dt
	_last_origin = origin
	_last_forward = forward.normalized() if forward.length_squared() > 0.0001 else _last_forward
	_xf_basis = basis
	if has_model():
		info.refresh()
	_flash = maxf(_flash - dt * 5.0, 0.0)
	match beat:
		Beat.HOLD:
			held_s += dt
			_validate(dt)
			if holding and not net_driven:
				_regrab -= dt
				if _regrab <= 0.0 and _try_grab(origin, _last_forward):
					_regrab = cfg("grapple_regrab_s")
		Beat.REEL:
			reel_t += dt
			_validate(dt)
	_advance_arms(dt)
	_mark_cues()
	if fx != null:
		_update_fx()
	if beat == Beat.REEL and _contact_taken:
		if not _beaked and not _taken.is_empty() and reel_t >= cfg("grapple_yank_s") + cfg("grapple_reel_s") * 0.9:
			_beaked = true
			if fx != null:
				fx.beak(origin, forward, _taken.size())
				fx.say(&"beak", origin)
		if not busy():
			beat = Beat.IDLE


# ------------------------------------------------------------------------------ grabbing

## How far a free arm reaches for a fish (m, world): grapple_reach x the mean arm length.
func reach_m() -> float:
	return cfg("grapple_reach") * mean_arm_m()


func mean_arm_m() -> float:
	var total := 0.0
	for a in 8:
		total += info.arm_len[a]
	return total / 8.0 * _scale()


func _arm_m(arm: int) -> float:
	return info.arm_len[arm] * _scale()


func _scale() -> float:
	return _model.global_basis.get_scale().x if has_model() else 1.0


## Arms holding a fish now (latched or yanking).
func held_count() -> int:
	var n := 0
	for t in arms:
		if t.grip != null and (t.phase == ArmPhase.LATCHED or t.phase == ArmPhase.YANK):
			n += 1
	return n


## Arms on their way to a fish.
func reaching_count() -> int:
	var n := 0
	for t in arms:
		if t.phase == ArmPhase.REACH and not t.whiff:
			n += 1
	return n


## What the arms hold (latched or yanking).
func held() -> Array[Grip]:
	var out: Array[Grip] = []
	for t in arms:
		if t.grip != null and (t.phase == ArmPhase.LATCHED or t.phase == ArmPhase.YANK):
			out.append(t.grip)
	return out


## Whether a fish counts as in reach from `origin` along `forward`: the full reach ahead, grapple_behind of it straight behind.
func in_reach(origin: Vector3, forward: Vector3, at: Vector3) -> bool:
	var off := at - origin
	var dist := off.length()
	if dist < 0.0001:
		return true
	var ahead := (forward.dot(off / dist) + 1.0) * 0.5
	return dist <= reach_m() * lerpf(clampf(cfg("grapple_behind"), 0.0, 1.0), 1.0, ahead)


## Grabs one fish in reach with a free arm (nearest first, weighted toward the nose). Returns whether it did.
func _try_grab(origin: Vector3, forward: Vector3) -> bool:
	var cap := clampi(roundi(cfg("grapple_arms")), 0, 8)
	var busy_arms := 0
	var taken := {}
	for t in arms:
		if t.grip != null:
			busy_arms += 1
			taken[t.grip.key] = true
	if busy_arms >= cap:
		return false
	var weight := cfg("grapple_front_bias")
	var best: Dictionary = {}
	var best_score := INF
	for c: Dictionary in _candidates(origin, reach_m()):
		var ckey := int(c.get("key", 0))
		if taken.has(ckey) or float(_immune.get(ckey, -1.0)) > _clock:
			continue
		var pos: Vector3 = c["pos"]
		if not in_reach(origin, forward, pos):
			continue
		var prey := c.get("prey") as FishController
		if prey != null and (not is_instance_valid(prey) or prey.battered or (_bite != null and _bite.world != null and is_instance_valid(_bite.world) 				and not bool(_bite.world.call("is_live_prey", prey)))):
			continue
		var off := pos - origin
		var dist := off.length()
		var cos_a := forward.dot(off / dist) if dist > 0.0001 else 1.0
		var score := dist * (1.0 + weight * (1.0 - cos_a) * 0.5)
		if score < best_score:
			best_score = score
			best = c
	if best.is_empty():
		return false
	var arm := _free_arm_for(best["pos"])
	if arm < 0:
		return false
	var g := Grip.new()
	g.key = int(best.get("key", 0))
	g.school = best.get("school") as School
	g.index = int(best.get("index", -1))
	g.prey = best.get("prey") as FishController
	g.pos = best["pos"]
	g.vel = best.get("vel", Vector3.ZERO)
	g.joined = _is_joined(g.prey)
	_start_reach(arms[arm], g, Vector3.INF)
	return true


## Candidates {"key", "pos", "vel", + "school"/"index" or "prey"} within `span` (and a margin) of `origin`.
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
				if at.distance_to(origin) <= span * 1.05:
					out.append({"key": school.get_instance_id() * 4096 + i, "pos": at, "vel": school.fish_velocity(i), "school": school, "index": i})
	if bite.settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if prey == bite.fish or not is_instance_valid(prey) or prey.battered:
				continue
			if prey.global_position.distance_to(origin) <= span * 1.05:
				out.append({"key": prey.get_instance_id(), "pos": prey.global_position, "vel": prey.swim_velocity(), "prey": prey})
	return out


## The free arm whose base is nearest the fish (so arms do not cross the body), or -1.
func _free_arm_for(world_pos: Vector3) -> int:
	var local := to_model(world_pos)
	var best := -1
	var best_d := INF
	for a in 8:
		var t: Tentacle = arms[a]
		if t.grip != null or t.phase == ArmPhase.REACH or t.phase == ArmPhase.LATCHED or t.phase == ArmPhase.YANK or t.phase == ArmPhase.REEL:
			continue
		var d := info.bases[a].distance_to(local) + (0.0 if t.phase == ArmPhase.REST else 0.05 * info.length)
		if d < best_d:
			best_d = d
			best = a
	return best


func _start_reach(t: Tentacle, g: Grip, goal: Vector3) -> void:
	t.from = t.joints.duplicate() if t.joints.size() == 15 else _gait_joints(t.arm)
	t.joints = t.from.duplicate()
	t.grip = g
	t.whiff = g == null
	t.goal = goal if g == null else g.pos
	t.phase = ArmPhase.REACH
	t.t = 0.0
	var dist := t.goal.distance_to(to_world(info.bases[t.arm]))
	var full := cfg("grapple_latch_s") if g != null else cfg("grapple_whiff_s") * 0.5
	t.reach_s = maxf(full * lerpf(0.5, 1.0, clampf(dist / maxf(reach_m(), 0.001), 0.0, 1.0)), 0.04)
	net_version += 1
	if fx != null:
		fx.play(&"whoosh", to_world(info.bases[t.arm]), 1)


## The nothing-held tap: the arm nearest the nose flicks out ahead and back.
func _whiff() -> void:
	var goal := _last_origin + _last_forward * reach_m() * 0.75
	var arm := _free_arm_for(goal)
	if arm < 0:
		return
	whiffs += 1
	_start_reach(arms[arm], null, goal)
	whiffed.emit(arm, goal)
	if fx != null:
		fx.say(&"whiff", goal)


func _is_joined(prey: FishController) -> bool:
	if prey == null or _bite == null or _bite.world == null or not is_instance_valid(_bite.world):
		return false
	var join: Object = _bite.world.get("join")
	return join != null and bool(join.call("is_joined", prey))


## Positions follow the fish; a fish gone, too far, or a prey that tore free lets its arm go.
func _validate(dt: float) -> void:
	var own_vel := Vector3.ZERO
	if _bite != null and is_instance_valid(_bite.fish):
		own_vel = _bite.fish.swim_velocity()
	var stretch_max := cfg("grapple_max_stretch")
	for t in arms:
		var g := t.grip
		if g == null or (t.phase != ArmPhase.REACH and t.phase != ArmPhase.LATCHED and t.phase != ArmPhase.YANK):
			continue
		if not _refresh(g):
			if not net_driven:
				_let_go(t, "gone", true)
			continue
		if net_driven:
			continue
		var base := to_world(info.bases[t.arm])
		var gap := g.pos.distance_to(base)
		if gap > stretch_max * _arm_m(t.arm):
			_let_go(t, "stretch", true)
			continue
		if g.prey == null or t.phase == ArmPhase.REACH:
			continue
		if _torn(g, base, own_vel, dt):
			_let_go(t, "torn", true)


## Whether a held prey tore the arm off this tick: a dash, leaving its school (when it was in one), or counter-steering (turning hard:
## its nose's turn rate, so a puppet's synced transform reads the same as a local fish).
func _torn(g: Grip, base: Vector3, own_vel: Vector3, dt: float) -> bool:
	var prey := g.prey
	if g.joined:
		return not _is_joined(prey)  # the leave is its dash
	var away := (prey.global_position - base)
	var gap := away.length()
	away = away / gap if gap > 0.0001 else -_last_forward
	if cfg("grapple_break_dash") > 0.0:
		if prey.puppet:
			if (prey.swim_velocity() - own_vel).dot(away) > cfg("grapple_break_rel"):
				return true
		elif LureField.dashing(prey):
			return true
	var steer_s := cfg("grapple_break_steer_s")
	if steer_s > 0.0 and dt > 0.0:
		var nose := -prey.global_basis.z.normalized()
		var rate := rad_to_deg(g.heading.angle_to(nose)) / dt if g.heading != Vector3.ZERO else 0.0
		g.heading = nose
		var turning := rate >= cfg("grapple_break_turn") and prey.swim_velocity().length() > 1.5
		g.steer_s = g.steer_s + dt if turning else maxf(g.steer_s - dt * 0.5, 0.0)
		if g.steer_s >= steer_s:
			return true
	return false


func _refresh(g: Grip) -> bool:
	if g.prey != null:
		if not is_instance_valid(g.prey) or g.prey.battered:
			return false
		if _bite != null and _bite.world != null and is_instance_valid(_bite.world) and not bool(_bite.world.call("is_live_prey", g.prey)):
			return false
		g.pos = g.prey.global_position
		g.vel = g.prey.swim_velocity()
		return true
	if g.school != null:
		if not is_instance_valid(g.school) or not g.school.is_alive(g.index) or g.school.is_claimed(g.index):
			return false
		g.pos = g.school.fish_position(g.index)
		g.vel = g.school.fish_velocity(g.index)
		return true
	if target_source.is_valid():
		for item: Variant in target_source.call():
			if item is Dictionary and int((item as Dictionary).get("key", -1)) == g.key:
				g.pos = (item as Dictionary)["pos"]
				g.vel = (item as Dictionary).get("vel", Vector3.ZERO)
				return true
		return false
	return true


## Arm `t` lets go of its fish (`why` as let_go) and settles back.
func _let_go(t: Tentacle, why: String, announce: bool) -> void:
	var at: Vector3 = _last_origin
	if t.grip != null:
		at = t.grip.pos
	elif t.joints.size() == 15:
		at = to_world(t.joints[14])
	if t.grip != null:
		if why == "torn":
			tears_total += 1
			_immune[t.grip.key] = _clock + cfg("grapple_break_immune_s")
		elif why == "stretch":
			snaps_total += 1
	t.grip = null
	_begin_retract(t, cfg("grapple_retract_s"))
	net_version += 1
	if announce:
		let_go.emit(t.arm, at, why)
		if fx != null:
			if why == "torn":
				fx.torn(at, (at - _last_origin).normalized())
				fx.say(&"torn", at)
			else:
				fx.snap_off(at)
				fx.say(&"snap_off", at)


func _mark_cues() -> void:
	var frame := Engine.get_physics_frames()
	for t in arms:
		if t.grip != null and t.grip.prey != null and is_instance_valid(t.grip.prey) and (t.phase == ArmPhase.LATCHED or t.phase == ArmPhase.YANK):
			_cues[t.grip.prey.get_instance_id()] = [frame, _last_origin]


# ------------------------------------------------------------------------------ the tow

## The octopus is towed behind what it holds: its own FishController gets a rope's pull each tick (the fish are never touched).
func _tow(bite: HunterBite, delta: float) -> void:
	var fish := bite.fish
	tow_push = Vector3.ZERO
	tow_taut = 0.0
	tow_anchor = Vector3.INF
	if not is_instance_valid(fish):
		_end_tow(null)
		return
	if fish.puppet or beat != Beat.HOLD or not bite.holding():
		_end_tow(fish)
		return
	var weight := 0.0
	var anchor := Vector3.ZERO
	var anchor_vel := Vector3.ZERO
	var prey_w := maxf(cfg("grapple_prey_weight"), 0.0)
	for t in arms:
		if t.grip == null or t.phase != ArmPhase.LATCHED:
			continue
		var w := prey_w if t.grip.prey != null else 1.0
		anchor += t.grip.pos * w
		anchor_vel += t.grip.vel * w
		weight += w
	if weight <= 0.0:
		_end_tow(fish)
		return
	anchor /= weight
	anchor_vel /= weight
	tow_anchor = anchor
	_start_tow(fish)
	var root := bite.mouth_point()
	var off := anchor - root
	var d := off.length()
	if d < 0.0001:
		return
	var n := off / d
	var rope := maxf(cfg("grapple_tow_length") * mean_arm_m(), 0.1)
	var slack := rope * clampf(cfg("grapple_tow_slack"), 0.0, 0.99)
	var taut := smoothstep(slack, rope, d)
	tow_taut = taut
	var v := fish.linear_velocity
	var k := 1.0 - exp(-maxf(cfg("grapple_tow_response"), 0.0) * delta)
	# Along the rope it only pulls: close in at stiffness x the stretch past the rope's length (fall back no faster than that).
	var closing := (v - anchor_vel).dot(n)
	var want := cfg("grapple_tow_stiffness") * (d - rope)
	var dv_r := (want - closing) * taut * k if closing < want else 0.0
	# Across it the octopus swings round with the fish.
	var v_side := v - n * v.dot(n)
	var a_side := anchor_vel - n * anchor_vel.dot(n)
	var dv_side := (a_side - v_side) * clampf(cfg("grapple_tow_follow"), 0.0, 1.0) * taut * k
	tow_push = n * dv_r + dv_side
	if tow_push.length_squared() > 0.0:
		fish.apply_push(tow_push)
	# The integrator caps a fish at its top speed: lift it so a fast school can still tow it.
	var need := (anchor_vel.length() + maxf(want, 0.0)) * 1.25
	var base := fish.max_boost_speed * fish.top_speed_scale / _raised
	var lift := clampf(need / maxf(base, 0.001), 1.0, 4.0)
	if absf(lift - _raised) > 0.01:
		fish.top_speed_scale = fish.top_speed_scale / _raised * lift
		_raised = lift


func _start_tow(fish: FishController) -> void:
	if _thrust_rig != null:
		return
	var mult := clampf(cfg("grapple_tow_thrust"), 0.01, 4.0)
	var rig: Object = _model.get_parent() if has_model() else null
	if rig != null and "thrust_scale" in rig:
		_thrust_rig = rig
		_thrust_mult = mult
		rig.set("thrust_scale", float(rig.get("thrust_scale")) * mult)
	elif fish != null:
		_thrust_rig = fish  # no rig: nothing to scale, but the tow is on
		_thrust_mult = 1.0


func _end_tow(fish: FishController) -> void:
	if _raised != 1.0 and fish != null and is_instance_valid(fish):
		fish.top_speed_scale /= _raised
	_raised = 1.0
	if _thrust_rig != null and is_instance_valid(_thrust_rig) and _thrust_mult != 1.0 and "thrust_scale" in _thrust_rig:
		_thrust_rig.set("thrust_scale", float(_thrust_rig.get("thrust_scale")) / _thrust_mult)
	_thrust_rig = null
	_thrust_mult = 1.0


# ------------------------------------------------------------------------------ net

## What each arm holds, for the other machines: 8 x [kind, a, b] (0 none; 1 school id, index; 2 a prey's id from `id_of`).
func net_state(id_of: Callable) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(24)
	for t in arms:
		var g := t.grip
		if g == null or (t.phase != ArmPhase.REACH and t.phase != ArmPhase.LATCHED and t.phase != ArmPhase.YANK):
			continue
		if g.school != null and is_instance_valid(g.school):
			out[t.arm * 3] = 1
			out[t.arm * 3 + 1] = g.school.id
			out[t.arm * 3 + 2] = g.index
		elif g.prey != null and is_instance_valid(g.prey):
			out[t.arm * 3] = 2
			out[t.arm * 3 + 1] = int(id_of.call(g.prey))
	return out


## A puppet follows the owner's grips: `fish_of(id) -> FishController` resolves a prey's id, `field` the schools.
func apply_net_state(state: PackedInt32Array, fish_of: Callable, field: WhatStinksField) -> void:
	net_driven = true
	if state.size() < 24:
		return
	if beat != Beat.HOLD:
		return  # the release is the bite's own message; the arms then reel what they held
	for t in arms:
		var kind := state[t.arm * 3]
		var g := t.grip
		var holding := g != null and (t.phase == ArmPhase.REACH or t.phase == ArmPhase.LATCHED or t.phase == ArmPhase.YANK)
		if kind == 0:
			if holding:
				_let_go(t, "net", true)
			continue
		var school: School = field.school_by_id(state[t.arm * 3 + 1]) if kind == 1 and field != null else null
		var prey: FishController = fish_of.call(state[t.arm * 3 + 1]) as FishController if kind == 2 else null
		if school == null and prey == null:
			continue
		var index := state[t.arm * 3 + 2] if kind == 1 else -1
		if holding and g.school == school and g.index == index and g.prey == prey:
			continue
		var ng := Grip.new()
		ng.school = school
		ng.index = index
		ng.prey = prey
		ng.key = prey.get_instance_id() if prey != null else school.get_instance_id() * 4096 + index
		if not _refresh(ng):
			continue
		if holding:
			t.grip = null
		_start_reach(t, ng, Vector3.INF)


# ------------------------------------------------------------------------------ arms

func _advance_arms(dt: float) -> void:
	for t in arms:
		if t.phase == ArmPhase.REST:
			continue
		t.t += dt
		match t.phase:
			ArmPhase.REACH:
				_reach_step(t)
			ArmPhase.LATCHED, ArmPhase.YANK:
				_hold_step(t)
			ArmPhase.REEL:
				_reel_step(t)
			ArmPhase.RETRACT:
				_retract_step(t)
		t.glow = move_toward(t.glow, _glow_target(t), dt * 8.0)


func _glow_target(t: Tentacle) -> float:
	match t.phase:
		ArmPhase.REACH:
			return 1.2
		ArmPhase.LATCHED:
			return 0.9 + 0.6 * t.taut
		ArmPhase.YANK:
			return 2.0
		ArmPhase.REEL:
			return 1.4
	return 0.0


## The arm shoots out: a front runs from base to tip, each joint going over from where it was to the shape that ends on the fish.
func _reach_step(t: Tentacle) -> void:
	var goal := t.goal
	if t.grip != null:
		goal = t.grip.pos
	var x := clampf(t.t / maxf(t.reach_s, 0.001), 0.0, 1.0)
	var shape := _reach_shape(t.arm, to_model(goal), 0.0)
	var w := 0.7
	var span := 0.5
	var front := (span + w) * pow(x, 1.2)
	var fr: PackedFloat32Array = info.fracs[t.arm]
	var out := PackedVector3Array()
	out.resize(15)
	for j in 15:
		var a := smoothstep(0.0, 1.0, clampf((front - fr[j] * span) / w, 0.0, 1.0))
		out[j] = t.from[j].lerp(shape[j], a)
	t.joints = out
	if x < 1.0:
		return
	if t.grip == null:
		_begin_retract(t, cfg("grapple_whiff_s") * 0.5)  # the whiff: out and back
		if fx != null:
			fx.whiff(goal)
		return
	if beat == Beat.REEL and _contact_taken:
		_let_go(t, "gone", false)  # latched after the snap: nothing to reel
		return
	t.phase = ArmPhase.YANK if beat == Beat.REEL else ArmPhase.LATCHED
	t.t = 0.0
	grabs_total += 1
	net_version += 1
	grabbed.emit(t.arm, goal)
	if fx != null:
		fx.latch(goal, (goal - to_world(info.bases[t.arm])).normalized())
		fx.say(&"grab", goal, held_count())


## Latched (or yanking): the arm runs from its base to the fish, slack and sagging when close, taut and trembling when far.
func _hold_step(t: Tentacle) -> void:
	var goal := t.grip.pos if t.grip != null else to_world(t.joints[14])
	var local := to_model(goal)
	var reach := local.distance_to(info.bases[t.arm]) / maxf(info.arm_len[t.arm], 0.001)
	t.taut = smoothstep(0.75, 1.1, reach)
	var tremble := cfg("grapple_tremble") * info.arm_len[t.arm] * (t.taut if t.phase == ArmPhase.LATCHED else 2.5)
	t.joints = _reach_shape(t.arm, local, tremble)


## Reeling the catch in: the tip carries it from where it was taken to the beak, then the arm settles onto the gait.
func _reel_step(t: Tentacle) -> void:
	var u := clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var x := t.goal_m.lerp(info.mouth, e)
	var shape := _reach_shape(t.arm, x, 0.0)
	var gait := _gait_joints(t.arm)
	var b := smoothstep(0.6, 1.0, u)
	var out := PackedVector3Array()
	out.resize(15)
	for j in 15:
		out[j] = shape[j].lerp(gait[j], b)
	t.joints = out
	if u >= 1.0:
		_rest(t)


func _begin_retract(t: Tentacle, seconds: float) -> void:
	t.ret0 = t.joints.duplicate() if t.joints.size() == 15 else _gait_joints(t.arm)
	t.phase = ArmPhase.RETRACT
	t.t = 0.0
	t.retract_s = maxf(seconds, 0.05)


func _retract_step(t: Tentacle) -> void:
	var x := clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0)
	var tgt := _gait_joints(t.arm)
	var w := 0.4
	var front := (1.0 + w) * (1.0 - pow(1.0 - x, 2.2))
	var fr: PackedFloat32Array = info.fracs[t.arm]
	var out := PackedVector3Array()
	out.resize(15)
	for j in 15:
		var b := smoothstep(0.0, 1.0, clampf((front - fr[j]) / w, 0.0, 1.0))
		out[j] = t.ret0[j].lerp(tgt[j], b)
	t.joints = out
	if x >= 1.0:
		_rest(t)


func _rest(t: Tentacle) -> void:
	t.phase = ArmPhase.REST
	t.joints = PackedVector3Array()
	t.grip = null
	t.taut = 0.0
	if fx != null:
		fx.morsel_off(t.arm)
	if has_model():
		_restore_arm(_model, t.arm)


## The arm from its base to `x` (model space), 15 joints: it leaves the body along the gait's own first segment (so it grows out of
## where the arm rests, whichever way that is), bends round to the fish and ends on it. Nearer than the arm is long it sags toward
## the world's down (grapple_sag); further it stretches (the solver's bone stretch). `tremble` (m) shivers a taut arm.
func _reach_shape(arm: int, x: Vector3, tremble: float) -> PackedVector3Array:
	var base := info.bases[arm]
	var length := info.arm_len[arm]
	var to_x := x - base
	var dist := maxf(to_x.length(), 0.0001)
	var dir_x := to_x / dist
	var gait := _gait_joints(arm)
	var d_base := dir_x
	if gait.size() >= 2 and gait[1].distance_squared_to(gait[0]) > 1e-10:
		d_base = (gait[1] - gait[0]).normalized()
	var radial := info.radials[arm]
	var d0 := d_base * 0.5 + dir_x * 0.6 + radial * 0.35
	d0 = d0.normalized() if d0.length_squared() > 1e-6 else dir_x
	var p1 := base + d0 * dist * 0.38
	var p2 := x - dir_x * dist * 0.28
	var n := 32
	var dense := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var iu := 1.0 - u
		dense.append(base * iu * iu * iu + p1 * 3.0 * iu * iu * u + p2 * 3.0 * iu * u * u + x * u * u * u)
	var len_c := WhipAttack._poly_length(dense)
	var down := _to_model_dir(Vector3.DOWN)
	var side := down - dir_x * down.dot(dir_x)
	if side.length_squared() < 1e-4:
		side = dir_x.cross(radial)
		if side.length_squared() < 1e-4:
			side = Vector3.UP
	side = side.normalized()
	if len_c < length and cfg("grapple_sag") > 0.0:
		var h := (2.0 / PI) * sqrt(maxf(dist * (length - len_c), 0.0)) * 0.9 * clampf(cfg("grapple_sag"), 0.0, 1.5)
		for i in dense.size():
			dense[i] += side * h * sin(PI * float(i) / float(n))
		len_c = WhipAttack._poly_length(dense)
	if tremble > 0.0:
		var across := dir_x.cross(side).normalized()
		for i in dense.size():
			var u2 := float(i) / float(n)
			dense[i] += across * tremble * sin(PI * u2) * sin(_clock * 47.0 + float(arm) * 1.3 + u2 * 9.0)
	return WhipAttack._resample(dense, info.fracs[arm], len_c)


## The rig's own joints (what a settled arm rests on).
func _gait_joints(arm: int) -> PackedVector3Array:
	if gait_provider.is_valid():
		return gait_provider.call(arm)
	if has_model():
		return _model.call("arm_rest_joints", arm)
	return _rest_shape(arm)


## The made-up arm at rest: trailing behind the head (+Z), flared a little.
func _rest_shape(arm: int) -> PackedVector3Array:
	var base := info.bases[arm]
	var dir := (Vector3(0.0, 0.0, 1.0) * cos(0.35) + info.radials[arm] * sin(0.35)).normalized()
	var out := PackedVector3Array()
	for j in 15:
		out.append(base + dir * info.arm_len[arm] * info.fracs[arm][j])
	return out


# ------------------------------------------------------------------------------ frames

func _to_model_dir(world_dir: Vector3) -> Vector3:
	return (_model.global_basis.inverse() * world_dir) if has_model() else (_xf_basis.inverse() * world_dir)


## World <-> model for points. With no model the made-up model's origin is the head: the beak minus the beak's offset.
func to_model(p: Vector3) -> Vector3:
	if has_model():
		return _model.global_transform.affine_inverse() * p
	return _xf_basis.inverse() * (p - _body_origin())


func to_world(p: Vector3) -> Vector3:
	if has_model():
		return _model.global_transform * p
	return _body_origin() + _xf_basis * p


func _body_origin() -> Vector3:
	return _last_origin - _xf_basis * info.mouth


# ------------------------------------------------------------------------------ posing the model

## Poses every arm the grapple owns on `octo` (an OctopusModel): joints -> bends and stretch. Returns the arms it drove.
func blend_pose(octo: Node3D) -> Array[int]:
	var driven: Array[int] = []
	for t in arms:
		if t.phase == ArmPhase.REST or t.joints.size() != 15:
			continue
		driven.append(t.arm)
		var result: Dictionary = WhipAttack.Solver.solve(octo, t.arm, t.joints)
		octo.call("set_arm_pose", t.arm, result["bends"])
		WhipAttack.Solver.apply_stretch(octo, t.arm, result["stretch"])
		if drive_model_fx and octo.has_method("set_arm_glow"):
			octo.call("set_arm_glow", t.arm, t.glow)
	if drive_model_fx and (beat != Beat.IDLE or _fx_dirty):
		_model_fx(octo)
		_fx_dirty = beat != Beat.IDLE
	return driven


func _model_fx(octo: Node3D) -> void:
	var held_share := float(held_count()) / 8.0
	var on := beat != Beat.IDLE
	if octo.has_method("set_sucker_glow"):
		octo.call("set_sucker_glow", (0.35 + 0.9 * held_share + (0.4 if beat == Beat.REEL else 0.0)) if on else 0.15)
	if octo.has_method("set_eye_glow"):
		octo.call("set_eye_glow", (0.5 + 0.8 * held_share) if on else 0.35)
	if octo.has_method("set_flash"):
		octo.call("set_flash", _flash * 0.6)


func _restore_arm(octo: Node3D, arm: int) -> void:
	WhipAttack.Solver.apply_stretch(octo, arm, PackedFloat32Array())
	if octo.has_method("set_arm_glow"):
		octo.call("set_arm_glow", arm, 0.0)


## The arms the grapple is posing now.
func driven_arms() -> Array[int]:
	var out: Array[int] = []
	for t in arms:
		if t.phase != ArmPhase.REST:
			out.append(t.arm)
	return out


func arm_weight(arm: int) -> float:
	var t: Tentacle = arms[arm]
	if t.phase == ArmPhase.REST:
		return 0.0
	if t.phase == ArmPhase.RETRACT or t.phase == ArmPhase.REEL:
		return 1.0 - smoothstep(0.85, 1.0, clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0))
	return 1.0


## Where arm `arm`'s tip is now (world), INF at rest.
func tip_world(arm: int) -> Vector3:
	var t: Tentacle = arms[arm]
	return to_world(t.joints[14]) if t.joints.size() == 15 else Vector3.INF


func joints_of(arm: int) -> PackedVector3Array:
	return (arms[arm] as Tentacle).joints


## The mantle's squash for a rig that reads it (the grapple leaves the mantle to the gait).
func mantle_pulse() -> float:
	return 0.0


## True while any arm is out of its rest (the rig keeps its hands off those).
func busy() -> bool:
	for t in arms:
		if t.phase != ArmPhase.REST:
			return true
	return false


func _update_fx() -> void:
	for t in arms:
		if t.phase == ArmPhase.REACH and t.joints.size() == 15:
			var pts := PackedVector3Array()
			for j in 15:
				pts.append(to_world(t.joints[j]))
			fx.trail(t.arm, pts, 0.8)
		else:
			fx.trail_off(t.arm)
		if t.phase == ArmPhase.REEL and t.joints.size() == 15:
			fx.morsel(t.arm, to_world(t.joints[14]), 1.0 - clampf(t.t / maxf(t.retract_s, 0.001), 0.0, 1.0))
		elif t.phase != ArmPhase.REST:
			fx.morsel_off(t.arm)


## Wires an FX node (tools).
func attach_fx(node: OctopusGrappleFx) -> void:
	fx = node
