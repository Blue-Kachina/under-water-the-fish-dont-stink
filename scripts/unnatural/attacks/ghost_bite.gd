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

## The jaws open, then snap shut (when it hurts), then fade.
const OPEN_TIME := 0.07
const SNAP_TIME := 0.16
const FADE_TIME := 0.32
## Teeth per jaw, and the horseshoe they sit on (degrees either side of the nose).
const TEETH := 11
const ARC := 115.0
const GHOST_COLOR := Color(0.6, 0.95, 1.0, 0.7)

## Bites so far, and zombies bitten.
var bites := 0
var bitten := 0

var _age := -1.0
var _aim := Vector3.FORWARD
var _snapped := false
var _upper := Node3D.new()
var _lower := Node3D.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	name = "GhostBite"
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = GHOST_COLOR
	add_child(_upper)
	add_child(_lower)
	# Unit jaws: a horseshoe 1 wide (each side) and 1 long, scaled to the bite's size.
	for jaw: Node3D in [_upper, _lower]:
		var down := jaw == _upper
		for t in TEETH:
			var along := lerpf(-ARC, ARC, (t + (0.0 if down else 0.5)) / (TEETH - (1.0 if down else 0.0)))
			var angle := deg_to_rad(clampf(along, -ARC, ARC))
			var tooth := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			var length := 0.42 if absf(along) < 40.0 else 0.32  # fangs at the front
			cone.height = length
			cone.top_radius = 0.09 if down else 0.0
			cone.bottom_radius = 0.0 if down else 0.09
			cone.radial_segments = 6
			cone.rings = 1
			cone.material = _material
			tooth.mesh = cone
			tooth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tooth.position = Vector3(sin(angle), (-length if down else length) * 0.5, -0.45 - cos(angle) * 0.55)
			jaw.add_child(tooth)
		# The gum: a thin bar along the horseshoe.
		for t in TEETH - 1:
			var a := deg_to_rad(lerpf(-ARC, ARC, float(t) / (TEETH - 1)))
			var b := deg_to_rad(lerpf(-ARC, ARC, float(t + 1) / (TEETH - 1)))
			var from := Vector3(sin(a), 0.0, -0.45 - cos(a) * 0.55)
			var to := Vector3(sin(b), 0.0, -0.45 - cos(b) * 0.55)
			var gum := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.07, 0.07, from.distance_to(to) + 0.02)
			bar.material = _material
			gum.mesh = bar
			gum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gum.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
			jaw.add_child(gum)
	visible = false


## How far ahead of the hitbox's middle the jaws reach (m): bite_reach, or
## more if the bow wave reaches further.
func reach() -> float:
	return maxf(settings.bite_reach, bow_reach(fish) * settings.bite_over_bow) * area_scale


## The jaws' half-width (m), likewise against the bow wave's.
func half_width() -> float:
	return maxf(settings.bite_width, bow_half_width(fish) * settings.bite_over_bow) * area_scale


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
	var target := horde.nearest_in_cone(origin(), nose, reach(), cos(deg_to_rad(settings.bite_aim_cone)))
	if target < 0:
		return
	var toward := horde.enemy_position(target) - origin()
	start(toward.normalized() if toward.length_squared() > 0.0001 else nose)


## Opens the jaws toward `direction` (unit); they snap shut SNAP_TIME later.
func start(direction: Vector3) -> void:
	_aim = direction
	_age = 0.0
	_snapped = false
	cooldown_left = settings.bite_cooldown
	bites += 1
	uses += 1
	visible = true
	_place(0.0)


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
