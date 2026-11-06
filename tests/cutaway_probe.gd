extends Node
## The follow cam against Marco Polo's solid walls: with its back to a wall it sits
## out past it and the wall is hidden (MarcoArena.cut_away), in open water it stays
## in and every wall shows, and it comes back in when the fish does.
##   Godot_console.exe --headless --path . res://tests/cutaway_probe.tscn

const TICKS := 120

var main: Node
var fish: FishController
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
	var mp := MarcoPoloSettings.shared()
	mp.whale_seeker = false
	mp.hide_time = 0.3
	mp.round_time = 300.0
	for arena_name: String in ["Sunken Temple", "Aquarium"]:
		await _arena_checks(mp, arena_name)
	print("cutaway_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _arena_checks(mp: MarcoPoloSettings, arena_name: String) -> void:
	print("%s:" % arena_name)
	mp.arena = arena_name
	if main.marco_polo:
		main.set_mode(main.FREE_SWIM)
		await _ticks(3)
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	var arena := game.arena as MarcoArena
	var camera := main.get_node("FollowCamera") as Camera3D
	game.start_round(1)
	await _ticks(10)
	var half := arena.size * 0.5

	# Open water: in, and every wall on show.
	_put(arena.global_position + Vector3(0.0, 8.0, 0.0), Vector3.FORWARD)
	await _ticks(180)
	check(arena.contains(camera.global_position), "open water: the camera is inside the arena")
	check(arena._cut_sides.is_empty(), "open water: no wall hidden")

	# Back to the +x wall, facing in: the camera would be inside the wall.
	_put(arena.global_position + Vector3(half.x - 1.0, 8.0, 0.0), Vector3.LEFT)
	await _ticks(240)
	check(not arena.contains(camera.global_position), "back to a wall: the camera is out past it (x %.1f of %.1f)" % [camera.global_position.x - arena.global_position.x, half.x])
	check(arena._cut_sides.has(Vector3.RIGHT), "that wall is hidden")
	check(_shown(arena, Vector3.LEFT) and _shown(arena, Vector3.FORWARD), "the other walls still show")

	# Swim back out: the camera comes in and the wall returns.
	_put(arena.global_position + Vector3(0.0, 8.0, 0.0), Vector3.LEFT)
	await _ticks(240)
	check(arena.contains(camera.global_position) and arena._cut_sides.is_empty(), "back in open water: inside again, walls back")

	# Off, the old pull-in.
	camera.set("wall_cutaway", false)
	_put(arena.global_position + Vector3(half.x - 1.0, 8.0, 0.0), Vector3.LEFT)
	await _ticks(240)
	check(arena.contains(camera.global_position) and arena._cut_sides.is_empty(), "wall_cutaway off: pulled in at the wall as before")
	camera.set("wall_cutaway", true)


## Whether every piece of `side` is visible (true with none tagged).
func _shown(arena: MarcoArena, side: Vector3) -> bool:
	for piece: Node3D in arena._shell_pieces.get(side, []):
		if not piece.visible:
			return false
	return true


func _put(at: Vector3, facing: Vector3) -> void:
	fish.freeze = true
	fish.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), at)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	if main.get_node("FollowCamera").has_method("snap"):
		main.get_node("FollowCamera").snap()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
