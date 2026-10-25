class_name JellyModel
extends RefCounted
## The Drifters' moon jelly (FishModel.build hands it here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.DRIFTER].
##
## A glassy bell fills the hitbox, its apex at the nose (-Z) and its open,
## scalloped rim toward the back; frilly oral arms trail out of its mouth under
## the middle and fine tentacles hang from its margin.
## - Body: the bell's outer surface (exumbrella), a superellipse dome with
##   lobed, scalloped lappets round the rim (jelly_bell.gdshader).
## - Subumbrella: its inner surface, the far side of a thick jelly (mesoglea),
##   seen through the outer one (jelly_bell_inner.gdshader).
## - Gonads: four horseshoes in the jelly over the stomach (jelly_organ).
## - OralArms, on the tail pivot (at the mouth): each a core with two or three
##   ruffled, twisting membrane ribbons (jelly_strand.gdshader).
## - Tentacles: thin tubes off the margin, evenly, in its notches or in
##   clusters (jelly_strand.gdshader).
## The bell pulses (BellPulse, jelly_pulse.gdshaderinc): a quick power stroke
## shuts it into a tall dome, a slower recovery stroke spreads it into a flat
## umbrella, its margin lagging and rippling. Strides drive it under
## Gait.Visual.BELL_PULSE (when the whole model also leans from upright as it
## swims, FishModel.bell_lean); else it beats with the swim. Arms and tentacles
## sway in waves and bend round after the tail pivot's swing (Sway feeds them
## the swing each frame), which only trails after the body (trails_tail).
## The fin pivots are empty: a jelly has no fins.
##
## Transparency: every part is see-through, so they're drawn in a fixed order
## (render_priority): strands first, writing depth, then the inner surface,
## the gonads and last the outer surface. From the front the bell layers over
## the arms behind it; from behind the arms hide what's behind them.

const BELL := preload("res://shaders/jelly_bell.gdshader")
const BELL_INNER := preload("res://shaders/jelly_bell_inner.gdshader")
const STRAND := preload("res://shaders/jelly_strand.gdshader")
const ORGAN := preload("res://shaders/jelly_organ.gdshader")

## Godot's front faces wind clockwise, seen from the front.
const CLOCKWISE := true

