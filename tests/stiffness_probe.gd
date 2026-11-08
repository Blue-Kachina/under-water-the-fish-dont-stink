## What Stinks? A2: body_stiffness on the King of Herrings and the Lamprey Queen. Each is dressed at size 1, swum round a circle
## at stiffness 0 (the old body), 0.4 (the default) and 1 (rigid); measures how far the tail swings off the head's line (the
## flex), the segment lengths (the body never stretches) and frame-to-frame jitter of the spine.
## Run headless: Godot_console.exe --headless --path . res://tests/stiffness_probe.tscn
extends Node

var main: Node
var fish: FishController
var checks := 0
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	for pair: Array in [["king_of_herrings", "KingRig"], ["lamprey_queen", "LampreyRig"]]:
		await _form(pair[0], pair[1])
	print("stiffness_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _form(key: String, node_name: String) -> void:
	var form := HunterForm.sheet(key)
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, key)
	await _frames(3)
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	var body := fish._visual.get_node(node_name) as Node3D
	var rig: SpineRig = body.get("rig")
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	input.stick = Vector2(1.0, 0.0)
	var tps := int(Engine.physics_ticks_per_second)
	await _frames(tps)
	var swing := {}
	var jitter := {}
	for s: float in [0.0, 0.4, 1.0]:
		body.set("stiffness_override", s)
		await _frames(tps / 2)
		var worst_swing := 0.0
		var worst_jitter := 0.0
		var worst_stretch := 0.0
		var last := rig.points.duplicate()
		var last2 := rig.points.duplicate()
		var step := rig.length / float(SpineRig.SPINE_N - 1)
		for i in tps * 2:
			await get_tree().process_frame
			var head := rig.points[0]
			var tail := rig.points[SpineRig.SPINE_N - 1]
			var line := fish.global_basis.z.normalized()
			var worst := 0.0
			for p in range(1, SpineRig.SPINE_N):
				var off := rig.points[p] - head
				worst = maxf(worst, (off - line * off.dot(line)).length())
				worst_stretch = maxf(worst_stretch, absf(rig.points[p].distance_to(rig.points[p - 1]) - step))
				# the spine's own motion relative to the head (the head's travel removed)
				var moved := (rig.points[p] - head) - 2.0 * (last[p] - last[0]) + (last2[p] - last2[0])
				worst_jitter = maxf(worst_jitter, moved.length())
			worst_swing = maxf(worst_swing, worst)
			last2 = last
			last = rig.points.duplicate()
		swing[s] = worst_swing
		jitter[s] = worst_jitter
		print("      %s stiffness %.1f: tail off the line %.2f m, spine accel/frame %.3f m, worst segment error %.3f m" % [key, s, worst_swing, worst_jitter, worst_stretch])
		_check(worst_stretch < step * 0.35, "%s stiffness %.1f: segments keep their length (%.3f of %.2f m)" % [key, s, worst_stretch, step])
	_check(swing[1.0] < swing[0.4] and swing[0.4] < swing[0.0], "%s: more stiffness, less bend (%.2f > %.2f > %.2f m)" % [key, swing[0.0], swing[0.4], swing[1.0]])
	_check(jitter[0.4] < jitter[0.0] * 1.1 + 0.02, "%s: the stiffer body is no jerkier (%.3f vs %.3f m/frame)" % [key, jitter[0.4], jitter[0.0]])
	body.set("stiffness_override", -1.0)
