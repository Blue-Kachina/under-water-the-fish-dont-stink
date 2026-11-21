extends RefCounted
## The Gulper Mother as a Hunter's body (what_stinks.md section 2): GulperBoss._build_look
## taken out of the boss (it welds to UnnaturalRun) and shrunk to a playable eel. One
## BossMesh in its rest pose (head at z 0, tailward +z) that GulperRig bends along a spine
## in the model's own space, with the boss's own skin shader (boss_gulper.gdshader), eyes
## and the tail's lure. Sizes are in girth units `k`, built at the boss's own k of 1 because its skin shader has metres in it
## (the gape drop). The body is UNITS k long: GulperRig scales it to fill the hitbox, and the
## controller's body_scale then scales that to the form's length like every other form.

const SKIN := preload("res://shaders/boss_gulper.gdshader")
const EYE := preload("res://shaders/fish_eye.gdshader")
## The mouth's pouch (k), the body behind it to the whip's end (k), and the lure's stalk past that (k).
const MOUTH := 17.0
const BODY := 51.0
const STALK := 2.5
const UNITS := BODY + STALK
## Where the mouth's rim centre sits below the spine (k).
const RIM_Y := -3.2


## The look in girth unit `k`: {mesh, skin, eyes: [[node, rest point, rest basis]], lure: [node, rest point]}.
static func build(k: float) -> Dictionary:
	var lm := MOUTH * k
	var length := BODY * k
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
	mesh.loft(body_from, length, body, 200, 22, BossMesh.BODY)
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
			70, 3, Vector2(0.0, 1.0), BossMesh.FIN)
	# The pouch: an open mouth hanging below thin jaws, raw throat inside.
	var pouch := func(a: float) -> Vector4:
		var e := pow(a, 0.8)
		var sag := sin(a * PI) * (1.0 - a * 0.5)  # a loose bag, sagging between the rim and the throat
		return Vector4((lerpf(5.4, 2.3, e) + 1.0 * sag) * k, (lerpf(6.6, 2.4, e) + 1.8 * sag) * k, (lerpf(-3.2, 0.0, a) - 1.6 * sag) * k, 1.9)
	var folds := func(a: float, angle: float) -> float:
		var below := maxf(-cos(angle), 0.0)
		return 1.0 + 0.2 * below * (1.0 - a) + 0.05 * sin(angle * 11.0 + a * 7.0) * sqrt(1.0 - a) * (0.4 + below)
	mesh.loft(0.0, lm * 1.05, pouch, 36, 44, BossMesh.INSIDE, Callable(), 0.0, folds)
	var rim_at := func(a: float, angle: float) -> Vector3:
		var slice: Vector4 = pouch.call(a)
		return Vector3(sin(angle) * slice.x, slice.z + cos(angle) * slice.y, a * lm * 1.05)
	# The jaws: thin rods along the top of the rim and down its sides, needle teeth pointing in.
	for angle: float in [0.0, deg_to_rad(118.0), -deg_to_rad(118.0)]:
		var path := PackedVector3Array()
		for i in 24:
			path.append(rim_at.call(i / 23.0 * 0.95, angle))
		mesh.tube(path, func(t: float) -> float: return lerpf(0.45, 0.75, t) * k, 6, BossMesh.EXTRA2)
		var count := 28 if angle == 0.0 else 20
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
		stalk.append(tip + Vector3(0.0, 0.8 * k * sin(s * PI * 0.6), STALK * k * s))
	mesh.tube(stalk, func(t: float) -> float: return lerpf(0.09, 0.05, t) * k, 6, BossMesh.FILAMENT, Vector2(0.5, 1.0))
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("mouth_len", lm * 1.05)
	skin.set_shader_parameter("rim_y", RIM_Y * k)
	skin.set_shader_parameter("hinge_y", 0.0)
	skin.set_shader_parameter("belly_span", Vector2(belly_from, belly_to))
	skin.set_shader_parameter("spine_wave", Vector4(0.9 * k, 0.2 / k, 3.0, 0.3))
	skin.set_shader_parameter("flutter", Vector3(0.35 * k, 1.4 / k, 5.5))
	var eyes: Array = []
	# Beady black eyes at the snout's tip.
	for side: float in [-1.0, 1.0]:
		var top: Vector3 = rim_at.call(0.07, 0.0)
		var eye := _eye(0.42 * k, Color(0.12, 0.12, 0.15), Color(0.05, 0.05, 0.07), 0.6)
		eyes.append([eye, top + Vector3(side * 0.55 * k, 0.45 * k, 0.0), Basis.looking_at(Vector3(side, 0.4, -0.4), Vector3.UP)])
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
	var light := OmniLight3D.new()
	light.name = "LureLight"
	light.light_color = Color(1.0, 0.35, 0.55)
	light.light_energy = 2.5
	lure.add_child(light)
	return {"mesh": mesh.commit(), "skin": skin, "eyes": eyes, "lure": [lure, Vector3(0.0, 0.7 * k, length + 2.2 * k)]}


## A lifelike eye (fish_eye.gdshader), `radius` in model units.
static func _eye(radius: float, iris: Color, inner: Color, pupil: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = EYE
	material.set_shader_parameter("iris", iris)
	material.set_shader_parameter("iris_inner", inner)
	material.set_shader_parameter("pupil", pupil)
	material.set_shader_parameter("sheen", 0.15)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var eye := MeshInstance3D.new()
	eye.mesh = sphere
	eye.material_override = material
	eye.scale = Vector3.ONE * radius * 2.0
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return eye