## Per species (FishCharacter.SPECIES order). Colours are hex; lengths are of the
## hitbox's length unless they say m.
const LOOKS := [
	{  # Moon jelly (Aurelia aurita): clear milky bell, four lilac horseshoe
		# gonads, radial canals, a fine fringe on a scalloped rim, short frilly arms.
		"own": "cfe4f4", "centre": "e8f2fb", "edge": "d2e6f5", "rim": "f4faff", "glow": "bfe0ff",
		"alpha": 0.12, "rim_alpha": 0.5, "glow_power": 0.4,
		"stripes": 0, "stripe": "000000", "stripe_width": 0.0, "stripe_alpha": 0.0,
		"canals": 16, "canal": "f8fcff", "canal_alpha": 0.4, "spots": 0.12, "spot": "ffffff", "muscle": 0.3, "rim_band": 0.0,
		"depth": 0.46, "dome": 2.5, "flare": 0.07, "thick": 0.32, "margin": 0.05,
		"lobes": 8, "lappet": 0.006, "notch": 0.02, "fine_lobes": 48, "fine_lappet": 0.006,
		"gonad": "c8a0e8", "gonad_alpha": 0.6,
		"arm_len": 0.75, "arm_width": 0.1, "ribbons": 2, "wave": 0.1, "ruffle": 0.3, "twist": 0.35, "spiral": 0.0,
		"rows_per_wave": 10.0, "arm_cols": 5, "billow": 0.45, "taper_from": 0.7, "slack": 0.03, "edge_fade": 0.35,
		"curl": 0.3, "arm_spread": 0.22,
		"arm_root": "e4eef8", "arm_edge": "e6c4ee", "arm_alpha": 0.45, "arm_edge_alpha": 0.8, "arm_bands": 0, "arm_band": "ffffff",
		"tentacles": 160, "place": "rim", "tent_len": [0.06, 0.1], "tent_radius": 0.0016, "tent_segs": 5,
		"tent_color": "eef6fc", "tent_alt": "e2d2f2", "tent_alt_share": 0.25, "tent_alpha": 0.55, "splay": 0.6, "tent_sway": 0.01,
	},
	{  # Pacific sea nettle (Chrysaora fuscescens): amber bell with darker radial
		# stripes, long maroon tentacles, long spiralling cream oral arms.
		"own": "e8902a", "centre": "f8c070", "edge": "d8781e", "rim": "b85a14", "glow": "ffd090",
		"alpha": 0.4, "rim_alpha": 0.45, "glow_power": 0.3,
		"stripes": 16, "stripe": "8a3a10", "stripe_width": 0.3, "stripe_alpha": 0.5,
		"canals": 0, "canal": "ffffff", "canal_alpha": 0.0, "spots": 0.4, "spot": "fff0d0", "muscle": 0.15, "rim_band": 0.0,
		"depth": 0.46, "dome": 2.0, "flare": -0.05, "thick": 0.2, "margin": 0.05,
		"lobes": 32, "lappet": 0.02, "notch": 0.008, "fine_lobes": 0, "fine_lappet": 0.0,
		"gonad": "f8d8a8", "gonad_alpha": 0.35,
		"arm_len": 0.95, "arm_width": 0.06, "ribbons": 2, "wave": 0.065, "ruffle": 0.35, "twist": 1.8, "spiral": 0.55,
		"curl": 0.35, "arm_spread": 0.2,
		"arm_root": "f4e2c8", "arm_edge": "fff6e8", "arm_alpha": 0.75, "arm_edge_alpha": 0.9, "arm_bands": 10, "arm_band": "d8b890",
		"tentacles": 24, "place": "notch", "tent_len": [0.7, 0.95], "tent_radius": 0.0035, "tent_segs": 22,
		"tent_color": "7a1a1a", "tent_alt": "9a2a1a", "tent_alt_share": 0.3, "tent_alpha": 0.85, "splay": 0.3, "tent_sway": 0.06,
	},
	{  # Lion's mane (Cyanea capillata): crimson to amber bell with a lobed margin,
		# masses of hair-fine tentacles in clusters, ruffled curtain oral arms.
		"own": "c8401a", "centre": "f0a040", "edge": "b8301a", "rim": "8a1a10", "glow": "ffb070",
		"alpha": 0.62, "rim_alpha": 0.45, "glow_power": 0.25,
		"stripes": 16, "stripe": "5a0a06", "stripe_width": 0.12, "stripe_alpha": 0.35,
		"canals": 0, "canal": "ffffff", "canal_alpha": 0.0, "spots": 0.12, "spot": "ffd8a8", "muscle": 0.3, "rim_band": 0.0,
		"depth": 0.4, "dome": 2.8, "flare": 0.03, "thick": 0.24, "margin": 0.06,
		"lobes": 8, "lappet": 0.04, "notch": 0.06, "fine_lobes": 28, "fine_lappet": 0.016,
		"gonad": "d86a3a", "gonad_alpha": 0.3,
		"arm_len": 0.8, "arm_width": 0.13, "ribbons": 3, "wave": 0.13, "ruffle": 0.3, "twist": 0.25, "spiral": 0.1,
		"rows_per_wave": 10.0, "arm_cols": 6, "billow": 0.5, "taper_from": 0.78, "slack": 0.03, "edge_fade": 0.3,
		"curl": 0.45, "arm_spread": 0.25,
		"arm_root": "a82a14", "arm_edge": "e0602a", "arm_alpha": 0.7, "arm_edge_alpha": 0.82, "arm_bands": 0, "arm_band": "ffffff",
		"tentacles": 104, "place": "cluster", "tent_len": [0.55, 0.95], "tent_radius": 0.0017, "tent_segs": 14,
		"tent_color": "f0b060", "tent_alt": "c8401a", "tent_alt_share": 0.35, "tent_alpha": 0.7, "splay": 0.4, "tent_sway": 0.07,
	},
	{  # Purple-striped jelly (Chrysaora colorata): pale silvery-pink bell with bold
		# purple radial stripes and rim, frilly lilac oral arms, fine reddish tentacles.
		"own": "f4d4e4", "centre": "fbe8f0", "edge": "eccadc", "rim": "6a2a8a", "glow": "d8a0f0",
		"alpha": 0.32, "rim_alpha": 0.5, "glow_power": 0.35,
		"stripes": 16, "stripe": "6a2a8a", "stripe_width": 0.2, "stripe_alpha": 0.9,
		"canals": 0, "canal": "ffffff", "canal_alpha": 0.0, "spots": 0.25, "spot": "ffffff", "muscle": 0.15, "rim_band": 0.03,
		"depth": 0.5, "dome": 2.1, "flare": -0.04, "thick": 0.2, "margin": 0.05,
		"lobes": 32, "lappet": 0.02, "notch": 0.008, "fine_lobes": 0, "fine_lappet": 0.0,
		"gonad": "e8c0e8", "gonad_alpha": 0.35,
		"arm_len": 0.95, "arm_width": 0.065, "ribbons": 2, "wave": 0.065, "ruffle": 0.35, "twist": 1.4, "spiral": 0.35,
		"curl": 0.35, "arm_spread": 0.2,
		"arm_root": "7a2aa8", "arm_edge": "c8a0e8", "arm_alpha": 0.8, "arm_edge_alpha": 0.9, "arm_bands": 0, "arm_band": "ffffff",
		"tentacles": 8, "place": "notch", "tent_len": [0.8, 1.0], "tent_radius": 0.0035, "tent_segs": 22,
		"tent_color": "a8303a", "tent_alt": "6a2a8a", "tent_alt_share": 0.25, "tent_alpha": 0.85, "splay": 0.3, "tent_sway": 0.06,
	},
]

