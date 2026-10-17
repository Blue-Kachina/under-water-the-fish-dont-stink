class_name NatureRun
extends Node
## Nature mode in the Ocean: the player swims Extra Swishy (no boost) among
## schools of harmless fish (School) and after a calm lone fish (a WanderBot).
## Ramming the lone fish nose first at the player's nature_batter_speed or
## faster batters it: it explodes, the count goes up, and a moment later a new
## one turns up a little way off.
##
## Schools keep swimming around the player: settings.school_count of them
## (NatureSettings, live). One that strays past the leash, or is wiped out, is
## replaced by a new one, out of the player's view. School fish batter the same
## way (fast, nose first, the bow wave counting), several in one pass if they're
## packed tight: each tick a small pool of hitboxes (SchoolFish.LAYER) is put on
## the fish near the player, and one query (Battery.areas_touched) finds every
## one its front touches. Each costs the player a little speed (hit_speed_cost).
##
## Points (NatureScore): every battery scores, quick ones chain into multis and
## a run of them at speed is a spree. A battered fish may leave a pearl (Pearl),
## more likely deeper into a multi; pearls are drawn in and counted.
##
## The camera's ball cam looks at `focus`: whichever is nearest ahead of the
## player of the lone fish and the schools' centres (pick_focus(), which main
## calls as ball cam goes on), picked again if the focus goes away, or chosen
## on the school wheel (set_focus(), TargetWheel). focus_changed says so.
##
## Lives under the Ocean (setup() before adding it). end() hands the player's
## fish back.

## A kickoff or respawn has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
signal battered(attacker: FishController, victim: FishController)
## The ball cam's focus changed (null: nothing to look at).
signal focus_changed(focus: Node3D)
## A school fish battered, where it was.
signal school_fish_battered(attacker: FishController, school: School, at: Vector3)
## Points scored (NatureScore's events: "battery", "multi", "spree").
signal awarded(event: Dictionary)
## A pearl collected.
signal pearl_collected(by: FishController)

const FISH_SCENE := preload("res://scenes/fish.tscn")
## The lone fish first waits this far ahead of the player (m).
const FIRST_DISTANCE := 30.0
## Later ones turn up this far from the player (m), in any direction.
const RESPAWN_DISTANCE := Vector2(30.0, 50.0)
## Seconds between a battery and the next fish.
const RESPAWN_TIME := 1.5
## The target's colour (and its explosion's).
const TARGET_COLOR := Color(0.55, 0.95, 0.75)
const TARGET_NAMES := ["Wanda", "Gill", "Bubbles", "Finley", "Coral", "Squirt", "Nemo-ish", "Sardine Steve"]
## A wandering target further than this from the player (m) is brought back near it.
const LEASH := 150.0
## New schools (after the first ones) turn up outside this cone ahead of the
## player (cosine of its half-angle), so they don't pop in on screen.
const SPAWN_HIDDEN := 0.4
## Within this (m) of the player, past its own size and bow wave, school fish get hitboxes.
const HITBOX_RANGE := 4.0

var ocean: Node3D
var player: FishController
var settings := NatureSettings.shared()
## The lone fish.
var target: FishController
var bot: WanderBot
var schools: Array[School] = []
## What ball cam looks at: the lone fish or a school's centre.
var focus: Node3D
## Batteries this run.
var batteries := 0
## The speed of the last battery (m/s).
var last_battery_speed := 0.0
var _respawn_left := -1.0
var _lone_target := true
## Per school: seconds until it's replaced, once wiped out (-1: not yet).
var _school_respawn := {}
## Points: batteries, multis and sprees.
var score := NatureScore.new(settings)
## Pearls collected this run, and those still out.
var pearls := 0
var pearls_out: Array[Pearl] = []
## The hitbox pool for school fish near the player, and which fish each is on
## ([school, index]).
var _hitboxes: Array[Area3D] = []
var _hitbox_fish := {}


func setup(nature_ocean: Node3D, player_fish: FishController) -> void:
	ocean = nature_ocean
	player = player_fish


func _ready() -> void:
	score.awarded.connect(awarded.emit)
	target = FISH_SCENE.instantiate()
	target.name = "TargetFish"
	target.character = FishCharacter.Family.HYBRID
	target.display_name = TARGET_NAMES.pick_random()
	add_child(target)
	Match1v1.copy_tuning(player, target)
	target.swim_strokes = false  # it just cruises
	target.team_color = TARGET_COLOR
	bot = WanderBot.new()
	bot.name = "WanderBot"
	bot.fish = target
	bot.threat = player
	add_child(bot)
	start()


