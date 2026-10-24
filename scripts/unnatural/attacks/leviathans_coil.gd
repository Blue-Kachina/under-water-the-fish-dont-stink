class_name LeviathansCoil
extends FishAttack
## Leviathan's Coil (planning_unnatural.md §7b, D13), a steady boss weapon (FishAttack; the Blood
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


## It reads its own facets, and has no attacks to count (FishAttack).
func own_facets() -> bool:
	return true


func counts_uses() -> bool:
	return false


func count() -> int:
	return (powers.coil_segments + facet_count("count")) * (LONG_SCALE if milestone(4) else 1)


func damage() -> float:
	return powers.coil_damage * (1.0 + facet("damage"))


func size() -> float:
	return powers.coil_radius * (1.0 + facet("size")) * size_scale


func tick() -> float:
	return powers.coil_tick / (1.0 + facet("rate")) / attack_speed


func on_removed() -> void:
	if is_instance_valid(_coils):
		_coils.queue_free()
	_coils = null
	Sfx.stop_loop(_loop)
	_loop = 0
	trail.clear()
	_drawn.clear()


func _work(delta: float) -> void:
	var at := fish.global_position
	if _loop == 0:
		_loop = Sfx.start_loop("pw/coil_loop", fish)
	if trail.is_empty():
		trail.append(at)
	elif at.distance_to(trail[0]) >= powers.coil_spacing:
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
				PowerupFx.flash(run, to, 0.9, tint(), 0.2)
				strike(target, damage() * SNAP_DAMAGE, (to - trail[1]).normalized(), powers.coil_proc)
	if milestone(3) and trail.size() > 2:
		_tail_left -= delta
		if _tail_left <= 0.0:
			_tail_left = TAIL_EVERY
			lashes += 1
			var end := trail[trail.size() - 1]
			PowerupFx.shock(run, end, TAIL_REACH, tint(), Vector3.UP, 0.35)
			strike_area(run.horde.query_sphere(end, TAIL_REACH), damage() * TAIL_DAMAGE, end, powers.coil_proc)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = maxf(_tick_left + tick(), 0.0)
	var slow := milestone(1)
	# Every segment's zombies in one area hit, each pushed off its own segment.
	var squeezed := PackedInt32Array()
	var pushes := PackedVector3Array()
	for k in range(1, trail.size()):
		for i in run.horde.query_sphere(trail[k], size()):
			hits += 1
			var push := run.horde.enemy_position(i) - trail[k]
			if slow:
				run.horde.shove(i, -run.horde.enemy_velocity(i) * SLOW_SHARE)
			squeezed.append(i)
			pushes.append(push.normalized() if push.length_squared() > 0.0001 else Vector3.UP)
	strike_area(squeezed, damage(), Vector3.INF, powers.coil_proc, pushes)


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
		_spine_material = FxKit.glow(Color(tint().lerp(Color.WHITE, 0.2), 0.6), FxKit.across(), true)
		_spine_material.vertex_color_use_as_albedo = true
		FxKit.fade_near(_spine_material, powers.coil_fade_near, powers.coil_fade_far)
		_drawn = PackedVector3Array()  # a new node: draw it all
	if trail == _drawn:
		return
	_drawn = trail.duplicate()
	var multi := _coils.multimesh
	# Not within coil_clear of the fish: the trail runs back toward the camera, so
	# coils there would sit between it and the fish.
	var first := 1
	while first < trail.size() and trail[first].distance_to(fish.global_position) < powers.coil_clear:
		first += 1
	var shown := maxi(trail.size() - first, 0)
	if multi.instance_count < shown:
		multi.instance_count = maxi(shown, 8)
	multi.visible_instance_count = shown
	var drawn_size := minf(size(), powers.coil_draw_max)  # its reach grows; its look stops at coil_draw_max
	for k in shown:
		var at := trail[k + first]
		var ahead := trail[k + first - 1] - at
		var basis := Basis.IDENTITY
		if ahead.length_squared() > 0.0001:
			basis = Basis.looking_at(ahead, Vector3.UP if absf(ahead.normalized().y) < 0.98 else Vector3.BACK)
		var coil_size := drawn_size * lerpf(0.9, 0.5, float(k + first - 1) / maxf(count(), 1))
		multi.set_instance_transform(k, Transform3D(basis * Basis.from_scale(Vector3.ONE * coil_size), at))
	if trail.size() - first >= 2:
		_spine.mesh = FxKit.ribbons([trail.slice(first)], [drawn_size * 0.4], true, true)
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
	var glow := worn_material(0.7)
	FxKit.fade_near(glow, powers.coil_fade_near, powers.coil_fade_far)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = tint().darkened(0.65)
	dark.roughness = 0.4
	dark.emission_enabled = true
	dark.emission = tint()
	dark.emission_energy_multiplier = 0.2
	FxKit.fade_near(dark, powers.coil_fade_near, powers.coil_fade_far)
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
