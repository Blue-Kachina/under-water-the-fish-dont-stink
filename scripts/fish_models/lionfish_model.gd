class_name LionfishModel
extends RefCounted
## The lionfish (FishModel.build hands it here): skin m.skin of
## FishCharacter.SKINS[FishCharacter.Family.LIONFISH].
##
## One smooth lofted body (a big head tapering to a slim tail stalk) painted
## with bands, mottling and its face (lionfish_skin.gdshader); a crest of long
## venomous dorsal spines webbed at their bases; huge fan pectorals of banded
## rays and frilly membrane on the fin pivots, the motion showpiece, rippling
## with the swim; soft dorsal, anal and tail fins with spotted rays; fleshy
## tentacles over the eyes. Spines and rays are low-poly tapered tubes
## (lionfish_spine.gdshader), webs thin membranes (lionfish_web.gdshader); both
## carry how far out along which ray each point is, so they ripple as one
## (lionfish_fin.gdshaderinc). Fins on the body's bending part bend with it.

const SKIN := preload("res://shaders/lionfish_skin.gdshader")
const SPINE := preload("res://shaders/lionfish_spine.gdshader")
const WEB := preload("res://shaders/lionfish_web.gdshader")

## Each skin's look, in FishCharacter.SKINS order. Lengths are shares of the
## hitbox (l its length, h its height) unless they say m.
const LOOKS := [
	{  # Red Lionfish, Pterois volitans: maroon and cream zebra bands, banded spines, feathery fans.
		"albedo": Color(0.55, 0.1, 0.08), "ground": Color(0.97, 0.91, 0.84), "ground_tint": 0.0,
		"band": Color(0.55, 0.1, 0.08), "band_tint": 1.0, "band_shade": 1.0, "band_strength": 1.0,
		"band_period": 0.085, "band_duty": Vector2(0.32, 0.62), "band_soft": 0.02, "thin_line": 0.75,
		"mottle": 0.0, "stalk_lines": 0.0, "belly_lift": 1.05, "eye_bar": 1.0, "roughness": 0.34,
		"iris": Color(0.8, 0.3, 0.15), "stocky": 0.0, "ray_thick": 1.0,
		"spine_len": 1.2, "spine_web": 0.38, "spine_pale": Color(0.97, 0.93, 0.88), "spine_band": 0.045, "spine_band_to": 100.0,
		"spine_flag": 0.012, "web_color": Color(0.96, 0.9, 0.84), "web_alpha": Vector2(0.75, 0.35), "web_band": 0.85,
		"pec_len": 0.46, "pec_rays": 15, "pec_web": 0.58, "pec_dip": 0.22, "pec_feather": 0.02, "pec_spread": Vector2(1.05, -1.05),
		"pec_lengths": [0.5, 0.7, 0.86, 0.96, 1.0, 1.0, 0.97, 0.9, 0.8, 0.68, 0.55],
		"ray_pale": Color(0.97, 0.93, 0.88), "ray_band": 0.042, "pec_band": 0.06, "pec_spots": 0.0, "pec_alpha": Vector2(0.8, 0.45),
		"soft_alpha": Vector2(0.45, 0.2), "tentacle": 0.34, "tentacles": 1, "cirri": 0,
	},
	{  # Clearfin Lionfish, Pterois radiata: dark red-brown with thin white lines, bare white spines and rays.
		"albedo": Color(0.3, 0.12, 0.08), "ground": Color(0.3, 0.12, 0.08), "ground_tint": 1.0,
		"band": Color(0.96, 0.96, 0.93), "band_tint": 0.0, "band_shade": 1.0, "band_strength": 0.95,
		"band_period": 0.075, "band_duty": Vector2(0.08, 0.13), "band_soft": 0.0, "thin_line": 0.0,
		"mottle": 0.0, "stalk_lines": 1.0, "belly_lift": 1.45, "eye_bar": 0.0, "roughness": 0.3,
		"iris": Color(0.7, 0.5, 0.3), "stocky": 0.0, "ray_thick": 1.5,
		"spine_len": 1.25, "spine_web": 0.16, "spine_pale": Color(0.97, 0.97, 0.95), "spine_band": 0.0, "spine_band_to": 100.0,
		"spine_flag": 0.0, "web_color": Color(0.8, 0.86, 0.9), "web_alpha": Vector2(0.28, 0.08), "web_band": 0.0,
		"pec_len": 0.5, "pec_rays": 14, "pec_web": 0.22, "pec_dip": 0.25, "pec_feather": 0.0, "pec_spread": Vector2(1.0, -1.1),
		"pec_lengths": [0.55, 0.75, 0.9, 1.0, 1.0, 0.97, 0.92, 0.84, 0.74, 0.62],
		"ray_pale": Color(0.97, 0.97, 0.95), "ray_band": 0.0, "pec_band": 0.0, "pec_spots": 0.0, "pec_alpha": Vector2(0.3, 0.1),
		"soft_alpha": Vector2(0.22, 0.06), "tentacle": 0.22, "tentacles": 1, "cirri": 0,
	},
	{  # Fuzzy Dwarf, Dendrochirus brachypterus: stocky, mottled rust-brown, round banded fans.
		"albedo": Color(0.56, 0.3, 0.17), "ground": Color(0.56, 0.3, 0.17), "ground_tint": 1.0,
		"band": Color(0.3, 0.12, 0.06), "band_tint": 1.0, "band_shade": 0.5, "band_strength": 0.9,
		"band_period": 0.1, "band_duty": Vector2(0.38, 0.55), "band_soft": 0.12, "thin_line": 0.0,
		"mottle": 0.85, "stalk_lines": 0.0, "belly_lift": 1.6, "eye_bar": 0.7, "roughness": 0.55,
		"iris": Color(0.86, 0.47, 0.22), "stocky": 1.0, "ray_thick": 1.0,
		"spine_len": 0.82, "spine_web": 0.62, "spine_pale": Color(0.86, 0.62, 0.46), "spine_band": 0.036, "spine_band_to": 100.0,
		"spine_flag": 0.008, "web_color": Color(0.86, 0.66, 0.52), "web_alpha": Vector2(0.88, 0.6), "web_band": 0.75,
		"pec_len": 0.33, "pec_rays": 13, "pec_web": 1.0, "pec_dip": 0.1, "pec_feather": 0.0, "pec_spread": Vector2(1.15, -1.15),
		"pec_lengths": [0.62, 0.8, 0.92, 0.99, 1.0, 1.0, 0.98, 0.92, 0.84, 0.72],
		"ray_pale": Color(0.88, 0.66, 0.5), "ray_band": 0.034, "pec_band": 0.05, "pec_spots": 0.0, "pec_alpha": Vector2(0.92, 0.7),
		"soft_alpha": Vector2(0.6, 0.3), "tentacle": 0.22, "tentacles": 2, "cirri": 30,
	},
	{  # Spotfin Lionfish, Pterois antennata: blush pink with red bands, tall white spines, spotted fans.
		"albedo": Color(0.7, 0.15, 0.15), "ground": Color(0.94, 0.82, 0.79), "ground_tint": 0.0,
		"band": Color(0.7, 0.15, 0.15), "band_tint": 1.0, "band_shade": 1.0, "band_strength": 1.0,
		"band_period": 0.08, "band_duty": Vector2(0.26, 0.44), "band_soft": 0.02, "thin_line": 0.35,
		"mottle": 0.0, "stalk_lines": 0.0, "belly_lift": 1.08, "eye_bar": 1.0, "roughness": 0.34,
		"iris": Color(0.8, 0.3, 0.15), "stocky": 0.0, "ray_thick": 1.3,
		"spine_len": 1.55, "spine_web": 0.3, "spine_pale": Color(0.97, 0.95, 0.94), "spine_band": 0.04, "spine_band_to": 0.2,
		"spine_flag": 0.0, "web_color": Color(0.95, 0.86, 0.83), "web_alpha": Vector2(0.6, 0.3), "web_band": 0.6,
		"pec_len": 0.5, "pec_rays": 14, "pec_web": 0.55, "pec_dip": 0.28, "pec_feather": 0.0, "pec_spread": Vector2(1.05, -1.1),
		"pec_lengths": [0.6, 0.8, 0.94, 1.0, 1.0, 0.96, 0.9, 0.82, 0.72, 0.6],
		"ray_pale": Color(0.97, 0.96, 0.95), "ray_band": 0.0, "pec_band": 0.0, "pec_spots": 1.0, "pec_alpha": Vector2(0.65, 0.35),
		"soft_alpha": Vector2(0.4, 0.18), "tentacle": 0.5, "tentacles": 1, "cirri": 0,
	},
]

