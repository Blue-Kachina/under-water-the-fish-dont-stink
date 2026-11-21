class_name BubbleCurtain
extends Node3D
## A wall of rising bubbles (the Aquarium's airstones, its floor wand, the
## chest's burps, the diver's helmet; planning_marco_polo.md §12). While it's
## working it's loud (a positional fizz, mp/airstone), shows on the seeker's
## scope as clutter (MarcoArena.bubble_sources) and masks a hider inside it
## (MarcoArena.bubble_mask_at). Some pulse on a timer, so a spot that's safe now
## isn't in a few seconds.
##
## Its box is `extent` big, standing on its origin (y 0 up to extent.y),
## centred on x and z.

var extent := Vector3(20.0, 40.0, 2.0)
## Pulsing: on for on_time s, then off for off_time s (off_time 0: always on).
var on_time := 0.0
var off_time := 0.0
## Where in its cycle it starts (s).
var offset := 0.0
## Bubbles per metre of its length.
var density := 5.0
## How fast the bubbles rise (m/s).
var rise := 5.0
## Bubble size (m).
var bubble_size := 0.12
var active := true
## Plays its fizz (off for small sources that share another's).
var sound := true

var _time := 0.0
var _burst_left := 0.0
var _particles := CPUParticles3D.new()
var _loop := -1


func _ready() -> void:
	_time = offset
	var bubble := SphereMesh.new()
	bubble.radius = bubble_size
	bubble.height = bubble_size * 2.0
	bubble.radial_segments = 6
	bubble.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.4, 0.55, 0.6)
	material.metallic_specular = 1.0
	material.roughness = 0.05
	bubble.material = material
	_particles.mesh = bubble
	_particles.amount = clampi(roundi(maxf(extent.x, extent.z) * density), 8, 400)
	_particles.lifetime = extent.y / maxf(rise, 0.1)
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(extent.x * 0.5, 0.1, extent.z * 0.5)
	_particles.direction = Vector3.UP
	_particles.spread = 6.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = rise * 0.8
	_particles.initial_velocity_max = rise * 1.2
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.6
	_particles.local_coords = false
	_particles.preprocess = _particles.lifetime
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.position = Vector3(0.0, 0.1, 0.0)
	add_child(_particles)
	_set_active(_wanted())


func _process(delta: float) -> void:
	_time += delta
	_burst_left -= delta
	var wanted := _wanted()
	if wanted != active:
		_set_active(wanted)


func _exit_tree() -> void:
	if _loop >= 0:
		Sfx.stop_loop(_loop)
		_loop = -1


## Working for `seconds` from now, whatever its timer says (the chest's burp).
func burst(seconds: float) -> void:
	_burst_left = seconds
	_set_active(true)


## Whether it's working and `pos` (world) is in it.
func masks(pos: Vector3) -> bool:
	if not active:
		return false
	var local := to_local(pos)
	return absf(local.x) <= extent.x * 0.5 and absf(local.z) <= extent.z * 0.5 and local.y >= -0.5 and local.y <= extent.y


## Spots along it (world) for the scope's fizz: one every 4 m, at heights that
## move as the bubbles do.
func sources() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var count := maxi(roundi(maxf(extent.x, extent.z) / 4.0), 1)
	var long_x := extent.x >= extent.z
	for n in count:
		var t := (n + 0.5) / count - 0.5
		var along := t * (extent.x if long_x else extent.z)
		var y := fposmod(_time * rise + n * 7.3, extent.y)
		out.append(to_global(Vector3(along, y, 0.0) if long_x else Vector3(0.0, y, along)))
	return out


func _wanted() -> bool:
	if _burst_left > 0.0:
		return true
	if on_time < 0.0:
		return false  # only bursts
	if off_time <= 0.0:
		return true
	return fposmod(_time, on_time + off_time) < on_time


func _set_active(on: bool) -> void:
	active = on
	_particles.emitting = on
	if not sound or not is_inside_tree():
		return
	if on and _loop < 0:
		_loop = Sfx.start_loop("mp/airstone", self)
	elif not on and _loop >= 0:
		Sfx.stop_loop(_loop, 0.6)
		_loop = -1
