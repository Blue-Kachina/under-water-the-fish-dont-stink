class_name JellyfishHalo
extends Powerup
## Jellyfish Halo (planning_unnatural.md §7b, D14), a weapon: jellies orbit
## the fish (count(): jelly_count, + the count facet) orbit_radius() m out,
## spin() turns a second. Every sting_tick() s each stings the zombies it
## touches (jelly_radius) for damage(), proc coefficient jelly_proc. The
## jellies live in the world (one node for them all), not on the fish, so its
## strides don't swing them. Milestones: at the first, each jelly trails a
## ghost that stings too (TRAIL_SHARE of the damage); at the second, the halo
## swings out to PULSE_REACH times as far every PULSE_EVERY s; at the third, a
## second ring as big circles OUTER_REACH times as far out, the other way, for
## OUTER_SHARE of the damage; at the fourth, each sting jumps on to the
## nearest other zombie within JUMP_REACH for JUMP_SHARE of it.

## The ghosts trail their jellies by this much of a turn (radians), a size
## and damage share behind.
const TRAIL_LAG := 0.45
const TRAIL_SHARE := 0.5
## The second milestone's pulse: every PULSE_EVERY s the halo swings out to
## PULSE_REACH times its radius and back, over PULSE_TIME s.
const PULSE_EVERY := 4.0
const PULSE_TIME := 1.0
const PULSE_REACH := 2.2
const OUTER_REACH := 1.7
const OUTER_SHARE := 0.75
const JUMP_REACH := 4.0
const JUMP_SHARE := 0.5

## Stings so far, for the probes.
var stings := 0
## Stings that jumped on (the fourth milestone), for the probes.
var jumps := 0
var _halo: Node3D
var _loop := 0
var _turn := 0.0
var _sting_left := 0.0
var _pulse_age := 0.0
## The jellies' count, trail and outer ring when last built.
var _built := Vector3i(-1, -1, -1)


func count() -> int:
	return settings.jelly_count + facet_count("count")


func orbit_radius() -> float:
	var reach := settings.halo_radius * (1.0 + facet("radius")) * area_scale()
	if milestone(2) and _pulse_age < PULSE_TIME:
		reach *= 1.0 + (PULSE_REACH - 1.0) * sin(PI * _pulse_age / PULSE_TIME)
	return reach


func spin() -> float:
	return settings.halo_spin * (1.0 + facet("spin"))


func damage() -> float:
	return settings.jelly_damage * (1.0 + facet("damage"))


func sting_tick() -> float:
	return settings.jelly_tick / (1.0 + facet("rate")) / rate_scale()


func on_stacks_changed() -> void:
	_build()


func on_removed() -> void:
	if is_instance_valid(_halo):
		_halo.queue_free()
	_halo = null
	Sfx.stop_loop(_loop)
	_loop = 0


## Where jelly `k` is now (`lag` radians behind: its ghost; `outer`: the third
## milestone's ring, further out and turning the other way).
func jelly_position(k: int, lag := 0.0, outer := false) -> Vector3:
	var a := (-_turn if outer else _turn) - lag + k * TAU / maxi(count(), 1) + (PI / maxi(count(), 1) if outer else 0.0)
	return fish.global_position + Vector3(cos(a), 0.15 * sin(a * 3.0 + _turn), sin(a)) * orbit_radius() * (OUTER_REACH if outer else 1.0)


func on_tick(delta: float) -> void:
	var trail := milestone(1)
	var outer := milestone(3)
	if not is_instance_valid(_halo) or _built != Vector3i(count(), 1 if trail else 0, 1 if outer else 0):
		_build()
	if _loop == 0:
		_loop = Sfx.start_loop("pw/jelly_halo_loop", fish)
	_turn = fmod(_turn + spin() * TAU * delta, TAU)
	_pulse_age = fmod(_pulse_age + delta, PULSE_EVERY)
	var n := count()
	for k in mini(n, _halo.get_child_count()):
		var jelly := _halo.get_child(k) as Node3D
		jelly.global_position = jelly_position(k)
		# Swimming: the bell squeezes and lets go, each a beat after the last.
		var beat := sin(_turn * 3.0 + k * 1.7)
		jelly.scale = Vector3(1.0 + 0.1 * beat, 1.0 - 0.12 * beat, 1.0 + 0.1 * beat) * settings.jelly_radius
	if trail:
		for k in mini(n, _halo.get_child_count() - n):
			var ghost := _halo.get_child(n + k) as Node3D
			ghost.global_position = jelly_position(k, TRAIL_LAG)
			ghost.scale = Vector3.ONE * settings.jelly_radius * 0.7
	if outer:
		var first := n * (2 if trail else 1)
		for k in mini(n, _halo.get_child_count() - first):
			var far := _halo.get_child(first + k) as Node3D
			far.global_position = jelly_position(k, 0.0, true)
	_sting_left -= delta
	if _sting_left > 0.0:
		return
	_sting_left += sting_tick()
	_sting_left = maxf(_sting_left, 0.0)
	for k in n:
		_sting(jelly_position(k), settings.jelly_radius, damage())
		if trail:
			_sting(jelly_position(k, TRAIL_LAG), settings.jelly_radius * 0.7, damage() * TRAIL_SHARE)
		if outer:
			_sting(jelly_position(k, 0.0, true), settings.jelly_radius, damage() * OUTER_SHARE)


