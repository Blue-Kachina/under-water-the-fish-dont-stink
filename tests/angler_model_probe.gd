## Lantern Angler model (D1): scripts/what_stinks/forms/angler_model.gd + shaders/angler_skin.gdshader, API in angler_contract.md.
## Builds it at 0.5x, 1x and 3x and checks the mesh budget and extents, the spine and rest pose, the jaw hinge maths and its clamps, the
## esca stalk spring chain (rest, response to a push, settling, constant segment lengths, no NaN), the esca light budget (cap, release,
## halo fallback), uniform pushes (jaw, esca, tail, fins), the translucent teeth copy of the skin, eyes, rebuild safety and determinism.
## Run headless: Godot_console.exe --headless --path . res://tests/angler_model_probe.tscn
## (Shaders do not compile headless: the look is checked with tests/angler_shots.tscn.)
extends Node3D

var checks := 0
var failures := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make(length: float, at := Vector3.ZERO) -> AnglerModel:
	var model := AnglerModel.new()
	add_child(model)
	model.global_position = at
	model.build(length)
	model.pose_straight(0.0, 0.0)
	return model


func _run() -> void:
	for length: float in [3.0, 6.0, 18.0]:
		await _size(length)
	await _jaw()
	await _stalk()
	await _lights()
	await _uniforms()
	await _rebuild()
	print("angler_model_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _size(length: float) -> void:
	print("length %.1f m:" % length)
	var model := _make(length)
	var k := length / 6.0
	var stats := model.mesh_stats()
	print("      vertices %d, triangles %d, teeth %d" % [stats["vertices"], stats["triangles"], stats["teeth"]])
	_check(int(stats["vertices"]) < 40000 and int(stats["vertices"]) > 5000, "vertex budget under 40k")
	_check(int(stats["teeth"]) >= 40, "needle teeth: %d" % int(stats["teeth"]))
	_check(model.body_node != null and model.teeth_node != null and model.rig.instances.size() == 2, "body and teeth meshes on the rig")
	var box := model.body_node.mesh.get_aabb()
	_check(box.end.z <= length + 0.05 * k and box.end.z >= length * 0.97, "tail reaches the body length (%.2f of %.2f)" % [box.end.z, length])
	_check(box.position.z >= -1.1 * k and box.position.z <= -0.2 * k, "the jaw and the lure stand past the snout (%.2f)" % box.position.z)
	_check(box.size.x > 3.0 * k and box.size.x < 9.0 * k, "width reads as a globe (%.2f)" % box.size.x)
	_check(box.size.y > 4.0 * k and box.size.y < 7.5 * k, "height with the stalk (%.2f)" % box.size.y)
	_check(model.rig.points[0].distance_to(Vector3.ZERO) < 0.001 and absf(model.rig.points[SpineRig.SPINE_N - 1].z - length) < 0.01 * length, "the spine runs from the head along +Z, %.2f m" % model.rig.points[SpineRig.SPINE_N - 1].z)
	_check(model.stalk_nodes.size() == 6 and model.eyes.size() == 2, "6 stalk nodes and 2 eyes")
	var left := model.eyes[0].global_position
	var right := model.eyes[1].global_position
	_check(absf(left.x + right.x) < 0.001 * length and left.x < 0.0 and absf(left.y - right.y) < 0.001 * length and absf(left.z - right.z) < 0.001 * length, "eyes mirror each other")
	_check(left.y > 0.4 * k and left.z > 0.5 * k and left.z < 1.6 * k, "eyes sit high on the head, a metre back (%s)" % left)
	_check(model.esca_world().y > 2.2 * k and model.esca_world().z < 0.2 * k, "the esca hangs over and ahead of the mouth (%s)" % model.esca_world())
	_check(model._place(model.esca_rest()).distance_to(model.esca_world()) < 0.001 * length, "esca_world at rest is esca_rest placed")
	_check(model.stalk_nodes[0].global_position.distance_to(model._place(AnglerModel.STALK_REST[0] * k)) < 0.002 * length, "stalk base node sits on the forehead")
	var mouth := model.mouth_world(0.0)
	_check(mouth.y < 0.3 * k and mouth.y > -1.2 * k and mouth.z > 0.4 * k and mouth.z < 1.8 * k, "the mouth point is inside the head's front (%s)" % mouth)
	model.queue_free()
	await _frames(1)


func _jaw() -> void:
	print("jaw:")
	var model := _make(6.0)
	model.jaw_open = 0.0
	var shut := model.mouth_world(0.0)
	var open := model.mouth_world(1.0)
	var wide := model.mouth_world(2.2)
	_check(open.y < shut.y - 0.3 and wide.y < open.y - 0.2, "the mouth point drops with jaw_open (%.2f, %.2f, %.2f)" % [shut.y, open.y, wide.y])
	# The hinge maths is what the shader does: a point at the hinge doesn't move, one in front of it swings down and back.
	var hinge := Vector3(0.0, AnglerModel.HINGE.x, AnglerModel.HINGE.y)
	_check(model._hinged(hinge, 1.2).distance_to(hinge) < 0.0001, "the hinge point stays put")
	var lip := Vector3(0.0, 0.0, 0.0)
	var dropped := model._hinged(lip, 0.9)
	_check(dropped.y < -1.0 and absf(dropped.distance_to(hinge) - lip.distance_to(hinge)) < 0.0001, "the lip swings about the hinge keeping its radius (y %.2f)" % dropped.y)
	model.jaw_open = 99.0
	_check(model.jaw_open <= (AnglerModel.MAX_JAW_ANGLE - AnglerModel.JAW_REST) / AnglerModel.GAPE_ANGLE + 0.0001, "jaw_open clamps at the widest (%.2f)" % model.jaw_open)
	model.jaw_open = -5.0
	_check(model.jaw_open >= -0.121 and AnglerModel._jaw_angle(model.jaw_open) >= -0.02, "jaw_open clamps shut tight")
	model.jaw_open = 2.0
	var hinge_param: Vector3 = model.skin.get_shader_parameter("hinge")
	var teeth_param: Vector3 = model.teeth_skin.get_shader_parameter("hinge")
	_check(is_equal_approx(hinge_param.z, AnglerModel._jaw_angle(2.0)) and hinge_param == teeth_param, "skin and teeth turn together (%.2f rad)" % hinge_param.z)
	_check(AnglerModel._jaw_angle(2.0) > 1.5 and AnglerModel._jaw_angle(1.0) > 0.9, "exaggerated gape: 1.0 is %.0f deg, 2.0 is %.0f deg" % [rad_to_deg(AnglerModel._jaw_angle(1.0)), rad_to_deg(AnglerModel._jaw_angle(2.0))])
	model.queue_free()
	await _frames(1)


func _stalk() -> void:
	print("stalk:")
	var model := _make(6.0)
	model.stalk_sway = 0.0
	var rest := model._stalk_rest.duplicate()
	for i in 120:
		model.update(1.0 / 60.0, Vector3.ZERO)
	var drift := 0.0
	for i in 6:
		drift = maxf(drift, model._stalk[i].distance_to(rest[i]))
	_check(drift < 0.001, "no push, no sway: the chain stays at rest (%.4f m)" % drift)
	# A hard push from the head's acceleration: the tip lags behind, within the rod's length.
	var peak := 0.0
	var worst_len := 0.0
	for i in 30:
		model.update(1.0 / 60.0, Vector3(0.0, 0.0, 60.0))
		peak = maxf(peak, model._stalk[5].distance_to(rest[5]))
	for i in range(1, 6):
		worst_len = maxf(worst_len, absf(model._stalk[i].distance_to(model._stalk[i - 1]) - model._stalk_len[i]))
	_check(peak > 0.15 and peak < 3.0, "a push swings the esca (%.2f m) but not off the rod" % peak)
	_check(worst_len < 0.002, "the rod keeps each segment's length (error %.5f m)" % worst_len)
	model.kick_stalk(Vector3(5.0, 0.0, 0.0))
	var kicked := 0.0
	for i in 20:
		model.update(1.0 / 60.0, Vector3.ZERO)
		kicked = maxf(kicked, absf(model._stalk[5].x - rest[5].x))
	_check(kicked > 0.05, "kick_stalk flicks the esca sideways (%.2f m)" % kicked)
	for i in 600:
		model.update(1.0 / 60.0, Vector3.ZERO)
	var settle := model._stalk[5].distance_to(rest[5])
	_check(settle < 0.02, "the chain settles back to rest (%.4f m after 10 s)" % settle)
	var finite := true
	for p in model._stalk:
		finite = finite and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
	_check(finite, "no NaN in the chain")
	model.update(1.0 / 60.0, Vector3.ZERO)
	_check(model.stalk_nodes[5].global_position.distance_to(model._place(model._stalk[5])) < 0.001, "the last stalk node follows the chain's end")
	var now: PackedVector3Array = model.skin.get_shader_parameter("stalk_now")
	_check(now.size() == 6 and now[5].distance_to(model._stalk[5]) < 0.0001, "the skin has the chain")
	for i in 5:
		model.update(0.5, Vector3(0.0, 80.0, 0.0))
	var bounded := true
	for p in model._stalk:
		bounded = bounded and p.length() < 20.0 and is_finite(p.x)
	_check(bounded, "half-second frames and huge pushes stay bounded")
	model.queue_free()
	await _frames(1)


func _lights() -> void:
	print("lights:")
	AnglerModel.light_cap = 2
	AnglerModel.lights_in_use = 0
	var models: Array[AnglerModel] = []
	for i in 4:
		models.append(_make(6.0, Vector3(float(i) * 20.0, 0.0, 0.0)))
	for m in models:
		m.update(1.0 / 60.0)
	var with_light := 0
	for m in models:
		if m.has_light():
			with_light += 1
	_check(with_light == 2 and AnglerModel.lights_in_use == 2, "cap 2 across 4 anglers: %d lights, %d in use" % [with_light, AnglerModel.lights_in_use])
	_check(models[3]._halo.visible and not models[3].has_light(), "the one over budget glows with its halo alone")
	models[0].queue_free()
	await _frames(2)
	models[3].update(1.0 / 60.0)
	_check(AnglerModel.lights_in_use == 2 and models[3].has_light(), "a freed light is handed to the next angler")
	models[1].light_enabled = false
	models[1].update(1.0 / 60.0)
	_check(not models[1].has_light(), "light_enabled false drops the light")
	models[2].esca_intensity = 0.0
	models[2].update(1.0 / 60.0)
	_check(not models[2].has_light() and not models[2]._halo.visible, "esca dark: no light, no halo")
	models[2].esca_intensity = 2.5
	models[2].update(1.0 / 60.0)
	var big := (models[2]._halo.mesh as QuadMesh).size.x
	models[2].esca_intensity = 1.0
	models[2].update(1.0 / 60.0)
	_check(big > (models[2]._halo.mesh as QuadMesh).size.x, "a flare grows the halo")
	AnglerModel.light_cap = 0
	for m in models:
		if is_instance_valid(m):
			m.update(1.0 / 60.0)
	_check(AnglerModel.lights_in_use == 0, "cap 0 releases every light (in use %d)" % AnglerModel.lights_in_use)
	for m in models:
		if is_instance_valid(m):
			m.queue_free()
	await _frames(2)
	_check(AnglerModel.lights_in_use == 0, "no light leaks with the models gone (%d)" % AnglerModel.lights_in_use)
	AnglerModel.light_cap = 6
	AnglerModel.lights_in_use = 0


func _uniforms() -> void:
	print("uniforms:")
	var model := _make(6.0)
	model.esca_intensity = 3.0
	model.esca_color = Color(1.0, 0.4, 0.2)
	_check(is_equal_approx(float(model.skin.get_shader_parameter("esca_intensity")), 3.0) and model.skin.get_shader_parameter("esca_color") == Color(1.0, 0.4, 0.2), "esca intensity and colour reach the skin")
	model.tail_bend = 0.7
	_check(is_equal_approx(float(model.skin.get_shader_parameter("tail_bend")), 0.7) and is_equal_approx(float(model.teeth_skin.get_shader_parameter("tail_bend")), 0.7), "tail_bend reaches both skins")
	model.set_pectoral(0.4, 0.2)
	_check(is_equal_approx(float(model.skin.get_shader_parameter("pect_flap_l")), 0.4) and is_equal_approx(float(model.skin.get_shader_parameter("pect_sweep")), 0.2), "pectoral flap and sweep")
	model.set_pectoral_sides(0.3, -0.3, 0.0)
	_check(is_equal_approx(float(model.skin.get_shader_parameter("pect_flap_r")), -0.3), "per-side flap for a roll")
	model.fin_flutter = 9.0
	_check(model.fin_flutter == 2.0, "fin_flutter clamps")
	model.eye_glint = 1.5
	var glow := float((model.eyes[0].material_override as ShaderMaterial).get_shader_parameter("glow"))
	_check(glow > 0.7, "eye_glint lights the eyes (%.2f)" % glow)
	_check(model.teeth_skin.shader != model.skin.shader and model.teeth_skin.shader.code.contains("ALPHA = ta;") and not model.skin.shader.code.contains("ALPHA = ta;"), "only the teeth's copy of the shader blends")
	_check(model.skin in model.rig.materials and model.teeth_skin in model.rig.materials, "both skins are fed the spine")
	model.rig.apply()
	var pos: PackedVector3Array = model.skin.get_shader_parameter("spine_pos")
	_check(pos.size() == SpineRig.SPINE_N and float(model.skin.get_shader_parameter("spine_length")) > 5.9, "the spine uniforms reach the skin")
	model.pose_straight(0.8, 0.0)
	_check(model.rig.points[0].distance_to(Vector3.ZERO) < 0.001 and absf(model.rig.points[SpineRig.SPINE_N - 1].x) > 0.4, "pose_straight(bend) curves the tail (x %.2f)" % model.rig.points[SpineRig.SPINE_N - 1].x)
	model.queue_free()
	await _frames(1)


func _rebuild() -> void:
	print("rebuild:")
	var model := _make(6.0)
	var first := model.mesh_stats()
	var box1 := model.body_node.mesh.get_aabb()
	model.build(6.0)
	model.pose_straight(0.0, 0.0)
	await _frames(2)
	var second := model.mesh_stats()
	_check(first["vertices"] == second["vertices"] and first["teeth"] == second["teeth"] and box1.is_equal_approx(model.body_node.mesh.get_aabb()), "building twice gives the same body")
	var live := 0
	for child in model.get_children():
		if child is MeshInstance3D:
			live += 1
	# Body, teeth, two eyes and the halo.
	_check(live == 5, "rebuild leaves one set of parts (%d mesh nodes)" % live)
	model.build(12.0)
	model.pose_straight(0.0, 0.0)
	await _frames(2)
	_check(absf(model.rig.length - 12.0) < 0.001 and model.body_node.mesh.get_aabb().end.z > 11.0, "a size change rebuilds at the new length")
	model.queue_free()
	await _frames(1)
