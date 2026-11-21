class_name FishAnatomy
extends RefCounted
## The inner layers of a fish for Marco Polo's reveal (planning_marco_polo.md §3):
## its skeleton and its heart and vessels, generated from the body's own shape and
## cached per class and species (of()).
##
## The shape comes from the model's Body mesh: its slices along z (half width,
## half height, middle height), so it fits whatever made the body (a loft, a
## class's own builder). Everything is built in the Body's own space, so it sits
## beside the Body at the Body's transform and bends with it (FishModel.bend_part).
## Bones and vessels carry their order in COLOR (marco_reveal.gdshader): r the
## bone's kind (SPINE grows first, then RIB, then SKULL), g how far along it is
## (bones) or how far from the heart (vessels, 0..1).
## - lofted fish: a tapered spine of vertebrae, ribs every few slices sized to
##   the slice, neural and haemal spines, a skull shell over the nose slices and
##   gill arches; the heart (two lobes) just behind the gills, the ventral aorta
##   to the gills, the dorsal aorta under the spine to the tail, and branches to
##   the pectoral fins, the head and the median fins;
## - the jelly: a glowing nerve ring round the bell's margin (its skeleton), and
##   radial canals from the stomach out to a ring canal; its "heart" is the
##   four-lobed stomach;
## - the ray: a cartilage fan (a spine and radials out to the disc's edge);
## - the boxfish: its armour plates as a lattice over the body;
## - the sea hare: a soft inner shell on its back, no spine.
## The fins' rays aren't here: the reveal draws them on the fins' own meshes.

## Bone kinds (COLOR.r).
const SPINE := 0.0
const RIB := 0.33
const SKULL := 0.66
## How many slices the body's shape is sampled into.
const BINS := 64

static var _cache := {}

var _z := Vector2(-0.5, 0.5)
var _hw := PackedFloat32Array()
var _hh := PackedFloat32Array()
var _mid := PackedFloat32Array()
var _bones := Tubes.new()
var _vessels := Tubes.new()
var _heart := Tubes.new()
var _heart_at := Vector3.ZERO


## The model's anatomy, built the first time its class and species ask:
## {profile: ImageTexture, z: Vector2 (nose, tail), bones: ArrayMesh,
## vessels: ArrayMesh, heart: ArrayMesh, heart_at: Vector3, depth: float (the
## body's biggest half height), length: float}. Empty if it has no Body.
static func of(model: FishModel) -> Dictionary:
	var key := "%d:%d" % [model.fish_class, model.species]
	if _cache.has(key):
		return _cache[key]
	var body := body_of(model)
	if body == null or body.mesh == null:
		return {}
	var maker := FishAnatomy.new()
	maker._sample(body.mesh)
	var to_body := model_transform(model, body).affine_inverse()
	match model.fish_class:
		FishCharacter.FishClass.DRIFTER:
			maker._jelly()
		FishCharacter.FishClass.GLIDER:
			maker._ray()
		FishCharacter.FishClass.ALCHEMIST:
			maker._sea_hare(model, to_body)
		FishCharacter.FishClass.BULWARK:
			maker._fish(model, to_body, true)
		_:
			maker._fish(model, to_body, false)
	var anatomy := {
		"profile": maker._profile_texture(),
		"z": maker._z,
		"bones": maker._bones.commit(),
		"vessels": maker._vessels.commit(true),
		"heart": maker._heart.commit(),
		"heart_at": maker._heart_at,
		"depth": maker._max(maker._hh),
		"length": maker._z.y - maker._z.x,
	}
	_cache[key] = anatomy
	return anatomy


## The model's Body (every class names its main body mesh that).
static func body_of(model: FishModel) -> MeshInstance3D:
	return model.find_child("Body", true, false) as MeshInstance3D