## Draw order of the see-through parts (render_priority: higher draws later).
const STRANDS_FIRST := -3
const INNER_NEXT := -2
const ORGANS_NEXT := -1
const OUTER_LAST := 0


static func build(m: FishModel) -> void:
	var k: Dictionary = LOOKS[clampi(m.species, 0, LOOKS.size() - 1)]
	var g := _geometry(m, k)
	var own := Color.html(k["own"])
	m._body_material = m._material(own, 0.1, 0.4)
	var apex: float = g["apex"]
	var depth: float = g["depth"]
	var thick: float = k["thick"]
	# The bell.
	var outer_material := _bell_material(m, k, g, false)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _bell_mesh(g, false)
	body.material_override = outer_material
	body.extra_cull_margin = 0.3
	m.add_child(body)
	var inner := MeshInstance3D.new()
	inner.name = "Subumbrella"
	inner.mesh = _bell_mesh(g, true)
	inner.material_override = _bell_material(m, k, g, true)
	inner.extra_cull_margin = 0.3
	m.add_child(inner)
	var gonads := MeshInstance3D.new()
	gonads.name = "Gonads"
	gonads.mesh = _gonad_mesh(g)
	gonads.material_override = _organ_material(m, k, g)
	m.add_child(gonads)
	# The fin pivots carry nothing (a jelly has no fins), by the rim.
	var rx: float = g["rx"]
	m._fin_pivots(Vector3(rx * 0.85, 0.0, apex + depth * 0.8))
	# The oral arms hang from the mouth, on the tail pivot under the bell's middle.
	var mouth := apex + depth * thick + 0.004
	m._tail_pivot(Vector3(0.0, 0.0, mouth))
	var arm_material := _strand_material(m, k, g, true)
	var arms := MeshInstance3D.new()
	arms.name = "OralArms"
	arms.mesh = _arms_mesh(g, k)
	arms.material_override = arm_material
	arms.extra_cull_margin = 0.5
	m.tail.add_child(arms)
	# How far along the arms they leave the bell: they bend only past there.
	var arm_len: float = k["arm_len"]
	var inside := (apex + depth - mouth) / (arm_len * m._size.z)
	arm_material.set_shader_parameter("bend_from", clampf(inside * 0.7, 0.0, 0.6))
	var sway := Sway.new()
	sway.name = "JellySway"
	sway.model = m
	sway.materials.append(arm_material)
	sway.arms.append(arms)
	var count: int = k["tentacles"]
	if count > 0:
		var tentacle_material := _strand_material(m, k, g, false)
		tentacle_material.set_shader_parameter("pivot", Vector3(0.0, 0.0, mouth))
		var tentacles := MeshInstance3D.new()
		tentacles.name = "Tentacles"
		tentacles.mesh = _tentacles_mesh(g, k, m.species)
		tentacles.material_override = tentacle_material
		tentacles.extra_cull_margin = 0.5
		m.add_child(tentacles)
		sway.materials.append(tentacle_material)
	m.add_child(sway)
	# Every part pulses with the bell (BellPulse): strides drive it under
	# Gait.Visual.BELL_PULSE. The arms trail behind, never beating like a tail.
	m.bell = BellPulse.new()
	m.trails_tail = true
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material and material.shader in [BELL, BELL_INNER, ORGAN, STRAND] and not m._bell_pulses.has(material):
			m._bell_pulses.append(material)


