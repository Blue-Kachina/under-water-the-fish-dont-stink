class_name TorpedoLauncher
extends Powerup
## Torpedo Launcher (planning_unnatural.md §7): any hit has a chance to fire
## heat-seeking torpedoes from the fish (1, and another every
## torpedo_stacks_per_extra stacks), each after its own nearest zombie. One
## explodes on impact (or when its time's up): torpedo_damage to every zombie
## in the blast (proc coefficient torpedo_proc, so it can start lightning but
## never torpedoes again). More stacks: more chance, more torpedoes, a bigger blast.
## They fly as one pooled swarm (TorpedoSwarm), at most torpedo_max at once,
## and only torpedo_fx_rate blasts a second are shown: a big launcher stays smooth.

## Torpedoes fired and blasts so far, and launches folded into others (no room), for the probes.
var fired := 0
var blasts := 0
var folded := 0

var _swarm: TorpedoSwarm
var _loop := 0
## Blast visuals left to show this second (torpedo_fx_rate): past it, a blast
## still hurts, but goes off unseen.
var _fx_left := 0.0
var _fx_time := 0.0


func chance() -> float:
	return soft_chance(settings.torpedo_chance + settings.torpedo_chance_per_stack * extra())


func count() -> int:
	return 1 + int(extra()) / maxi(settings.torpedo_stacks_per_extra, 1)


func blast() -> float:
	return (settings.torpedo_blast + settings.torpedo_blast_per_stack * extra()) * size_scale()


func on_hit(_index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	var power := proc_power(chance() * proc)
	if power > 0.0:
		launch(chain, power)


## Torpedoes flying now.
func in_flight() -> int:
	return _swarm.count() if is_instance_valid(_swarm) else 0


## count() torpedoes from the fish, each at one of its nearest zombies (the
## nearest first), `power` times as strong (Powerup.proc_power()), while fewer
## than torpedo_max are flying. Those there's no room for aren't lost (the perf
## pass): their power goes into the torpedoes launched now, or with none, into
## those already flying, so a big launcher costs no more work, only hits harder.
func launch(chain: Array, power := 1.0) -> void:
	var room := settings.torpedo_max - in_flight()
	var total := count() * maxf(power, 1.0)
	if room <= 0:
		folded += 1
		if is_instance_valid(_swarm):
			_swarm.boost(total)
		return
	if not is_instance_valid(_swarm):
		_swarm = TorpedoSwarm.new()
		_swarm.name = "Torpedoes"
		_swarm.launcher = self
		run.add_child(_swarm)
	var from := fish.global_position
	var wanted := mini(count(), room)
	if wanted < count():
		folded += 1
	var each := total / wanted
	var nearest := _nearest(from, 25.0, wanted)
	var from_chain := chain + [id]
	for n in wanted:
		var spread := Vector3(run.rng.randf_range(-1, 1), run.rng.randf_range(0.2, 1.0), run.rng.randf_range(-1, 1)).normalized()
		var velocity := (-fish.global_basis.z * 0.6 + spread * 0.4).normalized() * settings.torpedo_speed * 0.5
		_swarm.add(from + spread * 0.6, velocity, nearest[n % nearest.size()] if not nearest.is_empty() else -1, from_chain, each)
		fired += 1
	Sfx.play_at("pw/torpedo_launch", from)


## The running sound: one loop at the fish while any are flying, louder with more.
func on_tick(_delta: float) -> void:
	var flying := in_flight()
	if flying > 0 and _loop == 0:
		_loop = Sfx.start_loop("pw/torpedo_loop", fish)
	elif flying == 0 and _loop != 0:
		Sfx.stop_loop(_loop)
		_loop = 0
	if _loop != 0:
		Sfx.set_loop(_loop, clampf(flying / 6.0, 0.3, 1.0))


## Up to `k` live zombies within `reach` of `at`, the nearest first (a
## running pick, no sort: k is a handful).
func _nearest(at: Vector3, reach: float, k: int) -> PackedInt32Array:
	var picked := PackedInt32Array()
	var gaps := PackedFloat32Array()
	for i in run.horde.query_sphere(at, reach):
		var d := run.horde.enemy_position(i).distance_squared_to(at)
		if picked.size() < k or d < gaps[picked.size() - 1]:
			var slot := picked.size() if picked.size() < k else k - 1
			if picked.size() < k:
				picked.append(i)
				gaps.append(d)
			while slot > 0 and gaps[slot - 1] > d:
				picked[slot] = picked[slot - 1]
				gaps[slot] = gaps[slot - 1]
				slot -= 1
			picked[slot] = i
			gaps[slot] = d
	return picked


func on_removed() -> void:
	if is_instance_valid(_swarm):
		_swarm.queue_free()
	_swarm = null
	Sfx.stop_loop(_loop)
	_loop = 0


## A torpedo's blast at `at`, `power` times its damage (a folded torpedo's
## blast is a little wider too).
func explode(at: Vector3, chain: Array, power := 1.0) -> void:
	blasts += 1
	var reach := blast() * minf(1.0 + 0.1 * (maxf(power, 1.0) - 1.0), 1.6)
	Sfx.play_at("fx/explosion", at, clampf(reach / 6.0, 0.0, 1.0))
	var now := Time.get_ticks_msec() / 1000.0
	_fx_left = minf(_fx_left + (now - _fx_time) * settings.torpedo_fx_rate, settings.torpedo_fx_rate * 0.5)
	_fx_time = now
	if _fx_left >= 1.0:
		_fx_left -= 1.0
		Explosion.spawn(run.ocean, at, Powerup.color(id), reach, 0.0, 0.25)
	run.hit_area(run.horde.query_sphere(at, reach), settings.torpedo_damage * maxf(power, 1.0), fish, id, at, 1.0,
			run.powerup_settings.torpedo_proc, chain)


## Twin launch tubes along the flanks, their muzzles glowing.
func make_worn() -> Node3D:
	var rack := Node3D.new()
	rack.name = "Tubes"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.42, 0.45, 0.48)
	steel.metallic = 0.8
	steel.roughness = 0.35
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (fish.hitbox_width * 0.5 + 0.04), fish.hitbox_height * 0.1, -fish.hitbox_length * 0.05)
		rack.add_child(worn_mesh(WornKit.barrel_tube(snappedf(fish.hitbox_length * 0.5, 0.05), 0.07), steel, at, Vector3(-PI / 2.0, 0.0, 0.0)))
		rack.add_child(worn_mesh(WornKit.ring(0.07, 0.025), worn_material(1.8), at + Vector3(0.0, 0.0, -fish.hitbox_length * 0.25),
				Vector3(PI / 2.0, 0.0, 0.0)))
	return rack


