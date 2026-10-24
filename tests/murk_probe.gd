extends Node
## The murk (planning_murk.md) in the real game:
## - the fog maths: fog_reach() undoes fog_at(); murk_cull 1 never culls;
## - Unnatural turns the water murky (murk_density, the sky fogged with it) and
##   puts the ocean back after; murk_density 0 leaves the ocean's own fog;
## - the Horde draws a zombie only within the cull distance of a camera that
##   can see it (not behind every camera, murk_frustum), for every split-screen
##   camera; red eyes from glint_near to glint_far, and none without murk;
## - steering slows past the murk's far_reach (murk_far), or far_distance;
## - with murk_spawn_anywhere, packs spawn all round a player, in front too;
## - the minimap's survey counts the swarms into its grid and lists the
##   elites; your heading is up on the map.
##   Godot_console.exe --headless --path . res://tests/murk_probe.tscn

var main: Node
var fish: FishController
var run: UnnaturalRun
var settings := UnnaturalSettings.shared()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("the fog's maths:")
	var reach := UnnaturalSettings.fog_reach(0.98, 0.035)
	check(absf(reach - 111.77) < 0.1, "98%% fog at 0.035 is %.1f m out" % reach)
	check(absf(UnnaturalSettings.fog_at(reach, 0.035) - 0.98) < 0.0001, "fog_at() undoes fog_reach()")
	check(UnnaturalSettings.fog_reach(1.0, 0.035) == INF and UnnaturalSettings.fog_reach(0.5, 0.0) == INF, "never: a fog of 1, or no density")

	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	var ocean_env: Environment = main.get_node("Ocean").environment()
	var clear_density := ocean_env.fog_density
	var clear_sky := ocean_env.fog_sky_affect
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.battery_damage = 0.0
	settings.fish_attack = 2
	settings.twists = false
	settings.chest_drop_chance = 0.0
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	settings.difficulty_per_minute = 0.0
	settings.card_choices = 0
	settings.god_mode = true
	settings.murk_density = 0.035
	settings.murk_sky = 1.0
	settings.murk_cull = 0.98
	settings.murk_cull_margin = 5.0
	settings.murk_frustum = true
	settings.murk_far = 0.85
	settings.murk_spawn_anywhere = true
	settings.glint_from = 0.8
	settings.glint_distance = 170.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	var horde := run.horde
	run.start()
	await _ticks(5)

	print("the murk:")
	var env := ocean_env
	check(absf(env.fog_density - 0.035) < 0.0005, "Unnatural's water is murky (%.4f)" % env.fog_density)
	check(is_equal_approx(env.fog_sky_affect, 1.0), "and the sky's fogged with it")
	check(absf(horde.cull_distance - (reach + 5.0)) < 0.5, "the Horde's cull distance is the 98%% line plus the margin (%.1f m)" % horde.cull_distance)
	check(absf(horde.far_reach - UnnaturalSettings.fog_reach(0.85, 0.035)) < 0.5, "and steering slows past the 85%% line (%.1f m)" % horde.far_reach)
	var surface := run.blood_moon.find_child("Surface", false, false) as MeshInstance3D
	check(surface != null and (surface.mesh as PlaneMesh).size.x >= 2000.0, "the surface reaches far past the arena (no seam in view)")
	settings.murk_far = 0.0
	await _ticks(2)
	check(horde.far_reach < 0.0, "murk_far 0: far_distance again")
	settings.murk_far = 0.85
	settings.murk_density = 0.0
	await _frames(3)
	await _ticks(2)
	check(absf(env.fog_density - clear_density * 1.25) < 0.0005 and is_equal_approx(env.fog_sky_affect, clear_sky),
			"murk_density 0: the ocean's own fog (with the blood moon's), and its sky")
	check(horde.cull_distance == INF and horde.glint_far == 0.0, "and nothing's culled for distance, no eyes")
	settings.murk_density = 0.035
	await _ticks(2)

	print("drawing:")
	var camera := Camera3D.new()
	add_child(camera)
	var eye := run.centre + Vector3(0.0, 0.0, 60.0)
	camera.global_transform = Transform3D(Basis.IDENTITY, eye)  # looking along -z
	School.view_cameras = [camera] as Array[Camera3D]
	var near := _place(horde, eye + Vector3(0, 0, -20))
	var middle := _place(horde, eye + Vector3(0, 0, -80))
	var far := _place(horde, eye + Vector3(0, 0, -200))
	var behind := _place(horde, eye + Vector3(0, 0, 20))
	horde._draw_horde(0.0)
	check(horde.drawn_count == 2, "drawn: the ones at 20 m and 80 m ahead, not 200 m out or behind (%d)" % horde.drawn_count)
	check(horde.glint_count == 1, "red eyes: only the one at 80 m (%d)" % horde.glint_count)
	settings.murk_frustum = false
	horde._draw_horde(0.0)
	check(horde.drawn_count == 3, "murk_frustum off: the one behind too (%d)" % horde.drawn_count)
	settings.murk_frustum = true
	var second := Camera3D.new()
	add_child(second)
	second.global_transform = Transform3D(Basis.IDENTITY, eye + Vector3(0, 0, 50))
	School.view_cameras = [camera, second] as Array[Camera3D]
	horde._draw_horde(0.0)
	check(horde.drawn_count == 3, "split-screen: the one behind the first camera is in front of the second (%d)" % horde.drawn_count)
	check(horde.view_sets == 1, "cameras without their own player layers share one set of looks (%d)" % horde.view_sets)
	camera.cull_mask = TreasureChest.view_mask(0)
	second.cull_mask = TreasureChest.view_mask(1)
	horde._draw_horde(0.0)
	check(horde.view_sets == 2 and horde.drawn_count == 3 and horde.drawn_instances == 4,
			"per view: a set each, the first drawing the two ahead of it, the second the one behind and the near one (%d sets, %d, %d)" % [horde.view_sets, horde.drawn_count, horde.drawn_instances])
	var on_layer := func(s: int) -> int:
		var count := 0
		for look in horde._per_set:
			if horde._looks[s * horde._per_set + look].visible and horde._looks[s * horde._per_set + look].layers == TreasureChest.player_layer(s):
				count += horde._used[s * horde._per_set + look]
		return count
	check(on_layer.call(0) == 2 and on_layer.call(1) == 2, "each set on its own player's layer (%d, %d)" % [on_layer.call(0), on_layer.call(1)])
	settings.per_view_horde = false
	horde._draw_horde(0.0)
	check(horde.view_sets == 1 and horde.drawn_instances == 3, "per_view_horde off: one set for both (%d)" % horde.drawn_instances)
	settings.per_view_horde = true
	camera.cull_mask = 0xFFFFF
	School.view_cameras = [camera] as Array[Camera3D]

	print("detail:")
	var bands := func() -> PackedInt32Array:
		var counts := PackedInt32Array([0, 0, 0])
		for look in horde._per_set:
			counts[look % Horde.BANDS] += horde._used[look]
		return counts
	var close := _place(horde, eye + Vector3(0, 0, -6))
	horde._draw_horde(0.0)
	check(bands.call() == PackedInt32Array([1, 0, 2]), "near at 6 m; with lod_far_distance %.0f (times its size), far at 20 m and 80 m... (%s)" % [settings.lod_far_distance, bands.call()])
	settings.lod_far_distance = 50.0
	horde._draw_horde(0.0)
	check(bands.call() == PackedInt32Array([1, 1, 1]), "...mid at 20 m with it at 50 (%s)" % bands.call())
	settings.lod_far_distance = 30.0
	horde.remove(close)
	var full := 0
	var far_tris := 0
	var per_kind: Array[String] = []
	for kind in horde.kinds:
		var whole: Mesh = SchoolLook.meshes(kind.look_key())[0]
		var cut: Mesh = SchoolLook.detail_meshes(kind.look_key(), settings.lod_far_error)[0]
		var kind_full := 0
		var kind_far := 0
		for s in whole.get_surface_count():
			kind_full += (whole.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		for s in cut.get_surface_count():
			kind_far += (cut.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		full += kind_full
		far_tris += kind_far
		per_kind.append("%s %d/%d (%d/%d surfaces)" % [kind.id, kind_far, kind_full, cut.get_surface_count(), whole.get_surface_count()])
		if cut.get_surface_count() > whole.get_surface_count() or (cut.get_surface_count() == whole.get_surface_count() and kind.look_key() is int 				and kind.fish_class != FishCharacter.FishClass.DRIFTER):
			far_tris = full  # parts not merged: fail below (a jelly's parts each have their own shader: nothing to merge)
	print("    far/full per kind: ", ", ".join(per_kind))
	check(far_tris * 10 < full, "far looks are a tenth of the triangles or fewer, their parts merged where they can be (%d of %d)" % [far_tris, full])
	settings.lod_mid_error = 0.05
	horde._draw_horde(0.0)
	var mid_mesh: Mesh = horde._looks[1].multimesh.mesh
	check(mid_mesh == SchoolLook.detail_meshes(horde.kinds[0].look_key(), 0.05)[0], "changing an error re-cuts the looks")
	settings.lod_mid_error = 0.02
	horde._draw_horde(0.0)
	settings.murk_cull = 1.0
	settings.glint_distance = 0.0
	horde.apply_murk(0.035)
	horde._draw_horde(0.0)
	check(horde.drawn_count == 3 and horde.glint_count == 0, "murk_cull 1 and glint_distance 0: all three ahead drawn, no eyes (%d, %d)" % [horde.drawn_count, horde.glint_count])
	settings.murk_cull = 0.98
	settings.glint_distance = 170.0
	horde.apply_murk(0.035)
	for i: int in [near, middle, far, behind]:
		horde.remove(i)

	print("the minimap's survey:")
	var spot := run.centre + Vector3(20.0, 0.0, -30.0)
	for n in 12:
		horde.spawn(0, spot + Vector3(n * 0.1, 0.0, 0.0), Vector3.FORWARD)
	horde.spawn(0, run.centre + Vector3(-40.0, 0.0, 10.0), Vector3.FORWARD, true)
	await _ticks(6)  # a Horde step or two (30 Hz), so they're in its live list
	horde.survey(4.0, 0.0)
	var cells := horde.survey_cells
	var x := int((spot.x - horde.survey_origin.x) / horde.survey_cell)
	var z := int((spot.z - horde.survey_origin.z) / horde.survey_cell)
	var counted := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			counted += horde.survey_counts[clampi(z + dz, 0, cells - 1) * cells + clampi(x + dx, 0, cells - 1)]
	check(counted == 12.0, "the pack of 12 is counted where it is (%d)" % counted)
	check(horde.survey_elites.size() == 1, "the elite is listed apart (%d)" % horde.survey_elites.size())
	var map: Minimap = main._unnatural_hud._minimap
	await _frames(3)
	check(map.visible, "the map's up")
	var player_camera := map.hud.player_camera if is_instance_valid(map.hud.player_camera) else get_viewport().get_camera_3d()
	var ahead := -player_camera.global_basis.z
	ahead.y = 0.0
	var ahead_spot := map.to_map(fish.global_position + ahead.normalized() * 20.0)
	check(ahead_spot.y < map.size.y * 0.5 - 5.0 and absf(ahead_spot.x - map.size.x * 0.5) < 2.0, "where you look is straight up on it")
	settings.minimap = false
	await _frames(2)
	check(not map.visible, "minimap off hides it")
	settings.minimap = true

	print("spawning in the murk:")
	var facing := -fish.global_basis.z
	var in_front := 0
	var in_band := 0
	for n in 300:
		var p := run.spawn_point(fish.global_position)
		var off := p - fish.global_position
		if off.normalized().dot(facing) >= UnnaturalRun.SPAWN_HIDDEN:
			in_front += 1
		if off.length() <= settings.spawn_distance_max + 1.0:
			in_band += 1
	check(in_front > 30, "packs turn up in front too (%d of 300)" % in_front)
	check(in_band == 300, "all within spawn_distance_max (%d)" % in_band)
	settings.murk_spawn_anywhere = false
	in_front = 0
	for n in 300:
		var p := run.spawn_point(fish.global_position)
		if (p - fish.global_position).normalized().dot(facing) >= UnnaturalRun.SPAWN_HIDDEN:
			in_front += 1
	check(in_front < 5, "murk_spawn_anywhere off: out of view again (%d in front)" % in_front)
	settings.murk_spawn_anywhere = true

	print("leaving:")
	School.view_cameras = [] as Array[Camera3D]
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	check(absf(env.fog_density - clear_density) < 0.0005 and is_equal_approx(env.fog_sky_affect, clear_sky),
			"the ocean's fog and sky are back (%.4f, %.2f)" % [env.fog_density, env.fog_sky_affect])
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## A still zombie at `at` (drawn where it is: its last position too).
func _place(horde: Horde, at: Vector3) -> int:
	var i := horde.spawn(0, at, Vector3.FORWARD)
	horde._last_position[i] = at
	horde._position[i] = at
	return i


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
