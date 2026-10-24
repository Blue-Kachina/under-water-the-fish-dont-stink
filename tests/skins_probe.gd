extends Node
## Every playable fish in every species (FishCharacter.SPECIES) builds a model the
## game can use: the swim pivots, a Body, a team tint, a swim that runs, a tail
## that stays on its body as it wags (FishModel._bend_body), a triangle count
## fit to draw up close, and a school/horde bake (SchoolLook).
##   Godot_console.exe --headless --path . res://tests/species_probe.tscn
## `-- --class=<key>` checks one class only.

## Most triangles a model may have (its parts all together).
const MAX_TRIANGLES := 40000
## Classes that needn't bend into a tail (no tail stalk to bend).
const NO_BEND := [FishCharacter.FishClass.DRIFTER, FishCharacter.FishClass.GLIDER]

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			only = arg.trim_prefix("--class=")
	for fish_class: FishCharacter.FishClass in FishCharacter.SPECIES:
		if only != "" and FishCharacter.CLASSES[fish_class].key != only:
			continue
		for species in FishCharacter.species_count(fish_class):
			_check_model(fish_class, species)
	print("species_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check_model(fish_class: FishCharacter.FishClass, species: int) -> void:
	var name := "%s / %s" % [FishCharacter.display_name(fish_class), FishCharacter.species_name(fish_class, species)]
	print(name + ":")
	var model := FishModel.build(fish_class, species)
	add_child(model)
	check(model.species == species, "wears species %d" % species)
	check(model.tail != null and model.fin_left != null and model.fin_right != null, "has its swim pivots")
	check(model.find_child("Body", true, false) is GeometryInstance3D, "has a Body")
	var triangles := _triangles(model)
	check(triangles <= MAX_TRIANGLES, "%d triangles (at most %d)" % [triangles, MAX_TRIANGLES])
	model.set_body_color(Color(0.1, 0.4, 1.0))
	check(model.body_color().is_equal_approx(Color(0.1, 0.4, 1.0)), "takes a team tint")
	model.reset_body_color()
	# Swim a moment with the tail swung, as the controller drives it.
	for i in 30:
		model.tail.rotation = Vector3(0.0, 0.8 * sin(i * 0.3), 0.0)
		model.react(1.0 / 60.0, Vector3(0.0, 0.0, -15.0))
	if not fish_class in NO_BEND:
		check(model._bend_span.y > model._bend_span.x, "bends into its tail")
	if model._bend_span.y > model._bend_span.x:
		model.tail.rotation = Vector3(0.0, 0.8, 0.0)
		model.apply_bend()
		var expected := model.bend_point(model._tail_rest)
		check(model.tail.position.is_equal_approx(expected) and absf(model.tail.position.x) > 0.005,
				"the tail pivot rides the bend (x %.3f m at 0.8 rad)" % model.tail.position.x)
		model.tail.rotation = Vector3.ZERO
		model.apply_bend()
		check(model.tail.position.is_equal_approx(model._tail_rest), "and comes back to rest")
	var baked := SchoolLook._bake(model)
	check(baked.get_surface_count() > 0, "bakes for schools and the horde")
	model.free()


## Triangles in every mesh part of `model`.
func _triangles(model: Node) -> int:
	var total := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
				total += (indices as PackedInt32Array).size() / 3
			else:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total
