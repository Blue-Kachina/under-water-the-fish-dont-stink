extends Node
## Unnatural's split-screen co-op (planning_unnatural.md phase 8, LocalCoop): a
## controller's Back/View joins an Unnatural run, each player with their own
## fish, survivor cam and Unnatural HUD in their own view, their own attack and
## stats; the director scales with players; the team shares one level, and a
## level-up offers each player their own cards without pausing the game (D3);
## a downed player is revived by a teammate staying close (D7), and the run's
## over only when everyone's down; leaving drops the player from the run.
##   Godot_console.exe --headless --path . res://tests/unnatural_coop_probe.tscn

const PADS := [11, 12]

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var failures := 0


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
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.enemy_speed_scale = 0.0
	settings.card_choices = 3
	settings.cards_pause = true
	var local: LocalCoop = main._local
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run

	print("joining:")
	_press(PADS[0], LocalCoop.JOIN_BUTTON)
	await _ticks(5)
	check(local.count() == 2 and run.players.size() == 2, "Back/View joins the Unnatural run")
	var split: SplitScreen = main.get_node_or_null("SplitScreen")
	check(split != null and split.count() == 2, "the window splits")
	var second: PlayerSlot = local.slots[1]
	var first: PlayerSlot = local.slots[0]
	check(first.mode_hud == main._unnatural_hud and first.mode_hud.get_viewport() == split.view(0), "the first player's Unnatural HUD moved into their view")
	check(second.mode_hud is UnnaturalHud and (second.mode_hud as UnnaturalHud).fish == second.fish and second.mode_hud.get_viewport() == split.view(1),
			"the second has their own, in their view")
	check(second.camera.get("steady_heading") == settings.steady_camera and not second.camera.get("ball_cam"), "and the survivor cam")
	check(run.attack_of(second.fish) != null and run.health_of(second.fish) != null and run.twist_of(second.fish) != null,
			"their own attack, health and twist")
	check(second.fish.global_position.distance_to(fish.global_position) >= UnnaturalRun.SPAWN_SPACING - 0.5, "side by side")
	run.director.players = 2
	var two := run.director.baseline()
	run.director.players = 1
	check(two > run.director.baseline(), "the director wants more zombies for two")

	print("levels:")
	var offers := {}
	run.cards_offered.connect(func(f: FishController, cards: Array, _h: String, _l: String) -> void: offers[f] = cards)
	run.levels.add(run.levels.xp_to_next())
	await _ticks(3)
	check(offers.has(fish) and offers.has(second.fish), "one team level: each player gets their own cards")
	check(not get_tree().paused and not run.cards_pause_game(), "the game doesn't pause in co-op (D3)")
	check(run.is_picking(second.fish), "the picker can't be hurt or seen while choosing")
	run.pick(fish, 0)
	run.pick(second.fish, 1)
	await _ticks(2)
	check(not run.is_picking(fish) and not run.is_picking(second.fish), "both picked")

	print("down and revive:")
	settings.revive_time = 0.5
	second.fish.freeze = false
	second.fish.revive(Transform3D(Basis.IDENTITY, fish.global_position + Vector3(30, 0, 0)))
	await _ticks(3)
	var health := run.health_of(second.fish)
	health.iframes_left = 0.0
	run.hurt(second.fish, health.hp + 10.0)
	await _ticks(2)
	check(health.down and not run.is_over, "a player down, the run goes on")
	check(second.fish.controls_locked, "they can't swim while down")
	await _ticks(60)
	check(health.down and run.revive_progress(second.fish) == 0.0, "nobody near: still down")
	fish.freeze = false
	fish.revive(Transform3D(Basis.IDENTITY, second.fish.global_position + Vector3(2, 0, 0)))
	await _ticks(int(Engine.physics_ticks_per_second * 0.8))
	check(not health.down and is_equal_approx(health.hp, health.max_hp * settings.revive_hp) and not second.fish.controls_locked,
			"a teammate close by revives them (%.0f hp)" % health.hp)
	var first_health := run.health_of(fish)
	first_health.iframes_left = 0.0
	run.hurt(fish, first_health.hp * 10.0 + 100.0)  # well past any armour or twist (a Boxfish's Armoured)
	await _ticks(2)
	check(first_health.down and not run.is_over, "one down: not over")
	health.iframes_left = 0.0
	run.hurt(second.fish, health.hp * 10.0 + 100.0)
	await _ticks(2)
	check(run.is_over, "both down: the run's over")
	main.reset_play()
	await _ticks(5)
	check(not run.is_over and not health.down and not first_health.down, "R: everyone back up")

	print("leaving:")
	local.leave(second)
	await _ticks(5)
	check(local.count() == 1 and run.players.size() == 1 and main.get_node_or_null("SplitScreen") == null, "a player leaves: one again, the whole window")
	check(main._unnatural_hud.get_viewport() == main.get_viewport(), "the first player's HUD back in the window")
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _press(pad: int, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = pad
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