## The bell's measurements (m): its rim's half width `rx` and half height `ry`,
## its `apex` (z) and `depth` (apex to rim), and the rim's lobes.
static func _geometry(m: FishModel, k: Dictionary) -> Dictionary:
	var l := m._size.z
	var depth_share: float = k["depth"]
	var lobes: int = k["lobes"]
	var fine: int = k["fine_lobes"]
	var lappet: float = k["lappet"]
	var notch: float = k["notch"]
	var fine_lappet: float = k["fine_lappet"]
	return {
		"rx": m._size.x * 0.49, "ry": m._size.y * 0.49, "l": l,
		"apex": -l * 0.5, "depth": l * depth_share,
		"dome": k["dome"], "flare": k["flare"], "thick": k["thick"], "margin": k["margin"],
		"lobes": lobes, "fine_lobes": fine,
		"lappet": lappet * l, "notch": notch * l, "fine_lappet": fine_lappet * l,
		"around": clampi(maxi(lobes, fine) * 5, 128, 160),
	}


## How far the rim reaches back at `theta` (m): out on each lobe (lappet), in
## at the notches between, with finer scallops on top.
static func _lobe(g: Dictionary, theta: float) -> float:
	var lobes: int = g["lobes"]
	var lappet: float = g["lappet"]
	var notch: float = g["notch"]
	var lobe := pow(absf(cos(theta * lobes * 0.5)), 0.6)
	var reach := lappet * lobe - notch * (1.0 - lobe)
	var fine: int = g["fine_lobes"]
	if fine > 0:
		var fine_lappet: float = g["fine_lappet"]
		reach += fine_lappet * (pow(absf(cos(theta * fine * 0.5)), 0.5) - 0.5)
	return reach


## A point on the bell's outer surface, `t` from the apex (0) to the rim (1),
## `theta` round it: a superellipse dome (flatter-topped as `dome` grows past
## 2), flaring or tucking at the rim, its lobes reaching back.
static func _outer(g: Dictionary, t: float, theta: float) -> Vector3:
	var dome: float = g["dome"]
	var flare: float = g["flare"]
	var phi := clampf(t, 0.0, 1.0) * PI * 0.5
	var rho := pow(maxf(sin(phi), 0.0), 2.0 / dome)
	var along := 1.0 - pow(maxf(cos(phi), 0.0), 2.0 / dome)
	var rim := smoothstep(0.78, 1.0, t)
	rho *= 1.0 + flare * smoothstep(0.55, 1.0, t)
	var depth: float = g["depth"]
	var apex: float = g["apex"]
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	return Vector3(cos(theta) * rx * rho, sin(theta) * ry * rho, apex + along * depth + _lobe(g, theta) * rim)


## A point on the bell's inner surface, `tau` from the rim's edge (0) to the
## middle of its roof (1): the outer surface drawn in by the jelly's thickness,
## a thin margin at the rim and thick over the top.
static func _inner(g: Dictionary, tau: float, theta: float) -> Vector3:
	var t := 1.0 - tau
	var point := _outer(g, t, theta)
	var margin: float = g["margin"]
	var shrink := margin * smoothstep(0.0, 0.12, tau)
	point.x *= 1.0 - shrink
	point.y *= 1.0 - shrink * 0.6
	var thick: float = g["thick"]
	var depth: float = g["depth"]
	point.z += thick * depth * (1.0 - t * t)
	return point


static func _bell_point(g: Dictionary, u: float, theta: float, inner: bool) -> Vector3:
	return _inner(g, u, theta) if inner else _outer(g, u, theta)


## The bell's outer (or `inner`) surface. Rows crowd toward the rim, where the
## lobes are.
static func _bell_mesh(g: Dictionary, inner: bool) -> ArrayMesh:
	var around: int = g["around"]
	var rows := 14 if inner else 26
	var buf := Buf.new()
	var apex: float = g["apex"]
	var depth: float = g["depth"]
	# Normals point out of the jelly: away from a point inside the bell for the
	# outer surface, toward one behind it (in the cavity) for the inner one.
	var inside := Vector3(0.0, 0.0, apex + depth * (1.3 if inner else 0.6))
	for i in rows + 1:
		var row := float(i) / rows
		var u := pow(row, 1.5) if inner else 1.0 - pow(1.0 - row, 1.5)
		for j in around + 1:
			var theta := TAU * j / around
			var point := _bell_point(g, u, theta, inner)
			var e := 0.002
			var at := clampf(u, 0.02, 0.98)
			var along := _bell_point(g, at + e, theta, inner) - _bell_point(g, at - e, theta, inner)
			var across := _bell_point(g, at, theta + e, inner) - _bell_point(g, at, theta - e, inner)
			var normal := along.cross(across).normalized()
			var out := (inside - point) if inner else (point - inside)
			if normal.dot(out) < 0.0:
				normal = -normal
			var t := 1.0 - u if inner else u
			buf.add(point, normal, Vector2(float(j) / around, t), Vector2.ZERO)
	for i in rows:
		for j in around:
			var a := i * (around + 1) + j
			var b := a + around + 1
			buf.tri(a, b, a + 1)
			buf.tri(a + 1, b, b + 1)
	return buf.commit()


