extends Node
## The King of Herrings' attack exaggeration (planning_new_hunters.md B5; the kit is AttackExaggerate). A child of the KingRig, so
## it runs after the rig has posed the body each frame (king_rig.gd is another worker's: this bends what it posed).
##
## It owns the kit, feeds it the bite's beats (opened = press, released, landed, aborted; a tap's strike counts as its release),
## then bends the posed spine a little more:
##   coil   the body winds tighter on the press and through the hold (extra curl on top of coil_curl_deg, with a lift along the
##          fish's up so a tight coil does not pass through itself); a quick unwinding dip first (anticipation)
##   tail   the whip tail stretches king_whip_stretch x on the release, with smear, and rings out
##   lag    the tail trails the head's sweep on a spring (the whip), king_whip_lag of it
##   head   the eyes bulge with the charge and pop on the release
##   limb   the flank lampreys swell and flail
##   jaw    KingJaw reads the kit's jaw scale (the gape swells to 2.2x with the charge)
## The tail stride (the swim wave) is untouched. Everything here is re-posed by the rig next frame, so an idle or hidden driver
## leaves nothing behind. Not a class_name: the King form preloads it.

const KingRig := preload("res://scripts/what_stinks/forms/king_rig.gd")

var rig: Node3D  # king_rig.gd
var jaw: Object  # king_jaw.gd
var fish: FishController
var ex: AttackExaggerate
var bite: HunterBite
var form: Dictionary = {}
## The tail's lag behind the head's sweep (a spring), rad and rad/s.
var lag := 0.0
var lag_v := 0.0
## What the last bend applied (probes read these): the extra curl (rad), the lift (m), the tail stretch, the tail's lag turn (rad).
var shown := {"curl": 0.0, "lift": 0.0, "stretch": 1.0, "lag": 0.0, "eyes": 1.0, "limbs": 1.0}
var bent_frames := 0
## Frozen by a probe: ticks with this delta instead of the frame's (negative: off).
var fixed_delta := -1.0
## A probe's master multiplier (negative: the hunter_exaggeration setting).
var master_override := -1.0
var _struck := false
var _tap := false
var _bound: HunterBite


## A setting that may not be registered yet: `fallback` until it is.
static func opt(id: String, fallback: float) -> float:
	var got: Variant = WhatStinksSettings.shared().get(id)
	return float(got) if got != null else fallback


## The King's own channel numbers (the form sheet's "exaggerate" preset). Tail: 1.5x on the release (king_whip_stretch), no stretch while
## the coil is held. Coil: king_coil_tighten x the curl at full charge. Eyes (head) and lampreys (limb) bulge; the jaw keeps the kit's 2.2x.
static func preset() -> Dictionary:
	return {"snap_omega": 26.0, "snap_zeta": 0.8, "channels": {
		"head": {"hold_peak": 1.7, "release_peak": 1.6},
		"tail": {"hold_peak": 1.0, "squash": 0.88, "release_peak": opt("king_whip_stretch", 1.5), "omega": 16.0, "zeta": 0.3, "volume": 0.5},
		"coil": {"hold_peak": opt("king_coil_tighten", 1.55), "squash": 0.88, "release_peak": 0.7, "omega": 14.0, "zeta": 0.5, "volume": 0.0},
	}}


func setup(with_fish: FishController, with_form: Dictionary) -> void:
	fish = with_fish
	form = with_form.duplicate()
	if not form.has("exaggerate"):
		form["exaggerate"] = preset()
	ex = AttackExaggerate.new(AttackExaggerate.params_from(WhatStinksSettings.shared(), form))
	ex.camera_punch.connect(_on_punch)
	if jaw != null:
		jaw.set("ex", ex)


func _find_bite() -> void:
	var found := fish.get_node_or_null("HunterBite") as HunterBite
	if found == _bound:
		return
	_bound = found
	bite = found
	ex.reset()
	lag = 0.0
	lag_v = 0.0
	if found == null:
		return
	found.opened.connect(func() -> void:
		_struck = false
		_tap = not found.holding()
		ex.press())
	found.released.connect(func(charge: float) -> void:
		_struck = true
		ex.release(maxf(charge, 0.35)))
	found.aborted.connect(func() -> void: ex.abort())
	found.landed.connect(func(taken: int) -> void: ex.contact(1.0 if taken > 0 else 0.3))


func _on_punch(amount: float, dir: Vector3) -> void:
	var camera: Object = ChompKit.view_camera(fish) if is_instance_valid(fish) else null
	if camera != null and camera.has_method("punch"):
		camera.call("punch", amount, dir)


func _process(delta: float) -> void:
	if ex == null or not is_instance_valid(fish) or not rig.is_visible_in_tree():
		return
	step(delta if fixed_delta < 0.0 else fixed_delta)


