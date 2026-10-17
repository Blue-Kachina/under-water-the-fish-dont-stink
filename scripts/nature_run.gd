class_name NatureRun
extends Node
## Nature mode in the Ocean: the players swim Extra Swishy (no boost) among
## schools of harmless fish (School) and after a calm lone fish (a WanderBot).
## Ramming the lone fish nose first at a player's nature_batter_speed or
## faster batters it: it explodes, the count goes up, and a moment later a new
## one turns up a little way off.
##
## Schools keep swimming around the players: settings.school_count of them
## (NatureSettings, live). One that strays past the leash from every player, or
## is wiped out, is replaced by a new one, out of every player's view. School
## fish batter the same way (fast, nose first, the bow wave counting), several
## in one pass if they're packed tight: each tick a small pool of hitboxes
## (SchoolFish.LAYER) is put on the fish near the players here, and one query
## per player (Battery.areas_touched) finds every one its front touches. Each
## costs that player a little speed (hit_speed_cost).
##
## Points (NatureScore, one per player): every battery scores, quick ones chain
## into multis and a run of them at speed is a spree. A battered fish may
## leave a pearl (Pearl), more likely deeper into a multi; pearls are drawn in
## and counted. The team's counts, and each player's share, are `rules`
## (CoopRules).
##
## Co-op: `players` are every player's fish, 1 to 4, in split-screen (all
## local) or online (others' are puppets, FishController.puppet, moved by the
## network). Players pass through each other. One machine has `authority` over
## the world (offline: this one; online: the host): it runs the schools'
## leaders and populations, the lone fish, pearl drops and the counts. A
## battery is seen first where the attacker is: it shows at once there
## (_claim_battery), scores for the attacker, and is confirmed by the
## authority (confirm_battery), which tells everyone (battery_confirmed). Two
## players hitting the same fish within SHARE_WINDOW both get the credit
## (nothing is ever taken back). Pearls are claimed and confirmed the same way.
## The *_claimed / *_confirmed / school_* / target_state signals are what an
## online session (CoopSession) sends; the apply_* and spawn_* methods are
## what it calls with what it receives.
##
## Each player's camera's ball cam looks at their own focus (focus_of()):
## whichever is nearest ahead of them of the lone fish and the schools' centres
## (pick_focus(), which main calls as ball cam goes on), picked again if it
## goes away, or chosen on the school wheel (set_focus(), TargetWheel).
## focus_changed says so.
##
## Lives under the Ocean (setup() before adding it). end() hands the players'
## fish back.

## A kickoff or respawn has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
signal battered(attacker: FishController, victim: FishController)
## A player's ball cam focus changed (null: nothing to look at).
signal focus_changed(focus: Node3D, fish: FishController)
## A school fish battered, where it was.
signal school_fish_battered(attacker: FishController, school: School, at: Vector3)
## Points scored (NatureScore's events: "battery", "multi", "spree"), with
## "by": the player's fish.
signal awarded(event: Dictionary)
## A pearl collected (confirmed).
signal pearl_collected(by: FishController)
## For an online session (see the class description). `key` names a battered
## fish: "s<school id>:<index>", or "t<generation>" for the lone fish.
signal school_spawned(school: School, at: Vector3, heading: Vector3)
signal school_removed(id: int)
signal battery_claimed(key: String, attacker: FishController, chain: int)
signal battery_confirmed(key: String, attackers: Array, at: Vector3, pearl_id: int)
signal battery_shared(key: String, attacker: FishController)
signal pearl_claimed(id: int, by: FishController)
signal pearl_confirmed(id: int, by: FishController)
## The authority started the run over (start()): everyone does the same.
signal restarted
## The authority moved the lone fish (a respawn), or took it away (present false).
signal target_state(present: bool, at: Transform3D, target_name: String, generation: int)

