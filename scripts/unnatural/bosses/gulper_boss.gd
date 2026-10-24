class_name GulperBoss
extends BloodLeviathan
## The Gulper Mother, an alternate final boss: a giant gulper eel, almost all
## mouth, its stretched belly showing what it has swallowed, a glowing lure on
## its whip tail. It fights as the King does (circle, spit, fury), and:
## - every gulper_every s (not in fury) it opens wide and draws in the zombies
##   within gulper_range of its mouth, swallowing up to gulper_max, each healing
##   it gulper_heal of its max hp (its belly fills);
## - spitting, it vomits gulper_vomit zombies at its target with its bile;
## - in fury it charges mouth open, and a player it reaches is swallowed (held
##   in its mouth, drained) until they stride their way out.

const GULPER_SKIN := preload("res://shaders/boss_gulper.gdshader")
## A gulp: how long the mouth stays open (s), and how near the mouth (m, of
## its girth) a zombie is swallowed.
const GULP_TIME := 2.0
const SWALLOW_REACH := 0.75

## Zombies swallowed this fight, and in the gulp on now.
var swallowed := 0
var gulps := 0
var _gulp_left := 0.0
var _open_left := 0.0
var _in_gulp := 0
var _gape := 0.0
var _lure_light: OmniLight3D


func boss_title() -> String:
	return "THE GULPER MOTHER"


func boss_line() -> String:
	return "IT SWALLOWS THE DEAD WHOLE"


func net_kind() -> String:
	return "gulper"


func body_length() -> float:
	return settings.leviathan_segments * settings.leviathan_girth * 1.1


func mouth_length() -> float:
	return 17.0 * settings.leviathan_girth / 6.0


func proxy_distance(n: int) -> float:
	var lm := mouth_length()
	if n == 0:
		return lm * 0.35
	if n == 1:
		return lm * 0.85
	return lm + (n - 2) / maxf(proxy_count() - 3, 1) * (body_length() * 0.72 - lm)


func proxy_radius(n: int) -> float:
	var k := settings.leviathan_girth / 6.0
	if n == 0:
		return 6.0 * k
	if n == 1:
		return 4.4 * k
	var t := float(n - 2) / maxf(proxy_count() - 3, 1)
	return lerpf(3.4, 0.9, t) * k


func _pose_parts() -> void:
	var k := settings.leviathan_girth / 6.0
	for n in parts.size():
		var drop := -2.6 * k if n == 0 else (-1.2 * k if n <= 2 else 0.0)
		var at := rig.place(Vector3(0.0, drop, proxy_distance(n)))
		run.horde.place(parts[n], at, -rig.frame_at(proxy_distance(n)).basis.z)


func mouth_point() -> Vector3:
	return rig.place(Vector3(0.0, -1.6 * settings.leviathan_girth / 6.0, mouth_length() * 0.45))


func hold_reach() -> float:
	return 5.5 * settings.leviathan_girth / 6.0


func grabs() -> bool:
	return true


func _ready() -> void:
	super()
	name = "GulperMother"
	_gulp_left = settings.gulper_every * 0.6


func _special(delta: float, _prey: FishController) -> void:
	# The gulp: open wide, draw the nearby dead in, swallow them.
	if phase != Phase.FURY:
		_gulp_left -= delta
		if _gulp_left <= 0.0 and _open_left <= 0.0:
			_gulp_left = settings.gulper_every
			_open_left = GULP_TIME
			_in_gulp = 0
			gulps += 1
	if _open_left > 0.0:
		_open_left -= delta
		var mouth := mouth_point()
		var reach := SWALLOW_REACH * settings.leviathan_girth
		for i in run.horde.query_sphere(mouth, settings.gulper_range):
			if run.horde.is_proxy(i) or run.horde.is_immortal(i):
				continue
			var off := mouth - run.horde.enemy_position(i)
			if off.length() <= reach and _in_gulp < settings.gulper_max:
				run.horde.remove(i)
				_in_gulp += 1
				swallowed += 1
				hp = minf(hp + max_hp * settings.gulper_heal, max_hp)
			else:
				run.horde.shove(i, off.normalized() * settings.gulper_pull * delta * 3.0)


