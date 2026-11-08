## Lantern Angler: a 180 degree turn in place. Logs how far the tail point trails the body axis over time (angle between the body's
## back direction and head->tail), so the tail's follow can be tuned.
## Run headless: Godot_console.exe --headless --path . res://tests/angler_turn_probe.tscn
extends Node

const FORM := preload("res://scripts/what_stinks/forms/lantern_angler.gd")

var main: Node
var fish: FishController


func _ready() -> void:
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.TAP
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	for i in 5:
		await get_tree().process_frame
	main.set_environment("Ocean")
	for i in 5:
		await get_tree().process_frame
	var form := HunterForms.DEFAULTS.duplicate()
	form.merge(FORM.sheet() as Dictionary, true)
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	FORM.dress(fish, form)
	for i in 3:
		await get_tree().process_frame
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 30.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	var rig: Node3D = (fish._visual as Node3D).get_node("LanternRig")
	for i in 110:
		await get_tree().physics_frame
		fish.linear_velocity = Vector3.ZERO
		fish.angular_velocity = Vector3.ZERO
	var rate := 6.0  # rad/s: a 180 in about a second
	var t := 0.0
	var turned := 0.0
	var next_log := 0.0
	while t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		fish.linear_velocity = Vector3.ZERO
		if turned < PI:
			fish.angular_velocity = Vector3(0.0, rate, 0.0)
			turned += rate * get_physics_process_delta_time()
		else:
			fish.angular_velocity = Vector3.ZERO
		if t >= next_log:
			next_log += 0.2
			var pts: PackedVector3Array = rig.rig.points
			var back := fish.global_basis.z
			var mid := (pts[SpineRig.SPINE_N / 2] - pts[0]).normalized()
			var tail := (pts[SpineRig.SPINE_N - 1] - pts[0]).normalized()
			print("t=%.1f turned=%3.0f deg  mid lag=%3.0f deg  tail lag=%3.0f deg" % [t, rad_to_deg(turned), rad_to_deg(back.angle_to(mid)), rad_to_deg(back.angle_to(tail))])
	get_tree().quit()
