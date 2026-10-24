class_name SeaHareModel
extends RefCounted
## The Alchemists (FishModel.build hands them here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.ALCHEMIST] (LOOKS, in that order),
## three sea hares and a chromodorid nudibranch, each after a reference picture
## in private_content/.
##
## One seamless soft body (_body_mesh), shaped per species (slim or flat): a
## head, a neck swelling to the body and a pointed tail, its sides rounding down
## onto a flat foot. The rear bends into the tail (FishModel._bend_body), and a
## wave runs down the body behind the head, much stronger with each stride
## (sea_hare_skin.gdshader). Two flaps (_flap_mesh) sit where each species has
## them: a sea hare's parapodia folding over the rear of its back, or the
## nudibranch's wavy mantle skirt. They are on hinges that roll with the swim
## animation's fin pivots (FishModel._follow_flaps), so the flap gait beats
## them (Gait.Visual.FLAP). On the head (_horn_mesh): rhinophores (rolled ears,
## or the nudibranch's ridged ones), oral tentacles (the California's are big
## flappy lobes) and small eyes. The Tinctoria carries a curled gill plume
## (_plume); the Ragged is covered in long, branching jelly-coral growths
## (_growths). Everything is drawn with sea_hare_skin.gdshader.

const SKIN := preload("res://shaders/sea_hare_skin.gdshader")

## Of the body's length: the nose's rounding and the tail's taper to its point.
const NOSE := 0.07
const TAIL := 0.18
## How square the body's underside is (1 round, toward 0 boxier): the foot.
const FOOT := 0.75
## Along the body: where it starts bending into the tail, and where the body
## wave starts (behind the head).
const BEND_FROM := 0.66
const WAVE_FROM := 0.22
## The body wave at the tail (of the hitbox's height): side to side idling, and
## up and down at a stride's push (sea_hare_skin.gdshader multiplies these).
const SWAY := 0.035
const HEAVE := 0.045

