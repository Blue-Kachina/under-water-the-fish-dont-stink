## Extra Swishy strides on the Ember Octopus and the Lantern Angler (planning_hunter_refine.md follow-up, 2026-11-08):
##   octopus  a stride fires the jet on the input: the mantle swells at once (the expansion), squeezes as the stride peaks, refills as
##            it fades; strides are not doubled by the free-running beat; the Battletoads pop rings on the mantle; with no stride the
##            free beat still runs; speed pulls the arms into a tighter bundle (bare rig, no fish).
##   angler   the tail follows the stick's sweep (sign and size), steps the free sway aside while striding, rings past the sweep,
##            swells with flow and relaxes back when the strides stop; each stride's input flicks it (the fish's strode signal).
## Run headless: Godot_console.exe --headless --path . res://tests/stride_forms_probe.tscn
extends Node

const ANGLER := preload("res://scripts/what_stinks/forms/lantern_angler.gd")
const DT := 1.0 / 60.0

var main: Node
var fish: FishController
var checks := 0
var failures := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _octopus()
	await _angler()
	print("stride_forms_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------------------------------------ octopus

func _bare() -> OctopusRig:
	var rig := OctopusRig.new()
	add_child(rig)
	rig.build_model(6.0)
	rig.floor_query = func(_a: Vector3, _b: Vector3) -> Dictionary: return {}
	return rig


## The stride at `phase` seconds into it (0.3 s to the peak, 0.5 s of fade).
func _stride(phase: float, strides: int) -> Dictionary:
	var peak := 0.3
	var fade := 0.5
	var power := smoothstep(0.0, peak, phase) if phase < peak else clampf(1.0 - (phase - peak) / fade, 0.0, 1.0)
	return {"phase": phase, "power": power, "peak": peak, "fade": fade, "strides": strides}


func _octopus() -> void:
	print("octopus:")
	var settings := WhatStinksSettings.shared()
	var rig := _bare()
	await _frames(2)
	var ctx := {"throttle": 1.0, "vel": Vector3(0.0, 0.0, -3.0)}
	# --- the first stride breathes in: the mantle swells and the arms spread, no jet yet
	rig.stride_override = {"phase": -1.0, "power": 0.0, "peak": 0.3, "fade": 0.5, "strides": 0}
	for i in 30:
		rig.step(DT, ctx)
	var jets0 := int(rig.shown["jets"])
	var mantle_min := 9.0
	var mantle_at_peak := -9.0
	var spread_at_peak := 9.0
	var pop_max := -9.0
	var pop_min := 9.0
	var t := 0.0
	var first_inflate_t := -1.0
	while t < 0.45:  # cut off by the next stride while it holds open
		rig.stride_override = _stride(t, 1)
		rig.step(DT, ctx)
		var m: float = rig.shown["mantle"]
		mantle_min = minf(mantle_min, m)
		if first_inflate_t < 0.0 and m < -0.3:
			first_inflate_t = t
		if absf(t - 0.3) < DT * 0.6:
			spread_at_peak = rig.shown["spread"]
		pop_max = maxf(pop_max, rig._pop)
		pop_min = minf(pop_min, rig._pop)
		t += DT
	_check(first_inflate_t >= 0.0 and first_inflate_t < 0.25, "the first stride swells the mantle (past -0.3 at %.2f s into it)" % first_inflate_t)
	_check(mantle_min < -0.6, "...a real expansion, not a flicker (mantle %.2f)" % mantle_min)
	_check(spread_at_peak > 0.2, "...the arms spread open (spread %.2f)" % spread_at_peak)
	_check(int(rig.shown["jets"]) == jets0 and rig._thrust_env < 0.001, "...and it does not push (jets %d)" % (int(rig.shown["jets"]) - jets0))
	_check(pop_max > 0.3 and pop_min < 0.0, "the Battletoads pop swells past the jet and rings thin (%.2f .. %.2f)" % [pop_min, pop_max])
	# --- the second stride squeezes: the mantle deflates, the arms close, the push
	var env_max := 0.0
	t = 0.0
	while t < 0.9:
		rig.stride_override = _stride(t, 2)
		rig.step(DT, ctx)
		env_max = maxf(env_max, rig._thrust_env)
		if absf(t - 0.3) < DT * 0.6:
			mantle_at_peak = rig.shown["mantle"]
			spread_at_peak = rig.shown["spread"]
		t += DT
	_check(mantle_at_peak > 0.3, "the second stride squeezes the mantle (mantle %.2f at the peak)" % mantle_at_peak)
	_check(spread_at_peak < -0.1, "...the delta bundling in the squeeze (spread %.2f)" % spread_at_peak)
	_check(int(rig.shown["jets"]) - jets0 == 1, "...two strides are one jet (%d)" % (int(rig.shown["jets"]) - jets0))
	_check(env_max > 1.2, "...and the squeeze carries the push (peak %.2f)" % env_max)
	# --- strides back to back alternate: four make two jets; a pause starts over by breathing in
	rig.stride_override = {"phase": -1.0, "power": 0.0, "peak": 0.3, "fade": 0.5, "strides": 0}
	for i in 90:
		rig.step(DT, ctx)
	var j1 := int(rig.shown["jets"])
	for n in 4:
		var tt := 0.0
		while tt < 0.45:  # each cut off at 0.45 s by the next
			rig.stride_override = _stride(tt, n + 1)
			rig.step(DT, ctx)
			tt += DT
	_check(int(rig.shown["jets"]) - j1 == 2, "four strides in a row make two jets (%d)" % (int(rig.shown["jets"]) - j1))
	# --- no stride: the free beat runs, and sync off keeps it during strides
	rig.stride_override = {}
	var j2 := int(rig.shown["jets"])
	for i in 240:
		rig.step(DT, ctx)
	_check(int(rig.shown["jets"]) - j2 >= 3, "with no stride the free-running beat goes on (%d jets in 4 s)" % (int(rig.shown["jets"]) - j2))
	settings.set("octopus_stride_sync", 0.0)
	var j3 := int(rig.shown["jets"])
	for i in 150:
		rig.stride_override = _stride(minf(float(i) * DT, 0.8), 1)
		rig.step(DT, ctx)
	_check(int(rig.shown["jets"]) - j3 >= 1 and not rig._jet_stride, "stride sync off: the beat ignores strides (jets %d)" % (int(rig.shown["jets"]) - j3))
	settings.set("octopus_stride_sync", 1.0)
	rig.stride_override = {}
	# --- pop off
	settings.set("octopus_stride_pop", 0.0)
	var pop_off := 0.0
	for k in 40:
		rig.stride_override = _stride(float(k) * DT, 10)
		rig.step(DT, ctx)
		pop_off = maxf(pop_off, absf(rig._pop))
	_check(pop_off < 0.01, "octopus_stride_pop 0 turns the pop off (%.3f)" % pop_off)
	settings.set("octopus_stride_pop", 1.0)
	rig.stride_override = {}
	rig.queue_free()
	await _frames(2)
	# --- speed tightens the arms
	var slow := await _arm_spread(Vector3(0.0, 0.0, -0.5))
	var fast := await _arm_spread(Vector3(0.0, 0.0, -20.0))
	_check(fast < slow * 0.75, "speed pulls the arms into a tighter bundle (spread %.2f m slow, %.2f m fast)" % [slow, fast])
	settings.set("octopus_speed_tuck", 0.0)
	var no_tuck := await _arm_spread(Vector3(0.0, 0.0, -20.0))
	_check(no_tuck > fast * 1.2, "octopus_speed_tuck 0 turns it off (%.2f m)" % no_tuck)
	settings.set("octopus_speed_tuck", 0.6)


## How far the arm tips are from the body's axis on average, after a second at `vel` (model space, metres).
func _arm_spread(vel: Vector3) -> float:
	var rig := _bare()
	await _frames(2)
	for i in 120:
		rig.step(DT, {"throttle": 0.0, "vel": vel})
	var total := 0.0
	for a in 8:
		var p := rig.model.arm_tip_local(a)
		total += Vector2(p.x, p.y).length()
	rig.queue_free()
	await _frames(2)
	return total / 8.0


# ------------------------------------------------------------------------------------------------ angler

func _angler() -> void:
	print("angler:")
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.TAP
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	var form := HunterForms.DEFAULTS.duplicate()
	form.merge(ANGLER.sheet() as Dictionary, true)
	var size := HunterSize.shared()
	size.size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	ANGLER.dress(fish, form)
	await _frames(3)
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 30.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.freeze = true
	var rig: Node3D = (fish._visual as Node3D).get_node_or_null("LanternRig")
	_check(rig != null, "the angler's rig is on the model")
	if rig == null:
		return
	await _frames(40)
	_check(float(rig.shown["stride_w"]) < 0.05 and absf(float(rig.shown["stride"])) < 0.01, "no stride: the tail is the free sway (weight %.2f)" % float(rig.shown["stride_w"]))
	# the fish's own stride: Original swim style gives none, Extra Swishy gives the fish's
	fish.swim_style = FishController.SwimStyle.ORIGINAL
	_check((rig.call("_stride_info") as Dictionary).is_empty(), "Original swimming has no stride to follow")
	fish.swim_style = FishController.SwimStyle.EXTRA_SWISHY
	_check(not (rig.call("_stride_info") as Dictionary).is_empty(), "Extra Swishy swimming hands the rig the fish's stride")
	fish.swim_style = FishController.SwimStyle.ORIGINAL
	# --- the tail follows the sweep
	rig.stride_override = {"swing": Vector2(0.8, 0.0), "power": 0.9, "phase": 0.2, "flow": 0.5, "growth": 0.8}
	var sway_max := 0.0
	for i in 40:
		await get_tree().process_frame
		sway_max = maxf(sway_max, absf(float(rig.shown["sway"])) * (1.0 if i > 25 else 0.0))
	var right := float(rig.shown["stride"])
	_check(right > 0.35, "a sweep to one side bends the tail that way (%.2f rad)" % right)
	_check(float(rig.shown["stride_w"]) > 0.9 and sway_max < 0.03, "the free sway steps aside while striding (weight %.2f, sway %.3f)" % [float(rig.shown["stride_w"]), sway_max])
	_check(float(rig.shown["grow"]) > 0.1, "the tail swells with flow (grow %.2f)" % float(rig.shown["grow"]))
	_check(absf(float(rig.model.tail_bend)) > 0.3, "and the model's tail is bent by it (tail_bend %.2f)" % float(rig.model.tail_bend))
	rig.stride_override = {"swing": Vector2(-0.8, 0.0), "power": 0.9, "phase": 0.2, "flow": 0.5, "growth": 0.8}
	var overshoot := 0.0
	for i in 40:
		await get_tree().process_frame
		overshoot = minf(overshoot, float(rig.shown["stride"]))
	var left := float(rig.shown["stride"])
	_check(left < -0.35, "the next sweep, the other way, bends it the other way (%.2f rad)" % left)
	_check(overshoot < -0.55 * 1.0 and overshoot < left - 0.02, "and it whips past the sweep before it settles (%.2f past %.2f)" % [overshoot, left])
	# --- a stride's input flicks the tail
	rig.stride_override = {}
	await _frames(90)
	_check(absf(float(rig.shown["stride"])) < 0.02 and float(rig.shown["grow"]) < 0.02, "when the strides stop the tail relaxes back (%.3f rad, grow %.3f)" % [float(rig.shown["stride"]), float(rig.shown["grow"])])
	var kick_peak := 0.0
	fish.strode.emit(0.5, 0.2)
	for i in 8:
		await get_tree().process_frame
		kick_peak = maxf(kick_peak, absf(float(rig.shown["stride"])))
	_check(kick_peak > 0.03, "a stride's input flicks the tail at once (%.3f rad)" % kick_peak)
	var settings := WhatStinksSettings.shared()
	settings.set("angler_stride_pop", 0.0)
	rig.stride_override = {"swing": Vector2(0.8, 0.0), "power": 0.9, "phase": 0.2, "flow": 1.0, "growth": 0.8}
	await _frames(40)
	_check(float(rig.shown["grow"]) < 0.01, "angler_stride_pop 0 turns the swell off (%.3f)" % float(rig.shown["grow"]))
	_check(float(rig.shown["stride"]) > 0.35, "...but the tail still follows the sweep (%.2f rad)" % float(rig.shown["stride"]))
	settings.set("angler_stride_pop", 1.0)
	rig.stride_override = {}
