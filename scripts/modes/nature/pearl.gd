class_name Pearl
extends Node3D
## A pearl a battered fish left behind in Nature (NatureRun): a small glowing,
## iridescent bead with an aura and a light of its own, bobbing where the fish
## was. Swim over it, or just close by: within magnet_radius it's drawn to the
## nearest player's fish (keeping up with it, and faster the nearer it gets),
## and within absorb_radius it's absorbed, streaming into the fish (collected).
## Left alone, it flickers through its last seconds and fades.
##
## Values come from NatureSettings, live. In Nature pearls are only counted;
## in Unnatural (UnnaturalRun) they're XP pearls, worth `value` XP, and with
## hundreds out their lights go off (set_light()).

signal collected(pearl: Pearl, by: FishController)

const AURA_SHADER := preload("res://shaders/pearl_aura.gdshader")
const COLOR := Color(0.93, 0.95, 1.0)
const GLOW := Color(0.75, 0.9, 1.0)
## How long the absorbing takes (s), and the flicker before it fades (s).
const ABSORB_TIME := 0.3
const FLICKER_TIME := 3.0
## A pearl with no fish within twice its pull rests this many ticks between looks.
const SLEEP_TICKS := 7

var settings: NatureSettings
## Its number in the run (NatureRun), the same on every machine in co-op; -1: not the run's.
var id := -1
## Fish that can collect it (the players').
var collectors: Array[FishController] = []
var age := 0.0
var velocity := Vector3.ZERO
## Being absorbed into this fish (null: not yet).
var absorbing: FishController
## What it's worth (Unnatural's XP).
var value := 1.0
## How much bigger than pearl_size it is (Unnatural: drops merged into it).
var bulk := 1.0
## Flying to this fish wherever it is, as if in its pickup range (Unnatural's
## Magnet); null: the nearest collector in range.
var drawn_by: FishController

## One bead and one aura mesh for every pearl (the aura's strength is per
## pearl, an instance uniform), so hundreds out cost little more than one.
static var _bead: SphereMesh
static var _shell: SphereMesh

var _body := MeshInstance3D.new()
var _aura := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _absorb_left := 0.0
var _base := Vector3.ZERO
var _bob := randf() * TAU
var _size := 0.0
var _strength := -1.0
## Ticks left resting (no fish near: hundreds out cost little).
var _sleep := 0


func _init(pearl_settings: NatureSettings) -> void:
	settings = pearl_settings
	_make_meshes()
	_body.mesh = _bead
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_aura.mesh = _shell
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_light.light_color = GLOW
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	add_child(_light)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


static func _make_meshes() -> void:
	if _bead:
		return
	_bead = SphereMesh.new()
	_bead.radial_segments = 20
	_bead.rings = 10
	_bead.radius = 1.0
	_bead.height = 2.0
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
	_bead.material = pearly
	_shell = SphereMesh.new()
	_shell.radial_segments = 20
	_shell.rings = 10
	_shell.radius = 1.0
	_shell.height = 2.0
	var aura := ShaderMaterial.new()
	aura.shader = AURA_SHADER
	aura.set_shader_parameter("glow", GLOW)
	_shell.material = aura


func _ready() -> void:
	_base = global_position
	_resize()


## Its own light on or off (the glow and aura stay).
func set_light(on: bool) -> void:
	_light.visible = on


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
	if _sleep > 0 and drawn_by == null:
		_sleep -= 1
		return
	if not is_equal_approx(_size, settings.pearl_size * bulk):
		_resize()
	var nearest: FishController = null
	var gap := INF
	var reach := settings.magnet_radius
	if is_instance_valid(drawn_by) and not drawn_by.battered:
		nearest = drawn_by
		gap = drawn_by.global_position.distance_to(global_position)
		reach = maxf(gap + 1.0, reach)
	for fish in collectors:
		if nearest == drawn_by and nearest != null:
			break
		if not is_instance_valid(fish) or fish.battered:
			continue
		var d := fish.global_position.distance_to(global_position)
		if d < gap:
			gap = d
			nearest = fish
	if nearest and gap <= settings.absorb_radius * maxf(bulk, 1.0):
		absorbing = nearest
		_absorb_left = ABSORB_TIME
		return
	if nearest and gap < reach:
		# Keep up with the fish, and close in faster the nearer it is.
		var toward := (nearest.global_position - global_position) / gap
		var pull := settings.magnet_strength * (1.0 + 2.0 * (1.0 - gap / reach))
		if nearest == drawn_by:
			pull = maxf(pull, settings.magnet_strength * 3.0)
		velocity = nearest.swim_velocity() + toward * pull
		_base += velocity * delta
	else:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-2.0 * delta))
		_base += velocity * delta
		if gap > reach * 2.0 and velocity.length_squared() < 0.01 and _fade() >= 1.0:
			_sleep = SLEEP_TICKS  # nobody near: it only looks again now and then
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
	if is_equal_approx(amount, _strength):
		return
	_strength = amount
	_aura.set_instance_shader_parameter("strength", amount)
	_light.light_energy = 1.2 * amount
	_body.visible = amount > 0.05


func _resize() -> void:
	_size = settings.pearl_size * bulk
	_body.scale = Vector3.ONE * _size
	_aura.scale = Vector3.ONE * _size * 2.6
	_light.omni_range = maxf(_size * 14.0, 1.0)