## Each species:
## - wide, top, waist, sole: the body from its nose (0) to its tail tip (1),
##   evenly spaced: half width (of the hitbox's half width), and the top of the
##   back, the line it's widest along and the sole (of the hitbox's half
##   height, from its middle).
## - skin: sea_hare_skin.gdshader's settings for every part.
## - flap_*: the flaps' span along the body, where they leave it (rad round from
##   the top of the back), the way they set off (rad, 0 straight out, PI / 2
##   straight up) and curl on from there, their reach and thickness (of the
##   hitbox's height) and ruffle.
## - ear, tentacle: the rhinophores and oral tentacles (_horn_mesh's shape; sizes
##   of the hitbox's height), where they sit (along, angle round from the top)
##   and which way they grow and curl (the right one's; mirrored for the left);
##   a tentacle's own skin settings over the head's (skin).
## - eyes, plume, growths: whether it has eyes, a gill plume, and how many growths.
const LOOKS := [
	{  # California Sea Hare (Aplysia californica): slim and translucent red, densely dotted dark maroon with white sparkles; tall folded parapodia over the rear; big flared, wavy oral tentacles; slim rolled rhinophores, pale-tipped. Shiny.
		"wide": [0.28, 0.32, 0.26, 0.26, 0.3, 0.38, 0.45, 0.5, 0.52, 0.48, 0.4, 0.28, 0.14],
		"top": [0.0, 0.16, 0.18, 0.22, 0.32, 0.5, 0.7, 0.86, 0.92, 0.82, 0.56, 0.26, -0.1],
		"waist": [-0.3, -0.3, -0.28, -0.28, -0.3, -0.34, -0.38, -0.4, -0.42, -0.46, -0.52, -0.6, -0.66],
		"sole": [-0.6, -0.68, -0.7, -0.74, -0.8, -0.86, -0.9, -0.92, -0.92, -0.9, -0.86, -0.8, -0.74],
		"skin": {
			"albedo": Color("a8302c"), "second_color": Color("4a0e14"), "third_color": Color("f4e6d0"), "belly_color": Color("c8524a"),
			"rim_color": Color("e8d0c0"), "inner_color": Color("8a2026"), "horn_color": Color("a8302c"), "tip_color": Color("e8d8a0"),
			"pattern": 0, "seed": 3.0, "roughness": 0.3, "specular": 0.55, "clearcoat": 0.45, "bump": 0.8, "rim_from": 0.9, "cover": 0.5,
			"horn_mix": 0.3, "tip_mix": 0.8,
		},
		"flap_span": Vector2(0.42, 0.95), "flap_root": 0.95, "flap_angle": 1.4, "flap_curl": 1.5, "flap_reach": 0.9, "flap_thick": 0.025, "ruffle": 0.14,
		"ear": {"length": 0.32, "radius": 0.055, "curl": 0.6, "flat": 0.6, "groove": 0.4, "taper": 0.45, "frill": 0.1,
			"along": 0.17, "angle": 0.55, "axis": Vector3(0.35, 1.0, 0.25), "bend": Vector3.BACK},
		"tentacle": {"length": 0.42, "radius": 0.14, "curl": 1.8, "flat": 0.22, "groove": 0.0, "taper": 0.9, "frill": 0.1,
			"along": 0.03, "angle": 1.75, "axis": Vector3(0.8, 0.0, -0.6), "bend": Vector3(1.0, 0.6, 0.2),
			"skin": {"tip_mix": 0.0, "edge_mix": 0.7, "edge_color": Color("f0d8c8")}},
		"eyes": true, "iris": Color("c87a3a"), "plume": false, "growths": 0,
	},
	{  # Spotted Sea Hare (Aplysia dactylomela): pale cream, black rings (some big, paler inside) over a cracked dark network; short wavy knobbly parapodia on the rear. Matte.
		"wide": [0.3, 0.34, 0.3, 0.32, 0.4, 0.5, 0.58, 0.62, 0.6, 0.54, 0.44, 0.3, 0.16],
		"top": [0.0, 0.16, 0.2, 0.26, 0.4, 0.58, 0.74, 0.84, 0.84, 0.72, 0.48, 0.2, -0.15],
		"waist": [-0.3, -0.3, -0.28, -0.28, -0.3, -0.34, -0.38, -0.4, -0.42, -0.46, -0.52, -0.6, -0.66],
		"sole": [-0.6, -0.68, -0.7, -0.74, -0.8, -0.86, -0.9, -0.92, -0.92, -0.9, -0.86, -0.8, -0.74],
		"skin": {
			"albedo": Color("d6ccb2"), "second_color": Color("1c1814"), "third_color": Color("efe8d6"), "belly_color": Color("d8d0bc"),
			"rim_color": Color("e8e0c8"), "inner_color": Color("a89c80"), "horn_color": Color("cdc4ac"), "tip_color": Color("efe8d6"),
			"pattern": 1, "seed": 7.0, "roughness": 0.8, "specular": 0.3, "clearcoat": 0.0, "bump": 1.0, "knobs": 0.8, "rim_from": 0.7, "cover": 0.4,
			"horn_mix": 0.2, "tip_mix": 0.4,
		},
		"flap_span": Vector2(0.5, 0.94), "flap_root": 0.75, "flap_angle": 1.5, "flap_curl": 1.2, "flap_reach": 0.42, "flap_thick": 0.03, "ruffle": 0.18,
		"ear": {"length": 0.3, "radius": 0.06, "curl": 0.7, "flat": 0.85, "groove": 0.45, "taper": 0.5,
			"along": 0.15, "angle": 0.6, "axis": Vector3(0.4, 1.0, 0.35), "bend": Vector3.BACK},
		"tentacle": {"length": 0.26, "radius": 0.07, "curl": 1.0, "flat": 0.4, "groove": 0.15, "taper": 0.7, "frill": 0.15,
			"along": 0.03, "angle": 1.85, "axis": Vector3(0.75, -0.25, -0.6), "bend": Vector3(1.0, 0.3, 0.3)},
		"eyes": true, "iris": Color("b89040"), "plume": false, "growths": 0,
	},
	{  # Ragged Sea Hare (Bursatella leachii): a dark olive mound, pale-granuled with blue spots ringed dark, covered in long branching growths like translucent jelly coral, pale olive spotted dark; small hidden parapodia. Matte.
		"wide": [0.32, 0.38, 0.4, 0.46, 0.54, 0.6, 0.64, 0.64, 0.6, 0.52, 0.4, 0.26, 0.12],
		"top": [0.0, 0.18, 0.26, 0.38, 0.52, 0.64, 0.72, 0.74, 0.7, 0.58, 0.4, 0.18, -0.15],
		"waist": [-0.3, -0.3, -0.28, -0.28, -0.3, -0.34, -0.38, -0.4, -0.42, -0.46, -0.52, -0.6, -0.66],
		"sole": [-0.6, -0.68, -0.7, -0.74, -0.8, -0.86, -0.9, -0.92, -0.92, -0.9, -0.86, -0.8, -0.74],
		"skin": {
			"albedo": Color("2e2a1a"), "second_color": Color("a8a47a"), "third_color": Color("2f8cff"), "belly_color": Color("4a4430"),
			"rim_color": Color("6a6a48"), "inner_color": Color("2a2618"), "horn_color": Color("4a4630"), "tip_color": Color("8c9468"),
			"growth_color": Color("7e8862"), "growth_spot": Color("1e1e10"),
			"pattern": 2, "seed": 11.0, "roughness": 0.85, "specular": 0.3, "clearcoat": 0.0, "bump": 1.4, "rim_from": 0.8, "cover": 0.2,
			"horn_mix": 0.4, "tip_mix": 0.3,
		},
		"flap_span": Vector2(0.55, 0.88), "flap_root": 0.6, "flap_angle": 1.55, "flap_curl": 0.9, "flap_reach": 0.26, "flap_thick": 0.03, "ruffle": 0.12,
		"flap_rows": 32,
		"ear": {"length": 0.24, "radius": 0.05, "curl": 0.6, "flat": 0.85, "groove": 0.4, "taper": 0.5,
			"along": 0.16, "angle": 0.6, "axis": Vector3(0.4, 1.0, 0.4), "bend": Vector3.BACK},
		"tentacle": {"length": 0.2, "radius": 0.06, "curl": 0.9, "flat": 0.4, "groove": 0.1, "taper": 0.75, "frill": 0.1,
			"along": 0.03, "angle": 1.9, "axis": Vector3(0.75, -0.2, -0.65), "bend": Vector3(1.0, 0.35, 0.3)},
		"eyes": true, "iris": Color("a08040"), "plume": false, "growths": 120,
	},
	{  # Tinctoria (Goniobranchus tinctorius), a chromodorid nudibranch: a long flat oval, a red net over white (dense white spots) with darker red patches, a white underside and wavy white mantle skirt; ridged red rhinophores on white stalks; a curled pink-white gill plume edged red. No eyes to see. Matte.
		"wide": [0.3, 0.4, 0.46, 0.5, 0.52, 0.53, 0.53, 0.53, 0.52, 0.49, 0.42, 0.32, 0.18],
		"top": [-0.12, 0.14, 0.26, 0.34, 0.4, 0.43, 0.45, 0.45, 0.43, 0.38, 0.28, 0.12, -0.12],
		"waist": [-0.42, -0.42, -0.42, -0.42, -0.42, -0.42, -0.42, -0.42, -0.42, -0.43, -0.44, -0.45, -0.46],
		"sole": [-0.66, -0.74, -0.78, -0.8, -0.8, -0.8, -0.8, -0.8, -0.8, -0.8, -0.78, -0.74, -0.66],
		"skin": {
			"albedo": Color("c0281c"), "second_color": Color("780c0c"), "third_color": Color("f6eee6"), "belly_color": Color("f4f0ea"),
			"rim_color": Color("f6f2ec"), "inner_color": Color("f0e8e0"), "horn_color": Color("b82418"), "base_color": Color("f4eee8"),
			"pattern": 3, "seed": 5.0, "roughness": 0.75, "specular": 0.3, "clearcoat": 0.0, "bump": 0.6, "rim_from": 0.25, "cover": 0.0,
			"mantle": 0.8, "horn_mix": 1.0, "base_len": 0.42, "lamellae": 9.0, "groove_shade": 0.0,
		},
		"flap_span": Vector2(0.04, 0.97), "flap_root": 1.62, "flap_angle": -0.35, "flap_curl": 0.6, "flap_reach": 0.2, "flap_thick": 0.014, "ruffle": 0.3,
		"ear": {"length": 0.36, "radius": 0.07, "curl": 0.15, "flat": 0.9, "groove": 0.0, "taper": 0.75, "ridges": 9.0, "stalk": 0.42,
			"along": 0.1, "angle": 0.45, "axis": Vector3(0.2, 1.0, -0.15), "bend": Vector3.BACK},
		"tentacle": null,
		"eyes": false, "plume": true, "growths": 0,
		"plume_skin": {"horn_color": Color("f4dcd2"), "edge_color": Color("c0281c"), "edge_mix": 0.85, "base_len": 0.0, "lamellae": 0.0},
	},
]


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.species, 0, LOOKS.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var ends := Vector2(-l * 0.5, l * 0.5)
	var at := func(along: float) -> float: return lerpf(ends.x, ends.y, along)
	var slice := func(along: float) -> Vector4: return _slice(look, along, w, h)
	var skin_look: Dictionary = look.skin
	m._body_material = m._material(skin_look.albedo)  # for set_body_color(); the skin does the shading
	var wave := {"wave_from": at.call(WAVE_FROM), "wave_len": ends.y - float(at.call(WAVE_FROM)), "sway_amp": h * SWAY, "heave_amp": h * HEAVE}

	# The body, nose to tail tip in one piece.
	var skin := _skin(m, look, 0, wave)
	var flap_span: Vector2 = look.flap_span
	skin.set_shader_parameter("flap_span", Vector2(at.call(flap_span.x), at.call(flap_span.y)))
	skin.set_shader_parameter("nose_z", ends.x)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(ends, slice, 84, 48)
	body.material_override = skin
	m.add_child(body)
	var bent: Array = []

	# The flaps, either side, hinged where the fin pivots sit; they roll with
	# the pivots (FishModel._follow_flaps) and ride the body's wave and bend.
	var root_mid := _flap_root(slice, ends, lerpf(flap_span.x, flap_span.y, 0.5), 1.0, look.flap_root)
	m._fin_pivots(root_mid)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "FlapLeft" if side < 0.0 else "FlapRight"
		hinge.position = root_mid * Vector3(side, 1.0, 1.0)
		m.add_child(hinge)
		m._flaps.append(hinge)
		var material := _skin(m, look, 1, wave)
		material.set_shader_parameter("part_origin", hinge.position)
		material.set_shader_parameter("wave_amp", h * 0.03)
		material.set_shader_parameter("waves", 1.6)
		var flap := MeshInstance3D.new()
		flap.name = "Parapodium"
		flap.mesh = _flap_mesh(look, side, slice, ends, h, hinge.position)
		flap.material_override = material
		flap.extra_cull_margin = 0.1  # it ripples out of its bounds
		hinge.add_child(flap)
		bent.append(flap)

	# The head: eyes, rhinophores behind them, oral tentacles at the front. They
	# sit in their own space, in front of the body wave.
	var head_material := _skin(m, look, 2, wave)
	head_material.set_shader_parameter("sway", 0.0)
	var eye := Vector3.ZERO
	if look.eyes:
		var eye_radius := h * 0.042
		eye = _surface(slice, ends, 0.115, 1.0) - _surface_normal(slice, ends, 0.115, 1.0) * eye_radius * 0.45
		skin.set_shader_parameter("eye_at", eye)
		skin.set_shader_parameter("eye_radius", eye_radius)
		for side: float in [-1.0, 1.0]:
			var ball := m._real_eye(eye * Vector3(side, 1.0, 1.0), eye_radius, Vector3(side * 0.9, 0.35, -0.5), look.iris, 0.5)
			(ball.material_override as ShaderMaterial).set_shader_parameter("rim_color", (skin_look.albedo as Color).darkened(0.6))
	else:
		skin.set_shader_parameter("eye_radius", 0.0)
	_horns(m, look.ear, head_material, slice, ends, h, "Rhinophore")
	if look.tentacle != null:
		var tentacle: Dictionary = look.tentacle
		var tentacle_material := head_material
		if tentacle.has("skin"):
			tentacle_material = _skin(m, look, 2, wave)
			tentacle_material.set_shader_parameter("sway", 0.0)
			var settings: Dictionary = tentacle.skin
			for key: String in settings:
				tentacle_material.set_shader_parameter(key, settings[key])
		_horns(m, tentacle, tentacle_material, slice, ends, h, "OralTentacle")

	if look.plume:
		bent.append(_plume(m, look, wave, slice, ends, h))
	if int(look.growths) > 0:
		bent.append(_growths(m, look, wave, slice, ends, h, eye))

	# The rear of the body bends into the tail; the pivot sits at its tip.
	var tip: Vector4 = slice.call(0.99)
	m._tail_pivot(Vector3(0.0, tip.z, at.call(0.99)))
	m.bend_share = 0.7
	m._bend_body(at.call(BEND_FROM), bent)


