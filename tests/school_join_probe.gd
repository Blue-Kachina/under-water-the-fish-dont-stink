extends Node
## What Stinks? Phase 2 (what_stinks.md section 5): joining a school. Part one
## is School alone (claim, ease-in, lockstep, lean, release, a claimed place
## eaten, startle): a twin school from the same seed with no claims is the
## control, so the checks also show a claim never changes the school's own sim
## (which is what keeps it deterministic for the net). Part two plays the real
## mode through Main: schools made of the prey's classes, the join prompt and
## radius, join_any_class, the player's fish frozen and out of collisions with
## its model hidden, lockstep, leaning by the stick, Leave (dash, loud, echo
## reset, rejoin cooldown), Spook (one per round, echo reset in the school),
## a joined player eaten with its place, ally markers, name plates hidden from
## the Hunter, prey bots joining, and a new round letting everyone go.
##   Godot_console.exe --headless --path . res://tests/school_join_probe.tscn

var main: Node
var game: WhatStinksMatch
var fish: FishController
var failures := 0
var checks := 0
var camera := Camera3D.new()


func _ready() -> void:
	add_child(camera)
	camera.global_position = Vector3(0, 900, 0)  # far off: no full models
	camera.make_current()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(done: Callable, seconds: float) -> bool:
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _school(settings: NatureSettings, parent: Node) -> School:
	var school := School.new()
	parent.add_child(school)
	school.setup(settings, Vector3(2000, 0, 0), Vector3.FORWARD, FishCharacter.FishClass.SKIRMISHER, 11)
	return school


func _run() -> void:
	await _school_part()
	await _match_part()
	print("school_join_probe: %d of %d checks failed" % [failures, checks])
	get_tree().quit(1 if failures else 0)


# --- Part one: the School -------------------------------------------------------

