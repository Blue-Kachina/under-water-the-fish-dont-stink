class_name TreasureChest
extends Node3D
## A chest in Unnatural's seabed (planning_unnatural.md §7, D4; round 2):
## buried half sunk in the sand, or dropped by a kill and sinking to it. Found
## by its faint glow and the bubbles rising from it (and the HUD's ping, near
## enough). UnnaturalRun opens it when a player batters it or holds still
## beside it.
##
## Every chest is every player's: each opens it for themselves (opened_by) and
## gets their own pick. Once you've opened it, it's gone from your view: in
## split-screen each player's camera sees its own render layer
## (view_mask()), and the shut chest shows only on the layers of the local
## players who haven't opened it. The opener sees its lid pop open with a
## flash (a copy of it on their layer alone), then it's gone.

const GOLD := Color(1.0, 0.78, 0.25)
## A cursed chest's blood red, and a boss chest's steel blue (D13).
const BLOOD := Color(0.9, 0.06, 0.1)
const STEEL := Color(0.5, 0.8, 1.0)

## A treasure chest offers powerups by a rolled rarity; a cursed one (blood
## red, rarer) cursed powerups; a boss's chest (steel blue) its own `item`.
enum Kind { TREASURE, CURSED, BOSS }
const WOOD := Color(0.32, 0.18, 0.08)
const SIZE := Vector3(1.4, 0.9, 0.95)
## Render layers 17-20: one per local player (their slot).
const PLAYER_LAYERS := 0xF << 16
## How fast a dropped chest sinks to the seabed (m/s).
const SINK_SPEED := 8.0
const OPEN_TIME := 1.5

var kind := Kind.TREASURE
## A boss chest's powerup.
var item := ""
## The players who've opened it (puppets too, online).
var opened_by: Array[FishController] = []
## A dropped chest sinks to this height; -INF: it's where it's meant to be.
var sink_to := -INF

var _progress := {}
## The player layers it still shows on, shut.
var _shown := PLAYER_LAYERS
var _shut := Node3D.new()
var _lid: Node3D
var _light := OmniLight3D.new()
var _bubbles := CPUParticles3D.new()
var _glow := StandardMaterial3D.new()
var _age := 0.0


## The render layer of local player `index` (their slot, 0..3).
static func player_layer(index: int) -> int:
	return 1 << (16 + clampi(index, 0, 3))


## A camera's cull mask for local player `index`: everything but the other
## players' layers.
static func view_mask(index: int) -> int:
	return (0xFFFFF & ~PLAYER_LAYERS) | player_layer(index)


static func _wood() -> StandardMaterial3D:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.8
	return wood


## Its trim and glow: gold, blood red or steel blue.
func tint() -> Color:
	match kind:
		Kind.CURSED:
			return BLOOD
		Kind.BOSS:
			return STEEL
	return GOLD


func _ready() -> void:
	_glow.albedo_color = tint()
	_glow.metallic = 0.8
	_glow.roughness = 0.3
	_glow.emission_enabled = true
	_glow.emission = tint()
	_glow.emission_energy_multiplier = 1.2
	add_child(_shut)
	_lid = _build(_shut, _glow)
	_light.light_color = tint()
	_light.light_energy = 1.0
	_light.omni_range = 5.0
	_light.position.y = 1.2
	_shut.add_child(_light)
	_bubbles.amount = 16
	_bubbles.lifetime = 4.0
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(SIZE.x * 0.4, 0.1, SIZE.z * 0.4)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 12.0
	_bubbles.gravity = Vector3(0.0, 1.2, 0.0)
	_bubbles.initial_velocity_min = 0.6
	_bubbles.initial_velocity_max = 1.4
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.4
	var bubble := SphereMesh.new()
	bubble.radius = 0.05
	bubble.height = 0.1
	bubble.radial_segments = 6
	bubble.rings = 3
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_color = Color(0.85, 0.95, 1.0, 0.5)
	bubble.material = foam
	_bubbles.mesh = bubble
	_bubbles.position.y = SIZE.y
	_shut.add_child(_bubbles)
	_set_layers(_shut, _shown)


