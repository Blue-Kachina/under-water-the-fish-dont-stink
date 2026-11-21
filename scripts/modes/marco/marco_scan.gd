class_name MarcoScan
extends Node3D
## The "Marco!" scan (planning_marco_polo.md, play-test 2): an energy pulse
## from where the seeker called, a shell racing out over marco_scan_time until
## it's covered the whole arena (a bright line where it cuts the scenery). Every machine
## sees the pulse: it gives the seeker away.
## On a seeker's machine (local_view_role() == SEEKER) the pulse also leaves
## ghosts: once the front reaches a live hider or a Fake Fish (not one in a
## porthole), every cell its body moves through for ghost_window seconds
## glows. A cell's heat is how far the fish moved while covering it, adding up
## over frames, so a fish that barely moved leaves a faint copy of its shape
## and a fast one a long streak. Each cell fades from the last time it was
## touched, the hotter the longer, so a streak's start fades before its end.
## Movement comes from the body's transform frame to frame, so it works the
## same on puppets (online guests).

const SCAN_SHADER := preload("res://shaders/marco_scan.gdshader")
const GHOST_SHADER := preload("res://shaders/marco_ghost.gdshader")
const GHOST_WALLS_SHADER := preload("res://shaders/marco_ghost_walls.gdshader")
const RIPPLE_SHADER := preload("res://shaders/marco_ripple.gdshader")
const RIPPLE_WALLS_SHADER := preload("res://shaders/marco_ripple_walls.gdshader")
## MarcoPoloMatch.Role.SEEKER (Role { HIDER, SEEKER }).
const SEEKER := 1
## The pulse's mint (the streaks have their own colour: ghost_color).
const COLOR := Color(0.4, 1.0, 0.75)
## Body samples per species (spread over the Body mesh's vertices).
const MAX_POINTS := 260
## Bigger jumps than this in a frame are teleports (a respawn), not movement (m).
const TELEPORT := 6.0

var match_node: Node
var settings: Resource
## Whether this machine draws a seeker's view (so records and shows ghosts).
var seeker_view := false
## The pulses running: {origin, age, reach, shell, material, seeker, reached: {fish id -> age}}.
var pulses: Array[Dictionary] = []
## The ghost cells: Vector3i -> Vector4(heat, time last touched, 0, time it shows from).
var cells := {}

var _clock := 0.0
## Streak heads for MarcoScan.streak_heads: seeker id -> {fish id -> {pos, heading, time, strength}}.
## Kept on every machine and in any view (bots read them), unlike the drawn cells.
var _heads := {}
## The wake ripples: {pos, born (clock), power 0..1}, oldest first. Each is a thin ring
## that widens and fades; rings shed along a path make a V-shaped wake.
var ripples: Array[Dictionary] = []
var _ripples := MultiMeshInstance3D.new()
var _ripple_material := ShaderMaterial.new()
var _ripple_walls := ShaderMaterial.new()
var _ripple_buffer := PackedFloat32Array()
var _since_ripple := {}  # fish id -> metres since its last ripple
var _last := {}  # fish instance id -> its body's Transform3D last frame
var _ghosts := MultiMeshInstance3D.new()
var _ghost_material := ShaderMaterial.new()
var _ghost_walls := ShaderMaterial.new()
var _buffer := PackedFloat32Array()
static var _points := {}  # "class:species" -> PackedVector3Array in the body's space


## Hooks the scan to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	mp_match.set_meta("marco_scan", self)
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as Resource if from_match is Resource else MarcoPoloSettings.shared()
	if mp_match.has_signal("marco_scan_started"):
		mp_match.connect("marco_scan_started", func(origin: Vector3, seeker: Node) -> void: start_pulse(origin, seeker))
	elif mp_match.has_signal("marco_called"):
		mp_match.connect("marco_called", _on_marco)
	if mp_match.has_signal("round_started"):
		mp_match.connect("round_started", func(_index: int, _seeker: Node) -> void: clear())


func _ready() -> void:
	top_level = true
	_ghost_material.shader = GHOST_SHADER
	_ghost_walls.shader = GHOST_WALLS_SHADER
	_ghost_material.next_pass = _ghost_walls
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	_ghosts.multimesh = multi
	_ghosts.material_override = _ghost_material
	_ghosts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghosts.extra_cull_margin = 16384.0  # the cells are anywhere in the arena
	add_child(_ghosts)
	_ripple_material.shader = RIPPLE_SHADER
	_ripple_walls.shader = RIPPLE_WALLS_SHADER
	_ripple_material.next_pass = _ripple_walls
	var ring := QuadMesh.new()
	ring.size = Vector2.ONE
	var ripple_multi := MultiMesh.new()
	ripple_multi.transform_format = MultiMesh.TRANSFORM_3D
	ripple_multi.use_colors = true
	ripple_multi.mesh = ring
	_ripples.multimesh = ripple_multi
	_ripples.material_override = _ripple_material
	_ripples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ripples.extra_cull_margin = 16384.0
	add_child(_ripples)


