extends Node
## Marco Polo (planning_marco_polo.md), phases 0 and 1: its card (variant and
## arena pickers, no split-screen: extra local players dropped, joining off);
## Play starts a match of the player and bots in the Ocean; rounds with the
## seeker held through the countdown, seeker rotation, the clock and "all
## caught" ends; apply_role (seeker boost and big bow, hiders sinking at
## hider_buoyancy); tags with no speed rule; Last Fish Swimming (eliminated,
## belly-up float, spectating a live hider (the bumpers cycle everyone in the
## round) and moving on when that one's out)
## and Join the Seekers (converts, seekers can't tag seekers, convert_hold);
## line-of-sight scoring (invisible still counts; walls, the cone and range
## stop it; los_cone_angle; once per seeker); hidden tallies; bumping; then
## noise and exposure (still and sinking silent, a flip reaches the aura, a
## good cruise stays low, a bad stride beats a good one, the fade times,
## bubble masking, points per layer).
##   Godot_console.exe --headless --path . res://tests/marco_polo_probe.tscn

const TICKS := 120  # physics ticks per second

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var mp: MarcoPoloSettings


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	mp = MarcoPoloSettings.shared()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	mp.whale_seeker = false  # this probe is the fish seeker's rules; whale_spike_probe and whale_sight_probe have the whale's
	mp.arena = "Ocean"
	mp.hide_time = 0.5
	mp.round_time = 60.0
	mp.round_over_time = 0.5
	mp.min_players = 4
	mp.rounds = 0
	mp.bot_seeker_rounds = 0
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER

	print("card and no split-screen:")
	main.set_mode(main.NATURE)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(3)
	var extra: PlayerSlot = main._local.join(7)
	await _ticks(3)
	check(extra != null and main._local.count() == 2, "a split-screen player joined Nature")
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	check(main.MARCO_POLO in main.MODES and main.MARCO_POLO in main.MATCH_MODES and main.MARCO_POLO in main.NATURE_MODES, "Marco Polo is a match mode on Nature's tuning")
	check(main.current_environment == "Ocean", "plays in the arena picked (the Ocean)")
	check(main._match_card != null and main.marco_polo == null and not fish.visible, "waits on its card, fish sitting out")
	check(main._match_card != null and main._match_card.pickers.size() == 3, "the card has the variant, Start as and arena pickers")
	var arena_picks: Array = []
	var start_picks: Array = []
	if main._match_card:
		for choice: Dictionary in main._match_card.choices:
			if choice.title == "Arena":
				arena_picks = choice.options
			elif choice.title == "Start as":
				start_picks = choice.options
	check(start_picks == ["Seeker", "Hider"], "Start as: Seeker or Hider (%s)" % [start_picks])
	check(arena_picks == ["Sunken Temple", "Aquarium"], "the arena picker offers the Sunken Temple and the Aquarium, not the Ocean (%s)" % [arena_picks])
	check(main._local.count() == 1, "extra local players dropped")
	check(main._match_card != null and main._match_card.note.contains("split-screen"), "with a note on the card")
	check(not main._local.can_join() and main._local.no_split_screen, "split-screen joining is off")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null and fish.visible, "Play starts the match")
	if game == null:
		_finish()
		return
	check(game.players.size() == 4 and game.bots.size() == 3, "bots fill it to min_players (%d fish)" % game.players.size())
	check(game.seekers().size() == 1 and game.live_hiders().size() == 3, "one seeker, three hiders")
	check(not main._local.can_join(), "joining stays off in the match")
	check(Console.has_command("mp_role") and Console.has_command("mp_cone") and Console.has_command("mp_expose"), "the mp_* console commands are on")
	check(game.rounds_in_match() == 1, "one round per human by default")
	var pose: Callable = main._camera.get("pose_override")
	check(pose.is_valid() and pose.call(fish) == null, "the camera asks the match for a porthole view (none while out)")
	var ucam := UnnaturalSettings.shared()
	check(bool(main._camera.get("steady_heading")) == ucam.steady_camera and not bool(main._camera.get("hold_opens_wheel")),
			"Unnatural's survivor cam is on (follow or free, Y swaps them)")
	var was_free: bool = main._camera.get("free_cam")
	main._camera.set("free_cam", not was_free)  # what Y does
	await _ticks(2)
	check(bool(main._camera.get("free_cam")) != was_free, "a swapped view sticks while the match keeps the survivor cam on")
	main._camera.set("free_cam", was_free)
	var marco_pad := InputMap.has_action(&"marco") and InputMap.action_get_events(&"marco").any(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK)
	var marco_key := InputMap.action_get_events(&"marco").any(func(e: InputEvent) -> bool:
			return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_M) if InputMap.has_action(&"marco") else false
	check(marco_pad and marco_key, "Marco! is on the left stick click and M")
	for id: String in ["count", "seen", "ping", "aura", "heartbeat"]:
		check(SoundCatalog.has(MarcoPoloMatch.SOUNDS[id]), "cue %s is %s" % [id, MarcoPoloMatch.SOUNDS[id]])
	await _plate_checks(game)
	await _start_as_checks(game)

	print("roles:")
	mp.rounds = 3
	mp.bot_seeker_rounds = 1
	game.start_round(1)  # a bot seeks: the player hides
	await _ticks(2)
	_still_bots(game)
	var seeker: FishController = game.seekers()[0]
	check(game.bots.has(seeker) and game.role_of(fish) == MarcoPoloMatch.Role.HIDER, "round 2: a bot seeks, the player hides")
	check(game.phase == MarcoPoloMatch.Phase.COUNTDOWN and seeker.controls_locked and not fish.controls_locked, "countdown: the seeker's held, hiders scatter")
	check(seeker.boost_enabled and is_equal_approx(seeker.bow_scale, mp.seeker_bow_scale) and is_equal_approx(seeker.buoyancy, mp.seeker_buoyancy),
			"seeker: boost, the big bow (x%.1f), neutral buoyancy" % seeker.bow_scale)
	check(not fish.boost_enabled and is_equal_approx(fish.bow_scale, 1.0) and is_equal_approx(fish.buoyancy, mp.hider_buoyancy), "hider: no boost, normal bow, sinks")
	check(game.local_view_role() == MarcoPoloMatch.Role.HIDER, "local view role: hider")
	await _go_live(game)
	check(game.phase == MarcoPoloMatch.Phase.LIVE and not seeker.controls_locked, "LIVE: the seeker's free")

	print("buoyancy:")
	var hider: FishController = _bot_hiders(game)[0]
	var start_y := hider.global_position.y
	# The seeker well clear of the others: a sinking hider landing on it isn't buoyancy.
	seeker.global_position = game.center + Vector3(0.0, 10.0, -90.0)
	seeker.linear_velocity = Vector3.ZERO
	seeker.angular_velocity = Vector3.ZERO
	var seeker_y := seeker.global_position.y
	await _ticks(TICKS * 2)
	var sank := start_y - hider.global_position.y
	check(sank > 0.5 and hider.linear_velocity.y < -0.1, "a hider sinks (%.2f m in 2 s, %.2f m/s)" % [sank, hider.linear_velocity.y])
	check(absf(seeker.global_position.y - seeker_y) < 0.3, "the seeker holds its depth (%.2f m, buoyancy %.2f, vy %.2f, freeze %s, locked %s, %s)" % [seeker.global_position.y - seeker_y, seeker.buoyancy, seeker.linear_velocity.y, seeker.freeze, seeker.controls_locked, FishCharacter.CLASSES.get(seeker.character, {}).get("name", seeker.character)])

	print("line of sight:")
	var far := game.center + Vector3(0.0, 0.0, 200.0)
	for f: FishController in game.players:
		_park(f, far + Vector3(randf_range(-30, 30), 0.0, randf_range(-30, 30)))
	var eye := game.center + Vector3(0.0, 5.0, 0.0)
	_park(seeker, eye, Vector3.FORWARD)
	_park(hider, eye + Vector3.FORWARD * 10.0)
	await _ticks(3)
	var before := float(game._tally[hider])
	await _ticks(TICKS)
	var gained := float(game._tally[hider]) - before
	check(game.exposure(seeker, hider) < 0.01 and absf(gained - mp.seen_points_none) < 0.15,
			"invisible but in sight: the base rate (+%.2f in 1 s, exposure %.2f)" % [gained, game.exposure(seeker, hider)])
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10.0, 10.0, 0.5)
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = eye + Vector3.FORWARD * 5.0
	await _ticks(3)
	before = float(game._tally[hider])
	await _ticks(TICKS / 2)
	check(float(game._tally[hider]) - before < 0.01 and not game.in_sight(seeker, hider), "a wall in between stops it")
	wall.queue_free()
	await _ticks(2)
	_park(hider, eye + Vector3.RIGHT * 10.0)
	await _ticks(2)
	check(not game.in_sight(seeker, hider), "beside the seeker (outside the cone): no")
	_park(hider, eye + Vector3.FORWARD * (game.sight_range() + 10.0))
	await _ticks(2)
	check(not game.in_sight(seeker, hider), "past the sight range (%.0f m): no" % game.sight_range())
	var off := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(50.0)) * 10.0
	_park(hider, eye + off)
	await _ticks(2)
	mp.los_cone_angle = 70.0
	var narrow := game.in_sight(seeker, hider)
	mp.los_cone_angle = 120.0
	var wide := game.in_sight(seeker, hider)
	mp.los_cone_angle = 70.0
	check(not narrow and wide, "50 degrees off: out at los_cone_angle 70, in at 120")
	mp.debug_show_los_cone = true
	_park(hider, eye + Vector3.FORWARD * 10.0)
	await _ticks(3)
	var labels := game._sight._labels.filter(func(l: Label3D) -> bool: return l.visible)
	check(game._sight._mesh.get_surface_count() > 0 and labels.size() == 1, "the debug cone draws, with one +n/s (%d surfaces, %d labels)" % [game._sight._mesh.get_surface_count(), labels.size()])
	mp.debug_show_los_cone = false
	await _ticks(2)
	check(game._sight._mesh.get_surface_count() == 0, "and clears when off")

	print("hidden tallies:")
	check(game.own_round_tally(hider) == 0.0 and float(game._tally[hider]) > 0.5, "another fish's tally isn't given out during the round")
	fish.freeze = true
	_park(fish, eye + Vector3.FORWARD * 8.0 + Vector3.RIGHT * 1.5)
	await _ticks(TICKS / 2)
	check(game.own_round_tally(fish) > 0.0 and game.is_seen_now(fish), "the local hider's own tally and eye pip (%.2f)" % game.own_round_tally(fish))
	check(not game.is_seen_now(hider), "nobody else's eye pip")
	check(not _hud_shows_number(game, float(game._tally[hider])), "no HUD label shows a hider's round points")
	fish.freeze = false

	print("several seekers:")
	mp.variant = MarcoPoloSettings.Variant.CONVERSION
	var second: FishController = _bot_hiders(game)[1]
	game._on_caught(second, "tag", seeker)
	await _ticks(TICKS * 2)  # past convert_hold
	_park(second, eye + Vector3.RIGHT * 2.0, Vector3.FORWARD)
	_park(hider, eye + Vector3.FORWARD * 10.0 + Vector3.RIGHT * 1.0)
	_park(fish, far)
	await _ticks(3)
	before = float(game._tally[hider])
	await _ticks(TICKS)
	gained = float(game._tally[hider]) - before
	check(game.seekers().size() == 2 and absf(gained - 2.0 * mp.seen_points_none) < 0.25, "two seekers in sight pay twice (+%.2f in 1 s)" % gained)

	print("Join the Seekers:")
	check(game.role_of(second) == MarcoPoloMatch.Role.SEEKER and second.boost_enabled and is_equal_approx(second.bow_scale, mp.seeker_bow_scale),
			"a tag converted the hider (boost, big bow)")
	_park(second, eye + Vector3.UP * 20.0)
	await _ticks(2)
	seeker.freeze = false
	_ram(seeker, second)
	await _ticks(20)
	check(game.role_of(second) == MarcoPoloMatch.Role.SEEKER and game.seekers().size() == 2, "seekers can't tag seekers")
	_still_bots(game)
	var third: FishController = hider
	game._on_caught(third, "tag", seeker)
	check(not game.is_seeking(third) and third.controls_locked, "a new seeker is held for convert_hold")
	_park(fish, third.global_position + Vector3.FORWARD * 1.6)
	fish.freeze = false
	await _ticks(10)
	check(game.is_live_hider(fish), "and can't tag during it")
	await _ticks(roundi(mp.convert_hold * TICKS) + 5)
	check(game.is_seeking(third), "once convert_hold ends, it seeks")
	_ram(third, fish)
	await _ticks(30)
	check(game.role_of(fish) == MarcoPoloMatch.Role.SEEKER, "and its tag converts (the player now seeks)")
	check(game.phase == MarcoPoloMatch.Phase.ROUND_OVER, "the last hider caught: the round's over")
	check(game.local_view_role() == MarcoPoloMatch.Role.SEEKER, "local view role: seeker")

	print("rounds:")
	var first_seeker: FishController = game.starting_seekers[0]
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.COUNTDOWN, 3.0)
	check(game.round_index == 2 and game.starting_seekers[0] != first_seeker, "the next round, a new seeker (round %d)" % (game.round_index + 1))
	check(game.totals().get(fish, 0.0) > 0.0, "the totals carry on between rounds")
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.round_time = 1.0
	await _go_live(game)
	_still_bots(game)
	for f: FishController in game.players:
		_park(f, game.center + Vector3(randf_range(-40, 40), 30.0, randf_range(-40, 40)))
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.OVER, 4.0)
	check(game.phase == MarcoPoloMatch.Phase.OVER, "the clock runs out on the last round: the match is over")
	check(game.winner != null, "with a winner")
	mp.round_time = 60.0

	print("Last Fish Swimming:")
	mp.rounds = 3
	game.start_match()
	game.start_round(1)
	await _go_live(game)
	_still_bots(game)
	seeker = game.seekers()[0]
	check(game.role_of(fish) == MarcoPoloMatch.Role.HIDER, "the player hides")
	_park(fish, game.center + Vector3(0.0, 5.0, 0.0))
	fish.freeze = false
	_ram(seeker, fish)
	await _ticks(30)
	check(game.eliminated.has(fish) and game.role_of(fish) == MarcoPoloMatch.Role.HIDER, "a tag with no speed rule eliminates")
	check(fish.global_basis.y.y < -0.5, "belly-up")
	var y0 := fish.global_position.y
	await _ticks(TICKS / 2)
	check(fish.global_position.y > y0 + 0.3, "floating up")
	var watched := game.spectate_target()
	check(watched != null and game.is_live_hider(watched) and camera.target == watched, "spectating a live hider")
	check(bool(camera.get("steady_heading")) == UnnaturalSettings.shared().steady_camera, "...on the survivor cam")
	var others := game.live_hiders()
	others.erase(watched)
	game.cycle_spectate(1)
	check(game.spectate_target() != watched and camera.target == game.spectate_target(), "the bumpers cycle the fish in the round")
	for i in game.players.size():
		if game.is_live_hider(game.spectate_target()):
			break
		game.cycle_spectate(1)
	watched = game.spectate_target()
	game._on_caught(watched, "tag", seeker)
	await _ticks(roundi((mp.spectate_switch_delay + 0.2) * TICKS))
	check(game.spectate_target() != watched and game.is_live_hider(game.spectate_target()), "the watched hider out: the view moves on")
	await _ticks(roundi(mp.eliminated_float * TICKS))
	check(not fish.visible, "the eliminated fish fades out")
	game._on_caught(game.live_hiders()[0], "tag", seeker)
	check(game.phase == MarcoPoloMatch.Phase.ROUND_OVER, "everyone caught: ROUND_OVER straight away")
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.COUNTDOWN, 3.0)
	check(fish.visible and not game.eliminated.has(fish) and camera.target == null, "the next round brings everyone back")

	print("bumping:")
	await _go_live(game)
	_still_bots(game)
	var hiders := game.live_hiders()
	if hiders.size() >= 2:
		var a: FishController = hiders[0]
		var b: FishController = hiders[1]
		var bumps := []
		game.bumped.connect(func(x: FishController, y: FishController, speed: float) -> void: bumps.append(speed))
		_park(a, game.center + Vector3(0.0, 10.0, 60.0), Vector3.FORWARD)
		_park(b, game.center + Vector3(0.0, 10.0, 57.0), Vector3.BACK)
		await _ticks(2)
		var na := game.noise(a)
		a.freeze = false
		b.freeze = false
		a.linear_velocity = Vector3.FORWARD * 5.0
		b.linear_velocity = Vector3.BACK * 5.0
		await _ticks(40)
		check(not bumps.is_empty() and game.noise(a) > na + 0.3, "a bump: noise (%.2f) and mp_bump (%s)" % [game.noise(a), MarcoPoloMatch.SOUNDS.bump])
	else:
		check(false, "two hiders to bump")

	await _noise_checks(game)
	_finish()


