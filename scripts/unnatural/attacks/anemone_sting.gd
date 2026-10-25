class_name AnemoneSting
extends FishAttack
## The Clownfish's auto-attack (planning_unnatural.md §5): a stinging pulse
## all round it, like brushing an anemone. Every sting_cooldown seconds, if a
## zombie is within reach, a ring of tendrils lashes out and everything within
## radius() takes sting_damage, pushed away. It's melee, so the pulse always
## reaches further than the bow wave (sting_over_bow times it).
##
## As a weapon (Weapons): at its first milestone a second pulse (an echo, its
## own AnemoneSting) follows ECHO_AFTER s later, ECHO_SIZE times as big for
## ECHO_DAMAGE of the damage; at its second, every sting takes SLOW_SHARE of
## the zombie's speed; at its third, each pulse draws the zombies within
## PULL_REACH times its radius toward the fish (PULL_SPEED m/s); at its
## fourth, the echo has an echo of its own (a third pulse, bigger again).

## The pulse grows to full size, hurts there, then fades.
const GROW_TIME := 0.1
const FADE_TIME := 0.3
const TENDRILS := 18
const COLOR := Color(1.0, 0.45, 0.75, 0.55)
## It hits many at once.
const PROC := 0.6
const ECHO_AFTER := 0.15
const ECHO_SIZE := 1.5
const ECHO_DAMAGE := 0.5
const SLOW_SHARE := 0.6
const PULL_REACH := 2.0
const PULL_SPEED := 8.0

var is_echo := false
## 0: the pulse itself; 1: its echo; 2: the echo's echo (the fourth milestone).
var echo_depth := 0
var _echo: AnemoneSting
var _echo_left := -1.0
var _age := -1.0
var _shell := MeshInstance3D.new()
var _tendrils := MeshInstance3D.new()
## The pulse: a shell bright at its rim and clear face on (FxKit.rim), so from
## inside it (the camera often is) there's nothing in the way.
var _shell_material := FxKit.rim(COLOR, 0.02, 0.3, true)
## The tendrils: soft-edged, fading near the camera.
var _material := FxKit.glow(COLOR, FxKit.across(), true)


func _init() -> void:
	name = "AnemoneSting"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.material = _shell_material
	_shell.mesh = sphere
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	# Tendrils out in every direction (a Fibonacci sphere), each a wavy line
	# from 0.3 out to 1, narrowing to a point; all one mesh.
	var strands := []
	for t in TENDRILS:
		var y := 1.0 - 2.0 * (t + 0.5) / TENDRILS
		var ring := sqrt(1.0 - y * y)
		var angle := t * PI * (3.0 - sqrt(5.0))
		var out := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var side := out.cross(Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT).normalized()
		var line := PackedVector3Array()
		for k in 7:
			var s := k / 6.0
			line.append(out * lerpf(0.3, 1.0, s) + side * sin(s * TAU * 1.2 + t) * 0.06 * s)
		strands.append(line)
	_tendrils.mesh = FxKit.ribbons(strands, [0.045], true)
	_tendrils.mesh.surface_set_material(0, _material)
	_tendrils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tendrils)
	visible = false


func cooldown() -> float:
	return settings.sting_cooldown


func damage() -> float:
	return settings.sting_damage


func proc() -> float:
	return PROC


func size_weight() -> float:
	return settings.sting_size_weight if settings else 1.0


## The pulse's radius (m): sting_radius, or more if the bow wave reaches further.
func radius() -> float:
	return maxf(settings.sting_radius, GhostBite.bow_reach(fish) * settings.sting_over_bow) * size_scale


func busy() -> bool:
	return _age >= 0.0 and _age < GROW_TIME


func fire() -> bool:
	var at := origin()
	if horde.query_sphere(at, radius()).is_empty():
		return false
	pulse()
	if milestones >= 1 and not is_echo:
		_echo_left = ECHO_AFTER
	return true


## One pulse, now (an echo's, at the fourth milestone, has its own echo).
func pulse() -> void:
	_age = 0.0
	if echo_depth == 1 and milestones >= 4:
		_echo_left = ECHO_AFTER
	visible = true
	_place(0.0)


func _animate(delta: float) -> void:
	if is_instance_valid(_echo):
		_echo._animate(delta)
	if _echo_left >= 0.0:
		_echo_left -= delta
		if _echo_left < 0.0:
			_make_echo().pulse()
	if _age < 0.0:
		return
	var before := _age
	_age += delta
	if before < GROW_TIME and _age >= GROW_TIME:
		var at := origin()
		var stung := horde.query_sphere(at, radius())
		strike_area(stung, settings.sting_damage, at)
		if milestones >= 2:
			for i in stung:
				if horde.is_alive(i):
					horde.shove(i, -horde.enemy_velocity(i) * SLOW_SHARE)
		if milestones >= 3:
			for i in horde.query_sphere(at, radius() * PULL_REACH):
				var inward := at - horde.enemy_position(i)
				if inward.length_squared() > 0.01:
					horde.shove(i, inward.normalized() * PULL_SPEED)
	if _age >= GROW_TIME + FADE_TIME:
		_age = -1.0
		visible = false
		return
	_place(_age)


## The echo pulse, with this one's scales (bigger, softer).
func _make_echo() -> AnemoneSting:
	if not is_instance_valid(_echo):
		_echo = AnemoneSting.new()
		_echo.is_echo = true
		_echo.kind = kind  # its hits are the sting's (FishAttack.make sets kind; this one's made here)
		_echo.echo_depth = echo_depth + 1
		_echo.top_level = true
		_echo.fish = fish
		_echo.horde = horde
		_echo.settings = settings
		_echo.on_hit = on_hit
		add_child(_echo)
	_echo.size_scale = size_scale * ECHO_SIZE
	_echo.damage_scale = damage_scale * ECHO_DAMAGE
	_echo.knock_scale = knock_scale
	_echo.milestones = milestones
	return _echo


func _place(age: float) -> void:
	var grow := clampf(age / GROW_TIME, 0.0, 1.0)
	var size := radius() * (0.25 + 0.75 * (1.0 - (1.0 - grow) * (1.0 - grow)))
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size), origin())
	_tendrils.rotation.y = age * 3.0
	var fade := 1.0 - clampf((age - GROW_TIME) / FADE_TIME, 0.0, 1.0)
	_material.albedo_color = Color(COLOR, minf(COLOR.a * 1.6, 1.0) * fade * (0.35 + 0.65 * grow))
	_shell_material.set_shader_parameter("tint", Color(COLOR, COLOR.a * fade * (0.35 + 0.65 * grow)))
