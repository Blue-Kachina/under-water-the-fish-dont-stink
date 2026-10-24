class_name WhaleModel
extends RefCounted
## The Breachers' baby whales (FishModel.build hands it here): species m.species
## of FishCharacter.SPECIES[FishCharacter.FishClass.BREACHER], in its order:
## humpback, orca, beluga, sperm whale and blue whale calves.
##
## Whales swim with horizontal flukes that beat up and down (Gait.Visual.FLUKE),
## so the body bends in its vertical plane: the tail pivot's pitch bends the
## back half of the body (FishModel._bend_body; fish_bend.gdshaderinc bends
## about any axis), and the flukes ride the pivot.
##
## One smooth lofted body (_body_mesh): superelliptic slices, a calf's big head
## and chubby middle narrowing to a tail stock that is taller than it is wide.
## Each species' head is shaped into the slices (the humpback's flat rostrum,
## the beluga's melon, the sperm whale's boxy forehead over an underslung jaw,
## the blue whale's broad U-shaped head) and its relief into the skin (the
## beluga's dorsal ridge, the sperm whale's hump and knuckles, the tail stock's
## keels). The hide is painted in whale_calf_skin.gdshader (patches, mottling,
## wrinkles, tubercles, throat pleats, blowholes, mouth line); the flippers
## (_flipper) are lofted airfoils and the flukes and dorsal fins thick blades
## (_fin), painted in whale_calf_fin.gdshader.

const SKIN_SHADER := preload("res://shaders/whale_calf_skin.gdshader")
const FIN_SHADER := preload("res://shaders/whale_calf_fin.gdshader")

## Body slices nose to tail, and points round each.
const ROWS := 110
const HALF := 60
const AROUND := HALF * 2

## Shared by the calves: a big rounded head, the girth just behind the
## flippers, a tall narrow tail stock. Tables run nose 0 to tail 1
## (FishModel._sample): half width (of the widest), and the top and bottom (of
## half the hitbox's height).
const CALF_SHAPE := {
	"width": 0.235,
	"w_tab": [0.6, 0.86, 0.97, 1.0, 0.98, 0.9, 0.74, 0.5, 0.29, 0.14, 0.075],
	"top_tab": [0.34, 0.72, 0.9, 0.98, 1.0, 0.96, 0.86, 0.72, 0.58, 0.46, 0.34],
	"bot_tab": [-0.42, -0.86, -1.06, -1.14, -1.12, -1.02, -0.86, -0.68, -0.52, -0.4, -0.3],
	"nose": 0.07, "nose_w": 0.1, "pointed": false,
	"n_head": Vector2(2.1, 2.2), "n_body": Vector2(2.05, 2.1), "n_stock": Vector2(1.9, 1.9),
	"box": 0.0, "melon": 0.0, "neck": 0.0, "jaw": 0.0,
	"dorsal_ridge": 0.0, "hump": 0.0, "hump_a": 0.62, "knuckles": 0,
	"keel": 0.012, "rostrum_ridge": 0.0,
	"eye": 0.011, "eye_a": 0.2, "eye_s": 0.56, "iris": Color(0.22, 0.16, 0.12),
	"mouth_tip_s": 0.5, "mouth_s": 0.6, "mouth_a": 0.19, "mouth_arch": 0.04, "mouth_w": 0.0045,
	"blow_a": 0.14, "blow_pair": 1.0, "blow_x": 0.0,
	"pec_a": 0.27, "pec_s": 0.74, "pec_len": 0.16, "pec_chord": [0.07, 0.075, 0.07, 0.06, 0.045, 0.03],
	"pec_out": Vector3(1.0, -0.55, 0.32), "pec_sweep": Vector3(0.0, -0.02, 0.22), "pec_thick": 0.24, "pec_knobs": 0.0,
	"dorsal": Vector2(0.0, 0.0), "dorsal_h": 0.0, "dorsal_angles": [-0.7, -0.85, -1.05, -1.35, -1.6],
	"fluke_len": 0.25, "fluke_angles": [-0.1, -0.3, -0.55, -0.9, -1.3], "fluke_lengths": [0.55, 1.0, 0.6, 0.3, 0.12],
	"fluke_curl": Vector3(0.0, 0.0, 0.08), "fluke_scallop": 0.0,
}

