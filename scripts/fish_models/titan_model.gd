extends RefCounted
## The Titans: adult whales (planning_marco_whales.md §6), the grown-up
## Breachers. FishModel.build hands a Titan here by path (no class_name):
## species m.species in SPECIES_KEYS order (humpback, orca, beluga, sperm whale,
## blue whale), skin m.skin (SKINS, variants within a species).
##
## The calves' pipeline (WhaleModel) taken up for adults, not the calves scaled
## up: everything is measured in L, the standard length (snout to the fluke
## notch, STANDARD of the hitbox's length), so the shape is the species' own
## whatever the hitbox's width and height. Targets and how each is measured:
## titan_specs.md, tools/model_measure.gd. Faults and compromises:
## titan_art_log.md.
##
## One smooth lofted body (_body_mesh): superelliptic slices from width, top
## and bottom tables (Catmull-Rom between their stations, so no creases), the
## relief raised into the skin (hump, knuckles, ridges, keels). The hide is
## painted in titan_skin.gdshader (pleats, tubercles, barnacles, scars,
## patches, mottling, the eye's sunk socket and fold, blowholes). Flippers are
## lofted airfoils (_flipper, tubercles scalloped into their leading edge), the
## flukes one lofted airfoil wing tip to tip through the tail stock (_fluke,
## notch, swept tips, serrated trailing edge), the dorsal a thick blade (_fin),
## all painted in titan_fin.gdshader. Three LODs (LODS) swap by distance
## (GeometryInstance3D visibility ranges, LOD_RANGES).

const SKIN_SHADER := preload("res://shaders/titan_skin.gdshader")
const FIN_SHADER := preload("res://shaders/titan_fin.gdshader")

const SPECIES_KEYS := ["humpback", "orca", "beluga", "sperm", "blue"]
const SPECIES_NAMES := ["Humpback", "Orca", "Beluga", "Sperm Whale", "Blue Whale"]
## Each species' skins (index 0 its default look): the key, the name, and what
## each changes from the species' look.
const SKINS := {
	"humpback": [
		{"key": "atlantic", "name": "North Atlantic", "look": {}},
		{"key": "southern", "name": "Southern", "look": {
			"belly_s": 0.5, "belly_mottle": 1.0, "fluke_white": 0.86, "pattern_seed": 7.1, "white_top": 1.0,
			"flank": Color("383d44"), "scars": 0.8}},
		{"key": "pacific", "name": "North Pacific", "look": {
			"belly": Color("b9bec2"), "belly_s": 0.62, "belly_mottle": 0.7, "fluke_white": 0.5, "pattern_seed": 3.7,
			"white_top": 0.15, "back": Color("272a30"), "barnacles": 1.0}},
	],
	"orca": [
		{"key": "resident", "name": "Resident", "look": {}},
		{"key": "biggs", "name": "Bigg's", "look": {
			"dorsal_round": 0.015, "dorsal_tip": 0.84, "eye_patch": Vector4(0.2, 0.4, 0.045, 0.013),
			"saddle_at": Vector3(0.56, 0.085, 0.24), "saddle_color": Color("666a70"), "scars": 0.3,
			"pattern_seed": 5.9}},
		{"key": "antarctic_b", "name": "Antarctic Type B", "look": {
			"cape": 1.0, "cape_color": Color("4e535a"), "patch": Color("e4d9b4"), "fluke_under": Color("e4d9b4"),
			"eye_patch": Vector4(0.19, 0.38, 0.075, 0.022), "saddle": 0.6, "saddle_color": Color("6f747b"),
			"scars": 0.4, "pattern_seed": 8.3}},
	],
	"beluga": [
		{"key": "white", "name": "White", "look": {}},
		{"key": "cream", "name": "Cream", "look": {
			"back": Color("e4dac0"), "flank": Color("e8dfc7"), "belly": Color("eee8d6"),
			"fin_under": Color("e4dac0"), "fin_edge": Color("a39a80"), "scar_color": Color("bfb497"), "pattern_seed": 6.2}},
		{"key": "scarred", "name": "Scarred", "look": {
			"back": Color("dce1e0"), "scars": 0.9, "scar_color": Color("878d8f"), "pattern_seed": 9.4}},
	],
	"sperm": [
		{"key": "grey", "name": "Grey", "look": {}},
		{"key": "scarred_bull", "name": "Scarred Bull", "look": {
			"scars": 1.0, "mottle": 0.35, "mottle_color": Color("8d8e8c"), "pattern_seed": 7.7}},
		{"key": "brown", "name": "Brown", "look": {
			"back": Color("463c35"), "flank": Color("54483f"), "belly": Color("85786b"),
			"fin_under": Color("54483f"), "fin_edge": Color("54483f"), "pattern_seed": 5.1}},
	],
	"blue": [
		{"key": "mottled", "name": "Mottled", "look": {}},
		{"key": "dark", "name": "Dark", "look": {
			"back": Color("36424f"), "flank": Color("434f5c"), "mottle": 0.6, "mottle_color": Color("7b8c9c"),
			"pattern_seed": 2.9}},
		{"key": "sulphur", "name": "Sulphur Bottom", "look": {
			"belly": Color("a3a28c"), "belly_s": 0.78, "fin_under": Color("aeb0a0"), "pattern_seed": 8.8}},
	],
}

## The standard length's share of the hitbox's length: the fluke tips trail the
## notch to about the hitbox's back.
const STANDARD := 0.93
## Each LOD: body slices, points round each slice, and how much of the fins'
## full resolution they keep.
const LODS := [Vector3(150, 112, 1.0), Vector3(66, 52, 0.5), Vector3(30, 24, 0.25)]
## Where the LODs swap: camera distances in hitbox lengths (LOD0 up to the
## first, LOD1 up to the second, LOD2 beyond).
const LOD_RANGES := [2.5, 6.0]
## When there's no Titan class to read the hitbox from (model_measure,
## model_shots before FishCharacter has one): width, height, length (m).
const FALLBACK_SIZE := Vector3(2.4, 2.6, 10.0)