## `node`'s transform in `model`'s space (it needn't be in the tree yet).
static func model_transform(model: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var at: Node = node
	while at and at != model:
		if at is Node3D:
			xform = (at as Node3D).transform * xform
		at = at.get_parent()
	return xform


# --- The body's shape ---------------------------------------------------------

func _sample(mesh: Mesh) -> void:
	var points := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		points.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var lo := INF
	var hi := -INF
	for p in points:
		lo = minf(lo, p.z)
		hi = maxf(hi, p.z)
	_z = Vector2(lo, maxf(hi, lo + 0.01))
	var top := PackedFloat32Array()
	var bottom := PackedFloat32Array()
	_hw.resize(BINS)
	top.resize(BINS)
	bottom.resize(BINS)
	for i in BINS:
		_hw[i] = -1.0
		top[i] = -INF
		bottom[i] = INF
	for p in points:
		var i := clampi(int((p.z - _z.x) / (_z.y - _z.x) * BINS), 0, BINS - 1)
		_hw[i] = maxf(_hw[i], absf(p.x))
		top[i] = maxf(top[i], p.y)
		bottom[i] = minf(bottom[i], p.y)
	_hh.resize(BINS)
	_mid.resize(BINS)
	for i in BINS:
		if _hw[i] >= 0.0:
			_hh[i] = (top[i] - bottom[i]) * 0.5
			_mid[i] = (top[i] + bottom[i]) * 0.5
		else:
			_hh[i] = -1.0
	# Empty bins take their neighbours' (a coarse mesh along z).
	for i in BINS:
		if _hw[i] >= 0.0:
			continue
		var before := i - 1
		while before >= 0 and _hw[before] < 0.0:
			before -= 1
		var after := i + 1
		while after < BINS and _hw[after] < 0.0:
			after += 1
		var from := before if before >= 0 else after
		var to := after if after < BINS else before
		if from < 0 or from >= BINS:
			_hw[i] = 0.0
			_hh[i] = 0.0
			_mid[i] = 0.0
			continue
		var t := 0.0 if to == from else float(i - from) / float(to - from)
		_hw[i] = lerpf(_hw[from], _hw[to], t)
		_hh[i] = lerpf(_hh[from], _hh[to], t)
		_mid[i] = lerpf(_mid[from], _mid[to], t)


## The slice `along` the body (nose 0 to tail 1): (half width, half height, middle height).
func slice(along: float) -> Vector3:
	var at := clampf(along, 0.0, 1.0) * (BINS - 1)
	var i := mini(int(at), BINS - 2)
	var t := at - i
	return Vector3(lerpf(_hw[i], _hw[i + 1], t), lerpf(_hh[i], _hh[i + 1], t), lerpf(_mid[i], _mid[i + 1], t))


func z(along: float) -> float:
	return lerpf(_z.x, _z.y, along)


## A point `scale` of the way out to the skin `along` the body, `angle` round
## from the top (+ toward +X).
func skin_point(along: float, angle: float, scale: float) -> Vector3:
	var s := slice(along)
	return Vector3(sin(angle) * s.x * scale, s.z + cos(angle) * s.y * scale, z(along))


func _max(values: PackedFloat32Array) -> float:
	var most := 0.0
	for v in values:
		most = maxf(most, v)
	return most


func _profile_texture() -> ImageTexture:
	var image := Image.create_empty(BINS, 1, false, Image.FORMAT_RGBAF)
	for i in BINS:
		image.set_pixel(i, 0, Color(_hw[i], _hh[i], _mid[i], 1.0))
	return ImageTexture.create_from_image(image)


# --- Lofted fish --------------------------------------------------------------

func _fish(model: FishModel, to_body: Transform3D, armoured: bool) -> void:
	var depth := _max(_hh)
	var width := _max(_hw)
	var length := _z.y - _z.x
	var bone := clampf(minf(depth, width) * 0.075, 0.003, 0.08)
	# The spine: vertebrae from behind the skull to the tail, a little above the middle.
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var grown := PackedFloat32Array()
	var rings := 140
	var vertebrae := 26.0
	for i in rings + 1:
		var along := lerpf(0.1, 0.985, float(i) / rings)
		var s := slice(along)
		spine.append(Vector3(0.0, s.z + s.y * 0.12, z(along)))
		var knob := pow(absf(sin(along * vertebrae * PI)), 6.0)
		radii.append(bone * lerpf(1.0, 0.45, along) * (0.8 + 0.4 * knob))
		grown.append(float(i) / rings)
	_bones.tube(spine, radii, SPINE, grown, 6)
	if armoured:
		_lattice(bone * 0.45)
	else:
		_ribs(bone)
	_skull(bone)
	# The heart, just behind the gills and low in the body.
	var heart_along := 0.24
	var hs := slice(heart_along)
	_heart_at = Vector3(0.0, hs.z - hs.y * 0.45, z(heart_along))
	_two_lobed_heart(clampf(hs.y * 0.22, 0.008, 0.25))
	# The vessels, from the heart.
	var vessel := bone * 0.5
	var gill := slice(0.18)
	var gill_base := Vector3(0.0, gill.z - gill.y * 0.4, z(0.18))
	var aorta_root := Vector3(0.0, gill.z + gill.y * 0.02, z(0.2))
	var ventral := [_heart_at, _heart_at.lerp(gill_base, 0.5) + Vector3(0.0, -gill.y * 0.05, 0.0), gill_base]
	var start := _vessels.path(ventral, vessel * 1.3, 0.0)
	# The gill arches, round each side up to the dorsal aorta.
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var along := 0.16 + 0.025 * k
			var arch := [gill_base]
			for n in 5:
				var a := lerpf(PI * 0.85, PI * 0.35, n / 4.0)
				arch.append(skin_point(along, a * side, 0.62))
			arch.append(aorta_root)
			_vessels.path(arch, vessel * 0.6, start)
	# The dorsal aorta under the spine, to the tail.
	var dorsal := [aorta_root]
	for n in 13:
		var along := lerpf(0.24, 0.98, n / 12.0)
		var s := slice(along)
		dorsal.append(Vector3(0.0, s.z, z(along)))
	var root_d := start + aorta_root.distance_to(gill_base) + gill.y
	_vessels.path(dorsal, vessel, root_d)
	# Forward to the head.
	var head := [aorta_root, skin_point(0.12, 0.0, 0.2), skin_point(0.04, 0.0, 0.1)]
	_vessels.path(head, vessel * 0.6, root_d)
	# Out to the pectoral fins.
	for pivot: Node3D in [model.fin_left, model.fin_right]:
		if pivot == null:
			continue
		var at := to_body * FishAnatomy.model_transform(model, pivot).origin
		var from := Vector3(0.0, slice(0.27).z, z(0.27))
		_vessels.path([aorta_root, from, from.lerp(at, 0.5), at], vessel * 0.55, root_d)
	# Up to the dorsal fin and down to the anal fin.
	for along: float in [0.42, 0.6]:
		var s := slice(along)
		var base := Vector3(0.0, s.z, z(along))
		var d := root_d + absf(base.z - aorta_root.z)
		_vessels.path([base, Vector3(0.0, s.z + s.y * 0.95, base.z + length * 0.03)], vessel * 0.45, d)
		if along > 0.5:
			_vessels.path([base, Vector3(0.0, s.z - s.y * 0.95, base.z + length * 0.03)], vessel * 0.45, d)


## Ribs from the spine down round the body cavity, every few slices; neural
## spines up from each vertebra and haemal spines down behind the ribs.
func _ribs(bone: float) -> void:
	var length := _z.y - _z.x
	var count := 11
	for i in count:
		var along := lerpf(0.24, 0.6, float(i) / (count - 1))
		var s := slice(along)
		var root := Vector3(0.0, s.z + s.y * 0.12, z(along))
		for side: float in [-1.0, 1.0]:
			var points := PackedVector3Array([root])
			var radii := PackedFloat32Array([bone * 0.42])
			var grown := PackedFloat32Array([0.0])
			for n in 8:
				var t := (n + 1) / 8.0
				var a := lerpf(PI * 0.42, PI * 0.9, t)
				var p := skin_point(along, a * side, 0.84)
				p.z += t * length * 0.035
				points.append(p)
				radii.append(bone * lerpf(0.4, 0.15, t))
				grown.append(t)
			_bones.tube(points, radii, RIB, grown, 4)
	for i in 22:
		var along := lerpf(0.12, 0.93, float(i) / 21.0)
		var s := slice(along)
		var root := Vector3(0.0, s.z + s.y * 0.12, z(along))
		var up := Vector3(0.0, s.z + s.y * 0.82, root.z + length * 0.025)
		_bones.tube(PackedVector3Array([root, up]), PackedFloat32Array([bone * 0.32, bone * 0.1]), RIB, PackedFloat32Array([0.0, 1.0]), 4)
		if along > 0.62:
			var down := Vector3(0.0, s.z - s.y * 0.8, root.z + length * 0.025)
			_bones.tube(PackedVector3Array([root, down]), PackedFloat32Array([bone * 0.3, bone * 0.1]), RIB, PackedFloat32Array([0.0, 1.0]), 4)


## The boxfish's armour: a diamond lattice of plates' edges over the carapace.
func _lattice(bar: float) -> void:
	var rows := 9
	var around := 14
	for i in rows:
		var a0 := lerpf(0.1, 0.84, float(i) / rows)
		var a1 := lerpf(0.1, 0.84, float(i + 1) / rows)
		for j in around:
			var angle := TAU * j / around
			var step := TAU / around * 0.5
			var p := skin_point(a0, angle, 0.95)
			for dir: float in [-1.0, 1.0]:
				var q := skin_point(a1, angle + step * dir, 0.95)
				var g := float(i) / rows
				_bones.tube(PackedVector3Array([p, q]), PackedFloat32Array([bar, bar]), RIB, PackedFloat32Array([g, g + 1.0 / rows]), 4)


## The skull: a shell over the nose slices, and the jaw's line.
func _skull(bone: float) -> void:
	_bones.shell(self, 0.02, 0.15, 0.78, SKULL, 10, 18)
	for side: float in [-1.0, 1.0]:
		# The gill cover's rim, behind the skull.
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		var grown := PackedFloat32Array()
		for n in 7:
			var t := n / 6.0
			var p := skin_point(0.2 - 0.02 * sin(t * PI), lerpf(PI * 0.25, PI * 0.85, t) * side, 0.93)
			points.append(p)
			radii.append(bone * 0.35)
			grown.append(t)
		_bones.tube(points, radii, SKULL, grown, 4)


func _two_lobed_heart(radius: float) -> void:
	_heart.blob(Vector3.ZERO, Vector3(1.0, 0.85, 1.1) * radius, 0.0)
	_heart.blob(Vector3(0.0, radius * 0.55, radius * 0.75), Vector3(0.8, 0.7, 0.75) * radius, 0.0)


# --- The hand-made four --------------------------------------------------------

## A jelly: a nerve ring round the margin, radial canals out to a ring canal,
## and the four-lobed stomach for a heart.
func _jelly() -> void:
	var rim_along := 0.9
	var rim := slice(rim_along)
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	var grown := PackedFloat32Array()
	var thick := clampf(rim.x * 0.035, 0.004, 0.05)
	var sides := 48
	for n in sides + 1:
		var a := TAU * n / sides
		ring.append(Vector3(sin(a) * rim.x * 0.92, rim.z + cos(a) * rim.y * 0.92, z(rim_along)))
		radii.append(thick)
		grown.append(absf(float(n) / sides - 0.5) * 2.0)
	_bones.tube(ring, radii, SPINE, grown, 5)
	# Rhopalia: little knobs round the ring.
	for n in 8:
		var a := TAU * (n + 0.5) / 8.0
		var p := Vector3(sin(a) * rim.x * 0.92, rim.z + cos(a) * rim.y * 0.92, z(rim_along))
		_bones.blob(p, Vector3.ONE * thick * 2.2, RIB)
	# The stomach and the canals.
	var centre := slice(0.3)
	_heart_at = Vector3(0.0, centre.z, z(0.3))
	var lobe := clampf(rim.x * 0.12, 0.01, 0.2)
	for n in 4:
		var a := TAU * n / 4.0 + PI * 0.25
		_heart.blob(Vector3(sin(a), cos(a), 0.0) * lobe * 0.9, Vector3(1.0, 1.0, 0.6) * lobe, 0.0)
	var canal := thick * 0.7
	for n in 8:
		var a := TAU * n / 8.0
		var path := [_heart_at]
		for k in 6:
			var along := lerpf(0.25, rim_along - 0.02, (k + 1) / 6.0)
			path.append(skin_point(along, a, 0.8))
		_vessels.path(path, canal, 0.0)
	var ring_canal := []
	for n in sides + 1:
		var a := TAU * n / sides
		ring_canal.append(skin_point(rim_along - 0.02, a, 0.82))
	var reach := _heart_at.distance_to(skin_point(rim_along - 0.02, 0.0, 0.8)) * 1.3
	_vessels.path(ring_canal, canal * 0.8, reach)


## A ray: a cartilage fan, a little skull, and vessels out along the radials.
func _ray() -> void:
	var depth := _max(_hh)
	var bone := clampf(depth * 0.12, 0.003, 0.05)
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var grown := PackedFloat32Array()
	for i in 101:
		var along := lerpf(0.08, 0.98, i / 100.0)
		var s := slice(along)
		spine.append(Vector3(0.0, s.z, z(along)))
		radii.append(bone * lerpf(1.0, 0.4, along) * (0.85 + 0.3 * pow(absf(sin(along * 30.0 * PI)), 6.0)))
		grown.append(i / 100.0)
	_bones.tube(spine, radii, SPINE, grown, 6)
	var count := 20
	_heart_at = Vector3(0.0, slice(0.32).z - slice(0.32).y * 0.2, z(0.32))
	_two_lobed_heart(clampf(depth * 0.25, 0.006, 0.1))
	var aorta := []
	for n in 11:
		var along := lerpf(0.32, 0.95, n / 10.0)
		aorta.append(Vector3(0.0, slice(along).z - bone * 1.2, z(along)))
	_vessels.path(aorta, bone * 0.5, 0.0)
	for i in count:
		var along := lerpf(0.1, 0.82, float(i) / (count - 1))
		var s := slice(along)
		for side: float in [-1.0, 1.0]:
			var points := PackedVector3Array()
			var rr := PackedFloat32Array()
			var gg := PackedFloat32Array()
			for n in 9:
				var t := n / 8.0
				points.append(Vector3(side * s.x * 0.86 * t, s.z, z(along) + t * t * (_z.y - _z.x) * 0.05))
				rr.append(bone * lerpf(0.45, 0.12, t))
				gg.append(t)
			_bones.tube(points, rr, RIB, gg, 4)
			if i % 3 == 1:
				var vein := []
				for n in 6:
					var t := n / 5.0
					vein.append(Vector3(side * s.x * 0.85 * t, s.z + bone * 1.3, z(along) + t * t * (_z.y - _z.x) * 0.05 + bone * 2.0))
				_vessels.path(vein, bone * 0.32, _heart_at.distance_to(vein[0]))
	# The neurocranium and the pectoral girdle's arc.
	_bones.shell(self, 0.0, 0.14, 0.4, SKULL, 8, 14)
	var girdle := PackedVector3Array()
	var gr := PackedFloat32Array()
	var gg2 := PackedFloat32Array()
	var g := slice(0.22)
	for n in 13:
		var t := n / 12.0
		girdle.append(Vector3(lerpf(-1.0, 1.0, t) * g.x * 0.45, g.z - g.y * 0.2, z(0.22) + absf(t - 0.5) * (_z.y - _z.x) * 0.06))
		gr.append(bone * 0.5)
		gg2.append(absf(t - 0.5) * 2.0)
	_bones.tube(girdle, gr, SKULL, gg2, 4)


## A sea hare: a soft inner shell on its back, and its heart under it.
func _sea_hare(model: FishModel, to_body: Transform3D) -> void:
	var middle := 0.42
	var s := slice(middle)
	var length := _z.y - _z.x
	var centre := Vector3(0.0, s.z + s.y * 0.5, z(middle))
	_bones.cup(centre, Vector2(s.x * 0.55, length * 0.14), s.y * 0.22, SPINE, 7, 20)
	_heart_at = Vector3(0.0, s.z + s.y * 0.15, z(middle) + length * 0.04)
	_two_lobed_heart(clampf(s.y * 0.2, 0.008, 0.15))
	var vessel := clampf(s.y * 0.05, 0.003, 0.03)
	var forward := [_heart_at]
	for n in 7:
		var along := lerpf(middle - 0.05, 0.04, n / 6.0)
		forward.append(Vector3(0.0, slice(along).z + slice(along).y * 0.1, z(along)))
	_vessels.path(forward, vessel, 0.0)
	var back := [_heart_at]
	for n in 7:
		var along := lerpf(middle + 0.08, 0.95, n / 6.0)
		back.append(Vector3(0.0, slice(along).z, z(along)))
	_vessels.path(back, vessel, 0.0)
	for pivot: Node3D in [model.fin_left, model.fin_right]:
		if pivot == null:
			continue
		var at := to_body * FishAnatomy.model_transform(model, pivot).origin
		_vessels.path([_heart_at, _heart_at.lerp(at, 0.5) + Vector3(0.0, s.y * 0.15, 0.0), at], vessel * 0.7, 0.0)


## Mesh arrays being built: tubes along polylines, blobs and shells, each
## vertex coloured (kind, along, 0).
class Tubes:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	## Vessels' raw distances from the heart (m), normalised on commit.
	var _far := 0.0

	## A tube through `points`, `radii` thick, its COLOR.g from `grown`.
	func tube(points: PackedVector3Array, radii: PackedFloat32Array, kind: float, grown: PackedFloat32Array, sides := 6) -> void:
		var count := points.size()
		if count < 2:
			return
		var first := verts.size()
		var up := Vector3.UP
		for i in count:
			var ahead := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
			if absf(ahead.dot(up)) > 0.95:
				up = Vector3.RIGHT
			var right := ahead.cross(up).normalized()
			var over := right.cross(ahead).normalized()
			for k in sides:
				var a := TAU * k / sides
				var out := right * cos(a) + over * sin(a)
				verts.append(points[i] + out * radii[i])
				normals.append(out)
				colors.append(Color(kind, grown[i], 0.0))
		for i in count - 1:
			for k in sides:
				var a := first + i * sides + k
				var b := first + i * sides + (k + 1) % sides
				indices.append_array([a, b, a + sides, b, b + sides, a + sides])

	## A vessel along `path` (Vector3s), `radius` thick, `start` m from the
	## heart where it begins. Returns the distance at its end.
	func path(points: Array, radius: float, start: float) -> float:
		var line := PackedVector3Array()
		var radii := PackedFloat32Array()
		var grown := PackedFloat32Array()
		var d := start
		for i in points.size():
			var p: Vector3 = points[i]
			if i > 0:
				d += p.distance_to(line[i - 1])
			line.append(p)
			radii.append(radius * lerpf(1.0, 0.55, float(i) / maxf(points.size() - 1, 1)))
			grown.append(d)
			_far = maxf(_far, d)
		tube(line, radii, 0.0, grown, 5)
		return d

	## An ellipsoid at `at`, `size` its half extents.
	func blob(at: Vector3, size: Vector3, kind: float) -> void:
		var first := verts.size()
		var rings := 8
		var around := 12
		for i in rings + 1:
			var v := PI * i / rings
			for k in around:
				var u := TAU * k / around
				var n := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
				verts.append(at + n * size)
				normals.append((n / size).normalized())
				colors.append(Color(kind, 0.0, 0.0))
		for i in rings:
			for k in around:
				var a := first + i * around + k
				var b := first + i * around + (k + 1) % around
				indices.append_array([a, b, a + around, b, b + around, a + around])

	## A shell over the body from `from` to `to` along it, `scale` of the way
	## out to the skin; COLOR.g runs along it.
	func shell(body: FishAnatomy, from: float, to: float, scale: float, kind: float, rows: int, around: int) -> void:
		var first := verts.size()
		for i in rows + 1:
			var t := float(i) / rows
			var along := lerpf(from, to, t)
			var s := body.slice(along)
			for k in around:
				var a := TAU * k / around
				var out := Vector3(sin(a), cos(a), 0.0)
				verts.append(Vector3(out.x * s.x * scale, s.z + out.y * s.y * scale, body.z(along)))
				normals.append(Vector3(out.x / maxf(s.x, 1e-4), out.y / maxf(s.y, 1e-4), 0.0).normalized())
				colors.append(Color(kind, t, 0.0))
		for i in rows:
			for k in around:
				var a := first + i * around + k
				var b := first + i * around + (k + 1) % around
				indices.append_array([a, b, a + around, b, b + around, a + around])

	## A cupped oval sheet centred on `at`, `semi` (across, along) wide, its edge
	## `droop` m down; COLOR.g runs from its middle to its edge.
	func cup(at: Vector3, semi: Vector2, droop: float, kind: float, rings: int, around: int) -> void:
		var first := verts.size()
		for i in rings + 1:
			var r := float(i) / rings
			for k in around:
				var a := TAU * k / around
				var x := cos(a) * semi.x * r
				var zz := sin(a) * semi.y * r
				verts.append(at + Vector3(x, -droop * r * r, zz))
				var slope := 2.0 * droop * r
				normals.append(Vector3(cos(a) * slope / maxf(semi.x, 1e-4), 1.0, sin(a) * slope / maxf(semi.y, 1e-4)).normalized())
				colors.append(Color(kind, r, 0.0))
		for i in rings:
			for k in around:
				var a := first + i * around + k
				var b := first + i * around + (k + 1) % around
				indices.append_array([a, b, a + around, b, b + around, a + around])

	## The mesh (null if empty). `normalise`: COLOR.g as a share of the furthest
	## distance (vessels).
	func commit(normalise := false) -> ArrayMesh:
		if verts.is_empty():
			return null
		if normalise and _far > 0.0:
			for i in colors.size():
				var c := colors[i]
				colors[i] = Color(c.r, c.g / _far, c.b)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
