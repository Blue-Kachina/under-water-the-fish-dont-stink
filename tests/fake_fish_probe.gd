extends Node
## Marco Polo's Fake Fish (planning_marco_polo.md §9, phase 6):
## - a hider's skill throws one (one charge a round, none in a porthole or as a seeker);
## - it's a copy of the thrower (class and species), registered as a decoy;
## - throwing it is silent for the thrower; it swims off along their facing at
##   about fake_speed, striding badly with a flip or two: pings on the scope
##   and layers in the seeker's view;
## - after fake_life it pops (bubbles, mp/fake_pop, a last ping) and is gone;
## - a seeker's tag pops it too: FOOLED (signal, mp/fooled, fooled_hold).
##   Godot_console.exe --headless --path . res://tests/fake_fish_probe.tscn [-- --arena=NAME]

const TICKS := 120

var main: Node
var fish: FishController
var failures := 0
var mp: MarcoPoloSettings
var arena_name := "Sunken Temple"
var sounds: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			arena_name = arg.trim_prefix("--arena=")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	mp = MarcoPoloSettings.shared()
	Sfx.requested.connect(func(id: String) -> void: sounds.append(id))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	mp.hide_time = 0.3
	mp.round_time = 120.0
	mp.round_over_time = 0.3
	mp.min_players = 3
	mp.rounds = 3
	mp.bot_seeker_rounds = 11  # every bot a turn (it was a bool)
	mp.fake_charges = 1
	mp.fake_life = 3.0
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.arena = arena_name if main.ENVIRONMENTS.has(arena_name) else "Ocean"
	print("Fake Fish in the %s:" % mp.arena)
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null, "the match is on")
	if game == null:
		_finish()
		return
	game.start_round(1)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	check(game.is_live_hider(fish), "the player hides")
	var seeker: FishController = game.seekers()[0]
	var open := _open_water(game)
	# The player in open water facing +x, the seeker 20 m off to the side watching.
	_park(fish, open, Vector3.RIGHT)
	fish.freeze = false
	_park(seeker, open + Vector3(8.0, 0.0, 18.0), (open + Vector3(8.0, 0.0, 0.0) - (open + Vector3(8.0, 0.0, 18.0))).normalized())
	await _ticks(10)
	fish.freeze = true  # held still: any noise it makes is the throw's
	var noise_before := game.noise(fish)
	var pings_before := game.recent_pings(seeker).size()
	var flips := [0]
	check(game.fake_charges(fish) == mp.fake_charges, "a hider starts the round with %d charge" % mp.fake_charges)
	check(game.throw_fake(fish), "the skill throws a Fake Fish")
	check(game.fake_charges(fish) == 0 and not game.throw_fake(fish), "one a round: the second press does nothing")
	check(not game.throw_fake(seeker), "seekers have none")
	await _ticks(1)
	var fakes := game.decoys()
	check(fakes.size() == 1, "one decoy registered (%d)" % fakes.size())
	if fakes.is_empty():
		_finish()
		return
	var fake: FishController = fakes[0]
	fake.dodged.connect(func(_d: Vector3) -> void: flips[0] += 1)
	check(fake.character == fish.character and fake.species == fish.species, "a copy of the thrower (class %d, species %d)" % [fake.character, fake.species])
	check(game.decoy_owner(fake) == fish, "the thrower owns it")
	check(game.noise(fish) <= noise_before + 0.001, "throwing it is silent (noise %.2f -> %.2f)" % [noise_before, game.noise(fish)])
	var start := fake.global_position
	await _seconds(1.2)
	var gone := fake.global_position - start
	check(gone.dot(Vector3.RIGHT) > 4.0, "it swims off along the thrower's facing (%.1f m in 1.2 s)" % gone.dot(Vector3.RIGHT))
	var top_speed := 0.0
	var top_exposure := 0.0
	for i in TICKS:
		top_speed = maxf(top_speed, Vector2(fake.linear_velocity.x, fake.linear_velocity.z).length())
		top_exposure = maxf(top_exposure, game.exposure(seeker, fake))
		await get_tree().physics_frame
	check(top_speed > mp.fake_speed * 0.6 and top_speed < mp.fake_speed * 1.8, "at about fake_speed (top %.1f m/s, fake_speed %.1f)" % [top_speed, mp.fake_speed])
	check(game.recent_pings(seeker).size() > pings_before, "loud: pings on the seeker's scope (%d -> %d)" % [pings_before, game.recent_pings(seeker).size()])
	check(top_exposure >= mp.layer_skeleton, "it builds up in the seeker's view (exposure %.2f)" % top_exposure)
	sounds.clear()
	await _until(func() -> bool: return game.decoys().is_empty(), mp.fake_life + 1.0)
	check(game.decoys().is_empty(), "after fake_life it's gone")
	check(sounds.has("mp/fake_pop"), "with a pop (mp/fake_pop)")
	check(flips[0] >= 1, "it flipped on the way (%d)" % flips[0])

	print(" fooled:")
	game.start_round(2)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	seeker = game.seekers()[0]
	check(game.is_live_hider(fish) and game.fake_charges(fish) == mp.fake_charges, "a new round, a new charge")
	_park(fish, open, Vector3.RIGHT)
	_park(seeker, open + Vector3(0.0, 0.0, 30.0))
	var fooled: Array = []
	game.fooled.connect(func(s: FishController, f: FishController) -> void: fooled.append([s, f]), CONNECT_ONE_SHOT)
	game.throw_fake(fish)
	await _ticks(1)
	fake = game.decoys()[0]
	# The seeker comes straight at it.
	seeker.freeze = false
	var ahead := fake.global_position + Vector3.RIGHT * 6.0
	seeker.global_transform = Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), ahead)
	sounds.clear()
	for i in TICKS:
		if not fooled.is_empty():
			break
		seeker.linear_velocity = (fake.global_position - seeker.global_position).normalized() * 14.0
		await get_tree().physics_frame
	check(not fooled.is_empty() and fooled[0][0] == seeker, "the seeker's tag is FOOLED (signal)")
	check(sounds.has("mp/fooled"), "mp/fooled")
	check(game.is_live_hider(fish), "the thrower is fine")
	await _ticks(2)
	check(game.decoys().is_empty(), "it pops when tagged")
	_finish()