## Each species (FishCharacter.SPECIES order): colours, pattern and any shape
## it changes from CALF_SHAPE.
const LOOKS := [
	{  # Humpback calf: near-black over a white-mottled belly, a flat knobbly
		# rostrum, throat pleats, a small dorsal on a hump, very long
		# white-edged flippers with knobs along their leading edge.
		"back": Color("23262b"), "flank": Color("3a3e45"), "belly": Color("e4e6e6"),
		"belly_s": 0.66, "belly_mottle": 1.0, "mottle": 0.0, "mottle_color": Color("8a929a"),
		"tubercles": 1.0, "pleats": 1.0, "pleat_s": 0.7, "pleat_a": 0.46, "wrinkle": 0.0,
		"orca": 0.0, "patch": Color("e8c0a0"), "saddle": 0.0, "roughness": 0.4,
		"fin_under": Color("e8eaea"), "fin_edge": Color("e8eaea"), "fin_edge_w": 0.3, "fin_white": 0.6,
		"top_tab": [0.1, 0.44, 0.74, 0.96, 1, 0.98, 0.9, 0.72, 0.58, 0.46, 0.34],
		"bot_tab": [-0.5, -0.92, -1.1, -1.16, -1.12, -1, -0.82, -0.66, -0.52, -0.4, -0.3],
		"w_tab": [0.62, 0.86, 0.96, 1, 0.98, 0.9, 0.74, 0.52, 0.294, 0.145, 0.075],
		"nose": 0.05, "nose_w": 0.15, "pointed": true, "n_head": Vector2(2.3, 2.0),
		"rostrum_ridge": 0.006, "hump": 0.022, "hump_a": 0.64,
		"mouth_tip_s": 0.46, "mouth_s": 0.58, "mouth_a": 0.21, "mouth_arch": 0.07,
		"eye_a": 0.225, "eye_s": 0.6,
		"pec_a": 0.25, "pec_s": 0.7, "pec_len": 0.36, "pec_chord": [0.075, 0.08, 0.075, 0.068, 0.058, 0.045, 0.03],
		"pec_out": Vector3(1.0, -0.42, 0.62), "pec_sweep": Vector3(0.0, 0.02, 0.12), "pec_thick": 0.2, "pec_knobs": 0.18,
		"dorsal": Vector2(0.64, 0.71), "dorsal_h": 0.24, "dorsal_angles": [-0.9, -1.0, -1.2, -1.45, -1.65],
		"fluke_len": 0.23, "fluke_scallop": 0.05,
	},
	{  # Orca calf: black, its patches still peachy-orange (eye patch, chin and
		# belly sweeping up into a flank lobe), a faint grey saddle, a curved
		# dorsal, round paddle flippers.
		"back": Color("16171a"), "flank": Color("1c1d21"), "belly": Color("f0c8a8"),
		"belly_s": 0.72, "belly_mottle": 0.0, "mottle": 0.0, "mottle_color": Color("2a2c30"),
		"tubercles": 0.0, "pleats": 0.0, "pleat_s": 0.7, "pleat_a": 0.4, "wrinkle": 0.0,
		"orca": 1.0, "patch": Color("f2c4a0"), "saddle": 0.25, "roughness": 0.3,
		"fin_under": Color("f0c8a8"), "fin_edge": Color("16171a"), "fin_edge_w": 0.0, "fin_white": 0.0,
		"top_tab": [0.36, 0.72, 0.9, 0.98, 1, 0.97, 0.86, 0.7, 0.58, 0.46, 0.34],
		"bot_tab": [-0.34, -0.8, -1.02, -1.12, -1.12, -1.03, -0.86, -0.66, -0.52, -0.4, -0.3],
		"nose": 0.085, "nose_w": 0.1, "pointed": true, "n_head": Vector2(2.0, 2.1),
		"mouth_tip_s": 0.56, "mouth_s": 0.62, "mouth_a": 0.12, "mouth_arch": 0.0, "mouth_w": 0.0035,
		"eye_a": 0.15, "eye_s": 0.5, "blow_a": 0.17, "blow_pair": 0.0,
		"pec_a": 0.25, "pec_s": 0.78, "pec_len": 0.13, "pec_chord": [0.08, 0.1, 0.11, 0.105, 0.085, 0.05],
		"pec_out": Vector3(1.0, -0.8, 0.45), "pec_sweep": Vector3(0.0, 0.0, 0.08), "pec_thick": 0.22,
		"dorsal": Vector2(0.43, 0.56), "dorsal_h": 0.62, "dorsal_angles": [-0.62, -0.76, -0.98, -1.3, -1.7],
		"fluke_len": 0.23,
	},
	{  # Beluga calf: grey (they whiten as they grow), a soft rounded melon over
		# a short beak, a supple neck crease, no dorsal fin but a low ridge,
		# small paddle flippers, flukes with a rounded trailing edge.
		"back": Color("6f7476"), "flank": Color("8a8f91"), "belly": Color("a8acad"),
		"belly_s": 0.7, "belly_mottle": 0.0, "mottle": 0.25, "mottle_color": Color("9aa0a2"),
		"tubercles": 0.0, "pleats": 0.0, "pleat_s": 0.7, "pleat_a": 0.4, "wrinkle": 0.35,
		"orca": 0.0, "patch": Color("ffffff"), "saddle": 0.0, "roughness": 0.36,
		"fin_under": Color("9a9ea0"), "fin_edge": Color("55595b"), "fin_edge_w": 0.2, "fin_white": 0.0,
		"top_tab": [0.2, 0.9, 1.06, 0.95, 0.97, 0.98, 0.88, 0.7, 0.58, 0.46, 0.34],
		"bot_tab": [-0.3, -0.72, -0.96, -1.08, -1.12, -1.04, -0.86, -0.66, -0.52, -0.4, -0.3],
		"w_tab": [0.5, 0.86, 0.92, 0.9, 0.98, 0.92, 0.76, 0.54, 0.304, 0.145, 0.075],
		"nose": 0.06, "nose_w": 0.08, "n_head": Vector2(2.0, 2.0), "melon": 0.05, "neck": 0.05,
		"dorsal_ridge": 0.009, "keel": 0.008,
		"mouth_tip_s": 0.58, "mouth_s": 0.6, "mouth_a": 0.1, "mouth_arch": -0.02, "mouth_w": 0.0035,
		"eye_a": 0.13, "eye_s": 0.52, "blow_a": 0.2, "blow_pair": 0.0,
		"pec_a": 0.27, "pec_s": 0.76, "pec_len": 0.11, "pec_chord": [0.065, 0.085, 0.09, 0.085, 0.07, 0.04],
		"pec_out": Vector3(1.0, -0.75, 0.3), "pec_sweep": Vector3(0.0, 0.03, 0.08), "pec_thick": 0.22,
		"fluke_len": 0.22, "fluke_angles": [-0.12, -0.34, -0.62, -0.95, -1.3], "fluke_lengths": [0.58, 1.0, 0.75, 0.45, 0.2],
	},
	{  # Sperm whale calf: a boxy, squared-off forehead over a narrow underslung
		# jaw with pale lips, wrinkled dark-grey skin, a low hump and a row of
		# knuckles down its back, small flippers, broad triangular flukes.
		"back": Color("3a3c3f"), "flank": Color("4a4c50"), "belly": Color("6a6c70"),
		"belly_s": 0.78, "belly_mottle": 0.0, "mottle": 0.15, "mottle_color": Color("5a5c60"),
		"tubercles": 0.0, "pleats": 0.0, "pleat_s": 0.7, "pleat_a": 0.4, "wrinkle": 1.0,
		"orca": 0.0, "patch": Color("ffffff"), "saddle": 0.0, "roughness": 0.55,
		"fin_under": Color("4a4c50"), "fin_edge": Color("2a2c2e"), "fin_edge_w": 0.25, "fin_white": 0.0,
		"top_tab": [0.92, 0.98, 1, 0.98, 0.95, 0.92, 0.84, 0.7, 0.58, 0.46, 0.34],
		"bot_tab": [-0.5, -0.72, -0.88, -1.02, -1.1, -1.04, -0.86, -0.66, -0.52, -0.4, -0.3],
		"w_tab": [0.68, 0.8, 0.86, 0.92, 0.98, 0.92, 0.76, 0.54, 0.304, 0.145, 0.075],
		"width": 0.225, "nose": 0.035, "nose_w": 0.045, "n_head": Vector2(3.2, 2.6), "box": 1.0, "jaw": 1.0,
		"hump": 0.016, "hump_a": 0.6, "knuckles": 5, "keel": 0.014,
		"mouth_tip_s": 0.94, "mouth_s": 0.88, "mouth_a": 0.3, "mouth_arch": 0.0, "mouth_w": 0.0035,
		"eye_a": 0.31, "eye_s": 0.68, "blow_a": 0.025, "blow_pair": 0.0, "blow_x": -0.05,
		"pec_a": 0.36, "pec_s": 0.78, "pec_len": 0.09, "pec_chord": [0.055, 0.065, 0.065, 0.055, 0.04, 0.025],
		"pec_out": Vector3(1.0, -0.7, 0.3), "pec_sweep": Vector3(0.0, 0.0, 0.06), "pec_thick": 0.24,
		"fluke_len": 0.25, "fluke_angles": [-0.12, -0.3, -0.55, -0.9, -1.3], "fluke_lengths": [0.62, 1.0, 0.62, 0.3, 0.12],
	},
	{  # Blue whale calf: mottled blue-grey, a broad flat U-shaped head with a
		# splashguard ridge, throat pleats, a tiny dorsal far back, slender
		# flippers.
		"back": Color("4a5a6c"), "flank": Color("6a7c8e"), "belly": Color("a8b4bc"),
		"belly_s": 0.72, "belly_mottle": 0.0, "mottle": 0.75, "mottle_color": Color("9aacbc"),
		"tubercles": 0.0, "pleats": 1.0, "pleat_s": 0.72, "pleat_a": 0.44, "wrinkle": 0.0,
		"orca": 0.0, "patch": Color("ffffff"), "saddle": 0.0, "roughness": 0.36,
		"fin_under": Color("b0bcc4"), "fin_edge": Color("8a9cac"), "fin_edge_w": 0.25, "fin_white": 0.0,
		"top_tab": [0.12, 0.42, 0.7, 0.94, 1, 0.97, 0.86, 0.7, 0.58, 0.46, 0.34],
		"bot_tab": [-0.36, -0.76, -0.98, -1.08, -1.08, -0.98, -0.82, -0.66, -0.52, -0.4, -0.3],
		"w_tab": [0.86, 0.95, 0.99, 1, 0.97, 0.88, 0.72, 0.5, 0.285, 0.136, 0.075],
		"width": 0.225, "nose": 0.04, "nose_w": 0.07, "n_head": Vector2(2.8, 2.0), "rostrum_ridge": 0.007,
		"mouth_tip_s": 0.5, "mouth_s": 0.58, "mouth_a": 0.21, "mouth_arch": 0.045,
		"eye_a": 0.22, "eye_s": 0.59, "blow_a": 0.15, "blow_pair": 1.0,
		"pec_a": 0.27, "pec_s": 0.74, "pec_len": 0.15, "pec_chord": [0.05, 0.055, 0.05, 0.042, 0.032, 0.02],
		"pec_out": Vector3(1.0, -0.6, 0.45), "pec_sweep": Vector3(0.0, 0.0, 0.12), "pec_thick": 0.22,
		"dorsal": Vector2(0.76, 0.8), "dorsal_h": 0.15, "dorsal_angles": [-0.85, -1.0, -1.25, -1.5, -1.7],
		"fluke_len": 0.2,
	},
]


