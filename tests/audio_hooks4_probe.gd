extends Node
## Sound effects, phase 4 (planning_audio.md §4): space. A bed under each
## environment (and none under a replay, Unnatural's seabed instead of the
## ocean's), the murk closing the underwater low-pass and fading its loop in,
## the surface (breach, splash, the open air), bubble columns, scraping and the
## bow wave, hoop rims, and split-screen's shared mix. Listens to
## Sfx.requested, so it works whatever profile is picked.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/audio_hooks4_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var failures := 0
var heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.requested.connect(func(id: String) -> void: heard.append(id))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	await _beds()
	await _surface()
	await _things()
	_shared_mix()
	print("audio_hooks4_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _beds() -> void:
	print("beds:")
	heard.clear()
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.5)
	check(_bed() == "amb/aquarium_loop", "Free Play: the aquarium's bed (%s)" % _bed())
	check(is_equal_approx(Sfx.underwater_cutoff(), Sfx.WATER_HZ), "and clear water's low-pass (%.0f Hz)" % Sfx.underwater_cutoff())
	heard.clear()
	main.set_mode(main.FREE_SWIM)
	await _seconds(0.5)
	check(_bed() == "amb/ocean_loop" and not heard.has("amb/murk_loop"), "Free Swim: the ocean's bed, no murk (%s)" % _bed())
	heard.clear()
	main.set_mode(main.OBSTACLE_COURSE)
	await _seconds(0.5)
	check(_bed() == "amb/arena_loop", "the obstacle course: its bed (%s)" % _bed())
	heard.clear()
	main.set_mode(main.UNNATURAL)
	await _seconds(0.1)
	main._match_card.play_requested.emit()
	await _seconds(0.8)
	check(heard.has("amb/seabed_loop") and _bed() == "", "Unnatural: the seabed, and the ocean's bed gives way (%s)" % _bed())
	check(heard.has("amb/murk_loop") and Sfx.underwater_cutoff() < Sfx.WATER_HZ - 100.0,
			"its murk: a loop, and the low-pass closes (%.0f Hz)" % Sfx.underwater_cutoff())
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.6)
	check(is_equal_approx(Sfx.underwater_cutoff(), Sfx.WATER_HZ), "back out: clear water again")


func _surface() -> void:
	print("the surface:")
	check(Sfx.water_surface == INF, "no surface in the aquarium")
	fish.freeze = true
	fish.global_position = Vector3(0.0, 10.0, 0.0)
	Sfx.water_surface = 12.0
	await _seconds(0.2)
	heard.clear()
	fish.global_position = Vector3(0.0, 14.0, 0.0)
	await _seconds(0.1)
	check(heard.has("fish/breach"), "up through it: a breach")
	heard.clear()
	fish.global_position = Vector3(0.0, 10.0, 0.0)
	await _seconds(0.1)
	check(heard.has("fish/splash"), "back down: a splash")
	var camera := get_viewport().get_camera_3d()
	Sfx.water_surface = camera.global_position.y - 3.0
	heard.clear()
	await _seconds(1.0)
	var space: SpaceSounds = Sfx.hooks.get_node("Space")
	check(Sfx.is_looping(space._loop) and Sfx.underwater_cutoff() > 10000.0, "a camera above it: the air opens up (%.0f Hz), the surface loop" % Sfx.underwater_cutoff())
	Sfx.water_surface = INF
	await _seconds(1.0)
	check(is_equal_approx(Sfx.underwater_cutoff(), Sfx.WATER_HZ), "and closes again")
	fish.freeze = false


func _things() -> void:
	print("things in the world:")
	var holder := Node3D.new()
	add_child(holder)
	var column := BubbleColumn.new()
	heard.clear()
	holder.add_child(column)
	await _seconds(0.1)
	check(heard.has("arena/bubble_column_loop") and Sfx.is_looping(column.get_meta(&"sfx_loop", 0)), "a bubble column has its loop")
	var handle: int = column.get_meta(&"sfx_loop", 0)
	column.queue_free()
	await _seconds(0.1)
	check(not Sfx.is_looping(handle), "which ends with it")
	holder.queue_free()

	var rim := StaticBody3D.new()
	var hoop := Hoop.new()
	hoop.add_child(rim)
	add_child(hoop)
	heard.clear()
	fish.body_entered.emit(rim)
	check(heard.has("arena/hoop_rim"), "clipping a hoop's rim")
	hoop.queue_free()

	main.set_mode(main.FREE_PLAY)
	await _seconds(0.5)
	heard.clear()
	fish.freeze = false
	fish.global_transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), Vector3(0.0, 0.6, 0.0))
	fish.linear_velocity = Vector3.RIGHT * 20.0
	await _seconds(0.4)
	check(heard.has("fish/scrape_loop"), "sliding along the floor: the scrape (on surface %s, y %.2f)" % [fish.on_surface, fish.global_position.y])
	main.set_mode(main.FREE_SWIM)
	await _seconds(0.3)
	heard.clear()
	fish.bow_wave = true
	fish.boost_enabled = true
	fish.boost_unlimited = true
	var input := FishInput.new()
	fish.controls = input
	input.boost = true
	await _seconds(3.0)
	check(heard.has("fish/bow_wave_loop"), "the bow wave at speed (bow %.2f at %.0f m/s)" % [fish.bow_amount, fish.speed])
	input.boost = false
	fish.controls = null
	await _seconds(0.3)


func _shared_mix() -> void:
	print("split-screen's shared mix:")
	var near := Node3D.new()
	var far := Node3D.new()
	add_child(near)
	add_child(far)
	near.global_position = Vector3.ZERO
	far.global_position = Vector3(100.0, 0.0, 0.0)
	var sound := Vector3(100.0, 0.0, 5.0)
	check(Sfx.heard_at(sound) == sound, "alone: where it is")
	Sfx.ears = [near, far]
	var placed := Sfx.heard_at(sound)
	check(is_equal_approx(placed.distance_to(near.global_position), sound.distance_to(far.global_position)),
			"beside the second player: as near the first as it is the second (%.1f m)" % placed.distance_to(near.global_position))
	check(Sfx.heard_at(Vector3(3.0, 0.0, 0.0)) == Vector3(3.0, 0.0, 0.0), "beside the first: where it is")
	Sfx.ears = []
	near.queue_free()
	far.queue_free()


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame


## The id of the bed under the current environment ("" for none).
func _bed() -> String:
	var bed: BedSounds = main._environment.get_meta(&"sfx_bed", null)
	return bed._bed_id if bed else "(no BedSounds)"
