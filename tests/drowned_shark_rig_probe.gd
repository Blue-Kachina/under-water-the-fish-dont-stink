extends Node
## The Drowned Shark mini-boss on the SwimRig (planning_core_roadmap.md 2.3 P5): with the Monsters' gait's
## procedural_rig off (the default) its model is exactly as it always was (no rig, no bank); with it on the rig
## engages from the boss's own velocity, the wave runs, the body banks into a turn, the mouth follows the head and
## the chomp still works; switching it off hands the body back.
##   Godot_console.exe --headless --path . res://tests/drowned_shark_rig_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var failures := 0


func _ready() -> void:
	GaitSettings.rig_defaults_off = true  # its off-path recordings predate the rig defaults going on
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _place(at: Vector3) -> void:
	fish.freeze = false
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	settings.spawning = false
	settings.card_choices = 0
	settings.chest_count = 0
	settings.shrine_count = 0
	settings.stage_events = false
	settings.twists = false
	settings.base_hp = 100000.0
	settings.enemy_speed_scale = 1.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.bite_damage = 0.0
	settings.iframes = 0.0
	settings.run_length = 0
	settings.shark_chomp_range = 0.0  # no chomps in the way
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	var gait := GaitSettings.shared().for_class(FishCharacter.FishClass.MONSTER)
	check(not gait.procedural_rig, "the Monsters' gait has the rig off by default")
	run.horde.clear()
	await _ticks(2)
	var shark := DrownedShark.new()
	var start := fish.global_position + Vector3(0.0, 0.0, -80.0)
	run._add_boss(shark, start, 100000.0)
	await _ticks(3)
	var model := shark._model as FishModel
	_place(start + Vector3(0.0, 0.0, -200.0))
	shark._charge_left = 1000.0
	await _ticks(120)
	check(shark.velocity.length() > 1.0, "it is swimming after the player (%.1f m/s)" % shark.velocity.length())
	check(model.rig == null and is_zero_approx(model.rotation.z), "rig off: no rig made, no bank")
	var mouth_off := shark.mouth_point()
	var from_body := mouth_off.distance_to(shark.global_position)
	# On.
	gait.procedural_rig = true
	await _ticks(90)
	check(model.rig != null and model.rig.engaged, "rig on: it engages")
	check(model.rig.wave_freq > 0.3, "the wave runs with its speed (%.2f Hz)" % model.rig.wave_freq)
	var mouth_on := shark.mouth_point()
	check(mouth_on.is_finite() and absf(mouth_on.distance_to(shark.global_position) - from_body) < shark._length * 0.25,
			"the mouth stays at the head (%.2f m from the body, %.2f before)" % [mouth_on.distance_to(shark.global_position), from_body])
	# A turn: the prey jumps to its side and it banks.
	var banked := 0.0
	var bent := 0.0
	_place(shark.global_position + shark.global_basis.x * 120.0 + Vector3(0.0, 0.0, 0.0))
	for i in 150:
		await get_tree().physics_frame
		if absf(model.rotation.z) > absf(banked):
			banked = model.rotation.z
		bent = maxf(bent, absf(model.rig.pose.spine_yaw()))
	check(absf(banked) > 0.02, "it banks into the turn (%.3f rad)" % banked)
	check(bent > 0.02, "and curls its spine (%.3f rad)" % bent)
	check(model.rig.pose.is_finite_pose() and model.bend_point(Vector3(0.0, 0.0, 0.8)).is_finite(), "the pose stays finite")
	# A chomp with the rig on still lands.
	settings.shark_chomp_range = 30.0
	shark._chomp_cool = 0.0
	_place(shark.mouth_point() - shark.global_basis.z * settings.shark_chomp_reach * 0.5)
	for i in int((settings.shark_chomp_wind + settings.chomp_strike) * 120) + 60:
		await get_tree().physics_frame
	check(shark.chomps >= 1, "a chomp with the rig on still closes its jaws (%d)" % shark.chomps)
	# Off again.
	gait.procedural_rig = false
	await _ticks(10)
	check(not model.rig.engaged and absf(model.rotation.z) < 1e-5, "rig off again: the body is handed back, no bank")
	print("drowned_shark_rig_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)