## Shared by the adults. Tables run nose 0 to notch 1 over 11 stations, all in
## L: the full width, and the top's height above and the bottom's depth below
## the body's axis (the whole is then centred on the hitbox). The rest are
## places along (0 snout, 1 notch), shares round the body (s: 0 the back, 1 the
## belly) and sizes in L.
const TITAN_SHAPE := {
	"w_tab": [0.06, 0.1, 0.16, 0.19, 0.19, 0.17, 0.14, 0.1, 0.06, 0.03, 0.035],
	"top_tab": [0.0, 0.03, 0.07, 0.095, 0.1, 0.095, 0.085, 0.07, 0.05, 0.034, 0.012],
	"bot_tab": [0.02, 0.05, 0.09, 0.11, 0.11, 0.1, 0.085, 0.07, 0.05, 0.034, 0.012],
	"mid_share": 0.45,
	"nose": 0.05, "nose_w": 0.08, "nose_low": 0.05, "pointed": false,
	"n_head": Vector2(2.3, 2.1), "n_body": Vector2(2.1, 2.0), "n_stock": Vector2(1.75, 1.75),
	"melon": 0.0, "melon_a": 0.08, "melon_len": 0.05, "neck": 0.0, "box": 0.0,
	# A separate lower jaw (jaw > 0, its length in L; the sperm whale's): where
	# its hinge is along, how far its top sinks into the head there, its width
	# and depth (L).
	"jaw": 0.0, "jaw_hinge": 0.27, "jaw_sink": 0.006, "jaw_w": 0.04, "jaw_d": 0.028,
	"rostrum_ridge": 0.0, "dorsal_ridge": 0.0, "hump": 0.0, "hump_a": 0.63, "hump_len": 0.05, "hump_w": 0.025,
	"knuckles": 0, "knuckle_h": 0.003, "keel": 0.005,
	"eye": 0.0045, "eye_a": 0.2, "eye_s": 0.6, "iris": Color(0.2, 0.15, 0.11),
	"mouth_tip_s": 0.5, "mouth_s": 0.62, "mouth_a": 0.2, "mouth_arch": 0.05, "mouth_w": 0.0016,
	"blow_a": 0.15, "blow_pair": 1.0, "blow_x": 0.0, "splashguard": 1.0,
	"pec_a": 0.25, "pec_s": 0.68, "pec_len": 0.15, "pec_chord": [0.05, 0.055, 0.05, 0.04, 0.025],
	"pec_out": Vector3(1.0, -0.6, 0.3), "pec_sweep": Vector3(0.0, 0.0, 0.08), "pec_thick": 0.2,
	"pec_knobs": 0, "pec_knob_amp": 0.0, "pec_sink": 0.35,
	"dorsal": Vector2(0.0, 0.0), "dorsal_h": 0.0, "dorsal_angles": [-0.9, -1.0, -1.2, -1.45, -1.65],
	"dorsal_thick": 0.01,
	# A fin built as a fan instead (dorsal_tip > 0, the orca's): every column
	# reaches the tip, over this share of the root; dorsal_round spreads the
	# tip over that share of the root (0 a sharp point). dorsal_curl sweeps the
	# columns' tips back (of their length).
	"dorsal_tip": 0.0, "dorsal_round": 0.0, "dorsal_curl": Vector3(0.0, 0.0, 0.12),
	"tail_a": 0.95,
	"fluke_half": 0.13, "fluke_root": 0.085, "fluke_back": 0.06, "fluke_bulge": 0.02,
	"fluke_serr": 0.0, "fluke_teeth": 8, "fluke_thick": Vector2(0.16, 0.09), "fluke_curl": 0.0,
	# Paint (titan_skin / titan_fin).
	"back": Color("2a2d33"), "flank": Color("3a3e45"), "belly": Color("e4e6e6"),
	"belly_s": 0.7, "belly_mottle": 0.0, "mottle": 0.0, "mottle_color": Color("8a929a"),
	"tubercles": 0.0, "pleats": 0.0, "pleat_s": 0.68, "pleat_a": 0.5, "pleat_pitch": 0.011,
	"wrinkle": 0.0, "barnacles": 0.0, "scars": 0.0, "scar_color": Color("e5e5e2"),
	"orca": 0.0, "patch": Color("f4f4f2"), "saddle": 0.0, "saddle_color": Color("6b6e74"),
	# The orca's patches (titan_skin): the eye patch (along, s round, its half
	# length and half height in L), how far it rises toward its back end; the
	# white band's edge (s round at the chin, between the flippers, at the flank
	# lobe's peak, and where the lobe peaks along); the saddle (along, its half
	# length, how far down it reaches round); a grey cape (Antarctic type B: the
	# flanks pale, the back dark).
	"eye_patch": Vector4(0.19, 0.38, 0.05, 0.02), "eye_patch_tilt": 0.15,
	"orca_band": Vector4(0.63, 0.9, 0.5, 0.62), "saddle_at": Vector3(0.56, 0.07, 0.22),
	"cape": 0.0, "cape_color": Color("50555c"),
	"fluke_plain": 0.0,
	"fluke_under": null,  # the flukes' pale underside, when it isn't fin_under (the orca's white under black flippers)
	"roughness": 0.42, "clearcoat": 0.35, "sss": 0.0,
	"fin_under": Color("e8eaea"), "fin_edge": Color("e8eaea"), "fin_edge_w": 0.2, "white_top": 0.0,
	"fluke_white": 0.0, "pattern_seed": 1.3,
}

