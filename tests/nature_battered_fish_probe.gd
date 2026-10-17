extends Node
## Battered fish on school fish in a Nature run: a fast ram nose first through a
## school batters several of them (scoring, a multi, explosions, fewer fish); a
## slow pass, or one sideways, batters none; each fish costs the player speed as
## hit_speed_cost says, never under the battering speed with the guard on; the
## survivors burst away and a rush makes a school tighten; pearls drop by
## chance, more in a multi, and are drawn in and counted.
##   Godot_console.exe --headless --path . res://tests/nature_battered_fish_probe.tscn

var main: Node
var fish: FishController
var settings := NatureSettings.shared()
var run: NatureRun
var failures := 0
var events: Array = []
## The most scared any school got during the last _ram().
var peak_alarm := 0.0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_mode(main.NATURE)
	await _ticks(3)
	settings.lone_target = false
	settings.school_count = 1
	settings.school_speed = 0.0  # held still, so the rams are repeatable
	settings.pearl_chance = 0.0
	settings.pearl_chance_per_step = 0.0
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.nature_run
	run.awarded.connect(func(event: Dictionary) -> void: events.append(event))
	var school: School = run.schools[0]
	await _ticks(240)  # settle in place

	print("slow pass:")
	var before := school.alive_count()
	await _ram(school, fish.nature_batter_speed * 0.5)
	check(school.alive_count() == before and run.battered_fish == 0, "under the battering speed: none battered")

	print("sideways:")
	await _ram(school, fish.nature_batter_speed + 8.0, true)
	check(school.alive_count() == before and run.battered_fish == 0, "fast but side on: none battered")

	print("fast ram:")
	school.alarm = 0.0
	var speed_before := fish.nature_batter_speed + 10.0
	await _ram(school, speed_before)
	var battered := before - school.alive_count()
	check(battered >= 2, "a fast ram through the school batters several (%d)" % battered)
	check(run.battered_fish == battered and run.score.points > 0, "counted (%d) and scored (%d points)" % [run.battered_fish, run.score.points])
	check(events.any(func(e: Dictionary) -> bool: return e.type == NatureScore.MULTI and e.title == "DOUBLE DIP"), "a multi: DOUBLE DIP")
	check(run.score.best_chain == battered, "all one chain (%d)" % run.score.best_chain)
	check(fish.speed >= fish.nature_batter_speed - 0.5, "the guard keeps it at the battering speed (%.1f m/s)" % fish.speed)
	check(peak_alarm > 0.3, "the rush scared the school (alarm up to %.2f)" % peak_alarm)

	print("speed cost:")
	settings.hit_speed_cost = 0.5
	settings.hit_cost_keeps_batter_speed = false
	var target: School = await _fresh_school()
	var fast := fish.nature_batter_speed + 30.0
	var first := run.battered_fish
	var line := _aim(target)
	fish.linear_velocity = line * fast
	var just_before := fast
	for i in 240:
		if run.battered_fish > first:
			break
		just_before = fish.linear_velocity.length()
		await get_tree().physics_frame
	var hits := run.battered_fish - first
	await _ticks(1)  # the push lands on the next physics step
	var after := fish.linear_velocity.length()
	check(hits >= 1, "battered %d" % hits)
	check(hits >= 1 and after < just_before * 0.6 and after < fish.nature_batter_speed + 30.0, "half the speed off for each (%.1f m/s, from %.1f, %d hit)" % [after, just_before, hits])
	fish.linear_velocity = Vector3.ZERO
	settings.hit_speed_cost = 0.03
	settings.hit_cost_keeps_batter_speed = true

	print("burst:")
	var loose := School.new()
	run.add_child(loose)
	loose.setup(settings, fish.global_position + Vector3(0, 40, 0), Vector3.FORWARD, FishCharacter.Family.OCTANE)
	await _ticks(120)
	var middle := 0
	var best := INF
	for i in loose.fish_count():
		var gap := loose.fish_position(i).distance_to(loose.centre.global_position)
		if gap < best:
			best = gap
			middle = i
	var near_before := []
	for i in loose.fish_count():
		if i != middle and loose.fish_position(i).distance_to(loose.fish_position(middle)) < settings.burst_radius * 0.6:
			near_before.append([i, loose.fish_velocity(i)])
	var at := loose.batter(middle)
	var outward := 0
	for entry: Array in near_before:
		var change: Vector3 = loose.fish_velocity(entry[0]) - entry[1]
		if change.dot(loose.fish_position(entry[0]) - at) > 0.0 and change.length() > 1.0:
			outward += 1
	check(not near_before.is_empty() and outward == near_before.size(), "the survivors near it burst away (%d of %d)" % [outward, near_before.size()])
	loose.queue_free()

	print("pearls:")
	settings.pearl_chance = 1.0
	var pearl_school: School = await _fresh_school()
	await _ram(pearl_school, fish.nature_batter_speed + 10.0)
	await _ticks(1)
	var dropped := run.pearls_out.size() + run.pearls
	check(dropped >= 1, "pearl_chance 1: battered fish leave pearls (%d)" % dropped)
	settings.pearl_chance = 0.0
	settings.pearl_chance_per_step = 0.5
	var pearls_before := run.pearls_out.size() + run.pearls
	var fresh: School = await _fresh_school()
	await _ram(fresh, fish.nature_batter_speed + 10.0)
	await _ticks(1)
	var chained := run.pearls_out.size() + run.pearls - pearls_before
	check(chained >= 1 and chained < run.score.best_chain, "chance 0 + 0.5 a step: only deeper into the multi (%d pearls)" % chained)
	settings.pearl_chance_per_step = 0.0
	# A pearl to one side: drawn in from 4 m as the fish speeds past, not from 10.
	for pearl in run.pearls_out.duplicate():
		pearl.queue_free()
	await _ticks(2)
	var collected := run.pearls
	var near_pearl := await _pearl_pass(4.0)
	check(run.pearls == collected + 1 and not is_instance_valid(near_pearl), "passing 4 m off at speed collects it (%d)" % run.pearls)
	var far_pearl := await _pearl_pass(10.0)
	check(run.pearls == collected + 1 and is_instance_valid(far_pearl), "passing 10 m off doesn't")
	far_pearl.age = settings.pearl_lifetime - 0.05
	await _ticks(12)
	check(not is_instance_valid(far_pearl), "left alone, it fades away at its lifetime")

	settings.lone_target = true
	settings.school_count = 3
	settings.school_speed = 5.5
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("nature_battered_fish_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## A new school (fresh fish, held still) near the player, settled.
func _fresh_school() -> School:
	var old: School = run.schools[0]
	run._replace_school(old)
	var school: School = run.schools[-1]
	await _ticks(240)
	return school


## The player 12 m from the school's centre, heading through it at `speed`
## (nose first, or side on), for long enough to cross it, or `ticks` if given.
func _ram(school: School, speed: float, sideways := false) -> void:
	var line := _aim(school, sideways)
	var start := fish.global_position
	fish.linear_velocity = line * speed
	peak_alarm = 0.0
	var crossing := roundi((24.0 / maxf(speed, 1.0)) * 120.0) + 10
	for i in crossing:
		fish.linear_velocity = fish.linear_velocity.normalized() * maxf(fish.linear_velocity.length(), speed * 0.5)
		await get_tree().physics_frame
		peak_alarm = maxf(peak_alarm, school.alarm)
		if fish.global_position.distance_to(start) > 24.0:
			break
	fish.linear_velocity = Vector3.ZERO


## Puts the player 12 m from the school's centre, facing (or side on to) the
## line through it. Returns the line.
func _aim(school: School, sideways := false) -> Vector3:
	var middle := school.middle()
	var line := Vector3(1, 0, 0.3).normalized()
	var facing := Basis.looking_at(line.cross(Vector3.UP) if sideways else line, Vector3.UP)
	fish.global_transform = Transform3D(facing, middle - line * 12.0)
	fish.angular_velocity = Vector3.ZERO
	return line


## A pearl `off` m to the side of the player's line, the player passing it at 25 m/s.
func _pearl_pass(off: float) -> Pearl:
	var start := fish.global_position + Vector3(0, 30, 0)
	var line := Vector3.FORWARD
	var pearl := Pearl.new(settings)
	pearl.collectors = [fish]
	pearl.position = start + line * 15.0 + Vector3.RIGHT * off
	run.add_child(pearl)
	pearl.collected.connect(run._on_pearl_collected)
	fish.global_transform = Transform3D(Basis.looking_at(line, Vector3.UP), start)
	for i in 240:
		fish.linear_velocity = line * 25.0
		await get_tree().physics_frame
	fish.linear_velocity = Vector3.ZERO
	await _ticks(60)
	return pearl


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
