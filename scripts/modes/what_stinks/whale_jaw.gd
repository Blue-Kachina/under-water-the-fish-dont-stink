class_name WhaleJaw
extends HunterJaw
## A whale Hunter's hinged lower jaw (two-stage-attack.md 4b; meta "hunter_jaw" on the model, as the shark's):
## the Titan model's jaw (TitanModel.hunter_jaw: a belly patch or the sperm whale's rod, the inside, the baleen
## or teeth) posed from the Bite's `open`. Exaggerated, Battletoads style: it drops to `whale_gape_deg`, the jaw
## stretches `whale_smear` times as long as it opens, the Bite's fling past wide swings it further, and
## `fullness` (0 to 1; EngulfAttack sets it as fish go in) balloons the throat. Built only on a Hunter's model:
## Marco Polo's Titans never get one, so their mouth stays the painted line, shut.
##
## Exaggeration pass (planning_new_hunters.md B1): the jaw owns an AttackExaggerate (`ex`) that EngulfAttack drives
## with the bite's beats (press, hold(charge), release, contact, abort). It reads back as
##   jaw     the gape multiplier (hold up to ~2.2x, soft-limited at whale_gape_max_deg) and its smear,
##   head    the whole body swells a little on the charge (squash on the press, pop on the release),
##   tail    the body lunges (z stretch) on the release,
##   throat  the pleats balloon while held (on top of `fullness`) and gulp on the release; the tongue rides it,
##   teeth   the baleen plates / teeth grow from their roots (species touch),
## plus a rebound: the shut jaw bounces open and settles after the bite lands. Hit-stop freezes the pose a few ticks.

## Roots of the body pulse: how much of the head channel's departure the whole body shows, and of the tail's.
const BODY_HEAD := 0.4
const BODY_TAIL := 0.12
## The rebound spring (rad/s, ratio).
const REBOUND_OMEGA := 30.0
const REBOUND_ZETA := 0.3
## A whale's preset over AttackExaggerate.DEFAULTS: heavy and slow-bodied, so a slightly longer dip, and a new channel
## for the species touch (baleen plates, teeth).
const PRESET := {
	"antic_time": 0.14,
	"channels": {
		"teeth": {"hold_peak": 1.5, "squash": 0.85, "release_peak": 2.3, "omega": 24.0, "zeta": 0.35, "volume": 0.2},
	},
}

var settings := WhatStinksSettings.shared()
## How full the mouth is (0 to 1): the throat's pleats swell to it. Set by the attack, applied by the next pose().
var fullness := 0.0
## The Titan model's jaw pieces (TitanModel.hunter_jaw's dictionary).
var info := {}
## The exaggeration (AttackExaggerate), driven by EngulfAttack; null only before build().
var ex: AttackExaggerate
## The form sheet this jaw was dressed for (its `exaggeration` multiplier and `exaggerate` preset).
var form := {}
var _model: FishModel
var _fish: FishController
var _open_shown := -999.0
var _full_shown := -999.0
var _ex_shown := -999.0
var _angle_shown := 0.0
var _rebound := 0.0
var _rebound_v := 0.0
var _parts: Array[Dictionary] = []  # {"node": MeshInstance3D, "kind": &"baleen"|&"teeth"|&"tongue", "pivot": float (mesh y that stays put)}
var _body_base := Vector3.ONE
var _body_set := Vector3.ONE


## The jaw on `model` (a Titan's), which this builds the pieces for.
func build(model: FishModel, _skin_color: Color) -> void:
	_model = model
	var titan := load(FishModel.TITAN_MODEL) as GDScript
	info = titan.call("hunter_jaw", model)
	mouth = {"front": info.mouth, "length": float(info.length), "width": float(info.width)}
	_body_base = model.scale
	_body_set = model.scale
	_find_parts()
	set_exaggeration(form)
	pose(0.0)