## Each species (SPECIES_KEYS order): what it changes from TITAN_SHAPE. An
## empty entry isn't built yet and borrows the humpback's shape (Wave 4).
const LOOKS := [
	{  # Humpback: bulky and knobbly, a flat rostrum with tubercles, pleats to
		# the navel, a small dorsal on a hump, the longest flippers of any whale
		# (tubercles scalloped into their leading edge), flukes with a serrated
		# trailing edge and a black-and-white underside. titan_specs.md §1.
		"w_tab": [0.08, 0.1, 0.165, 0.2, 0.21, 0.19, 0.162, 0.11, 0.065, 0.03, 0.03],
		"top_tab": [0.008, 0.025, 0.075, 0.1, 0.11, 0.105, 0.095, 0.075, 0.05, 0.029, 0.02],
		"bot_tab": [0.028, 0.045, 0.12, 0.135, 0.13, 0.115, 0.095, 0.075, 0.05, 0.029, 0.02],
		"nose": 0.055, "nose_w": 0.075, "nose_low": 0.045,
		"n_head": Vector2(2.6, 2.2), "n_body": Vector2(2.1, 2.0), "n_stock": Vector2(1.7, 1.7),
		"hump": 0.01, "hump_a": 0.632, "hump_len": 0.045, "hump_w": 0.026,
		"knuckles": 5, "knuckle_h": 0.006, "keel": 0.006,
		"eye_a": 0.23, "eye_s": 0.6,
		"mouth_tip_s": 0.5, "mouth_s": 0.63, "mouth_a": 0.215, "mouth_arch": 0.07,
		"blow_a": 0.15,
		"pec_a": 0.28, "pec_s": 0.66, "pec_len": 0.285,
		"pec_chord": [0.05, 0.056, 0.056, 0.054, 0.05, 0.045, 0.039, 0.031, 0.02],
		"pec_out": Vector3(1.0, -0.5, 0.32), "pec_sweep": Vector3(0.0, -0.04, 0.1), "pec_thick": 0.2,
		"pec_knobs": 9, "pec_knob_amp": 0.12, "pec_sink": 0.6,
		"dorsal": Vector2(0.605, 0.655), "dorsal_h": 0.022, "dorsal_thick": 0.009,
		"dorsal_angles": [-0.35, -0.5, -0.75, -1.1, -1.45],
		"fluke_half": 0.16, "fluke_root": 0.09, "fluke_back": 0.07, "fluke_bulge": 0.02,
		"fluke_serr": 0.0045, "fluke_teeth": 13,
		"back": Color("1f2227"), "flank": Color("2e3238"), "belly": Color("e2e4e3"),
		"belly_s": 0.82, "belly_mottle": 0.35,
		"tubercles": 1.0, "pleats": 1.0, "pleat_s": 0.68, "pleat_a": 0.5, "pleat_pitch": 0.012,
		"barnacles": 0.8, "scars": 0.5, "roughness": 0.46, "clearcoat": 0.3,
		"fin_under": Color("e6e8e7"), "fin_edge": Color("e6e8e7"), "fin_edge_w": 0.22, "white_top": 0.9,
		"fluke_white": 0.28, "pattern_seed": 1.3,
	},
	{  # Orca (an adult male): sleek and deep, a short blunt head with no beak,
		# the tall straight dorsal mid-back, big rounded paddle flippers, glossy
		# black with crisp white patches (eye patch, chin, belly band sweeping up
		# into a flank lobe) and a grey saddle. titan_specs.md §2.
		"w_tab": [0.05, 0.1, 0.145, 0.17, 0.17, 0.16, 0.135, 0.09, 0.055, 0.03, 0.03],
		"top_tab": [0.012, 0.045, 0.075, 0.09, 0.095, 0.09, 0.08, 0.065, 0.048, 0.029, 0.018],
		"bot_tab": [0.022, 0.055, 0.09, 0.11, 0.115, 0.1, 0.085, 0.075, 0.055, 0.029, 0.018],
		"nose": 0.06, "nose_w": 0.07, "nose_low": 0.055,
		"n_head": Vector2(2.2, 2.1), "n_body": Vector2(2.05, 2.0), "n_stock": Vector2(1.7, 1.7),
		"keel": 0.007,
		"eye": 0.004, "eye_a": 0.13, "eye_s": 0.56, "iris": Color(0.16, 0.12, 0.09),
		"mouth_tip_s": 0.5, "mouth_s": 0.6, "mouth_a": 0.115, "mouth_arch": 0.0, "mouth_w": 0.0013,
		"blow_a": 0.155, "blow_pair": 0.0, "blow_x": 0.0, "splashguard": 0.35,
		"pec_a": 0.18, "pec_s": 0.76, "pec_len": 0.17,
		"pec_chord": [0.06, 0.085, 0.097, 0.1, 0.1, 0.098, 0.094, 0.088, 0.08],
		"pec_out": Vector3(1.0, -1.0, 0.35), "pec_sweep": Vector3(0.0, -0.02, 0.06), "pec_thick": 0.18,
		"pec_sink": 0.45,
		"dorsal": Vector2(0.354, 0.474), "dorsal_h": 0.2, "dorsal_thick": 0.014,
		"dorsal_tip": 0.8, "dorsal_round": 0.08, "dorsal_curl": Vector3.ZERO,
		"fluke_half": 0.125, "fluke_root": 0.07, "fluke_back": 0.05, "fluke_bulge": 0.012,
		"fluke_thick": Vector2(0.16, 0.1),
		"back": Color("111215"), "flank": Color("15171b"), "belly": Color("f2f2f0"), "belly_s": 1.5,
		"orca": 1.0, "patch": Color("f3f3f0"), "saddle": 1.0, "saddle_color": Color("5c6066"),
		"eye_patch": Vector4(0.185, 0.4, 0.055, 0.014), "eye_patch_tilt": 0.2,
		"saddle_at": Vector3(0.55, 0.06, 0.2),
		"scars": 0.0, "roughness": 0.22, "clearcoat": 0.65,
		"fin_under": Color("15171b"), "fin_edge": Color("15171b"), "fin_edge_w": 0.0,
		"fluke_white": 1.0, "fluke_plain": 1.0, "fluke_under": Color("f0f0ee"), "pattern_seed": 2.3,
	},
	{  # Beluga: stout and white, a soft rounded melon overhanging a short beak, a
		# neck crease, no dorsal fin (a low ridge), small upturned paddle flippers,
		# deeply notched flukes with rounded lobes. Matte, light through the skin.
		# titan_specs.md §3.
		"w_tab": [0.05, 0.13, 0.19, 0.21, 0.215, 0.22, 0.19, 0.13, 0.065, 0.035, 0.03],
		"top_tab": [0.005, 0.04, 0.08, 0.1, 0.11, 0.11, 0.1, 0.075, 0.045, 0.029, 0.018],
		"bot_tab": [0.025, 0.08, 0.105, 0.12, 0.14, 0.135, 0.11, 0.085, 0.05, 0.029, 0.018],
		"nose": 0.03, "nose_w": 0.045, "nose_low": 0.035,
		"n_head": Vector2(2.1, 2.1), "n_body": Vector2(2.05, 2.05), "n_stock": Vector2(1.75, 1.75),
		"melon": 0.05, "melon_a": 0.055, "melon_len": 0.045, "neck": 0.016,
		"hump": 0.008, "hump_a": 0.6, "hump_len": 0.1, "hump_w": 0.018, "keel": 0.006,
		"eye": 0.0045, "eye_a": 0.11, "eye_s": 0.55, "iris": Color(0.12, 0.1, 0.08),
		"mouth_tip_s": 0.6, "mouth_s": 0.56, "mouth_a": 0.085, "mouth_arch": -0.02, "mouth_w": 0.0012,
		"blow_a": 0.15, "blow_pair": 0.0, "blow_x": 0.0, "splashguard": 0.2,
		"pec_a": 0.18, "pec_s": 0.72, "pec_len": 0.12,
		"pec_chord": [0.045, 0.06, 0.065, 0.065, 0.062, 0.058, 0.052, 0.045, 0.035],
		"pec_out": Vector3(1.0, -0.7, 0.25), "pec_sweep": Vector3(0.0, 0.09, 0.05), "pec_thick": 0.2,
		"pec_sink": 0.45,
		"fluke_half": 0.11, "fluke_root": 0.06, "fluke_back": 0.05, "fluke_bulge": 0.028,
		"fluke_thick": Vector2(0.16, 0.11),
		"back": Color("e6eae8"), "flank": Color("e9edeb"), "belly": Color("f0f2f0"), "belly_s": 0.8,
		"wrinkle": 0.35, "scars": 0.25, "scar_color": Color("a9aeae"),
		"roughness": 0.62, "clearcoat": 0.08, "sss": 0.6,
		"fin_under": Color("e6eae8"), "fin_edge": Color("b6b4ab"), "fin_edge_w": 0.12,
		"fluke_white": 0.0, "pattern_seed": 4.1,
	},
	{  # Sperm whale (an adult male): the huge squared box head, a third of the
		# body, overhanging a narrow underslung jaw with white lips; deep prune
		# wrinkles behind the head, a low hump two-thirds back then knuckles to
		# the flukes, broad triangular flukes, the S-shaped blowhole at the front
		# left. titan_specs.md §4.
		"w_tab": [0.1, 0.12, 0.15, 0.17, 0.17, 0.17, 0.15, 0.1, 0.06, 0.03, 0.03],
		"top_tab": [0.075, 0.085, 0.09, 0.09, 0.09, 0.085, 0.075, 0.06, 0.04, 0.024, 0.015],
		"bot_tab": [0.03, 0.085, 0.095, 0.105, 0.1, 0.105, 0.09, 0.07, 0.05, 0.026, 0.015],
		"nose": 0.015, "nose_w": 0.02, "nose_low": 0.03, "box": 1.0,
		"n_head": Vector2(4.0, 2.6), "n_body": Vector2(2.1, 2.0), "n_stock": Vector2(1.75, 1.75),
		"hump": 0.02, "hump_a": 0.64, "hump_len": 0.035, "hump_w": 0.03,
		"knuckles": 6, "knuckle_h": 0.006, "keel": 0.006,
		"eye": 0.0035, "eye_a": 0.3, "eye_s": 0.62, "iris": Color(0.14, 0.11, 0.08),
		"mouth_tip_s": 0.92, "mouth_s": 0.8, "mouth_a": 0.27, "mouth_arch": 0.0, "mouth_w": 0.0,  # the jaw is its own mesh
		"blow_a": 0.02, "blow_pair": 0.0, "blow_x": -0.022, "splashguard": 0.3,
		"jaw": 0.22, "jaw_hinge": 0.27, "jaw_sink": 0.006, "jaw_w": 0.04, "jaw_d": 0.028,
		"pec_a": 0.34, "pec_s": 0.74, "pec_len": 0.1,
		"pec_chord": [0.035, 0.045, 0.05, 0.05, 0.048, 0.045, 0.04, 0.035, 0.028],
		"pec_out": Vector3(1.0, -0.8, 0.35), "pec_sweep": Vector3(0.0, 0.0, 0.06), "pec_thick": 0.22,
		"pec_sink": 0.45,
		"fluke_half": 0.15, "fluke_root": 0.09, "fluke_back": 0.06, "fluke_bulge": 0.008,
		"fluke_thick": Vector2(0.15, 0.09),
		"back": Color("34363a"), "flank": Color("404246"), "belly": Color("5e6063"), "belly_s": 0.86,
		"wrinkle": 1.0, "scars": 0.35, "roughness": 0.56, "clearcoat": 0.15,
		"fin_under": Color("45474b"), "fin_edge": Color("45474b"), "fin_edge_w": 0.0,
		"fluke_white": 0.0, "pattern_seed": 3.3,
	},
	{  # Blue whale: long and slender, a broad flat U-shaped head with a median
		# ridge and a big splashguard, mottled blue-grey, fine pleats to the
		# navel, slender flippers, a tiny dorsal far back. titan_specs.md §5.
		"w_tab": [0.06, 0.09, 0.12, 0.14, 0.14, 0.13, 0.11, 0.08, 0.05, 0.025, 0.025],
		"top_tab": [0.004, 0.02, 0.05, 0.068, 0.073, 0.068, 0.06, 0.048, 0.036, 0.019, 0.012],
		"bot_tab": [0.014, 0.03, 0.07, 0.08, 0.08, 0.072, 0.064, 0.052, 0.038, 0.019, 0.012],
		"nose": 0.04, "nose_w": 0.06, "nose_low": 0.04,
		"n_head": Vector2(2.8, 2.2), "n_body": Vector2(2.05, 2.0), "n_stock": Vector2(1.7, 1.7),
		"rostrum_ridge": 0.004, "keel": 0.006,
		"eye": 0.0035, "eye_a": 0.22, "eye_s": 0.6,
		"mouth_tip_s": 0.5, "mouth_s": 0.63, "mouth_a": 0.205, "mouth_arch": 0.06, "mouth_w": 0.0011,
		"blow_a": 0.13, "splashguard": 1.4,
		"pec_a": 0.28, "pec_s": 0.66, "pec_len": 0.12,
		"pec_chord": [0.025, 0.032, 0.035, 0.035, 0.033, 0.03, 0.026, 0.02, 0.012],
		"pec_out": Vector3(1.0, -0.6, 0.35), "pec_sweep": Vector3(0.0, 0.0, 0.08), "pec_thick": 0.2,
		"pec_sink": 0.5,
		"dorsal": Vector2(0.752, 0.792), "dorsal_h": 0.02, "dorsal_thick": 0.005,
		"dorsal_angles": [-0.7, -0.9, -1.1, -1.35, -1.55],
		"fluke_half": 0.125, "fluke_root": 0.07, "fluke_back": 0.06, "fluke_bulge": 0.012,
		"back": Color("4a5a6c"), "flank": Color("5a6b7c"), "belly": Color("8796a3"), "belly_s": 0.8,
		"mottle": 1.0, "mottle_color": Color("9aacbc"),
		"pleats": 1.0, "pleat_s": 0.66, "pleat_a": 0.5, "pleat_pitch": 0.008,
		"scars": 0.2, "roughness": 0.45, "clearcoat": 0.3,
		"fin_under": Color("a9b8c4"), "fin_edge": Color("b8c6d0"), "fin_edge_w": 0.15,
		"fluke_white": 0.0, "pattern_seed": 6.6,
	},
]