## The player at the ocean's spawn, the lone fish waiting ahead of it and the
## schools around.
func start() -> void:
	batteries = 0
	last_battery_speed = 0.0
	_respawn_left = -1.0
	pearls = 0
	score.reset()
	for pearl in pearls_out:
		if is_instance_valid(pearl):
			pearl.queue_free()
	pearls_out.clear()
	var spawn: Transform3D = ocean.spawn_transform()
	player.revive(spawn)
	var ahead := -spawn.basis.z
	_lone_target = settings.lone_target
	if _lone_target:
		_place_target(spawn.origin + ahead * FIRST_DISTANCE, ahead)
	else:
		target.batter()
	for school in schools:
		school.queue_free()
	schools.clear()
	_school_respawn.clear()
	for i in settings.school_count:
		_add_school(spawn, i == 0)
	_announce_teleport([player, target])
	pick_focus()


## Hands the player's fish back. Call before freeing the run.
func end() -> void:
	if is_instance_valid(player) and player.battered:
		player.revive(player.global_transform)


func _physics_process(delta: float) -> void:
	_update_schools(delta)
	_batter_school_fish()
	_place_hitboxes(delta)
	_update_lone_target(delta)
	score.update(delta, player.speed, player.nature_batter_speed)
	if not _focus_ok(focus):
		pick_focus()


func _update_lone_target(delta: float) -> void:
	if settings.lone_target != _lone_target:
		_lone_target = settings.lone_target
		_respawn_left = -1.0
		if _lone_target:
			_respawn_target()
		elif not target.battered:
			target.batter()  # just gone, no explosion
	if not _lone_target:
		return
	if _respawn_left >= 0.0:
		_respawn_left -= delta
		if _respawn_left < 0.0:
			_respawn_target()
		return
	if Battery.hits(player, target, player.nature_batter_speed):
		_batter()
	elif target.global_position.distance_to(player.global_position) > LEASH:
		_respawn_target()


## Keeps settings.school_count schools out, replacing strays and wiped-out ones.
func _update_schools(delta: float) -> void:
	while schools.size() < settings.school_count:
		_add_school(player.global_transform, false)
	while schools.size() > settings.school_count:
		_remove_school(_farthest_school())
	for school in schools.duplicate():
		if school.leader_position.distance_to(player.global_position) > settings.leash:
			_replace_school(school)
		elif school.alive_count() == 0:
			var left: float = _school_respawn.get(school, settings.respawn_time) - delta
			_school_respawn[school] = left
			if left < 0.0:
				_replace_school(school)


## A new school around `around` (the player's spawn or where it is now). The
## first one waits ahead, off to one side; later ones turn up out of view.
func _add_school(around: Transform3D, first: bool) -> void:
	var ahead := -around.basis.z
	var direction: Vector3
	var distance: float
	if first:
		var side := 1.0 if randf() < 0.5 else -1.0
		direction = ahead.rotated(Vector3.UP, side * deg_to_rad(35.0))
		distance = settings.first_school_distance
	else:
		direction = _hidden_direction(ahead)
		distance = randf_range(settings.spawn_distance_min, maxf(settings.spawn_distance_min, settings.spawn_distance_max))
	var at := around.origin + direction * distance
	var heading := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var school := School.new()
	school.name = "School%d" % schools.size()
	school.threats = [player]
	add_child(school)
	school.setup(settings, at, heading, FishCharacter.CARS.keys().pick_random())
	schools.append(school)


## A direction (mostly level) from the player that's outside its view ahead.
func _hidden_direction(ahead: Vector3) -> Vector3:
	var direction := Vector3.ZERO
	for attempt in 12:
		direction = Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
		if direction.dot(ahead) < SPAWN_HIDDEN:
			break
	return direction


func _replace_school(school: School) -> void:
	_remove_school(school)
	_add_school(player.global_transform, false)


func _remove_school(school: School) -> void:
	schools.erase(school)
	_school_respawn.erase(school)
	school.queue_free()


func _farthest_school() -> School:
	var farthest: School = schools[0]
	for school in schools:
		if school.centre.global_position.distance_to(player.global_position) > farthest.centre.global_position.distance_to(player.global_position):
			farthest = school
	return farthest


## The nearest thing ahead of the player to look at: the lone fish or a
## school's centre. Ones behind count as further away.
func pick_focus() -> void:
	var best: Node3D = null
	var best_cost := INF
	var ahead := -player.global_basis.z
	var candidates: Array[Node3D] = [target]
	for school in schools:
		candidates.append(school.centre)
	for candidate in candidates:
		if not _focus_ok(candidate):
			continue
		var offset := candidate.global_position - player.global_position
		var cost := offset.length() * (1.5 - ahead.dot(offset.normalized()))
		if cost < best_cost:
			best = candidate
			best_cost = cost
	if best != focus:
		focus = best
		focus_changed.emit(focus)


## Looks at `candidate` (a school's centre or the lone fish) if it's still there.
func set_focus(candidate: Node3D) -> void:
	if _focus_ok(candidate) and candidate != focus:
		focus = candidate
		focus_changed.emit(focus)


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
		return _lone_target and not target.battered
	return candidate.get_parent() in schools