## Four horseshoe gonads round the stomach, in the jelly between the bell's
## two surfaces, their open sides facing out.
static func _gonad_mesh(g: Dictionary) -> ArrayMesh:
	var buf := Buf.new()
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	var apex: float = g["apex"]
	var depth: float = g["depth"]
	var dome: float = g["dome"]
	var thick: float = g["thick"]
	var segments := 28
	var sides := 8
	var tube := 0.015 * rx / 0.42
	for q in 4:
		var beta := TAU * q / 4.0
		var centre := Vector2(cos(beta), sin(beta)) * 0.36
		var spine: Array[Vector3] = []
		for i in segments + 1:
			# Round from one horn of the horseshoe to the other, the gap outward.
			var psi := beta + 0.55 + (TAU - 1.1) * i / segments
			var rho2 := centre + Vector2(cos(psi), sin(psi)) * 0.17
			var rho := rho2.length()
			var along := 1.0 - pow(maxf(1.0 - pow(rho, dome), 0.0), 1.0 / dome)
			var z := apex + depth * (along + thick * (1.0 - rho * rho) * 0.55)
			spine.append(Vector3(rho2.x * rx, rho2.y * ry, z))
		var radii: Array[float] = []
		for i in segments + 1:
			var v := float(i) / segments
			radii.append(tube * (0.55 + 0.45 * sin(PI * v)))
		buf.tube(spine, radii, sides, 0.0, Vector2.ZERO, Vector3.FORWARD, 0.45)
	return buf.commit()


## The oral arms (tail pivot space, the mouth at the origin): each a tapering
## core with ruffled membrane ribbons along it, twisting (and, for some,
## spiralling round each other) as they trail back.
static func _arms_mesh(g: Dictionary, k: Dictionary) -> ArrayMesh:
	var buf := Buf.new()
	var l: float = g["l"]
	var arm_len: float = k["arm_len"]
	var length := arm_len * l
	var width: float = k["arm_width"]
	var ribbons: int = k["ribbons"]
	var wavelength: float = k["wave"]
	var ruffle: float = k["ruffle"]
	var twist: float = k["twist"]
	var spiral: float = k["spiral"]
	var curl: float = k["curl"]
	var spread: float = k["arm_spread"]
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	var rows_per_wave: float = k.get("rows_per_wave", 8.0)
	var rows := clampi(int(length / wavelength * rows_per_wave), 60, 150)
	var columns: int = k.get("arm_cols", 4)
	var billow_size: float = k.get("billow", 0.6)
	var taper_from: float = k.get("taper_from", 0.6)
	var edge_slack: float = k.get("slack", 0.0)
	var angles: Array = [-1.05, 1.05] if ribbons == 2 else [-1.5, 0.0, 1.5]
	for arm in 4:
		var seed := 0.13 + 0.23 * arm
		var heading := PI * 0.25 + PI * 0.5 * arm
		var core: Array[Vector3] = []
		var radii: Array[float] = []
		for i in rows + 1:
			var s := float(i) / rows
			core.append(_arm_core(s, length, heading, spread, spiral, rx, ry, arm))
			radii.append(width * 0.16 * (1.0 - 0.75 * s) * (0.6 + 0.4 * smoothstep(0.0, 0.08, s)))
		# The core, coarser than the frills.
		var core_path: Array[Vector3] = []
		var core_radii: Array[float] = []
		for i in range(0, rows + 1, 3):
			core_path.append(core[i])
			core_radii.append(radii[i])
		buf.tube(core_path, core_radii, 5, seed, Vector2.ZERO, Vector3(cos(heading), sin(heading), 0.0))
		# The frilly ribbons: membranes out from the core whose edges are far
		# longer than their roots, so they ruffle into folds that crowd tighter
		# toward the edge, and roll over at it.
		for r in ribbons:
			var base: float = angles[r]
			var start := buf.size()
			for i in rows + 1:
				var s := float(i) / rows
				var tangent := (core[mini(i + 1, rows)] - core[maxi(i - 1, 0)]).normalized()
				var spin := heading + spiral * TAU * s
				var out := Vector3(cos(spin), sin(spin), 0.0)
				out = (out - tangent * out.dot(tangent)).normalized()
				var side := tangent.cross(out)
				var angle := base + twist * TAU * s + 0.3 * sin(s * 7.0 + arm)
				var direction := out * cos(angle) + side * sin(angle)
				var normal := tangent.cross(direction)
				var envelope := smoothstep(0.0, 0.12, s) * (1.0 - 0.8 * pow(smoothstep(taper_from, 1.0, s), 1.5)) * (0.8 + 0.2 * sin(PI * s))
				var reach := width * envelope
				for j in columns + 1:
					var across := float(j) / columns
					# Rounded folds, the same all across so the edge never zigzags,
					# on a slow billow; both swell toward the edge, which rolls over.
					var wave := s * length / wavelength * TAU + r * 1.7 + arm * 2.3
					var billow := sin(s * length / wavelength * 0.27 * TAU + r * 2.0 + arm) * billow_size
					var fold := sin(wave) * (0.85 + 0.15 * sin(s * 11.0 + r)) + billow
					var lift := across * across * (3.0 - 2.0 * across)  # smooth from the core out
					var point: Vector3 = core[i] + direction * (radii[i] * 0.8 + reach * across * (1.0 - 0.12 * across * across))
					point += normal * (ruffle * reach * lift * fold + curl * reach * across * across)
					# Loose fabric: the edge slackens back and forth along the arm.
					point += tangent * edge_slack * reach * lift * cos(wave)
					buf.add(point, Vector3.ZERO, Vector2(seed, s), Vector2(across, r))
			for i in rows:
				for j in columns:
					var a := start + i * (columns + 1) + j
					var b := a + columns + 1
					buf.tri(a, b, a + 1, false)
					buf.tri(a + 1, b, b + 1, false)
	return buf.commit(true)


