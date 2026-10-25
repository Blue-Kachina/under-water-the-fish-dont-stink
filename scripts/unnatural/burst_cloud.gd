class_name BurstCloud
extends Node3D
## What a Bloated Boxfish leaves when it dies (planning_unnatural.md §3): a
## sickly cloud that swells out to `radius` and hurts any player inside it
## (UnnaturalRun checks contains()) until it fades after `lifetime` seconds.
## Elite modifiers (P5) use it too: a Burning elite's fire patches, and an
## Electric one's shock, which `delay`s (a faint shell showing where, doing
## nothing) before it goes off.
##
## Its look (planning_environment.md, Phase 6) follows what it is (`style`,
## from its cause when left at AUTO): FIRE is tongues of flame and embers
## through it, SHOCK a cage of arcs crackling over it (flickering faster as
## it nears going off, then a flash), HAZE soft billowing puffs. Each has a
## faint rim at its true radius, so the edge of the danger reads.

enum Style { AUTO, FIRE, SHOCK, HAZE }

const SWELL_TIME := 0.25
const COLOR := Color(0.55, 0.75, 0.2, 0.32)
## Arcs over a shock's shell, and how often they're redrawn (s).
const ARCS := 7
const ARC_EVERY := 0.07

var radius := 3.5
var lifetime := 2.5
var age := 0.0
## What a touch does (-1: the run's burst_damage), its colour, and what the run log calls it.
var damage := -1.0
var color := COLOR
var cause := "a burst cloud"
## Seconds before it can hurt (lifetime counts from when it does).
var delay := 0.0
## Whether it slows a player in it too (a hagfish's slime: UnnaturalRun chills them).
var slows := false
var style := Style.AUTO

var _shell := MeshInstance3D.new()
var _shell_material: ShaderMaterial
var _puffs := CPUParticles3D.new()
var _arcs := MeshInstance3D.new()
var _arc_left := 0.0
var _dice := RandomNumberGenerator.new()
var _went_off := false

static var _puff_mesh: QuadMesh
static var _arc_material: StandardMaterial3D


func _ready() -> void:
	if style == Style.AUTO:
		style = Style.FIRE if "fire" in cause else (Style.SHOCK if "shock" in cause else Style.HAZE)
	_dice.randomize()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_shell.mesh = sphere
	_shell_material = FxKit.rim(Color(color, 0.0), 0.0, 0.0, true)
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	match style:
		Style.FIRE:
			_puffs.mesh = GreekFire.FirePatch._flame_mesh()
			_puffs.amount = 26
			_puffs.lifetime = 0.7
			_puffs.lifetime_randomness = 0.4
			_puffs.direction = Vector3.UP
			_puffs.spread = 25.0
			_puffs.initial_velocity_min = 0.4
			_puffs.initial_velocity_max = 1.0
			_puffs.gravity = Vector3(0.0, 1.8, 0.0)
			_puffs.color_ramp = GreekFire.FirePatch._ramp
			_puffs.scale_amount_min = 1.4
			_puffs.scale_amount_max = 2.6
		Style.SHOCK:
			_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arcs.material_override = _arc_glow()
			add_child(_arcs)
			_puffs.mesh = _puff()
			_puffs.amount = 6
			_puffs.lifetime = 0.3
			_puffs.gravity = Vector3.ZERO
			_puffs.initial_velocity_min = 0.0
			_puffs.initial_velocity_max = 0.0
			_puffs.color = Color(color.lightened(0.5), 0.5)
			_puffs.scale_amount_min = 1.5
			_puffs.scale_amount_max = 3.0
		_:
			_puffs.mesh = _puff()
			_puffs.amount = 14
			_puffs.lifetime = 1.6
			_puffs.lifetime_randomness = 0.3
			_puffs.direction = Vector3.UP
			_puffs.spread = 180.0
			_puffs.initial_velocity_min = 0.1
			_puffs.initial_velocity_max = 0.4
			_puffs.gravity = Vector3(0.0, 0.15, 0.0)
			_puffs.angle_min = -180.0
			_puffs.angle_max = 180.0
			var ramp := Gradient.new()
			ramp.set_color(0, Color(color, 0.0))
			ramp.add_point(0.25, Color(color.lightened(0.15), 0.5))
			ramp.add_point(0.7, Color(color, 0.35))
			ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
			_puffs.color_ramp = ramp
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.5))
			grow.add_point(Vector2(1.0, 1.0))
			_puffs.scale_amount_curve = grow
			_puffs.scale_amount_min = 2.4
			_puffs.scale_amount_max = 3.6
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puffs.local_coords = true
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puffs.emitting = delay <= 0.0 or style == Style.SHOCK
	add_child(_puffs)
	_place()


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay = maxf(delay - delta, 0.0)
		_place()
		return
	if not _went_off and style == Style.SHOCK:
		_went_off = true
		PowerupFx.shock(get_parent(), global_position, radius, color.lightened(0.4))
		PowerupFx.flash(get_parent(), global_position, radius * 0.8, color.lightened(0.6))
	age += delta
	if age >= lifetime:
		queue_free()
		return
	_place()