const FISH_SCENE := preload("res://scenes/fish.tscn")
## The lone fish first waits this far ahead of the players (m).
const FIRST_DISTANCE := 30.0
## Later ones turn up this far from the players (m), in any direction.
const RESPAWN_DISTANCE := Vector2(30.0, 50.0)
## Seconds between a battery and the next fish.
const RESPAWN_TIME := 1.5
## The target's colour (and its explosion's).
const TARGET_COLOR := Color(0.55, 0.95, 0.75)
const TARGET_NAMES := ["Wanda", "Gill", "Bubbles", "Finley", "Coral", "Squirt", "Nemo-ish", "Sardine Steve"]
## A wandering target further than this from every player (m) is brought back near them.
const LEASH := 150.0
## New schools (after the first ones) turn up outside this cone ahead of every
## player (cosine of its half-angle), so they don't pop in on screen.
const SPAWN_HIDDEN := 0.4
## Within this (m) of a player, past its own size and bow wave, school fish get hitboxes.
const HITBOX_RANGE := 4.0
## Two players' batteries on the same fish this close together (s, as the
## authority receives them) are one shared battery, credited to both.
const SHARE_WINDOW := 0.3
## Players spawn side by side, this far apart (m).
const SPAWN_SPACING := 3.0

var ocean: Node3D
## Every player's fish (see the class description); the first is `player`.
var players: Array[FishController] = []
var player: FishController
## This machine runs the world (offline, or the online host). Set before adding.
var authority := true
var settings := NatureSettings.shared()
## The world's dice (spawns, names, pearl drops), the authority's.
var rng := RandomNumberGenerator.new()
## The lone fish.
var target: FishController
var bot: WanderBot
var schools: Array[School] = []
## The team's counts and each player's share.
var rules := CoopRules.new()
## Fish battered by the team this run, and pearls collected.
var battered_fish: int:
	get:
		return rules.team_battered_fish
var pearls: int:
	get:
		return rules.team_pearls
## The first player's points (score_of() for anyone's).
var score: NatureScore:
	get:
		return score_of(player)
## What the first player's ball cam looks at: the lone fish or a school's centre.
var focus: Node3D:
	get:
		return focus_of(player)
## The speed of the last battery here (m/s), by anyone.
var last_battery_speed := 0.0
## Pearls still out.
var pearls_out: Array[Pearl] = []
var _respawn_left := -1.0
var _lone_target := true
## The lone fish's respawns so far (its batteries' keys carry it).
var _target_generation := 0
## Per school: seconds until it's replaced, once wiped out (-1: not yet).
var _school_respawn := {}
var _schools_by_id := {}
var _next_school_id := 0
## Per player (their fish): points, ball cam focus, and their last battery's speed.
var _scores := {}
var _focus := {}
var _battery_speed := {}
## Batteries confirmed: key -> {"time": ms, "attackers": [fish]}; and those shown
## here already (a claim waiting on the authority, or confirmed).
var _confirmed := {}
var _shown := {}
var _next_pearl_id := 0
var _pearls_by_id := {}
var _collected := {}
## The hitbox pool for school fish near the players, and which fish each is on
## ([school, index]).
var _hitboxes: Array[Area3D] = []
var _hitbox_fish := {}


func setup(nature_ocean: Node3D, player_fish: FishController) -> void:
	ocean = nature_ocean
	player = player_fish
	players = [player_fish]


func _ready() -> void:
	if authority:
		rng.randomize()
	for fish in players:
		_join(fish)
	target = FISH_SCENE.instantiate()
	target.name = "TargetFish"
	target.character = FishCharacter.Family.HYBRID
	target.display_name = TARGET_NAMES[rng.randi_range(0, TARGET_NAMES.size() - 1)]
	add_child(target)
	Match1v1.copy_tuning(player, target)
	target.swim_strokes = false  # it just cruises
	target.team_color = TARGET_COLOR
	if authority:
		bot = WanderBot.new()
		bot.name = "WanderBot"
		bot.fish = target
		bot.threat = player
		add_child(bot)
	else:
		target.make_puppet()  # where the host says (target_state, its snapshots)
	start()