## One frame's work (probes call it with their own delta).
func step(delta: float) -> void:
	_find_bite()
	ex.set_strength(master_override if master_override >= 0.0 else opt("hunter_exaggeration", 1.0), float(form.get("exaggeration", 1.0)))
	_sync_channels()
	if bite != null:
		if bite.holding():
			ex.hold(bite.charge())
		elif _tap and ex.phase == AttackExaggerate.Phase.HOLD:
			ex.hold(0.55)  # a tap has no charge: a middling wind
		if bite.bite != null and bite.bite.phase == ChompKit.Phase.STRIKE and not _struck:
			_struck = true  # a tap's strike is its release
			ex.release(0.7)
	var dt := ex.tick(delta)
	_spring(dt)
	if jaw != null:
		jaw.call("refresh")
	rig.get_parent().set_meta("exaggerate_peak", ex.peak_scale())
	if _bend():
		bent_frames += 1


## Live panel changes to the King's own multipliers reach the channels.
func _sync_channels() -> void:
	var channels: Dictionary = preset()["channels"]
	for id: String in ["tail", "coil"]:
		var c: AttackExaggerate.Channel = ex.channels[StringName(id)]
		c.cfg["release_peak"] = channels[id]["release_peak"]
		c.cfg["hold_peak"] = channels[id]["hold_peak"]


func _swing() -> float:
	var coil_attack := bite.attack as CoilAttack if bite != null else null
	return coil_attack.sweep_at(bite) if coil_attack != null else 0.0


## The tail's spring after the head's sweep (the whip): chases the sweep, rings (zeta well under 1), then settles.
func _spring(dt: float) -> void:
	var swing := _swing()
	var left := dt
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		lag_v += (-110.0 * (lag - swing) - 2.0 * 0.28 * 10.5 * lag_v) * h
		lag += lag_v * h
		left -= h


## Bends the spine the rig posed. Returns whether it changed anything.
func _bend() -> bool:
	var sp: SpineRig = rig.get("rig")
	var n := SpineRig.SPINE_N
	var base: float = rig.get("_coil")
	if _tap and bite != null and not bite.holding():
		base = maxf(base, 0.5)  # a tap never winds the plain coil: the exaggeration still curls it a little
	var tight := deg_to_rad(WhatStinksSettings.shared().coil_curl_deg) * base * (ex.scale_of(&"coil") - 1.0)
	var stretch := ex.scale_basis(&"tail", Vector3.BACK).z.z
	var whip := (_swing() - lag) * opt("king_whip_lag", 0.45)
	var eyes := ex.scale_of(&"head")
	var limbs := ex.scale_of(&"limb")
	var girth: float = rig.get("girth")
	var lift_total := maxf(tight, 0.0) / PI * girth * 2.6
	shown = {"curl": tight, "lift": lift_total, "stretch": stretch, "lag": whip, "eyes": eyes, "limbs": limbs}
	if absf(tight) < 0.0005 and absf(whip) < 0.0005 and absf(stretch - 1.0) < 0.002 and absf(eyes - 1.0) < 0.002 and absf(limbs - 1.0) < 0.002:
		return false
	var pts := sp.points
	var axis := sp.head_up.normalized()
	var first := int(n * 0.12)
	var last := int(n * 0.75)
	var from := pts.duplicate()
	var at := pts[0]
	for s in range(1, n):
		var along := float(s) / float(n - 1)
		var ramp := clampf(float(s - first) / float(last - first), 0.0, 1.0)
		var turn := tight * ramp - whip * smoothstep(0.1, 1.0, along)
		var grow := 1.0 + (stretch - 1.0) * smoothstep(0.3, 0.75, along)
		at += (from[s] - from[s - 1]).rotated(axis, turn) * grow
		pts[s] = at + axis * (lift_total * smoothstep(0.0, 1.0, ramp))
	sp.points = pts
	sp.call("_frames")
	rig.call("_pose_riders")
	_scale_riders(eyes, limbs)
	sp.apply()
	return true


## The eyes bulge and the lampreys swell about their own origins (the rig poses them afresh next frame).
func _scale_riders(eyes: float, limbs: float) -> void:
	for rider: Array in rig.get("_riders"):
		var node: Node3D = rider[0]
		var mesh := node as MeshInstance3D
		var is_eye := mesh != null and mesh.material_override is ShaderMaterial and (mesh.material_override as ShaderMaterial).shader == KingRig.EYE_SHADER
		var k := eyes if is_eye else limbs
		if absf(k - 1.0) > 0.002:
			var xf := node.global_transform
			node.global_transform = Transform3D(xf.basis.scaled(Vector3.ONE * k), xf.origin)