## How long each of the 13 dorsal spines is, front to back, of the longest.
const DORSAL := [0.5, 0.82, 0.97, 1.0, 0.97, 0.9, 0.82, 0.74, 0.65, 0.56, 0.47, 0.38, 0.3]


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.skin, 0, LOOKS.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var stocky: float = look.stocky
	var albedo: Color = look.albedo
	# The body: a big deep head tapering to a slim tail stalk; the dwarf shorter
	# and chunkier.
	var ends := Vector2(-l * lerpf(0.47, 0.45, stocky), l * lerpf(0.31, 0.23, stocky))
	var semi := Vector2(w * lerpf(0.125, 0.15, stocky), h * 0.5)
	var profile := func(along: float) -> Vector3:
		var widest := lerpf(0.32, 0.36, stocky)
		var stalk := lerpf(0.87, 0.85, stocky)
		var stalk_size := lerpf(0.27, 0.32, stocky)
		var deep := _depth(along, widest, stalk, stalk_size, 0.62)
		var wide := _depth(along, widest * 0.85, stalk, stalk_size * 1.3, 0.5)
		var head := 1.0 - smoothstep(0.0, 0.45, along)
		var slim := lerpf(1.0, 0.55, smoothstep(0.3, 0.95, along))
		return Vector3(semi.x * wide * slim, semi.y * deep, -semi.y * 0.22 * pow(head, 1.5))
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var surface := func(along: float, up: float) -> Vector3: return FishModel._loft_point(ends, profile, at.call(along), up)
	m._body_material = m._material(albedo)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	for key: String in ["albedo", "ground", "ground_tint", "band", "band_tint", "band_shade", "band_strength", "band_period",
			"band_duty", "band_soft", "thin_line", "mottle", "stalk_lines", "belly_lift", "eye_bar", "roughness"]:
		skin.set_shader_parameter(key, look[key])
	skin.set_shader_parameter("mottle_color", albedo.darkened(0.55))
	skin.set_shader_parameter("fleck_color", Color(0.95, 0.85, 0.74))
	skin.set_shader_parameter("band_bulge", l * 0.025)
	skin.set_shader_parameter("head_z", at.call(0.24))
	skin.set_shader_parameter("stalk_from", at.call(0.7))
	skin.set_shader_parameter("nose_z", ends.x)
	var nose: Vector3 = profile.call(0.02)
	skin.set_shader_parameter("mouth_y", nose.z - semi.y * 0.05)
	skin.set_shader_parameter("mouth_back", span * 0.1)
	skin.set_shader_parameter("gill_z", at.call(0.25))
	skin.set_shader_parameter("girth", (semi.x + semi.y) / 2.0)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m._loft_mesh(ends, profile, 64, 40)
	body.material_override = skin
	m.add_child(body)
	# Eyes high on the head, set deep; the bar through them is painted.
	var eye_radius := h * 0.085
	var eye_spot: Vector3 = surface.call(0.13, 0.42)
	var eye := Vector3(eye_spot.x - eye_radius * 0.45, eye_spot.y, eye_spot.z)
	skin.set_shader_parameter("eye_at", eye)
	skin.set_shader_parameter("eye_radius", eye_radius)
	for side: float in [-1.0, 1.0]:
		var ball := m._real_eye(eye * Vector3(side, 1.0, 1.0), eye_radius, Vector3(side * 0.9, 0.25, -0.35), look.iris, 0.45)
		var material := ball.material_override as ShaderMaterial
		material.set_shader_parameter("rim_color", albedo.darkened(0.6))
		material.set_shader_parameter("iris_inner", (look.iris as Color).darkened(0.5))
	# Fin and spine materials: the bands follow the body's tint.
	var spine_band_fixed: Color = albedo.darkened(0.25) if stocky > 0.5 else albedo
	var spines := _spine_material(m, look, look.spine_pale, look.spine_band, spine_band_fixed)
	spines.set_shader_parameter("band_range", Vector2(0.0, look.spine_band_to))
	var crest := _web_material(m, look, look.web_color, look.web_alpha, look.web_band, look.spine_band, spine_band_fixed)
	for material: ShaderMaterial in [spines, crest]:
		_wave(material, Vector3.RIGHT, h * 0.012, h * look.spine_len, 0.6, 0.8, 0.35)
	var soft_rays := _spine_material(m, look, look.ray_pale if look.ray_band <= 0.0 else look.spine_pale, 0.028, spine_band_fixed)
	soft_rays.set_shader_parameter("band_duty", 0.4)
	var soft_web := _web_material(m, look, look.web_color, look.soft_alpha, 0.0, 0.0, spine_band_fixed)
	for material: ShaderMaterial in [soft_rays, soft_web]:
		_wave(material, Vector3.RIGHT, h * 0.03, h * 0.45, 0.9, 1.4, 0.5)
	# The dorsal crest: 13 long spines rising off the back, leaning back more
	# toward the rear, their tips curving back, webbed at their bases.
	var bent: Array = []
	var crest_rays: Array = []
	for k in DORSAL.size():
		var t := float(k) / (DORSAL.size() - 1)
		var root: Vector3 = surface.call(lerpf(0.2, 0.6, t), 1.0) * Vector3(0.0, 1.0, 1.0) - Vector3(0.0, h * 0.04, 0.0)
		var lean := lerpf(0.22, 0.75, t)
		var length := h * float(look.spine_len) * float(DORSAL[k]) + h * 0.04
		crest_rays.append(_ray(root, Vector3(0.0, cos(lean), sin(lean)), Vector3(0.0, -0.04, 0.14), length, k))
	bent.append(_tubes(m, crest_rays, Vector3.RIGHT, h * 0.02, 5, 7, spines, "DorsalSpines"))
	bent.append(_webs(m, crest_rays, Vector3.RIGHT, look.spine_web, 0.45, 0.0, look.spine_flag, crest, "DorsalWeb"))
	# The soft dorsal and anal fins behind it, rounded, their rays spotted.
	var soft_lengths := [0.32, 0.42, 0.46, 0.47, 0.46, 0.43, 0.38, 0.32, 0.25, 0.17]
	var dorsal_rays: Array = []
	for k in soft_lengths.size():
		var t := float(k) / (soft_lengths.size() - 1)
		var root: Vector3 = surface.call(lerpf(0.61, 0.83, t), 1.0) * Vector3(0.0, 1.0, 1.0) - Vector3(0.0, h * 0.025, 0.0)
		var lean := lerpf(0.75, 1.25, t)
		dorsal_rays.append(_ray(root, Vector3(0.0, cos(lean), sin(lean)), Vector3(0.0, 0.0, 0.08), h * float(soft_lengths[k]) * lerpf(1.0, 0.85, stocky), k))
	bent.append(_tubes(m, dorsal_rays, Vector3.RIGHT, h * 0.009, 4, 6, soft_rays, "SoftDorsalRays"))
	bent.append(_webs(m, dorsal_rays, Vector3.RIGHT, 1.0, 0.07, 0.0, 0.0, soft_web, "SoftDorsal"))
	var anal_lengths := [0.18, 0.3, 0.38, 0.42, 0.42, 0.38, 0.31, 0.22]
	var anal_rays: Array = []
	for k in anal_lengths.size():
		var t := float(k) / (anal_lengths.size() - 1)
		var root: Vector3 = surface.call(lerpf(0.62, 0.8, t), -1.0) * Vector3(0.0, 1.0, 1.0) + Vector3(0.0, h * 0.025, 0.0)
		var lean := lerpf(0.55, 1.15, t)
		anal_rays.append(_ray(root, Vector3(0.0, -cos(lean), sin(lean)), Vector3(0.0, 0.0, 0.08), h * float(anal_lengths[k]), k))
	bent.append(_tubes(m, anal_rays, Vector3.RIGHT, h * 0.009, 4, 6, soft_rays, "AnalRays"))
	bent.append(_webs(m, anal_rays, Vector3.RIGHT, 1.0, 0.07, 0.0, 0.0, soft_web, "Anal"))
	# The great pectoral fans behind the gills, on the swim animation's pivots:
	# rays fanning out back and to the side from high to low, webbed part way
	# (the dwarf to the tips) and pleated like a folding fan.
	var root_at: Vector3 = surface.call(0.29, -0.15)
	m._fin_pivots(Vector3(root_at.x * 0.8, root_at.y, root_at.z))
	for side: float in [-1.0, 1.0]:
		_pectoral(m, look, side, spine_band_fixed)
	# Pelvic fins under the chest.
	for side: float in [-1.0, 1.0]:
		var base: Vector3 = surface.call(0.32, -0.9) * Vector3(side * 0.6, 0.97, 1.0)
		var out := Vector3(side * 0.3, -1.0, 0.75).normalized()
		var normal := out.cross(Vector3.BACK).normalized()
		var spread := normal.cross(out).normalized()
		var pelvic_rays: Array = []
		for k in 6:
			var angle := lerpf(0.4, -0.45, k / 5.0)
			var direction := out * cos(angle) + spread * sin(angle)
			pelvic_rays.append(_ray(base + Vector3(0.0, 0.0, k * l * 0.006), direction, Vector3(0.0, 0.0, 0.08), h * lerpf(0.5, 0.36, absf(k - 2.0) / 3.0), k))
		var pelvic_spines := _spine_material(m, look, look.ray_pale if look.ray_band <= 0.0 else look.spine_pale, 0.03, spine_band_fixed)
		var pelvic_web := _web_material(m, look, look.web_color, look.pec_alpha, look.web_band, 0.03, spine_band_fixed)
		for material: ShaderMaterial in [pelvic_spines, pelvic_web]:
			_wave(material, normal, h * 0.025, h * 0.45, 0.8, 1.2, 0.5)
		_tubes(m, pelvic_rays, normal, h * 0.01, 4, 6, pelvic_spines, "PelvicRays")
		_webs(m, pelvic_rays, normal, 0.85, 0.15, 0.0, 0.0, pelvic_web, "Pelvic")
	# The tail: a rounded fan of spotted rays, its root set well into the stalk.
	m._tail_pivot(Vector3(0.0, 0.0, at.call(0.94)))
	var stalk: float = profile.call(0.94).y
	var tail_lengths := [0.78, 0.9, 0.97, 1.0, 1.0, 1.0, 1.0, 1.0, 0.97, 0.9, 0.78]
	var tail_rays: Array = []
	for k in tail_lengths.size():
		var t := float(k) / (tail_lengths.size() - 1)
		var angle := lerpf(0.72, -0.72, t)
		var root := Vector3(0.0, lerpf(stalk, -stalk, t) * 0.85, -l * 0.045)
		tail_rays.append(_ray(root, Vector3(0.0, sin(angle), cos(angle)), Vector3.ZERO, l * lerpf(0.21, 0.2, stocky) * float(tail_lengths[k]), k))
	var tail_spines := _spine_material(m, look, look.ray_pale if look.ray_band <= 0.0 else look.spine_pale, 0.028, spine_band_fixed)
	tail_spines.set_shader_parameter("band_duty", 0.4)
	tail_spines.set_shader_parameter("band_range", Vector2(l * 0.06, 100.0))
	var tail_web := _web_material(m, look, look.web_color, look.soft_alpha, 0.0, 0.0, spine_band_fixed)
	for material: ShaderMaterial in [tail_spines, tail_web]:
		_wave(material, Vector3.RIGHT, l * 0.012, l * 0.2, 0.8, 1.5, 0.35)
	_tubes(m.tail, tail_rays, Vector3.RIGHT, h * 0.01, 4, 7, tail_spines, "TailRays")
	_webs(m.tail, tail_rays, Vector3.RIGHT, 1.0, 0.05, 0.0, 0.0, tail_web, "TailFin")
	# Fleshy tentacles over the eyes (the dwarf's frillier, with skin flaps
	# all over its head and flanks, its fuzzy look).
	var tentacle_material := _spine_material(m, look, look.spine_pale, 0.02 if look.spine_band > 0.0 else 0.0, spine_band_fixed)
	tentacle_material.set_shader_parameter("band_duty", 0.5)
	_wave(tentacle_material, Vector3.BACK, h * 0.02, h * 0.3, 0.5, 1.0, 0.0)
	var tentacles: Array = []
	for side: float in [-1.0, 1.0]:
		for k in int(look.tentacles):
			var root := eye * Vector3(side * 0.7, 1.0, 1.0) + Vector3(0.0, eye_radius * 0.8, eye_radius * (k * 1.4 - 0.2))
			var direction := Vector3(side * 0.25, 1.0, 0.2 + 0.35 * k).normalized()
			tentacles.append(_ray(root, direction, Vector3(0.0, 0.0, 0.25), h * float(look.tentacle) * (1.0 - 0.3 * k), side * 10.0 + k))
	_tubes(m, tentacles, Vector3.BACK, h * 0.028, 5, 7, tentacle_material, "Tentacles", 0.15, 2.2)
	var cirri: Array = []
	for k in int(look.cirri):
		var along := 0.06 + 0.7 * fmod(k * 0.618034, 1.0)
		var up := lerpf(-0.6, 0.85, fmod(k * 0.381966 + 0.2, 1.0))
		var side := -1.0 if k % 2 == 0 else 1.0
		var root: Vector3 = surface.call(along, up) * Vector3(side * 0.96, 1.0, 1.0)
		var slice: Vector3 = profile.call(along)
		var normal := Vector3(root.x / maxf(slice.x * slice.x, 1e-4), (root.y - slice.z) / maxf(slice.y * slice.y, 1e-4), 0.0).normalized()
		cirri.append(_ray(root, (normal + Vector3(0.0, 0.2, 0.6)).normalized(), Vector3(0.0, 0.1, 0.2), h * lerpf(0.08, 0.16, fmod(k * 0.7548, 1.0)), k))
	if not cirri.is_empty():
		bent.append(_tubes(m, cirri, Vector3.UP, h * 0.016, 4, 3, tentacle_material, "Cirri", 0.15, 1.6))
	# The rear of the body flexes into the tail.
	m.bend_share = 0.62
	m._bend_body(at.call(0.42), bent)