## The chest's body, bands and lid under `root`; returns the lid's hinge.
func _build(root: Node3D, glow: StandardMaterial3D) -> Node3D:
	var wood := _wood()
	var body := _box(Vector3(SIZE.x, SIZE.y * 0.6, SIZE.z), wood)
	body.position.y = SIZE.y * 0.3
	root.add_child(body)
	for x: float in [-0.5, 0.5]:
		var band := _box(Vector3(0.1, SIZE.y * 0.62, SIZE.z + 0.04), glow)
		band.position = Vector3(x * SIZE.x * 0.7, SIZE.y * 0.3, 0.0)
		root.add_child(band)
	var hinge := Node3D.new()
	hinge.position = Vector3(0.0, SIZE.y * 0.6, -SIZE.z * 0.5)  # hinged at the back
	root.add_child(hinge)
	var lid := _box(Vector3(SIZE.x, SIZE.y * 0.35, SIZE.z), wood)
	lid.position = Vector3(0.0, SIZE.y * 0.175, SIZE.z * 0.5)
	hinge.add_child(lid)
	var lock := _box(Vector3(0.22, 0.25, 0.08), glow)
	lock.position = Vector3(0.0, 0.0, SIZE.z + 0.03)
	hinge.add_child(lock)
	return hinge


func is_open_for(fish: FishController) -> bool:
	return fish in opened_by


## Whether everyone in `players` has opened it.
func open_for_all(players: Array[FishController]) -> bool:
	for fish in players:
		if is_instance_valid(fish) and fish not in opened_by:
			return false
	return true


## How far `fish` is through opening it by holding still (0..1), for the HUD.
func progress_of(fish: FishController) -> float:
	return _progress.get(fish, 0.0)


func set_progress(fish: FishController, amount: float) -> void:
	if amount <= 0.0:
		_progress.erase(fish)
	else:
		_progress[fish] = amount


## `fish` opens it (false: it already had). `layer`: the opener's render layer
## when they're a local player (0: someone elsewhere), who sees the lid pop
## open, and then no more of it.
func open_for(fish: FishController, layer := 0) -> bool:
	if fish in opened_by:
		return false
	opened_by.append(fish)
	_progress.erase(fish)
	if layer != 0 and is_inside_tree():
		_shown &= ~layer
		_set_layers(_shut, _shown)
		_shut.visible = _shown != 0
		_play_opening(layer)
	return true


## Gone for good (everyone's opened it, or it's no more on the host).
func vanish() -> void:
	_shown = 0
	_shut.visible = false
	var timer := get_tree().create_timer(OPEN_TIME + 0.2) if is_inside_tree() else null
	if timer:
		timer.timeout.connect(queue_free)
	else:
		queue_free()


## A copy of it on `layer` alone, its lid popping open with a flash, then gone.
func _play_opening(layer: int) -> void:
	var copy := Node3D.new()
	copy.name = "Opening"
	var glow := _glow.duplicate() as StandardMaterial3D
	add_child(copy)
	var hinge := _build(copy, glow)
	var light := OmniLight3D.new()
	light.light_color = tint()
	light.omni_range = 6.0
	light.position.y = 1.2
	copy.add_child(light)
	_set_layers(copy, layer)
	Explosion.spawn(get_parent(), global_position + Vector3.UP, tint(), 2.5, 0.0, 0.4)
	var tween := copy.create_tween()
	tween.tween_method(func(t: float) -> void:
		hinge.rotation.x = -1.9 * clampf(t / 0.35 * OPEN_TIME, 0.0, 1.0)
		var fade := clampf(1.0 - t, 0.0, 1.0)
		light.light_energy = 3.0 * fade
		glow.emission_energy_multiplier = 0.2 + 2.0 * fade
		copy.scale = Vector3.ONE * (1.0 if t < 0.6 else lerpf(1.0, 0.01, (t - 0.6) / 0.4)), 0.0, 1.0, OPEN_TIME)
	tween.tween_callback(copy.queue_free)


func _process(delta: float) -> void:
	_age += delta
	if sink_to > -INF and position.y > sink_to:
		position.y = maxf(position.y - SINK_SPEED * delta, sink_to)
	if _shown == 0:
		return
	var most := 0.0
	for fish: FishController in _progress:
		most = maxf(most, _progress[fish])
	var pulse := 0.75 + 0.25 * sin(_age * 2.2)
	_light.light_energy = (1.0 + 2.0 * most) * pulse
	_glow.emission_energy_multiplier = (1.0 + 2.0 * most) * pulse
	_lid.rotation.x = -0.25 * most + 0.03 * sin(_age * 9.0) * most


static func _set_layers(node: Node, mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = mask
	for child in node.get_children():
		_set_layers(child, mask)


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	return mesh