## Puts a WhaleJaw on `fish`'s Titan model once (safe to call every round): meta "hunter_jaw". Returns it.
## `sheet` is the form's (its exaggeration multiplier and preset; the jaw refreshes them each call).
static func wear(fish: FishController, sheet: Dictionary = {}) -> WhaleJaw:
	var model := fish.get("_visual") as FishModel
	if model == null:
		return null
	if model.has_meta("hunter_jaw"):
		var worn := model.get_meta("hunter_jaw") as WhaleJaw
		if worn != null:
			worn._fish = fish
			if not sheet.is_empty():
				worn.set_exaggeration(sheet)
		return worn
	var jaw := WhaleJaw.new()
	jaw.form = sheet
	jaw._fish = fish
	jaw.build(model, Color.WHITE)
	model.set_meta("hunter_jaw", jaw)
	if model.has_meta("titan_lod_rescale"):
		(model.get_meta("titan_lod_rescale") as Callable).call(fish.body_scale)  # the jaw's LODs follow the fish's scale too
	return jaw


## (Re)makes the exaggeration for `sheet` (a Hunter form's dictionary) at the panel's current numbers.
func set_exaggeration(sheet: Dictionary) -> void:
	form = sheet
	var params := AttackExaggerate.params_from(settings, {"exaggeration": sheet.get("exaggeration", 1.0)})
	params["camera_punch"] = float(params["camera_punch"]) * 0.5  # HunterBiteFx punches the camera on landing too
	params = AttackExaggerate.merged(AttackExaggerate.merged(PRESET, params), sheet.get("exaggerate", {}))
	if ex != null and ex.camera_punch.is_connected(_on_camera_punch):
		ex.camera_punch.disconnect(_on_camera_punch)
	ex = AttackExaggerate.new(params)
	ex.camera_punch.connect(_on_camera_punch)
	_ex_shown = -999.0


## Where the mouth is, in the model's space: the lips' front.
func mouth_local() -> Vector3:
	return info.mouth


## How far the jaw is dropped now (rad, 0 shut), for the probes and the attack's box.
func angle() -> float:
	return _angle_shown


## The mouth's half width and length (m, model space).
func mouth_width() -> float:
	return float(info.width)


func mouth_length() -> float:
	return float(info.length)


# --- The beats (EngulfAttack calls these) --------------------------------------------------

func ex_press() -> void:
	if ex != null:
		ex.press()


func ex_hold(charge: float) -> void:
	if ex != null:
		ex.hold(charge)


func ex_release(charge: float) -> void:
	if ex != null:
		ex.release(charge)


## The bite landed (`share` 0..1: how much it caught): hit-stop, the camera punch and the jaw's rebound off the catch.
func ex_contact(share: float) -> void:
	if ex == null:
		return
	if ex.phase == AttackExaggerate.Phase.ANTICIPATE or ex.phase == AttackExaggerate.Phase.HOLD:
		ex.release(maxf(ex.charge, 0.4))  # a one-press (tap) bite never released: the snap plays at the landing
	ex.contact(share)
	var kick := deg_to_rad(_setting("whale_rebound_deg", 16.0)) * ex.strength * lerpf(0.6, 1.0, clampf(share, 0.0, 1.0))
	_rebound_v += kick * REBOUND_OMEGA / 0.75


func ex_abort() -> void:
	if ex != null:
		ex.abort()


## Back to rest at once (a new round).
func ex_reset() -> void:
	if ex != null:
		ex.reset()
	_rebound = 0.0
	_rebound_v = 0.0
	_ex_shown = -999.0


## Advances the exaggeration by `delta` (one physics tick; EngulfAttack.on_tick does, before the pose). Returns the
## hit-stop-aware delta (the rig's own clock).
func step(delta: float) -> float:
	if ex == null:
		return delta
	var want := maxf(0.0, _setting("hunter_exaggeration", 1.0) * float(form.get("exaggeration", 1.0)))
	if not is_equal_approx(want, ex.strength):
		ex.set_strength(_setting("hunter_exaggeration", 1.0), float(form.get("exaggeration", 1.0)))
	var dt := ex.tick(delta)
	var left := dt
	var w2 := REBOUND_OMEGA * REBOUND_OMEGA
	while left > 0.0 and (absf(_rebound) > 0.0001 or absf(_rebound_v) > 0.0001):
		var h := minf(left, AttackExaggerate.STEP)
		_rebound_v += (-w2 * _rebound - 2.0 * REBOUND_ZETA * REBOUND_OMEGA * _rebound_v) * h
		_rebound += _rebound_v * h
		left -= h
	if absf(_rebound) < 0.0001 and absf(_rebound_v) < 0.0001:
		_rebound = 0.0
		_rebound_v = 0.0
	return dt


