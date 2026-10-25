class_name Shrine
extends Node3D
## A sunken shrine (planning_unnatural.md, "Playability pass" P5): a fixed spot
## on the stage's seabed. Since planning_environment.md (Phase 3) each is a
## small ruined tholos: round steps, a ring of Doric columns (some broken, one
## fallen), a statue of its god on a plinth, and a bronze brazier burning in
## its kind's colour. Nothing about it shows through the murk from far off (no
## beam, its light obeys the fog); players find it by swimming near
## (`discovered`), and then it's on the minimap and compass. Swim over it and
## press Jump (UnnaturalRun.use_shrine()):
## - TIDE (Poseidon, a trident): hold its ring (shrine_tide_radius) for
##   shrine_tide_time s while the horde comes, and win a free chest;
## - CHANCE (Tyche, a cornucopia): pay pearls for a chance at an item;
## - DEEP (Hades, veiled, a bident): the stage gets harder (more elites), but
##   bosses drop more chests;
## - PEARLS (Aphrodite before a scallop shell, a pearl): every pearl out flies
##   to the team.
## A spent shrine's brazier goes cold. UnnaturalRun keeps its state; this draws it.

enum Kind { TIDE, CHANCE, DEEP, PEARLS }
const NAMES := ["Shrine of the Tide", "Shrine of Chance", "Shrine of the Deep", "Shrine of Pearls"]
const COLORS := [Color(0.3, 0.75, 1.0), Color(1.0, 0.8, 0.3), Color(0.65, 0.25, 1.0), Color(0.92, 0.95, 1.0)]
const GODS := ["poseidon", "tyche", "hades", "aphrodite"]
## The temple: its top step's radius, the column ring's, and the steps.
const STEP_RADIUS := 3.7
const COLUMN_RING := 3.15
const STEPS := 3
const RISE := 0.26
const PLINTH := Vector3(1.05, 0.95, 1.05)
## The brazier's spot (on the top step, in front of the statue) and its light.
const BRAZIER_AT := Vector3(0.0, 0.0, 2.0)
const LIGHT_RANGE := 7.0

var kind := Kind.TIDE
## Its place in the run's `shrines` (online's index).
var index := 0
## Used up for everyone (a Tide won, the Deep taken, the Pearls drawn).
var spent := false
## Found: a player has come within shrine_reveal_range, so it shows on the
## team's minimap and compass (planning_environment.md, E4).
var discovered := false
## Chance: tries per player (fish -> count).
var tries := {}
## Tide: running, the seconds held so far, and seconds to its next wave.
var tide_active := false
var tide_held := 0.0
var tide_wave_left := 0.0
## The Tide's ring's radius (m), set by the run.
var ring_radius := 8.0

## Each kind's temple (marble, bronze), built once.
static var _looks := {}

var _flames := CPUParticles3D.new()
var _embers := CPUParticles3D.new()
var _light := OmniLight3D.new()
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _age := 0.0


static func title(shrine_kind: int) -> String:
	return NAMES[shrine_kind]


static func color_of(shrine_kind: int) -> Color:
	return COLORS[shrine_kind]


func tint() -> Color:
	return COLORS[kind]


## The top step's height (m): where the brazier and plinth stand.
static func floor_height() -> float:
	return RISE * STEPS


