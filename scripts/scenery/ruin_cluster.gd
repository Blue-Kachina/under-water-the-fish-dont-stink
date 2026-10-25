class_name RuinCluster
extends RefCounted
## One small temple ruin on the seabed (planning_environment.md, Phase 4),
## built from a seed as one marble mesh: a two-step platform half sunk in the
## sand, a colonnade along one side (columns standing, broken off, or fallen
## beside it), a stretch of architrave where neighbours still stand, a row of
## stumps along the other side, a statue standing on its plinth or toppled,
## and rubble round it all. About 14-20 m across, centred on the origin.

const GODS := ["poseidon", "tyche", "hades", "aphrodite"]


static func build(seed_value: int) -> MeshKit:
	var kit := MeshKit.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var width := dice.randf_range(13.0, 18.0)
	var depth := dice.randf_range(8.0, 11.0)
	var tilt := Basis(Vector3.RIGHT, dice.randf_range(-0.04, 0.04)) * Basis(Vector3.BACK, dice.randf_range(-0.03, 0.03))
	var floor_y := 0.55
	kit.merge(GreekKit.block(Vector3(width, 0.45, depth), seed_value + 1), Transform3D(tilt, Vector3(0.0, -0.2, 0.0)))
	kit.merge(GreekKit.block(Vector3(width - 0.9, 0.4, depth - 0.9), seed_value + 2), Transform3D(tilt, Vector3(0.0, 0.18, 0.0)))
	# The colonnade along the far side (+Z), columns every ~2.6 m.
	var count := maxi(roundi((width - 1.6) / 2.6), 3)
	var gap := (width - 1.6) / (count - 1)
	var standing := PackedByteArray()
	standing.resize(count)
	for n in count:
		var x := -width * 0.5 + 0.8 + gap * n
		var at := tilt * Vector3(x, floor_y, depth * 0.5 - 0.9)
		var turn := Basis(Vector3.UP, dice.randf() * TAU)
		var roll := dice.randf()
		if roll < 0.5:
			kit.merge(GreekKit.column(GreekKit.COLUMN_HEIGHT, seed_value + 10 + n), Transform3D(tilt * turn, at))
			standing[n] = 1
		elif roll < 0.8:
			kit.merge(GreekKit.drum(dice.randf_range(0.6, 2.2), GreekKit.COLUMN_RADIUS, true, seed_value + 10 + n), Transform3D(tilt * turn, at))
		else:
			var away := Basis(Vector3.UP, dice.randf_range(-0.6, 0.6) - PI / 2.0)
			kit.merge(GreekKit.fallen_column(4, seed_value + 10 + n), Transform3D(away, at + Vector3(dice.randf_range(-0.5, 0.5), -floor_y + 0.05,
					dice.randf_range(0.6, 1.4))))
	# Architrave blocks over neighbours that still stand (one may have slid off).
	for n in count - 1:
		if standing[n] and standing[n + 1]:
			var x := -width * 0.5 + 0.8 + gap * (n + 0.5)
			var beam := GreekKit.block(Vector3(gap + 0.5, 0.55, 0.62), seed_value + 30 + n, true)
			if dice.randf() < 0.25:
				kit.merge(beam, Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, 0.15),
						Vector3(x + dice.randf_range(-1.0, 1.0), 0.0, depth * 0.5 + dice.randf_range(0.8, 2.0))))
			else:
				kit.merge(beam, Transform3D(tilt, tilt * Vector3(x, floor_y + GreekKit.COLUMN_HEIGHT, depth * 0.5 - 0.9)))
	# Stumps along the near side.
	for n in count:
		if dice.randf() < 0.55:
			var x := -width * 0.5 + 0.8 + gap * n
			kit.merge(GreekKit.drum(dice.randf_range(0.25, 0.9), GreekKit.COLUMN_RADIUS, true, seed_value + 50 + n),
					Transform3D(tilt * Basis(Vector3.UP, dice.randf() * TAU), tilt * Vector3(x, floor_y, -depth * 0.5 + 0.9)))
	# A statue: standing on its plinth, or toppled off it.
	var god: String = GODS[dice.randi() % GODS.size()]
	var plinth_at := tilt * Vector3(dice.randf_range(-width * 0.25, width * 0.25), floor_y, dice.randf_range(-0.5, 1.0))
	kit.merge(GreekKit.block(Vector3(1.0, 0.9, 1.0), seed_value + 60), Transform3D(tilt, plinth_at))
	var statue := GreekKit.statue(god, seed_value + 61)
	if dice.randf() < 0.5:
		kit.merge(statue, Transform3D(tilt * Basis(Vector3.UP, dice.randf_range(-0.5, 0.5)), plinth_at + Vector3.UP * 0.9))
	else:
		var lie := Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.BACK, PI / 2.0 + dice.randf_range(-0.1, 0.1))
		kit.merge(statue, Transform3D(lie, plinth_at + Vector3(dice.randf_range(-2.0, 2.0), 0.15, -depth * 0.5 - 1.8)))
	# Rubble round it.
	for n in 14:
		var angle := dice.randf() * TAU
		var r := dice.randf_range(width * 0.4, width * 0.75)
		var at := Vector3(cos(angle) * r, -0.1, sin(angle) * r * depth / width * 1.2)
		var turn := Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, dice.randf_range(-0.3, 0.3))
		match n % 5:
			0:
				kit.merge(GreekKit.drum(dice.randf_range(0.6, 1.0), GreekKit.COLUMN_RADIUS, dice.randf() < 0.5, seed_value + 70 + n),
						Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.BACK, PI / 2.0), at + Vector3.UP * 0.28))
			1:
				kit.merge(GreekKit.capital(GreekKit.COLUMN_RADIUS * 0.94, seed_value + 70 + n), Transform3D(turn, at))
			2:
				kit.merge(GreekKit.amphora(dice.randf() < 0.4, dice.randf() < 0.6, seed_value + 70 + n),
						Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.BACK, 1.45), at + Vector3.UP * 0.18))
			_:
				kit.merge(GreekKit.block(Vector3(dice.randf_range(0.5, 1.4), dice.randf_range(0.3, 0.55), dice.randf_range(0.4, 0.8)),
						seed_value + 70 + n), Transform3D(turn, at))
	return kit