static func build(m: FishModel) -> void:
	var look := _look(m.species)
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var ends := Vector2(-l * 0.5, l * 0.3)
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var back: Color = look.back
	var flank: Color = look.flank
	var gain := Vector3.ONE * minf((_ratio(flank.r, back.r) + _ratio(flank.g, back.g) + _ratio(flank.b, back.b)) / 3.0, 4.0)
	m.fluke = true
	m._body_material = m._material(back, 0.4)  # for set_body_color(); the skin does the shading
	m.bend_share = 0.6

	# The body.
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("albedo", back)
	skin.set_shader_parameter("flank_gain", gain)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("belly_s", look.belly_s)
	skin.set_shader_parameter("belly_mottle", look.belly_mottle)
	skin.set_shader_parameter("mottle", look.mottle)
	skin.set_shader_parameter("mottle_color", look.mottle_color)
	skin.set_shader_parameter("tubercles", look.tubercles)
	skin.set_shader_parameter("wrinkle", look.wrinkle)
	skin.set_shader_parameter("pleats", look.pleats)
	skin.set_shader_parameter("pleat_s", look.pleat_s)
	skin.set_shader_parameter("pleat_z", at.call(look.pleat_a))
	skin.set_shader_parameter("orca", look.orca)
	skin.set_shader_parameter("patch_color", look.patch)
	skin.set_shader_parameter("saddle", look.saddle)
	skin.set_shader_parameter("roughness", look.roughness)
	skin.set_shader_parameter("nose_z", ends.x)
	skin.set_shader_parameter("tail_z", ends.y)
	skin.set_shader_parameter("mouth_tip_s", look.mouth_tip_s)
	skin.set_shader_parameter("mouth_s", look.mouth_s)
	skin.set_shader_parameter("mouth_corner", look.mouth_a)
	skin.set_shader_parameter("mouth_arch", look.mouth_arch)
	skin.set_shader_parameter("mouth_width", look.mouth_w)
	skin.set_shader_parameter("pale_lips", look.box)
	var blow: Vector3 = _surface(look, look.blow_a, 0.0, w, h, ends)[0]
	blow.x = float(look.blow_x) * w
	skin.set_shader_parameter("blow_pos", blow)
	skin.set_shader_parameter("blow_pair", look.blow_pair)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(look, ends, w, h)
	body.material_override = skin
	m.add_child(body)

	# Fins, flippers and flukes: in the body's colour (tinted with it), pale
	# underneath where the species is.
	var fins := ShaderMaterial.new()
	fins.shader = FIN_SHADER
	fins.set_shader_parameter("albedo", back)
	fins.set_shader_parameter("flank_gain", gain)
	fins.set_shader_parameter("under_color", look.fin_under)
	fins.set_shader_parameter("edge_color", look.fin_edge)
	fins.set_shader_parameter("edge_width", look.fin_edge_w)
	fins.set_shader_parameter("mottle", look.mottle)
	fins.set_shader_parameter("mottle_color", look.mottle_color)
	fins.set_shader_parameter("roughness", look.roughness)
	m._skins.append(fins)
	var flippers := fins.duplicate() as ShaderMaterial
	flippers.set_shader_parameter("flipper", true)
	flippers.set_shader_parameter("white_top", look.fin_white)
	m._skins.append(flippers)
	var top := func(along: float) -> Vector3: return _surface(look, along, 0.0, w, h, ends)[0]
	var bent: Array = []
	var dorsal: Vector2 = look.dorsal
	if float(look.dorsal_h) > 0.0:
		var dorsal_h: float = h * float(look.dorsal_h)
		var inset := Vector3(0.0, -0.012, 0.0)
		bent.append(_fin(m, fins, top.call(dorsal.x) + inset, top.call(dorsal.y) + inset, Vector3.UP,
				look.dorsal_angles, [dorsal_h, dorsal_h * 0.9, dorsal_h * 0.62, dorsal_h * 0.3, dorsal_h * 0.08],
				Vector3(0.0, 0.0, 0.1), 0.022, 16, 8))

	# Flippers low behind the head, on the swim animation's pivots.
	var pectoral := _surface(look, look.pec_a, look.pec_s, w, h, ends)
	var pec_at: Vector3 = (pectoral[0] as Vector3) - (pectoral[1] as Vector3) * 0.02
	m._fin_pivots(pec_at)
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		var out: Vector3 = look.pec_out
		var sweep: Vector3 = look.pec_sweep
		_flipper(pivot, flippers, Vector3.ZERO, out * Vector3(side, 1.0, 1.0), Vector3.BACK, float(look.pec_len),
				look.pec_chord, float(look.pec_thick), float(look.pec_knobs), sweep * Vector3(side, 1.0, 1.0))

	# The flukes: two lobes out across the tail stock, flat, swept back to
	# pointed tips with a notch between them, on the tail pivot.
	var tail_a := 0.94
	var stock := _section(look, tail_a, w, h)
	m._tail_pivot(Vector3(0.0, stock[3], at.call(tail_a)))
	var fluke_len: float = float(look.fluke_len)
	var lengths: Array = []
	for k: float in look.fluke_lengths:
		lengths.append(k * fluke_len)
	var root := 0.07
	for side: float in [-1.0, 1.0]:
		var angles: Array = []
		for a: float in look.fluke_angles:
			angles.append(a)
		var lobe := _fin(m.tail, fins, Vector3(0.0, 0.0, -root * 0.6), Vector3(0.0, 0.0, root * 0.4), Vector3(side, 0.0, 0.0),
				angles, lengths, look.fluke_curl, 0.022, 22, 10, float(look.fluke_scallop))
		lobe.name = "Fluke"
	if float(look.jaw) > 0.0:
		_jaw(m, fins, look, w, h, ends)
	m._bend_body(at.call(0.48), bent)

	# Small eyes low on the head, near the corner of the mouth.
	var eye_r: float = look.eye
	var eye := _surface(look, look.eye_a, look.eye_s, w, h, ends)
	var eye_at: Vector3 = (eye[0] as Vector3) - (eye[1] as Vector3) * eye_r * 0.55
	skin.set_shader_parameter("eye_pos", eye[0])
	skin.set_shader_parameter("eye_radius", eye_r)
	for side: float in [-1.0, 1.0]:
		var normal: Vector3 = eye[1]
		var gaze := (normal + Vector3(0.0, 0.0, -0.25)).normalized() * Vector3(side, 1.0, 1.0)
		var ball := m._real_eye(eye_at * Vector3(side, 1.0, 1.0), eye_r, gaze, look.iris, 0.55)
		var material := ball.material_override as ShaderMaterial
		material.set_shader_parameter("rim_color", Color(0.03, 0.03, 0.035))
		material.set_shader_parameter("pupil_stretch", 1.2)
		material.set_shader_parameter("sheen", 0.45)


