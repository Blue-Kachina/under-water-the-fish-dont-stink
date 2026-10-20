class_name FishModelMore
extends RefCounted
## The looks of the later playable fish (FishModel.build hands them here), each
## built from simple shapes to fill its hitbox like the first six:
## - Lionfish: red and cream bands, fans of long venomous spines;
## - Moon Jelly: a glassy dome, trailing frilled arms and tentacles;
## - Mantis Shrimp: armoured segments, stalk eyes and two club claws;
## - Baby Whale Shark: a stout spotted slate body, a wide flat head and a mean little face.
## They only use FishModel's helpers (parts, eyes, fin membranes, the pivots
## the swim animation moves), so they swim like the others.

static func build(model: FishModel, family: FishCharacter.Family) -> void:
	match family:
		FishCharacter.Family.LIONFISH:
			_lionfish(model)
		FishCharacter.Family.MOON_JELLY:
			_jelly(model)
		FishCharacter.Family.MANTIS:
			_mantis(model)
		FishCharacter.Family.WHALE_SHARK:
			_whale_shark(model)


static func _lionfish(m: FishModel) -> void:
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var red := Color(0.72, 0.16, 0.1)
	var cream := Color(0.96, 0.9, 0.78)
	m._body_material = m._material(red, 0.5)
	var body := m._part(m, m._sphere(), m._body_material, Vector3(0.0, 0.0, l * 0.02), Vector3(w * 0.5, h * 0.84, l * 0.8))
	body.name = "Body"
	var stripe := m._material(cream, 0.5)
	for k in 5:
		var z := lerpf(-0.26, 0.24, k / 4.0) * l
		var girth := 1.0 - pow(absf(z / (l * 0.4)), 2.0) * 0.55
		m._part(m, m._cylinder(), stripe, Vector3(0.0, 0.0, z + l * 0.02), Vector3(w * 0.52 * girth, l * 0.028, h * 0.86 * girth), Vector3(PI / 2.0, 0.0, 0.0))
	var fins := m._fin_material(red, cream, 12.0, 0.01, 1.6, 0.6)
	m._skins.append(fins)
	# Pectoral fans: long spines radiating from the pivots.
	m._fin_pivots(Vector3(w * 0.22, -h * 0.05, -l * 0.12))
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		for k in 7:
			var fan := lerpf(-0.8, 0.8, k / 6.0)
			var spine_length := l * lerpf(0.34, 0.5, 1.0 - absf(fan))
			var direction := Vector3(side * 0.9, fan * 0.45, 0.45 + fan * 0.5).normalized()
			var spine := m._part(pivot, m._cylinder(), stripe if k % 2 == 0 else m._material(red, 0.5), direction * spine_length * 0.5,
					Vector3(w * 0.016, spine_length, w * 0.016))
			spine.look_at_from_position(spine.position, direction * spine_length, Vector3.UP)
			spine.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			spine.scale = Vector3(w * 0.016, spine_length, w * 0.016)
		m._membrane(pivot, fins, Vector3(0.0, h * 0.06, 0.0), Vector3(0.0, -h * 0.06, 0.0), Vector3(side * 0.9, 0.0, 0.6),
				[l * 0.16, l * 0.26, l * 0.3, l * 0.26, l * 0.16], 0.9, 0.08)
	# A row of dorsal spines, and a soft fan tail.
	for k in 8:
		var z := lerpf(-0.22, 0.22, k / 7.0) * l
		var rise := h * (0.24 + 0.22 * sin(PI * k / 7.0))
		m._part(m, m._cylinder(), stripe if k % 2 == 0 else m._material(red, 0.5), Vector3(0.0, h * 0.4 + rise * 0.45, z),
				Vector3(w * 0.014, rise, w * 0.014), Vector3(0.25, 0.0, 0.0))
	m._tail_pivot(Vector3(0.0, 0.0, l * 0.4))
	m._membrane(m.tail, fins, Vector3(0.0, h * 0.18, 0.0), Vector3(0.0, -h * 0.18, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.14, l * 0.2, l * 0.22, l * 0.2, l * 0.14], -0.5, 0.05)
	for side: float in [-1.0, 1.0]:
		m._eye(Vector3(side * w * 0.2, h * 0.2, -l * 0.3), h * 0.1, Vector3(side * 0.8, 0.1, -0.5), 0.6, null, Color(0.9, 0.6, 0.1), 0.4)
	m._mouth(Vector3(0.0, -h * 0.12, -l * 0.395), Vector3(w * 0.1, h * 0.05, 0.03))


