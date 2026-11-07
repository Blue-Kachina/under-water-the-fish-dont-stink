extends RefCounted
## The Fallen Angel as a Hunter's body (what_stinks.md section 2): FallenAngelBoss._build_look taken out of the
## boss (it welds to UnnaturalRun and its AI) and built at the boss's own height. One glass body (boss_angel.gdshader)
## over the orange organs inside it (boss_angel_organ.gdshader), both in their rest pose (the head's top at z 0, the
## tail's tip at z H) for AngelRig to bend along a spine; two torn wing paddles at the shoulders and the crown's six
## tentacles, plain nodes AngelRig places. The boss's own static helpers draw the body, wings and tentacles, so the
## Hunter and the boss never drift apart.

const BODY_SHADER := preload("res://shaders/boss_angel.gdshader")
const ORGAN_SHADER := preload("res://shaders/boss_angel_organ.gdshader")
const TENTACLE_SHADER := preload("res://shaders/angel_tentacle.gdshader")
const TENTACLES := 6
## The body's height in model units (the boss's own default: its shaders are tuned to it). AngelRig scales it to fill the hitbox.
const H := 40.0


## The look: {body, organs, wing: Mesh, tentacle: Mesh, skin, organ_skin, wing_skin: ShaderMaterial, tentacle_skins: Array[ShaderMaterial]}.
static func build() -> Dictionary:
	var h := H
	var body := BossMesh.new(h)
	var profile := func(along: float) -> Vector4:
		var slice: Vector4 = FallenAngelBoss._body_slice(along)
		return Vector4(slice.x * h, slice.y * h, slice.z * h, slice.w)
	var ridges := func(a: float, angle: float) -> float:
		return 1.0 + 0.012 * sin(angle * 14.0) * smoothstep(0.2, 0.35, a) * (1.0 - smoothstep(0.85, 1.0, a))
	body.loft(0.0, h, profile, 220, 48, BossMesh.BODY, Callable(), 0.0, ridges)
	# Two horns at the top corners of the hood, pricked up and out like ears.
	for side_x: float in [-1.0, 1.0]:
		var base := Vector3(side_x * h * 0.062, h * 0.004, h * 0.05)
		var path := PackedVector3Array()
		for i in 12:
			var t := i / 11.0
			path.append(base + Vector3(side_x * (0.03 * t + 0.012 * t * t), 0.004 * t, -0.085 * t + 0.01 * t * t) * h)
		body.tube(path, func(t: float) -> float: return h * 0.024 * pow(1.0 - t, 0.85) + h * 0.001, 12, BossMesh.EXTRA)
	var skin := ShaderMaterial.new()
	skin.shader = BODY_SHADER
	skin.set_shader_parameter("height", h)
	skin.set_shader_parameter("spine_wave", Vector4(h * 0.01, 0.4, 2.2, 0.55))
	skin.set_shader_parameter("flutter", Vector3(h * 0.004, 0.8, 3.0))
	# Inside the hood: the folded crown and brain; below the neck, the gut. Both glow through the glass.
	var organs := BossMesh.new(h)
	var head_r := func(along: float) -> Vector4:
		var r := h * 0.08 * pow(maxf(sin(along * PI), 0.0), 0.5) * lerpf(1.0, 0.8, along)
		return Vector4(r, r * 0.72, h * 0.03, 2.0)
	var head_lumps := func(a: float, angle: float) -> float:
		return 1.0 + 0.13 * sin(angle * 3.0 + a * 6.0) + 0.07 * sin(angle * 7.0 - a * 11.0)
	organs.loft(h * 0.018, h * 0.14, head_r, 36, 28, BossMesh.INSIDE, Callable(), 0.0, head_lumps)
	var gut_r := func(along: float) -> Vector4:
		var r := h * 0.068 * pow(maxf(sin(along * PI), 0.0), 0.45) * lerpf(1.0, 0.75, along)
		return Vector4(r * 1.15, r * 0.8, h * 0.03 * (1.0 - along * 0.5), 2.0)
	var gut_lumps := func(a: float, angle: float) -> float:
		return 1.0 + 0.1 * sin(angle * 2.0 + a * 13.0) + 0.06 * sin(angle * 5.0 + a * 29.0)
	organs.loft(h * 0.2, h * 0.46, gut_r, 48, 24, BossMesh.INSIDE, Callable(), 1.0, gut_lumps)
	var organ_skin := ShaderMaterial.new()
	organ_skin.shader = ORGAN_SHADER
	organ_skin.set_shader_parameter("height", h)
	var wing_skin := ShaderMaterial.new()
	wing_skin.shader = BODY_SHADER
	wing_skin.set_shader_parameter("height", h)
	wing_skin.set_shader_parameter("is_wing", true)
	var tentacle_skins: Array[ShaderMaterial] = []
	for t in TENTACLES:
		var material := ShaderMaterial.new()
		material.shader = TENTACLE_SHADER
		material.set_shader_parameter("rest_length", h * 0.36)
		tentacle_skins.append(material)
	return {
		"body": body.commit(), "organs": organs.commit(),
		"wing": FallenAngelBoss._wing_mesh(h), "tentacle": FallenAngelBoss._tentacle_mesh(h * 0.36, h * 0.026),
		"skin": skin, "organ_skin": organ_skin, "wing_skin": wing_skin, "tentacle_skins": tentacle_skins,
	}