## Species `species`' look: its own entries over CALF_SHAPE's.
static func _look(species: int) -> Dictionary:
	var look: Dictionary = CALF_SHAPE.duplicate()
	look.merge(LOOKS[clampi(species, 0, LOOKS.size() - 1)], true)
	return look


## How many times brighter `to` is than `from` (sRGB channels, in linear light).
static func _ratio(to: float, from: float) -> float:
	var a := pow(maxf(to, 0.0), 2.2)
	var b := pow(maxf(from, 0.0), 2.2)
	return clampf(a / maxf(b, 0.002), 1.0, 6.0)


static func _spow(value: float, power: float) -> float:
	return signf(value) * pow(absf(value), power)


## The body's slice `along` it (nose 0, tail 1): half width, height of its top
## and of its bottom from its middle, its middle's height, and how square its
## top and bottom halves are (superellipse exponents, 2 an oval).
static func _section(look: Dictionary, along: float, w: float, h: float) -> PackedFloat32Array:
	var half_w := w * float(look.width) * FishModel._sample(look.w_tab, along)
	var top := h * 0.5 * FishModel._sample(look.top_tab, along)
	var bot := h * 0.5 * FishModel._sample(look.bot_tab, along)
	# The beluga's melon swells the forehead; its neck crease pinches behind.
	var melon: float = look.melon
	if melon > 0.0:
		top += h * melon * exp(-pow((along - 0.13) / 0.06, 2.0))
	var neck: float = look.neck
	if neck > 0.0:
		var pinch := exp(-pow((along - 0.235) / 0.035, 2.0)) * neck
		top -= h * pinch * 0.5
		half_w -= w * pinch * 0.12
	var mid := lerpf(bot, top, 0.45)
	# The nose closes the slices: over `nose` in height, and over `nose_w` across.
	# A boxy head (the sperm whale's) closes only right at its front, and its
	# lower half closes further back, under the overhanging forehead.
	var pointed: bool = look.get("pointed", false)
	var box: float = look.box
	var cap := _nose_cap(along, look.nose, pointed)
	var cap_w := _nose_cap(along, look.nose_w, pointed)
	var cap_low := cap
	if box > 0.0:
		cap_low = _nose_cap(along, lerpf(float(look.nose), 0.16, box), false)
	if along > 0.97:
		var end := sqrt(maxf(1.0 - pow((along - 0.97) / 0.03, 2.0), 0.0))
		cap *= end
		cap_w *= end
		cap_low *= end
	var head := 1.0 - smoothstep(0.1, 0.32, along)
	var stock := smoothstep(0.7, 0.92, along)
	var n_head: Vector2 = look.n_head
	var n_body: Vector2 = look.n_body
	var n_stock: Vector2 = look.n_stock
	var n := n_body.lerp(n_head, head).lerp(n_stock, stock)
	return PackedFloat32Array([half_w * cap_w, (top - mid) * cap, (mid - bot) * cap_low, mid, n.x, n.y])


