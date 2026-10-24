extends Node
## The gait layer (big_changes.md §6, Phase 1), on Nature's tuning in the Ocean:
## - zero change: every class, on its default gait, swims a scripted run of
##   strides and coasting exactly as before the layer (tests/fixtures/
##   gait_baseline.json, recorded on the code before it);
## - every class has a Gait, the GAITS section edits it live, and presets and
##   co-op carry it;
## - each Gait number does what it says (stroke time, stroke power, coast drag,
##   coast buoyancy);
## - the camera follows the body, not the model (where gaits will bob and tilt).
##   Godot_console.exe --headless --path . res://tests/gait_probe.tscn
## With `-- --record` it only writes the baseline (run it on the code before a
## change that must keep the swimming the same).

const BASELINE := "res://tests/fixtures/gait_baseline.json"
## The scripted run: strides at the peak, then letting go to coast (ticks).
const STRIDE_TICKS := 300
const COAST_TICKS := 180
const SAMPLE_EVERY := 20

var main: Node
var fish: FishController
var panel: Node
var input := FishInput.new()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	panel = main.get_node("DebugPanel")
	panel.load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	if "--record" in OS.get_cmdline_user_args():
		var runs := {}
		for fish_class: int in FishCharacter.FishClass.values():
			runs[str(fish_class)] = await _trajectory(fish_class)
		var out := FileAccess.open(BASELINE, FileAccess.WRITE)
		out.store_string(JSON.stringify(runs, "\t"))
		out.close()
		print("gait_probe: recorded %d classes -> %s" % [runs.size(), BASELINE])
		get_tree().quit(0)
		return

	print("zero change (default gaits against the baseline):")
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	for fish_class: int in FishCharacter.FishClass.values():
		if not baseline.has(str(fish_class)) or not GaitSettings.default_for(fish_class).is_default():
			continue  # a class that came with its own gait (the Alchemists' flap): nothing to keep
		var now := await _trajectory(fish_class)
		var then: Array = baseline[str(fish_class)]
		var worst := 0.0
		for i in mini(now.size(), then.size()):
			for j in 6:
				worst = maxf(worst, absf(float(now[i][j]) - float(then[i][j])))
		check(now.size() == then.size() and worst < 1e-4, "%s swims as before (worst diff %.7f)" % [FishCharacter.display_name(fish_class), worst])

	print("settings:")
	var settings := GaitSettings.shared()
	var all_default := true
	for fish_class: FishCharacter.FishClass in FishCharacter.FishClass.values():
		var own := not GaitSettings.default_for(fish_class).is_default()
		all_default = all_default and settings.for_class(fish_class) != null and (own or settings.for_class(fish_class).is_default())
	check(all_default, "every class has a gait, all on today's defaults but those given their own")
	var flap := settings.for_class(FishCharacter.FishClass.ALCHEMIST)
	check(flap.stroke_axis == Gait.StrokeAxis.FLAP and flap.visual == Gait.Visual.FLAP, "the Alchemists flap")
	fish.set_look(FishCharacter.FishClass.DRIFTER, 0)
	check(fish.gait == settings.for_class(FishCharacter.FishClass.DRIFTER), "a fish holds its class's gait")
	settings.set("drifter_coast_drag", 3.0)
	check(is_equal_approx(fish.gait.coast_drag, 3.0) and is_equal_approx(settings.get("drifter_coast_drag"), 3.0),
			"setting drifter_coast_drag reaches the drifter's gait")
	check(is_equal_approx(settings.for_class(FishCharacter.FishClass.SKIRMISHER).coast_drag, 1.0), "and no other class's")
	var shown := 0
	var groups := 0
	for property in settings.get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP and String(property.name).ends_with("s"):  # the class headings
			groups += 1
		elif property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and String(property.name).begins_with("lancer_"):
			shown += 1
	check(groups == FishCharacter.FishClass.size(), "a heading per class (%d)" % groups)
	check(shown == GaitSettings.gait_properties().size() and shown >= 4, "each class shows the gait's options (%d)" % shown)
	check(panel.option_range("gaits/lancer_stroke_time").get("allow_greater", false), "the panel has a GAITS section (lancer_stroke_time)")
	check(not panel.option_range("gaits/lancer_visual").has("min"), "single-value enums aren't shown yet")
	check(panel.tuning_snapshot().get("gaits", {}).get("drifter_coast_drag", 0.0) == 3.0, "presets save the gaits")
	check("gaits" in CoopSession.TUNING_SECTIONS, "the host's gaits go to guests")
	check(SettingDocs.DOCS.has("gaits/drifter_coast_drag"), "the options have descriptions")
	panel.restore_tuning({"gaits": {"drifter_coast_drag": 1.0}})
	check(settings.for_class(FishCharacter.FishClass.DRIFTER).is_default(), "restoring puts it back")

	print("what each number does (Skirmishers):")
	var gait := settings.for_class(FishCharacter.FishClass.SKIRMISHER)
	fish.set_look(FishCharacter.FishClass.SKIRMISHER, 0)
	var base_peak: float = fish.swishy.peak_time()
	gait.stroke_time = 2.0
	check(is_equal_approx(fish.swishy.peak_time(), base_peak * 2.0) and is_equal_approx(fish.swishy.fade_time(), fish.stride_fade_time * 2.0),
			"stroke time 2 doubles the peak and fade times")
	gait.stroke_time = 1.0
	var normal := _end(await _trajectory(FishCharacter.FishClass.SKIRMISHER), STRIDE_TICKS)
	gait.stroke_power = 0.0
	var powerless := _end(await _trajectory(FishCharacter.FishClass.SKIRMISHER), STRIDE_TICKS)
	gait.stroke_power = 2.0
	var strong := _end(await _trajectory(FishCharacter.FishClass.SKIRMISHER), STRIDE_TICKS)
	gait.stroke_power = 1.0
	check(powerless.z > normal.z * 0.2 and powerless.z < normal.z * 0.85, "stroke power 0: strides add nothing (%.1f of %.1f m)" % [powerless.z, normal.z])
	check(strong.z > normal.z * 1.1, "stroke power 2 goes further (%.1f m)" % strong.z)
	var coasted := _coast(await _trajectory(FishCharacter.FishClass.SKIRMISHER))
	gait.coast_drag = 4.0
	var draggy := _coast(await _trajectory(FishCharacter.FishClass.SKIRMISHER))
	gait.coast_drag = 1.0
	check(draggy.x < coasted.x * 0.8, "coast drag 4 slows the coast (%.1f vs %.1f m/s)" % [draggy.x, coasted.x])
	gait.coast_buoyancy = -8.0
	var sunk := _coast(await _trajectory(FishCharacter.FishClass.SKIRMISHER))
	gait.coast_buoyancy = 0.0
	check(sunk.y < coasted.y - 3.0, "coast buoyancy -8 sinks it between strides (%.1f vs %.1f m/s up)" % [sunk.y, coasted.y])
	check(gait.is_default(), "all back to defaults")

	print("camera:")
	var camera: Camera3D = main.get_node("FollowCamera")
	input.clear()
	fish.request_reset()
	for i in 120:
		await get_tree().process_frame
	var before := fish.global_transform.affine_inverse() * camera.global_transform
	fish._visual.rotation = Vector3(0.9, 0.0, 0.6)  # what a tilting gait would do to the model
	for i in 60:
		await get_tree().process_frame
	var after := fish.global_transform.affine_inverse() * camera.global_transform
	fish._visual.rotation = Vector3.ZERO
	check(before.origin.distance_to(after.origin) < 0.05 and before.basis.z.angle_to(after.basis.z) < 0.02,
			"tilting the model doesn't move the camera (%.3f m)" % before.origin.distance_to(after.origin))

	print("gait_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The scripted run as `fish_class` from a standstill: [position (from the
## start), velocity] every SAMPLE_EVERY ticks.
func _trajectory(fish_class: int) -> Array:
	input.clear()
	fish.set_look(fish_class, 0)
	fish.request_reset()
	for i in 5:
		await get_tree().physics_frame
	var start := fish.global_position
	# Read loosely, so --record also runs on the code from before the gait layer.
	var gait: Variant = fish.get("gait")
	var peak: float = fish.stride_peak_time * (gait.stroke_time if gait else 1.0)
	var peak_ticks := maxi(roundi(peak * Engine.physics_ticks_per_second), 1)
	var samples := []
	for tick in STRIDE_TICKS + COAST_TICKS:
		if tick < STRIDE_TICKS:
			input.forward = 1.0
			input.stick = Vector2.RIGHT * (1.0 if floori(float(tick) / peak_ticks) % 2 == 0 else -1.0)
		else:
			input.clear()
		await get_tree().physics_frame
		if (tick + 1) % SAMPLE_EVERY == 0:
			var p := fish.global_position - start
			var v := fish.linear_velocity
			samples.append([p.x, p.y, p.z, v.x, v.y, v.z])
	input.clear()
	return samples


## How far it got (m, along its start's facing) by tick `tick`, as Vector3(0, 0, distance).
func _end(samples: Array, tick: int) -> Vector3:
	var row: Array = samples[floori(float(tick) / SAMPLE_EVERY) - 1]
	return Vector3(0.0, 0.0, Vector3(row[0], row[1], row[2]).length())


## The coast: Vector3(speed at its end, vertical speed at its end, 0).
func _coast(samples: Array) -> Vector3:
	var row: Array = samples[-1]
	return Vector3(Vector3(row[3], row[4], row[5]).length(), row[4], 0.0)