func _setting(setting: String, fallback: Variant) -> Variant:
	var value: Variant = settings.get(setting) if settings else null
	return fallback if value == null else value


func _call(method: String, args: Array, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node) or not match_node.has_method(method):
		return fallback
	return match_node.callv(method, args)


## Drops every pulse and ghost (a new round).
func clear() -> void:
	for pulse in pulses:
		_free_pulse(pulse)
	pulses.clear()
	cells.clear()
	_heads.clear()
	ripples.clear()
	_since_ripple.clear()
	_ripples.multimesh.visible_instance_count = 0
	_last.clear()
	_ghosts.multimesh.visible_instance_count = 0


## Starts a pulse from `seeker` (every machine).
func _on_marco(seeker: Node) -> void:
	if seeker is Node3D and is_instance_valid(seeker):
		start_pulse((seeker as Node3D).global_position, seeker)


func start_pulse(origin: Vector3, seeker: Node = null) -> void:
	var material := ShaderMaterial.new()
	material.shader = SCAN_SHADER
	material.set_shader_parameter("color", COLOR)
	material.set_shader_parameter("glow", float(_setting("scan_glow", 1.0)))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var shell := MeshInstance3D.new()
	shell.mesh = sphere
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.extra_cull_margin = 16384.0
	add_child(shell)
	shell.global_position = origin
	pulses.append({"origin": origin, "age": 0.0, "reach": _reach(origin), "shell": shell,
			"material": material, "reached": {},
			"seeker": seeker.get_instance_id() if seeker else 0})


## How far the pulse has to go from `origin` to cover the arena: its box's far corner.
func _reach(origin: Vector3) -> float:
	var world: Variant = match_node.get("arena") if is_instance_valid(match_node) else null
	var box_size: Variant = (world as Node3D).get("size") if world is Node3D and is_instance_valid(world) else null
	if box_size is Vector3:
		var box := AABB((world as Node3D).global_position - (box_size as Vector3) * 0.5, box_size as Vector3)
		var far := 0.0
		for i in 8:
			far = maxf(far, origin.distance_to(box.get_endpoint(i)))
		return far
	return float(_setting("ocean_radius", 90.0)) * 2.0


## The pulse's radius `age` s in: quick out of the gate, easing off.
func radius_at(pulse: Dictionary, age: float) -> float:
	var t := clampf(age / maxf(float(_setting("marco_scan_time", 2.0)), 0.05), 0.0, 1.0)
	return float(pulse.reach) * (1.0 - pow(1.0 - t, 1.6))


func _process(delta: float) -> void:
	_clock += delta
	seeker_view = int(_call("local_view_role", [], 0)) == SEEKER
	var scan_time := maxf(float(_setting("marco_scan_time", 2.0)), 0.05)
	var window := float(_setting("ghost_window", 1.5))
	var recording := false
	for pulse in pulses:
		pulse.age = float(pulse.age) + delta
		_draw_pulse(pulse, scan_time)
		if float(pulse.age) < scan_time + window:
			recording = true
	for i in range(pulses.size() - 1, -1, -1):
		if float(pulses[i].age) >= scan_time + window:
			_free_pulse(pulses[i])
			pulses.remove_at(i)
	if recording:
		_record(delta, window)
	else:
		_last.clear()
	_draw_ghosts()
	_draw_ripples()


func _draw_pulse(pulse: Dictionary, scan_time: float) -> void:
	var progress := clampf(float(pulse.age) / scan_time, 0.0, 1.0)
	var radius := maxf(radius_at(pulse, float(pulse.age)), 0.01)
	var shell := pulse.shell as MeshInstance3D
	shell.visible = progress < 1.0
	shell.scale = Vector3.ONE * radius
	(pulse.material as ShaderMaterial).set_shader_parameter("progress", progress)


func _free_pulse(pulse: Dictionary) -> void:
	if is_instance_valid(pulse.shell):
		(pulse.shell as Node).queue_free()


# --- Ghosts -------------------------------------------------------------------

