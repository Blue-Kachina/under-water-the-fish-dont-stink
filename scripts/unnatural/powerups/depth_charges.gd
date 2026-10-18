class_name DepthCharges
extends Powerup
## Depth Charges (planning_unnatural.md §7b, D14), a weapon: a mine rack under
## the fish. A mine drops behind it every interval() s; it arms after arm_time()
## s, then blows when a zombie comes within charge_trigger m (or when life() s
## are up): damage() to every zombie within blast() m (proc coefficient
## charge_proc). At most max_mines() out (the oldest goes). Milestones: at the
## first, a triggered mine pulls the zombies round it in for PULL_TIME s
## before it blows; at the second, every CLUSTER_EVERY-th blast throws
## CLUSTER_COUNT smaller ones round it; at the third, an armed mine drifts
## toward the nearest zombie within DRIFT_REACH at DRIFT_SPEED m/s; at the
## fourth, every blast goes off again AFTERSHOCK_AFTER s later, for
## AFTERSHOCK_SHARE of the damage.

## The first milestone's pull: PULL_TIME s, zombies within PULL_REACH blasts
## drawn in at PULL_ACCEL m/s².
const PULL_TIME := 0.35
const PULL_REACH := 2.0
const PULL_ACCEL := 120.0
## The second's cluster: every CLUSTER_EVERY-th blast throws CLUSTER_COUNT
## more, CLUSTER_SIZE of the size and damage, a blast out.
const CLUSTER_EVERY := 4
const CLUSTER_COUNT := 4
const CLUSTER_SIZE := 0.55
const DRIFT_REACH := 10.0
const DRIFT_SPEED := 3.0
const AFTERSHOCK_AFTER := 0.4
const AFTERSHOCK_SHARE := 0.6

## Mines dropped and blown so far, for the probes.
var dropped := 0
var blown := 0
var mines: Array[Mine] = []
var _next := 0.0
## The fourth milestone's aftershocks to come: [s left, where, reach, damage].
var _aftershocks: Array = []
## Aftershocks gone off so far, for the probes.
var aftershocks := 0


func interval() -> float:
	return settings.charge_interval / (1.0 + facet("rate"))


func damage() -> float:
	return settings.charge_damage * (1.0 + facet("damage"))


func blast() -> float:
	return settings.charge_blast * (1.0 + facet("blast"))


func arm_time() -> float:
	return settings.charge_arm / (1.0 + facet("arm"))


func life() -> float:
	return settings.charge_life * duration_scale()


func max_mines() -> int:
	return settings.charge_max + facet_count("mines")


func on_tick(delta: float) -> void:
	for k in range(_aftershocks.size() - 1, -1, -1):
		var shock: Array = _aftershocks[k]
		shock[0] -= delta
		if shock[0] <= 0.0:
			_aftershocks.remove_at(k)
			aftershocks += 1
			_blast(shock[1], shock[2], shock[3], true)
	_next -= delta
	if _next <= 0.0:
		_next = interval()
		drop()
	for k in range(mines.size() - 1, -1, -1):
		var mine := mines[k]
		if not is_instance_valid(mine):
			mines.remove_at(k)
			continue
		mine.age += delta
		mine.arm_time = arm_time()
		if mine.fuse >= 0.0:
			mine.fuse -= delta
			_pull(mine.global_position, delta)
			if mine.fuse <= 0.0:
				mines.remove_at(k)
				explode(mine.global_position)
				mine.queue_free()
			continue
		var armed := mine.age >= arm_time()
		if armed and milestone(3):
			_drift(mine, delta)
		if mine.age >= life() or (armed and not run.horde.query_sphere(mine.global_position, settings.charge_trigger).is_empty()):
			if milestone(1) and mine.age < life():
				mine.fuse = PULL_TIME  # the first milestone: it draws them in, then blows
				continue
			mines.remove_at(k)
			explode(mine.global_position)
			mine.queue_free()


## The first milestone: zombies round a mine drawn toward it.
## The third milestone: an armed mine drifts toward the nearest zombie close by.
func _drift(mine: Mine, delta: float) -> void:
	var target := run.horde.nearest_in_cone(mine.global_position, Vector3.FORWARD, DRIFT_REACH, -1.0)
	if target < 0:
		return
	var to := run.horde.enemy_position(target) - mine.global_position
	if to.length() > 0.2:
		mine.global_position += to.normalized() * minf(DRIFT_SPEED * delta, to.length())


func _pull(at: Vector3, delta: float) -> void:
	for i in run.horde.query_sphere(at, blast() * PULL_REACH):
		var toward := at - run.horde.enemy_position(i)
		if toward.length_squared() > 0.01:
			run.horde.shove(i, toward.normalized() * PULL_ACCEL * delta)


## A mine behind the fish, now.
func drop() -> void:
	while mines.size() >= max_mines():
		var oldest: Variant = mines.pop_front()  # untyped: a spent one is a freed instance
		if is_instance_valid(oldest):
			oldest.queue_free()
	var mine := Mine.new()
	mine.tint = color(id)
	mine.arm_time = arm_time()
	run.add_child(mine)
	mine.global_position = fish.global_position + fish.global_basis.z * (fish.hitbox_length * 0.6)
	mines.append(mine)
	dropped += 1


func explode(at: Vector3) -> void:
	blown += 1
	_blast(at, blast(), damage())
	if milestone(2) and blown % CLUSTER_EVERY == 0:
		for n in CLUSTER_COUNT:
			var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / CLUSTER_COUNT + run.rng.randf() * 0.5)
			_blast(at + out * blast(), blast() * CLUSTER_SIZE, damage() * CLUSTER_SIZE)