## Where an oral arm's core is `s` along it (0 at the mouth, 1 at its tip):
## out from the mouth toward `heading`, then trailing back, wavering, and
## spiralling round the others by `spiral` turns.
static func _arm_core(s: float, length: float, heading: float, spread: float, spiral: float, rx: float, ry: float, arm: int) -> Vector3:
	var spin := heading + spiral * TAU * s
	var out := spread * smoothstep(0.0, 0.45, s) * (1.0 + 0.25 * s)
	var waver := 0.04 * length * s * sin(s * 5.0 + arm * 1.9)
	return Vector3(cos(spin) * rx * out + waver, sin(spin) * ry * out + waver * 0.4, s * length)


## The tentacles (model space): thin tapering tubes from the margin, spread
## round it ("rim"), in the notches between its lobes ("notch"), or in
## clusters inside the margin by the notches ("cluster").
static func _tentacles_mesh(g: Dictionary, k: Dictionary, skin: int) -> ArrayMesh:
	var buf := Buf.new()
	var random := RandomNumberGenerator.new()
	random.seed = 7919 + skin * 101
	var count: int = k["tentacles"]
	var place: String = k["place"]
	var lengths: Array = k["tent_len"]
	var radius: float = k["tent_radius"]
	var segments: int = k["tent_segs"]
	var splay: float = k["splay"]
	var l: float = g["l"]
	var lobes: int = g["lobes"]
	var clusters := lobes
	for n in count:
		var theta := 0.0
		var root := Vector3.ZERO
		match place:
			"rim":
				theta = TAU * (n + random.randf_range(-0.3, 0.3)) / count
				root = _inner(g, 0.015, theta)
			"notch":
				var notch := floori((n + 0.5) * lobes / float(count))
				theta = (2.0 * notch + 1.0) * PI / lobes
				root = _inner(g, 0.03, theta)
			_:
				var cluster := n % clusters
				theta = (2.0 * cluster + 1.0) * PI / lobes + random.randf_range(-0.2, 0.2)
				root = _inner(g, random.randf_range(0.02, 0.2), theta)
		var length := l * random.randf_range(lengths[0], lengths[1])
		var out := Vector3(root.x, root.y, 0.0).normalized()
		var side := Vector3(-out.y, out.x, 0.0)
		var seed := random.randf()
		var path: Array[Vector3] = []
		var radii: Array[float] = []
		for i in segments + 1:
			var s := float(i) / segments
			var point := root + Vector3(0.0, 0.0, length * s)
			point += out * splay * length * 0.3 * pow(smoothstep(0.0, 1.0, s), 1.2)
			point += side * 0.05 * length * s * sin(s * 4.0 + seed * TAU)
			path.append(point)
			radii.append(radius * (1.0 - 0.7 * s))
		buf.tube(path, radii, 3, seed, Vector2(0.0, length), out)
	return buf.commit()


