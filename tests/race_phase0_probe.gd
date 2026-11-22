extends Node
## Race phase 0 measurements (planning_race.md): Nature's swimming in the Ocean, a long perfect stride
## chain at a few top speed caps (speed over time, 90 degree turn radius at that speed), and the body
## length of every roster entry before and after a size cap of CAP_X x the Skirmisher.
##   Godot_console.exe --headless --path . res://tests/race_phase0_probe.tscn

const CAP_X := 2.0
const RUN_TIME := 18.0
## Race top speed candidates: the stroke cap (m/s). The fish's own is stroke_max_speed (40).
const CAPS := [8.0, 10.0, 12.0, 14.0]

var main: Node
var fish: FishController
var input := FishInput.new()


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	_run.call_deferred()


func _run() -> void:
	print("nature: max_speed %.1f stroke_max_speed %.1f accel %.1f drag %.2f" % [
			fish.max_speed, fish.stroke_max_speed, fish.forward_accel, fish.linear_drag])
	var peak := fish.stride_peak_time
	for cap: float in CAPS:
		fish.top_speed_scale = cap / fish.stroke_max_speed
		await _chain(cap, peak)
		await _turn(cap * 0.9)
	fish.top_speed_scale = 1.0
	_lengths()
	get_tree().quit(0)


func _chain(cap: float, peak: float) -> void:
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var start := fish.global_position
	var t := 0.0
	var marks := {5.0: 0.0, 10.0: 0.0, 15.0: 0.0, 20.0: 0.0, 25.0: 0.0}
	var best := 0.0
	var sum := 0.0
	var n := 0
	while t < RUN_TIME:
		input.stick = Vector2.RIGHT * (1.0 if int(t / peak) % 2 == 0 else -1.0)
		input.forward = 1.0
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		best = maxf(best, fish.speed)
		if t > 8.0:
			sum += fish.speed
			n += 1
		for k: float in marks:
			if t >= k and marks[k] == 0.0:
				marks[k] = fish.speed
	print("cap %4.1f: peak %5.1f  mean after 8s %5.1f  at 5/10/15/20/25 s: %s  travelled %.0f m (a wandering chain, not a lap)" % [
			cap, best, sum / maxf(n, 1), marks.values().map(func(v: float) -> String: return "%.1f" % v), (fish.global_position - start).length()])
	input.clear()


func _turn(v: float) -> void:
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var heading := -fish.global_basis.z
	fish.linear_velocity = heading * v
	await _ticks(1)
	var v0 := fish.linear_velocity.length()
	var last := fish.global_position
	var path := 0.0
	var t := 0.0
	var turned := 0.0
	while t < 4.0 and turned < PI * 0.5:
		input.stick = Vector2.RIGHT
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		path += fish.global_position.distance_to(last)
		last = fish.global_position
		turned = absf(heading.signed_angle_to(-fish.global_basis.z, Vector3.UP))
	print("   full stick at %4.1f m/s: 90 deg in %.2fs, radius %5.2f m, speed lost %.1f m/s" % [
			v0, t, path / maxf(turned, 0.01), v0 - fish.linear_velocity.length()])
	input.clear()


func _lengths() -> void:
	var ref := FishCharacter.hitbox_size(FishCharacter.FishClass.SKIRMISHER).z
	var cap := ref * CAP_X
	print("Skirmisher length %.2f m, cap (%.1fx) %.2f m" % [ref, CAP_X, cap])
	var rows: Array = []
	for c: FishCharacter.FishClass in FishCharacter.CLASSES:
		var len := FishCharacter.hitbox_size(c).z
		var hidden: bool = FishCharacter.CLASSES[c].get("hidden", false)
		rows.append(["class", FishCharacter.display_name(c), len, hidden, FishCharacter.species_count(c)])
	for key: String in HunterForms.KEYS:
		var sheet := HunterForms.sheet(key)
		rows.append(["form", str(sheet["name"]), float(sheet["length_m"]), not bool(sheet["ready"]), int(sheet["class"])])
	for r: Array in rows:
		var len: float = r[2]
		print("%-5s %-18s length %6.2f m  capped %5.2f  scale %.3f  (%s %s)" % [r[0], r[1], len, minf(len, cap),
				minf(1.0, cap / len), "hidden/unready" if r[3] else "", r[4]])


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