func _blast(at: Vector3, reach: float, amount: float, aftershock := false) -> void:
	if milestone(4) and not aftershock:
		_aftershocks.append([AFTERSHOCK_AFTER, at, reach, amount * AFTERSHOCK_SHARE])
	Explosion.spawn(run.ocean, at, color(id), reach, 0.0, 0.3)
	for i in run.horde.query_sphere(at, reach):
		var push := run.horde.enemy_position(i) - at
		run.hit(i, amount, fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP, settings.charge_proc, [id])


func on_removed() -> void:
	_aftershocks.clear()
	for mine in mines:
		if is_instance_valid(mine):
			mine.queue_free()
	mines.clear()


## A little rack of mines under the belly.
func make_worn() -> Node3D:
	var rack := Node3D.new()
	rack.name = "MineRack"
	rack.position = Vector3(0.0, -fish.hitbox_height * 0.5 - 0.06, fish.hitbox_length * 0.15)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.33, 0.3)
	steel.metallic = 0.7
	steel.roughness = 0.45
	var bar := BoxMesh.new()
	bar.size = Vector3(0.06, 0.04, fish.hitbox_length * 0.45)
	rack.add_child(worn_mesh(bar, steel, Vector3(0.0, 0.03, 0.0)))
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 8
	ball.rings = 4
	for n in 3:
		rack.add_child(worn_mesh(ball, steel, Vector3(0.0, -0.05, (n - 1) * fish.hitbox_length * 0.14)))
	return rack


## One mine, bobbing where it was dropped: a naval mine (a steel ball with a
## band round its middle and detonator horns all over, one shared mesh), and
## a light on top blinking with a soft glow round it, quicker once it's
## armed. It dithers away near the camera (they're dropped right behind the fish).
class Mine extends Node3D:
	const ARMED_BLINK := 5.0
	const BLINK := 2.0
	var age := 0.0
	var tint := Color.WHITE
	## When it arms (s), and its fuse once triggered (the pull; -1: not lit).
	var arm_time := 0.5
	var fuse := -1.0
	var _light := MeshInstance3D.new()
	var _halo := MeshInstance3D.new()

	static var _body: ArrayMesh
	static var _lamp: SphereMesh
	static var _halo_mesh: QuadMesh
	static var _on: StandardMaterial3D
	static var _off: StandardMaterial3D
	static var _glow: StandardMaterial3D

	func _ready() -> void:
		if _body == null:
			_build()
		var body := MeshInstance3D.new()
		body.mesh = _body
		add_child(body)
		_light.mesh = _lamp
		_light.position.y = 0.33
		_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_light)
		_halo.mesh = _halo_mesh
		_halo.material_override = _glow
		_halo.position.y = 0.33
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)

	func _process(delta: float) -> void:
		position.y += sin(age * 2.5) * 0.15 * delta
		var armed := age >= arm_time
		var blink := fuse >= 0.0 or fmod(age * (ARMED_BLINK if armed else BLINK), 1.0) < 0.5
		_light.material_override = _on if blink else _off
		_halo.visible = blink

	static func _build() -> void:
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.24, 0.27, 0.26)
		steel.metallic = 0.75
		steel.roughness = 0.4
		FxKit.fade_near(steel)
		var ball := SphereMesh.new()
		ball.radius = 0.3
		ball.height = 0.6
		ball.radial_segments = 14
		ball.rings = 7
		var band := TorusMesh.new()
		band.inner_radius = 0.28
		band.outer_radius = 0.33
		band.rings = 18
		band.ring_segments = 4
		var horn := CylinderMesh.new()
		horn.top_radius = 0.035
		horn.bottom_radius = 0.05
		horn.height = 0.14
		horn.radial_segments = 6
		horn.rings = 1
		var cap := SphereMesh.new()
		cap.radius = 0.04
		cap.height = 0.08
		cap.radial_segments = 6
		cap.rings = 3
		var parts := [[ball, Transform3D.IDENTITY], [band, Transform3D.IDENTITY]]
		# Horns round the top half and the middle, like the real thing.
		for out: Vector3 in [Vector3(1, 0.35, 0), Vector3(-1, 0.35, 0), Vector3(0, 0.35, 1), Vector3(0, 0.35, -1),
				Vector3(0.7, -0.5, 0.7), Vector3(-0.7, -0.5, -0.7), Vector3(0.7, 0.75, -0.7), Vector3(-0.7, 0.75, 0.7)]:
			var dir := out.normalized()
			var turn := Basis(Quaternion(Vector3.UP, dir))
			parts.append([horn, Transform3D(turn, dir * 0.33)])
			parts.append([cap, Transform3D(turn, dir * 0.4)])
		_body = ArrayMesh.new()
		FxKit.merge_into(_body, parts, steel)
		_lamp = SphereMesh.new()
		_lamp.radius = 0.06
		_lamp.height = 0.12
		_lamp.radial_segments = 8
		_lamp.rings = 4
		_on = StandardMaterial3D.new()
		_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_on.albedo_color = Color(1.0, 0.25, 0.15)
		FxKit.fade_near(_on)
		_off = _on.duplicate()
		_off.albedo_color = Color(0.25, 0.05, 0.05)
		_glow = FxKit.glow(Color(1.0, 0.3, 0.2, 0.7), FxKit.dot(), true)
		_glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo_mesh = QuadMesh.new()
		_halo_mesh.size = Vector2(0.7, 0.7)