## Name plates (Hud.plate_filter): to the seeker a hider's shows only from
## the skin layer up; to a hider every plate shows.
func _plate_checks(game: MarcoPoloMatch) -> void:
	print("name plates:")
	check(main._hud.plate_filter.is_valid(), "the HUD asks the match about name plates")
	check(game.role_of(fish) == MarcoPoloMatch.Role.SEEKER, "(the player seeks)")
	var hider: FishController = game.live_hiders()[0]
	game.set_exposure(hider, mp.layer_cardio + 0.01)
	check(not game.shows_plate(hider), "a hider at the cardiovascular layer: no plate for the seeker")
	game.set_exposure(hider, mp.layer_skin + 0.01)
	check(game.shows_plate(hider), "at skin: its plate shows")
	game.set_exposure(hider, 0.0)
	check(game.shows_plate(fish) and game.shows_plate(game.seekers()[0]), "seekers' plates always show")
	game.apply_role(fish, MarcoPoloMatch.Role.HIDER)
	game.role[fish] = MarcoPoloMatch.Role.HIDER
	check(game.shows_plate(hider), "to a hider every plate shows, unseen or not")
	game.role[fish] = MarcoPoloMatch.Role.SEEKER
	game.apply_role(fish, MarcoPoloMatch.Role.SEEKER)
	await _ticks(1)