## How deep (or wide) a lionfish is `along` it (nose 0 to tail 1), of its
## most: a snout (`nose` toward 1 the blunter) swelling to `widest`, holding its
## depth through the middle of the body before narrowing to the tail stalk,
## `stalk_size` at `stalk`, with a rounded end.
static func _depth(along: float, widest: float, stalk: float, stalk_size: float, nose: float) -> float:
	if along < widest:
		return pow(maxf(1.0 - pow((widest - along) / widest, 2.0), 0.0), nose)
	if along < stalk:
		var t := pow((along - widest) / (stalk - widest), 1.4)
		return lerpf(1.0, stalk_size, t * t * (3.0 - 2.0 * t))
	return stalk_size * sqrt(maxf(1.0 - pow((along - stalk) / (1.0 - stalk), 2.0), 0.0))


## One pectoral fan (side -1 left, 1 right) on its fin pivot (see LOOKS).
static func _pectoral(m: FishModel, look: Dictionary, side: float, band_fixed: Color) -> void:
	var l := m._size.z
	var h := m._size.y
	var pivot := m.fin_left if side < 0.0 else m.fin_right
	var out := Vector3(side * 0.62, -0.18, 0.78).normalized()
	var spread := (Vector3.UP - out * out.dot(Vector3.UP)).normalized()
	var normal := out.cross(spread).normalized()
	var length := l * float(look.pec_len)
	var count: int = look.pec_rays
	var range_v: Vector2 = look.pec_spread
	var lengths: Array = look.pec_lengths
	var rays: Array = []
	for k in count:
		var t := float(k) / (count - 1)
		var angle := lerpf(range_v.x, range_v.y, t)
		var direction := out * cos(angle) + spread * sin(angle)
		# The root runs down a short line on the body; rays sweep back and droop.
		var root := spread * lerpf(h * 0.08, -h * 0.08, t) - Vector3(side * h * 0.02, 0.0, 0.0)
		var bow := Vector3(side * 0.04, -0.06 * t, 0.18)
		rays.append(_ray(root, direction, bow, length * FishModel._sample(lengths, t), k))
	var ray_material := _spine_material(m, look, look.ray_pale, look.ray_band, band_fixed)
	var web_material := _web_material(m, look, look.web_color, look.pec_alpha, 0.9 if float(look.pec_band) > 0.0 else 0.0, look.pec_band, band_fixed)
	web_material.set_shader_parameter("spots", look.pec_spots)
	web_material.set_shader_parameter("spot_size", l * 0.03)
	for material: ShaderMaterial in [ray_material, web_material]:
		_wave(material, normal, length * 0.07, length, 0.85, 1.0, 0.45)
	var thick := 0.012 if float(look.pec_web) >= 1.0 else 0.009
	_tubes(pivot, rays, normal, h * thick * float(look.ray_thick), 5, 10, ray_material, "PectoralRays")
	_webs(pivot, rays, normal, look.pec_web, look.pec_dip, length * 0.035, look.pec_feather, web_material, "Pectoral")


