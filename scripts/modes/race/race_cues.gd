class_name RaceCues
extends Node3D
## The guidance dressed along a track (planning_race.md section 6): lantern buoys on the racing line, glow coral on the
## channel's walls, arrow glyphs on the outer wall before each bend, a dotted stripe on the floor under the racing line,
## and lights in the roofed stretches. All of it is look: nothing here collides. The cues find the walls and floor with
## Terrain's queries, so build() runs after the terrain is up and in the tree.

const GLYPH_SHADER := preload("res://shaders/race_glyph.gdshader")
## Spacing along the lap (m) of the buoys (and on a bend), the glow coral, the floor stripe's dots.
const BUOY_STEP := 24.0
const BUOY_STEP_BEND := 12.0
const CORAL_STEP := 9.0
const STRIPE_STEP := 5.0
## How far a glyph sits before the bend's start (m): two of them.
const GLYPH_BEFORE: Array[float] = [34.0, 17.0]
const GLYPH_SIZE := Vector2(7.0, 4.5)
## Lights in a roof: a glowing lamp each LAMP_STEP, a real light each LIGHT_STEP (m).
const LAMP_STEP := 8.0
const LIGHT_STEP := 16.0
const CORAL_COLORS: Array[Color] = [Color(0.1, 0.8, 0.95), Color(0.95, 0.2, 0.75), Color(0.45, 0.95, 0.2), Color(1.0, 0.5, 0.12)]

var track: RaceTrack
var _dice := RandomNumberGenerator.new()


## Dresses `race_track` (needs Terrain.active to be the track's rock).
func build(race_track: RaceTrack) -> void:
	track = race_track
	_dice.seed = 4711
	_buoys()
	_coral()
	_glyphs()
	_stripe()
	_lamps()


# --- Buoys on the racing line -----------------------------------------------------------------------------

func _buoys() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var d := 0.0
	while d < track.lap_length:
		var fix := track.sample(d)
		var bend := fix.tag == "bend" or absf(track.line_offset(d)) > 2.5
		var at := track.racing_line(d)
		transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.8 if bend else 0.6)), at))
		colors.append(Color(1.2, 0.6, 0.15) if not track.roofed(d) else Color(0.5, 0.9, 1.1))
		d += BUOY_STEP_BEND if bend else BUOY_STEP
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	mesh.radial_segments = 10
	mesh.rings = 5
	_multimesh("Buoys", mesh, transforms, colors)


# --- Glow coral on the walls ------------------------------------------------------------------------------

func _coral() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var d := 3.0
	while d < track.lap_length:
		var fix := track.sample(d)
		for side: float in [-1.0, 1.0]:
			var from := fix.pos + fix.up * _dice.randf_range(-fix.height * 0.35, 1.5)
			var hit := _wall_hit(from, fix.right * side, fix.width * 0.5 + 6.0)
			if not hit.is_finite():
				continue
			var normal := Terrain.normal(hit)
			var color := CORAL_COLORS[_dice.randi() % CORAL_COLORS.size()]
			for spike in 3:
				var wobble := Vector3(_dice.randf_range(-1.0, 1.0), _dice.randf_range(-0.3, 1.0), _dice.randf_range(-1.0, 1.0)) * 0.7
				var tilt := (normal + wobble).normalized()
				var size := _dice.randf_range(0.7, 1.5)
				var basis := _upright(tilt) * Basis.from_scale(Vector3(size, size * _dice.randf_range(0.8, 1.6), size))
				transforms.append(Transform3D(basis, hit + normal * 0.05 + _dice.randf_range(0.0, 0.5) * fix.forward))
				colors.append(color)
		d += CORAL_STEP * _dice.randf_range(0.7, 1.3)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 1.3
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_bottom = false
	_multimesh("GlowCoral", cone, transforms, colors)


# --- Arrow glyphs before each bend ------------------------------------------------------------------------