## Every torpedo a launcher has flying (round 2's perf pass): one node and one
## MultiMesh for them all, not a node each. Each seeks its target, picking a
## new one near it now and then once its target's gone, and blows up on
## impact or when its time's up.
class TorpedoSwarm extends MultiMeshInstance3D:
	const TURN := 6.0
	## How often (ticks) a torpedo with no target looks for one, and how far.
	const RETARGET_TICKS := 6
	const RETARGET_REACH := 15.0

	static var _mesh: ArrayMesh

	var launcher: TorpedoLauncher
	var _position := PackedVector3Array()
	var _velocity := PackedVector3Array()
	var _target := PackedInt32Array()
	var _age := PackedFloat32Array()
	## Each torpedo's power (its blast's damage multiplier: launches folded into it).
	var _power := PackedFloat32Array()
	var _chain: Array = []
	var _ticks := 0

	func _ready() -> void:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh == null:
			_mesh = _torpedo_mesh()
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _mesh
		multimesh.instance_count = 0
		top_level = true
		global_transform = Transform3D.IDENTITY

	func count() -> int:
		return _position.size()

	func add(at: Vector3, velocity: Vector3, target: int, chain: Array, power := 1.0) -> void:
		_position.append(at)
		_velocity.append(velocity)
		_target.append(target)
		_age.append(0.0)
		_power.append(minf(power, Powerup.BANK_MAX))
		_chain.append(chain)

	## `power` more spread over the torpedoes flying (a launch with no room
	## left), each up to Powerup.BANK_MAX.
	func boost(power: float) -> void:
		var n := _power.size()
		if n == 0:
			return
		var each := power / n
		for i in n:
			_power[i] = minf(_power[i] + each, Powerup.BANK_MAX)

	## The total power flying now (probes).
	func power_total() -> float:
		var total := 0.0
		for p in _power:
			total += p
		return total

	func _physics_process(delta: float) -> void:
		_ticks += 1
		var horde := launcher.run.horde
		var settings := launcher.settings
		var speed := settings.torpedo_speed
		var turn := 1.0 - exp(-TURN * delta)
		var blown: Array[int] = []
		for i in _position.size():
			_age[i] += delta
			var target := _target[i]
			if target >= 0 and not horde.is_alive(target):
				target = -1
			if target < 0 and (_ticks + i) % RETARGET_TICKS == 0:
				target = horde.nearest_in_cone(_position[i], _velocity[i].normalized() if _velocity[i].length_squared() > 0.01 else Vector3.FORWARD,
						RETARGET_REACH, -0.2)
			_target[i] = target
			var velocity := _velocity[i]
			if target >= 0:
				var to := horde.enemy_position(target) - _position[i]
				if to.length() <= horde.enemy_radius(target) + 0.4:
					blown.append(i)
					continue
				velocity = velocity.lerp(to.normalized() * speed, turn)
			velocity = velocity.normalized() * minf(velocity.length() + speed * 2.0 * delta, speed)
			_velocity[i] = velocity
			_position[i] += velocity * delta
			if _age[i] >= settings.torpedo_life:
				blown.append(i)
		# Last first, so the swaps don't move one still to go.
		for b in range(blown.size() - 1, -1, -1):
			var i := blown[b]
			var at := _position[i]
			var chain: Array = _chain[i]
			var power := _power[i]
			_remove(i)
			launcher.explode(at, chain, power)
		_draw()

	func _remove(i: int) -> void:
		var last := _position.size() - 1
		_position[i] = _position[last]
		_velocity[i] = _velocity[last]
		_target[i] = _target[last]
		_age[i] = _age[last]
		_power[i] = _power[last]
		_chain[i] = _chain[last]
		_position.resize(last)
		_velocity.resize(last)
		_target.resize(last)
		_age.resize(last)
		_power.resize(last)
		_chain.resize(last)

	func _draw() -> void:
		var n := _position.size()
		if multimesh.instance_count < n:
			multimesh.instance_count = maxi(n, multimesh.instance_count * 2)
		multimesh.visible_instance_count = n
		for i in n:
			var forward := _velocity[i].normalized() if _velocity[i].length_squared() > 0.01 else Vector3.FORWARD
			var up := Vector3.UP if absf(forward.y) < 0.98 else Vector3.BACK
			# The torpedo's nose is -z: point it the way it's going, spinning slowly on its axis.
			var basis := Basis.looking_at(forward, up) * Basis(Vector3.BACK, _age[i] * 9.0)
			multimesh.set_instance_transform(i, Transform3D(basis, _position[i]))

	## One torpedo, nose along -z, as one mesh for the MultiMesh: a slim
	## gunmetal body with a tapered tail, a nose cap and a propeller ring
	## glowing in the launcher's colour, cross tail fins, and a faint wake
	## streaming behind. A surface per material (3), so the whole swarm is
	## 3 draw calls.
	static func _torpedo_mesh() -> ArrayMesh:
		const R := 0.055  # the body's radius
		const BODY := 0.6
		var along := Basis(Vector3.RIGHT, -PI / 2.0)  # a primitive's y axis onto -z (nose forward)
		var gunmetal := StandardMaterial3D.new()
		gunmetal.albedo_color = Color(0.3, 0.33, 0.37)
		gunmetal.metallic = 0.75
		gunmetal.roughness = 0.35
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Powerup.color("torpedo")
		glow.emission_enabled = true
		glow.emission = Powerup.color("torpedo")
		glow.emission_energy_multiplier = 2.2
		var wake := StandardMaterial3D.new()
		wake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wake.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wake.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wake.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		wake.cull_mode = BaseMaterial3D.CULL_DISABLED
		wake.albedo_color = Color(Powerup.color("torpedo").lerp(Color.WHITE, 0.4), 0.18)
		var fade := Gradient.new()  # along the streak: strong at the tail, gone at its end
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.set_color(1, Color(1, 1, 1, 1))
		var streak := GradientTexture2D.new()
		streak.gradient = fade
		streak.fill_from = Vector2(0.5, 1.0)
		streak.fill_to = Vector2(0.5, 0.0)
		streak.width = 4
		streak.height = 32
		wake.albedo_texture = streak

		var body := CylinderMesh.new()
		body.top_radius = R
		body.bottom_radius = R
		body.height = BODY
		body.radial_segments = 10
		body.rings = 1
		var tail := CylinderMesh.new()
		tail.top_radius = R
		tail.bottom_radius = R * 0.35
		tail.height = 0.14
		tail.radial_segments = 10
		tail.rings = 1
		var fin_flat := BoxMesh.new()
		fin_flat.size = Vector3(R * 4.4, 0.012, 0.1)
		var fin_up := BoxMesh.new()
		fin_up.size = Vector3(0.012, R * 4.4, 0.1)
		var nose := SphereMesh.new()
		nose.radius = R
		nose.height = R * 2.0
		nose.radial_segments = 10
		nose.rings = 5
		var ring := TorusMesh.new()
		ring.inner_radius = R * 0.45
		ring.outer_radius = R * 0.85
		ring.rings = 10
		ring.ring_segments = 5
		var trail := CylinderMesh.new()
		trail.top_radius = R * 0.9
		trail.bottom_radius = 0.0
		trail.height = 0.6
		trail.radial_segments = 6
		trail.rings = 1
		trail.cap_top = false
		trail.cap_bottom = false

		var tail_z := BODY * 0.5 + 0.07
		var mesh := ArrayMesh.new()
		for surface: Array in [
			[gunmetal, [[body, Transform3D(along, Vector3.ZERO)], [tail, Transform3D(along, Vector3(0, 0, tail_z))],
				[fin_flat, Transform3D(Basis(), Vector3(0, 0, tail_z))], [fin_up, Transform3D(Basis(), Vector3(0, 0, tail_z))]]],
			# The nose cap stretched to a point; the ring behind the tail.
			[glow, [[nose, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.8)), Vector3(0, 0, -BODY * 0.5))],
				[ring, Transform3D(along, Vector3(0, 0, tail_z + 0.08))]]],
			[wake, [[trail, Transform3D(along, Vector3(0, 0, tail_z + 0.08 + 0.3))]]],
		]:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part: Array in surface[1]:
				tool.append_from(part[0], 0, part[1])
			tool.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, surface[0])
		return mesh
