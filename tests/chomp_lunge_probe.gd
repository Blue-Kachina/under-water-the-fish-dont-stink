extends Node
## Zombie lunges' light impact (ChompKit.light_impact, planning_bosses_and_survival.md
## §4f) in the real game: a lunge landing ticks the camera, flashes the
## vignette and puffs bubbles; however many land, at most one plays per player
## per lunge_impact_every s (the rest only merge their shake), so a
## 200-zombie swarm costs the same as one lunge; lunge_impact off, none play.
##   Godot_console.exe --headless --path . res://tests/chomp_lunge_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var horde: Horde
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
	settings.card_choices = 0
	settings.chest_count = 0
	settings.shrine_count = 0
	settings.stage_events = false
	settings.twists = false
	settings.base_hp = 1000000.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.bite_damage = 0.0
	settings.iframes = 0.0
	settings.run_length = 0
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	await _direct()
	await _swarm(true)
	await _swarm(false)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## 200 lunges landing in one tick: one impact, 199 merged; the next window, one more.
func _direct() -> void:
	print("200 lunges at once:")
	ChompKit.reset()
	var camera := ChompKit._camera_of(fish)
	var hud := ChompKit._hud_of(fish)
	hud.hurt_level = 0.0
	for n in 200:
		ChompKit.light_impact(run, fish, fish.global_position + Vector3(cos(n), 0.2, sin(n)) * 2.0)
	check(ChompKit.light_impacts == 1 and ChompKit.light_merged == 199, "one impact plays, the rest merge (%d played, %d merged)" % [ChompKit.light_impacts, ChompKit.light_merged])
	check(camera != null and float(camera.get("_punch")) > 0.0, "the camera ticks (%.3f m)" % (float(camera.get("_punch")) if camera else 0.0))
	check(hud.hurt_level >= settings.lunge_impact_flash * 0.9 and hud.hurt_level < settings.chomp_vignette, "a light rim flash (%.2f)" % hud.hurt_level)
	await _ticks(int(settings.lunge_impact_every * 120.0) + 2)
	ChompKit.light_impact(run, fish, fish.global_position + Vector3.FORWARD * 2.0)
	check(ChompKit.light_impacts == 2, "the next window, another plays")
	# What it costs: a merged call (most of a swarm's) and a played one (no
	# knock: a thousand of them would fling the fish).
	var knock := settings.lunge_impact_knock
	settings.lunge_impact_knock = 0.0
	var t := Time.get_ticks_usec()
	for n in 10000:
		ChompKit.light_impact(run, fish, fish.global_position + Vector3.FORWARD * 2.0)
	var merged_us := (Time.get_ticks_usec() - t) / 10000.0
	t = Time.get_ticks_usec()
	for n in 1000:
		ChompKit._light_at.erase(fish)
		ChompKit.light_impact(run, fish, fish.global_position + Vector3.FORWARD * 2.0)
	var played_us := (Time.get_ticks_usec() - t) / 1000.0
	settings.lunge_impact_knock = knock
	fish._ball_push = Vector3.ZERO
	await _ticks(30)  # the hit-stop timers run out
	# A swarm landing 200 lunges a second on each of 3 players, one played per window.
	var per_second := 3.0 * (200.0 * merged_us + played_us / maxf(settings.lunge_impact_every, 0.01))
	print("  cost: merged %.2f us, played %.2f us; a 3-player, 200-lunges/s swarm: %.3f ms per second (%.3f%% of a 60 fps frame budget)" % [
			merged_us, played_us, per_second / 1000.0, per_second / 1000.0 / 1000.0 * 100.0])
	check(per_second / 1000.0 < 10.0, "under 1%% of the frame budget (%.2f ms of every 1000)" % (per_second / 1000.0))


## A real swarm of 200 lunging swordfish round the player for 2 s: at most one
## light impact per window (lunge_impact on), none with it off.
func _swarm(on: bool) -> void:
	print("a 200-swordfish swarm, lunge_impact %s:" % ("on" if on else "off"))
	settings.lunge_impact = on
	horde.clear()
	await _ticks(2)
	ChompKit.reset()
	var kind := -1
	for k in horde.kinds.size():
		if horde.kinds[k].id == "swordfish":
			kind = k
	fish.freeze = false
	fish.global_position = run.centre
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true
	for n in 200:
		var angle := TAU * n / 200.0
		var at := fish.global_position + Vector3(cos(angle), sin(n * 0.7) * 0.3, sin(angle)) * (6.0 + (n % 5) * 2.0)
		horde.spawn(kind, at, (fish.global_position - at).normalized(), false, true)  # undying: only their lunges count here
	var taken: float = run.stats_of(fish).taken
	var seconds := 2.0
	await _ticks(int(seconds * 120.0))
	var hurt: float = run.stats_of(fish).taken - taken
	var windows := ceili(seconds / settings.lunge_impact_every) + 1
	if on:
		check(hurt > 0.0 and ChompKit.light_impacts >= 1, "lunges land (%.0f damage) and light impacts play (%d)" % [hurt, ChompKit.light_impacts])
		check(ChompKit.light_impacts <= windows, "throttled: at most one per %.2f s window (%d in %d windows, %d merged)" % [settings.lunge_impact_every, ChompKit.light_impacts, windows, ChompKit.light_merged])
		var fx := run.get_node_or_null("ChompFx") as ChompKit.Fx
		check(fx != null and fx.puffs.size() == ChompKit.Fx.PUFFS, "its bubble puffs stay a fixed pool (%d)" % (fx.puffs.size() if fx else 0))
	else:
		check(hurt > 0.0 and ChompKit.light_impacts == 0, "off: lunges still land (%.0f damage), no impacts play" % hurt)
	settings.lunge_impact = true
	horde.clear()
	await _ticks(2)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