func _glyphs() -> void:
	for cp: Dictionary in track.checkpoints:
		if cp["tag"] != "bend":
			continue
		var mid := float(cp["d"])
		var before := track.sample(mid - 12.0).forward
		var after := track.sample(mid + 12.0).forward
		var turn: float = before.cross(after).y
		if absf(turn) < 0.05:
			continue
		var sign_turn := -1.0 if turn > 0.0 else 1.0  # + a right-hander (clockwise from above)
		var start := mid - 24.0  # the bend's first metre
		for before_m in GLYPH_BEFORE:
			var fix := track.sample(start - before_m)
			var from := fix.pos + fix.up * 1.5
			var outer := -sign_turn  # the outside of the bend is the side away from the turn
			var hit := _wall_hit(from, fix.right * outer, fix.width * 0.5 + 6.0)
			if not hit.is_finite():
				continue
			var normal := Terrain.normal(hit)
			var along := fix.right * sign_turn
			along = (along - normal * along.dot(normal)).normalized()
			var up := normal.cross(along).normalized()
			var glyph := MeshInstance3D.new()
			glyph.name = "Glyph%d" % get_child_count()
			var quad := QuadMesh.new()
			quad.size = GLYPH_SIZE
			var material := ShaderMaterial.new()
			material.shader = GLYPH_SHADER
			quad.material = material
			glyph.mesh = quad
			glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glyph.transform = Transform3D(Basis(along, up, normal), hit + normal * 0.12)
			add_child(glyph)


# --- The stripe on the floor under the racing line --------------------------------------------------------

func _stripe() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var d := 0.0
	while d < track.lap_length:
		var at := track.racing_line(d)
		var hit := _wall_hit(at, Vector3.DOWN, 16.0)
		if hit.is_finite():
			var normal := Terrain.normal(hit)
			var forward := track.sample(d).forward
			var along := (forward - normal * forward.dot(normal)).normalized()
			var basis := Basis(along.cross(normal).normalized(), normal, along)
			transforms.append(Transform3D(basis, hit + normal * 0.06))
			colors.append(Color(0.2, 0.8, 0.9))
		d += STRIPE_STEP
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.04, 1.6)
	_multimesh("Stripe", mesh, transforms, colors)


# --- Lights where the track is roofed ---------------------------------------------------------------------

func _lamps() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var d := 0.0
	var last_light := -999.0
	while d < track.lap_length:
		if track.roofed(d):
			var fix := track.sample(d)
			for side: float in [-1.0, 1.0]:
				var at := fix.pos + fix.right * side * fix.width * 0.5 * 0.82 + fix.up * fix.height * 0.18
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), at))
				colors.append(Color(0.5, 0.9, 1.1))
			if d - last_light >= LIGHT_STEP:
				last_light = d
				var light := OmniLight3D.new()
				light.name = "Lamp%d" % get_child_count()
				light.position = fix.pos + fix.up * fix.height * 0.3
				light.omni_range = fix.width * 1.1 + 8.0
				light.light_color = Color(0.5, 0.9, 1.0)
				light.light_energy = 2.2
				light.shadow_enabled = false
				add_child(light)
		d += LAMP_STEP
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh.radial_segments = 8
	mesh.rings = 4
	_multimesh("Lamps", mesh, transforms, colors)


# --- Helpers ------------------------------------------------------------------------------------------------

## The first point along `dir` from `from` (within `reach` m) where the rock begins; (INF, INF, INF) when there is none.
func _wall_hit(from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var t := 0.0
	var prev := 0.0
	while t <= reach:
		if Terrain.sdf(from + dir * t) < 0.3:
			var lo := prev
			var hi := t
			for i in 5:  # bisect the last step
				var m := (lo + hi) * 0.5
				if Terrain.sdf(from + dir * m) < 0.3:
					hi = m
				else:
					lo = m
			return from + dir * hi
		prev = t
		t += 0.5
	return Vector3.INF


## A basis with Y along `up` (the cone's axis).
func _upright(up: Vector3) -> Basis:
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.1:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized())


func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	if transforms.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