## How far open the body is `along` it near the nose, closing over `nose`:
## round, or a cone if `pointed`.
static func _nose_cap(along: float, nose: float, pointed: bool) -> float:
	if along >= nose:
		return 1.0
	var x := along / nose
	var cap := x * (2.0 - x)
	return pow(cap, 0.75) if pointed else sqrt(cap)


## A slice of the body `along` it, without the relief: its points round from
## the top (down the right side first), their outward normals, how far round
## each is (0 the top to 1 the bottom) and the half round (m).
static func _ring(look: Dictionary, along: float, w: float, h: float) -> Array:
	var section := _section(look, along, w, h)
	var points := PackedVector2Array()
	for k in AROUND:
		var t := TAU * k / AROUND
		var up := cos(t)
		var n := section[4] if up >= 0.0 else section[5]
		var x := section[0] * _spow(sin(t), 2.0 / n)
		var y := section[3] + (section[1] if up >= 0.0 else section[2]) * _spow(up, 2.0 / n)
		points.append(Vector2(x, y))
	var half := HALF
	var arcs := PackedFloat32Array()
	arcs.resize(AROUND)
	arcs[0] = 0.0
	for k in range(1, half + 1):
		arcs[k] = arcs[k - 1] + points[k].distance_to(points[k - 1])
	for k in range(half + 1, AROUND):
		arcs[k] = arcs[AROUND - k]
	var half_round := arcs[half]
	var round_share := PackedFloat32Array()
	var normals := PackedVector2Array()
	for k in AROUND:
		round_share.append(arcs[k] / half_round if half_round > 1e-6 else minf(k, AROUND - k) / float(half))
		var tangent := points[(k + 1) % AROUND] - points[(k + AROUND - 1) % AROUND]
		normals.append(Vector2(-tangent.y, tangent.x).normalized())
	return [points, normals, round_share, half_round]