func _school_part() -> void:
	var settings := NatureSettings.new()
	settings.fish_per_school = 40
	settings.fish_scale = 0.5
	var school := _school(settings, self)
	var twin := _school(settings, self)  # the same seed, no claims
	var other: FishController = load("res://scenes/fish.tscn").instantiate()
	other.freeze = true
	add_child(other)
	var player: FishController = load("res://scenes/fish.tscn").instantiate()
	add_child(player)
	player.freeze = true
	await _frames(240)

	print("claiming a place:")
	var near := school.fish_position(5) + Vector3(2.5, 1.0, 0.0)
	player.global_position = near
	var expect := school.nearest_free(near)
	var index := school.claim_nearest(player, near, 0.6)
	check(index == expect and index >= 0, "the nearest free fish is claimed (%d)" % index)
	check(school.is_claimed(index) and school.claimed_by(index) == player and school.claim_of(player) == index, "the school knows who has it")
	check(school.claimed_count() == 1 and school.claimed_indices() == [index], "one place claimed")
	check(not school.claim(index, other, 0.6), "a claimed place can't be claimed again")
	check(school.claim_of(player) == index and not school.claim(school.nearest_free(near), player, 0.6), "a fish can't hold two places")
	check(school.nearest_free(near) != index, "the next free fish is a different one")
	check(not school.claim(-1, other) and not school.claim(9999, other), "bad indices are refused")

	print("easing in, then lockstep:")
	var start := player.global_position
	await _frames(1)
	check(player.global_position.distance_to(start) < 1.0 and school.claim_progress(player) < 0.2, "it starts where the player was (%.2f m moved, progress %.2f)" % [player.global_position.distance_to(start), school.claim_progress(player)])
	var last := player.global_position
	var worst_jump := 0.0
	var progress_ok := true
	var last_progress := 0.0
	for i in 60:  # 0.5 s of ticks
		await _frames(1)
		worst_jump = maxf(worst_jump, player.global_position.distance_to(last))
		last = player.global_position
		var now := school.claim_progress(player)
		progress_ok = progress_ok and now >= last_progress - 0.0001
		last_progress = now
	check(worst_jump < 0.5, "no snap on the way in (biggest step %.3f m a tick)" % worst_jump)
	check(progress_ok and last_progress > 0.5, "progress rises (%.2f)" % last_progress)
	await _frames(120)
	check(school.claim_progress(player) >= 0.999, "eased in by join_ease")
	var gap := player.global_position.distance_to(school.fish_position(index))
	check(gap < 0.4, "the fish sits on its place (%.2f m off)" % gap)
	check(player.linear_velocity.distance_to(school.fish_velocity(index)) < 0.01, "and moves with it (%.2f m/s apart)" % player.linear_velocity.distance_to(school.fish_velocity(index)))
	var heading_gap := (-player.global_basis.z).angle_to(school.fish_heading(index))
	check(heading_gap < 0.3, "facing the way the fish does (%.2f rad)" % heading_gap)
	await _frames(240)
	check(player.global_position.distance_to(school.fish_position(index)) < 0.4, "still in lockstep 2 s later")
	var same := true
	for i in school.fish_count():
		if i != index:
			same = same and school.fish_position(i).distance_to(twin.fish_position(i)) < 0.001
	check(same, "the claim left every other fish exactly where the unclaimed twin has it")
	check(school.fish_position(index).distance_to(twin.fish_position(index)) < 0.05, "and its own place too, with no lean")

	print("leaning:")
	school.set_lean(player, Vector2(1.0, 0.0), 2.0)
	await _frames(180)
	var lean := school.fish_position(index) - twin.fish_position(index)
	check(lean.length() > 1.6 and lean.length() < 2.2, "the stick leans the place about its range (%.2f m of 2)" % lean.length())
	check(absf(lean.normalized().dot(Vector3.UP)) < 0.5, "sideways for a sideways stick")
	check(player.global_position.distance_to(school.fish_position(index)) < 0.4, "the fish follows its place")
	school.set_lean(player, Vector2(0.0, 1.0), 2.0)
	await _frames(180)
	lean = school.fish_position(index) - twin.fish_position(index)
	check(lean.y > 1.2, "an upward stick leans up (%.2f m)" % lean.y)
	school.set_lean(player, Vector2.ZERO, 2.0)
	await _frames(240)
	check((school.fish_position(index) - twin.fish_position(index)).length() < 0.15, "centred again")

	print("release:")
	var out := school.release_claim(player)
	check(not out.is_empty() and out["position"] is Vector3 and out["velocity"] is Vector3, "release says where and how it was")
	check(not school.is_claimed(index) and school.claim_of(player) == -1 and school.claimed_count() == 0, "the place is free")
	check(school.is_alive(index), "the school fish stays")
	check(school.release_claim(player).is_empty(), "releasing twice gives nothing")

	print("a claimed place eaten:")
	var lost: Array = []
	school.claim_lost.connect(func(f: FishController) -> void: lost.append(f))
	var victim := school.claim_nearest(player, player.global_position, 0.0)
	await _frames(10)
	var before := school.alive_count()
	school.eat([victim], 2.5, 2.5, 3, 4.0)
	check(lost == [player], "the fish is told its place is gone")
	check(not school.is_claimed(victim) and not school.is_alive(victim) and school.alive_count() == before - 1, "the place is gone, the claim with it")
	var again := school.claim_nearest(player, player.global_position, 0.6)
	check(again >= 0 and again != victim, "it can claim another")
	school.batter(again)
	check(lost.size() == 2 and not school.is_claimed(again), "a battery does the same")
	var mask := school.alive_mask()
	var guest := _school(settings, self)
	var guest_claim := guest.claim_nearest(player, guest.fish_position(3), 0.0)
	guest.apply_alive_mask(mask)
	check(guest_claim < 0 or guest.is_claimed(guest_claim) == (mask[guest_claim] == 1), "a mask that kills a place drops its claim")

	print("startle:")
	var calm := _school(settings, self)
	await _frames(240)
	var top_before := 0.0
	for i in calm.fish_count():
		top_before = maxf(top_before, calm.fish_velocity(i).length())
	var tight := calm.radius()
	calm.startle(3.0, 3, 4.0)
	check(is_equal_approx(calm.alarm, 1.0), "the whole school is at full alarm")
	var top_after := 0.0
	for i in calm.fish_count():
		top_after = maxf(top_after, calm.fish_velocity(i).length())
	check(top_after > top_before + 5.0, "every fish bolts (top speed %.1f from %.1f m/s)" % [top_after, top_before])
	await _frames(240)
	var spread := 0.0
	var middle := calm.middle()
	for i in calm.fish_count():
		spread = maxf(spread, calm.fish_position(i).distance_to(middle))
	check(spread > tight * 1.5, "it splits (farthest %.1f m, school radius %.1f)" % [spread, tight])
	await _frames(120 * 12)
	spread = 0.0
	middle = calm.middle()
	for i in calm.fish_count():
		spread = maxf(spread, calm.fish_position(i).distance_to(middle))
	check(spread < tight * 2.5, "and re-forms (farthest %.1f m)" % spread)
	school.queue_free()
	twin.queue_free()
	guest.queue_free()
	calm.queue_free()


