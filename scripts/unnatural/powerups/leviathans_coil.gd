class_name LeviathansCoil
extends Powerup
## Leviathan's Coil (planning_unnatural.md §7b, D13), a boss weapon (the Blood
## Leviathan's): a trail of glowing coils follows the fish, like the
## Leviathan's own body (count(): coil_segments, + the count facet,
## coil_spacing m apart along the way it swam). Every tick() s each hurts the
## zombies it touches (size()) for damage(), proc coefficient coil_proc. One
## MultiMesh for them all. Milestones: at the first, the coils slow what they
## touch (SLOW_SHARE of its speed); at the second, the head snaps at the
## nearest zombie within SNAP_REACH every SNAP_EVERY s, for SNAP_DAMAGE hits'
## worth; at the third, the tail end lashes out in a shock ring every TAIL_EVERY
## s (TAIL_REACH m, TAIL_DAMAGE hits' worth); at the fourth, the coil is
## LONG_SCALE times as long.

const SLOW_SHARE := 0.5
const SNAP_EVERY := 1.5
const SNAP_REACH := 5.0
const SNAP_DAMAGE := 5.0
const TAIL_EVERY := 2.0
const TAIL_REACH := 4.5
const TAIL_DAMAGE := 3.0
const LONG_SCALE := 2

## Hits so far, for the probes.
var hits := 0
## Tail lashes so far (the third milestone), for the probes.
var lashes := 0
## Where the fish has been, newest first, coil_spacing m apart.
var trail := PackedVector3Array()
var _coils: MultiMeshInstance3D
var _spine: MeshInstance3D
var _spine_material: StandardMaterial3D
## The trail as last drawn.
var _drawn := PackedVector3Array()
var _tick_left := 0.0
var _snap_left := SNAP_EVERY
var _tail_left := TAIL_EVERY
var _loop := 0


func count() -> int:
	return (settings.coil_segments + facet_count("count")) * (LONG_SCALE if milestone(4) else 1)


func damage() -> float:
	return settings.coil_damage * (1.0 + facet("damage"))


func size() -> float:
	return settings.coil_radius * (1.0 + facet("size"))


func tick() -> float:
	return settings.coil_tick / (1.0 + facet("rate"))


func on_removed() -> void:
	if is_instance_valid(_coils):
		_coils.queue_free()
	_coils = null
	Sfx.stop_loop(_loop)
	_loop = 0
	trail.clear()
	_drawn.clear()


func on_tick(delta: float) -> void:
	var at := fish.global_position
	if _loop == 0:
		_loop = Sfx.start_loop("pw/coil_loop", fish)
	if trail.is_empty():
		trail.append(at)
	elif at.distance_to(trail[0]) >= settings.coil_spacing:
		trail.insert(0, at)
	if trail.size() > count() + 1:
		trail.resize(count() + 1)
	_draw()
	if milestone(2) and trail.size() > 1:
		_snap_left -= delta
		if _snap_left <= 0.0:
			_snap_left = SNAP_EVERY
			var target := run.horde.nearest_in_cone(trail[1], Vector3.FORWARD, SNAP_REACH, -1.0)
			if target >= 0:
				var to := run.horde.enemy_position(target)
				PowerupFx.flash(run, to, 0.9, color(id), 0.2)
				run.hit(target, damage() * SNAP_DAMAGE, fish, id, (to - trail[1]).normalized(), settings.coil_proc, [id])
	if milestone(3) and trail.size() > 2:
		_tail_left -= delta
		if _tail_left <= 0.0:
			_tail_left = TAIL_EVERY
			lashes += 1
			var end := trail[trail.size() - 1]
			PowerupFx.shock(run, end, TAIL_REACH, color(id), Vector3.UP, 0.35)
			for i in run.horde.query_sphere(end, TAIL_REACH):
				var out := run.horde.enemy_position(i) - end
				run.hit(i, damage() * TAIL_DAMAGE, fish, id, out.normalized() if out.length_squared() > 0.0001 else Vector3.UP,
						settings.coil_proc, [id])
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = maxf(_tick_left + tick(), 0.0)
	var slow := milestone(1)
	for k in range(1, trail.size()):
		for i in run.horde.query_sphere(trail[k], size()):
			hits += 1
			var push := run.horde.enemy_position(i) - trail[k]
			if slow:
				run.horde.shove(i, -run.horde.enemy_velocity(i) * SLOW_SHARE)
			run.hit(i, damage(), fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP,
					settings.coil_proc, [id])


