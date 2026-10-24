class_name GhostBite
extends FishAttack
## The Shark's auto-attack in Unnatural (planning_unnatural.md §5, D8): huge
## spectral shark jaws, several times the fish's size, that snap shut on the
## zone in front of it. Aiming is hard in 3D water, so it's hugely
## exaggerated: the jaws always reach further than the bow wave at its
## biggest (bite_over_bow times it, bow wave powerups included), otherwise
## ramming would do the same job.
##
## Every bite_cooldown seconds, if a zombie is within reach and no more than
## bite_aim_cone off the nose, the jaws open toward the nearest such zombie and
## snap shut SNAP_TIME later: everything inside them (an ellipsoid reach long
## and twice bite_width wide) takes bite_damage, knocked away from the fish.
##
## As a weapon (Weapons) its milestones add echo jaws (more GhostBites of its
## own) that snap with it: at the first, behind the fish; at the second, at
## both sides too; at the third, above and below it too. At the fourth every
## bite snaps again AGAIN_AFTER s later.

## The jaws open, then snap shut (when it hurts), then fade.
const OPEN_TIME := 0.07
const SNAP_TIME := 0.16
const FADE_TIME := 0.32
## Teeth per jaw, and the horseshoe they sit on (degrees either side of the nose).
const TEETH := 11
const ARC := 115.0
const GHOST_COLOR := Color(0.6, 0.95, 1.0, 0.55)
const AGAIN_AFTER := 0.3

## Bites so far, and zombies bitten.
var bites := 0
var bitten := 0
## Second snaps (the fourth milestone), for the probes.
var snapped_again := 0

var _age := -1.0
var _aim := Vector3.FORWARD
var _snapped := false
## The milestones' echo jaws (made as they're needed), and whether this is one.
var _echoes: Array[GhostBite] = []
var is_echo := false
## The fourth milestone's second snap: s until it (-1: none to come).
var _again_left := -1.0
var _upper := MeshInstance3D.new()
var _lower := MeshInstance3D.new()
## The teeth: white-hot at their tips, fading toward the gum.
var _material := FxKit.glow(GHOST_COLOR, _tooth_glow())
## The gum: a soft glowing lip along the horseshoe.
var _gum_material := FxKit.glow(GHOST_COLOR, FxKit.across())

static var _tooth_texture: GradientTexture2D


func _init() -> void:
	name = "GhostBite"
	_material.cull_mode = BaseMaterial3D.CULL_BACK  # one side: both added up burn out to white
	# Unit jaws: a horseshoe 1 wide (each side) and 1 long, scaled to the
	# bite's size. Each jaw one mesh: its teeth and its gum.
	for jaw: MeshInstance3D in [_upper, _lower]:
		var down := jaw == _upper
		var teeth := []
		for t in TEETH:
			var along := lerpf(-ARC, ARC, (t + (0.0 if down else 0.5)) / (TEETH - (1.0 if down else 0.0)))
			var angle := deg_to_rad(clampf(along, -ARC, ARC))
			var length := 0.42 if absf(along) < 40.0 else 0.32  # fangs at the front
			# A cone, tip up (v 0 at the tip); the upper jaw's turned over to point down.
			var cone := CylinderMesh.new()
			cone.height = length
			cone.top_radius = 0.0
			cone.bottom_radius = 0.09
			cone.radial_segments = 6
			cone.rings = 1
			var at := Vector3(sin(angle), (-length if down else length) * 0.5, -0.45 - cos(angle) * 0.55)
			teeth.append([cone, Transform3D(Basis(Vector3.RIGHT, PI) if down else Basis(), at)])
		var mesh := ArrayMesh.new()
		FxKit.merge_into(mesh, teeth, _material)
		var gum := PackedVector3Array()
		for t in 25:
			var a := deg_to_rad(lerpf(-ARC, ARC, t / 24.0))
			gum.append(Vector3(sin(a), 0.0, -0.45 - cos(a) * 0.55))
		FxKit.merge_into(mesh, [[FxKit.ribbons([gum], [0.16]), Transform3D.IDENTITY]], _gum_material)
		jaw.mesh = mesh
		jaw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(jaw)
	visible = false


## Up a tooth (v): bright at its tip, faint at its root.
static func _tooth_glow() -> GradientTexture2D:
	if _tooth_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.85))
		gradient.set_color(1, Color(1, 1, 1, 0.12))
		_tooth_texture = GradientTexture2D.new()
		_tooth_texture.gradient = gradient
		_tooth_texture.fill_from = Vector2(0.5, 0.0)
		_tooth_texture.fill_to = Vector2(0.5, 1.0)
		_tooth_texture.width = 1
		_tooth_texture.height = 16
	return _tooth_texture


## How far ahead of the hitbox's middle the jaws reach (m): bite_reach, or
## more if the bow wave reaches further.
func reach() -> float:
	return maxf(settings.bite_reach, bow_reach(fish) * settings.bite_over_bow) * size_scale


## The jaws' half-width (m), likewise against the bow wave's.
func half_width() -> float:
	return maxf(settings.bite_width, bow_half_width(fish) * settings.bite_over_bow) * size_scale


## How far ahead of the hitbox's middle `of`'s bow wave reaches at its biggest (m).
static func bow_reach(of: FishController) -> float:
	var half := of.hitbox_length * 0.5
	return half + (of.bow_length * of.bow_scale if of.bow_wave else Battery.REACH)