## The fish a scan can catch moving: live hiders out of the portholes and Fake Fish.
func _candidates() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish: Variant in _call("live_hiders", [], []):
		if is_instance_valid(fish) and fish is FishController and not bool(_call("is_hidden", [fish], false)):
			out.append(fish)
	for fake: Variant in _call("decoys", [], []):
		if is_instance_valid(fake) and fake is FishController:
			out.append(fake)
	return out


func _record(delta: float, window: float) -> void:
	var min_speed := float(_setting("ghost_min_speed", 0.25))
	var echo := float(_setting("ghost_still_echo", 0.3))
	var full := float(_setting("ghost_full", 1.5))
	var scale := maxf(float(_setting("ghost_intensity_scale", 2.5)), 0.001)
	var seen := {}
	for fish in _candidates():
		var body := _body_of(fish)
		if body == null:
			continue
		var id := fish.get_instance_id()
		seen[id] = true
		var now := body.global_transform
		var was: Variant = _last.get(id)
		_last[id] = now
		var moved := (was as Transform3D).origin.distance_to(now.origin) if was is Transform3D else 0.0
		var steady: bool = was is Transform3D and moved <= TELEPORT  # not a respawn
		var velocity := ((now.origin - (was as Transform3D).origin) / maxf(delta, 0.0001)) if steady else Vector3.ZERO
		var moving: bool = steady and moved >= min_speed * delta
		var into := -1.0  # how far into the window (0..1), the latest pulse's
		var fresh := false  # the front reached it this frame
		for pulse in pulses:
			var reached: Dictionary = pulse.reached
			if not reached.has(id) and (pulse.origin as Vector3).distance_to(now.origin) <= radius_at(pulse, float(pulse.age)):
				reached[id] = float(pulse.age)
				fresh = true
			if reached.has(id) and float(pulse.age) - float(reached[id]) <= window:
				into = maxf(into, (float(pulse.age) - float(reached[id])) / maxf(window, 0.001))
				if moving:
					_set_head(int(pulse.seeker), id, now.origin, velocity, clampf(velocity.length() / 8.0, 0.15, 1.0))
				elif reached[id] == pulse.age:
					_set_head(int(pulse.seeker), id, now.origin, Vector3.ZERO, clampf(echo, 0.05, 1.0))
		if into < 0.0:
			continue
		if seeker_view:
			if fresh and echo > 0.0:
				# The front just reached it: a faint copy of its body, moving or not.
				_stamp(fish, now, now, echo * full / scale)
				_ripple(now.origin, clampf(echo * 2.0, 0.2, 1.0))
			if moving:
				_shed(id, (was as Transform3D).origin, now.origin, clampf(velocity.length() / 8.0, 0.25, 1.0))
				# Later in the window counts for more: the streak's head glows longer than its tail.
				_stamp(fish, was as Transform3D, now, moved * (0.35 + 0.65 * into))
	for id: Variant in _last.keys():
		if not seen.has(id):
			_last.erase(id)


## Sheds a ripple every ghost_ripple_gap metres along the path `from` -> `to`.
func _shed(fish_id: int, from: Vector3, to: Vector3, power: float) -> void:
	var gap := maxf(float(_setting("ghost_ripple_gap", 0.7)), 0.05)
	var length := maxf(from.distance_to(to), 0.0001)
	var next := gap - float(_since_ripple.get(fish_id, gap))  # metres along this step to the next ripple
	while next <= length:
		_ripple(from.lerp(to, maxf(next, 0.0) / length), power)
		next += gap
	_since_ripple[fish_id] = length - (next - gap)


func _ripple(at: Vector3, power: float) -> void:
	if ripples.size() >= int(_setting("ghost_ripple_max", 3000)) or float(_setting("ghost_ripple_glow", 1.0)) <= 0.0:
		return
	ripples.append({"pos": at, "born": _clock, "power": power})


## Where a streak ends now: the newest place `fish_id` was seen moving after `seeker_id`'s call.
func _set_head(seeker_id: int, fish_id: int, at: Vector3, velocity: Vector3, strength: float) -> void:
	var of_seeker: Dictionary = _heads.get(seeker_id, {})
	var heading := velocity.normalized() if velocity.length() > 0.01 else Vector3.ZERO
	of_seeker[fish_id] = {"pos": at, "heading": heading, "time": _clock, "strength": strength, "fish": fish_id}
	_heads[seeker_id] = of_seeker