func _ready() -> void:
	var look: Array = _look_of(kind)
	for n in look.size():
		var part := MeshInstance3D.new()
		part.name = ["Marble", "Bronze", "Pearl"][n]
		part.mesh = look[n]
		add_child(part)
	var top := floor_height()
	var bowl := BRAZIER_AT + Vector3(0.0, top + 1.07, 0.0)
	_flames.mesh = GreekFire.FirePatch._flame_mesh()
	_flames.amount = 14
	_flames.lifetime = 0.8
	_flames.lifetime_randomness = 0.4
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 0.18
	_flames.direction = Vector3.UP
	_flames.spread = 15.0
	_flames.initial_velocity_min = 0.3
	_flames.initial_velocity_max = 0.8
	_flames.gravity = Vector3(0.0, 1.4, 0.0)
	_flames.scale_amount_min = 0.55
	_flames.scale_amount_max = 0.95
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Color.WHITE.lerp(tint(), 0.35), 0.0))
	ramp.add_point(0.15, Color(Color.WHITE.lerp(tint(), 0.5), 0.75))
	ramp.add_point(0.55, Color(tint(), 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint().darkened(0.6), 0.0))
	_flames.color_ramp = ramp
	_flames.position = bowl
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flames)
	_embers.mesh = _ember_mesh()
	_embers.amount = 10
	_embers.lifetime = 2.5
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.25
	_embers.direction = Vector3.UP
	_embers.spread = 35.0
	_embers.initial_velocity_min = 0.2
	_embers.initial_velocity_max = 0.6
	_embers.gravity = Vector3(0.0, 0.25, 0.0)
	_embers.color = tint().lightened(0.3)
	_embers.position = bowl + Vector3.UP * 0.2
	add_child(_embers)
	_light.light_color = tint()
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.4
	_light.position = bowl + Vector3.UP * 0.5
	add_child(_light)
	# The Tide's ring: a band of light on the sand, round a curb of stones.
	_ring_material = FxKit.glow(Color(tint(), 0.0), FxKit.band())
	_ring = MeshInstance3D.new()
	_ring.name = "TideRing"
	_ring.mesh = FxKit.disc_mesh()
	_ring.material_override = _ring_material
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _process(delta: float) -> void:
	_age += delta
	var pulse := 0.5 + 0.5 * sin(_age * 2.2)
	_flames.emitting = not spent
	_embers.emitting = not spent
	_light.light_energy = 0.0 if spent else 1.6 + 0.5 * pulse + (1.5 if tide_active else 0.0)
	_ring.visible = tide_active
	if tide_active:
		_ring.scale = Vector3(ring_radius, 1.0, ring_radius)
		_ring_material.albedo_color = Color(tint(), 0.55 + 0.35 * pulse)


## Whether `point` is over it (anywhere up its column), within `reach` m.
func is_over(point: Vector3, reach: float) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= reach