## How far the relief raises the skin (m) `along` the body, `s` round it (0
## top, 1 bottom): the rostrum's median ridge, the beluga's dorsal ridge, the
## hump and the sperm whale's knuckles down the back, and the tail stock's
## keels above and below.
static func _relief(look: Dictionary, along: float, s: float, half_round: float) -> float:
	var raised := 0.0
	var spine := s * half_round / 0.014
	var spine_line := exp(-spine * spine)
	var rostrum: float = look.rostrum_ridge
	if rostrum > 0.0:
		raised += rostrum * smoothstep(0.02, 0.06, along) * (1.0 - smoothstep(0.12, 0.17, along)) * spine_line
	var ridge: float = look.dorsal_ridge
	if ridge > 0.0:
		var wide := s * half_round / 0.022
		raised += ridge * smoothstep(0.4, 0.55, along) * (1.0 - smoothstep(0.74, 0.86, along)) * exp(-wide * wide)
	var hump: float = look.hump
	if hump > 0.0:
		var wide := s * half_round / 0.03
		raised += hump * exp(-pow((along - float(look.hump_a)) / 0.045, 2.0)) * exp(-wide * wide)
	var knuckles: int = look.knuckles
	for i in knuckles:
		var a := float(look.hump_a) + 0.065 + 0.04 * i
		raised += 0.008 * (1.0 - 0.12 * i) * exp(-pow((along - a) / 0.011, 2.0)) * spine_line
	var keel: float = look.keel
	var fade := smoothstep(0.76, 0.9, along) * (1.0 - smoothstep(0.97, 1.0, along))
	var bottom := (1.0 - s) * half_round / 0.012
	raised += keel * fade * (spine_line + exp(-bottom * bottom))
	return raised


