class_name BossItemFx
## The boss items' shared looks (planning_bosses_and_survival.md §2): a
## glowing tether stretched between two points (a hagfish's, a lamprey's
## drain), and the little creatures themselves, each its own node under the
## run (top level, so it isn't dragged round with the fish).


## A glowing tether in `tint`, `width` m thick, under `parent` (stretch() places it).
static func tether(parent: Node, tint: Color, width: float) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = "Tether"
	var tube := CylinderMesh.new()
	tube.top_radius = width * 0.5
	tube.bottom_radius = width * 0.5
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	line.mesh = tube
	var glow := FxKit.glow(tint)
	glow.albedo_color.a = 0.55
	line.material_override = glow
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.top_level = true
	parent.add_child(line)
	return line


## `line` (a tether()) from `from` to `to`.
static func stretch(line: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var long := span.length()
	if long < 0.001:
		line.visible = false
		return
	line.visible = true
	var up := span / long
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	line.global_transform = Transform3D(Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3(1.0, long, 1.0)), (from + to) * 0.5)


## A small eel-like creature (a hagfish, a lamprey: `sucker` gives it a round
## mouth) `length` m long in `tint`, glowing a little, under `parent`.
static func creature(parent: Node, length: float, girth: float, tint: Color, sucker := false) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = "Creature"
	body.mesh = WornKit.fish_body(length, girth, 0.0, sucker)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = tint
	skin.roughness = 0.4
	skin.emission_enabled = true
	skin.emission = tint
	skin.emission_energy_multiplier = 0.5
	body.material_override = skin
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.top_level = true
	parent.add_child(body)
	return body


## `body` at `at`, its nose toward `facing` (a direction), turned `roll` rad round it.
static func place(body: Node3D, at: Vector3, facing: Vector3, roll := 0.0) -> void:
	var ahead := facing.normalized() if facing.length_squared() > 0.0001 else Vector3.FORWARD
	var basis := Basis.looking_at(ahead, Vector3.UP if absf(ahead.y) < 0.95 else Vector3.BACK)
	body.global_transform = Transform3D(basis.rotated(ahead, roll), at)
