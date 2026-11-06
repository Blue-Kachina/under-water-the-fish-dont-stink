extends Node3D
## Probe for SonarMap and MarcoPoloHud (planning_marco_polo.md §4, §6, phase 3),
## against a stub match:
## - the local seeker gets the scope: their own pings become blips (another
##   seeker's don't), and blips fade out after blip_life;
## - a hider gets the hider map; a spectator the map of the hider they watch;
## - outside a round the map's hidden;
## - the HUD never shows a round score while the round's on (the totals panel
##   shows only the totals from before it, and a seeker sees only their own);
## - the catch feed says "TAGGED" and "FISH OUT OF WATER", never "seen".
## `--shots` (needs a window): the scope, the hider map and the HUD, as PNGs.
##   Godot_console.exe --headless --path . res://tests/sonar_probe.tscn
##   Godot_console.exe --path . res://tests/sonar_probe.tscn -- --shots --out=DIR

const FISH_SCENE := preload("res://scenes/fish.tscn")

var failures := 0
var out_dir := "user://sonar_shots"
var stub: StubMatch
var map: SonarMap
var hud: MarcoPoloHud


func _ready() -> void:
	var shots := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--shots":
			shots = true
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	_run.call_deferred(shots)


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _spawn(fish_class: FishCharacter.FishClass, at: Vector3, title: String) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	fish.character = fish_class
	fish.display_name = title
	add_child(fish)
	fish.global_position = at
	fish.freeze = true
	return fish


func _run(shots: bool) -> void:
	if shots:
		get_window().size = Vector2i(1280, 720)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.08, 0.2, 0.24)
		var world := WorldEnvironment.new()
		world.environment = environment
		add_child(world)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 6.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	stub = StubMatch.new()
	add_child(stub)
	var me := _spawn(FishCharacter.FishClass.HUNTER, Vector3.ZERO, "You")
	var other := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(20.0, 0.0, -25.0), "Nemo")
	var third := _spawn(FishCharacter.FishClass.CHARMER, Vector3(-30.0, 0.0, 10.0), "Koi")
	stub.players = [me, other, third]
	stub.me = me
	stub.roles = {me: 1, other: 0, third: 0}
	stub.totals_now = {me: 34.0, other: 51.0, third: 12.0}
	stub.settings.blip_life = 0.5
	map = SonarMap.new()
	stub.add_child(map)
	map.bind(stub)
	hud = MarcoPoloHud.new()
	stub.add_child(hud)
	hud.bind(stub)
	stub.phase = 1
	await _frames(2)
	print("the local seeker's scope:")
	check(map.mode == "scope" and map.visible, "the seeker gets the scope (%s)" % map.mode)
	stub.pinged.emit(me, Vector3(10.0, 0.0, -20.0), 0.8, false)
	stub.pinged.emit(me, Vector3(-15.0, 0.0, 5.0), 0.4, true)
	stub.pinged.emit(other, Vector3(5.0, 0.0, 5.0), 1.0, false)
	check(map.blips.size() == 2, "its own pings are blips, another seeker's aren't (%d)" % map.blips.size())
	if shots:
		await _shot("scope")
		stub.phase = 0
		stub.phase_left = 7.2
		await _shot("seeker_countdown")
		stub.phase = 1
	await get_tree().create_timer(0.7).timeout
	check(map.blips.is_empty(), "blips fade out after blip_life (%d left)" % map.blips.size())
	print("the seeker's HUD:")
	check(_totals_shown(me).size() == 1 and _totals_shown(me).has(me), "a seeker sees only their own total")
	print("a hider's map:")
	stub.roles = {me: 0, other: 1, third: 0}
	stub.noise_now = 0.6
	stub.seen_now = true
	await _frames(2)
	check(map.mode == "hider", "a hider gets the hider map (%s)" % map.mode)
	check(_totals_shown(me).size() == 3, "a hider sees the totals from before the round")
	hud._on_caught(third, "tag", other)
	hud._on_caught(me, "out_of_water", null)
	var feed_text := ""
	for line: Dictionary in hud._feed:
		feed_text += String(line.text) + " | "
	check(feed_text.contains("TAGGED") and feed_text.contains("FISH OUT OF WATER") and not feed_text.to_lower().contains("seen"),
			"the feed: %s" % feed_text)
	check(hud._banner == "FISH OUT OF WATER!", "the banner for my own fish out of water (%s)" % hud._banner)
	stub.totals_now[other] = 999.0  # a mid-round change would be a radar: totals only move between rounds
	check(stub.round_tally_calls == 0, "the HUD never asked for a round tally during the round")
	if shots:
		hud._banner_age = 0.5
		await _shot("hider")
	print("a spectator:")
	stub.spectating = true
	stub.watched = third
	stub.roles = {me: 0, other: 1, third: 0}
	await _frames(2)
	check(map.mode == "hider" and map._subject == third, "the map of the watched hider")
	print("the round's over:")
	stub.spectating = false
	stub.phase = 2
	hud._on_round_over({"round": 0, "seekers": [other], "points": {me: 12.0, other: 40.0, third: 7.0},
			"totals": {me: 46.0, other: 91.0, third: 19.0}, "survivors": [], "cleared": true, "time_left": 61.0})
	await _frames(2)
	check(not map.visible, "the map's hidden outside a round")
	if shots:
		await _shot("round_over")
	print("sonar_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Who the HUD's totals panel would list for `me` now.
func _totals_shown(me: Node) -> Array:
	var seeker := stub.role_of(me) == 1
	var shown := []
	for fish: Node in stub.totals():
		if not seeker or fish == me:
			shown.append(fish)
	return shown


func _shot(shot_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("  shot %s" % shot_name)


## The bits of MarcoPoloMatch the map and HUD read.
class StubMatch extends Node:
	signal pinged(seeker: Node, pos: Vector3, loudness: float, polo: bool)
	signal round_started(index: int, seeker: Node)
	var settings := MarcoPoloSettings.new()
	var players: Array[FishController] = []
	var roles := {}
	var me: FishController
	var phase := 0
	var phase_left := 0.0
	var time_left := 143.0
	var round_index := 1
	var arena: Node = null
	var porthole_system: Node = null
	var camera: Node = null
	var center := Vector3.ZERO
	var totals_now := {}
	var spectating := false
	var watched: FishController
	var noise_now := 0.0
	var seen_now := false
	var round_tally_calls := 0

	func local_fish() -> FishController:
		return me

	func role_of(fish: Node) -> int:
		return int(roles.get(fish, 0))

	func is_spectating() -> bool:
		return spectating

	func spectate_target() -> FishController:
		return watched

	func rounds_in_match() -> int:
		return 3

	func max_exposure(_fish: Node) -> float:
		return 0.5

	func noise(_fish: Node) -> float:
		return noise_now

	func is_seen_now(_fish: Node) -> bool:
		return seen_now

	func fake_charges(_fish: Node) -> int:
		return 1

	func marco_ready(_fish: Node) -> float:
		return 0.6

	func marco_ring_left(_fish: Node) -> float:
		return 1.0

	func live_hiders() -> Array[FishController]:
		var out: Array[FishController] = []
		for fish in players:
			if role_of(fish) == 0:
				out.append(fish)
		return out

	func seekers() -> Array[FishController]:
		var out: Array[FishController] = []
		for fish in players:
			if role_of(fish) == 1:
				out.append(fish)
		return out

	func decoys() -> Array[FishController]:
		return []

	func totals() -> Dictionary:
		return totals_now.duplicate()

	func own_round_tally(_fish: Node) -> float:
		round_tally_calls += 1
		return 0.0
