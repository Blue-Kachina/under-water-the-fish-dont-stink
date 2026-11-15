extends Node
## Blade flora (FloraField, planning_abyssal_look.md flora pass): the blade data round-trips through a MultiMesh, a kelp column makes
## its strands, stipes, blades and glints, the Seabed builds blade kelp (and the old meshes with the flag off), clear_around removes
## blades, and the far level keeps its share. Prints the blade counts.
##   Godot_console.exe --headless --path . res://tests/flora_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("FloraField:")
	var field := FloraField.new()
	add_child(field)
	field.add_blade(Vector3(3, 1, 4), 1.5, 2.0, 0.4, 0.2, 5.0, FloraField.Type.AMBER, 0.5, 0.25, 0.75)
	field.build()
	check(field.blade_count() == 1 and field.node_count() == 2, "one blade, a near and a far node")
	var headless := DisplayServer.get_name() == "headless"  # the dummy renderer keeps no instance data
	var near: MultiMeshInstance3D = null
	for slot: Array in field._nodes:
		if not slot[2]:
			near = field._nodes[slot]
	check(near != null and near.multimesh.instance_count == 1, "near multimesh has the blade")
	if near and not headless:
		var t := near.multimesh.get_instance_transform(0)
		check(t.origin.is_equal_approx(Vector3(3, 1, 4)), "origin round-trips")
		check(t.basis.x.is_equal_approx(Vector3(1.5, 2.0, 0.4)), "length, yaw, tilt in basis.x")
		check(t.basis.y.is_equal_approx(Vector3(0.2, 5.0, float(FloraField.Type.AMBER) + 0.495)), "width, sway height, type+bend in basis.y")
		check(t.basis.z.x == 0.25 and is_equal_approx(t.basis.z.y, 0.75), "seeds in basis.z")
	check(FloraField.blade_mesh(7).surface_get_array_len(0) == 14 and FloraField.blade_mesh(3).surface_get_array_len(0) == 6, "7-row mesh has 14 vertices, 3-row 6")
	field.queue_free()

	print("Kelp column:")
	var f2 := FloraField.new()
	f2.far_keep = 0.5
	add_child(f2)
	var dice := RandomNumberGenerator.new()
	dice.seed = 5
	var made := f2.add_kelp_column(Vector3(10, 0, 10), 8.0, 0, 30.0, 1.0, 4.0, 1.0, dice)
	f2.build()
	check(made == f2.blade_count() and made > 100, "column adds blades (%d)" % made)
	check(f2.glint_count() == 32, "glints per metre (%d)" % f2.glint_count())
	var far := f2.far_blade_count()
	check(far < f2.blade_count() and far > f2.blade_count() / 4, "far level keeps a share (%d of %d)" % [far, f2.blade_count()])
	f2.clear_around(Vector3(10, 0, 10), 3.0)
	check(f2.blade_count() == 0 and f2.glint_count() == 0, "clear_around removes the column")
	f2.queue_free()

	print("Seabed:")
	var settings := UnnaturalSettings.new()
	var bed := Seabed.new()
	add_child(bed)
	var t0 := Time.get_ticks_msec()
	bed.setup(settings, 11, 20.0)
	bed.set_murk(settings.murk_density)
	var ms := Time.get_ticks_msec() - t0
	check(bed.flora != null, "blade flora is on by default")
	var blades := bed.flora.blade_count()
	print("  blades %d  far level %d  glints %d  nodes %d  scatter tiles %d  build %d ms" % [blades, bed.flora.far_blade_count(),
			bed.flora.glint_count(), bed.flora.node_count(), bed.scatter.tile_count(), ms])
	check(blades > 20000, "a forest of blades (%d)" % blades)
	var cover := bed.flora.cover_added
	print("  phase 3 (cover, grass, tufts, fronds): %d blades, budget %d" % [cover, settings.flora_cover_budget])
	check(cover > 5000 and cover <= settings.flora_cover_budget + 64,  # a recipe in progress may finish past the cap
			 "ground cover, grass, tufts and fronds were laid (%d)" % cover)
	var lay := RuinCluster.layout(123)
	check(lay["width"] >= 13.0 and lay["depth"] >= 8.0 and lay["bases"].size() >= 0, "ruin layout replays the ruin's dice")
	var tight := UnnaturalSettings.new()
	tight.flora_cover_budget = 3000
	var bed4 := Seabed.new()
	add_child(bed4)
	bed4.setup(tight, 11, 20.0)
	check(bed4.flora.cover_added <= 3000 + 60, "the cover budget caps the blades (%d)" % bed4.flora.cover_added)
	var kelp_only := UnnaturalSettings.new()
	kelp_only.flora_cover_patches = 0
	kelp_only.flora_grass_clusters = 0
	kelp_only.flora_seagrass_blades = 0.0
	kelp_only.flora_rock_tufts = 0.0
	kelp_only.flora_wall_tufts = 0.0
	kelp_only.flora_frond_clumps = 0.0
	kelp_only.flora_ruin_cover = 0.0
	var bed5 := Seabed.new()
	add_child(bed5)
	bed5.setup(kelp_only, 11, 20.0)
	check(bed5.flora.cover_added == 0 and bed5.flora.blade_count() < blades, "all phase 3 settings at zero: kelp only (%d)" % bed5.flora.blade_count())
	bed4.queue_free()
	bed5.queue_free()
	check(bed.flora.draw_distance > 0.0, "draw distance follows the murk (%.0f m)" % bed.flora.draw_distance)
	bed.clear_around(bed.global_position + Vector3(0, 0, 0), 14.0)
	check(bed.flora.blade_count() <= blades, "clear_around on the seabed")
	bed.queue_free()
	await get_tree().process_frame

	var half := UnnaturalSettings.new()
	half.flora_blade_mult = 0.5
	var bed2 := Seabed.new()
	add_child(bed2)
	bed2.setup(half, 11, 20.0)
	var halved := bed2.flora.blade_count()
	print("  blade multiplier 0.5: %d blades" % halved)
	check(halved < blades * 0.6 and halved > blades * 0.4, "blade multiplier scales the count")
	bed2.queue_free()
	await get_tree().process_frame

	var old := UnnaturalSettings.new()
	old.flora_blades = false
	var bed3 := Seabed.new()
	add_child(bed3)
	bed3.setup(old, 11, 20.0)
	check(bed3.flora == null and bed3.scatter.count() > 0, "flag off: the old kelp meshes (no flora)")
	bed3.queue_free()
	await get_tree().process_frame
	print("ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)
