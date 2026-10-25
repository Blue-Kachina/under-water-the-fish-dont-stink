extends Node
## The jellies' bell pulsation (BellPulse, jelly_pulse.gdshaderinc), from
## private_content/jellyfish_swim_compact.gif:
## - a stride is a power stroke (a quick contraction, the margin leading) and,
##   under Gait.BellRhythm.ALTERNATE, the next a recovery stroke (a slower
##   expansion past rest, the margin lagging and overshooting into a flare);
## - with no stride after a power stroke the bell relaxes open on its own and
##   glides back to rest; EACH_STRIDE makes every stride a whole pulse;
## - without a gait it beats with the swim;
## - in the game, a Drifter's strides drive it, its shaders get the shape, and
##   its oral arms (the tail pivot) don't wag with lateral sweeps.
##   Godot_console.exe --headless --path . res://tests/jelly_pulse_probe.tscn

const DT := 1.0 / 120.0
const PEAK := 0.28
const FADE := 0.48

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("power and recovery strokes (alternate):")
	var gait := Gait.new()
	var bell := BellPulse.new()
	_idle(bell, gait, 1.0)
	var margin_led := false
	var t := 0.0
	while t < PEAK:
		bell.step_strides(DT, t, PEAK, FADE, gait)
		t += DT
		if t < PEAK * 0.6 and bell.margin > bell.crown + 0.05:
			margin_led = true
	check(bell.last_power and bell.crown > 0.7, "a stride shuts the bell by its peak (crown %.2f, margin %.2f)" % [bell.crown, bell.margin])
	check(margin_led, "the margin leads the crown as it shuts")
	# Chain the next stride at the peak: the recovery stroke.
	t = 0.0
	var lowest_margin := 0.0
	var crown_ahead := false
	var open_time := INF
	var chained_open := 0.0
	while t < PEAK + FADE:
		if absf(t - PEAK) < DT * 0.5:
			chained_open = bell.crown
		bell.step_strides(DT, t, PEAK, FADE, gait)
		t += DT
		lowest_margin = minf(lowest_margin, bell.margin)
		if bell.crown < bell.margin - 0.05:
			crown_ahead = true
		if bell.crown <= -0.6 and open_time == INF:
			open_time = t
	check(not bell.last_power and bell.crown < -0.6, "the next stride spreads it open past rest (crown %.2f)" % bell.crown)
	check(crown_ahead, "the crown leads the margin as it opens")
	check(lowest_margin < -1.02, "the margin overshoots into a flare (%.2f)" % lowest_margin)
	check(chained_open < -0.6, "chained at the peak, it's open by the next stride (crown %.2f)" % chained_open)
	check(bell.power_strokes == 1 and bell.strides == 2, "strides take turns: power, then recovery")
	# A third stride, from open: a power stroke again, quicker over the same
	# swing than the recovery was.
	t = 0.0
	var shut_time := INF
	while t < PEAK:
		bell.step_strides(DT, t, PEAK, FADE, gait)
		t += DT
		if bell.crown >= 0.6 and shut_time == INF:
			shut_time = t
	check(bell.last_power and bell.power_strokes == 2, "from open, the next stride shuts it again")
	check(shut_time * 1.3 < open_time, "the power stroke is quicker than the recovery (%.2f s vs %.2f s)" % [shut_time, open_time])

	print("left alone:")
	bell = BellPulse.new()
	_idle(bell, gait, 1.0)
	_stride(bell, gait, PEAK + FADE)
	var lowest := INF
	var t2 := 0.0
	while t2 < gait.bell_recovery_time + 0.4:
		bell.step_strides(DT, -1.0, PEAK, FADE, gait)
		t2 += DT
		lowest = minf(lowest, bell.crown)
	check(lowest < -0.4, "after a power stroke with no recovery stride it relaxes open on its own (%.2f)" % lowest)
	_idle(bell, gait, 3.0)
	check(absf(bell.crown - BellPulse.REST) < BellPulse.IDLE_BEAT + 0.08, "then glides near rest with a faint beat (%.2f)" % bell.crown)
	var still := Gait.new()
	still.bell_ripple = 0.0
	bell = BellPulse.new()
	_idle(bell, still, 1.0)
	var spread := 0.0
	for i in 2:
		var t3 := 0.0
		while t3 < PEAK:
			bell.step_strides(DT, t3, PEAK, FADE, still)
			t3 += DT
			spread = maxf(spread, absf(bell.crown - bell.margin))
	check(spread < 0.25 and bell.ripple < 0.01, "bell_ripple 0: the margin keeps with the crown (%.2f apart)" % spread)

	print("each stride a whole pulse:")
	var each := Gait.new()
	each.bell_rhythm = Gait.BellRhythm.EACH_STRIDE
	bell = BellPulse.new()
	var highest := -INF
	var low := INF
	for i in 4:
		var t4 := 0.0
		while t4 < PEAK + FADE:  # left to fade, so there's time to open
			bell.step_strides(DT, t4, PEAK, FADE, each)
			t4 += DT
			highest = maxf(highest, bell.crown)
			if i > 0:
				low = minf(low, bell.crown)
	check(bell.power_strokes == 4, "every stride is a power stroke (%d of %d)" % [bell.power_strokes, bell.strides])
	check(highest > 0.5 and low < -0.5, "and it opens again within each (%.2f..%.2f)" % [low, highest])

	print("beating with the swim (no gait):")
	var model := FishModel.build(FishCharacter.FishClass.DRIFTER)
	add_child(model)
	check(model.bell != null and model.trails_tail and not model._bell_pulses.is_empty(), "a jelly model has a bell, trailing arms and pulsing shaders")
	var top := -INF
	var bottom := INF
	for i in 400:
		model.react(DT, Vector3(0.0, 0.0, -3.0))
		top = maxf(top, model.bell.crown)
		bottom = minf(bottom, model.bell.crown)
	check(top > 0.3 and bottom < -0.2, "it beats on its own (%.2f..%.2f)" % [bottom, top])
	var material: ShaderMaterial = model._bell_pulses[0]
	check(is_equal_approx(float(material.get_shader_parameter("bell_crown")), model.bell.crown), "its shaders take the bell's shape")
	model.queue_free()

	await _in_game()
	print("jelly_pulse_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _in_game() -> void:
	print("in the game (Nature, Extra Swishy):")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	var panel: Node = main.get_node("DebugPanel")
	panel.load_mode_preset(main.NATURE_PRESET)
	var fish: FishController = main.get_node("Fish")
	var input := FishInput.new()
	fish.controls = input
	await get_tree().physics_frame
	var results := {}
	for fish_class: FishCharacter.FishClass in [FishCharacter.FishClass.DRIFTER, FishCharacter.FishClass.HUNTER]:
		input.clear()
		fish.set_look(fish_class, 0)
		fish.request_reset()
		for i in 10:
			await get_tree().physics_frame
		var peak_ticks := maxi(roundi(fish.swishy.peak_time() * Engine.physics_ticks_per_second), 1)
		# How far the tail swings back and forth within each pair of strides
		# (a steady trail round a turn isn't a wag).
		var swings: Array[float] = []
		var window: Array[float] = []
		var crowns: Array[float] = []
		for tick in 240:
			input.forward = 1.0
			input.stick = Vector2.RIGHT * (1.0 if floori(float(tick) / peak_ticks) % 2 == 0 else -1.0)
			await get_tree().physics_frame
			await get_tree().process_frame
			window.append(fish._tail.rotation.y)
			if window.size() == peak_ticks * 2:
				swings.append(window.max() - window.min() - absf(window[-1] - window[0]))  # less any steady drift
				window.clear()
			if fish._visual.bell:
				crowns.append(fish._visual.bell.crown)
		var total := 0.0
		for swing in swings.slice(1):
			total += swing
		results[fish_class] = total / maxf(swings.size() - 1, 1)
		if fish_class == FishCharacter.FishClass.DRIFTER:
			var bell: BellPulse = fish._visual.bell
			check(bell.strides > 6 and bell.power_strokes > 2 and bell.strides - bell.power_strokes > 2,
					"strides drive the bell, power and recovery in turn (%d strides, %d power)" % [bell.strides, bell.power_strokes])
			check(crowns.max() > 0.6 and crowns.min() < -0.5, "it shuts and opens as it goes (%.2f..%.2f)" % [crowns.min(), crowns.max()])
	input.clear()
	var jelly: float = results[FishCharacter.FishClass.DRIFTER]
	var shark: float = results[FishCharacter.FishClass.HUNTER]
	check(jelly < 0.15 and shark > 0.3, "a jelly's arms don't wag with side-to-side strides (%.2f rad a stride pair; a shark's tail %.2f)" % [jelly, shark])
	main.queue_free()


func _idle(bell: BellPulse, gait: Gait, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		bell.step_strides(DT, -1.0, PEAK, FADE, gait)
		t += DT


## One stride, `seconds` long.
func _stride(bell: BellPulse, gait: Gait, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		bell.step_strides(DT, t, PEAK, FADE, gait)
		t += DT