static func _bell_material(m: FishModel, k: Dictionary, g: Dictionary, inner: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BELL_INNER if inner else BELL
	var own := Color.html(k["own"])
	material.set_shader_parameter("albedo", own)
	material.set_shader_parameter("own", own)
	material.set_shader_parameter("centre_color", Color.html(k["centre"]))
	material.set_shader_parameter("edge_color", Color.html(k["edge"]))
	material.set_shader_parameter("rim_color", Color.html(k["rim"]))
	material.set_shader_parameter("glow_color", Color.html(k["glow"]))
	var alpha: float = k["alpha"]
	material.set_shader_parameter("base_alpha", alpha * (0.6 if inner else 1.0))
	material.set_shader_parameter("rim_alpha", k["rim_alpha"])
	material.set_shader_parameter("glow", k["glow_power"])
	material.set_shader_parameter("stripes", float(k["stripes"]))
	material.set_shader_parameter("stripe_color", Color.html(k["stripe"]))
	material.set_shader_parameter("stripe_width", k["stripe_width"])
	var stripe_alpha: float = k["stripe_alpha"]
	material.set_shader_parameter("stripe_alpha", stripe_alpha * (0.5 if inner else 1.0))
	material.set_shader_parameter("canals", float(k["canals"]) if inner else 0.0)
	material.set_shader_parameter("canal_color", Color.html(k["canal"]))
	material.set_shader_parameter("canal_alpha", k["canal_alpha"])
	material.set_shader_parameter("spots", 0.0 if inner else float(k["spots"]))
	material.set_shader_parameter("spot_color", Color.html(k["spot"]))
	material.set_shader_parameter("rim_band", 0.0 if inner else float(k["rim_band"]))
	material.set_shader_parameter("muscle", k["muscle"])
	material.set_shader_parameter("inner", inner)
	_pulse_params(material, g)
	material.render_priority = INNER_NEXT if inner else OUTER_LAST
	m._skins.append(material)
	m._waving.append(material)
	return material


static func _organ_material(m: FishModel, k: Dictionary, g: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ORGAN
	material.set_shader_parameter("color", Color.html(k["gonad"]))
	material.set_shader_parameter("opacity", k["gonad_alpha"])
	_pulse_params(material, g)
	material.render_priority = ORGANS_NEXT
	m._waving.append(material)
	return material


## The arms' (`arms`, on the tail pivot) or the tentacles' look.
static func _strand_material(m: FishModel, k: Dictionary, g: Dictionary, arms: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STRAND
	var own := Color.html(k["own"])
	material.set_shader_parameter("albedo", own)
	material.set_shader_parameter("own", own)
	material.set_shader_parameter("glow_color", Color.html(k["glow"]))
	material.set_shader_parameter("on_tail", arms)
	if arms:
		material.set_shader_parameter("root_color", Color.html(k["arm_root"]))
		material.set_shader_parameter("edge_color", Color.html(k["arm_edge"]))
		material.set_shader_parameter("core_alpha", k["arm_alpha"])
		material.set_shader_parameter("edge_alpha", k["arm_edge_alpha"])
		material.set_shader_parameter("edge_fade", k.get("edge_fade", 0.0))
		material.set_shader_parameter("bands", float(k["arm_bands"]))
		material.set_shader_parameter("band_color", Color.html(k["arm_band"]))
		material.set_shader_parameter("tint_share", 0.45)
		material.set_shader_parameter("sway", 0.025)
		material.set_shader_parameter("sway_waves", 1.1)
		material.set_shader_parameter("ripple", 0.006)
		var wave: float = k["wave"]
		var arm_len: float = k["arm_len"]
		var l: float = g["l"]
		material.set_shader_parameter("ripple_waves", arm_len * l / wave * 0.5)
		material.set_shader_parameter("glow", 0.25)
	else:
		var color := Color.html(k["tent_color"])
		material.set_shader_parameter("root_color", color)
		material.set_shader_parameter("edge_color", color)
		material.set_shader_parameter("alt_color", Color.html(k["tent_alt"]))
		material.set_shader_parameter("alt_share", k["tent_alt_share"])
		material.set_shader_parameter("core_alpha", k["tent_alpha"])
		material.set_shader_parameter("edge_alpha", k["tent_alpha"])
		material.set_shader_parameter("tint_share", 0.3)
		material.set_shader_parameter("pulsing", true)
		material.set_shader_parameter("swing_share", 0.8)
		material.set_shader_parameter("sway", k["tent_sway"])
		material.set_shader_parameter("sway_waves", 1.4)
		material.set_shader_parameter("ripple", 0.0)
		material.set_shader_parameter("glow", 0.15)
	_pulse_params(material, g)
	material.render_priority = STRANDS_FIRST
	m._skins.append(material)
	m._waving.append(material)
	return material


static func _pulse_params(material: ShaderMaterial, g: Dictionary) -> void:
	material.set_shader_parameter("bell_apex", g["apex"])
	material.set_shader_parameter("bell_depth", g["depth"])


## Feeds the arms' and tentacles' shaders the tail pivot's swing each frame,
## so they bend round after it from their roots (jelly_strand.gdshader). The
## arms draw the stride cue themselves, bent as they are, so the plain-part
## overlay FishModel gives the tail's meshes (unbent) comes off them.
class Sway:
	extends Node

	var model: FishModel
	var materials: Array[ShaderMaterial] = []
	var arms: Array[MeshInstance3D] = []

	func _init() -> void:
		process_priority = 100  # after whatever swings the tail this frame

	func _process(_delta: float) -> void:
		if model == null or model.tail == null:
			return
		var swing := Vector2(model.tail.rotation.x, model.tail.rotation.y)
		for material in materials:
			material.set_shader_parameter("swing", swing)
		for part in arms:
			var overlay := part.material_overlay as ShaderMaterial
			if overlay and overlay.shader == FishModel.STRIDE_OVERLAY:
				part.material_overlay = null


## Mesh arrays built up a vertex and a triangle at a time.
class Buf:
	extends RefCounted

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()

	func size() -> int:
		return vertices.size()

	func add(point: Vector3, normal: Vector3, uv: Vector2, uv2: Vector2) -> int:
		vertices.append(point)
		normals.append(normal)
		uvs.append(uv)
		uv2s.append(uv2)
		return vertices.size() - 1

	## A triangle, wound to face the way its corners' normals point (unless
	## `orient` is false: the normals come from the winding, commit(true)).
	func tri(a: int, b: int, c: int, orient := true) -> void:
		if orient:
			var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			if not JellyModel.CLOCKWISE:
				face = -face
			if face.dot(normals[a] + normals[b] + normals[c]) < 0.0:
				var swap := b
				b = c
				c = swap
		indices.append(a)
		indices.append(b)
		indices.append(c)

	## A tube along `path` (`radii` thick), `sides` round, its UV.x `seed`,
	## UV.y 0 to 1 along it and UV2 `uv2`. `reference` sets which way its first
	## side faces; `flat` squashes it along Z.
	func tube(path: Array[Vector3], radii: Array[float], sides: int, seed: float, uv2: Vector2, reference: Vector3, flat := 1.0) -> void:
		var count := path.size()
		var start := vertices.size()
		var frame_normal := Vector3.ZERO
		for i in count:
			var tangent := (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
			if i == 0:
				frame_normal = reference - tangent * reference.dot(tangent)
				if frame_normal.length() < 0.01:
					frame_normal = Vector3.UP - tangent * tangent.y
			else:
				frame_normal = frame_normal - tangent * frame_normal.dot(tangent)
			frame_normal = frame_normal.normalized()
			var binormal := tangent.cross(frame_normal)
			var s := float(i) / (count - 1)
			for j in sides:
				var angle := TAU * j / sides
				var direction := frame_normal * cos(angle) + binormal * sin(angle)
				var offset := direction * radii[i]
				offset.z *= flat
				var normal := Vector3(direction.x, direction.y, direction.z / flat).normalized()
				add(path[i] + offset, normal, Vector2(seed, s), uv2)
		for i in count - 1:
			for j in sides:
				var a := start + i * sides + j
				var b := start + i * sides + (j + 1) % sides
				var c := a + sides
				var d := b + sides
				tri(a, c, b)
				tri(b, c, d)

	## The mesh; `smooth_normals` works the normals out from the triangles.
	func commit(smooth_normals := false) -> ArrayMesh:
		if smooth_normals:
			for i in normals.size():
				normals[i] = Vector3.ZERO
			for i in range(0, indices.size(), 3):
				var a := indices[i]
				var b := indices[i + 1]
				var c := indices[i + 2]
				var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
				if not JellyModel.CLOCKWISE:
					face = -face
				normals[a] += face
				normals[b] += face
				normals[c] += face
			for i in normals.size():
				normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0 else Vector3.UP
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