## The lofted body from its nose (`ends.x`) to its tail (`ends.y`), its slices
## bunched toward both ends. UV is (distance back over the skin from the nose,
## arc round from the top) in metres, and UV2 (share of the half round, the
## half round in m), for whale_calf_skin.
static func _body_mesh(look: Dictionary, ends: Vector2, w: float, h: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := PackedVector3Array()
	var back := PackedFloat32Array()
	last.resize(AROUND)
	back.resize(AROUND)
	for i in ROWS + 1:
		var u := float(i) / ROWS
		var along := lerpf(u, 0.5 - 0.5 * cos(PI * u), 0.6)
		var z := lerpf(ends.x, ends.y, along)
		var ring := _ring(look, along, w, h)
		var points: PackedVector2Array = ring[0]
		var normals: PackedVector2Array = ring[1]
		var shares: PackedFloat32Array = ring[2]
		var half_round: float = ring[3]
		for k in AROUND:
			var p := points[k] + normals[k] * _relief(look, along, shares[k], half_round)
			var vertex := Vector3(p.x, p.y, z)
			back[k] = ends.x if i == 0 else back[k] + vertex.distance_to(last[k])
			last[k] = vertex
			tool.set_uv(Vector2(back[k], shares[k] * half_round))
			tool.set_uv2(Vector2(shares[k], half_round))
			tool.add_vertex(vertex)
	for i in ROWS:
		for k in AROUND:
			var a := i * AROUND + k
			var b := i * AROUND + (k + 1) % AROUND
			for corner: int in [a, b, a + AROUND, b, b + AROUND, a + AROUND]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A point on the right side of the body (relief aside) `along` it, `s` round
## (0 top, 1 bottom), and its outward normal (across the body).
static func _surface(look: Dictionary, along: float, s: float, w: float, h: float, ends: Vector2) -> Array:
	var ring := _ring(look, along, w, h)
	var points: PackedVector2Array = ring[0]
	var normals: PackedVector2Array = ring[1]
	var shares: PackedFloat32Array = ring[2]
	var z := lerpf(ends.x, ends.y, along)
	for k in HALF:
		if s <= shares[k + 1] or k == HALF - 1:
			var f := clampf(inverse_lerp(shares[k], shares[k + 1], s), 0.0, 1.0)
			var p := points[k].lerp(points[k + 1], f)
			var n := normals[k].lerp(normals[k + 1], f).normalized()
			return [Vector3(p.x, p.y, z), Vector3(n.x, n.y, 0.0)]
	return [Vector3(0.0, 0.0, z), Vector3.UP]


## The sperm whale's narrow underslung lower jaw: a rod tucked half into the
## underside of its head, from just behind the forehead's front back to the
## corner of the mouth, rounded at its tip.
static func _jaw(m: FishModel, material: ShaderMaterial, look: Dictionary, w: float, h: float, ends: Vector2) -> void:
	var rows := 36
	var around := 24
	var from := 0.045
	var to := float(look.mouth_a) + 0.02
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centres := PackedVector3Array()
	for i in rows + 1:
		var t := float(i) / rows
		var along := lerpf(from, to, t)
		var bottom: Vector3 = _surface(look, along, 1.0, w, h, ends)[0]
		var tip := maxf(sqrt(maxf(1.0 - pow(maxf(1.0 - t / 0.12, 0.0), 2.0), 0.0)), 0.05)
		var back := 1.0 - smoothstep(0.75, 1.0, t) * 0.7
		var half_w := w * lerpf(0.035, 0.06, t) * tip * back
		var half_h := h * 0.085 * tip * back
		var centre := Vector3(0.0, bottom.y - half_h * 0.05, bottom.z)
		centres.append(centre)
		for k in around:
			var angle := TAU * k / around
			points.append(centre + Vector3(sin(angle) * half_w, cos(angle) * half_h, 0.0))
			uvs.append(Vector2(sin(angle) * half_w, bottom.z))
			uv2s.append(Vector2(t, 0.0))
	var indices := PackedInt32Array()
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, a + around, b, b, a + around, b + around]:
				indices.append(corner)
	var jaw := MeshInstance3D.new()
	jaw.name = "Jaw"
	jaw.mesh = _outward_mesh(points, uvs, uv2s, indices, func(i: int) -> Vector3: return centres[i / around])
	jaw.material_override = material
	m.add_child(jaw)