## Start as (MarcoPoloSettings.start_as): solo, you seek once and a bot seeks
## bot_seeker_rounds while you hide, in the order picked.
func _start_as_checks(game: MarcoPoloMatch) -> void:
	print("Start as:")
	mp.bot_seeker_rounds = 1
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	var order := game.seeker_order()
	check(game.rounds_in_match() == 2 and order[0] == fish and game.bots.has(order[1]), "Seeker: you seek round 1, a bot round 2 (2 rounds)")
	mp.start_as = MarcoPoloSettings.StartAs.HIDER
	game.start_match()
	await _ticks(2)
	check(game.round_index == 0 and game.bots.has(game.seekers()[0]) and game.role_of(fish) == MarcoPoloMatch.Role.HIDER,
			"Hider: round 1 a bot seeks, the player hides")
	check(game.seeker_order()[1] == fish, "...and the player seeks round 2")
	mp.bot_seeker_rounds = 3
	check(game.rounds_in_match() == 4, "bot_seeker_rounds 3: four rounds (%d)" % game.rounds_in_match())
	mp.bot_seeker_rounds = 0
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	game.start_match()
	await _ticks(2)


func _noise_checks(game: MarcoPoloMatch) -> void:
	print("noise:")
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	game.start_round(1)
	await _go_live(game)
	_still_bots(game)
	var seeker: FishController = game.seekers()[0]
	var hider: FishController = _bot_hiders(game)[0]
	var meter := game.noise_meter(hider)
	check(meter != null, "every hider has a NoiseMeter")
	var eye := game.center + Vector3(0.0, 5.0, 0.0)
	_park(seeker, eye, Vector3.FORWARD)
	_park(hider, eye + Vector3.FORWARD * 6.0)
	hider.freeze = false
	await _ticks(TICKS * 2)
	check(meter.noise < 0.01 and game.exposure(seeker, hider) < 0.01, "still: no noise, nothing seen")
	check(meter.steady_at(Vector3(0.0, -6.0, 0.0)) == 0.0, "sinking is silent")
	check(meter.steady_at(Vector3(0.0, 0.0, -mp.loud_speed)) > 0.5 and meter.steady_at(Vector3(0.0, 6.0, 0.0)) > 0.0, "fast or upward swimming is steady noise")
	check(meter.stride_noise(0.2) > meter.stride_noise(0.9) * 3.0, "a bad stride is louder than a good one (%.2f vs %.2f)" % [meter.stride_noise(0.2), meter.stride_noise(0.9)])
	# A good cruise: average speed and well-timed strides, near.
	var cruise := (mp.quiet_speed + mp.loud_speed) * 0.35
	await _swim(hider, cruise, 1.0, func() -> void: hider.strode.emit(0.9, 0.5), 0.5)
	var e := game.exposure(seeker, hider)
	check(mp.layer_for(e) <= MarcoPoloSettings.Layer.CARDIO and mp.layer_for(e) >= MarcoPoloSettings.Layer.SKELETON,
			"a good cruise stays low (exposure %.2f, %s)" % [e, MarcoPoloSettings.LAYER_NAMES[mp.layer_for(e)]])
	_park(hider, eye + Vector3.FORWARD * 6.0)
	hider.freeze = false
	hider.dodged.emit(Vector3.FORWARD)
	await _swim(hider, cruise, 0.05, Callable(), 1.0)
	e = game.exposure(seeker, hider)
	check(mp.layer_for(e) == MarcoPoloSettings.Layer.AURA, "a flip reaches the aura (%.2f)" % e)
	# The fade: from the aura, held still (target 0), at exposure_fade per second.
	game.set_exposure(hider, 0.92)
	_park(hider, hider.global_position)
	var times := {}
	var scale := 0.2 / mp.exposure_fade  # the times below are at a fade of 0.2 a second
	for i in roundi(6.0 * scale * TICKS):
		await get_tree().physics_frame
		var layer := mp.layer_for(game.exposure(seeker, hider))
		if not times.has(layer):
			times[layer] = float(i) / TICKS
	var expect := {MarcoPoloSettings.Layer.SKIN: 0.35, MarcoPoloSettings.Layer.MUSCLE: 1.35, MarcoPoloSettings.Layer.SKELETON: 3.4, MarcoPoloSettings.Layer.NONE: 4.2}
	var fade_ok := true
	var line := PackedStringArray()
	for layer: int in expect:
		var at: float = times.get(layer, -1.0)
		line.append("%s %.2f s" % [MarcoPoloSettings.LAYER_NAMES[layer], at])
		fade_ok = fade_ok and absf(at - float(expect[layer]) * scale) < 0.15 * scale
	check(fade_ok, "fade times from the aura (%s)" % ", ".join(line))
	# Distance falloff.
	check(is_equal_approx(game.distance_falloff(5.0), 1.0) and absf(game.distance_falloff(mp.half_sight) - 0.5) < 0.01 \
			and game.distance_falloff(game.sight_range()) == 0.0, "distance falloff: 1 near, 0.5 at %.0f m, 0 at the murk" % mp.half_sight)
	# Bubble masking, with a test curtain.
	meter.reset()
	meter.mask_at = func(at: Vector3) -> float: return mp.bubble_mask if at.distance_to(hider.global_position) < 3.0 else 1.0
	meter.add(0.5)
	check(absf(meter.noise - 0.5 * mp.bubble_mask) < 0.01, "inside a bubble curtain noise is masked (%.2f)" % meter.noise)
	meter.mask_at = Callable()
	# Points per layer.
	_park(hider, eye + Vector3.FORWARD * 6.0)
	var rates := PackedStringArray()
	var rates_ok := true
	for layer in 6:
		var mid: float = [0.04, 0.16, 0.35, 0.55, 0.75, 0.92][layer]
		var before := float(game._tally[hider])
		for i in TICKS / 2:
			game.set_exposure(hider, mid)
			await get_tree().physics_frame
		var rate := (float(game._tally[hider]) - before) * 2.0
		rates.append("%.1f" % rate)
		rates_ok = rates_ok and absf(rate - mp.seen_points(layer)) < 0.4
	check(rates_ok, "points per layer per second (%s)" % ", ".join(rates))
	# Marco!
	var pings := []
	game.pinged.connect(func(s: FishController, at: Vector3, loud: float, polo: bool) -> void: pings.append(polo))
	check(game.marco(seeker) and game.marco_ready(seeker) < 0.01, "Marco! goes on cooldown")
	check(pings.has(true) and game.recent_pings(seeker).size() > 0, "and the hiders answer Polo! on the scope")
	check(not game.marco(seeker), "not again until it's ready")


