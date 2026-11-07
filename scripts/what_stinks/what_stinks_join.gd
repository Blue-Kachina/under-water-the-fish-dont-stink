class_name WhatStinksJoin
extends Node
## Joining a school in What Stinks? (what_stinks.md section 5). A prey fish
## within join_radius of a school (of its own class, unless join_any_class) can
## join it: the school hands it a place (School.claim, a real school fish), eases
## it in over join_ease and from then on writes its transform, so it swims in
## lockstep. The controller only reads: the stick leans the place (join_lean m),
## a button Leaves (a dash out, loud, a fresh start for its echo, and a
## rejoin_cooldown), another Spooks (one per round: the whole school bolts and
## re-forms, every fish's echo in it reset).
##
## The fish adopts the school's look: its own model hides and the school fish it
## stands in for shows (so the Hunter can't tell it from the rest); it's frozen
## and out of collisions while joined. Other prey (and the player) see ally
## markers; the Hunter's name plates are hidden by the match (shows_plate).
##
## Host-judged and deterministic for the net: the host picks places
## (join/leave/spook are the host's calls; a guest applies what it's told with
## join(fish, school, index)), and the school's own sim does the rest.

signal joined(fish: FishController, school: School, index: int)
## `loud`: the leave was a dash (leave_noise's worth, for the noise meter).
signal left(fish: FishController, loud: bool)
signal spooked(fish: FishController, school: School)
## A fish's echo goes back to 0 (it left, or its school was spooked). Phase 3's
## echo meter listens; `echo` below is only the placeholder it will replace.
signal echo_reset(fish: FishController)
## A guest: our own player pressed a button (action "join" with a school id and place, "leave", "spook"); the host judges it.
signal requested(action: String, school_id: int, index: int)

const MARKER_OWN := Color(1.0, 0.9, 0.35)
const MARKER_ALLY := Color(0.4, 1.0, 0.55)
const MARKER_HEIGHT := 1.1
const BUTTON_NAMES := {"jump": "Jump", "boost": "Boost", "powerslide": "Powerslide", "air_roll": "Air roll"}

var game: WhatStinksMatch
var settings := WhatStinksSettings.shared()
## fish -> the School it's in.
var schools := {}
## fish -> seconds until it may join again.
var cooldown := {}
## fish -> spooks left this round.
var charges := {}
## fish -> echo (0..1), a placeholder until Phase 3's echo meter; only ever reset here.
var echo := {}
## Loud leaves so far this round (fish -> count), for the noise meter and probes.
var loud_leaves := {}

var _saved := {}
var _markers := {}
var _marker_mesh: SphereMesh


func bind(match_node: WhatStinksMatch) -> void:
	game = match_node
	_marker_mesh = SphereMesh.new()
	_marker_mesh.radius = 0.28
	_marker_mesh.height = 0.56
	_marker_mesh.radial_segments = 8
	_marker_mesh.rings = 4


# --- Asking -------------------------------------------------------------------

func is_joined(fish: FishController) -> bool:
	return schools.has(fish)


func school_of(fish: FishController) -> School:
	return schools.get(fish)


## The class a school has to be for `fish` to join it (its own, off a Hunter's form).
func class_of(fish: FishController) -> FishCharacter.FishClass:
	if bool(fish.get_meta("ws_swapped", false)):
		return int((fish.get_meta("ws_base_look") as Array)[0]) as FishCharacter.FishClass
	return fish.character


func eligible(fish: FishController, school: School) -> bool:
	return settings.join_any_class or school.character == class_of(fish)


## Whether `fish` may join at all now: live prey, in a round that's on (the
## countdown too: that's when the prey find a school), not in one, not cooling down.
func can_join(fish: FishController) -> bool:
	return game != null and is_instance_valid(fish) and game.is_live_prey(fish) and not is_joined(fish) \
			and game.phase in [WhatStinksMatch.Phase.COUNTDOWN, WhatStinksMatch.Phase.LIVE] \
			and float(cooldown.get(fish, 0.0)) <= 0.0


## The school within join_radius with a free fish nearest `fish` (and of a class
## it may join), or null.
func joinable_school(fish: FishController) -> School:
	if game == null or game.field == null:
		return null
	var best: School
	var best_gap := settings.join_radius
	for school in game.field.schools:
		if not eligible(fish, school):
			continue
		var index := school.nearest_free(fish.global_position)
		if index < 0:
			continue
		var gap := school.fish_position(index).distance_to(fish.global_position)
		if gap <= best_gap:
			best_gap = gap
			best = school
	return best


