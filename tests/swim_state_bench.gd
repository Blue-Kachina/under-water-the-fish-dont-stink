extends Node
## What SwimState costs a physics tick (M5 acceptance: under 5 % on the parity
## probe's tick). Swims a stride run in the Ocean and averages the engine's
## physics-process time per tick, which holds the fish's _integrate_forces; on a
## fish with swim_state it also times _fill_swim_state alone. Run it on both
## trees and compare:
##   Godot_console.exe --headless --path . res://tests/swim_state_bench.tscn

const WARM := 240
const TICKS := 2400

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
	fish.request_reset()
	var peak_ticks := maxi(roundi(fish.swishy.peak_time() * 120.0), 1)
	var total := 0.0
	for tick in WARM + TICKS:
		input.forward = 1.0
		input.stick = Vector2.RIGHT * (1.0 if floori(float(tick) / peak_ticks) % 2 == 0 else -1.0)
		await get_tree().physics_frame
		if tick >= WARM:
			total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("physics process per tick: %.1f us (mean over %d ticks)" % [total / TICKS * 1e6, TICKS])
	if fish.has_method("_fill_swim_state"):
		var body := Basis.IDENTITY
		var start := Time.get_ticks_usec()
		for i in 100000:
			fish.call("_fill_swim_state", Vector3(0.0, 0.0, -10.0), body, Vector3.ZERO, 1.0 / 120.0)
		print("_fill_swim_state alone: %.2f us a call" % ((Time.get_ticks_usec() - start) / 100000.0))
	get_tree().quit()