## The serpent along the trail (the first spot is the fish itself, so not
## drawn): a plated vertebra at each spot, turned along the way the trail
## runs and smaller toward its tail (one MultiMesh), and a glowing spine
## threading them (FxKit ribbons, fading to the tail). Both fade near the
## camera: the trail runs back toward it. Redrawn only when the trail moves on.
func _draw() -> void:
	if not is_instance_valid(_coils):
		_coils = MultiMeshInstance3D.new()
		_coils.name = "Coils"
		_coils.top_level = true
		_coils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_coils.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _vertebra_mesh()
		multi.instance_count = 0
		_coils.multimesh = multi
		run.add_child(_coils)
		_coils.global_transform = Transform3D.IDENTITY
		_spine = MeshInstance3D.new()
		_spine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_coils.add_child(_spine)
		_spine_material = FxKit.glow(Color(color(id).lerp(Color.WHITE, 0.2), 0.8), FxKit.across(), true)
		_spine_material.vertex_color_use_as_albedo = true
		_drawn = PackedVector3Array()  # a new node: draw it all
	if trail == _drawn:
		return
	_drawn = trail.duplicate()
	var multi := _coils.multimesh
	var shown := maxi(trail.size() - 1, 0)
	if multi.instance_count < shown:
		multi.instance_count = maxi(shown, 8)
	multi.visible_instance_count = shown
	for k in shown:
		var at := trail[k + 1]
		var ahead := trail[k] - at
		var basis := Basis.IDENTITY
		if ahead.length_squared() > 0.0001:
			basis = Basis.looking_at(ahead, Vector3.UP if absf(ahead.normalized().y) < 0.98 else Vector3.BACK)
		var coil_size := size() * lerpf(0.9, 0.5, float(k) / maxf(count(), 1))
		multi.set_instance_transform(k, Transform3D(basis * Basis.from_scale(Vector3.ONE * coil_size), at))
	if trail.size() >= 3:
		_spine.mesh = FxKit.ribbons([trail.slice(1)], [size() * 0.5], true, true)
		_spine.mesh.surface_set_material(0, _spine_material)
	else:
		_spine.mesh = null


## One vertebra, unit size, its front along -z: a plated body in the
## powerup's glow and a darker fin along its back, raked toward the tail.
func _vertebra_mesh() -> ArrayMesh:
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 12
	body.rings = 6
	var fin := PrismMesh.new()
	fin.size = Vector3(1.1, 0.7, 0.12)
	fin.left_to_right = 0.2
	var glow := worn_material(1.4)
	FxKit.fade_near(glow)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color(id).darkened(0.65)
	dark.roughness = 0.4
	dark.emission_enabled = true
	dark.emission = color(id)
	dark.emission_energy_multiplier = 0.25
	FxKit.fade_near(dark)
	var mesh := ArrayMesh.new()
	FxKit.merge_into(mesh, [[body, Transform3D(Basis.from_scale(Vector3(0.8, 0.65, 1.1)), Vector3.ZERO)]], glow)
	FxKit.merge_into(mesh, [[fin, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0.75, 0.15))]], dark)
	return mesh


## A red band round the tail, where the coils start.
func make_worn() -> Node3D:
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(fish.hitbox_width, fish.hitbox_height) * 0.3
	ring.outer_radius = ring.inner_radius + 0.06
	ring.rings = 16
	ring.ring_segments = 5
	var band := worn_mesh(ring, worn_material(1.5), Vector3(0.0, 0.0, fish.hitbox_length * 0.35), Vector3(PI / 2.0, 0.0, 0.0))
	band.name = "CoilBand"
	return band
