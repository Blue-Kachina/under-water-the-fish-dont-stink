class_name BurstCloud
extends Node3D
## What a Bloated Boxfish leaves when it dies (planning_unnatural.md §3): a
## sickly cloud that swells out to `radius` and hurts any player inside it
## (UnnaturalRun checks contains()) until it fades after `lifetime` seconds.
## Elite modifiers (P5) use it too: a Burning elite's fire patches, and an
## Electric one's shock, which `delay`s (a faint shell showing where, doing
## nothing) before it goes off.

const SWELL_TIME := 0.25
const COLOR := Color(0.55, 0.75, 0.2, 0.32)

var radius := 3.5
var lifetime := 2.5
var age := 0.0
## What a touch does (-1: the run's burst_damage), its colour, and what the run log calls it.
var damage := -1.0
var color := COLOR
var cause := "a burst cloud"
## Seconds before it can hurt (lifetime counts from when it does).
var delay := 0.0

var _material := StandardMaterial3D.new()
var _ball := MeshInstance3D.new()


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = color
	sphere.material = _material
	_ball.mesh = sphere
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_place()


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay = maxf(delay - delta, 0.0)
		_place()
		return
	age += delta
	if age >= lifetime:
		queue_free()
		return
	_place()


## Whether `point` is inside it now (`margin` m of grace for the player's size).
func contains(point: Vector3, margin := 0.0) -> bool:
	return delay <= 0.0 and age < lifetime and global_position.distance_to(point) <= current_radius() + margin


func current_radius() -> float:
	return radius * clampf(age / SWELL_TIME, 0.15, 1.0)


func _place() -> void:
	if delay > 0.0:
		# Armed: a faint shell at its full size, flickering faster as it nears.
		_ball.scale = Vector3.ONE * radius
		_material.albedo_color = Color(color, color.a * (0.25 + 0.25 * sin(Time.get_ticks_msec() * 0.03 / maxf(delay, 0.1))))
		return
	_ball.scale = Vector3.ONE * maxf(current_radius(), 0.05)
	var fade := 1.0 - clampf((age - lifetime * 0.6) / (lifetime * 0.4), 0.0, 1.0)
	_material.albedo_color = Color(color, color.a * fade)
