extends Node
## Race roster (planning_race.md probes): every roster entry, dressed and given the shared speed + RaceHandling, swims a
## perfect stride chain to the same top speed (within TOLERANCE), fits under the size cap, and leaves nothing behind when
## its modifiers are popped. Deviations are printed as open items, they do not retune anything.
##   Godot_console.exe --headless --path . res://tests/race_roster_probe.tscn [-- --only=hunter --run=10]

const TOLERANCE := 0.02
const CHAIN_TIME := 12.0
const MEASURE_FROM := 8.0

var main: Node
var fish: FishController
var input := FishInput.new()
var failures := 0
var deviations: Array[String] = []
var chain_time := CHAIN_TIME
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
		elif arg.begins_with("--run="):
			chain_time = float(arg.substr(6))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	RaceRoster.entries()  # warm the class cache
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL  %s" % what)
		failures += 1


func _run() -> void:
	var rs := RaceSettings.shared()
	var base_look := [int(fish.character), fish.species, fish.skin]
	var entries := RaceRoster.entries()
	check(entries.size() > 0, "the roster has entries")
	print("%d entries, top speed %.1f m/s, size cap %.1f" % [entries.size(), rs.race_top_speed, rs.race_size_cap])
	var cap_len := FishCharacter.hitbox_size(FishCharacter.FishClass.SKIRMISHER).z * rs.race_size_cap
	for e in entries:
		if only != "" and str(e["family"]) != only:
			continue
		await _one(e, rs, cap_len)
	fish.set_look(int(base_look[0]) as FishCharacter.FishClass, int(base_look[1]), int(base_look[2]))
	print("--- %d speed deviations over %.0f%%:" % [deviations.size(), TOLERANCE * 100.0])
	for d in deviations:
		print("  open item: %s" % d)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _one(e: Dictionary, rs: RaceSettings, cap_len: float) -> void:
	var before_speed := fish.top_speed_scale
	RaceRoster.dress(fish, e, rs.race_size_cap)
	fish.modifiers.push("race.shared", rs.shared_modifiers(fish.stroke_max_speed))
	fish.modifiers.push("race.handling", RaceHandling.modifiers(RaceHandling.of(e)))
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var peak := fish.stride_peak_time
	var t := 0.0
	var sum := 0.0
	var n := 0
	while t < chain_time:
		input.stick = Vector2.RIGHT * (1.0 if int(t / peak) % 2 == 0 else -1.0)
		input.forward = 1.0
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t > MEASURE_FROM:
			sum += fish.speed
			n += 1
	var mean := sum / maxf(n, 1)
	var rel := mean / rs.race_top_speed - 1.0
	var length: float = fish.hitbox_length
	check(length <= cap_len * 1.02, "%s: hitbox %.1f m over the cap %.1f m" % [e["key"], length, cap_len])
	var flag := ""
	if absf(rel) > TOLERANCE:
		flag = "  <-- off"
		deviations.append("%s mean %.2f m/s (%+.1f%%)" % [e["key"], mean, rel * 100.0])
	print("  %-34s mean %5.2f m/s (%+5.1f%%)  length %5.1f m%s" % [e["key"], mean, rel * 100.0, length, flag])
	input.clear()
	fish.modifiers.pop("race.shared")
	fish.modifiers.pop("race.handling")
	fish.modifiers.pop(RaceRoster.MODS_SIZE)
	check(is_equal_approx(fish.top_speed_scale, before_speed), "%s: popping the modifiers restores the top speed" % e["key"])



func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
