extends Node
func _ready() -> void:
	var o := OctopusModel.build(1.0)
	add_child(o)
	print("unit %.4f" % o.unit)
	print("mantle tip %s" % str(o.mantle_tip_local()))
	print("mouth %s siphon mouth %s exhaust %s" % [str(o.mouth_local()), str(o.siphon_mouth_local()), str(o.siphon_exhaust_dir())])
	for a in 8:
		var j := o.arm_rest_joints(a)
		print("arm %d base %s tip %s len %.3f seg3 %.4f" % [a, str(j[0] / o.unit), str(j[14] / o.unit), o.arm_length(a), o.arm_segment_length(a, 3)])
	get_tree().quit()