## The largest the whale's body is scaled now (a camera pads its collision radius with it; the jaw and the inside
## parts stay within the model, so only the body pulse reaches further out).
func peak_scale() -> float:
	var f := _body_factor()
	return maxf(maxf(f.x, f.z), 1.0)


## The most the body pulse can ever scale it (clamped): the worst-case camera margin.
func potential_peak() -> float:
	if ex == null:
		return 1.0
	var pulse := _setting("whale_body_pulse", 1.0)
	var top := 1.0
	for id in [&"head", &"tail"]:
		var ch: Dictionary = ex.params["channels"][id]
		var raw := maxf(float(ch["hold_peak"]), float(ch["release_peak"]))
		var s := 1.0 + (clampf(1.0 + (raw - 1.0) * ex.strength, 0.35, float(ex.params["max_scale"])) - 1.0) * (BODY_HEAD if id == &"head" else BODY_TAIL) * pulse
		top = maxf(top, s)
	return top


func _angle_of(jaw: float) -> float:
	var open := smoothstep(0.0, 1.0, jaw)
	if open <= 0.0 and absf(_rebound) < 0.004:
		return 0.0
	var swing := 0.0
	if open > 0.0:
		swing = maxf(open + overshoot * (1.0 if open > 0.03 else 0.0), -0.1)
	var mult := ex.scale_of(&"jaw") if ex != null else 1.0
	var gape := deg_to_rad(settings.whale_gape_deg) * swing * mult
	return clampf(-(_soften(gape) + maxf(_rebound, -0.02)), -deg_to_rad(maxf(_setting("whale_gape_max_deg", 135.0), 10.0)) - 0.2, 0.2)


## `gape` (rad) kept linear up to 60 percent of the limit, then eased into the limit (never past it).
func _soften(gape: float) -> float:
	var limit := deg_to_rad(maxf(_setting("whale_gape_max_deg", 135.0), 10.0))
	var knee := limit * 0.6
	if gape <= knee:
		return gape
	return knee + (limit - knee) * (1.0 - exp(-(gape - knee) / (limit - knee)))


func pose(jaw: float) -> void:
	if info.is_empty():
		return
	if ex != null and ex.in_hit_stop():
		return  # the few ticks of hit-stop: the pose holds
	var sig := _signature()
	if is_equal_approx(jaw + overshoot, _open_shown) and is_equal_approx(fullness, _full_shown) and is_equal_approx(sig, _ex_shown):
		return
	_open_shown = jaw + overshoot
	_full_shown = fullness
	_ex_shown = sig
	var open := smoothstep(0.0, 1.0, jaw)
	var cut := open > 0.03 or absf(_rebound) > 0.012
	var angle := _angle_of(jaw)
	_angle_shown = angle
	var stretch := 1.0
	if cut:
		stretch = lerpf(1.0, settings.whale_smear, clampf(open + overshoot, 0.0, 1.0)) * lerpf(1.0, _smear(), clampf(open * 4.0, 0.0, 1.0))
	var balloon := 0.0
	if ex != null:
		balloon = maxf(ex.scale_of(&"throat") - 1.0, 0.0) * 0.45 * _setting("whale_throat_balloon", 1.0)
	var jaw_skin: ShaderMaterial = info.jaw_skin
	if bool(info.sperm):
		if jaw_skin != null:
			jaw_skin.set_shader_parameter("jaw_angle", angle)
			jaw_skin.set_shader_parameter("jaw_stretch", stretch)
	else:
		var skin: ShaderMaterial = info.skin
		skin.set_shader_parameter("jaw_cut", 1.0 if cut else 0.0)
		skin.set_shader_parameter("throat_swell", clampf(fullness + balloon, 0.0, 1.8) * float(info.swell) * settings.engulf_swell)
		jaw_skin.set_shader_parameter("jaw_angle", angle)
		jaw_skin.set_shader_parameter("jaw_stretch", stretch)
		for patch: MeshInstance3D in info.patches:
			patch.visible = cut
	var jaw_node: Node3D = info.jaw
	var head: Node3D = info.head
	jaw_node.rotation.x = angle
	jaw_node.scale = Vector3(1.0, 1.0, stretch)
	jaw_node.visible = cut
	head.visible = cut
	_pose_parts()
	_pose_body()


