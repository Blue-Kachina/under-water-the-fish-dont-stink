class_name Pearl
extends Node3D
## A pearl a battered fish left behind in Nature (NatureRun): a small glowing,
## iridescent bead with an aura and a light of its own, bobbing where the fish
## was. Swim over it, or just close by: within magnet_radius it's drawn to the
## nearest player's fish (keeping up with it, and faster the nearer it gets),
## and within absorb_radius it's absorbed, streaming into the fish (collected).
## Left alone, it flickers through its last seconds and fades.
##
## Values come from NatureSettings, live. For now pearls are only counted.

signal collected(pearl: Pearl, by: FishController)

const AURA_SHADER := preload("res://shaders/pearl_aura.gdshader")
const COLOR := Color(0.93, 0.95, 1.0)
const GLOW := Color(0.75, 0.9, 1.0)
## How long the absorbing takes (s), and the flicker before it fades (s).
const ABSORB_TIME := 0.3
const FLICKER_TIME := 3.0

var settings: NatureSettings
## Its number in the run (NatureRun), the same on every machine in co-op; -1: not the run's.
var id := -1
## Fish that can collect it (the players').
var collectors: Array[FishController] = []
var age := 0.0
var velocity := Vector3.ZERO
## Being absorbed into this fish (null: not yet).
var absorbing: FishController

var _body := MeshInstance3D.new()
var _aura := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _aura_material := ShaderMaterial.new()
var _absorb_left := 0.0
var _base := Vector3.ZERO
var _bob := randf() * TAU
var _size := 0.0


func _init(pearl_settings: NatureSettings) -> void:
	settings = pearl_settings
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 10
	sphere.radius = 1.0
	sphere.height = 2.0
	var pearly := StandardMaterial3D.new()
	pearly.albedo_color = COLOR
	pearly.metallic = 0.35
	pearly.roughness = 0.12
	pearly.emission_enabled = true
	pearly.emission = GLOW
	pearly.emission_energy_multiplier = 0.9
	pearly.rim_enabled = true
	pearly.rim = 1.0
	pearly.rim_tint = 0.8
	pearly.clearcoat_enabled = true
	sphere.material = pearly
	_body.mesh = sphere
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	var shell := SphereMesh.new()
	shell.radial_segments = 20
	shell.rings = 10
	shell.radius = 1.0
	shell.height = 2.0
	_aura_material.shader = AURA_SHADER
	_aura_material.set_shader_parameter("glow", GLOW)
	shell.material = _aura_material
	_aura.mesh = shell
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_light.light_color = GLOW
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	add_child(_light)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func _ready() -> void:
	_base = global_position
	_resize()


## Seconds before it fades away.
func time_left() -> float:
	return settings.pearl_lifetime - age


func _physics_process(delta: float) -> void:
	if absorbing:
		_absorb(delta)
		return
	age += delta
	if age >= settings.pearl_lifetime:
		queue_free()
		return
	if not is_equal_approx(_size, settings.pearl_size):
		_resize()
	var nearest: FishController = null
	var gap := INF
	for fish in collectors:
		if not is_instance_valid(fish) or fish.battered:
			continue
		var d := fish.global_position.distance_to(global_position)
		if d < gap:
			gap = d
			nearest = fish
	if nearest and gap <= settings.absorb_radius:
		absorbing = nearest
		_absorb_left = ABSORB_TIME
		return
	if nearest and gap < settings.magnet_radius:
		# Keep up with the fish, and close in faster the nearer it is.
		var toward := (nearest.global_position - global_position) / gap
		var pull := settings.magnet_strength * (1.0 + 2.0 * (1.0 - gap / settings.magnet_radius))
		velocity = nearest.swim_velocity() + toward * pull
		_base += velocity * delta
	else:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-2.0 * delta))
		_base += velocity * delta
	_bob += delta * 1.4
	global_position = _base + Vector3(0.0, sin(_bob) * 0.12, 0.0)
	_set_strength(_fade())


## Streams into the fish, shrinking, then counts.
func _absorb(delta: float) -> void:
	_absorb_left -= delta
	var done := 1.0 - clampf(_absorb_left / ABSORB_TIME, 0.0, 1.0)
	if is_instance_valid(absorbing):
		global_position = global_position.lerp(absorbing.global_position, clampf(done * 1.5, 0.0, 1.0))
	scale = Vector3.ONE * (1.0 - done)
	_set_strength(1.0 + done)  # a last flare as it goes in
	if _absorb_left <= 0.0:
		collected.emit(self, absorbing)
		queue_free()


## 1 while fresh, flickering through its last seconds.
func _fade() -> float:
	var left := time_left()
	if left > FLICKER_TIME:
		return 1.0
	var flicker := 0.5 + 0.5 * signf(sin(age * lerpf(6.0, 22.0, 1.0 - left / FLICKER_TIME)))
	return lerpf(0.25, 1.0, flicker) * clampf(left / FLICKER_TIME * 1.5, 0.0, 1.0)


func _set_strength(amount: float) -> void:
	_aura_material.set_shader_parameter("strength", amount)
	_light.light_energy = 1.2 * amount
	_body.visible = amount > 0.05


func _resize() -> void:
	_size = settings.pearl_size
	_body.scale = Vector3.ONE * _size
	_aura.scale = Vector3.ONE * _size * 2.6
	_light.omni_range = maxf(_size * 14.0, 1.0)