# --- Part two: the mode ---------------------------------------------------------

func _match_part() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 1.0
	settings.round_time = 600.0
	settings.round_over_time = 0.5
	settings.match_over_time = 600.0
	settings.arena_radius = 150.0
	settings.school_count = 6
	settings.school_min = 30
	settings.school_max = 40
	settings.min_players = 4
	settings.bot_hunter_rounds = 1
	settings.start_as = WhatStinksSettings.StartAs.PREY
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.bots_join = false
	settings.join_any_class = false
	settings.join_radius = 4.0
	settings.join_ease = 0.6
	settings.rejoin_cooldown = 1.0
	settings.spook_charges = 1
	settings.school_prey_share = 0.7
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks

	print("the round:")
	check(game != null and game.join != null, "the match has a join system")
	if game == null:
		return
	check(not game.is_hunter(fish) and game.is_live_prey(fish), "the local fish is prey")
	var hunter: FishController = game.hunters[0]
	check(game.bots.has(hunter), "a bot hunts")
	var base_class := fish.character
	var own_kind := 0
	var kinds := {}
	for school in game.field.schools:
		kinds[school.character] = true
		if school.character == base_class:
			own_kind += 1
	check(own_kind >= 1, "a school of the player's own class exists (%d of %d)" % [own_kind, game.field.schools.size()])
	var prey_classes := {}
	for other in game.players:
		if other != hunter:
			prey_classes[game.join.class_of(other)] = true
	var covered := true
	for kind in prey_classes:
		covered = covered and kinds.has(kind)
	check(covered, "every class the prey play has a school (%d classes)" % prey_classes.size())
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 4.0), "live")
	# The Hunter sits still (a bot would eat the probe's fish).
	game.bots[hunter].set_physics_process(false)
	hunter.controls_locked = true
	hunter.freeze = true
	hunter.global_position = Vector3(0, -300, 0)
	for other in game.players:
		if other != fish and other != hunter:
			other.freeze = true

	var own: School
	var foreign: School
	for school in game.field.schools:
		if school.character == base_class and own == null:
			own = school
		elif school.character != base_class and foreign == null:
			foreign = school
	check(own != null and foreign != null, "an own-class school and another class's to test with")
	if own == null or foreign == null:
		return
	own.set_physics_process(false)  # pinned for the radius checks
	foreign.set_physics_process(false)

	print("the radius and the class:")
	var spot := own.fish_position(0)
	_place(fish, spot + Vector3(settings.join_radius * 0.5, 0, 0))
	check(game.join.joinable_school(fish) == own, "a school fish within the radius: joinable")
	check(game.join.prompt_for(fish).contains("Join"), "the prompt says so (\"%s\")" % game.join.prompt_for(fish))
	_place(fish, spot + Vector3(settings.join_radius * 6.0, 0, 0))
	check(game.join.joinable_school(fish) == null and game.join.prompt_for(fish) == "", "well outside it: nothing to join")
	check(not game.join.join(fish), "join() refuses out of range")
	_place(fish, foreign.fish_position(0) + Vector3(1.0, 0, 0))
	check(game.join.joinable_school(fish) == null, "another class's school isn't joinable (join_any_class off)")
	check(not game.join.join(fish, foreign), "even when told which")
	settings.join_any_class = true
	check(game.join.joinable_school(fish) == foreign, "join_any_class on: it is")
	settings.join_any_class = false
	own.set_physics_process(true)
	foreign.set_physics_process(true)

	print("joining:")
	var model: Node3D = fish.get("_visual")
	var layers := [fish.collision_layer, fish.collision_mask]
	var joined_events: Array = []
	game.join.joined.connect(func(f: FishController, s: School, i: int) -> void: joined_events.append([f, s, i]))
	_place(fish, own.fish_position(0) + Vector3(2.0, 0.5, 0.0))
	var count_before := own.alive_count()
	check(game.join.join(fish), "the player joins")
	var place := own.claim_of(fish)
	check(game.join.is_joined(fish) and game.join.school_of(fish) == own and place >= 0, "it holds a place in the school (%d)" % place)
	check(joined_events.size() == 1 and joined_events[0][0] == fish and joined_events[0][2] == place, "joined was announced")
	check(own.alive_count() == count_before and own.is_alive(place), "its place is a real school fish, none added or taken")
	check(fish.freeze and fish.controls_locked, "the fish is frozen and its own controls are off (the school moves it)")
	check(fish.collision_layer == 0 and fish.collision_mask == 0, "and touches nothing")
	check(not model.visible, "its own model is hidden: the school fish shows in its place")
	check(not game.join.join(fish), "it can't join twice")
	check(game.join.prompt_for(fish).contains("Leave"), "the prompt is Leave now (\"%s\")" % game.join.prompt_for(fish))
	await _frames(240)
	var apart := fish.global_position.distance_to(own.fish_position(place))
	check(apart < 0.5, "in lockstep with its place (%.2f m off)" % apart)
	check(fish.linear_velocity.distance_to(own.fish_velocity(place)) < 0.5, "same velocity (%.2f m/s apart)" % fish.linear_velocity.distance_to(own.fish_velocity(place)))
	check(game.is_live_prey(fish), "joined prey are still live prey")

	print("the view:")
	var marker: Node3D = game.join._markers.get(fish)
	check(marker != null and marker.visible, "a prey player sees its own marker")
	game.role[fish] = WhatStinksMatch.Role.HUNTER
	game.join._update_markers()
	check(not marker.visible, "a Hunter's view has no markers")
	var prey_mate: FishController = game.live_prey()[1] if game.live_prey()[0] == fish else game.live_prey()[0]
	check(not game.shows_plate(prey_mate), "the Hunter sees no prey's name plate")
	check(game.shows_plate(hunter), "but another Hunter's")
	game.role[fish] = WhatStinksMatch.Role.PREY
	game.join._update_markers()
	check(marker.visible and game.shows_plate(prey_mate), "prey see markers and plates")
	var plates_ok := true
	for other in game.players:
		plates_ok = plates_ok and game.shows_plate(other)
	check(plates_ok, "prey see every plate")

	print("Spook:")
	var mate: FishController
	for other in game.players:
		if other != fish and other != hunter and mate == null:
			mate = other
	other_unfreeze(mate)
	_place(mate, own.fish_position(2) + Vector3(1.0, 0, 0))
	settings.join_any_class = true  # the bot's class may not be the school's
	check(game.join.join(mate, own), "a second prey joins the same school")
	settings.join_any_class = false
	check(own.claimed_count() == 2 and own.claim_of(mate) != own.claim_of(fish), "on a different place")
	game.join.echo[fish] = 0.7
	game.join.echo[mate] = 0.4
	var spooks: Array = []
	var resets: Array = []
	game.join.spooked.connect(func(f: FishController, s: School) -> void: spooks.append([f, s]))
	game.join.echo_reset.connect(func(f: FishController) -> void: resets.append(f))
	check(int(game.join.charges[fish]) == 1, "one spook this round")
	var calm_alarm := own.alarm
	check(game.join.spook(fish), "the spook goes off")
	check(spooks.size() == 1 and spooks[0][1] == own, "it was announced")
	check(own.alarm > 0.99 and own.alarm > calm_alarm - 0.0001, "the school is at full alarm (%.2f)" % own.alarm)
	check(float(game.join.echo[fish]) == 0.0 and float(game.join.echo[mate]) == 0.0, "every joined echo in the school is back to 0")
	check(resets.has(fish) and resets.has(mate), "the echo reset was announced for both")
	check(int(game.join.charges[fish]) == 0 and not game.join.spook(fish), "a second spook is refused")
	check(game.join.is_joined(fish) and game.join.is_joined(mate), "both are still joined")
	await _frames(240)
	check(fish.global_position.distance_to(own.fish_position(own.claim_of(fish))) < 0.6, "the player moves with its school through the panic")

	print("Leave:")
	game.join.leave(mate, false)
	var left_events: Array = []
	game.join.left.connect(func(f: FishController, loud: bool) -> void: left_events.append([f, loud]))
	game.join.echo[fish] = 0.9
	var school_speed := own.fish_velocity(own.claim_of(fish))
	var mid := own.fish_position(own.claim_of(fish))
	check(game.join.leave(fish), "the player leaves")
	check(not game.join.is_joined(fish) and own.claim_of(fish) == -1, "out of the school")
	check(left_events.size() == 1 and left_events[0] == [fish, true], "announced as a loud leave")
	check(int(game.join.loud_leaves.get(fish, 0)) == 1, "counted as loud")
	check(float(game.join.echo[fish]) == 0.0, "its echo is back to 0")
	check(not fish.freeze and not fish.controls_locked and model.visible, "the fish is its own again")
	check(fish.collision_layer == layers[0] and fish.collision_mask == layers[1], "collisions are back")
	check(fish.linear_velocity.distance_to(school_speed) > settings.leave_speed * 0.8, "it dashed out (%.1f m/s over the school's)" % fish.linear_velocity.distance_to(school_speed))
	check(game.join._markers.get(fish) == null, "its marker is gone")
	check(not game.join.leave(fish), "leaving twice does nothing")
	_place(fish, mid)
	check(not game.join.can_join(fish) and not game.join.join(fish), "the rejoin cooldown holds it out")
	check(game.join.prompt_for(fish).contains("again"), "and says so (\"%s\")" % game.join.prompt_for(fish))
	check(await _until(func() -> bool: return game.join.can_join(fish), settings.rejoin_cooldown + 1.0), "the cooldown ends")
	_place(fish, own.fish_position(0) + Vector3(1.5, 0, 0))
	check(game.join.join(fish), "it can rejoin")

	print("lean through the stick:")
	var lean_place := own.claim_of(fish)
	Input.action_press("stick_right", 1.0)
	await _frames(240)
	var leaned: Vector3 = own._claims[lean_place]["ofs"]
	Input.action_release("stick_right")
	print("      lean from the stick: %.2f m (join_lean %.1f)" % [leaned.length(), settings.join_lean])
	check(leaned.length() > settings.join_lean * 0.8 and leaned.length() < settings.join_lean * 1.2, "the stick leans the player's place by join_lean")
	await _frames(240)
	leaned = own._claims[lean_place]["ofs"]
	check(leaned.length() < 0.2, "and centres when released (%.2f m)" % leaned.length())

	print("eaten with its place:")
	var alive_before := own.alive_count()
	var held := own.claim_of(fish)
	var point := fish.global_position
	var gone := game.field.eat_at(point, 1, func(at: Vector3) -> bool: return at.distance_to(point) < 0.6, [fish])
	check((gone["fish"] as Array) == [fish], "the bite took the joined player")
	check(not own.is_alive(held) and own.alive_count() == alive_before - 1, "and its school fish with it")
	check(int(gone["school_fish"]) == 0, "counted as a player, not a school fish")
	check(not game.join.is_joined(fish) and own.claim_of(fish) == -1, "the join system let it go")
	check(model.visible and fish.collision_layer == layers[0], "its model and collisions are restored (the match then hides the eaten)")

	print("bots join:")
	settings.bots_join = true
	settings.join_any_class = true
	var robot: FishController = mate
	robot.freeze = false
	_place(robot, own.fish_position(1) + Vector3(2.0, 0, 0))
	await _frames(30)
	check(game.join.is_joined(robot), "a bot within the radius joins a school by itself")
	settings.bots_join = false
	settings.join_any_class = false

	print("a new round:")
	var joined_now := game.join.is_joined(robot)
	game.join.begin_round(game.players)
	check(joined_now and game.join.schools.is_empty() and not robot.freeze and robot.get("_visual").visible, "begin_round lets everyone go")
	check(int(game.join.charges[fish]) == settings.spook_charges and game.join.cooldown.is_empty(), "spooks and cooldowns are fresh")
	game.start_round(1)
	await _frames(5)
	check(game.join.schools.is_empty(), "a started round has nobody joined")
	check(game.field.prey_kinds.size() >= 1, "and its schools are made of the prey's classes")
	game.end()


func other_unfreeze(f: FishController) -> void:
	f.freeze = false


func _place(f: FishController, at: Vector3) -> void:
	f.global_position = at
	f.linear_velocity = Vector3.ZERO
	f.angular_velocity = Vector3.ZERO