## A kind's temple: [marble mesh, bronze mesh], built once.
static func _look_of(shrine_kind: int) -> Array:
	if _looks.has(shrine_kind):
		return _looks[shrine_kind]
	var seed_value := 4100 + shrine_kind * 97
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var stone := MeshKit.new()
	var metal := MeshKit.new()
	var gem := MeshKit.new()
	var top := floor_height()
	stone.merge(GreekKit.round_steps(STEP_RADIUS, STEPS, RISE, 0.45, seed_value))
	# Six columns with the front (+Z) between two of them. One is broken off
	# short and one has fallen outward down the steps.
	var broken := dice.randi_range(0, 5)
	var fallen := (broken + dice.randi_range(2, 4)) % 6
	var standing := PackedInt32Array()
	for n in 6:
		var angle := PI / 2.0 + PI / 6.0 + TAU * n / 6.0
		var at := Vector3(cos(angle), 0.0, sin(angle)) * COLUMN_RING + Vector3.UP * top
		if n == fallen:
			var lie := Basis(Vector3.UP, -angle)
			var piece := GreekKit.fallen_column(4, seed_value + n)
			stone.merge(piece, Transform3D(lie, Vector3(cos(angle), 0.0, sin(angle)) * (COLUMN_RING + 0.6) + Vector3.UP * top * 0.4))
			stone.merge(GreekKit.capital(GreekKit.COLUMN_RADIUS * 0.94, seed_value + n),
					Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, 1.2), Vector3(cos(angle), 0.0, sin(angle))
					* (COLUMN_RING + 4.6) + Vector3.UP * 0.3))
			continue
		var turn := Basis(Vector3.UP, dice.randf() * TAU)
		if n == broken:
			stone.merge(GreekKit.drum(dice.randf_range(1.2, 1.9), GreekKit.COLUMN_RADIUS, true, seed_value + n), Transform3D(turn, at))
			continue
		stone.merge(GreekKit.column(GreekKit.COLUMN_HEIGHT, seed_value + n), Transform3D(turn, at))
		standing.append(n)
	# The architrave, where two neighbours still stand (a piece of it slid off one).
	var beam_y := top + GreekKit.COLUMN_HEIGHT
	for n in standing:
		var next := (n + 1) % 6
		if next not in standing:
			continue
		var from := PI / 2.0 + PI / 6.0 + TAU * n / 6.0
		var span := TAU / 6.0
		stone.merge(GreekKit.ring_beam(COLUMN_RING, span + 0.08, 0.6, 0.6, dice.randf() < 0.4, seed_value + 50 + n),
				Transform3D(Basis(Vector3.UP, -from + 0.04), Vector3.UP * beam_y))
	# The plinth and the statue on it, facing out the front.
	var plinth := GreekKit.block(PLINTH, seed_value + 9)
	stone.merge(plinth, Transform3D(Basis(), Vector3.UP * top))
	var god: String = GODS[shrine_kind]
	var on := Vector3.UP * (top + PLINTH.y)
	stone.merge(GreekKit.statue(god, seed_value + 3), Transform3D(Basis(), on))
	var hand := on + GreekKit.hand_of(god)
	match god:
		"poseidon":
			metal.merge(GreekKit.trident(2.7, 3), Transform3D(Basis(), Vector3(hand.x, on.y, hand.z)))
		"hades":
			metal.merge(GreekKit.trident(2.4, 2), Transform3D(Basis(Vector3.BACK, -0.08), Vector3(hand.x - 0.05, on.y, hand.z)))
		"tyche":
			stone.merge(GreekKit.cornucopia(), Transform3D(Basis(Vector3.UP, -PI * 0.5), hand + Vector3(0.0, 0.08, 0.0)))
		"aphrodite":
			stone.merge(GreekKit.scallop(1.35), Transform3D(Basis(), on + Vector3(0.0, -0.05, -0.38)))
			gem.merge(GreekKit.pearl(0.075), Transform3D(Basis(), hand + Vector3(0.0, 0.02, 0.0)))
	# The brazier, and a few stones and a pot about the steps.
	metal.merge(GreekKit.brazier(1.05, 0.36), Transform3D(Basis(), BRAZIER_AT + Vector3.UP * top))
	for n in 4:
		var angle := dice.randf() * TAU
		var r := STEP_RADIUS + 0.9 + dice.randf() * 2.5
		var size := Vector3(dice.randf_range(0.4, 0.9), dice.randf_range(0.25, 0.45), dice.randf_range(0.35, 0.7))
		stone.merge(GreekKit.block(size, seed_value + 30 + n), Transform3D(Basis(Vector3.UP, dice.randf() * TAU)
				* Basis(Vector3.RIGHT, dice.randf_range(-0.25, 0.25)), Vector3(cos(angle) * r, -0.1, sin(angle) * r)))
	stone.merge(GreekKit.amphora(false, true, seed_value + 40), Transform3D(Basis(Vector3.FORWARD, 1.5) * Basis(Vector3.UP, dice.randf() * TAU),
			Vector3(-2.2, top + 0.2, 2.6)))
	var look := [stone.mesh(true, GreekKit.marble())]
	look.append(metal.mesh(true, GreekKit.bronze()))
	if not gem.verts.is_empty():
		var nacre := StandardMaterial3D.new()
		nacre.albedo_color = Color(0.96, 0.93, 0.95)
		nacre.roughness = 0.12
		nacre.clearcoat_enabled = true
		nacre.rim_enabled = true
		nacre.rim = 0.6
		nacre.emission_enabled = true
		nacre.emission = COLORS[shrine_kind]
		nacre.emission_energy_multiplier = 0.4
		look.append(gem.mesh(false, nacre))
	_looks[shrine_kind] = look
	return look


static var _ember: QuadMesh


## A tiny glowing speck for the brazier's sparks.
static func _ember_mesh() -> QuadMesh:
	if _ember == null:
		_ember = QuadMesh.new()
		_ember.size = Vector2(0.05, 0.05)
		var material := FxKit.glow(Color.WHITE, FxKit.dot())
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		_ember.material = material
	return _ember