## The streaks' heads `seeker`'s last calls left, for bots and the scope:
## [{pos: Vector3, heading: Vector3 (zero for a still body echo), age: float (s), strength: 0..1}].
## One per hider (its newest), nothing older than ghost_fade_max. The streaks hide nobody
## from this: a hider who has since gone into a porthole stays out of the list.
func streak_heads(seeker: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seeker == null:
		return out
	var of_seeker: Dictionary = _heads.get(seeker.get_instance_id(), {})
	var oldest := float(_setting("ghost_fade_max", 8.0))
	for fish_id: Variant in of_seeker.keys():
		var head: Dictionary = of_seeker[fish_id]
		var age := _clock - float(head.time)
		var fish: Object = instance_from_id(int(fish_id))
		if age > oldest or not is_instance_valid(fish) or bool(_call("is_hidden", [fish], false)):
			continue
		out.append({"pos": head.pos, "heading": head.heading, "age": age, "strength": float(head.strength)})
	return out


## Every cell the body covers on its way from `from` to `to` gets `weight` (scaled) more heat.
func _stamp(fish: FishController, from: Transform3D, to: Transform3D, weight: float) -> void:
	var points := _points_of(fish)
	if points.is_empty():
		return
	var cell := maxf(float(_setting("ghost_cell", 0.15)), 0.02)
	var cap := int(_setting("ghost_max_cells", 16000))
	var delay := float(_setting("ghost_show_delay", 0.3))
	var steps := clampi(ceili(from.origin.distance_to(to.origin) / cell), 1, 16)
	var touched := {}
	for k in range(1, steps + 1):
		var xform := from.interpolate_with(to, float(k) / steps)
		for point in points:
			touched[Vector3i(((xform * point) / cell).floor())] = true
	var heat := weight * float(_setting("ghost_intensity_scale", 2.5))
	for key: Vector3i in touched:
		var old: Vector4 = cells.get(key, Vector4.ZERO)
		if old == Vector4.ZERO and cells.size() >= cap:
			continue
		cells[key] = Vector4(old.x + heat, _clock, 0.0, old.w if old != Vector4.ZERO else _clock + delay)


func _body_of(fish: FishController) -> MeshInstance3D:
	var model: Variant = fish.get("_visual")
	if model is FishModel and is_instance_valid(model):
		return FishAnatomy.body_of(model as FishModel)
	return null


## Up to MAX_POINTS of the body mesh's vertices, thinned on a fine grid (cached per species).
func _points_of(fish: FishController) -> PackedVector3Array:
	var model := fish.get("_visual") as FishModel
	var key := "%d:%d" % [model.fish_class, model.species]
	if _points.has(key):
		return _points[key]
	var body := FishAnatomy.body_of(model)
	var out := PackedVector3Array()
	if body and body.mesh and body.mesh.get_surface_count() > 0:
		var verts: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bounds := body.mesh.get_aabb()
		var grid := maxf(bounds.size.length() / 40.0, 0.01)
		var kept := {}
		for v in verts:
			kept[Vector3i((v / grid).floor())] = v
		var all: Array = kept.values()
		var stride := maxf(float(all.size()) / MAX_POINTS, 1.0)
		var i := 0.0
		while int(i) < all.size():
			out.append(all[int(i)])
			i += stride
	_points[key] = out
	return out


## Fades the cells and hands the live ones to the MultiMesh (shown only in a seeker's view).
func _draw_ghosts() -> void:
	var multi := _ghosts.multimesh
	_ghosts.visible = seeker_view and not cells.is_empty()
	if cells.is_empty():
		multi.visible_instance_count = 0
		return
	var cell := maxf(float(_setting("ghost_cell", 0.15)), 0.02)
	var full := maxf(float(_setting("ghost_full", 1.5)), 0.001)
	var fade_min := float(_setting("ghost_fade_min", 3.0))
	var fade_max := float(_setting("ghost_fade_max", 8.0))
	var head_time := maxf(float(_setting("ghost_head_time", 0.6)), 0.01)
	var size := cell * float(_setting("ghost_point_scale", 2.2))
	var walls := float(_setting("ghost_through_walls", 0.6))
	var glow := float(_setting("ghost_glow", 1.5))
	var cold := _setting("ghost_color", Color(0.35, 0.62, 1.0)) as Color
	var hot := _setting("ghost_head_color", Color(0.9, 0.97, 1.0)) as Color
	for material: ShaderMaterial in [_ghost_material, _ghost_walls]:
		material.set_shader_parameter("point_size", size)
		material.set_shader_parameter("glow", glow)
		material.set_shader_parameter("cold", cold)
		material.set_shader_parameter("hot", hot)
	_ghost_walls.set_shader_parameter("strength", walls)
	if multi.instance_count < cells.size():
		multi.instance_count = ceili(cells.size() / 512.0) * 512
		_buffer.resize(multi.instance_count * 16)
	var gone: Array[Vector3i] = []
	var n := 0
	for key: Vector3i in cells:
		var entry: Vector4 = cells[key]
		var heat := clampf(entry.x / full, 0.0, 1.0)
		var left := 1.0 - (_clock - entry.y) / maxf(lerpf(fade_min, fade_max, heat), 0.01)
		if left <= 0.0:
			gone.append(key)
			continue
		if _clock < entry.w:
			continue  # held back until the pulse front has moved past
		var head := clampf(1.0 - (_clock - entry.y) / head_time, 0.0, 1.0)
		var at := (Vector3(key) + _jitter(key)) * cell
		var o := n * 16
		_buffer[o] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = at.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = at.y
		_buffer[o + 8] = 0.0
		_buffer[o + 9] = 0.0
		_buffer[o + 10] = 1.0
		_buffer[o + 11] = at.z
		_buffer[o + 12] = heat
		_buffer[o + 13] = head
		_buffer[o + 14] = 0.0
		_buffer[o + 15] = left
		n += 1
	for key in gone:
		cells.erase(key)
	multi.buffer = _buffer
	multi.visible_instance_count = n


## Ages the ripples and hands the live ones to their MultiMesh: radius from the ring's age.
func _draw_ripples() -> void:
	var multi := _ripples.multimesh
	_ripples.visible = seeker_view and not ripples.is_empty()
	var life := maxf(float(_setting("ghost_ripple_life", 3.0)), 0.05)
	while not ripples.is_empty() and _clock - float(ripples[0].born) >= life:
		ripples.pop_front()
	if ripples.is_empty() or not seeker_view:
		multi.visible_instance_count = 0
		return
	var speed := float(_setting("ghost_ripple_speed", 2.2))
	var start := float(_setting("ghost_ripple_start", 0.25))
	var cold := _setting("ghost_color", Color(0.35, 0.62, 1.0)) as Color
	var hot := _setting("ghost_head_color", Color(0.9, 0.97, 1.0)) as Color
	for material: ShaderMaterial in [_ripple_material, _ripple_walls]:
		material.set_shader_parameter("cold", cold)
		material.set_shader_parameter("hot", hot)
		material.set_shader_parameter("glow", float(_setting("ghost_ripple_glow", 1.0)))
		material.set_shader_parameter("width", float(_setting("ghost_ripple_width", 0.09)))
	_ripple_walls.set_shader_parameter("strength", float(_setting("ghost_through_walls", 0.6)))
	if multi.instance_count < ripples.size():
		multi.instance_count = ceili(ripples.size() / 256.0) * 256
		_ripple_buffer.resize(multi.instance_count * 16)
	var n := 0
	for ripple in ripples:
		var age := _clock - float(ripple.born)
		var radius := start + speed * age
		var left := 1.0 - age / life
		var at: Vector3 = ripple.pos
		var o := n * 16
		_ripple_buffer[o] = radius
		_ripple_buffer[o + 1] = 0.0
		_ripple_buffer[o + 2] = 0.0
		_ripple_buffer[o + 3] = at.x
		_ripple_buffer[o + 4] = 0.0
		_ripple_buffer[o + 5] = radius
		_ripple_buffer[o + 6] = 0.0
		_ripple_buffer[o + 7] = at.y
		_ripple_buffer[o + 8] = 0.0
		_ripple_buffer[o + 9] = 0.0
		_ripple_buffer[o + 10] = radius
		_ripple_buffer[o + 11] = at.z
		_ripple_buffer[o + 12] = float(ripple.power)
		_ripple_buffer[o + 13] = 0.0
		_ripple_buffer[o + 14] = 0.0
		_ripple_buffer[o + 15] = left
		n += 1
	multi.buffer = _ripple_buffer
	multi.visible_instance_count = n


## A fixed spot inside cell `key` (0..1 each way), so the points don't sit on a lattice.
static func _jitter(key: Vector3i) -> Vector3:
	var h := absi(key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791)
	return Vector3(0.15 + 0.7 * float(h % 1024) / 1024.0, 0.15 + 0.7 * float((h >> 10) % 1024) / 1024.0,
			0.15 + 0.7 * float((h >> 20) % 1024) / 1024.0)


## The cells' centres inside `box` (world space), for probes.
func cells_in(box: AABB) -> Array[Vector3]:
	var cell := maxf(float(_setting("ghost_cell", 0.15)), 0.02)
	var out: Array[Vector3] = []
	for key: Vector3i in cells:
		var at := (Vector3(key) + Vector3.ONE * 0.5) * cell
		if box.has_point(at):
			out.append(at)
	return out