## A flipper on `parent`: a lofted airfoil from `root` (its base, sunk into the
## body) out along `out` for `length` m, its chord (along `chord_dir`, the
## trailing edge that way) as `chords` says from base to tip (spread evenly),
## `thick` of the chord through, bending back by `sweep` (of the length, at the
## tip). `knobs` scallops its leading edge (the humpback's tubercles). UV is
## (across the chord, out along it) in m; UV2 (out 0..1, across 0 the leading
## edge to 1 the trailing).
static func _flipper(parent: Node3D, material: ShaderMaterial, root: Vector3, out: Vector3, chord_dir: Vector3,
		length: float, chords: Array, thick: float, knobs: float, sweep: Vector3) -> MeshInstance3D:
	var span := out.normalized()
	var across := (chord_dir - span * chord_dir.dot(span)).normalized()
	var normal := span.cross(across)
	var rows := 30
	var around := 28
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centres := PackedVector3Array()
	for i in rows + 1:
		var t := float(i) / rows
		var centre := root + span * length * t + sweep * length * t * t
		var chord: float = FishModel._sample(chords, t) * sqrt(maxf(1.0 - pow(t, 6.0), 0.0))
		chord = maxf(chord, 0.0005)
		var knob := knobs * pow(absf(sin(t * PI * 5.5)), 2.0) * smoothstep(0.1, 0.25, t)
		centres.append(centre)
		for k in around:
			var theta := TAU * k / around
			var c := 0.5 - 0.5 * cos(theta)  # 0 leading edge, 1 trailing
			var lead := chord * (0.35 + knob * (1.0 - c) * 0.6)
			var x := -lead + (lead + chord * 0.65) * c
			var y := chord * thick * sin(theta) * pow(1.0 - c, 0.45) * 1.25
			points.append(centre + across * x + normal * y)
			uvs.append(Vector2(x, length * t))
			uv2s.append(Vector2(t, c))
	var indices := PackedInt32Array()
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, a + around, b, b, a + around, b + around]:
				indices.append(corner)
	var fin := MeshInstance3D.new()
	fin.name = "Flipper"
	fin.mesh = _outward_mesh(points, uvs, uv2s, indices, func(i: int) -> Vector3: return centres[i / around])
	fin.material_override = material
	parent.add_child(fin)
	return fin


## A mesh from these arrays with its normals pointing away from `centre_of`
## (the vertex index's centre line point): built, checked, and rewound if it
## came out inside out.
static func _outward_mesh(points: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array,
		indices: PackedInt32Array, centre_of: Callable) -> ArrayMesh:
	for attempt in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in points.size():
			tool.set_uv(uvs[i])
			tool.set_uv2(uv2s[i])
			tool.add_vertex(points[i])
		for index in indices:
			tool.add_index(index)
		tool.generate_normals()
		var arrays := tool.commit_to_arrays()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var outward := 0.0
		for i in range(0, mini(points.size(), normals.size()), 7):
			outward += normals[i].dot(points[i] - (centre_of.call(i) as Vector3))
		if outward >= 0.0 or attempt == 1:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			return mesh
		for t in range(0, indices.size(), 3):
			var swap := indices[t + 1]
			indices[t + 1] = indices[t + 2]
			indices[t + 2] = swap
	return null


## A thick, stiff fin on `parent`: from a root line `root0` to `root1` (parent
## space, its leading end first), columns reach out toward `out`, each turned
## `angles` (rad; + toward the leading end) and as long as `lengths` (both
## spread evenly along the root), their tips swept by `curl` (of the length, at
## the tip). It is `thick` m through at the root, thinning to a sharp edge.
## `scallop` (of the length) ripples the outer edge (the humpback's flukes).
static func _fin(parent: Node3D, material: ShaderMaterial, root0: Vector3, root1: Vector3, out: Vector3,
		angles: Array, lengths: Array, curl: Vector3, thick: float, columns := 16, rows := 8, scallop := 0.0) -> MeshInstance3D:
	var root := root1 - root0
	var root_length := root.length()
	var along := root / root_length
	var outward := (out - along * out.dot(along)).normalized()
	var normal := along.cross(outward)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 2:
		var facing := 1.0 if face == 0 else -1.0
		for i in columns + 1:
			var u := float(i) / columns
			var angle := FishModel._sample(angles, u)
			var length := FishModel._sample(lengths, u) * (1.0 - scallop * pow(absf(sin(u * PI * 4.0)), 3.0) * smoothstep(0.35, 0.6, u))
			var direction := outward * cos(angle) - along * sin(angle)
			for j in rows + 1:
				var v := float(j) / rows
				var mid := root0 + root * u + direction * length * v + curl * length * v * v
				var through := thick * pow(maxf(1.0 - v, 0.0), 0.55) * pow(sin(PI * u), 0.35) * (1.0 - 0.3 * v)
				var flat := mid - root0
				tool.set_uv(Vector2(flat.dot(along), flat.dot(outward)))
				tool.set_uv2(Vector2(u, v))
				tool.add_vertex(mid + normal * through * 0.5 * facing)
	var per_face := (columns + 1) * (rows + 1)
	for face in 2:
		for i in columns:
			for j in rows:
				var a := face * per_face + i * (rows + 1) + j
				var b := a + rows + 1
				var c := a + 1
				var d := b + 1
				var corners := [a, c, b, b, c, d] if face == 0 else [a, b, c, b, d, c]
				for corner: int in corners:
					tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	parent.add_child(fin)
	return fin
