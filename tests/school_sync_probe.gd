extends Node3D
## Online co-op's schools (going_coop.md §3.2, Spike C): two copies of one
## School built from the same seed, the host's roaming on its own and a
## guest's following it (School.follower), fed the host's leader and alarm
## SCHOOL_RATE times a second through LAG ms of delay (with jitter and some
## lost), as CoopSession does. The guest's fish should stay close to the
## host's, fish for fish, through turns and a battery's burst: close enough
## that nobody could tell, and that a ram aimed at one lands on the other.
##   Godot_console.exe --headless --path . res://tests/school_sync_probe.tscn

const SCHOOL_RATE := 10.0
const LAG := 0.1
const JITTER := 0.03
const LOSS := 0.05
## How far apart (m) a fish may be on the two machines: on average, and at most.
const MEAN_LIMIT := 0.5
const MAX_LIMIT := 1.5

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := NatureSettings.new()
	var host := School.new()
	var guest := School.new()
	guest.follower = true
	add_child(host)
	add_child(guest)
	var seed_value := 123457
	host.setup(settings, Vector3(0, 10, 0), Vector3.FORWARD, FishCharacter.FishClass.SKIRMISHER, seed_value)
	guest.setup(settings, Vector3(0, 10, 0), Vector3.FORWARD, FishCharacter.FishClass.SKIRMISHER, seed_value)

	print("built:")
	var same := host.display_name == guest.display_name and host.fish_count() == guest.fish_count()
	var placed := 0.0
	for i in host.fish_count():
		placed = maxf(placed, host.fish_position(i).distance_to(guest.fish_position(i)))
	check(same and placed < 0.001, "the same seed builds the same school (%s, %d fish, %.4f m apart)" % [host.display_name, host.fish_count(), placed])

	print("following (%d ms lag, %d ms jitter, %d%% lost):" % [LAG * 1000, JITTER * 1000, LOSS * 100])
	var inbox: Array = []  # [due, state, sent]
	var time := 0.0
	var send_left := 0.0
	var means := PackedFloat32Array()
	var worst := 0.0
	var battered := false
	for tick in 120 * 60:
		await get_tree().physics_frame
		time += 1.0 / 120.0
		send_left -= 1.0 / 120.0
		if send_left <= 0.0:
			send_left += 1.0 / SCHOOL_RATE
			if randf() >= LOSS:
				inbox.append([time + LAG + randf() * JITTER, host.net_state(), time])
		var keep: Array = []
		for item: Array in inbox:
			if item[0] <= time:
				var state: Array = item[1]
				guest.set_net_state(state[0], state[1], state[2], time - item[2])
			else:
				keep.append(item)
		inbox = keep
		if tick == 120 * 30 and not battered:
			# A battery: the host's fish first, the guest's when the word arrives.
			battered = true
			host.batter(3)
			_later(guest, 3)
		if tick > 120 * 5 and tick % 12 == 0:
			var sum := 0.0
			var count := 0
			for i in host.fish_count():
				if host.is_alive(i) and guest.is_alive(i):
					var gap := host.fish_position(i).distance_to(guest.fish_position(i))
					sum += gap
					count += 1
					worst = maxf(worst, gap)
			if count > 0:
				means.append(sum / count)
	var mean := 0.0
	for value in means:
		mean += value
	mean /= maxf(means.size(), 1.0)
	check(mean < MEAN_LIMIT, "a fish is on average %.2f m from its twin over a minute (limit %.1f)" % [mean, MEAN_LIMIT])
	check(worst < MAX_LIMIT, "and never more than %.2f m (limit %.1f)" % [worst, MAX_LIMIT])
	check(not host.is_alive(3) and not guest.is_alive(3) and host.alive_count() == guest.alive_count(), "a battery takes the same fish on both")
	var leaders := host.leader_position.distance_to(guest.leader_position)
	check(leaders < 1.0, "the leaders end %.2f m apart" % leaders)

	print("school_sync_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _later(school: School, index: int) -> void:
	await get_tree().create_timer(LAG).timeout
	school.batter(index)