## Its bow wave's half-width at its biggest (m).
static func bow_half_width(of: FishController) -> float:
	var half := of.hitbox_width * 0.5
	return half * (of.bow_girth * of.bow_scale if of.bow_wave else 1.0)


func cooldown() -> float:
	return settings.bite_cooldown


func damage() -> float:
	return settings.bite_damage


## Counts down, aims, bites and animates; `active` false holds it (down,
## picking a card).
func update(delta: float, active := true) -> void:
	_animate(delta)
	cooldown_left = maxf(cooldown_left - delta * attack_speed, 0.0)
	if not active or cooldown_left > 0.0 or _age >= 0.0 or fish.battered or settings.bite_damage <= 0.0:
		return
	var nose := -fish.global_basis.z
	var target := aim_target()
	if target < 0:
		return
	var toward := horde.enemy_position(target) - origin()
	start(toward.normalized() if toward.length_squared() > 0.0001 else nose)


## The nearest zombie within reach and bite_aim_cone of the nose.
func aim_target() -> int:
	return horde.nearest_in_cone(origin(), -fish.global_basis.z, reach(), cos(deg_to_rad(settings.bite_aim_cone)))


## Opens the jaws toward `direction` (unit); they snap shut SNAP_TIME later.
## `again`: the fourth milestone's second snap (which doesn't ask for a third).
func start(direction: Vector3, again := false) -> void:
	if not is_echo and milestones >= 4 and not again:
		_again_left = AGAIN_AFTER
	_aim = direction
	_age = 0.0
	_snapped = false
	cooldown_left = settings.bite_cooldown
	bites += 1
	uses += 0 if again else 1
	snapped_again += 1 if again else 0
	if not again and not is_echo:
		fired.emit()
	visible = true
	_place(0.0)
	if is_echo or milestones <= 0:
		return
	var side := direction.cross(fish.global_basis.y)
	side = side.normalized() if side.length_squared() > 0.0001 else fish.global_basis.x
	var aims: Array[Vector3] = [-direction]
	if milestones >= 2:
		aims.append(side)
		aims.append(-side)
	if milestones >= 3:
		var above := side.cross(direction).normalized()
		aims.append(above)
		aims.append(-above)
	for n in aims.size():
		_echo(n).start(aims[n])


## Echo jaw `n`, made the first time, with this bite's sizes and scales.
func _echo(n: int) -> GhostBite:
	while _echoes.size() <= n:
		var echo := GhostBite.new()
		echo.is_echo = true
		echo.top_level = true
		echo.fish = fish
		echo.horde = horde
		echo.settings = settings
		echo.on_hit = on_hit
		add_child(echo)
		_echoes.append(echo)
	var echo := _echoes[n]
	echo.size_scale = size_scale
	echo.damage_scale = damage_scale
	echo.knock_scale = knock_scale
	return echo


## Every zombie inside the jaws now (a slightly fuller ellipsoid than the
## horseshoe, the zombies' own size counting).
func zone_hits() -> PackedInt32Array:
	var found := PackedInt32Array()
	var length := reach()
	var width := half_width()
	var at := origin()
	var centre := at + _aim * length * 0.45
	var along_half := length * 0.55
	for i in horde.query_sphere(centre, maxf(along_half, width)):
		var offset := horde.enemy_position(i) - centre
		var r := horde.enemy_radius(i)
		var along := offset.dot(_aim)
		var side := (offset - _aim * along).length()
		var a := along / (along_half + r)
		var s := side / (width + r)
		if a * a + s * s <= 1.0:
			found.append(i)
	return found


func _animate(delta: float) -> void:
	for echo in _echoes:
		echo._animate(delta)
	if _again_left >= 0.0:
		_again_left -= delta
		if _again_left < 0.0:
			start(_aim, true)
	if _age < 0.0:
		return
	_age += delta
	if not _snapped and _age >= SNAP_TIME:
		_snapped = true
		var hits := zone_hits()
		bitten += hits.size()
		for i in hits:
			var push := horde.enemy_position(i) - origin()
			strike(i, settings.bite_damage, push.normalized() if push.length_squared() > 0.0001 else _aim)
	if _age >= SNAP_TIME + FADE_TIME:
		_age = -1.0
		visible = false
		return
	_place(_age)


## The jaws at `age` s into a bite: round the fish's nose, aimed, open then shut.
func _place(age: float) -> void:
	var width := half_width()
	var length := reach()
	var up := Vector3.UP if absf(_aim.y) < 0.98 else Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(_aim, up) * Basis.from_scale(Vector3(width, width * 0.8, length)), origin())
	var opening := clampf(age / OPEN_TIME, 0.0, 1.0)
	var shut := clampf((age - OPEN_TIME) / (SNAP_TIME - OPEN_TIME), 0.0, 1.0)
	var gap := 0.75 * opening * (1.0 - shut * shut)
	_upper.position.y = gap
	_lower.position.y = -gap
	_upper.rotation.x = -0.5 * gap
	_lower.rotation.x = 0.5 * gap
	var fade := 1.0 - clampf((age - SNAP_TIME) / FADE_TIME, 0.0, 1.0)
	_material.albedo_color = Color(GHOST_COLOR, GHOST_COLOR.a * opening * fade)
	_gum_material.albedo_color = Color(GHOST_COLOR, GHOST_COLOR.a * 0.8 * opening * fade)