## The line the prey's HUD shows: what the buttons do now.
func prompt_for(fish: FishController) -> String:
	if game == null or not is_instance_valid(fish) or not game.is_live_prey(fish):
		return ""
	if is_joined(fish):
		var text := "%s  Leave" % BUTTON_NAMES.get(settings.leave_button, settings.leave_button)
		var left_over := int(charges.get(fish, 0))
		if left_over > 0 and game.phase == WhatStinksMatch.Phase.LIVE:
			text += "     %s  Spook (%d)" % [BUTTON_NAMES.get(settings.spook_button, settings.spook_button), left_over]
		return text
	if not can_join(fish):
		var wait := float(cooldown.get(fish, 0.0))
		return "Can join again in %d" % ceili(wait) if wait > 0.0 else ""
	var near := joinable_school(fish)
	if near != null:
		return "%s  Join %s" % [BUTTON_NAMES.get(settings.join_button, settings.join_button), near.display_name if near.display_name != "" else "the school"]
	return ""


## What a late guest needs to see who is where: [[fish, school id, index], ...].
func claims() -> Array:
	var out: Array = []
	for fish: FishController in schools:
		var school: School = schools[fish]
		out.append([fish, school.id, school.claim_of(fish)])
	return out


# --- Doing --------------------------------------------------------------------

## `fish` joins `school` (default the nearest it can), at place `index` (default
## the free fish nearest it). The host's call; a guest passes what the host chose.
## False if it can't.
func join(fish: FishController, school: School = null, index := -1, told := false) -> bool:
	if told:
		if not is_instance_valid(fish) or is_joined(fish) or school == null:
			return false  # the host already judged it
	elif not can_join(fish):
		return false
	elif school == null:
		school = joinable_school(fish)
		if school == null:
			return false
	elif not eligible(fish, school):
		return false
	var place := index
	if place >= 0:
		if not school.claim(place, fish, settings.join_ease, fish.global_position):
			return false
	else:
		place = school.claim_nearest(fish, fish.global_position, settings.join_ease)
		if place < 0:
			return false
	_attach(fish, school)
	joined.emit(fish, school, place)
	return true


## `fish` leaves its school: a dash out (`dash`), loud, its echo back to 0, and
## the rejoin cooldown. False if it wasn't in one.
func leave(fish: FishController, dash := true) -> bool:
	if not is_joined(fish):
		return false
	var school: School = schools[fish]
	var was := school.release_claim(fish)
	_detach(fish)
	cooldown[fish] = settings.rejoin_cooldown
	if not was.is_empty():
		fish.global_transform = Transform3D(was["basis"], was["position"])
		var out: Vector3 = (was["position"] as Vector3) - school.middle()
		if out.length_squared() < 0.0001:
			out = -(was["basis"] as Basis).z
		var velocity: Vector3 = was["velocity"]
		if dash:
			velocity += out.normalized() * settings.leave_speed
		fish.linear_velocity = velocity
	if dash:
		loud_leaves[fish] = int(loud_leaves.get(fish, 0)) + 1
	reset_echo(fish)
	left.emit(fish, dash)
	return true


## A joined player startles its school (one of its spooks): every fish bolts and
## re-forms, and every fish's echo in it resets. False with none left or not joined.
func spook(fish: FishController, told := false, rng_state: Variant = null) -> bool:
	if not is_joined(fish):
		return false
	if not told and (int(charges.get(fish, 0)) <= 0 or game.phase != WhatStinksMatch.Phase.LIVE):
		return false
	var school: School = schools[fish]
	charges[fish] = maxi(int(charges.get(fish, 0)) - 1, 0)
	if rng_state != null:
		school.rng.state = int(rng_state)  # the host's: the school bolts the same way here
	school.set_meta("ws_spook_state", school.rng.state)
	school.startle(settings.spook_strength, settings.spook_groups, settings.spook_reform)
	for other: FishController in schools:
		if schools[other] == school:
			reset_echo(other)
	spooked.emit(fish, school)
	return true


func reset_echo(fish: FishController) -> void:
	echo[fish] = 0.0
	echo_reset.emit(fish)


## A new round: everyone out (before the schools are rebuilt), charges and cooldowns fresh.
func begin_round(fish_list: Array[FishController]) -> void:
	clear()
	cooldown.clear()
	charges.clear()
	echo.clear()
	loud_leaves.clear()
	for fish in fish_list:
		charges[fish] = settings.spook_charges
		echo[fish] = 0.0


## Everyone out quietly (round start, end of the match).
func clear() -> void:
	for fish: FishController in schools.keys():
		var school: School = schools[fish]
		if is_instance_valid(school):
			school.release_claim(fish)
		_detach(fish)
	schools.clear()
	for marker: Variant in _markers.values():
		if is_instance_valid(marker):
			(marker as Node).queue_free()
	_markers.clear()


