## OctopusModel (C1): the Ember Octopus body. Checks: structure and bone layout, size, skinning weights, mesh budgets, pose setters
## (direction of the bends, return to rest, smooth steps, extreme poses stay finite), mantle pulse and bend, arm separation at rest,
## read-back matches the skeleton, siphon, shader uniforms, LOD, and that the shader parses.
##   Godot_console.exe --headless --path . res://tests/octopus_model_probe.tscn
extends Node

var checks := 0
var failures := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


## The mesh's vertices skinned on the CPU with the skeleton's current pose.
func _skinned(octo: OctopusModel, mi: MeshInstance3D) -> PackedVector3Array:
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skel := octo.skeleton
	var xf: Array[Transform3D] = []
	for i in skel.get_bone_count():
		xf.append(skel.get_bone_global_pose(i) * skel.get_bone_global_rest(i).affine_inverse())
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		for q in 4:
			var w := weights[v * 4 + q]
			if w > 0.0:
				p += (xf[bones[v * 4 + q]] * verts[v]) * w
		out[v] = p
	return out


func _bounds(pts: PackedVector3Array) -> AABB:
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box


func _finite(pts: PackedVector3Array) -> bool:
	for p in pts:
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			return false
	return true


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	var octo := OctopusModel.build(1.0)
	var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	add_child(octo)
	print("build %.1f ms" % build_ms)
	_structure(octo)
	_size_and_budget(octo)
	_weights(octo)
	_poses(octo)
	_mantle(octo)
	_separation(octo)
	_readback(octo)
	_uniforms(octo)
	_idle_run(octo)
	var big := OctopusModel.build(6.0, 11)
	add_child(big)
	var box := _bounds(_skinned(big, big.body_mesh))
	_check(absf(box.size.z - 6.0) < 0.5, "a 6 m octopus is about 6 m long (%.2f)" % box.size.z)
	_check(big.arm_segment_length(0, 3) > 5.0 * octo.arm_segment_length(0, 3), "segment lengths scale with size")
	print("%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _structure(o: OctopusModel) -> void:
	_check(o.skeleton.get_bone_count() == 6 + 8 * 14, "118 bones (%d)" % o.skeleton.get_bone_count())
	_check(o.arm_bones.size() == 8, "8 arms")
	var all14 := true
	for a in 8:
		var chain: PackedInt32Array = o.arm_bones[a]
		all14 = all14 and chain.size() == 14
		for j in 14:
			all14 = all14 and chain[j] == 6 + a * 14 + j
			if j > 0:
				all14 = all14 and o.skeleton.get_bone_parent(chain[j]) == chain[j - 1]
		all14 = all14 and o.skeleton.get_bone_parent(chain[0]) == OctopusModel.HEAD_BONE
	_check(all14, "arm_bones[arm][segment] = 6 + arm*14 + segment, chained under the head")
	_check(o.mantle_bones.size() == 4 and o.skeleton.get_bone_parent(o.mantle_bones[0]) == 0, "4 mantle bones chained from the root")
	_check(o.arm_tips.size() == 8 and o.arm_tips[3] != null, "8 arm tip nodes")
	_check(o.eyes.size() == 2 and o.siphon != null and o.siphon_mouth != null, "eyes, siphon, siphon mouth")
	_check(o.has_meta("hunter_octopus"), "meta hunter_octopus")
	var bound := true
	for mi: MeshInstance3D in [o.body_mesh, o.web_mesh, o.sucker_mesh, o.sucker_mesh_lo]:
		bound = bound and mi.skeleton == NodePath("..") and mi.get_node_or_null(mi.skeleton) == o.skeleton and mi.skin != null
	_check(bound, "every skinned mesh is bound to the skeleton (skeleton path set, skin set)")
	_check(o.materials.size() == 4, "four materials")
	var found := false
	for u in o.materials[0].shader.get_shader_uniform_list():
		if u["name"] == "mantle_pulse":
			found = true
	_check(found, "the skin shader parses and exposes mantle_pulse")
	var angles_ok := true
	for a in 8:
		angles_ok = angles_ok and absf(OctopusModel.arm_angle(a) - deg_to_rad(22.5 + 45.0 * a)) < 1e-5
		angles_ok = angles_ok and OctopusModel.arm_side(a) == (1 if a in [0, 1, 6, 7] else -1)
	_check(angles_ok, "arm angles and sides")
	_check(o.sucker_mesh_lo.visibility_range_end > 6.9 and o.sucker_mesh.visibility_range_end > 2.9 and o.sucker_mesh_lo.visibility_range_begin > 2.9, "suckers have hi and lo visibility ranges (%.1f %.1f)" % [o.sucker_mesh.visibility_range_end, o.sucker_mesh_lo.visibility_range_end])


func _size_and_budget(o: OctopusModel) -> void:
	var box := _bounds(_skinned(o, o.body_mesh))
	_check(absf(box.size.z - 1.0) < 0.06, "rest extent along Z is length_m (%.3f)" % box.size.z)
	_check(box.position.z < -0.3 and box.end.z > 0.5, "mantle ahead (-Z), arms trailing behind (+Z): z %.2f .. %.2f" % [box.position.z, box.end.z])
	var tips_behind := true
	for a in 8:
		tips_behind = tips_behind and o.arm_rest_joints(a)[14].z > 0.3 * o.length_m
	_check(tips_behind, "every arm tip trails well behind the head")
	_check(box.size.x > box.size.y * 1.4, "the arms spread in a flat delta: wider than tall (%.2f x %.2f)" % [box.size.x, box.size.y])
	_check(box.size.x < 1.25 and box.size.y < 1.25, "not wider than long (%.2f x %.2f)" % [box.size.x, box.size.y])
	var counts := {"body": o.body_mesh, "web": o.web_mesh, "suckers": o.sucker_mesh, "suckers_lo": o.sucker_mesh_lo}
	var total_tris := 0
	for key: String in counts:
		var arrays: Array = (counts[key] as MeshInstance3D).mesh.surface_get_arrays(0)
		var verts: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var tris: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		total_tris += tris
		print("  %s: %d vertices, %d triangles" % [key, verts, tris])
	_check(total_tris < 140000, "triangle budget (%d)" % total_tris)
	var tip := o.mantle_tip_local()
	_check(absf(tip.z - OctopusModel.MANTLE_END * o.unit) < 0.01, "mantle_tip_local at rest is the mantle end (%.3f)" % tip.z)


func _weights(o: OctopusModel) -> void:
	var bad := 0
	var nbones := o.skeleton.get_bone_count()
	for mi: MeshInstance3D in [o.body_mesh, o.web_mesh, o.sucker_mesh, o.sucker_mesh_lo]:
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts.size():
			var sum := 0.0
			for q in 4:
				sum += weights[v * 4 + q]
				if bones[v * 4 + q] < 0 or bones[v * 4 + q] >= nbones:
					bad += 1
			if absf(sum - 1.0) > 1e-3:
				bad += 1
	_check(bad == 0, "every vertex has 4 valid bones and weights summing to 1 (%d bad)" % bad)


func _poses(o: OctopusModel) -> void:
	o.reset_pose()
	var rest_tip := o.arm_tip_local(2)
	var bends := PackedVector3Array()
	bends.resize(14)
	for j in 14:
		bends[j] = Vector3(0.15, 0.0, 0.0)
	o.set_arm_pose(2, bends)
	var tip := o.arm_tip_local(2)
	var frame := o.arm_bone_transform(2, 0)
	var oral := frame.basis.y
	_check((tip - rest_tip).dot(oral) > 0.02, "positive pitch curls toward the sucker side (%.3f)" % (tip - rest_tip).dot(oral))
	_check(o.arm_tip_local(5).distance_to(o.arm_rest_joints(5)[14]) < 1e-3, "other arms untouched")
	for j in 14:
		bends[j] = Vector3(0.0, 0.15, 0.0)
	o.set_arm_pose(2, bends)
	var yawed := o.arm_tip_local(2)
	_check((yawed - rest_tip).dot(-frame.basis.x) > 0.02, "positive yaw bends toward local -X (%.3f)" % (yawed - rest_tip).dot(-frame.basis.x))
	o.clear_arm_pose(2)
	_check(o.arm_tip_local(2).distance_to(rest_tip) < 1e-4, "clear_arm_pose returns to rest")
	# Smoothness: a slowly growing curl moves the tip in small, even steps.
	var last := rest_tip
	var worst := 0.0
	for i in 60:
		var c := 0.002 * float(i)
		for j in 14:
			bends[j] = Vector3(c, c * 0.5, 0.0)
		o.set_arm_pose(4, bends)
		var now := o.arm_tip_local(4)
		if i > 0:
			worst = maxf(worst, now.distance_to(last))
		last = now
	_check(worst < 0.02, "tiny bend steps give tiny tip steps (worst %.4f)" % worst)
	o.set_arm_bend(0, 5, 0.3, 0.0)
	_check(o.arm_joints(0)[6].distance_to(o.arm_rest_joints(0)[6]) > 0.005, "set_arm_bend moves later joints")
	o.reset_pose()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for trial in 40:
		for a in 8:
			for j in 14:
				bends[j] = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
			o.set_arm_pose(a, bends)
	var skinned := _skinned(o, o.body_mesh)
	_check(_finite(skinned), "extreme random poses stay finite")
	_check(_bounds(skinned).size.length() < 8.0, "extreme random poses stay bounded (%.2f)" % _bounds(skinned).size.length())
	o.reset_pose()
	var mantle_rest := o.mantle_tip_local()
	o.set_head_basis(Basis(Vector3.UP, 0.5))
	_check(o.arm_tip_local(0).distance_to(o.arm_rest_joints(0)[14]) > 0.1, "head basis carries the arms")
	_check(o.mantle_tip_local().distance_to(mantle_rest) < 1e-4, "head basis leaves the mantle alone")
	o.reset_pose()


func _mantle(o: OctopusModel) -> void:
	o.reset_pose()
	var mid_z := -0.34 * o.unit
	var rest_w := _mantle_width(o, mid_z)
	o.set_mantle_pulse(1.0)
	var squeezed := _mantle_width(o, mid_z)
	o.set_mantle_pulse(-1.0)
	var swollen := _mantle_width(o, mid_z)
	o.set_mantle_pulse(0.0)
	var back := _mantle_width(o, mid_z)
	_check(squeezed < rest_w * 0.86 and squeezed > rest_w * 0.65, "pulse +1 narrows the mantle %.3f -> %.3f" % [rest_w, squeezed])
	_check(swollen > rest_w * 1.07, "pulse -1 swells it (%.3f)" % swollen)
	_check(absf(back - rest_w) < 1e-4, "pulse 0 is rest")
	o.set_mantle_bend(0.4, 0.0)
	var tip := o.mantle_tip_local()
	_check(absf(tip.x) > 0.04, "mantle yaw swings the tip sideways (%.3f)" % tip.x)
	o.set_mantle_bend(0.0, 0.3)
	_check(absf(o.mantle_tip_local().y - tip.y) > 0.02, "mantle pitch lifts or drops the tip")
	_check(_finite(_skinned(o, o.body_mesh)), "bent mantle finite")
	o.reset_pose()


func _mantle_width(o: OctopusModel, mid_z: float) -> float:
	var best := 0.0
	for p in _skinned(o, o.body_mesh):
		if absf(p.z - mid_z) < 0.03 * o.unit and p.z < 0.0:
			best = maxf(best, absf(p.x))
	return best


func _separation(o: OctopusModel) -> void:
	o.reset_pose()
	var worst := 99.0
	var worst_pair := ""
	for a in 8:
		for b in range(a + 1, 8):
			var pa: PackedVector3Array = o._arm_dense[a]
			var pb: PackedVector3Array = o._arm_dense[b]
			var ra: PackedFloat32Array = o._arm_radii[a]
			var rb: PackedFloat32Array = o._arm_radii[b]
			for i in range(18, pa.size(), 2):
				for j in range(maxi(i - 8, 18), mini(i + 8, pb.size()), 2):
					var gap := pa[i].distance_to(pb[j]) - (ra[i] + rb[j])
					if gap < worst:
						worst = gap
						worst_pair = "%d-%d" % [a, b]
	_check(worst > -0.4 * 0.047 * o.unit, "arms do not cut through each other past the base (worst gap %.4f m, pair %s)" % [worst, worst_pair])


func _readback(o: OctopusModel) -> void:
	o.reset_pose()
	var worst := 0.0
	for a in 8:
		var j := o.arm_joints(a)
		var r := o.arm_rest_joints(a)
		for i in 15:
			worst = maxf(worst, j[i].distance_to(r[i]))
	_check(worst < 1e-4, "arm_joints at rest equals arm_rest_joints (%.6f)" % worst)
	_check(o.arm_length(1) > 0.4 * o.length_m and o.arm_length(1) < 1.2 * o.length_m, "arms are about half to one body long (%.2f)" % o.arm_length(1))
	_check(o.arm_tips[2].position.distance_to(o._arm_tip_offset[2]) < 1e-5, "tip node sits at the tip offset")
	var dir := o.siphon_exhaust_dir()
	_check(dir.z > 0.9 and dir.y < 0.0, "siphon exhaust points back and slightly down (%s)" % str(dir))
	o.set_siphon_aim(0.5, 0.0)
	_check(o.siphon_exhaust_dir().distance_to(dir) > 0.2, "siphon aim vectors the jet")
	o.set_siphon_aim(0.0, 0.0)
	_check(o.siphon_exhaust_dir().distance_to(dir) < 1e-4, "siphon aim 0,0 is rest")
	_check(o.siphon_mouth_local().z > 0.05 * o.unit, "siphon mouth is behind the head")
	_check(o.mouth_local().z > 0.06 * o.unit and absf(o.mouth_local().y) < 0.03 * o.unit, "mouth (beak) is behind the head at the arms' junction")
	var gl := o.arm_tip_global(1)
	_check(gl.distance_to(o.global_transform * o.arm_tip_local(1)) < 1e-6, "arm_tip_global")


func _uniforms(o: OctopusModel) -> void:
	o.set_charge(0.7)
	o.set_stroke(0.4)
	o.set_vein_travel(0.3)
	o.set_flash(0.2)
	o.set_arm_glow(6, 1.5)
	o.set_arm_glow(1, 0.5)
	var ok := true
	for m in o.materials:
		ok = ok and absf(float(m.get_shader_parameter("charge")) - 0.7) < 1e-5 and absf(float(m.get_shader_parameter("stroke")) - 0.4) < 1e-5
		ok = ok and absf(float(m.get_shader_parameter("vein_travel")) - 0.3) < 1e-5
		var b: Vector4 = m.get_shader_parameter("arm_glow_b")
		var a: Vector4 = m.get_shader_parameter("arm_glow_a")
		ok = ok and absf(b.z - 1.5) < 1e-5 and absf(a.y - 0.5) < 1e-5
	_check(ok, "uniform setters reach every material")
	o.set_mantle_pulse(0.5)
	_check(absf(float(o.materials[0].get_shader_parameter("mantle_pulse")) - 0.5) < 1e-5, "mantle pulse drives the shader uniform")
	o.reset_pose()
	_check(float(o.materials[0].get_shader_parameter("charge")) == 0.0 and float(o.materials[2].get_shader_parameter("vein_travel")) < 0.0, "reset_pose resets drivers")
	o.set_detail(false)
	_check(not o.sucker_mesh.visible and not o.sucker_mesh_lo.visible and not o.web_mesh.visible, "set_detail(false) hides suckers and webs")
	o.set_detail(true)
	o.sucker_range_lengths = 0.0
	_check(o.sucker_mesh_lo.visibility_range_end == 0.0, "sucker_range_lengths 0 is always on")
	o.sucker_range_lengths = 7.0


func _idle_run(o: OctopusModel) -> void:
	var worst := 0.0
	var worst_step := 0.0
	var last := o.arm_tip_local(1)
	for f in 600:
		if f == 1:
			last = o.arm_tip_local(1)
		o.idle_pose(float(f) / 60.0)
		var tip := o.arm_tip_local(1)
		worst = maxf(worst, tip.distance_to(o.arm_rest_joints(1)[14]))
		worst_step = maxf(worst_step, tip.distance_to(last))
		last = tip
	_check(worst < 0.5 * o.length_m, "idle pose stays near rest (%.3f)" % worst)
	_check(worst_step < 0.05 * o.length_m, "idle pose moves smoothly frame to frame (%.4f)" % worst_step)
	o.reset_pose()
