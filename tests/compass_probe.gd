extends Node
## The compass (planning_environment.md, Phase 2, E5): bearings (north = -Z,
## east = +X), where a bearing lands on the strip and when it's past the ends,
## the strip following the camera, the settings switching it and the ring
## off, the minimap's ring narrowing the map, and shrines showing only once
## found (shrine_reveal_range), and for good.
##   Godot_console.exe --headless --path . res://tests/compass_probe.tscn

var failures := 0
var main: Node
var fish: FishController


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.shrine_count = 4
	settings.shrine_reveal_range = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var hud: UnnaturalHud = run.huds[0] if "huds" in run and not run.huds.is_empty() else _find_hud(main)
	check(hud != null, "the run has a HUD")
	if hud == null:
		_finish()
		return
	var strip: CompassStrip = hud._compass
	var map: Minimap = hud._minimap

	print("bearings:")
	check(is_zero_approx(CompassStrip.bearing_of(Vector3(0, 0, -1))), "-Z is north (0)")
	check(is_equal_approx(CompassStrip.bearing_of(Vector3(1, 0, 0)), PI / 2.0), "+X is east (90)")
	check(is_equal_approx(absf(CompassStrip.bearing_of(Vector3(0, 0, 1))), PI), "+Z is south (180)")

	print("the strip:")
	await _frames(3)
	check(strip.visible, "shows by default")
	check(strip.size.x > 100.0 and strip.position.y > 20.0, "sits under the XP bar (%.0f wide at y %.0f)" % [strip.size.x, strip.position.y])
	strip.heading = 0.0
	var ahead: Array = strip.place(0.0)
	check(is_equal_approx(ahead[0], strip.size.x * 0.5) and ahead[1], "straight ahead is the middle")
	var east: Array = strip.place(deg_to_rad(60.0))
	check(east[0] > strip.size.x * 0.5 and east[1], "60 degrees east is right of it, within the %d-degree span" % roundi(settings.compass_fov))
	var behind: Array = strip.place(PI)
	# Pinned in the rounded end's cap (half the strip's height in from the edge).
	check(not behind[1] and (is_equal_approx(behind[0], strip.size.y * 0.5) or is_equal_approx(behind[0], strip.size.x - strip.size.y * 0.5)),
			"behind is past an end, pinned to it")
	check(hud.top_push() > 0.0 and hud._clock.offset_top > 22.0, "the clock moves down for it (+%.0f px)" % hud.top_push())
	var camera := hud.player_camera if is_instance_valid(hud.player_camera) else get_viewport().get_camera_3d()
	if camera:
		await _ticks(2)
		var looking := CompassStrip.bearing_of(-camera.global_basis.z)
		check(absf(wrapf(strip.heading - looking, -PI, PI)) < 0.05, "it follows the camera (%.0f vs %.0f deg)" % [rad_to_deg(strip.heading),
				rad_to_deg(looking)])
	settings.compass_strip = false
	await _frames(3)
	check(not strip.visible and hud.top_push() == 0.0, "compass_strip off hides it and the clock moves back")
	settings.compass_strip = true

	print("the ring:")
	await _frames(3)
	var with_ring := map._radius
	settings.compass_ring = false
	await _frames(3)
	check(map._radius > with_ring + 5.0, "the ring takes a band round the map (%.0f -> %.0f px)" % [with_ring, map._radius])
	settings.compass_ring = true

	print("shrines are found:")
	check(run.shrines.size() == settings.shrine_count, "%d shrines" % run.shrines.size())
	var far_one: Shrine = null
	for shrine in run.shrines:
		if not shrine.is_over(fish.global_position, settings.shrine_reveal_range):
			far_one = shrine
			break
	check(far_one != null and not far_one.discovered, "a far shrine starts hidden")
	if far_one:
		fish.global_position = far_one.global_position + Vector3(0.0, 4.0, settings.shrine_reveal_range - 5.0)
		fish.linear_velocity = Vector3.ZERO
		await _ticks(3)
		check(far_one.discovered, "swimming within shrine_reveal_range finds it")
		fish.global_position = run.centre + Vector3(0.0, 4.0, 0.0)
		await _ticks(3)
		check(far_one.discovered, "and it stays found")
	settings.shrine_reveal_range = 0.0
	await _frames(3)
	check(run.shrines.all(func(s: Shrine) -> bool: return s.discovered), "shrine_reveal_range 0: all show")
	settings.shrine_reveal_range = 60.0
	_finish()


func _finish() -> void:
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _find_hud(node: Node) -> UnnaturalHud:
	if node is UnnaturalHud:
		return node
	for child in node.get_children():
		var found := _find_hud(child)
		if found:
			return found
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