## Spitting, it vomits a pack at its prey as well as its bile.
func _spit(at: Vector3) -> void:
	super(at)
	if settings.gulper_vomit > 0:
		var mouth := mouth_point()
		run.horde.spawn_pack(0, settings.gulper_vomit, mouth, 2.5, (at - mouth).normalized(), 0.0)


func _glow_now() -> void:
	super()
	var open := 1.0 if _open_left > 0.0 or held or phase == Phase.FURY or _diving > 0.0 or winding_up() else 0.15
	_gape = move_toward(_gape, open, get_physics_process_delta_time() * 1.6)
	var full := clampf(0.15 + swallowed / 60.0, 0.0, 1.0)
	for material in skins:
		material.set_shader_parameter("gape", _gape)
		material.set_shader_parameter("fullness", full)
	if is_instance_valid(_lure_light):
		_lure_light.light_energy = 2.5 + sin(age * 3.1) * 0.8


func _build_look() -> void:
	var length := body_length()
	var k := settings.leviathan_girth / 6.0
	var lm := mouth_length()
	var rb := 2.7 * k
	var belly_from := lm
	var belly_to := lm + length * 0.26
	var mesh := BossMesh.new(length)
	# The body: an eel behind the mouth, its belly swollen, thinning to a whip.
	var body_from := lm * 0.82
	var body := func(along: float) -> Vector4:
		var z := lerpf(body_from, length, along)
		var bulge := 0.55 * sin(PI * clampf((z - belly_from) / (belly_to - belly_from), 0.0, 1.0))
		var t := clampf((along - 0.22) / 0.78, 0.0, 1.0)
		var r := rb * lerpf(1.0, 0.035, pow(t, 0.65))
		r *= smoothstep(0.0, 0.015, along) * 0.6 + 0.4
		r *= sqrt(maxf(1.0 - pow(maxf(along - 0.99, 0.0) / 0.01, 2.0), 0.0))
		return Vector4(r * (1.0 + bulge * 0.55), r * (1.0 + bulge), -r * bulge * 0.75, 2.0)
	mesh.loft(body_from, length, body, 260, 26, BossMesh.BODY)
	# Low dorsal and anal fins along the body.
	for fin: Array in [[1.0, 0.25, 0.85], [-1.0, 0.3, 0.8]]:
		var sign_y: float = fin[0]
		var from: float = fin[1]
		var to: float = fin[2]
		mesh.membrane(func(u: float) -> Vector3:
				var a := lerpf(from, to, u)
				var slice: Vector4 = body.call(a)
				return Vector3(0.0, slice.z + slice.y * 0.95 * sign_y, lerpf(body_from, length, a)),
			func(u: float) -> Vector3:
				var a := lerpf(from, to, u)
				var slice: Vector4 = body.call(a)
				var h := slice.x * 0.5 * sin(u * PI)
				return Vector3(0.0, h * sign_y, h * 0.4),
			90, 3, Vector2(0.0, 1.0), BossMesh.FIN)
	# The pouch: an open mouth hanging below thin jaws, raw throat inside.
	var pouch := func(a: float) -> Vector4:
		var e := pow(a, 0.8)
		var sag := sin(a * PI) * (1.0 - a * 0.5)  # a loose bag, sagging between the rim and the throat
		return Vector4((lerpf(5.4, 2.3, e) + 1.0 * sag) * k, (lerpf(6.6, 2.4, e) + 1.8 * sag) * k, (lerpf(-3.2, 0.0, a) - 1.6 * sag) * k, 1.9)
	# A teardrop of loose skin, deepest below, in soft folds.
	var folds := func(a: float, angle: float) -> float:
		var below := maxf(-cos(angle), 0.0)
		return 1.0 + 0.2 * below * (1.0 - a) + 0.05 * sin(angle * 11.0 + a * 7.0) * sqrt(1.0 - a) * (0.4 + below)
	mesh.loft(0.0, lm * 1.05, pouch, 44, 56, BossMesh.INSIDE, Callable(), 0.0, folds)
	var rim_at := func(a: float, angle: float) -> Vector3:
		var slice: Vector4 = pouch.call(a)
		return Vector3(sin(angle) * slice.x, slice.z + cos(angle) * slice.y, a * lm * 1.05)
	# The jaws: thin rods along the top of the rim and down its sides, needle
	# teeth all along them pointing in.
	for angle: float in [0.0, deg_to_rad(118.0), -deg_to_rad(118.0)]:
		var path := PackedVector3Array()
		for i in 30:
			path.append(rim_at.call(i / 29.0 * 0.95, angle))
		mesh.tube(path, func(t: float) -> float: return lerpf(0.45, 0.75, t) * k, 8, BossMesh.EXTRA2)
		var count := 34 if angle == 0.0 else 26
		for j in count:
			var a := lerpf(0.02, 0.7, j / float(count - 1))
			var base: Vector3 = rim_at.call(a, angle)
			var middle: Vector4 = pouch.call(a)
			var inward := (Vector3(0.0, middle.z, base.z) - base).normalized()
			mesh.tooth(base + inward * 0.35 * k, (inward + Vector3(0.0, 0.0, 0.15)).normalized() * lerpf(0.9, 0.4, a) * k, 0.12 * k, Vector3(0.0, 0.0, 0.25), 5)
	# The tail's lure stalk: a last filament off the whip's end.
	var tip := Vector3(0.0, 0.0, length)
	var stalk := PackedVector3Array()
	for i in 10:
		var s := i / 9.0
		stalk.append(tip + Vector3(0.0, 0.8 * k * sin(s * PI * 0.6), 2.2 * k * s))
	mesh.tube(stalk, func(t: float) -> float: return lerpf(0.09, 0.05, t) * k, 6, BossMesh.FILAMENT, Vector2(0.5, 1.0))
	var skin := _spine_material(GULPER_SKIN)
	skin.set_shader_parameter("mouth_len", lm * 1.05)
	skin.set_shader_parameter("rim_y", -3.2 * k)
	skin.set_shader_parameter("hinge_y", 0.0)
	skin.set_shader_parameter("belly_span", Vector2(belly_from, belly_to))
	skin.set_shader_parameter("spine_wave", Vector4(0.9 * k, 0.16, 2.6, 0.3))
	skin.set_shader_parameter("flutter", Vector3(0.35 * k, 1.4, 5.5))
	rig.length = length + 2.5 * k
	rig.add_mesh(self, mesh.commit(), skin)
	# Beady black eyes at the snout's tip.
	for side: float in [-1.0, 1.0]:
		var top: Vector3 = rim_at.call(0.07, 0.0)
		var eye := _eye(0.42 * k, Color(0.12, 0.12, 0.15), Color(0.05, 0.05, 0.07), 0.6)
		_add_rider(eye, top + Vector3(side * 0.55 * k, 0.45 * k, 0.0), Basis.looking_at(Vector3(side, 0.4, -0.4), Vector3.UP))
	# The lure: a glowing bulb at the tail's end, lighting the water round it.
	var lure := Node3D.new()
	lure.name = "Lure"
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55 * k
	sphere.height = 1.1 * k
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.6, 0.75)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.3, 0.5)
	glow.emission_energy_multiplier = 6.0
	sphere.material = glow
	bulb.mesh = sphere
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lure.add_child(bulb)
	_lure_light = OmniLight3D.new()
	_lure_light.light_color = Color(1.0, 0.35, 0.55)
	_lure_light.omni_range = 16.0 * k
	_lure_light.light_energy = 2.5
	lure.add_child(_lure_light)
	_add_rider(lure, Vector3(0.0, 0.7 * k, length + 2.2 * k), Basis.IDENTITY)


## Its bolts are gobs of bile.
func _bolt_mesh_look() -> Mesh:
	var gob := SphereMesh.new()
	gob.radius = 0.55
	gob.height = 0.9
	gob.radial_segments = 8
	gob.rings = 4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.55, 0.15)
	glow.roughness = 0.1
	glow.emission_enabled = true
	glow.emission = Color(0.6, 0.7, 0.1)
	glow.emission_energy_multiplier = 1.0
	gob.material = glow
	return gob
