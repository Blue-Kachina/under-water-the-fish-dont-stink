extends Node
func _ready() -> void:
	var rig := OctopusRig.new()
	add_child(rig)
	rig.build_model(6.0)
	rig.floor_query = func(_f: Vector3, _t: Vector3) -> Dictionary: return {}
	var line := "rest: "
	for a in 8:
		var p: Vector3 = rig.model.arm_rest_joints(a)[14]
		line += "%d(%.2f,%.2f,%.2f) " % [a, p.x, p.y, p.z]
	print(line)
	for mode in ["idle", "cruise", "jet"]:
		for i in 240:
			var c := {"throttle": 0.0, "vel": Vector3.ZERO}
			if mode == "cruise":
				c = {"throttle": 0.3, "vel": Vector3(0, 0, -3)}
			elif mode == "jet":
				c = {"throttle": 1.0, "vel": Vector3(0, 0, -7)}
			rig.step(1.0 / 60.0, c)
		line = mode + ": "
		for a in 8:
			var p := rig.model.arm_tip_local(a)
			line += "%d(%.2f,%.2f,%.2f) " % [a, p.x, p.y, p.z]
		print(line)
	get_tree().quit()
