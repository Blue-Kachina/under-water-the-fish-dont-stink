extends Node
## What Stinks? Hunter previews (the card's showcase): every ready form, shown the way the mode setup card shows it
## (HomeScreen.FishShowcase.show_form -> HunterPreview). Per form: it really swims (the fish travels, its gait phase
## advances, the camera follows), and the head's drawn path is smooth. For the forms with a spine rig (King of Herrings,
## Lamprey Queen, ...) the spine's points are measured frame to frame in the head's frame: the second difference over
## the body's length must stay under JITTER_MAX, from the first frame on (the trail is pre-rolled), and the body must
## actually bend as the fish wanders. Also checked with the tree paused (the pause menu's Change Character).
##   Godot_console.exe --headless --fixed-fps 144 --path . res://tests/preview_jitter_probe.tscn [-- --keys=a,b --frames=N --dump]
## --fixed-fps matters: it gives every frame the same delta and lets frames and physics ticks disagree (as on a 144 Hz
## screen), which is what showed the old jitter (a tail that snapped at every trail point while the trail filled).
## Before the fix (HEAD): worst 0.6 m on the King's tail, a spike every ~17 frames for the first 5.5 s of every showing.

const Showcase := preload("res://scripts/ui/home_screen.gd").FishShowcase
## The most the spine's points may move off a smooth path in one frame, over the body's length.
const JITTER_MAX := 0.0015
## The same for the head's drawn path (m per frame squared, over the body's length).
const HEAD_JITTER_MAX := 0.0005
const RIGGED := ["king_of_herrings", "lamprey_queen"]
## Frames after show_form that the spine measure skips: the body settles from the pre-roll (a 3 cm shift on a 16 m body, once).
const WARMUP := 4

var failures := 0
var checks := 0
var keys: Array[String] = []
var frames := 360
var dump := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--keys="):
			for k in arg.trim_prefix("--keys=").split(","):
				keys.append(k)
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg == "--dump":
			dump = true
	if keys.is_empty():
		keys = HunterForms.ready_keys()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	var holder := Control.new()
	holder.size = Vector2(400, 400)
	add_child(holder)
	var showcase: Showcase = Showcase.new()
	showcase.size = Vector2(400, 400)
	holder.add_child(showcase)
	await get_tree().process_frame
	for key in keys:
		await _form(showcase, key, false)
	if "king_of_herrings" in keys:
		get_tree().paused = true
		await _form(showcase, "king_of_herrings", true)
		get_tree().paused = false
	print("preview_jitter_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## The spine of the first rig the preview's fish wears (null: a model-only body).
func _rig(fish: Node3D) -> SpineRig:
	for node in fish.find_children("*", "Node3D", true, false):
		var rig: Variant = node.get("rig")
		if rig is SpineRig:
			return rig as SpineRig
	return null


func _form(showcase: Showcase, key: String, paused: bool) -> void:
	print("%s%s:" % [key, " (tree paused)" if paused else ""])
	showcase.show_form(key)
	# Straight after show_form: the body is already laid behind the head (the pre-roll), nothing builds up from nothing.
	var fish: FishController = showcase._fish
	check(fish != null and showcase._preview != null, "the form shows a swimming fish")
	if fish == null:
		return
	var rig := _rig(fish)
	var length := fish.hitbox_length
	var phase_start: float = fish.get("_swim_phase")
	var start := fish.global_position
	var camera: Camera3D = showcase._camera
	var camera_start := camera.global_position
	var spine: Array = []  # per frame: the spine's points in the head's frame
	var heads: Array[Vector3] = []
	var lateral: Array[float] = []
	var worst := 0.0
	var worst_head := 0.0
	var worst_at := -1
	for i in frames:
		await get_tree().process_frame
		var xf := fish.get_global_transform_interpolated()
		heads.append(xf.origin)
		if rig != null:
			var inverse := xf.affine_inverse()
			var local := PackedVector3Array()
			for p in rig.points:
				local.append(inverse * p)
			spine.append(local)
			lateral.append(local[local.size() - 1].x)
	for i in range(WARMUP, heads.size()):
		worst_head = maxf(worst_head, (heads[i] - 2.0 * heads[i - 1] + heads[i - 2]).length())
	# The spine in the head's frame changes only as the fish turns: smooth, so its second difference is tiny. (A snapping tail
	# jumps by 0.04 rad x its length at once.)
	for i in range(WARMUP, spine.size()):
		var a: PackedVector3Array = spine[i - 2]
		var b: PackedVector3Array = spine[i - 1]
		var c: PackedVector3Array = spine[i]
		for s in a.size():
			var d := (c[s] - 2.0 * b[s] + a[s]).length()
			if dump and i < 8 and s in [4, 47]:
				print("      frame %d point %d d=%.5f local=%s" % [i, s, d, c[s]])
			if d > worst:
				worst = d
				worst_at = i
	var travelled := fish.global_position.distance_to(start)
	var phase_moved := float(fish.get("_swim_phase")) - phase_start
	var camera_moved := camera.global_position.distance_to(camera_start)
	print("    travelled %.1f m, gait phase +%.1f, camera moved %.1f m, head 2nd diff %.5f m" % [travelled, phase_moved, camera_moved, worst_head])
	check(travelled > length * 0.15, "it swims (moved %.1f m)" % travelled)
	check(phase_moved > 1.0, "its gait phase advances (+%.1f)" % phase_moved)
	check(camera_moved > 0.1, "the camera follows it (%.1f m)" % camera_moved)
	check(fish.linear_velocity.length() > 0.1 and fish.input_forward > 0.05, "the throttle and velocity the gait reads are set")
	check(worst_head / length < HEAD_JITTER_MAX, "the head's drawn path is smooth (%.6f of its length)" % (worst_head / length))
	if rig != null:
		var lo := INF
		var hi := -INF
		for v in lateral:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var rel := worst / maxf(length, 0.001)
		print("    spine samples %d, worst second difference %.5f m (%.6f of length %.1f m) at sample %d, tail sway %.2f m" % [spine.size(), worst, rel, length, worst_at, hi - lo])
		check(rel < JITTER_MAX, "the spine moves smoothly (%.6f < %.4f)" % [rel, JITTER_MAX])
		check(hi - lo > length * 0.01, "the body bends with the wander (tail sway %.2f m)" % (hi - lo))
