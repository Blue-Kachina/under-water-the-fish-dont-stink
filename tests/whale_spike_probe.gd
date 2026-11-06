extends Node
## Marco Polo whales (planning_marco_whales.md) Phase 0, the spike: the Titans
## class exists and is hidden from the pickers; every hider class's model length
## (what whale_length defaults from); a whale seeker is the Titans class at body
## scale (hitbox, model, camera) with the whale's handling; tags; walls in the
## Ocean, the Sunken Temple and the Aquarium (spawn clear, no stuck or exploding
## body); the role swap back to a hider's own class.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/whale_spike_probe.tscn

const TICKS := 120

var main: Node
var mp: MarcoPoloSettings
var failures := 0
var _input := FishInput.new()


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	mp = MarcoPoloSettings.shared()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	_class_checks()
	_lengths()
	mp.hide_time = 0.5
	mp.round_time = 120.0
	mp.round_over_time = 0.5
	mp.min_players = 4
	mp.rounds = 0
	mp.bot_seeker_rounds = 0
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	for length: float in [0.0, 10.4]:  # the class's own 6.7 m, then 5x the longest hider model (2.08 m)
		mp.whale_length = length
		print("=== whale_length %s ===" % ("the class's (6.7 m)" if length == 0.0 else "%.1f m" % length))
		for arena_name in ["Ocean", "Sunken Temple", "Aquarium"]:
			await _arena(arena_name)
	print("whale_spike_probe: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _class_checks() -> void:
	print("the Titans class:")
	var titan := FishCharacter.FishClass.TITAN
	check(FishCharacter.CLASSES.has(titan) and FishCharacter.CLASSES[titan].key == "titan", "TITAN is in the class table, key titan")
	check(FishCharacter.from_key("titan") == titan, "from_key finds it")
	check(FishCharacter.species_count(titan) == 5, "five species")
	var keys: Array = []
	for i in 5:
		keys.append(FishCharacter.species_key(titan, i))
	check(keys == ["humpback", "orca", "beluga", "sperm", "blue"], "species keys %s" % [keys])
	check(not FishCharacter.pickable_classes().has(titan) and FishCharacter.pickable_classes().size() == FishCharacter.CLASSES.size() - 1,
			"hidden from the pickers (%d pickable of %d)" % [FishCharacter.pickable_classes().size(), FishCharacter.CLASSES.size()])


## Every pickable class's model length (the AABB of its meshes, along Z) next to its hitbox's.
func _lengths() -> void:
	print("hider lengths (m, model / hitbox):")
	var longest := 0.0
	var longest_hitbox := 0.0
	for fish_class: FishCharacter.FishClass in FishCharacter.pickable_classes():
		var worst := 0.0
		for species in FishCharacter.species_count(fish_class):
			var model := FishModel.build(fish_class, species)
			add_child(model)
			worst = maxf(worst, _extent(model, Transform3D.IDENTITY).size.z)
			model.queue_free()
		var hitbox := FishCharacter.hitbox_size(fish_class).z
		print("    %-12s model %.2f  hitbox %.2f" % [FishCharacter.CLASSES[fish_class].key, worst, hitbox])
		longest = maxf(longest, worst)
		longest_hitbox = maxf(longest_hitbox, hitbox)
	var titan_length := FishCharacter.hitbox_size(FishCharacter.FishClass.TITAN).z
	print("    longest model %.2f m, longest hitbox %.2f m; the Titan class is %.2f m (%.1fx the model, %.1fx the hitbox)" % [
			longest, longest_hitbox, titan_length, titan_length / longest, titan_length / longest_hitbox])
	check(titan_length >= 4.0 * longest_hitbox, "the Titan is at least 4x the longest hider hitbox")


func _extent(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := xform
	if node is Node3D and node != self:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = here * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var sub := _extent(child, here)
		if sub.size == Vector3.ZERO and sub.position == Vector3.ZERO:
			continue
		box = sub if first else box.merge(sub)
		first = false
	return box


func _arena(arena_name: String) -> void:
	print("%s:" % arena_name)
	mp.arena = arena_name
	if main.marco_polo:
		main.set_mode(main.FREE_SWIM)
		await _ticks(3)
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	var fish: FishController = main.get_node("Fish")
	var camera: Node3D = main._camera
	if game == null:
		check(false, "the match started")
		return
	var titan := FishCharacter.FishClass.TITAN
	check(game.role_of(fish) == MarcoPoloMatch.Role.SEEKER and fish.character == titan, "the local seeker is a Titan (%s)" % FishCharacter.CLASSES[fish.character].key)
	var length := fish.hitbox_length
	check(is_equal_approx(fish.body_scale, game.whale_body_scale()) and length > 4.0,
			"body scale %.2f: hitbox %.2f x %.2f x %.2f m" % [fish.body_scale, fish.hitbox_width, fish.hitbox_height, fish.hitbox_length])
	var visual: Node3D = fish.get("_visual")
	check(visual != null and visual.scale.is_equal_approx(Vector3.ONE * fish.body_scale), "the model is scaled with it (%s)" % [visual.scale if visual else null])
	check(is_equal_approx(fish.hitbox_length, FishCharacter.hitbox_size(titan).z * fish.body_scale), "the hitbox is the class's x the body scale")
	var shape := fish.get_node("Collision").shape as BoxShape3D
	check(shape.size.is_equal_approx(Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length)), "the collision box follows (%s)" % [shape.size])
	check(fish.turn_scale < 1.0 and fish.top_speed_scale > 1.0 and fish.accel_scale < 1.0 and fish.boost_scale > 1.0, "whale handling: turn %.2f, top speed %.2f, accel %.2f, boost %.2f" % [
			fish.turn_scale, fish.top_speed_scale, fish.accel_scale, fish.boost_scale])
	check(game.uses_auto_marco(fish) and not game.marco(fish), "Marco! is automatic, the button does nothing")
	_spawn_clear(game, fish, arena_name)

	var wait := 0
	while game.phase != MarcoPoloMatch.Phase.LIVE and wait < 20 * TICKS:
		await _ticks(1)
		wait += 1
	check(game.phase == MarcoPoloMatch.Phase.LIVE, "the round goes live")
	# Hold the bots still so the walk is the whale's alone.
	for bot: Node in game.bots.values():
		bot.set_physics_process(false)
	for f in game.players:
		if f != fish:
			(f as FishController).controls = FishInput.new()
	fish.controls = _input
	await _ticks(3)
	await _cam_check(fish, camera)
	await _drive(fish, game, arena_name)
	await _tag_check(game, fish)

	print("%s: the swap back:" % arena_name)
	var hider: FishController = game.live_hiders()[0] if not game.live_hiders().is_empty() else null
	var base_class := fish.get_meta("mp_base_look", [fish.character, fish.species]) as Array
	mp.bot_seeker_rounds = 1
	mp.rounds = 2
	game.start_round(1)
	await _ticks(3)
	var now_seeker: FishController = game.seekers()[0]
	check(now_seeker != fish and fish.character == int(base_class[0]) and is_equal_approx(fish.body_scale, 1.0) and is_equal_approx(fish.turn_scale, 1.0),
			"the old seeker is its own fish again (class %s, body x%.2f)" % [FishCharacter.CLASSES[fish.character].key, fish.body_scale])
	check(now_seeker.character == titan, "the new seeker is the Titan")
	check(hider == null or hider.character != titan or hider == now_seeker, "no hider is a Titan")
	fish.controls = null


## The Titan's start and every hider's start clear of the arena's solids.
func _spawn_clear(game: MarcoPoloMatch, fish: FishController, arena_name: String) -> void:
	var space := fish.get_world_3d().direct_space_state
	var rids: Array[RID] = []
	for f in game.players:
		rids.append(f.get_rid())
	var box := BoxShape3D.new()
	box.size = Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = fish.global_transform
	query.exclude = rids
	query.collision_mask = fish.collision_mask
	var hits := space.intersect_shape(query, 8)
	check(hits.is_empty(), "the Titan's start is clear of solids (%d overlaps%s)" % [hits.size(), "" if hits.is_empty() else ": " + str((hits[0].collider as Node).name)])
	print("    (%s: the seeker's start %s)" % [arena_name, fish.global_position])


## The seeker camera sits outside the whale's body and well back.
func _cam_check(fish: FishController, camera: Node3D) -> void:
	await _ticks(TICKS)
	var local := fish.global_transform.affine_inverse() * camera.global_position
	var half := Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length) / 2.0
	var clearance := maxf(absf(local.x) - half.x, maxf(absf(local.y) - half.y, absf(local.z) - half.z))
	print("    camera %.1f m from the whale's centre, %.1f m behind its tail, %.1f up, %.1f m clear of the body" % [
			camera.global_position.distance_to(fish.global_position), local.z - half.z, local.y, clearance])
	check(clearance > 1.0, "the camera is outside the body (%.1f m clear)" % clearance)


