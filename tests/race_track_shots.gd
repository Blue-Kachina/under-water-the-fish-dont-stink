extends Node
## Not a probe: pictures of the Canyon Reef Circuit for checking the track by eye. A top-down map (the rock above the
## water is clipped away, so the channel shows as its floor, with the centreline, racing line, checkpoints, streams
## and features drawn on it) and a shot at every feature, from behind and above, as a racer would meet it.
## Needs a window (not --headless):
##   Godot_console.exe --path . res://tests/race_track_shots.tscn -- --out=DIR [--only=map|features|NAME]

var out_dir := "user://race_track_shots"
var only := ""
var track: RaceTrack
var course: CanyonReefArena
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	add_child(sun)
	course = CanyonReefArena.new()
	add_child(course)
	course.configure_environment(environment.environment)
	track = course.track
	print("built: %s" % [course.terrain.stats])
	camera = Camera3D.new()
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	await _frames(4)
	if only == "" or only == "map":
		await _map()
	if only == "" or only == "features":
		await _features()
	if only == "" or only == "fx":
		await _fx()
	get_tree().quit()


## Two racers at speed on the climb's stream and the straight: the streaks, the draft glow and a stream's bubbles.
func _fx() -> void:
	var scene := load("res://scenes/fish.tscn") as PackedScene
	var fishes: Array[FishController] = []
	var d := float(CanyonReefTrack.features()["stream"]) + 6.0
	for i in 3:
		var fish := scene.instantiate() as FishController
		add_child(fish)
		fish.controls = FishInput.new()
		var fix := track.sample(d - float(i) * 6.0)
		var at := fix.pos + fix.right * (-3.0 if i == 1 else 0.0)
		fish.global_transform = Transform3D(Basis.looking_at(fix.forward, Vector3.UP), at)
		fishes.append(fish)
	camera.fov = 70.0
	for step in 90:
		for fish in fishes:
			fish.linear_velocity = -fish.global_basis.z * 20.0
		await get_tree().physics_frame
		if step == 70 or step == 85:
			var back := track.nearest(fishes[2].global_position)
			var from := fishes[2].global_position - back.forward * 9.0 + back.up * 3.5 + back.right * 4.0
			camera.global_transform = Transform3D(Basis.looking_at((fishes[0].global_position - from).normalized(), Vector3.UP), from)
			await _frames(1)
			await _shot("fx_pack_%d" % step)
	for fish in fishes:
		fish.queue_free()


func _map() -> void:
	var bounds := course.layout.bounds
	var centre := bounds.get_center()
	var overlay := _overlay()
	add_child(overlay)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(bounds.size.x, bounds.size.z) * 0.78
	camera.far = 400.0
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(centre.x, 130.0, centre.z))
	camera.near = 130.0 - 46.0  # clips the rock above y 46: the roofs and the rim come away
	await _frames(3)
	await _shot("map_top")
	camera.near = 0.05
	camera.far = 600.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	overlay.queue_free()


func _features() -> void:
	camera.fov = 75.0
	var features := CanyonReefTrack.features()
	var seen := {}
	for cp in track.checkpoints:
		var tag: String = cp["tag"]
		if tag == "" or tag == "bend" or tag == "stream":
			continue
		var d := float(cp["d"])
		var key := "%s_%d" % [tag, roundi(d)]
		if seen.has(tag) and tag != "tunnel":
			continue
		seen[tag] = true
		var back := track.sample(d - 24.0)
		var look := track.sample(d + 12.0)
		var from := back.pos + back.up * 7.0 + back.right * 3.0
		camera.global_transform = Transform3D(Basis.looking_at((look.pos - from).normalized(), Vector3.UP), from)
		await _frames(3)
		await _shot("feature_" + key)
		var high := track.sample(d)
		var above := high.pos + Vector3.UP * 38.0 - high.forward * 22.0
		camera.global_transform = Transform3D(Basis.looking_at((high.pos - above).normalized(), Vector3.UP), above)
		await _frames(2)
		await _shot("feature_" + key + "_above")
	var bend := track.sample(float(features.get("bend", 100.0)))
	var at := bend.pos + Vector3.UP * 7.0 - bend.forward * 22.0
	camera.global_transform = Transform3D(Basis.looking_at((bend.pos + bend.forward * 14.0 - at).normalized(), Vector3.UP), at)
	await _frames(3)
	await _shot("feature_bend")
	var line := track.sample(0.0)
	var behind := line.pos - line.forward * 26.0 + Vector3.UP * 6.0
	camera.global_transform = Transform3D(Basis.looking_at((line.pos + line.forward * 40.0 - behind).normalized(), Vector3.UP), behind)
	await _frames(3)
	await _shot("feature_grid")


## The track drawn over the water: the centreline (white), racing line (green), checkpoints (yellow ticks), streams
## (cyan) and the tagged points (red), at y 45 (just under the map's clip).
func _overlay() -> Node3D:
	var root := Node3D.new()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var lap := track.lap_length
	var n := int(lap / 2.0)
	for i in n:
		var d0 := float(i) * 2.0
		var d1 := d0 + 2.0
		_line(mesh, track.sample(d0).pos, track.sample(d1).pos, Color.WHITE)
		_line(mesh, track.racing_line(d0), track.racing_line(d1), Color(0.2, 1.0, 0.3))
		var f0 := track.sample(d0)
		_line(mesh, f0.pos - f0.right * f0.width * 0.5, track.sample(d1).pos - track.sample(d1).right * track.sample(d1).width * 0.5, Color(1.0, 0.6, 0.2))
		_line(mesh, f0.pos + f0.right * f0.width * 0.5, track.sample(d1).pos + track.sample(d1).right * track.sample(d1).width * 0.5, Color(1.0, 0.6, 0.2))
	for cp in track.checkpoints:
		var p: Vector3 = cp["pos"]
		var r: Vector3 = cp["right"]
		var w := float(cp["width"]) * 0.5
		_line(mesh, p - r * w, p + r * w, Color(1.0, 1.0, 0.2) if cp["tag"] == "" else Color(1.0, 0.2, 0.2))
	for s in track.streams:
		var d := float(s["d0"])
		while d < float(s["d1"]):
			var f := track.sample(d)
			var off: Vector2 = s["offset"]
			var p := f.pos + f.right * off.x + f.up * off.y
			_line(mesh, p - f.right * 2.0, p + f.right * 2.0, Color(0.2, 0.9, 1.0))
			d += 2.0
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = 0.0
	root.add_child(instance)
	return root


func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(a.x, 45.0, a.z))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(b.x, 45.0, b.z))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("shot %s" % shot_name)
