class_name BurstCloud
extends Node3D
## What a Bloated Boxfish leaves when it dies (planning_unnatural.md §3): a
## sickly cloud that swells out to `radius` and hurts any player inside it
## (UnnaturalRun checks contains()) until it fades after `lifetime` seconds.

const SWELL_TIME := 0.25
const COLOR := Color(0.55, 0.75, 0.2, 0.32)

var radius := 3.5
var lifetime := 2.5
var age := 0.0

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
	_material.albedo_color = COLOR
	sphere.material = _material
	_ball.mesh = sphere
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_place()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	_place()


## Whether `point` is inside it now (`margin` m of grace for the player's size).
func contains(point: Vector3, margin := 0.0) -> bool:
	return age < lifetime and global_position.distance_to(point) <= current_radius() + margin


func current_radius() -> float:
	return radius * clampf(age / SWELL_TIME, 0.15, 1.0)


func _place() -> void:
	_ball.scale = Vector3.ONE * maxf(current_radius(), 0.05)
	var fade := 1.0 - clampf((age - lifetime * 0.6) / (lifetime * 0.4), 0.0, 1.0)
	_material.albedo_color = Color(COLOR, COLOR.a * fade)
