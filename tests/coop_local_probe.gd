extends Node
## Nature's split-screen co-op (LocalCoop): a controller's Back/View joins a
## run, up to four players, each with their own fish, camera, HUD and school
## wheel in their own view; each controller drives only its own fish; any
## player can batter the lone fish or school fish, and the team's count and
## each player's share (CoopRules) add up, with two players on one fish at
## once sharing it; pearls count for whoever collects them; the first
## player's tuning reaches every fish; holding Back/View leaves, and with one
## player left (or out of Nature) the first player has the whole window back.
##   Godot_console.exe --headless --path . res://tests/coop_local_probe.tscn

## Made-up controller ids for the joining players (nothing real is plugged in).
const PADS := [11, 12, 13]

var main: Node
var fish: FishController
var camera: Camera3D
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	var local: LocalCoop = main._local
	print("joining:")
	main.set_mode(main.NATURE)
	await _ticks(3)
	_press(PADS[0], LocalCoop.JOIN_BUTTON)
	await _ticks(3)
	check(local.count() == 1, "no joining on the card")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: NatureRun = main.nature_run
	_press(PADS[0], LocalCoop.JOIN_BUTTON)
	await _ticks(5)
	check(local.count() == 2 and run.players.size() == 2, "Back/View on another controller joins the run")
	var split: SplitScreen = main.get_node_or_null("SplitScreen")
	check(split != null and split.count() == 2, "the window splits in two")
	check(camera.get_viewport() == split.view(0) and camera.current, "the first player's camera moved into the first view")
	check(main._hud.get_viewport() == split.view(0), "...and their HUD")
	_press(PADS[0], LocalCoop.JOIN_BUTTON)
	await _ticks(3)
	check(local.count() == 2, "pressing it again doesn't join twice")
	for pad in PADS.slice(1):
		_press(pad, LocalCoop.JOIN_BUTTON)
		await _ticks(3)
	await _ticks(5)
	check(local.count() == 4 and run.players.size() == 4 and split.count() == 4, "four players, four views")
	_press(99, LocalCoop.JOIN_BUTTON)
	await _ticks(3)
	check(local.count() == 4, "no fifth player")
	var characters := {}
	var spots: Array[Vector3] = []
	for slot in local.slots:
		characters[slot.fish.character] = true
		spots.append(slot.fish.global_position)
		check(slot.camera.current and slot.camera.get_viewport() == split.view(slot.index) and slot.camera.fish == slot.fish,
				"player %d: own camera, current in view %d" % [slot.index + 1, slot.index])
		check(slot.hud.fish == slot.fish and slot.hud.nature_run == run and is_instance_valid(slot.wheel) and slot.wheel.fish == slot.fish,
				"player %d: own HUD and school wheel" % [slot.index + 1])
	check(characters.size() == 4, "everyone's a different fish")
	var apart := INF
	for a in spots.size():
		for b in range(a + 1, spots.size()):
			apart = minf(apart, spots[a].distance_to(spots[b]))
	check(apart >= NatureRun.SPAWN_SPACING - 0.5, "side by side, not on top of each other (%.1f m apart)" % apart)
	check(School.view_cameras.size() == 4, "school detail follows all four cameras")
	var second: PlayerSlot = local.slots[1]
	check(second.fish.get_collision_exceptions().has(fish), "co-op fish pass through each other")
	var was: FishCharacter.Family = second.fish.character
	_press(PADS[0], JOY_BUTTON_DPAD_RIGHT)
	await _ticks(2)
	check(second.fish.character != was, "D-pad changes a joined player's fish")

	print("controllers:")
	Input.parse_input_event(_axis(PADS[0], JOY_AXIS_TRIGGER_RIGHT, 1.0))
	await _ticks(3)
	check(second.input.strength("thrust_forward") > 0.9, "a joined player's trigger reads on their input (%.2f)" % second.input.strength("thrust_forward"))
	check(second.fish.input_forward > 0.9, "...and swims their fish")
	check(fish.input_forward < 0.01 and local.slots[2].fish.input_forward < 0.01, "...and nobody else's")
	Input.parse_input_event(_axis(PADS[0], JOY_AXIS_TRIGGER_RIGHT, 0.0))
	await _ticks(3)

	print("batteries:")
	var third: PlayerSlot = local.slots[2]
	await _ram_target(run, third.fish)
	check(run.rules.battered_by(third.fish) == 1 and run.battered_fish == 1, "player 3 batters the lone fish: theirs and the team's")
	check(run.score_of(third.fish).points > 0 and run.score_of(fish).points == 0, "their points, not player 1's")
	await _ticks(roundi((NatureRun.RESPAWN_TIME + 0.3) * 120.0))
	check(not run.target.battered, "the lone fish comes back")
	# Two at once on one school fish.
	var school: School = run.schools[0]
	var index := _alive_index(school)
	var before := run.battered_fish
	await _ram_school_fish_together(run, school, index, [fish, second.fish])
	check(not school.is_alive(index), "two players ram one school fish at once: it's battered")
	check(run.battered_fish == before + 1, "one fish for the team (%d -> %d)" % [before, run.battered_fish])
	check(run.rules.battered_by(fish) >= 1 and run.rules.battered_by(second.fish) >= 1 and run.rules.shared_batteries >= 1,
			"...credited to both (shared %d)" % run.rules.shared_batteries)

	print("pearls:")
	# Clear any pearls from before, then one sure drop, the others well away.
	for old in run.pearls_out.duplicate():
		old.queue_free()
	await _ticks(2)
	var collector := local.slots[3].fish
	for slot in local.slots:
		if slot.fish != collector:
			slot.fish.global_position = collector.global_position + Vector3(0, 60 + 10 * slot.index, 0)
			slot.fish.linear_velocity = Vector3.ZERO
	var pearl_before := run.pearls
	var mine_before := run.rules.pearls_of(collector)
	run.settings.pearl_chance = 1.0
	school = run.schools[0]
	index = _alive_index(school)
	await _ram_school_fish_together(run, school, index, [collector])
	run.settings.pearl_chance = NatureSettings.new().pearl_chance
	check(not run.pearls_out.is_empty() or run.pearls > pearl_before, "a pearl drops")
	collector.linear_velocity = Vector3.ZERO
	if not run.pearls_out.is_empty():
		collector.global_position = run.pearls_out[0].global_position + Vector3(0.3, 0, 0)
	await _ticks(90)
	check(run.pearls > pearl_before and run.pearls - pearl_before == run.rules.pearls_of(collector) - mine_before,
			"the player who swims over them has them (team %d -> %d, theirs %d -> %d)" % [pearl_before, run.pearls, mine_before, run.rules.pearls_of(collector)])

	print("tuning:")
	var tuning_before := fish.max_speed
	fish.max_speed = 31.5
	main._panel.tuning_changed.emit()
	await _ticks(3)
	check(local.slots.all(func(slot: PlayerSlot) -> bool: return is_equal_approx(slot.fish.max_speed, 31.5)), "the first player's tuning reaches every fish")
	fish.max_speed = tuning_before
	main._panel.tuning_changed.emit()

	print("leaving:")
	var leaving: PlayerSlot = local.slots[1]
	var leaving_fish := leaving.fish
	Input.parse_input_event(_button(PADS[0], LocalCoop.JOIN_BUTTON, true))
	await _ticks(roundi((LocalCoop.LEAVE_HOLD + 0.2) * 120.0))
	Input.parse_input_event(_button(PADS[0], LocalCoop.JOIN_BUTTON, false))
	await _ticks(3)
	check(local.count() == 3 and split.count() == 3 and run.players.size() == 3, "holding Back/View leaves (three left)")
	check(not is_instance_valid(leaving_fish), "their fish goes")
	for slot in local.slots:
		check(slot.camera.get_viewport() == split.view(slot.index), "player %d now in view %d" % [slot.index + 1, slot.index])
	check(run.battered_fish >= 2, "the team keeps what they battered")
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	check(local.count() == 1 and main.get_node_or_null("SplitScreen") == null, "out of Nature: just the first player")
	check(camera.get_viewport() == main.get_viewport() and camera.current and main._hud.get_viewport() == main.get_viewport(),
			"their camera and HUD have the whole window back")
	check(fish.input_source == null, "every controller drives them again")
	check(School.view_cameras.is_empty(), "school detail back on the one camera")

	print("coop_local_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _press(pad: int, button: JoyButton) -> void:
	Input.parse_input_event(_button(pad, button, true))
	Input.parse_input_event(_button(pad, button, false))


func _button(pad: int, button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = pad
	event.button_index = button
	event.pressed = pressed
	return event


func _axis(pad: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = pad
	event.axis = axis
	event.axis_value = value
	return event


func _alive_index(school: School) -> int:
	for i in school.fish_count():
		if school.is_alive(i):
			return i
	return -1


## `who` 2.5 m behind the lone fish, nose on, fast, for a moment.
func _ram_target(run: NatureRun, who: FishController) -> void:
	var target := run.target
	var heading := -target.global_basis.z
	who.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), target.global_position - heading * 2.5)
	who.linear_velocity = heading * (who.nature_batter_speed + 6.0)
	who.angular_velocity = Vector3.ZERO
	for i in 30:
		await get_tree().physics_frame
		if target.battered:
			break


## Every one of `attackers` right behind school fish `index`, nose on and fast,
## so they reach it the same tick (they pass through each other).
func _ram_school_fish_together(run: NatureRun, school: School, index: int, attackers: Array) -> void:
	for i in 40:
		if not school.is_alive(index):
			break
		var at := school.fish_position(index)
		var heading := Vector3(1, 0, 0.2).normalized()
		for who: FishController in attackers:
			who.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at - heading * 0.9)
			who.linear_velocity = heading * (who.nature_batter_speed + 6.0)
			who.angular_velocity = Vector3.ZERO
		await get_tree().physics_frame
	for who: FishController in attackers:
		who.linear_velocity = Vector3.ZERO


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