## Out without a word (a fish removed from the match).
func release(fish: FishController) -> void:
	if is_joined(fish):
		var school: School = schools[fish]
		if is_instance_valid(school):
			school.release_claim(fish)
		_detach(fish)
	cooldown.erase(fish)
	charges.erase(fish)
	echo.erase(fish)


func _attach(fish: FishController, school: School) -> void:
	schools[fish] = school
	if not school.claim_lost.is_connected(_on_claim_lost):
		school.claim_lost.connect(_on_claim_lost)
	_saved[fish] = {"layers": [fish.collision_layer, fish.collision_mask], "mode": fish.freeze_mode, "locked": fish.controls_locked}
	fish.collision_layer = 0
	fish.collision_mask = 0
	fish.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	fish.freeze = true
	fish.controls_locked = true
	fish.set_model_visible(false)  # the school fish it stands in for is what shows


func _detach(fish: FishController) -> void:
	schools.erase(fish)
	var saved: Dictionary = _saved.get(fish, {})
	_saved.erase(fish)
	if not is_instance_valid(fish):
		return
	if not saved.is_empty():
		var layers: Array = saved["layers"]
		fish.collision_layer = int(layers[0])
		fish.collision_mask = int(layers[1])
		fish.freeze_mode = saved["mode"]
		fish.controls_locked = bool(saved["locked"])
	fish.freeze = fish.puppet
	fish.set_model_visible(true)
	var marker: Variant = _markers.get(fish)
	if marker != null and is_instance_valid(marker):
		(marker as Node).queue_free()
	_markers.erase(fish)


## A joined fish's place was eaten or battered: it's out (no dash, no cooldown).
func _on_claim_lost(fish: FishController) -> void:
	if not is_joined(fish):
		return
	_detach(fish)
	reset_echo(fish)
	left.emit(fish, false)


# --- Each frame ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if game == null:
		return
	var local := game.local_fish()
	if is_instance_valid(local) and not game.bots.has(local) and not local.puppet and game.is_live_prey(local):
		var input: PlayerInput = local.input_source if local.input_source else PlayerInput.everyone()
		if is_joined(local):
			if input.just_pressed(StringName(settings.leave_button)):
				if game.authority:
					leave(local)
				else:
					requested.emit("leave", -1, -1)
			elif input.just_pressed(StringName(settings.spook_button)):
				if game.authority:
					spook(local)
				else:
					requested.emit("spook", -1, -1)
		elif input.just_pressed(StringName(settings.join_button)):
			if game.authority:
				join(local)
			else:
				_request_join(local)
	_update_markers()


func _physics_process(delta: float) -> void:
	if game == null:
		return
	for fish: FishController in cooldown.keys():
		cooldown[fish] = maxf(float(cooldown[fish]) - delta, 0.0)
	var local := game.local_fish()
	for fish: FishController in schools:
		var school: School = schools[fish]
		if fish == local and not game.bots.has(fish):
			var input: PlayerInput = fish.input_source if fish.input_source else PlayerInput.everyone()
			var stick := Vector2(input.raw_strength("stick_right") - input.raw_strength("stick_left"),
					input.raw_strength("stick_up") - input.raw_strength("stick_down"))
			school.set_lean(fish, stick, settings.join_lean)
	if settings.bots_join and game.authority:
		for fish: FishController in game.bots:
			if is_instance_valid(fish) and can_join(fish):
				var near := joinable_school(fish)
				if near != null:
					join(fish, near)


## Ally markers: over every joined prey fish, in the colour of an ally (the
## local player's own differs), for prey only; never the Hunter's view.
func _update_markers() -> void:
	var shown := settings.ally_markers and game.local_view_role() == WhatStinksMatch.Role.PREY
	for fish: FishController in schools:
		if not is_instance_valid(fish):
			continue
		var marker: MeshInstance3D = _markers.get(fish)
		if marker == null:
			marker = MeshInstance3D.new()
			marker.name = "Marker"
			marker.mesh = _marker_mesh
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test = true
			material.albedo_color = MARKER_OWN if fish == game.local_fish() else MARKER_ALLY
			marker.material_override = material
			add_child(marker)
			_markers[fish] = marker
		marker.visible = shown
		marker.global_position = fish.global_position + Vector3.UP * MARKER_HEIGHT * maxf(fish.body_scale, 0.1)


## A guest's Join press: the school and place it'd take, asked of the host.
func _request_join(fish: FishController) -> void:
	if not can_join(fish):
		return
	var school := joinable_school(fish)
	if school != null:
		requested.emit("join", school.id, school.nearest_free(fish.global_position))
