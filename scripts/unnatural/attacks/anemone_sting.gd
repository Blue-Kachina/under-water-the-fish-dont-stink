class_name AnemoneSting
extends FishAttack
## The Clownfish's auto-attack (planning_unnatural.md §5): a stinging pulse
## all round it, like brushing an anemone. Every sting_cooldown seconds, if a
## zombie is within reach, a ring of tendrils lashes out and everything within
## radius() takes sting_damage, pushed away. It's melee, so the pulse always
## reaches further than the bow wave (sting_over_bow times it).

## The pulse grows to full size, hurts there, then fades.
const GROW_TIME := 0.1
const FADE_TIME := 0.3
const TENDRILS := 18
const COLOR := Color(1.0, 0.45, 0.75, 0.55)
## It hits many at once.
const PROC := 0.6

var _age := -1.0
var _shell := MeshInstance3D.new()
var _tendrils := Node3D.new()
var _material := FishAttack.ghost_material(COLOR)


func _init() -> void:
	name = "AnemoneSting"
	# A ring, not a shell: the camera often sits inside the pulse.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 8
	ring_mesh.material = _material
	_shell.mesh = ring_mesh
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	add_child(_tendrils)
	# Tendrils out in every direction (a Fibonacci sphere), each 1 long.
	for t in TENDRILS:
		var y := 1.0 - 2.0 * (t + 0.5) / TENDRILS
		var ring := sqrt(1.0 - y * y)
		var angle := t * PI * (3.0 - sqrt(5.0))
		var out := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var tendril := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.06
		cone.height = 0.7
		cone.radial_segments = 5
		cone.rings = 1
		cone.material = _material
		tendril.mesh = cone
		tendril.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var up := Vector3.UP if absf(out.y) < 0.98 else Vector3.BACK
		# The cylinder runs along y: point it outward, its base 0.3 out from the middle.
		tendril.transform = Transform3D(Basis.looking_at(out, up) * Basis(Vector3.RIGHT, -PI / 2.0), out * 0.65)
		_tendrils.add_child(tendril)
	visible = false


func cooldown() -> float:
	return settings.sting_cooldown


func damage() -> float:
	return settings.sting_damage


func proc() -> float:
	return PROC


## The pulse's radius (m): sting_radius, or more if the bow wave reaches further.
func radius() -> float:
	return maxf(settings.sting_radius, GhostBite.bow_reach(fish) * settings.sting_over_bow) * area_scale


func busy() -> bool:
	return _age >= 0.0 and _age < GROW_TIME


func fire() -> bool:
	var at := origin()
	if horde.query_sphere(at, radius()).is_empty():
		return false
	_age = 0.0
	visible = true
	_place(0.0)
	return true


func _animate(delta: float) -> void:
	if _age < 0.0:
		return
	var before := _age
	_age += delta
	if before < GROW_TIME and _age >= GROW_TIME:
		var at := origin()
		for i in horde.query_sphere(at, radius()):
			strike(i, settings.sting_damage, toward(at, i, nose()))
	if _age >= GROW_TIME + FADE_TIME:
		_age = -1.0
		visible = false
		return
	_place(_age)


func _place(age: float) -> void:
	var grow := clampf(age / GROW_TIME, 0.0, 1.0)
	var size := radius() * (0.25 + 0.75 * (1.0 - (1.0 - grow) * (1.0 - grow)))
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size), origin())
	_tendrils.rotation.y = age * 3.0
	var fade := 1.0 - clampf((age - GROW_TIME) / FADE_TIME, 0.0, 1.0)
	_material.albedo_color = Color(COLOR, COLOR.a * fade * (0.35 + 0.65 * grow))