# --- Materials -----------------------------------------------------------------

## Spines and rays (lionfish_spine.gdshader): `pale` with bands `band_len` m
## apart (0 for none) in the body's tinted colour (or `band_fixed`).
static func _spine_material(m: FishModel, look: Dictionary, pale: Color, band_len: float, band_fixed: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SPINE
	material.set_shader_parameter("albedo", look.albedo)
	material.set_shader_parameter("band_fixed", band_fixed)
	material.set_shader_parameter("band_tint", 1.0)
	material.set_shader_parameter("band_shade", 0.75 if float(look.stocky) > 0.5 else 1.0)
	material.set_shader_parameter("pale", pale)
	material.set_shader_parameter("band_len", band_len)
	material.set_shader_parameter("band_duty", 0.55)
	m._skins.append(material)
	m._waving.append(material)
	return material


## Webs (lionfish_web.gdshader): `color` see-through from `alpha` (root, edge),
## banded `band` strong every `band_len` m.
static func _web_material(m: FishModel, look: Dictionary, color: Color, alpha: Vector2, band: float, band_len: float, band_fixed: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WEB
	material.set_shader_parameter("albedo", look.albedo)
	material.set_shader_parameter("band_fixed", band_fixed)
	material.set_shader_parameter("band_tint", 1.0)
	material.set_shader_parameter("band_shade", 0.75 if float(look.stocky) > 0.5 else 1.0)
	material.set_shader_parameter("web_color", color)
	material.set_shader_parameter("pale", color)
	material.set_shader_parameter("alpha_root", alpha.x)
	material.set_shader_parameter("alpha_edge", alpha.y)
	material.set_shader_parameter("band_strength", band)
	material.set_shader_parameter("band_len", band_len)
	material.set_shader_parameter("band_duty", 0.5)
	m._skins.append(material)
	m._waving.append(material)
	return material


## How a fin ripples (lionfish_fin.gdshaderinc): out of its plane along
## `normal`, `amp` m at `reach` m out, `waves` along that, at `tempo`, the wave
## stepping `shift` rad from ray to ray.
static func _wave(material: ShaderMaterial, normal: Vector3, amp: float, reach: float, waves: float, tempo: float, shift: float) -> void:
	material.set_shader_parameter("wave_normal", normal.normalized())
	material.set_shader_parameter("wave_amp", amp)
	material.set_shader_parameter("ref_len", maxf(reach, 0.01))
	material.set_shader_parameter("waves", waves)
	material.set_shader_parameter("tempo", tempo)
	material.set_shader_parameter("coord_shift", shift)


# --- Geometry ------------------------------------------------------------------

## A ray (spine, fin ray, tentacle): from `root` along `direction`, curving by
## `bow` (of its length, toward the tip), `length` m long, number `coord`.
static func _ray(root: Vector3, direction: Vector3, bow: Vector3, length: float, coord: float) -> Dictionary:
	return {"root": root, "dir": direction.normalized(), "bow": bow, "length": length, "coord": coord}


## Where a ray is `t` of the way out (0 root, 1 tip).
static func _ray_point(ray: Dictionary, t: float) -> Vector3:
	var root: Vector3 = ray.root
	var direction: Vector3 = ray.dir
	var bow: Vector3 = ray.bow
	var length: float = ray.length
	return root + (direction * t + bow * t * t) * length


static func _ray_tangent(ray: Dictionary, t: float) -> Vector3:
	var direction: Vector3 = ray.dir
	var bow: Vector3 = ray.bow
	return (direction + bow * 2.0 * t).normalized()


## `rays` as tapered tubes (`sides` round, `rings` along), `radius` thick at the
## root thinning to `tip` of that, `flat` times wider across `normal`'s plane,
## in one mesh on `parent`.
static func _tubes(parent: Node3D, rays: Array, normal: Vector3, radius: float, sides: int, rings: int,
		material: ShaderMaterial, part_name: String, tip := 0.1, flat := 1.0) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := 0
	for ray: Dictionary in rays:
		var length: float = ray.length
		var coord: float = ray.coord
		for i in rings + 1:
			var t := float(i) / rings
			var centre := _ray_point(ray, t)
			var tangent := _ray_tangent(ray, t)
			var across := (normal - tangent * tangent.dot(normal))
			if across.length() < 1e-4:
				across = tangent.cross(Vector3.RIGHT if absf(tangent.x) < 0.9 else Vector3.UP)
			across = across.normalized()
			var side := tangent.cross(across).normalized()
			var r := radius * lerpf(1.0, tip, pow(t, 0.8))
			for k in sides + 1:
				var angle := TAU * k / sides
				tool.set_uv(Vector2(float(k) / sides, t))
				tool.set_uv2(Vector2(length * t, coord))
				tool.add_vertex(centre + (across * cos(angle) + side * sin(angle) * flat) * r)
		for i in rings:
			for k in sides:
				var a := first + i * (sides + 1) + k
				var b := a + 1
				var c := a + sides + 1
				var d := c + 1
				for corner: int in [a, c, b, b, c, d]:
					tool.add_index(corner)
		first += (rings + 1) * (sides + 1)
	return _commit(parent, tool, material, part_name)


## The web between neighbouring `rays`, out to `web` of their length, dipping
## between them by `dip` (of that), pleated out of the fin's plane by `pleat` m
## (folding back and forth like a fan's); past the web each ray carries a
## feathery flag `feather` m wide (0 for none). One mesh on `parent`.
static func _webs(parent: Node3D, rays: Array, normal: Vector3, web: float, dip: float, pleat: float,
		feather: float, material: ShaderMaterial, part_name: String) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := 0
	var columns := 6
	var rows := 9
	for g in rays.size() - 1:
		var a: Dictionary = rays[g]
		var b: Dictionary = rays[g + 1]
		var length_a: float = a.length
		var length_b: float = b.length
		var coord_a: float = a.coord
		var coord_b: float = b.coord
		var fold := 1.0 if g % 2 == 0 else -1.0
		for c in columns + 1:
			var u := float(c) / columns
			var hump := sin(PI * u)
			var reach := web * (1.0 - dip * pow(hump, 0.7))
			for r in rows + 1:
				var v := float(r) / rows
				var t := v * reach
				var point := _ray_point(a, t).lerp(_ray_point(b, t), u) + normal * pleat * fold * hump * v
				tool.set_uv(Vector2(u, v))
				tool.set_uv2(Vector2(lerpf(length_a, length_b, u) * t, lerpf(coord_a, coord_b, u)))
				tool.add_vertex(point)
		for c in columns:
			for r in rows:
				var i := first + c * (rows + 1) + r
				var j := i + rows + 1
				for corner: int in [i, j, i + 1, i + 1, j, j + 1]:
					tool.add_index(corner)
		first += (columns + 1) * (rows + 1)
	# Feathery flags along the free rays: a narrow leaf either side, widest
	# midway, folded a little along the ray.
	if feather > 0.0 and web < 1.0:
		var steps := 8
		for ray: Dictionary in rays:
			var length: float = ray.length
			var coord: float = ray.coord
			var from := web * 0.85
			for i in steps + 1:
				var s := float(i) / steps
				var t := lerpf(from, 1.0, s)
				var centre := _ray_point(ray, t)
				var tangent := _ray_tangent(ray, t)
				var flank := tangent.cross(normal).normalized()
				var half := feather * pow(sin(PI * minf(s * 1.15, 1.0)), 0.6) * (1.0 - 0.4 * s)
				for o: float in [-1.0, 0.0, 1.0]:
					var ruffle := normal * half * (0.35 * absf(o) + 0.25 * sin(s * 14.0 + o * 2.0) * absf(o))
					tool.set_uv(Vector2(0.5 + o * 0.5, lerpf(0.55, 1.0, absf(o))))
					tool.set_uv2(Vector2(length * t, coord))
					tool.add_vertex(centre + flank * half * o + ruffle)
			for i in steps:
				for o in 2:
					var a := first + i * 3 + o
					var b := a + 1
					var c := a + 3
					var d := c + 1
					for corner: int in [a, c, b, b, c, d]:
						tool.add_index(corner)
			first += (steps + 1) * 3
	return _commit(parent, tool, material, part_name)


static func _commit(parent: Node3D, tool: SurfaceTool, material: ShaderMaterial, part_name: String) -> MeshInstance3D:
	tool.generate_normals()
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = tool.commit()
	part.material_override = material
	part.extra_cull_margin = 0.2  # it ripples out of its bounds
	parent.add_child(part)
	return part