## Swim and boost: speed against a fish's, then walls: is it stuck, flung, or through.
func _drive(fish: FishController, game: MarcoPoloMatch, arena_name: String) -> void:
	var start := fish.global_position
	var heading := -fish.global_basis.z
	_input.clear()
	_input.forward = 1.0
	_input.boost = true
	var top := 0.0
	var stuck_ticks := 0
	var worst_jump := 0.0
	var last := fish.global_position
	var bad := false
	for tick in TICKS * 8:
		await _ticks(1)
		var speed := fish.linear_velocity.length()
		top = maxf(top, speed)
		var step := fish.global_position.distance_to(last)
		worst_jump = maxf(worst_jump, step)
		last = fish.global_position
		if speed < 0.5 and tick > TICKS:
			stuck_ticks += 1
		if not fish.global_position.is_finite() or not fish.linear_velocity.is_finite():
			bad = true
			break
		# Steer away from a wall it's pressed against: a soft turn.
		_input.stick = Vector2(0.6, 0.0) if tick % 480 > 240 else Vector2.ZERO
	_input.clear()
	var cap := fish.max_boost_speed * fish.top_speed_scale
	print("    drove %.1f m in 8 s, top speed %.1f m/s (cap %.1f), biggest step %.2f m, %d stuck ticks" % [
			start.distance_to(fish.global_position), top, cap, worst_jump, stuck_ticks])
	check(not bad, "no NaN positions or velocities")
	check(worst_jump < 1.0, "no teleporting (%.2f m in a tick)" % worst_jump)
	check(top <= cap * 1.1 and top > 1.0, "speed within its cap (%.1f of %.1f)" % [top, cap])
	check(stuck_ticks < TICKS * 3, "it isn't wedged (%d stuck ticks of %d)" % [stuck_ticks, TICKS * 7])
	await _ticks(TICKS / 2)


## A hider put in front of the whale's nose is tagged.
func _tag_check(game: MarcoPoloMatch, fish: FishController) -> void:
	var victim: FishController = game.live_hiders()[0]
	victim.freeze = true
	var ahead := -fish.global_basis.z * (fish.hitbox_length * 0.5 + 0.3)
	victim.global_position = fish.global_position + ahead
	fish.linear_velocity = Vector3.ZERO
	var before := game.live_hiders().size()
	await _ticks(TICKS / 2)
	victim.freeze = false
	check(game.live_hiders().size() == before - 1 or game.phase != MarcoPoloMatch.Phase.LIVE, "a hider at its nose is tagged (%d live of %d)" % [game.live_hiders().size(), before])


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