## One of the skin's materials (sea_hare_skin.gdshader) for `part` (0 body, 1
## flap, 2 horn or plume, 3 growth), coloured for `look`, riding the body wave
## `wave`. It ripples and waves with the swim (FishModel._waving, _body_waves).
static func _skin(m: FishModel, look: Dictionary, part: int, wave: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN
	var settings: Dictionary = look.skin
	for key: String in settings:
		material.set_shader_parameter(key, settings[key])
	for key: String in wave:
		material.set_shader_parameter(key, wave[key])
	material.set_shader_parameter("part", part)
	m._skins.append(material)
	m._waving.append(material)
	m._body_waves.append(material)
	return material


# --- The body ------------------------------------------------------------------

## The body's slice `along` it (nose 0 to tail 1), m: (half width, top of the
## back, the line it's widest along, the sole), the nose rounded off and the
## tail drawn to a point.
static func _slice(look: Dictionary, along: float, w: float, h: float) -> Vector4:
	var half_h := h * 0.5
	var wide := FishModel._sample(look.wide, along) * w * 0.5
	var top := FishModel._sample(look.top, along) * half_h
	var waist := FishModel._sample(look.waist, along) * half_h
	var sole := FishModel._sample(look.sole, along) * half_h
	var k := 1.0
	if along < NOSE:
		k = sqrt(maxf(1.0 - pow((NOSE - along) / NOSE, 2.0), 0.0))
	elif along > 1.0 - TAIL:
		k = pow(maxf((1.0 - along) / TAIL, 0.0), 0.75)
	return Vector4(wide * k, waist + (top - waist) * k, waist, waist - (waist - sole) * k)


## A slice's outline `angle` round from the top of the back (+ toward +X): an
## oval over the waist, squarer under it (the foot).
static func _outline(slice: Vector4, angle: float) -> Vector2:
	var across := sin(angle)
	var up := cos(angle)
	if up >= 0.0:
		return Vector2(across * slice.x, slice.z + up * (slice.y - slice.z))
	return Vector2(signf(across) * pow(absf(across), FOOT) * slice.x, slice.z - pow(-up, FOOT) * (slice.z - slice.w))


## A point on the body (at rest) `along` it, `angle` round from the top.
static func _surface(slice: Callable, ends: Vector2, along: float, angle: float) -> Vector3:
	var point := _outline(slice.call(along), angle)
	return Vector3(point.x, point.y, lerpf(ends.x, ends.y, along))


## The body's outward normal there.
static func _surface_normal(slice: Callable, ends: Vector2, along: float, angle: float) -> Vector3:
	var point := _surface(slice, ends, along, angle)
	var round_it := _surface(slice, ends, along, angle + 0.01) - point
	var down_it := _surface(slice, ends, minf(along + 0.005, 1.0), angle) - point
	var normal := down_it.cross(round_it).normalized()
	var waist: float = (slice.call(along) as Vector4).z
	if normal.dot(Vector3(point.x, point.y - waist, 0.0)) < 0.0:
		normal = -normal
	return normal


## The body's mesh: slices from `ends.x` (nose) to `ends.y` (tail). UV.x runs
## nose to tail and UV.y round it from the top of the back.
static func _body_mesh(ends: Vector2, slice: Callable, rows: int, around: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var along := float(i) / rows
		var z := lerpf(ends.x, ends.y, along)
		var outline: Vector4 = slice.call(along)
		for k in around:
			var point := _outline(outline, TAU * k / around)
			tool.set_uv(Vector2(along, float(k) / around))
			tool.add_vertex(Vector3(point.x, point.y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


# --- The flaps -----------------------------------------------------------------

## Where a flap leaves the body `along` it (side -1 left, 1 right), `angle` round
## from the top of the back, a little in under the skin so the join doesn't show.
static func _flap_root(slice: Callable, ends: Vector2, along: float, side: float, angle: float) -> Vector3:
	var point := _surface(slice, ends, along, angle)
	return Vector3(side * point.x * 0.92, point.y, point.z)


## One flap (side -1 left, 1 right), in its hinge's space (the hinge at
## `pivot_at`): a fleshy sheet leaving the body along look.flap_span, tallest
## behind its middle, setting off look.flap_angle and curling on by
## look.flap_curl, its rim rounded, ruffled and (skin.knobs) studded with little
## knobs. UV.x runs along it, UV.y round it (0 the outside's root, 0.5 the rim,
## 1 the inside's root), UV2 is (how far out, 0..1; how much of a knob) and
## COLOR the sheet's normal, for the shader's ripple.
static func _flap_mesh(look: Dictionary, side: float, slice: Callable, ends: Vector2, h: float, pivot_at: Vector3) -> ArrayMesh:
	var rows: int = look.get("flap_rows", 64)
	var steps := 16  # root to rim, each face
	var rim := 8  # round the rim
	var span: Vector2 = look.flap_span
	var reach_most := h * float(look.flap_reach)
	var set_off: float = look.flap_angle
	var curl: float = look.flap_curl
	var ruffle: float = look.ruffle
	var thick := h * float(look.flap_thick)
	var knobs: float = (look.skin as Dictionary).get("knobs", 0.0)
	var loop := (steps + 1) * 2 + rim - 1
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var test_outward := Vector3.ZERO
	for i in rows + 1:
		var u := float(i) / rows
		var root := _flap_root(slice, ends, lerpf(span.x, span.y, u), side, look.flap_root)
		var rise := sin(PI * pow(u, 0.85))
		var knob := pow(maxf(sin(u * PI * 17.0), 0.0), 3.0) * knobs
		var reach := reach_most * pow(rise, 0.9) * (1.0 + 0.06 * knob)
		var half := maxf(thick * sqrt(maxf(sin(PI * u), 0.0)), h * 0.004)
		# The sheet's middle, root to rim, and its outward normal.
		var middle: Array[Vector2] = []
		var normals: Array[Vector2] = []
		var point := Vector2(root.x, root.y)
		for j in steps + 1:
			var v := float(j) / steps
			var turn := set_off + curl * pow(v, 1.3)
			var direction := Vector2(side * cos(turn), sin(turn))
			var normal := Vector2(side * sin(turn), -cos(turn))
			if j > 0:
				point += direction * reach / steps
			middle.append(point + normal * reach * ruffle * v * v * sin(u * TAU * 2.5 + side))
			normals.append(normal)
		var z := root.z
		var add := func(at: Vector2, sheet: Vector2, s: float, v: float) -> void:
			tool.set_uv(Vector2(u, s))
			tool.set_uv2(Vector2(v, knob))
			tool.set_color(Color(sheet.x * 0.5 + 0.5, sheet.y * 0.5 + 0.5, 0.5))
			tool.add_vertex(Vector3(at.x, at.y, z) - pivot_at)
		for j in steps + 1:
			var v := float(j) / steps
			add.call(middle[j] + normals[j] * half * lerpf(1.0, 0.45, v), normals[j], 0.45 * v, v)
		var edge := middle[steps]
		var edge_normal := normals[steps]
		var edge_direction := Vector2(-edge_normal.y, edge_normal.x) * side
		var edge_half := half * 0.45
		for k in range(1, rim):
			var angle := PI * k / rim
			add.call(edge + edge_normal * edge_half * cos(angle) + edge_direction * edge_half * sin(angle), edge_normal, 0.45 + 0.1 * k / rim, 1.0)
		for j in range(steps, -1, -1):
			var v := float(j) / steps
			add.call(middle[j] - normals[j] * half * lerpf(1.0, 0.45, v), normals[j], 1.0 - 0.45 * v, v)
		if i == rows >> 1:
			test_outward = Vector3(normals[steps >> 1].x, normals[steps >> 1].y, 0.0)
	# Wind the faces so they face out: try one quad on the outside.
	var arrays := tool.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var probe := (rows >> 1) * loop + (steps >> 1)
	var facing := (verts[probe + loop] - verts[probe]).cross(verts[probe + 1] - verts[probe]).dot(test_outward)
	var flip := facing > 0.0  # front faces wind clockwise: their cross product points in
	var indices := PackedInt32Array()
	for i in rows:
		for j in loop - 1:
			var a := i * loop + j
			var b := a + loop
			var c := a + 1
			var d := b + 1
			for corner: int in ([a, c, b, c, d, b] if flip else [a, b, c, c, b, d]):
				indices.append(corner)
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = null
	var rebuilt := SurfaceTool.new()
	rebuilt.create_from_arrays(arrays)
	rebuilt.generate_normals()
	return rebuilt.commit()


# --- The head and the plume ----------------------------------------------------

## A rhinophore, oral tentacle or plume branch along +Z: a soft horn from a
## flared base (sunk into the body) tapering to a rounded tip, curling toward +Y.
## `shape` (sizes of `h`): length, radius, curl (rad), flat (its thickness in
## the curl's plane, of its width, so a flat one curls like a ribbon), groove (a
## slit down its -Y side, where it's rolled up), taper (its tip's thickness, of
## its base's), and optionally frill (its edges ruffle), ridges (rings of
## lamellae past its stalk) and stalk (of its length). UV.x runs base to tip,
## UV.y round it (0.75 down the slit; 0 and 0.5 a flat one's edges).
static func _horn_mesh(shape: Dictionary, h: float) -> ArrayMesh:
	var length := h * float(shape.length)
	var radius := h * float(shape.radius)
	var curl: float = shape.curl
	var flat: float = shape.flat
	var groove: float = shape.groove
	var taper: float = shape.taper
	var frill: float = shape.get("frill", 0.0)
	var ridges: float = shape.get("ridges", 0.0)
	var stalk: float = shape.get("stalk", 0.0)
	var rings := 30 if ridges > 0.0 or frill > 0.0 else 22
	var sides := 18
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := Vector3.ZERO
	for i in rings + 1:
		var t := float(i) / rings
		var pitch := curl * pow(t, 1.5)
		var forward := Vector3(0.0, sin(pitch), cos(pitch))
		var up := Vector3(0.0, cos(pitch), -sin(pitch))
		var r := radius * (1.0 + 0.6 * pow(1.0 - smoothstep(0.0, 0.3, t), 2.0)) * lerpf(1.0, taper, t)
		if t > 0.8:
			r *= sqrt(maxf(1.0 - pow((t - 0.8) / 0.2, 2.0), 0.0))
		if ridges > 0.0:
			r *= 1.0 + 0.16 * maxf(sin(t * ridges * TAU), 0.0) * smoothstep(stalk, stalk + 0.08, t)
		var slit := groove * smoothstep(0.12, 0.4, t) * (1.0 - smoothstep(0.75, 0.95, t))
		for k in sides + 1:
			var angle := TAU * k / sides
			var off := wrapf(angle - PI * 1.5, -PI, PI)
			var dent := 1.0 - slit * exp(-off * off / 0.18)
			var across := cos(angle)
			var ruffle := frill * sin(t * TAU * 2.5 + signf(across) * 1.3) * across * across * smoothstep(0.1, 0.4, t)
			tool.set_uv(Vector2(t, float(k) / sides))
			tool.add_vertex(at + (Vector3.RIGHT * across + up * (sin(angle) * flat + ruffle)) * r * dent)
		at += forward * length / rings
	for i in rings:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			for corner: int in [a, c, b, b, c, d]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A pair of head horns (`shape`, see _horn_mesh and LOOKS) set into the body.
static func _horns(m: FishModel, shape: Dictionary, material: ShaderMaterial, slice: Callable, ends: Vector2, h: float, part_name: String) -> void:
	var mesh := _horn_mesh(shape, h)
	var base := _surface(slice, ends, shape.along, shape.angle) - _surface_normal(slice, ends, shape.along, shape.angle) * h * float(shape.radius) * 0.6
	for side: float in [-1.0, 1.0]:
		var mirror := Vector3(side, 1.0, 1.0)
		_horn(m, mesh, material, base * mirror, (shape.axis as Vector3) * mirror, (shape.bend as Vector3) * mirror, part_name)


## A horn (_horn_mesh) set into the body at `base`, growing along `axis` and
## curling toward `bend_toward`.
static func _horn(m: FishModel, mesh: ArrayMesh, material: ShaderMaterial, base: Vector3, axis: Vector3, bend_toward: Vector3, part_name: String) -> void:
	var horn := MeshInstance3D.new()
	horn.name = part_name
	horn.mesh = mesh
	horn.material_override = material
	horn.transform = _frame(base, axis, bend_toward)
	m.add_child(horn)


## A horn's place: at `base`, growing along `axis`, curling toward `bend_toward`.
static func _frame(base: Vector3, axis: Vector3, bend_toward: Vector3) -> Transform3D:
	var z := axis.normalized()
	var y := (bend_toward - z * z.dot(bend_toward)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), base)


## The Tinctoria's gill plume: a ring of flat, frilly branches on the rear of its
## back, rising and curling out and over, pink-white edged red (look.plume_skin).
## One mesh in the model's space, riding the body wave and bend.
static func _plume(m: FishModel, look: Dictionary, wave: Dictionary, slice: Callable, ends: Vector2, h: float) -> MeshInstance3D:
	var centre := _surface(slice, ends, 0.8, 0.0) - Vector3(0.0, h * 0.02, 0.0)
	var branch := _horn_mesh({"length": 0.7, "radius": 0.075, "curl": 3.6, "flat": 0.3, "groove": 0.0, "taper": 0.45, "frill": 0.35}, h)
	var parts: Array = []
	var count := 10
	for k in count:
		var around := TAU * (k + 0.5) / count
		var out := Vector3(sin(around), 0.0, cos(around))
		parts.append([branch, _frame(centre + out * h * 0.08, Vector3.UP * 1.2 + out * 0.8, out)])
	var material := _skin(m, look, 2, wave)
	var settings: Dictionary = look.plume_skin
	for key: String in settings:
		material.set_shader_parameter(key, settings[key])
	var mesh := ArrayMesh.new()
	FxKit.merge_into(mesh, parts, material)
	var plume := MeshInstance3D.new()
	plume.name = "GillPlume"
	plume.mesh = mesh
	plume.material_override = material
	m.add_child(plume)
	return plume


# --- The Ragged's growths ------------------------------------------------------

## The Ragged's growths: long, flattened, branching like coral and wobbling like
## jelly (part 3), all over its back, flanks and head (not over the eyes),
## leaning back. Each is a main branch with three to five side branches in its
## plane. One mesh in the model's space, riding the body wave and bend.
static func _growths(m: FishModel, look: Dictionary, wave: Dictionary, slice: Callable, ends: Vector2, h: float, eye: Vector3) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var rays: Array = []
	var count: int = look.growths
	for k in count:
		var along := rng.randf_range(0.08, 0.95)
		var angle := rng.randf_range(-2.0, 2.0)
		var root := _surface(slice, ends, along, angle)
		if Vector3(absf(root.x), root.y, root.z).distance_to(eye) < h * 0.12:
			continue
		var normal := _surface_normal(slice, ends, along, angle)
		var length := h * rng.randf_range(0.22, 0.42) * lerpf(0.7, 1.0, sin(PI * along))
		var direction := (normal + Vector3(rng.randf_range(-0.25, 0.25), 0.2, rng.randf_range(0.2, 0.5))).normalized()
		var spread := direction.cross(Vector3.BACK)
		if spread.length() < 0.2:
			spread = Vector3.RIGHT
		spread = spread.normalized().rotated(direction, rng.randf_range(-0.6, 0.6))
		var main := _branch(root - normal * h * 0.02, direction, Vector3(0.0, 0.12, 0.1), length, h * 0.055, spread, 0.0, k)
		rays.append(main)
		var sides := rng.randi_range(3, 5)
		for j in sides:
			var t := lerpf(0.22, 0.82, float(j) / (sides - 1)) + rng.randf_range(-0.05, 0.05)
			var out := 1.0 if j % 2 == 0 else -1.0
			var twig := (direction * 0.75 + spread * out * 0.9).normalized()
			var twig_length := length * rng.randf_range(0.25, 0.45) * (1.1 - 0.5 * t)
			rays.append(_branch(LionfishModel._ray_point(main, t), twig, Vector3(0.0, 0.0, 0.1), twig_length, h * 0.055 * (1.0 - 0.6 * t) * 0.75,
					spread, length * t, k + t))
	var material := _skin(m, look, 3, wave)
	material.set_shader_parameter("wobble", h * 0.025)
	material.set_shader_parameter("wobble_len", h * 0.35)
	var growths := MeshInstance3D.new()
	growths.name = "Growths"
	growths.mesh = _branch_mesh(rays)
	growths.material_override = material
	growths.extra_cull_margin = 0.1  # it wobbles out of its bounds
	m.add_child(growths)
	return growths


## A growth's branch: a ray (LionfishModel._ray) `radius` thick at its root,
## flattened across `spread`, starting `from` m out along its growth.
static func _branch(root: Vector3, direction: Vector3, bow: Vector3, length: float, radius: float, spread: Vector3, from: float, coord: float) -> Dictionary:
	var ray := LionfishModel._ray(root, direction, bow, length, coord)
	ray.radius = radius
	ray.spread = spread
	ray.from = from
	return ray


## The growths' branches as flattened tapering tubes, pointed at the tips, in one
## mesh. UV.x runs along a branch, UV.y round it; UV2 is (m out along its
## growth, which growth).
static func _branch_mesh(rays: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := 0
	for ray: Dictionary in rays:
		var main: bool = float(ray.from) == 0.0
		var rings := 5 if main else 3
		var sides := 5 if main else 4
		var length: float = ray.length
		var radius: float = ray.radius
		var from: float = ray.from
		var coord: float = ray.coord
		for i in rings + 1:
			var t := float(i) / rings
			var centre := LionfishModel._ray_point(ray, t)
			var tangent := LionfishModel._ray_tangent(ray, t)
			var spread: Vector3 = ray.spread
			var across := spread - tangent * tangent.dot(spread)
			if across.length() < 1e-4:
				across = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
			across = across.normalized()
			var face := tangent.cross(across).normalized()
			var r := radius * lerpf(1.0, 0.22, pow(t, 1.2))
			for k in sides + 1:
				var angle := TAU * k / sides
				tool.set_uv(Vector2(t, float(k) / sides))
				tool.set_uv2(Vector2(from + length * t, coord))
				tool.add_vertex(centre + (across * cos(angle) + face * sin(angle) * 0.35) * r)
		for i in rings:
			for k in sides:
				var a := first + i * (sides + 1) + k
				var b := a + 1
				var c := a + sides + 1
				var d := c + 1
				for corner: int in [a, c, b, b, c, d]:
					tool.add_index(corner)
		first += (rings + 1) * (sides + 1)
	tool.generate_normals()
	return tool.commit()