func _process(delta: float) -> void:
	if style != Style.SHOCK or not is_inside_tree():
		return
	_arc_left -= delta * (1.0 + 3.0 / maxf(delay, 0.25) if delay > 0.0 else 2.0)
	if _arc_left <= 0.0:
		_arc_left = ARC_EVERY
		_draw_arcs()


## Whether `point` is inside it now (`margin` m of grace for the player's size).
func contains(point: Vector3, margin := 0.0) -> bool:
	return delay <= 0.0 and age < lifetime and global_position.distance_to(point) <= current_radius() + margin


func current_radius() -> float:
	return radius * clampf(age / SWELL_TIME, 0.15, 1.0)


func _place() -> void:
	var tint := Color(color, 1.0)
	if delay > 0.0:
		# Armed: a faint shell at its full size, its arcs crackling faster as it nears.
		_shell.scale = Vector3.ONE * radius
		_shell_material.set_shader_parameter("tint", Color(tint, 0.2 + 0.15 * sin(Time.get_ticks_msec() * 0.03 / maxf(delay, 0.1))))
		_puffs.emission_sphere_radius = radius * 0.7
		return
	var r := maxf(current_radius(), 0.05)
	var fade := 1.0 - clampf((age - lifetime * 0.6) / (lifetime * 0.4), 0.0, 1.0)
	_shell.scale = Vector3.ONE * r
	_shell_material.set_shader_parameter("tint", Color(tint, 0.35 * fade))
	_puffs.emission_sphere_radius = r * (0.55 if style == Style.FIRE else 0.6)
	_puffs.emitting = fade > 0.3
	if style == Style.SHOCK:
		_arcs.visible = fade > 0.05
		_arcs.transparency = 1.0 - fade


## New arcs: jagged lines between random points on the shell, crossed ribbons.
func _draw_arcs() -> void:
	var r := radius if delay > 0.0 else maxf(current_radius(), 0.05)
	var strands := []
	var widths := []
	for n in ARCS:
		var a := Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-1, 1), _dice.randf_range(-1, 1)).normalized() * r
		var b := (a + Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-1, 1), _dice.randf_range(-1, 1)) * r * 0.9).normalized() * r
		strands.append(FxKit.jagged(a, b, 6, r * 0.08, _dice, (a + b).normalized() * r * 0.15))
		widths.append(0.06 + 0.04 * _dice.randf())
	_arcs.mesh = FxKit.ribbons(strands, widths, true)


static func _puff() -> QuadMesh:
	if _puff_mesh == null:
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2.ONE
		var material := FxKit.glow(Color.WHITE, FxKit.dot(), true)
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		_puff_mesh.material = material
	return _puff_mesh


static func _arc_glow() -> StandardMaterial3D:
	if _arc_material == null:
		_arc_material = FxKit.glow(Color(0.7, 0.9, 1.0), FxKit.across(), true)
	return _arc_material