## A Titan's model on its own: species `species`, skin `skin`, the size of
## the Titan class's hitbox (FALLBACK_SIZE before there is one).
static func make(species: int, skin := 0) -> FishModel:
	var titan: Variant = FishCharacter.FishClass.get("TITAN")
	if titan != null:
		return FishModel.build(titan, species, skin)
	var m := FishModel.new()
	m.name = "Visual"
	m.species = clampi(species, 0, SPECIES_KEYS.size() - 1)
	m.skin = maxi(skin, 0)
	m._size = FALLBACK_SIZE
	build(m)
	return m


## Species `species`' skin keys and names, in order (the pick card's list).
static func skin_keys(species: int) -> Array:
	var keys: Array = []
	for entry: Dictionary in SKINS[SPECIES_KEYS[clampi(species, 0, SPECIES_KEYS.size() - 1)]]:
		keys.append(entry.key)
	return keys


static func skin_names(species: int) -> Array:
	var names: Array = []
	for entry: Dictionary in SKINS[SPECIES_KEYS[clampi(species, 0, SPECIES_KEYS.size() - 1)]]:
		names.append(entry.name)
	return names


static func build(m: FishModel) -> void:
	var species := clampi(m.species, 0, SPECIES_KEYS.size() - 1)
	var look := _look(species, m.skin)
	var full := m._size.z
	var l := full * STANDARD
	var ends := Vector2(-full * 0.5, -full * 0.5 + l)
	var at := func(along: float) -> float: return ends.x + l * along
	m.fluke = true
	m.set_meta("titan_species", SPECIES_KEYS[species])
	var back: Color = look.back
	var flank: Color = look.flank
	var gain := Vector3.ONE * minf((_ratio(flank.r, back.r) + _ratio(flank.g, back.g) + _ratio(flank.b, back.b)) / 3.0, 4.0)
	m._body_material = m._material(back, 0.45)  # for set_body_color(); the skin does the shading
	m.bend_share = 0.6

	# The body, in its LODs.
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	for key: String in ["belly_s", "belly_mottle", "mottle", "tubercles", "wrinkle", "pleats", "pleat_s",
			"barnacles", "scars", "orca", "saddle", "roughness", "clearcoat", "sss", "pattern_seed",
			"saddle_color", "eye_patch", "eye_patch_tilt", "orca_band", "saddle_at", "cape", "cape_color",
			"scar_color"]:
		skin.set_shader_parameter(key, look[key])
	skin.set_shader_parameter("albedo", back)
	skin.set_shader_parameter("flank_gain", gain)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("mottle_color", look.mottle_color)
	skin.set_shader_parameter("patch_color", look.patch)
	skin.set_shader_parameter("body_length", l)
	skin.set_shader_parameter("nose_z", ends.x)
	skin.set_shader_parameter("pleat_z", at.call(look.pleat_a))
	skin.set_shader_parameter("pleat_pitch", float(look.pleat_pitch) * l)
	skin.set_shader_parameter("mouth_tip_s", look.mouth_tip_s)
	skin.set_shader_parameter("mouth_s", look.mouth_s)
	skin.set_shader_parameter("mouth_corner", look.mouth_a)
	skin.set_shader_parameter("mouth_arch", look.mouth_arch)
	skin.set_shader_parameter("mouth_width", float(look.mouth_w) * l)
	skin.set_shader_parameter("pale_lips", look.box)
	var blow: Vector3 = _surface(look, look.blow_a, 0.0, l, ends)[0]
	blow.x = float(look.blow_x) * l
	skin.set_shader_parameter("blow_pos", blow)
	skin.set_shader_parameter("blow_pair", look.blow_pair)
	skin.set_shader_parameter("splashguard", look.splashguard)
	m._skins.append(skin)
	var bent: Array = []
	for lod in LODS.size():
		var res: Vector3 = LODS[lod]
		var body := MeshInstance3D.new()
		body.name = "Body" if lod == 0 else "BodyLod%d" % lod
		body.mesh = _body_mesh(look, ends, l, int(res.x), int(res.y), true)
		body.material_override = skin
		_set_lod(body, lod, full)
		m.add_child(body)
		if lod > 0:
			bent.append(body)

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
	fins.set_shader_parameter("clearcoat", look.clearcoat)
	fins.set_shader_parameter("barnacles", look.barnacles)
	fins.set_shader_parameter("scars", look.scars)
	fins.set_shader_parameter("pattern_seed", look.pattern_seed)
	fins.set_shader_parameter("body_length", l)
	m._skins.append(fins)
	var flippers := fins.duplicate() as ShaderMaterial
	flippers.set_shader_parameter("part", 1)
	flippers.set_shader_parameter("white_top", look.white_top)
	m._skins.append(flippers)
	var flukes := fins.duplicate() as ShaderMaterial
	flukes.set_shader_parameter("part", 2)
	flukes.set_shader_parameter("fluke_white", look.fluke_white)
	flukes.set_shader_parameter("fluke_plain", look.fluke_plain)
	if look.fluke_under != null:
		flukes.set_shader_parameter("under_color", look.fluke_under)
	m._skins.append(flukes)

	# The dorsal fin, on the back (bent with the body).
	var dorsal: Vector2 = look.dorsal
	if float(look.dorsal_h) > 0.0:
		var top := func(along: float) -> Vector3: return _surface(look, along, 0.0, l, ends)[0]
		var height := float(look.dorsal_h) * l
		var inset := Vector3(0.0, -0.004 * l, 0.0)
		var hump0 := _relief(look, dorsal.x, 0.0, 1.0, l)
		var hump1 := _relief(look, dorsal.y, 0.0, 1.0, l)
		var root0: Vector3 = top.call(dorsal.x) + inset + Vector3.UP * hump0
		var root1: Vector3 = top.call(dorsal.y) + inset + Vector3.UP * hump1
		var angles: Array = look.dorsal_angles
		var lengths: Array = [height, height * 0.92, height * 0.66, height * 0.32, height * 0.08]
		var tip_at := float(look.dorsal_tip)
		if tip_at > 0.0:
			# A fan: each column reaches for the tip (spread over dorsal_round of
			# the root, rounding it), so the edges run straight to it.
			angles = []
			lengths = []
			var base := root0.distance_to(root1)
			var rise := height - inset.y
			var spread := float(look.dorsal_round)
			for i in 17:
				var u := i / 16.0
				var c := u - 0.5
				var dx := (tip_at + c * spread) * base - u * base
				var dy := rise - spread * base * c * c * 2.0
				angles.append(-atan2(dx, dy))
				lengths.append(sqrt(dx * dx + dy * dy))
		for lod in LODS.size():
			var res: Vector3 = LODS[lod]
			var fin := _fin(m, fins, root0, root1, Vector3.UP, angles, lengths,
					look.dorsal_curl, float(look.dorsal_thick) * l, maxi(int(16 * res.z), 4), maxi(int(8 * res.z), 3))
			fin.name = "Dorsal" if lod == 0 else "DorsalLod%d" % lod
			_set_lod(fin, lod, full)
			bent.append(fin)

	# Flippers low behind the head, on the swim animation's pivots, their roots
	# sunk into the flank.
	var pectoral := _surface(look, look.pec_a, look.pec_s, l, ends)
	var chord0 := float((look.pec_chord as Array)[0]) * l
	var pec_at: Vector3 = (pectoral[0] as Vector3) - (pectoral[1] as Vector3) * chord0 * float(look.pec_sink)
	# Each pivot rides the head's counter-bend and the surge (a bend rider), and
	# holds a trim node the motion turns (FishModel.trims) on top of the swim's
	# own turn of the pivot.
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "FinLeftPivot" if side < 0.0 else "FinRightPivot"
		m.bend_rider(pec_at * Vector3(side, 1.0, 1.0)).add_child(pivot)
		var trim := Node3D.new()
		trim.name = "Trim"
		pivot.add_child(trim)
		m.trims.append(trim)
		if side < 0.0:
			m.fin_left = pivot
		else:
			m.fin_right = pivot
	var chords: Array = []
	for c: float in look.pec_chord:
		chords.append(c * l)
	for side: float in [-1.0, 1.0]:
		var pivot: Node3D = m.trims[0] if side < 0.0 else m.trims[1]
		var out: Vector3 = look.pec_out
		var sweep: Vector3 = look.pec_sweep
		for lod in LODS.size():
			var res: Vector3 = LODS[lod]
			var flipper := _flipper(pivot, flippers, out * Vector3(side, 1.0, 1.0), Vector3.BACK, float(look.pec_len) * l,
					chords, float(look.pec_thick), int(look.pec_knobs), float(look.pec_knob_amp), sweep * Vector3(side, 1.0, 1.0),
					maxi(int(72 * res.z), 10), maxi(int(28 * res.z), 8))
			flipper.name = "Flipper" if lod == 0 else "FlipperLod%d" % lod
			_set_lod(flipper, lod, full)

	# The flukes on the tail pivot: one wing tip to tip through the tail stock.
	var stock := _section(look, look.tail_a, l)
	m._tail_pivot(Vector3(0.0, stock[3], at.call(look.tail_a)))
	for lod in LODS.size():
		var res: Vector3 = LODS[lod]
		var fluke := _fluke(m.tail, flukes, look, l, ends.y - m.tail.position.z,
				maxi(int(80 * res.z), 10), maxi(int(22 * res.z), 8))
		fluke.name = "Fluke" if lod == 0 else "FlukeLod%d" % lod
		_set_lod(fluke, lod, full)
	# The sperm whale's narrow lower jaw under the box (bent with the head).
	if float(look.jaw) > 0.0:
		var jaw_material := fins.duplicate() as ShaderMaterial
		jaw_material.set_shader_parameter("part", 3)
		m._skins.append(jaw_material)
		for lod in LODS.size():
			var res: Vector3 = LODS[lod]
			var jaw := _jaw(m, jaw_material, look, l, ends, maxi(int(40 * res.z), 8), maxi(int(20 * res.z), 8))
			jaw.name = "Jaw" if lod == 0 else "JawLod%d" % lod
			_set_lod(jaw, lod, full)
			bent.append(jaw)
	m._bend_body(at.call(0.48), bent)
	# The Titans' motion (FishModel._titan_swim): the head counter-bends from the
	# bend's start forward to just behind the rostrum.
	m.titan_motion = true
	m.head_span = l * (0.48 - 0.12)

	# Small eyes low on the head, sunk in their sockets (the skin paints the
	# fold and lid round them). Only up close: they're gone past LOD0.
	var eye_r: float = float(look.eye) * l
	var eye := _surface(look, look.eye_a, look.eye_s, l, ends)
	var eye_at: Vector3 = (eye[0] as Vector3) - (eye[1] as Vector3) * eye_r * 0.6
	skin.set_shader_parameter("eye_pos", eye[0])
	skin.set_shader_parameter("eye_radius", eye_r)
	for side: float in [-1.0, 1.0]:
		var normal: Vector3 = eye[1]
		var gaze := (normal + Vector3(0.0, 0.0, -0.3)).normalized() * Vector3(side, 1.0, 1.0)
		var ball := m._real_eye(Vector3.ZERO, eye_r, gaze, look.iris, 0.5, m.bend_rider(eye_at * Vector3(side, 1.0, 1.0)))
		var material := ball.material_override as ShaderMaterial
		material.set_shader_parameter("rim_color", Color(0.03, 0.03, 0.035))
		material.set_shader_parameter("pupil_stretch", 1.3)
		material.set_shader_parameter("sheen", 0.6)
		_set_lod(ball, 0, full)

	# Visibility ranges don't follow a node's scale: whoever scales the model
	# (by `k`) calls this to scale the LODs' ranges with it.
	var parts: Array[GeometryInstance3D] = []
	var rest: Array[Vector4] = []
	for node: Node in m.find_children("*", "GeometryInstance3D", true, false):
		var part := node as GeometryInstance3D
		if part.has_meta("lod"):
			parts.append(part)
			rest.append(Vector4(part.visibility_range_begin, part.visibility_range_begin_margin,
					part.visibility_range_end, part.visibility_range_end_margin))
	m.set_meta("titan_lod_rescale", func(k: float) -> void:
		for i in parts.size():
			if not is_instance_valid(parts[i]):
				continue
			parts[i].visibility_range_begin = rest[i].x * k
			parts[i].visibility_range_begin_margin = rest[i].y * k
			parts[i].visibility_range_end = rest[i].z * k
			parts[i].visibility_range_end_margin = rest[i].w * k)