## The players at the ocean's spawn, side by side, the lone fish waiting ahead
## of them and the schools around.
func start() -> void:
	if authority:
		restarted.emit()
	last_battery_speed = 0.0
	_respawn_left = -1.0
	rules.reset()
	for fish: FishController in _scores:
		(_scores[fish] as NatureScore).reset()
	_battery_speed.clear()
	_confirmed.clear()
	_shown.clear()
	_collected.clear()
	for pearl in pearls_out:
		if is_instance_valid(pearl):
			pearl.queue_free()
	pearls_out.clear()
	_pearls_by_id.clear()
	var spawn: Transform3D = ocean.spawn_transform()
	var moved: Array = []
	for fish in players:
		if not fish.puppet:
			fish.revive(spawn_for(fish, spawn))
			moved.append(fish)
	for school in schools:
		school.queue_free()
	schools.clear()
	_schools_by_id.clear()
	_school_respawn.clear()
	if authority:
		var ahead := -spawn.basis.z
		_lone_target = settings.lone_target
		if _lone_target:
			_place_target(spawn.origin + ahead * FIRST_DISTANCE, ahead)
		else:
			target.batter()
			target_state.emit(false, target.global_transform, target.display_name, _target_generation)
		moved.append(target)
		for i in settings.school_count:
			_add_school(spawn, i == 0)
	elif not target.battered:
		target.batter()  # until the host says where it is (target_state)
	_announce_teleport(moved)
	for fish in players:
		if not fish.puppet:
			pick_focus(fish)


## Just this machine's players back to the start (a guest's reset: the world
## is the host's to restart).
func respawn_local() -> void:
	var spawn: Transform3D = ocean.spawn_transform()
	var moved: Array = []
	for fish in local_players():
		fish.revive(spawn_for(fish, spawn))
		moved.append(fish)
	_announce_teleport(moved)


## Where `fish` starts a run: beside the others, in its co-op place
## (meta "coop_index", else its place in `players`).
func spawn_for(fish: FishController, spawn: Transform3D) -> Transform3D:
	var index: int = fish.get_meta("coop_index", maxi(players.find(fish), 0))
	var side := 0.0 if index == 0 else SPAWN_SPACING * ceilf(index / 2.0) * (1.0 if index % 2 == 1 else -1.0)
	return Transform3D(spawn.basis, spawn.origin + spawn.basis.x * side)


## Hands the players' fish back. Call before freeing the run.
func end() -> void:
	for fish in players.duplicate():
		_leave(fish)
		if is_instance_valid(fish) and not fish.puppet and fish.battered:
			fish.revive(fish.global_transform)


## Another player joins the run (a split-screen player, or online a remote
## player's puppet). Their fish should be in the tree already.
func add_player(fish: FishController) -> void:
	if fish in players:
		return
	players.append(fish)
	_join(fish)
	if not fish.puppet:
		var spawn: Transform3D = player.global_transform if is_instance_valid(player) else ocean.spawn_transform()
		fish.revive(spawn_for(fish, Transform3D(spawn.basis.orthonormalized(), spawn.origin)))
		pick_focus(fish)
		_announce_teleport([fish])


## A player leaves the run (their fish is theirs to free). Their share of the
## counts stays in the team's.
func remove_player(fish: FishController) -> void:
	if fish not in players or fish == player:
		return
	_leave(fish)
	players.erase(fish)
	_scores.erase(fish)
	_focus.erase(fish)
	_battery_speed.erase(fish)
	_refresh_threats()


## A player's points (NatureScore).
func score_of(fish: FishController) -> NatureScore:
	if not _scores.has(fish):
		var their := NatureScore.new(settings)
		their.awarded.connect(func(event: Dictionary) -> void:
			event["by"] = fish
			awarded.emit(event))
		_scores[fish] = their
	return _scores[fish]


## What `fish`'s ball cam looks at (null: nothing).
func focus_of(fish: FishController) -> Node3D:
	var node: Node3D = _focus.get(fish)
	return node if is_instance_valid(node) else null


## The speed of `fish`'s last battery (m/s).
func last_battery_speed_of(fish: FishController) -> float:
	return _battery_speed.get(fish, 0.0)


## The players simulated on this machine (not puppets).
func local_players() -> Array[FishController]:
	var local: Array[FishController] = []
	for fish in players:
		if is_instance_valid(fish) and not fish.puppet:
			local.append(fish)
	return local