static func _jelly(m: FishModel) -> void:
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var glass := Color(0.78, 0.66, 0.96)
	m._body_material = m._material(glass, 0.15, 0.72)
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 0.5
	dome.is_hemisphere = true
	var bell := m._part(m, dome, m._body_material, Vector3(0.0, 0.0, l * 0.1), Vector3(w * 1.0, w * 1.0, l * 0.62) , Vector3(-PI / 2.0, 0.0, 0.0))
	bell.name = "Body"
	bell.scale = Vector3(w * 0.98, l * 0.62 / 0.5 * 0.5, h * 0.98)  # the rotated dome's own axes: x across, y along, z up
	# Four pale rings (the moon jelly's gonads) seen through the glass.
	var ring_material := m._material(Color(1.0, 0.85, 0.95), 0.3, 0.9)
	for k in 4:
		var angle := TAU * k / 4.0 + 0.4
		m._part(m, m._sphere(), ring_material, Vector3(cos(angle) * w * 0.16, sin(angle) * h * 0.16, -l * 0.02), Vector3(w * 0.11, h * 0.11, l * 0.09))
	var fins := m._fin_material(Color(0.95, 0.75, 1.0), Color(1.0, 0.95, 1.0), 14.0, 0.03, 2.4, 0.5)
	m._skins.append(fins)
	# Frilled oral arms trail either side on the swim animation's pivots.
	m._fin_pivots(Vector3(w * 0.14, -h * 0.1, l * 0.12))
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._membrane(pivot, fins, Vector3(0.0, h * 0.08, 0.0), Vector3(0.0, -h * 0.08, 0.0), Vector3(side * 0.25, -0.2, 1.0),
				[l * 0.2, l * 0.3, l * 0.34, l * 0.3, l * 0.2], 0.6, 0.15)
	# A fringe of tentacles streaming back from the tail pivot.
	m._tail_pivot(Vector3(0.0, -h * 0.05, l * 0.1))
	var thread := m._material(Color(0.85, 0.72, 1.0), 0.3, 0.8)
	for k in 9:
		var angle := TAU * k / 9.0
		var across := Vector3(cos(angle) * w * 0.36, sin(angle) * h * 0.3, 0.0)
		var length := l * (0.3 + 0.1 * (k % 3))
		m._part(m.tail, m._cylinder(), thread, across + Vector3(0.0, 0.0, length * 0.5), Vector3(w * 0.012, length, w * 0.012), Vector3(PI / 2.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		m._eye(Vector3(side * w * 0.2, h * 0.14, -l * 0.1), h * 0.07, Vector3(side * 0.5, 0.2, -0.8), 0.6)


static func _mantis(m: FishModel) -> void:
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var green := Color(0.15, 0.62, 0.35)
	m._body_material = m._material(green, 0.35)
	var plate := m._material(Color(0.95, 0.5, 0.12), 0.4)
	# Armoured segments, widest in the middle, the carapace in front.
	for k in 6:
		var t := k / 5.0
		var z := lerpf(-0.3, 0.3, t) * l
		var scale := Vector3(w * lerpf(0.5, 0.34, t), h * lerpf(0.7, 0.36, t), l * 0.2)
		var segment := m._part(m, m._sphere(), m._body_material if k % 2 == 0 else plate, Vector3(0.0, -h * 0.05 * t, z), scale)
		if k == 0:
			segment.name = "Body"
			segment.scale = Vector3(w * 0.52, h * 0.74, l * 0.3)
	var fins := m._fin_material(Color(0.1, 0.5, 0.85), Color(0.95, 0.5, 0.12), 9.0, 0.01, 2.0, 0.7)
	m._skins.append(fins)
	# Two raptorial claws: a folded arm and a club, on the swim animation's pivots.
	m._fin_pivots(Vector3(w * 0.2, -h * 0.28, -l * 0.3))
	var club := m._material(Color(0.95, 0.5, 0.12), 0.35)
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._part(pivot, m._capsule(), m._body_material, Vector3(side * w * 0.04, -h * 0.02, -l * 0.08), Vector3(w * 0.09, l * 0.2, w * 0.09), Vector3(PI / 2.0, 0.0, 0.0))
		m._part(pivot, m._sphere(), club, Vector3(side * w * 0.04, -h * 0.02, -l * 0.2), Vector3(w * 0.15, w * 0.13, l * 0.12))
	# A tail fan of swimmerets.
	m._tail_pivot(Vector3(0.0, -h * 0.07, l * 0.46))
	m._membrane(m.tail, fins, Vector3(0.0, h * 0.14, 0.0), Vector3(0.0, -h * 0.14, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.1, l * 0.14, l * 0.16, l * 0.14, l * 0.1], -0.4, 0.05)
	# Eyes on stalks, big and a little mad.
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * w * 0.18, h * 0.3, -l * 0.34)
		m._part(m, m._cylinder(), m._body_material, base + Vector3(0.0, h * 0.06, 0.0), Vector3(w * 0.04, h * 0.14, w * 0.04))
		m._eye(base + Vector3(side * w * 0.03, h * 0.15, 0.0), h * 0.09, Vector3(side * 0.5, 0.2, -0.8), 0.55, null, Color(0.9, 0.2, 0.3), 0.4)


static func _whale_shark(m: FishModel) -> void:
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var slate := Color(0.22, 0.32, 0.46)
	m._body_material = m._material(slate, 0.5)
	var belly := m._material(Color(0.88, 0.9, 0.92), 0.5)
	var spot := m._material(Color(0.95, 0.96, 0.9), 0.4)
	var dark := m._material(Color(0.07, 0.08, 0.12), 0.4)
	# A stout body with a wide, flat head, pale underneath.
	var body := m._part(m, m._sphere(), m._body_material, Vector3(0.0, h * 0.03, l * 0.08), Vector3(w * 0.46, h * 0.82, l * 0.6))
	body.name = "Body"
	m._part(m, m._sphere(), m._body_material, Vector3(0.0, 0.0, -l * 0.22), Vector3(w * 0.62, h * 0.62, l * 0.34))
	m._part(m, m._sphere(), belly, Vector3(0.0, -h * 0.16, -l * 0.02), Vector3(w * 0.4, h * 0.5, l * 0.74))
	# White spots over the back in rows, and two ridges down it.
	for row in 5:
		for k in 4:
			var z := lerpf(-0.3, 0.3, row / 4.0) * l
			var x := (k - 1.5) * w * 0.095 + (w * 0.045 if row % 2 else 0.0)
			var y := h * 0.37 * (1.0 - absf(x) / (w * 0.3)) + h * 0.06
			m._part(m, m._sphere(), spot, Vector3(x, y, z + l * 0.04), Vector3(w * 0.03, h * 0.045, l * 0.03))
	for side: float in [-1.0, 1.0]:
		m._part(m, m._capsule(), m._body_material.duplicate(), Vector3(side * w * 0.07, h * 0.4, l * 0.04), Vector3(w * 0.03, l * 0.55, w * 0.03), Vector3(PI / 2.0, 0.0, 0.0))
	var fins := m._fin_material(slate, Color(0.7, 0.78, 0.86), 10.0, 0.01, 1.4, 0.55)
	m._skins.append(fins)
	# Pectorals on the swim animation's pivots: broad, a little swept.
	m._fin_pivots(Vector3(w * 0.26, -h * 0.12, -l * 0.04))
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._part(pivot, m._sphere(), m._body_material, Vector3(side * w * 0.12, 0.0, l * 0.06), Vector3(w * 0.3, h * 0.07, l * 0.22), Vector3(0.0, side * 0.3, 0.0))
		m._membrane(pivot, fins, Vector3(0.0, 0.0, -l * 0.06), Vector3(0.0, 0.0, l * 0.14), Vector3(side * 1.0, 0.0, 0.3),
				[w * 0.08, w * 0.16, w * 0.2, w * 0.14, w * 0.06], 0.3, 0.08)
	# A tail with two crescent lobes, the upper longer.
	m._tail_pivot(Vector3(0.0, 0.0, l * 0.38))
	m._part(m.tail, m._capsule(), m._body_material, Vector3(0.0, h * 0.28, l * 0.08), Vector3(w * 0.05, h * 0.9, w * 0.05), Vector3(0.7, 0.0, 0.0))
	m._part(m.tail, m._capsule(), m._body_material, Vector3(0.0, -h * 0.18, l * 0.06), Vector3(w * 0.045, h * 0.55, w * 0.045), Vector3(-0.7, 0.0, 0.0))
	m._part(m.tail, m._sphere(), m._body_material, Vector3(0.0, 0.0, l * 0.02), Vector3(w * 0.13, h * 0.3, l * 0.16))
	# A mean face: small hard eyes under heavy brows, a wide downturned mouth with a row of little teeth.
	for side: float in [-1.0, 1.0]:
		var eye := Vector3(side * w * 0.27, h * 0.2, -l * 0.3)
		m._eye(eye, h * 0.075, Vector3(side * 0.5, 0.0, -0.85), 0.75, null, Color(0.85, 0.65, 0.1), 0.4)
		m._part(m, m._capsule(), dark, eye + Vector3(-side * w * 0.01, h * 0.11, -l * 0.005), Vector3(w * 0.035, w * 0.17, w * 0.035), Vector3(0.0, 0.0, -side * 1.1 + PI / 2.0 * 0.0))
	var mouth_y := -h * 0.1
	m._part(m, m._capsule(), dark, Vector3(0.0, mouth_y, -l * 0.385), Vector3(w * 0.025, w * 0.34, w * 0.025), Vector3(0.0, 0.0, PI / 2.0))
	for side: float in [-1.0, 1.0]:
		m._part(m, m._capsule(), dark, Vector3(side * w * 0.19, mouth_y - h * 0.045, -l * 0.37), Vector3(w * 0.025, w * 0.09, w * 0.025), Vector3(0.0, 0.0, PI / 2.0 + side * 0.7))
	for k in 7:
		var x := (k - 3.0) * w * 0.045
		m._part(m, m._prism(), spot, Vector3(x, mouth_y - h * 0.035, -l * 0.382), Vector3(w * 0.026, h * 0.07, w * 0.02), Vector3(PI, 0.0, 0.0))