## The body without its relief (hump, knuckles, ridges, keels): what
## model_measure measures the relief against.
static func bare_body_mesh(m: FishModel) -> ArrayMesh:
	var look := _look(clampi(m.species, 0, SPECIES_KEYS.size() - 1), m.skin)
	var full := m._size.z
	var l := full * STANDARD
	var res: Vector3 = LODS[0]
	return _body_mesh(look, Vector2(-full * 0.5, -full * 0.5 + l), l, int(res.x), int(res.y), false)


## Species `species`' look in skin `skin`: TITAN_SHAPE, its own entries over
## that (the humpback's while it has none yet), the skin's over those.
static func _look(species: int, skin: int) -> Dictionary:
	var look: Dictionary = TITAN_SHAPE.duplicate()
	var own: Dictionary = LOOKS[species]
	look.merge(own if not own.is_empty() else LOOKS[0], true)
	var skins: Array = SKINS[SPECIES_KEYS[species]]
	look.merge((skins[clampi(skin, 0, skins.size() - 1)] as Dictionary).look, true)
	# Centre the body on the hitbox's middle: as far above as below.
	var top := 0.0
	var bot := 0.0
	for v: float in look.top_tab:
		top = maxf(top, v)
	for v: float in look.bot_tab:
		bot = maxf(bot, v)
	look["shift"] = (bot - top) * 0.5
	return look