func _join(fish: FishController) -> void:
	score_of(fish)
	for other in players:
		if other != fish and is_instance_valid(other):
			fish.add_collision_exception_with(other)  # co-op fish pass through each other
			other.add_collision_exception_with(fish)
	_refresh_threats()


func _leave(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	for other in players:
		if other != fish and is_instance_valid(other):
			fish.remove_collision_exception_with(other)
			other.remove_collision_exception_with(fish)


## Every school fears, and every pearl comes to, every player.
func _refresh_threats() -> void:
	for school in schools:
		school.threats.assign(players)
	for pearl in pearls_out:
		if is_instance_valid(pearl):
			pearl.collectors.assign(players)


func _physics_process(delta: float) -> void:
	if authority:
		_update_schools(delta)
	_batter_school_fish()
	_place_hitboxes(delta)
	_update_lone_target(delta)
	for fish in local_players():
		score_of(fish).update(delta, fish.speed, fish.nature_batter_speed)
		if not _focus_ok(focus_of(fish)):
			pick_focus(fish)


func _update_lone_target(delta: float) -> void:
	if authority:
		if settings.lone_target != _lone_target:
			_lone_target = settings.lone_target
			_respawn_left = -1.0
			if _lone_target:
				_respawn_target()
			elif not target.battered:
				target.batter()  # just gone, no explosion
				target_state.emit(false, target.global_transform, target.display_name, _target_generation)
		if not _lone_target:
			return
		if _respawn_left >= 0.0:
			_respawn_left -= delta
			if _respawn_left < 0.0:
				_respawn_target()
			return
		var nearest := _nearest_player(target.global_position)
		if nearest:
			bot.threat = nearest
			if target.global_position.distance_to(nearest.global_position) > LEASH:
				_respawn_target()
				return
	if target.battered:
		return
	# Everyone who hits it this tick (two at once share it).
	var hitters: Array[FishController] = []
	for fish in local_players():
		if Battery.hits(fish, target, fish.nature_batter_speed):
			hitters.append(fish)
	var key := "t%d" % _target_generation
	for fish in hitters:
		_claim_battery(fish, key, fish != hitters[0])


## Keeps settings.school_count schools out, replacing strays and wiped-out ones.
func _update_schools(delta: float) -> void:
	while schools.size() < settings.school_count:
		_add_school(_group_transform(), false)
	while schools.size() > settings.school_count:
		_remove_school(_farthest_school())
	for school in schools.duplicate():
		var nearest := _nearest_player(school.leader_position)
		if nearest and school.leader_position.distance_to(nearest.global_position) > settings.leash:
			_replace_school(school)
		elif school.alive_count() == 0:
			var left: float = _school_respawn.get(school, settings.respawn_time) - delta
			_school_respawn[school] = left
			if left < 0.0:
				_replace_school(school)


## A new school around `around` (the players' spawn or where they are now). The
## first one waits ahead, off to one side; later ones turn up out of view.
func _add_school(around: Transform3D, first: bool) -> void:
	var ahead := -around.basis.z
	var at: Vector3
	if first:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		at = around.origin + ahead.rotated(Vector3.UP, side * deg_to_rad(35.0)) * settings.first_school_distance
	else:
		var distance := rng.randf_range(settings.spawn_distance_min, maxf(settings.spawn_distance_min, settings.spawn_distance_max))
		at = _hidden_point(around.origin, distance)
	var heading := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	var kind: FishCharacter.Family = FishCharacter.CARS.keys()[rng.randi_range(0, FishCharacter.CARS.size() - 1)]
	var school := spawn_school(_next_school_id, rng.randi() & 0x7fffffff, kind, at, heading)
	_next_school_id += 1
	school_spawned.emit(school, at, heading)


## Builds school `id` (the authority's numbering) from `school_seed`: the same
## school wherever it's built. Off the authority it follows the host's leader.
func spawn_school(id: int, school_seed: int, kind: FishCharacter.Family, at: Vector3, heading: Vector3) -> School:
	if _schools_by_id.has(id):
		return _schools_by_id[id]
	var school := School.new()
	school.name = "School%d" % id
	school.id = id
	school.follower = not authority
	school.threats.assign(players)
	add_child(school)
	school.setup(settings, at, heading, kind, school_seed)
	schools.append(school)
	_schools_by_id[id] = school
	_next_school_id = maxi(_next_school_id, id + 1)
	return school


func school_by_id(id: int) -> School:
	return _schools_by_id.get(id)


## A point `distance` from `around` (mostly level) outside every player's view ahead.
func _hidden_point(around: Vector3, distance: float) -> Vector3:
	var point := around
	for attempt in 16:
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
		point = around + direction * distance
		var hidden := true
		for fish in players:
			if not is_instance_valid(fish):
				continue
			var offset := point - fish.global_position
			if offset.length() > 0.001 and offset.normalized().dot(-fish.global_basis.z) >= SPAWN_HIDDEN:
				hidden = false
				break
		if hidden:
			break
	return point


func _replace_school(school: School) -> void:
	_remove_school(school)
	_add_school(_group_transform(), false)


func _remove_school(school: School) -> void:
	schools.erase(school)
	_school_respawn.erase(school)
	_schools_by_id.erase(school.id)
	school_removed.emit(school.id)
	school.queue_free()


## Takes school `id` away (the authority did).
func remove_school_by_id(id: int) -> void:
	var school: School = _schools_by_id.get(id)
	if school:
		_remove_school(school)


func _farthest_school() -> School:
	var farthest: School = schools[0]
	var farthest_gap := -1.0
	for school in schools:
		var nearest := _nearest_player(school.centre.global_position)
		var gap := school.centre.global_position.distance_to(nearest.global_position) if nearest else 0.0
		if gap > farthest_gap:
			farthest = school
			farthest_gap = gap
	return farthest


## The players' middle, facing the way the first one does.
func _group_transform() -> Transform3D:
	var sum := Vector3.ZERO
	var count := 0
	for fish in players:
		if is_instance_valid(fish) and not fish.battered:
			sum += fish.global_position
			count += 1
	var middle := sum / count if count > 0 else player.global_position
	return Transform3D(player.global_basis.orthonormalized(), middle)


## The player nearest `point` (battered ones too: they're coming back), or null.
func _nearest_player(point: Vector3) -> FishController:
	var nearest: FishController = null
	var gap := INF
	for fish in players:
		if not is_instance_valid(fish):
			continue
		var d := fish.global_position.distance_squared_to(point)
		if d < gap:
			gap = d
			nearest = fish
	return nearest


## The nearest thing ahead of `fish` (the first player by default) to look at:
## the lone fish or a school's centre. Ones behind count as further away.
func pick_focus(fish: FishController = null) -> void:
	if fish == null:
		fish = player
	var best: Node3D = null
	var best_cost := INF
	var ahead := -fish.global_basis.z
	var candidates: Array[Node3D] = [target]
	for school in schools:
		candidates.append(school.centre)
	for candidate in candidates:
		if not _focus_ok(candidate):
			continue
		var offset := candidate.global_position - fish.global_position
		var cost := offset.length() * (1.5 - ahead.dot(offset.normalized()))
		if cost < best_cost:
			best = candidate
			best_cost = cost
	_set_focus_of(fish, best)


## `fish`'s ball cam (the first player's by default) looks at `candidate` (a
## school's centre or the lone fish) if it's still there.
func set_focus(candidate: Node3D, fish: FishController = null) -> void:
	if _focus_ok(candidate):
		_set_focus_of(fish if fish else player, candidate)


func _set_focus_of(fish: FishController, candidate: Node3D) -> void:
	if candidate == focus_of(fish) and _focus.has(fish):
		return
	_focus[fish] = candidate
	focus_changed.emit(candidate, fish)


## What ball cam can look at, for the school wheel: [node, name, fish left] for
## the lone fish (if out) and each school with fish left.
func targets() -> Array:
	var found := []
	if _focus_ok(target):
		found.append([target, target.display_name, 1])
	for school in schools:
		if _focus_ok(school.centre):
			found.append([school.centre, school.display_name, school.alive_count()])
	return found


func _focus_ok(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_inside_tree() or not candidate.visible:
		return false
	if candidate == target:
		return not target.battered and (_lone_target or not authority)
	return candidate.get_parent() in schools


## Every school fish a local player's front touches now, at the battering
## speed or faster, is battered (any number in one tick: a double is a double).
func _batter_school_fish() -> void:
	if not settings.batter_schools or _hitbox_fish.is_empty():
		return
	# Every player's hits first, then the batteries: two players on the same
	# fish this tick share it.
	var hits_by := {}
	for fish in local_players():
		if fish.battered or fish.speed < fish.nature_batter_speed:
			continue
		var nose := -fish.global_basis.z
		var hits: Array[String] = []
		hits_by[fish] = hits
		for area in Battery.areas_touched(fish, SchoolFish.LAYER):
			var info: Array = _hitbox_fish.get(area, [])
			if info.is_empty():
				continue
			var school: School = info[0]
			var index: int = info[1]
			if not is_instance_valid(school) or not school.is_alive(index):
				continue
			var ahead := (school.fish_position(index) - fish.global_position).normalized()
			if ahead.dot(nose) >= Battery.FRONT:
				hits.append("s%d:%d" % [school.id, index])
	var claimed := {}
	for fish: FishController in hits_by:
		for key: String in hits_by[fish]:
			_claim_battery(fish, key, claimed.has(key))
			claimed[key] = true


## A local player batters the fish `key` names: it shows here at once (the
## explosion, the speed cost, the points), then goes to the authority.
## `sharing`: another player here hit it this same tick (it's gone already).
func _claim_battery(attacker: FishController, key: String, sharing := false) -> void:
	if not sharing and (_shown.has(key) or not _victim_out(key)):
		return
	last_battery_speed = attacker.speed
	_battery_speed[attacker] = attacker.speed
	var chain := score_of(attacker).on_battery()
	if key.begins_with("s"):
		_slow_player(attacker)
	if authority:
		confirm_battery(key, attacker, chain)  # which shows it (or shares it)
		return
	if not sharing:
		_shown[key] = true
		_announce_battered(attacker, key, _show_battered(key))
	battery_claimed.emit(key, attacker, chain)


func _announce_battered(attacker: FishController, key: String, at: Vector3) -> void:
	if key.begins_with("s"):
		school_fish_battered.emit(attacker, _school_of(key), at)
	else:
		battered.emit(attacker, target)


## The authority's say on a battery (its own players' or a claim from another
## machine): the first is confirmed, a second on the same fish within
## SHARE_WINDOW shares it, a later one is too late (the fish was gone).
## `chain` is the attacker's multi so far, which makes a pearl likelier.
func confirm_battery(key: String, attacker: FishController, chain: int) -> void:
	var now := Time.get_ticks_msec()
	if _confirmed.has(key):
		var record: Dictionary = _confirmed[key]
		if attacker in record.attackers or now - int(record.time) > SHARE_WINDOW * 1000.0:
			return
		record.attackers.append(attacker)
		apply_battery_shared(key, attacker)
		return
	if not _victim_out(key):
		return
	var at := _victim_position(key)
	var pearl_id := -1
	var chance := minf(settings.pearl_chance + settings.pearl_chance_per_step * maxi(chain - 1, 0), 1.0)
	if rng.randf() < chance:
		pearl_id = _next_pearl_id
		_next_pearl_id += 1
	apply_battery_confirmed(key, [attacker], at, pearl_id)


## Everyone (the authority included) on a confirmed battery: the fish goes (with
## its explosion, if it hasn't here already), the team's count, any pearl.
func apply_battery_confirmed(key: String, attackers: Array, at: Vector3, pearl_id: int) -> void:
	if not _confirmed.has(key):
		_confirmed[key] = {"time": Time.get_ticks_msec(), "attackers": attackers.duplicate()}
	if not _shown.has(key):
		_shown[key] = true
		if _victim_out(key):
			at = _show_battered(key)
		if not attackers.is_empty() and is_instance_valid(attackers[0]):
			_announce_battered(attackers[0], key, at)
	rules.on_battery(attackers)
	if key.begins_with("t") and authority:
		_respawn_left = RESPAWN_TIME
	if pearl_id >= 0:
		drop_pearl(pearl_id, at)
	battery_confirmed.emit(key, attackers, at, pearl_id)


## A second player shares a battery already confirmed.
func apply_battery_shared(key: String, attacker: FishController) -> void:
	if _confirmed.has(key) and attacker not in _confirmed[key].attackers:
		_confirmed[key].attackers.append(attacker)
	rules.on_shared(attacker)
	battery_shared.emit(key, attacker)


## Whether the fish `key` names is still about to be battered (here).
func _victim_out(key: String) -> bool:
	if key.begins_with("t"):
		return key == "t%d" % _target_generation and not target.battered
	var school := _school_of(key)
	var index := key.get_slice(":", 1).to_int()
	return school != null and index < school.fish_count() and school.is_alive(index)


func _victim_position(key: String) -> Vector3:
	if key.begins_with("t"):
		return target.global_position
	var school := _school_of(key)
	return school.fish_position(key.get_slice(":", 1).to_int()) if school else Vector3.ZERO


func _school_of(key: String) -> School:
	return _schools_by_id.get(key.substr(1).get_slice(":", 0).to_int()) if key.begins_with("s") else null


## The fish `key` names goes, with its explosion. Returns where it was.
func _show_battered(key: String) -> Vector3:
	if key.begins_with("t"):
		var at := target.global_position
		Explosion.spawn(ocean, at, TARGET_COLOR, 6.0)
		target.batter()
		return at
	var school := _school_of(key)
	var index := key.get_slice(":", 1).to_int()
	if school == null or index >= school.fish_count() or not school.is_alive(index):
		return Vector3.ZERO
	var at := school.batter(index)
	if settings.fish_explosion > 0.0:
		Explosion.spawn(ocean, at, TARGET_COLOR, settings.fish_explosion, 0.0, settings.fish_explosion_particles)
	return at


## Each fish battered takes hit_speed_cost of the attacker's speed (never below
## the battering speed, if hit_cost_keeps_batter_speed).
func _slow_player(fish: FishController) -> void:
	if settings.hit_speed_cost <= 0.0:
		return
	var velocity := fish.linear_velocity
	var speed := velocity.length()
	if speed <= 0.001:
		return
	var slower := speed * (1.0 - settings.hit_speed_cost)
	if settings.hit_cost_keeps_batter_speed:
		slower = maxf(slower, minf(speed, fish.nature_batter_speed + 0.5))
	fish.apply_push(velocity / speed * (slower - speed))


## The pool of hitboxes on the live school fish near the local players, where
## they'll be next tick (so this tick's are there for the next query).
func _place_hitboxes(delta: float) -> void:
	_hitbox_fish.clear()
	var used := 0
	var placed := {}
	if settings.batter_schools:
		for fish in local_players():
			if fish.battered:
				continue
			var at := fish.global_position
			var reach := HITBOX_RANGE + fish.bow_length * 2.0 + fish.speed * delta
			for school in schools:
				var size := FishCharacter.hitbox_size(school.character) * settings.fish_scale
				var fish_reach := reach + size.length()
				if school.centre.global_position.distance_to(at) > school.radius() * 2.0 + fish_reach + 4.0:
					continue
				var reach_squared := fish_reach * fish_reach
				for i in school.fish_count():
					if not school.is_alive(i) or placed.has(Vector2i(school.id, i)):
						continue
					var next := school.fish_position(i) + school.fish_velocity(i) * delta
					if next.distance_squared_to(at) > reach_squared:
						continue
					var box := _hitbox(used)
					used += 1
					placed[Vector2i(school.id, i)] = true
					((box.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
					var heading := school.fish_heading(i)
					var facing := Basis.looking_at(heading, Vector3.UP) if absf(heading.y) < 0.99 else Basis()
					box.global_transform = Transform3D(facing, next)
					_hitbox_fish[box] = [school, i]
	for i in range(used, _hitboxes.size()):
		_hitboxes[i].global_position = Vector3(0, -10000, 0)


func _hitbox(index: int) -> Area3D:
	while _hitboxes.size() <= index:
		var area := Area3D.new()
		area.name = "SchoolHitbox%d" % _hitboxes.size()
		area.collision_layer = SchoolFish.LAYER
		area.collision_mask = 0
		area.monitoring = false
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		area.add_child(shape)
		add_child(area)
		area.global_position = Vector3(0, -10000, 0)
		_hitboxes.append(area)
	return _hitboxes[index]


## Pearl `id` where a fish was battered (the authority rolled for it:
## pearl_chance, plus pearl_chance_per_step for each step of the multi).
func drop_pearl(id: int, at: Vector3) -> void:
	if _pearls_by_id.has(id) or _collected.has(id):
		return
	var pearl := Pearl.new(settings)
	pearl.name = "Pearl%d" % id
	pearl.id = id
	pearl.collectors.assign(players)
	pearl.position = at  # the run is a plain Node: this is where it is in the world
	add_child(pearl)
	pearl.reset_physics_interpolation()
	pearl.collected.connect(_on_pearl_collected)
	pearl.tree_exiting.connect(func() -> void:
		pearls_out.erase(pearl)
		_pearls_by_id.erase(id))
	pearls_out.append(pearl)
	_pearls_by_id[id] = pearl


## A pearl absorbed here: a local player's goes to the authority to count, one
## drawn into a puppet waits for the authority's word.
func _on_pearl_collected(pearl: Pearl, by: FishController) -> void:
	if pearl.id < 0:  # not the run's own (a probe's): just counts
		rules.on_pearl(by)
		pearl_collected.emit(by)
		return
	if _collected.has(pearl.id) or not is_instance_valid(by):
		return
	if authority:
		confirm_pearl(pearl.id, by)
	elif not by.puppet:
		pearl_claimed.emit(pearl.id, by)


## The authority's say on a pearl: the first to collect it has it.
func confirm_pearl(id: int, by: FishController) -> void:
	if _collected.has(id):
		return
	apply_pearl_confirmed(id, by)


## Everyone on a confirmed pearl: counted for `by`, and gone if it's still out here.
func apply_pearl_confirmed(id: int, by: FishController) -> void:
	if _collected.has(id):
		return
	_collected[id] = by
	var pearl: Pearl = _pearls_by_id.get(id)
	if is_instance_valid(pearl) and pearl.absorbing == null:
		pearl.queue_free()
	rules.on_pearl(by)
	pearl_collected.emit(by)
	pearl_confirmed.emit(id, by)


## A new lone fish somewhere around the players, heading off calmly.
func _respawn_target() -> void:
	var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
	var at := _group_transform().origin + direction * rng.randf_range(RESPAWN_DISTANCE.x, RESPAWN_DISTANCE.y)
	var heading := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	_place_target(at, heading)
	_announce_teleport([target])


func _place_target(at: Vector3, heading: Vector3) -> void:
	Match1v1.copy_tuning(player, target)  # tuning changes since apply to it too
	target.swim_strokes = false
	target.bow_wave = false
	target.boost_enabled = false
	target.spawn_boost = 0.0
	target.display_name = TARGET_NAMES[rng.randi_range(0, TARGET_NAMES.size() - 1)]
	_target_generation += 1
	target.revive(Transform3D(Basis.looking_at(heading, Vector3.UP), at))
	bot.home = at
	bot.pick_spot()
	target_state.emit(true, Transform3D(Basis.looking_at(heading, Vector3.UP), at), target.display_name, _target_generation)


## The authority moved the lone fish (or took it away): the same here.
func apply_target_state(present: bool, at: Transform3D, target_name: String, generation: int) -> void:
	_target_generation = generation
	target.display_name = target_name
	if present:
		target.revive(at)
		_announce_teleport([target])
	elif not target.battered:
		target.batter()


## A remote player's points, for the feed (NatureScore's event, "by" their fish).
func relay_award(event: Dictionary) -> void:
	awarded.emit(event)


func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)