func _finish() -> void:
	print("marco_polo_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


## Swims `who` forward at `speed` for `seconds`, calling `each` every `every` s.
func _swim(who: FishController, speed: float, seconds: float, each: Callable, every: float) -> void:
	var left := 0.0
	for i in roundi(seconds * TICKS):
		who.linear_velocity = -who.global_basis.z * speed
		left -= 1.0 / TICKS
		if left <= 0.0 and each.is_valid():
			left = every
			each.call()
		await get_tree().physics_frame


## Bots stop driving (the probe moves the fish).
func _still_bots(game: MarcoPoloMatch) -> void:
	for bot: Node in game.bots.values():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		var input: Variant = bot.get("input")
		if input is FishInput:
			(input as FishInput).clear()


func _bot_hiders(game: MarcoPoloMatch) -> Array[FishController]:
	var out: Array[FishController] = []
	for f in game.live_hiders():
		if game.bots.has(f):
			out.append(f)
	return out


## Holds `who` still at `at` facing `facing`.
func _park(who: FishController, at: Vector3, facing := Vector3.FORWARD) -> void:
	who.freeze = true
	who.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), at)
	who.linear_velocity = Vector3.ZERO
	who.angular_velocity = Vector3.ZERO


## `attacker` 1.8 m behind `victim`, nose on, closing slowly.
func _ram(attacker: FishController, victim: FishController) -> void:
	var heading := -victim.global_basis.z
	attacker.freeze = false
	victim.freeze = false
	attacker.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), victim.global_position - heading * 1.8)
	attacker.linear_velocity = heading * 3.0
	victim.linear_velocity = Vector3.ZERO


func _hud_shows_number(game: MarcoPoloMatch, points: float) -> bool:
	var wanted := ["%d" % roundi(points), "%.1f" % points]
	var nodes: Array[Node] = []
	if game._hud:
		nodes.append(game._hud)
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is Label and (node as Label).visible and (node as Label).text.strip_edges() in wanted and roundi(points) > 0:
			return true
		nodes.append_array(node.get_children())
	return false


func _go_live(game: MarcoPoloMatch) -> void:
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 5.0)


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