## A point in open water: the middle of the arena, half way up, else the Ocean's centre.
func _open_water(game: MarcoPoloMatch) -> Vector3:
	if game.arena is MarcoArena:
		var arena := game.arena as MarcoArena
		var space := arena.get_world_3d().direct_space_state
		for n in 40:
			var at := arena.global_position + Vector3(randf_range(-0.3, 0.3) * arena.size.x, arena.size.y * 0.45, randf_range(-0.3, 0.3) * arena.size.z)
			var clear := true
			for dir: Vector3 in [Vector3.RIGHT, Vector3(0.6, 0.0, 0.8), Vector3(0.0, 0.0, 1.0)]:
				var ray := PhysicsRayQueryParameters3D.create(at, at + dir * 24.0, arena.sight_blockers_mask())
				if not space.intersect_ray(ray).is_empty():
					clear = false
			if clear:
				return at
		return arena.global_position + Vector3(0.0, arena.size.y * 0.6, 0.0)
	return game.center + Vector3(0.0, 4.0, 0.0)


func _finish() -> void:
	print("fake_fish_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _still_bots(game: MarcoPoloMatch) -> void:
	for bot: Node in game.bots.values():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		var input: Variant = bot.get("input")
		if input is FishInput:
			(input as FishInput).clear()


func _park(who: FishController, at: Vector3, facing := Vector3.FORWARD) -> void:
	who.freeze = true
	who.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), at)
	who.linear_velocity = Vector3.ZERO
	who.angular_velocity = Vector3.ZERO


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _ticks(roundi(s * TICKS))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