func _batter() -> void:
	last_battery_speed = player.speed
	batteries += 1
	Explosion.spawn(ocean, target.global_position, TARGET_COLOR, 6.0)
	target.batter()
	_respawn_left = RESPAWN_TIME
	var chain := score.on_battery()
	_maybe_drop_pearl(target.global_position, chain)
	battered.emit(player, target)


## Every school fish the player's front touches now, at the battering speed or
## faster, is battered (any number in one tick: a double is a double).
func _batter_school_fish() -> void:
	if not settings.school_batteries or player.battered or player.speed < player.nature_batter_speed or _hitbox_fish.is_empty():
		return
	var nose := -player.global_basis.z
	var hits: Array = []
	for area in Battery.areas_touched(player, SchoolFish.LAYER):
		var info: Array = _hitbox_fish.get(area, [])
		if info.is_empty():
			continue
		var school: School = info[0]
		var index: int = info[1]
		if not is_instance_valid(school) or not school.is_alive(index):
			continue
		var ahead := (school.fish_position(index) - player.global_position).normalized()
		if ahead.dot(nose) >= Battery.FRONT:
			hits.append(info)
	for info: Array in hits:
		var school: School = info[0]
		var at := school.batter(info[1])
		last_battery_speed = player.speed
		batteries += 1
		if settings.fish_explosion > 0.0:
			Explosion.spawn(ocean, at, TARGET_COLOR, settings.fish_explosion, 0.0, settings.fish_explosion_particles)
		_slow_player()
		var chain := score.on_battery()
		_maybe_drop_pearl(at, chain)
		school_fish_battered.emit(player, school, at)


## Each fish battered takes hit_speed_cost of the player's speed (never below
## the battering speed, if hit_cost_keeps_batter_speed).
func _slow_player() -> void:
	if settings.hit_speed_cost <= 0.0:
		return
	var velocity := player.linear_velocity
	var speed := velocity.length()
	if speed <= 0.001:
		return
	var slower := speed * (1.0 - settings.hit_speed_cost)
	if settings.hit_cost_keeps_batter_speed:
		slower = maxf(slower, minf(speed, player.nature_batter_speed + 0.5))
	player.apply_push(velocity / speed * (slower - speed))


## The pool of hitboxes on the live school fish near the player, where they'll
## be next tick (so this tick's are there for the next query).
func _place_hitboxes(delta: float) -> void:
	_hitbox_fish.clear()
	var used := 0
	if settings.school_batteries and not player.battered:
		var at := player.global_position
		var reach := HITBOX_RANGE + player.bow_length * 2.0 + player.speed * delta
		for school in schools:
			var size := FishCharacter.hitbox_size(school.character) * settings.fish_scale
			var fish_reach := reach + size.length()
			if school.centre.global_position.distance_to(at) > school.radius() * 2.0 + fish_reach + 4.0:
				continue
			var reach_squared := fish_reach * fish_reach
			for i in school.fish_count():
				if not school.is_alive(i):
					continue
				var next := school.fish_position(i) + school.fish_velocity(i) * delta
				if next.distance_squared_to(at) > reach_squared:
					continue
				var box := _hitbox(used)
				used += 1
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


## A pearl where a fish was battered, by chance: pearl_chance, plus
## pearl_chance_per_step for each step of the multi past the first.
func _maybe_drop_pearl(at: Vector3, chain: int) -> void:
	var chance := minf(settings.pearl_chance + settings.pearl_chance_per_step * maxi(chain - 1, 0), 1.0)
	if randf() >= chance:
		return
	var pearl := Pearl.new(settings)
	pearl.name = "Pearl"
	pearl.collectors = [player]
	pearl.position = at  # the run is a plain Node: this is where it is in the world
	add_child(pearl)
	pearl.reset_physics_interpolation()
	pearl.collected.connect(_on_pearl_collected)
	pearl.tree_exiting.connect(func() -> void: pearls_out.erase(pearl))
	pearls_out.append(pearl)


func _on_pearl_collected(_pearl: Pearl, by: FishController) -> void:
	pearls += 1
	pearl_collected.emit(by)


## A new fish somewhere around the player, heading off calmly.
func _respawn_target() -> void:
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
	var at := player.global_position + direction * randf_range(RESPAWN_DISTANCE.x, RESPAWN_DISTANCE.y)
	var heading := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_place_target(at, heading)
	target.display_name = TARGET_NAMES.pick_random()
	_announce_teleport([target])


func _place_target(at: Vector3, heading: Vector3) -> void:
	Match1v1.copy_tuning(player, target)  # tuning changes since apply to it too
	target.swim_strokes = false
	target.bow_wave = false
	target.boost_enabled = false
	target.spawn_boost = 0.0
	target.revive(Transform3D(Basis.looking_at(heading, Vector3.UP), at))
	bot.home = at
	bot.pick_spot()


func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)
