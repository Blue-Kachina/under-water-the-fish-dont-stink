extends Node
## Solver round trip on the new rest: random-ish shapes from the mouth forward, joints -> bends -> forward joints.
func _ready() -> void:
	var octo := OctopusModel.build(6.0)
	add_child(octo)
	var worst := 0.0
	for arm in 8:
		var rest := octo.arm_rest_joints(arm)
		var base := rest[0]
		var L := octo.arm_length(arm)
		for case_i in 4:
			# a curve from the base swinging round to aim ahead (-Z): case 0 straight back (rest-ish), 1 sideways, 2 ahead, 3 ahead+up
			var aim: Vector3 = [Vector3(0, 0, 1), Vector3(signf(base.x + 0.001), 0, 0.2), Vector3(0.1 * signf(base.x + 0.001), 0, -1), Vector3(0, 0.6, -1)][case_i].normalized()
			var joints := PackedVector3Array()
			joints.append(base)
			var p := base
			var d0 := (rest[1] - rest[0]).normalized()
			for j in 14:
				var t := float(j + 1) / 14.0
				var d := d0.slerp(aim, minf(t * 3.0, 1.0)).normalized()
				p += d * octo.arm_segment_length(arm, j)
				joints.append(p)
			var res: Dictionary = WhipAttack.Solver.solve(octo, arm, joints)
			octo.set_arm_pose(arm, res["bends"])
			WhipAttack.Solver.apply_stretch(octo, arm, res["stretch"])
			var err := octo.arm_tip_local(arm).distance_to(joints[14]) / L
			worst = maxf(worst, err)
			print("arm %d case %d tip err %.3f" % [arm, case_i, err])
			octo.clear_arm_pose(arm)
			WhipAttack.Solver.apply_stretch(octo, arm, PackedFloat32Array())
	print("WORST %.3f" % worst)
	get_tree().quit()