## Extra stretch (1 = none) from how fast the gape is changing: the smear.
func _smear() -> float:
	if ex == null:
		return 1.0
	return 1.0 + minf(float(ex.params["smear"]) * ex.speed_of(&"jaw"), minf(float(ex.params["smear_max"]), 0.3))


## One number that changes whenever anything the exaggeration shows changes (the pose's cache key).
func _signature() -> float:
	if ex == null:
		return 0.0
	return ex.scale_of(&"jaw") + ex.scale_of(&"head") * 3.1 + ex.scale_of(&"tail") * 7.3 + ex.scale_of(&"throat") * 13.7 \
			+ ex.scale_of(&"teeth") * 29.0 + _rebound * 53.0 + ex.speed_of(&"jaw") * 0.37


# --- Species touches and the body ---------------------------------------------------------

## The baleen plates, teeth and tongue meshes, each with the y that stays fixed as it grows (its root).
func _find_parts() -> void:
	_parts.clear()
	var head: Node3D = info.head
	var jaw: Node3D = info.jaw
	for holder: Node3D in [head, jaw]:
		for child in holder.get_children():
			var node := child as MeshInstance3D
			if node == null or node.mesh == null:
				continue
			var box := node.mesh.get_aabb()
			match String(node.name):
				"Baleen", "UpperTeeth":
					_parts.append({"node": node, "kind": &"teeth", "pivot": box.end.y})  # hangs down from the roof
				"Teeth":
					_parts.append({"node": node, "kind": &"teeth", "pivot": box.position.y})  # points up from the lip
				"Floor":
					_parts.append({"node": node, "kind": &"tongue", "pivot": box.position.y})


func _pose_parts() -> void:
	if ex == null:
		return
	var pop := _setting("whale_tooth_pop", 1.0)
	# Fades as the jaw closes: grown plates and teeth would go through the lower jaw.
	var clear := smoothstep(deg_to_rad(8.0), deg_to_rad(45.0), -_angle_shown)
	var teeth_y := 1.0 + (ex.scale_of(&"teeth") - 1.0) * pop * clear
	var tongue_y := 1.0 + (ex.scale_of(&"throat") - 1.0) * 0.3 * pop
	for part in _parts:
		var node: MeshInstance3D = part.node
		var sy := teeth_y if part.kind == &"teeth" else tongue_y
		sy = maxf(sy, 0.2)
		node.scale = Vector3(1.0, sy, 1.0)
		node.position = Vector3(0.0, float(part.pivot) * (1.0 - sy), 0.0)


## What the whole body is scaled by now: the head swell on x and y, the tail's lunge on z (the nose reaches forward).
func _body_factor() -> Vector3:
	if ex == null:
		return Vector3.ONE
	var pulse := _setting("whale_body_pulse", 1.0)
	var across := 1.0 + (ex.scale_of(&"head") - 1.0) * BODY_HEAD * pulse
	var along := 1.0 + (ex.scale_of(&"tail") - 1.0) * BODY_TAIL * pulse
	return Vector3(across, across, along)


## Scales the Titan model by the body factor (the model's own scale, which the fish sets once per resize, is the base:
## if somebody else changes it, that is the new base).
func _pose_body() -> void:
	if not is_instance_valid(_model):
		return
	if not _model.scale.is_equal_approx(_body_set):
		_body_base = _model.scale
	var factor := _body_factor()
	_model.scale = _body_base * factor
	_body_set = _model.scale


func _on_camera_punch(amount: float, dir: Vector3) -> void:
	if _fish == null or not is_instance_valid(_fish):
		return
	var camera := ChompKit.view_camera(_fish)
	if camera:
		camera.call("punch", amount, dir)


func _setting(id: String, fallback: float) -> float:
	var got: Variant = settings.get(id)
	return float(got) if got != null else fallback