## Shows `part` only at its LOD's camera distances (LOD_RANGES, in hitbox
## lengths of `full` m).
static func _set_lod(part: GeometryInstance3D, lod: int, full: float) -> void:
	part.set_meta("lod", lod)
	var margin := full * 0.2
	if lod > 0:
		part.visibility_range_begin = float(LOD_RANGES[lod - 1]) * full
		part.visibility_range_begin_margin = margin
	if lod < LODS.size() - 1:
		part.visibility_range_end = float(LOD_RANGES[lod]) * full
		part.visibility_range_end_margin = margin
	part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## How many times brighter `to` is than `from` (sRGB channels, in linear light).
static func _ratio(to: float, from: float) -> float:
	var a := pow(maxf(to, 0.0), 2.2)
	var b := pow(maxf(from, 0.0), 2.2)
	return clampf(a / maxf(b, 0.002), 1.0, 6.0)


static func _spow(value: float, power: float) -> float:
	return signf(value) * pow(absf(value), power)


## `values` spread evenly over 0..1, read at `t` along a Catmull-Rom curve
## through them (smooth, so the loft has no creases at the stations).
static func _curve(values: Array, t: float) -> float:
	var last := values.size() - 1
	var x := clampf(t, 0.0, 1.0) * last
	var i := mini(int(x), last - 1)
	var f := x - i
	var p0: float = values[maxi(i - 1, 0)]
	var p1: float = values[i]
	var p2: float = values[i + 1]
	var p3: float = values[mini(i + 2, last)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


## The body's slice `along` it (nose 0, notch 1), in m: half width, the top's
## and the bottom's distance from its middle, its middle's height, and how
## square its top and bottom halves are (superellipse exponents, 2 an oval).
static func _section(look: Dictionary, along: float, l: float) -> PackedFloat32Array:
	var shift: float = look.shift
	var half_w := 0.5 * l * _curve(look.w_tab, along)
	var top := l * (_curve(look.top_tab, along) + shift)
	var bot := l * (-_curve(look.bot_tab, along) + shift)
	var melon: float = look.melon
	if melon > 0.0:
		top += l * melon * exp(-pow((along - float(look.melon_a)) / float(look.melon_len), 2.0))
	var neck: float = look.neck
	if neck > 0.0:
		var pinch := exp(-pow((along - 0.19) / 0.03, 2.0)) * neck
		top -= l * pinch * 0.5
		half_w -= l * pinch * 0.3
	var mid := lerpf(bot, top, float(look.mid_share))
	var pointed: bool = look.pointed
	var cap := _nose_cap(along, look.nose, pointed)
	var cap_w := _nose_cap(along, look.nose_w, pointed)
	var cap_low := _nose_cap(along, lerpf(float(look.nose_low), 0.12, float(look.box)), pointed)
	if along > 0.985:
		var end := sqrt(maxf(1.0 - pow((along - 0.985) / 0.015, 2.0), 0.0))
		cap *= end
		cap_w *= end
		cap_low *= end
	var head := 1.0 - smoothstep(0.08, 0.3, along)
	var stock := smoothstep(0.68, 0.9, along)
	var n_head: Vector2 = look.n_head
	var n_body: Vector2 = look.n_body
	var n_stock: Vector2 = look.n_stock
	var n := n_body.lerp(n_head, head).lerp(n_stock, stock)
	return PackedFloat32Array([maxf(half_w, 0.0) * cap_w, (top - mid) * cap, (mid - bot) * cap_low, mid, n.x, n.y])


## How far open the body is `along` it near the nose, closing over `nose`:
## round, or a cone if `pointed`.
static func _nose_cap(along: float, nose: float, pointed: bool) -> float:
	if along >= nose:
		return 1.0
	var x := along / nose
	var cap := x * (2.0 - x)
	return pow(cap, 0.75) if pointed else sqrt(cap)


## A slice of the body `along` it with `around` points, without the relief:
## its points round from the top (down the right side first), their outward
## normals, how far round each is (0 the top to 1 the bottom) and the half
## round (m).
static func _ring(look: Dictionary, along: float, l: float, around: int) -> Array:
	var section := _section(look, along, l)
	var points := PackedVector2Array()
	for k in around:
		var t := TAU * k / around
		var up := cos(t)
		var n := section[4] if up >= 0.0 else section[5]
		var x := section[0] * _spow(sin(t), 2.0 / n)
		var y := section[3] + (section[1] if up >= 0.0 else section[2]) * _spow(up, 2.0 / n)
		points.append(Vector2(x, y))
	var half := around / 2
	var arcs := PackedFloat32Array()
	arcs.resize(around)
	arcs[0] = 0.0
	for k in range(1, half + 1):
		arcs[k] = arcs[k - 1] + points[k].distance_to(points[k - 1])
	for k in range(half + 1, around):
		arcs[k] = arcs[around - k]
	var half_round := arcs[half]
	var round_share := PackedFloat32Array()
	var normals := PackedVector2Array()
	for k in around:
		round_share.append(arcs[k] / half_round if half_round > 1e-6 else minf(k, around - k) / float(half))
		var tangent := points[(k + 1) % around] - points[(k + around - 1) % around]
		normals.append(Vector2(-tangent.y, tangent.x).normalized())
	return [points, normals, round_share, half_round]


## How far the relief raises the skin (m) `along` the body, `s` round it (0
## top, 1 bottom): the rostrum's ridge, the beluga's dorsal ridge, the hump,
## the knuckles down the tail stock, and the stock's keels above and below.
static func _relief(look: Dictionary, along: float, s: float, half_round: float, l: float) -> float:
	var raised := 0.0
	var from_top := s * half_round / l
	var from_bottom := (1.0 - s) * half_round / l
	var spine := exp(-pow(from_top / 0.006, 2.0))
	var rostrum: float = look.rostrum_ridge
	if rostrum > 0.0:
		raised += rostrum * smoothstep(0.015, 0.05, along) * (1.0 - smoothstep(0.12, 0.17, along)) * exp(-pow(from_top / 0.01, 2.0))
	var ridge: float = look.dorsal_ridge
	if ridge > 0.0:
		raised += ridge * smoothstep(0.4, 0.55, along) * (1.0 - smoothstep(0.72, 0.84, along)) * exp(-pow(from_top / 0.016, 2.0))
	var hump: float = look.hump
	if hump > 0.0:
		raised += hump * exp(-pow((along - float(look.hump_a)) / float(look.hump_len), 2.0)) * exp(-pow(from_top / float(look.hump_w), 2.0))
	var knuckles: int = look.knuckles
	for i in knuckles:
		var a := float(look.hump_a) + 0.07 + 0.038 * i
		raised += float(look.knuckle_h) * (1.0 - 0.15 * i) * exp(-pow((along - a) / 0.011, 2.0)) * spine
	var keel: float = look.keel
	var fade := smoothstep(0.74, 0.88, along) * (1.0 - smoothstep(0.96, 1.0, along))
	raised += keel * fade * (spine + exp(-pow(from_bottom / 0.006, 2.0)))
	return raised * l


## The lofted body from its nose (`ends.x`) to its notch (`ends.y`): `rows`
## slices, bunched toward both ends, of `around` points. UV is (distance back
## over the skin from the nose, arc round from the top) in m, and UV2 (share of
## the half round, the half round in m), for titan_skin.
static func _body_mesh(look: Dictionary, ends: Vector2, l: float, rows: int, around: int, relief: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := PackedVector3Array()
	var back := PackedFloat32Array()
	last.resize(around)
	back.resize(around)
	for i in rows + 1:
		var u := float(i) / rows
		var along := lerpf(u, 0.5 - 0.5 * cos(PI * u), 0.55)
		var z := lerpf(ends.x, ends.y, along)
		var ring := _ring(look, along, l, around)
		var points: PackedVector2Array = ring[0]
		var normals: PackedVector2Array = ring[1]
		var shares: PackedFloat32Array = ring[2]
		var half_round: float = ring[3]
		for k in around:
			var p := points[k]
			if relief:
				p += normals[k] * _relief(look, along, shares[k], half_round, l)
			var vertex := Vector3(p.x, p.y, z)
			back[k] = ends.x if i == 0 else back[k] + vertex.distance_to(last[k])
			last[k] = vertex
			tool.set_uv(Vector2(back[k], shares[k] * half_round))
			tool.set_uv2(Vector2(shares[k], half_round))
			tool.add_vertex(vertex)
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A point on the right side of the body (relief aside) `along` it, `s` round
## (0 top, 1 bottom), and its outward normal (across the body).
static func _surface(look: Dictionary, along: float, s: float, l: float, ends: Vector2) -> Array:
	var around := 160
	var ring := _ring(look, along, l, around)
	var points: PackedVector2Array = ring[0]
	var normals: PackedVector2Array = ring[1]
	var shares: PackedFloat32Array = ring[2]
	var z := lerpf(ends.x, ends.y, along)
	var half := around / 2
	for k in half:
		if s <= shares[k + 1] or k == half - 1:
			var f := clampf(inverse_lerp(shares[k], shares[k + 1], s), 0.0, 1.0)
			var p := points[k].lerp(points[k + 1], f)
			var n := normals[k].lerp(normals[k + 1], f).normalized()
			return [Vector3(p.x, p.y, z), Vector3(n.x, n.y, 0.0)]
	return [Vector3(0.0, 0.0, z), Vector3.UP]


## A flipper on `parent` (its pivot, at the root sunk into the flank): a
## lofted airfoil out along `out` for `length` m, its chord (along
## `chord_dir`, the trailing edge that way) as `chords` says from root to tip,
## `thick` of the chord through, bending back by `sweep` (of the length, at the
## tip). `knobs` tubercles (`knob_amp` of the chord) scallop its leading edge
## over its outer two thirds, the humpback's. The root flares a little into the
## body. UV is (across the chord, out along it) in m; UV2 (out 0..1, across 0
## the leading edge to 1 the trailing).
static func _flipper(parent: Node3D, material: ShaderMaterial, out: Vector3, chord_dir: Vector3, length: float,
		chords: Array, thick: float, knobs: int, knob_amp: float, sweep: Vector3, rows: int, around: int) -> MeshInstance3D:
	var span := out.normalized()
	var across := (chord_dir - span * chord_dir.dot(span)).normalized()
	var normal := span.cross(across)
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centres := PackedVector3Array()
	var inside := 0.12  # of the length: the root runs on into the body and closes there, out of sight
	for i in rows + 1:
		var t := lerpf(-inside, 1.0, float(i) / rows)
		var centre := span * length * t + sweep * length * maxf(t, 0.0) * maxf(t, 0.0)
		var chord: float = FishModel._sample(chords, maxf(t, 0.0)) * sqrt(maxf(1.0 - pow(maxf(t, 0.0), 5.0), 0.0))
		chord *= 1.0 + 0.35 * exp(-pow(t / 0.06, 2.0))  # the root's flare into the body
		if t < 0.0:
			chord *= sqrt(maxf(1.0 - pow(t / inside, 2.0), 0.0))
		chord = maxf(chord, 0.0005 * length)
		t = maxf(t, 0.0)
		var knob := 0.0
		if knobs > 0:
			var phase := clampf((t - 0.25) / 0.72, 0.0, 1.0) * knobs
			# Rounded bumps with rounded scallops between (no sharp valleys).
			knob = knob_amp * (0.5 - 0.5 * cos(phase * TAU)) * smoothstep(0.2, 0.3, t) * (1.0 - smoothstep(0.93, 0.99, t))
		centres.append(centre)
		for k in around:
			var theta := TAU * k / around
			var c := 0.5 - 0.5 * cos(theta)  # 0 leading edge, 1 trailing
			var lead := chord * (0.3 + knob * pow(1.0 - c, 3.0))
			var x := -lead + (lead + chord * 0.7) * c
			var y := chord * thick * sin(theta) * pow(1.0 - c, 0.5) * 1.3
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


## The flukes on `parent` (the tail pivot), the notch `notch` m behind it: one
## lofted airfoil from tip to tip (span along X) through the tail stock, so
## there's no seam at the middle. Its leading edge runs from `fluke_root` (of
## L) ahead of the notch out and back to the tips, `fluke_back` behind the
## notch; its trailing edge from the notch out, bulging back by `fluke_bulge`,
## to the tips, cut into `fluke_teeth` scallops `fluke_serr` deep (the
## humpback's serrations). `fluke_thick` is the airfoil's thickness (of the
## chord) at the root and the tips. UV is (x, z) in m; UV2 (-1 left tip .. 1
## right tip, across 0 the leading edge to 1 the trailing).
static func _fluke(parent: Node3D, material: ShaderMaterial, look: Dictionary, l: float, notch: float,
		columns: int, around: int) -> MeshInstance3D:
	var half := float(look.fluke_half) * l
	var root := float(look.fluke_root) * l
	var tip_back := float(look.fluke_back) * l
	var bulge := float(look.fluke_bulge) * l
	var serr := float(look.fluke_serr) * l
	var teeth: int = look.fluke_teeth
	var thick: Vector2 = look.fluke_thick
	var curl := float(look.fluke_curl) * l
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centres := PackedVector3Array()
	var stations := columns * 2
	for i in stations + 1:
		# Spaced closer toward the tips, where the edges turn fastest.
		var t := -1.0 + 2.0 * float(i) / stations
		t = signf(t) * (1.0 - pow(1.0 - absf(t), 1.25))
		var u := absf(t)
		var lead := -root * (1.0 - pow(u, 1.5)) + tip_back * pow(u, 2.4)
		var trail := tip_back * pow(u, 1.35) + bulge * sin(PI * u) * pow(1.0 - u, 0.35)
		if serr > 0.0:
			# Irregular: each scallop its own depth and the spacing wandering, as
			# a real trailing edge is (ragged, not a pie crust).
			var wander := u * teeth + 0.35 * sin(u * 23.0 + signf(t) * 1.7)
			var depth := 0.55 + 0.45 * sin(floorf(wander) * 2.39 + signf(t) * 0.8)
			trail -= serr * depth * pow(absf(sin(wander * PI)), 0.8) * smoothstep(0.08, 0.2, u) * (1.0 - smoothstep(0.82, 0.95, u))
		# Round the tips: the chord closes like a quarter circle at the end.
		var close := sqrt(maxf(1.0 - pow(maxf(u - 0.9, 0.0) / 0.1, 2.0), 0.0))
		var middle := (lead + trail) * 0.5
		var chord := maxf((trail - lead) * maxf(close, 0.02), 0.0006 * l)
		lead = middle - chord * 0.5
		var ratio := lerpf(thick.x, thick.y, u) * (1.0 + 1.2 * exp(-pow(u / 0.08, 2.0)))
		var centre := Vector3(t * half, curl * u * u, notch + middle)
		centres.append(centre)
		for k in around:
			var theta := TAU * k / around
			var c := 0.5 - 0.5 * cos(theta)
			var z := lead + chord * c
			var y := chord * ratio * sin(theta) * 1.54 * sqrt(maxf(1.0 - c, 0.0)) * (0.35 + 0.65 * sqrt(c)) * 0.5
			var point := Vector3(t * half, curl * u * u + y, notch + z)
			points.append(point)
			uvs.append(Vector2(point.x, point.z))
			uv2s.append(Vector2(t, c))
	var indices := PackedInt32Array()
	for i in stations:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, a + around, b, b, a + around, b + around]:
				indices.append(corner)
	var fin := MeshInstance3D.new()
	fin.name = "Fluke"
	fin.mesh = _outward_mesh(points, uvs, uv2s, indices, func(i: int) -> Vector3: return centres[i / around])
	fin.material_override = material
	parent.add_child(fin)
	return fin


## The sperm whale's lower jaw on `parent`: a narrow rod `look.jaw` of L long
## under the head, from just behind the snout back to its hinge, its top sunk
## `jaw_sink` into the head's underside all along (tucked into its groove),
## the box overhanging its tip. UV is (x, z) in m, UV2 (along it 0 tip..1
## hinge, round 0 top..1 bottom).
static func _jaw(parent: Node3D, material: ShaderMaterial, look: Dictionary, l: float, ends: Vector2,
		rows: int, around: int) -> MeshInstance3D:
	var hinge := float(look.jaw_hinge)
	var length := float(look.jaw) * l
	var hinge_z := lerpf(ends.x, ends.y, hinge)
	var width := float(look.jaw_w) * l
	var depth := float(look.jaw_d) * l
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centres := PackedVector3Array()
	for i in rows + 1:
		var u := float(i) / rows  # 0 the tip, 1 the hinge
		var z := hinge_z - length * (1.0 - u)
		# Rounded at the tip; at the hinge it slims into the head, no step.
		var taper := lerpf(0.55, 1.0, u) * sqrt(maxf(1.0 - pow(maxf(0.06 - u, 0.0) / 0.06, 2.0), 0.0))
		taper *= lerpf(1.0, 0.25, smoothstep(0.75, 1.0, u))
		var half_w := 0.5 * width * maxf(taper, 0.02)
		var d := depth * maxf(taper, 0.02)
		var section := _section(look, hinge - float(look.jaw) * (1.0 - u), l)
		var top := section[3] - section[2] + float(look.jaw_sink) * l
		var centre := Vector3(0.0, top - d * 0.5, z)
		centres.append(centre)
		for k in around:
			var theta := TAU * k / around
			var p := centre + Vector3(half_w * _spow(sin(theta), 0.8), d * 0.5 * _spow(cos(theta), 0.8), 0.0)
			points.append(p)
			uvs.append(Vector2(p.x, p.z))
			uv2s.append(Vector2(u, 0.5 - 0.5 * cos(theta)))
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
	parent.add_child(jaw)
	return jaw


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
static func _fin(parent: Node3D, material: ShaderMaterial, root0: Vector3, root1: Vector3, out: Vector3,
		angles: Array, lengths: Array, curl: Vector3, thick: float, columns: int, rows: int) -> MeshInstance3D:
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
			var length := FishModel._sample(lengths, u)
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
