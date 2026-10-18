class_name SpaceSounds
extends Node
## The water's surface (planning_audio.md §3.2, §3.9), wherever a place sets
## Sfx.water_surface: a fish crossing it up breaches and down splashes, and a
## camera above it hears the open air (the low-pass opens up, the surface loop
## fades in). SfxHooks makes one. With no surface (INF) it does nothing.

## Vertical speed (m/s) for the quietest and the loudest splash.
const SPLASH_SOFT := 2.0
const SPLASH_HARD := 18.0
## How fast the air opens up and closes again (per second).
const OPEN_RATE := 4.0

var _above := {}
var _open := 0.0
var _loop := 0


func _exit_tree() -> void:
	Sfx.stop_loop(_loop)


func _process(delta: float) -> void:
	var surface := Sfx.water_surface
	if surface == INF:
		_above.clear()
		_set_open(0.0, delta)
		return
	for fish: FishController in Sfx.hooks.fish:
		if not is_instance_valid(fish) or fish.puppet or fish.battered:
			continue
		var above := fish.global_position.y > surface
		if _above.has(fish) and above != _above[fish]:
			var speed := absf(fish.linear_velocity.y)
			if above:
				Sfx.play_at("fish/breach", fish.global_position, clampf(inverse_lerp(SPLASH_SOFT, SPLASH_HARD, speed), 0.0, 1.0))
			else:
				Sfx.play_at("fish/splash", fish.global_position, clampf(inverse_lerp(SPLASH_SOFT, SPLASH_HARD, speed), 0.0, 1.0))
		_above[fish] = above
	var camera := get_viewport().get_camera_3d()
	_set_open(1.0 if camera != null and camera.global_position.y > surface else 0.0, delta)


func _set_open(target: float, delta: float) -> void:
	_open = move_toward(_open, target, OPEN_RATE * delta)
	Sfx.set_open_air(_open)
	if _open > 0.01 and _loop == 0:
		_loop = Sfx.start_loop("amb/surface_loop")
	elif _open <= 0.01 and _loop != 0:
		Sfx.stop_loop(_loop, 0.5)
		_loop = 0
	Sfx.set_loop(_loop, _open)