func _sting(at: Vector3, reach: float, amount: float) -> void:
	for i in run.horde.query_sphere(at, reach):
		stings += 1
		var push := run.horde.enemy_position(i) - at
		run.hit(i, amount, fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP,
				settings.jelly_proc, [id])
		if milestone(4):
			_jump(i, amount * JUMP_SHARE)


## The fourth milestone: a sting jumps from zombie `from` to the nearest other
## within JUMP_REACH.
func _jump(from: int, amount: float) -> void:
	if not run.horde.is_alive(from):
		return
	var at := run.horde.enemy_position(from)
	var best := -1
	var best_gap := INF
	for j in run.horde.query_sphere(at, JUMP_REACH):
		var gap := run.horde.enemy_position(j).distance_squared_to(at)
		if j != from and gap < best_gap:
			best = j
			best_gap = gap
	if best < 0:
		return
	jumps += 1
	var to := run.horde.enemy_position(best)
	PowerupFx.flash(run, to, 0.4, color(id), 0.15)
	run.hit(best, amount, fish, id, (to - at).normalized(), settings.jelly_proc * 0.5, [id])


func _build() -> void:
	if not is_instance_valid(_halo):
		_halo = Node3D.new()
		_halo.name = "JellyHalo"
		_halo.top_level = true
		run.add_child(_halo)
	for child in _halo.get_children():
		child.queue_free()
		_halo.remove_child(child)
	var trail := milestone(1)
	var outer := milestone(3)
	_built = Vector3i(count(), 1 if trail else 0, 1 if outer else 0)
	var mesh := _jelly_mesh(color(id))
	for k in count():
		var jelly := MeshInstance3D.new()
		jelly.mesh = mesh
		jelly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jelly.scale = Vector3.ONE * settings.jelly_radius
		_halo.add_child(jelly)
		jelly.global_position = jelly_position(k)
	if trail:
		var faint := _jelly_mesh(color(id).darkened(0.4))
		for k in count():
			var ghost := MeshInstance3D.new()
			ghost.name = "Ghost"
			ghost.mesh = faint
			ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.scale = Vector3.ONE * settings.jelly_radius * 0.7
			_halo.add_child(ghost)
			ghost.global_position = jelly_position(k, TRAIL_LAG)
	if outer:
		for k in count():
			var far := MeshInstance3D.new()
			far.name = "Outer"
			far.mesh = mesh
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			far.scale = Vector3.ONE * settings.jelly_radius
			_halo.add_child(far)
			far.global_position = jelly_position(k, 0.0, true)


## One jelly, as one mesh: a bell that glows at its rim and is nearly clear
## face on (FxKit.rim), a bright frill round its edge, and wavy tentacles
## trailing off, fading. Fades near the camera.
static func _jelly_mesh(tint: Color) -> ArrayMesh:
	var bell := SphereMesh.new()
	bell.radius = 0.35
	bell.height = 0.4
	bell.is_hemisphere = true
	bell.radial_segments = 14
	bell.rings = 5
	var mesh := ArrayMesh.new()
	FxKit.merge_into(mesh, [[bell, Transform3D.IDENTITY]], FxKit.rim(Color(tint, 0.9), 0.12, 0.6, true))
	var frill := PackedVector3Array()
	for t in 21:
		var a := t * TAU / 20.0
		frill.append(Vector3(cos(a) * 0.35, -0.01 + 0.02 * sin(a * 6.0), sin(a) * 0.35))
	var tentacles := []
	for t in 6:
		var a := t * TAU / 6.0 + 0.3
		var line := PackedVector3Array()
		for k in 7:
			var s := k / 6.0
			var r := lerpf(0.22, 0.12, s)
			line.append(Vector3(cos(a) * r + 0.05 * sin(s * 9.0 + t), -0.02 - s * 0.75, sin(a) * r + 0.05 * cos(s * 9.0 + t)))
		tentacles.append(line)
	var glow := FxKit.glow(Color(tint.lerp(Color.WHITE, 0.25), 0.9), FxKit.across(), true)
	glow.vertex_color_use_as_albedo = true
	FxKit.merge_into(mesh, [[FxKit.ribbons([frill], [0.06]), Transform3D.IDENTITY],
			[FxKit.ribbons(tentacles, [0.05], true, true), Transform3D.IDENTITY]], glow)
	return mesh


## A thin glowing ring over the head.
func make_worn() -> Node3D:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.17
	ring.rings = 16
	ring.ring_segments = 4
	var halo := worn_mesh(ring, worn_material(1.5), Vector3(0.0, fish.hitbox_height * 0.5 + 0.2, -fish.hitbox_length * 0.15))
	halo.name = "Halo"
	return halo
