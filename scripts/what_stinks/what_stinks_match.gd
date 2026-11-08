class_name WhatStinksMatch
extends Node
## What Stinks? (what_stinks.md): one Hunter against many prey in an open ocean
## full of NPC schools. The Hunter is a monster (a HunterForm: the Drowned Shark
## or a Titan, scaled by HunterSize) whose Bite (HunterBite) eats the fish
## nearest its bite point (WhatStinksField.eat_at: school fish and prey players
## alike); everyone else is prey. Phase 1 has no hiding: prey are free swimmers
## among the schools (joining a school is Phase 2).
##
## Written like MarcoPoloMatch: `roster` (players), `role` (fish -> Role), the
## `eaten` set, one apply_role(fish, role) at each round's start. A round is
## COUNTDOWN (the Hunter held, view blacked out, while the prey scatter) -> LIVE
## (until every prey is eaten or the clock runs out) -> ROUND_OVER (its points),
## and after the last round OVER. Rounds are one per person plus
## bot_hunter_rounds (settings.rounds overrides); hunters_per_round is a list, so
## few-vs-many works later. Variants: Clean Sweep, and Upset Stomach: the Hunter's
## satiation bar fills on school fish (by their size) and drains with hunger, a
## prey player in the bite is spat out (not eaten: flung, dazed, the Hunter's
## satiation drops, it gets queasy and can't bite for spit_cooldown), the Hunter
## wins on a full bar, the prey on the clock or when every Hunter's queasy bar
## maxes (it hurls: held for the rest of the round), and the schools respawn.
##
## An eaten prey spectates a live prey (left / right switch), as Marco Polo's
## eliminated hiders do. Points never show live (they'd leak who is a player):
## they show on the round's card.
##
## The host judges everything (`authority`); online guests are Phase 6. Lives
## under the environment (setup() before adding it): the Ocean. Bots fill the
## seats up to min_players. end() hands the player's fish back.

signal phase_changed(phase: int)
signal round_started(index: int, hunters: Array)
signal role_changed(fish: FishController, role: int)
## A bite landed: how many school fish and prey players it took.
signal bitten(hunter: FishController, school_fish: int, prey: Array)
## A Hunter's callout: a bite or ram that took fish ("type": NatureScore.BATTERY / MULTI / SPREE, "title", "chain", "spree", "count", "source": "bite" or "ram", "prey": the prey players it took).
signal callout(hunter: FishController, event: Dictionary)
signal eaten_fish(fish: FishController, by: FishController)
## Upset Stomach: `prey` was in a bite and spat out; the Hunter hurled (queasy at max); it fed on school fish.
signal spat(prey: FishController, hunter: FishController)
signal hurled(hunter: FishController)
signal fed(hunter: FishController, gain: float)
## Online. A bite of ours (a guest's Hunter) landed: the mouth and heading, for the host to judge.
signal local_bite(mouth: Vector3, forward: Vector3, charge: float, extra: Dictionary)
## The host: a Hunter's bite began; what a landed bite took (school id -> indices, and the prey players); extra seconds on its cooldown; a spat prey's fling.
signal bite_started(hunter: FishController)
## The host: a Hunter's jaws shut at `charge` (a negative one: the held bite was called off).
signal bite_closed(hunter: FishController, charge: float)
signal bite_result(hunter: FishController, taken: Dictionary, prey: Array)
signal bite_penalty(hunter: FishController, extra: float)
signal spit_applied(prey: FishController, hunter: FishController, velocity: Vector3, daze: float)
signal round_over(results: Dictionary)
signal match_over(winner: FishController)
signal spectate_target_changed(fish: FishController)
## The local player's role (as local_view_role()) changed.
signal local_role_changed(role: int)

enum Role { PREY, HUNTER }
enum Phase { COUNTDOWN, LIVE, ROUND_OVER, OVER }

const FISH_SCENE := preload("res://scenes/fish.tscn")
const BOT_NAMES := ["Guppy", "Minnow", "Tetra", "Danio", "Molly", "Platy", "Rasbora", "Barb", "Loach", "Pleco", "Gourami", "Cory"]
const BOT_PATH := "res://scripts/what_stinks/what_stinks_bot.gd"
const HUD_PATH := "res://scripts/what_stinks/what_stinks_hud.gd"

var settings := WhatStinksSettings.shared()
var size := HunterSize.shared()
var environment: Node3D
var field: WhatStinksField
## Prey joining schools (Phase 2).
var join: WhatStinksJoin
## What the Hunter sees of each prey: noise, echo, Click, Sniff (Phase 3).
var echo: WhatStinksEcho
## The kelp stands and rock arches the echo can't reach into.
var shadows: WhatStinksShadows
## The Hunter's reveal layers on the prey (HiderLooks, bound to this match).
var looks: WhatStinksLooks
## The follow cam and the school lock-on (WhatStinksCam).
var lock_cam: WhatStinksCam
## Fish taken by body rams so far (school fish and prey), and seconds until each Hunter may ram again.
var rammed_total := 0
## Per Hunter: its chain and spree (Nature's multi and spree counters, each fish taken counts).
var combos := {}
var _ram_left := {}
## The world's run here (the host's, or solo).
var authority := true
## Every fish in the match (people's and bots'), never assuming two.
var players: Array[FishController] = []
## Fish -> its bot node (bots only).
var bots := {}
## Fish -> Role.
var role := {}
## Fish -> true, once eaten this round.
var eaten := {}
var phase := Phase.COUNTDOWN
var round_index := 0
var time_left := 0.0
var phase_left := 0.0
## The round's Hunters.
var hunters: Array[FishController] = []
## Between-round totals: fish -> points.
var match_totals := {}
## Prey eaten this round, and across the match, by Hunter fish.
var round_eaten := 0
var match_eaten := {}
var camera: Node
var center := Vector3.ZERO
var winner: FishController
## The last round's results (round_over's).
var last_results := {}
## Fish -> their HunterBite (Hunters only).
var bites := {}
## Upset Stomach, Hunter fish -> its satiation (0..satiation_max) and queasy (0..queasy_max).
var satiation := {}
var queasy := {}
## Hunter -> true once it hurled this round.
var hurled_out := {}
## Prey spat out this round (all Hunters), and across the match by Hunter.
var round_spat := 0
var spat_total := {}
## The round's ocean seed (the host sends it so a guest's shadows are the same).
var last_seed := 0
## Fish -> the Transform3D it started the round at (the host sends each guest its own).
var round_places := {}

var _local: FishController
## Spat-out prey -> {left: seconds of daze left, boost: their boost_enabled before}.
var _daze := {}
## Hunter (a guest's) -> msec of the last bite the host judged for it.
var _net_bite_at := {}
## Hidden round tallies: fish -> points (host only).
var _tally := {}
var _spectating: FishController
var _layers := {}
var _player_base := {}
var _rng := RandomNumberGenerator.new()
var _hud: Node
var _local_role := -1


func setup(env: Node3D, player_fish: FishController, follow_camera: Node = null) -> void:
	environment = env
	_local = player_fish
	camera = follow_camera
	if not players.has(player_fish):
		players.insert(0, player_fish)


func _ready() -> void:
	_rng.randomize()
	center = environment.spawn_transform().origin if environment.has_method("spawn_transform") else Vector3.ZERO
	_player_base = {"buoyancy": _local.buoyancy, "boost_enabled": _local.boost_enabled, "bow_scale": _local.bow_scale,
			"speed_scale": _local.speed_scale, "turn_scale": _local.turn_scale, "rl_turn_scale": _local.rl_turn_scale,
			"drag_scale": _local.drag_scale, "top_speed_scale": _local.top_speed_scale, "boost_scale": _local.boost_scale,
			"accel_scale": _local.accel_scale, "hitbox_scale": _local.hitbox_scale, "body_scale": _local.body_scale}
	if authority:
		_fill_with_bots()
	for fish in players:
		_layers[fish] = [fish.collision_layer, fish.collision_mask]
	if environment is Ocean:
		(environment as Ocean).boundary_center = center
		(environment as Ocean).boundary_radius = settings.arena_radius
	field = WhatStinksField.new()
	field.name = "Field"
	field.authority = authority
	add_child(field)
	join = WhatStinksJoin.new()
	join.name = "Join"
	add_child(join)
	join.bind(self)
	shadows = WhatStinksShadows.new()
	shadows.name = "Shadows"
	add_child(shadows)
	echo = WhatStinksEcho.new()
	echo.name = "Echo"
	echo.shadows = shadows
	add_child(echo)
	echo.bind(self)
	looks = WhatStinksLooks.new()
	looks.name = "Looks"
	add_child(looks)
	looks.bind(self)
	lock_cam = WhatStinksCam.new()
	lock_cam.name = "LockCam"
	add_child(lock_cam)
	lock_cam.bind(self)
	_wire_hud()
	start_match()


## Hands the player's fish back. Call before freeing the match.
func end() -> void:
	if join != null:
		join.clear()
	if echo != null:
		echo.clear()
	for fish in players:
		if is_instance_valid(fish):
			_drop_bite(fish)
	if is_instance_valid(environment) and environment is Ocean:
		(environment as Ocean).boundary_radius = 0.0
	if lock_cam != null:
		lock_cam.clear()  # the lock-on, its wheel and the follow cam settings
	if is_instance_valid(camera):
		camera.set("target", null)
		if "body_follow" in camera:
			camera.set("body_follow", 1.0)
		if "extra_distance" in camera:
			camera.set("extra_distance", 0.0)
			camera.set("extra_height", 0.0)
	if not is_instance_valid(_local):
		return
	_restore_look(_local)
	_restore_values(_local)
	_restore_layers(_local)
	_local.team = -1
	_local.controls_locked = false
	_local.freeze = false
	_local.visible = true


# --- The roster -------------------------------------------------------------

## Adds a fish driven elsewhere (an online player's puppet) to the match; in a
## live round it spectates until the next.
func add_player(fish: FishController) -> void:
	if players.has(fish):
		return
	players.append(fish)
	_layers[fish] = [fish.collision_layer, fish.collision_mask]
	match_totals[fish] = match_totals.get(fish, 0.0)
	_tally[fish] = 0.0
	role[fish] = Role.PREY
	if authority:
		if phase == Phase.LIVE:
			eaten[fish] = true
		else:
			apply_role(fish, Role.PREY)


func remove_player(fish: FishController) -> void:
	if join != null:
		join.release(fish)
	players.erase(fish)
	role.erase(fish)
	eaten.erase(fish)
	_tally.erase(fish)
	_daze.erase(fish)
	_net_bite_at.erase(fish)
	satiation.erase(fish)
	queasy.erase(fish)
	match_totals.erase(fish)
	hunters.erase(fish)
	_drop_bite(fish)
	if _spectating == fish:
		_spectating = null
	if authority and phase == Phase.LIVE:
		_check_round_end()


## The fish people play (not bots).
func humans() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish in players:
		if not bots.has(fish):
			out.append(fish)
	return out


func _fill_with_bots() -> void:
	var names: Array = BOT_NAMES.duplicate()
	names.shuffle()
	for i in range(players.size(), maxi(settings.min_players, 2)):
		var fish: FishController = FISH_SCENE.instantiate()
		fish.name = "StinkBot%d" % i
		fish.character = FishCharacter.pickable_classes().pick_random()
		fish.display_name = String(names[i % names.size()])
		add_child(fish)
		Match1v1.copy_tuning(_local, fish)
		bots[fish] = null
		players.append(fish)


## The bot node for `fish` in `new_role`: the Hunter bot, or a wanderer round `home`.
func _set_bot(fish: FishController, new_role: int, home: Vector3) -> void:
	if not bots.has(fish):
		return
	var old: Variant = bots[fish]
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	var bot: Node
	if new_role == Role.HUNTER:
		var script := load(BOT_PATH) as GDScript
		bot = script.new()
		bot.set("fish", fish)
		bot.set("game", self)
	else:
		var wander := WhatStinksPreyBot.new()
		wander.game = self
		wander.fish = fish
		wander.home = home
		wander.pace = settings.prey_bot_pace
		bot = wander
	bot.name = "%sBot" % fish.name
	add_child(bot)
	bots[fish] = bot


# --- Rounds -----------------------------------------------------------------

## A new match from the first round.
func start_match() -> void:
	match_totals.clear()
	match_eaten.clear()
	spat_total.clear()
	for fish in players:
		match_totals[fish] = 0.0
	winner = null
	round_index = 0
	if authority:
		start_round(0)


## The order Hunters take their turns: each person once, then bot_hunter_rounds
## bots (in turn); the bots first with start_as Prey. No people: every bot.
func hunter_order() -> Array[FishController]:
	var people := humans()
	var robots: Array[FishController] = []
	for fish in players:
		if bots.has(fish):
			robots.append(fish)
	if people.is_empty():
		return robots
	var bot_turns: Array[FishController] = []
	if not robots.is_empty():
		for i in maxi(settings.bot_hunter_rounds, 0):
			bot_turns.append(robots[i % robots.size()])
	if settings.start_as == WhatStinksSettings.StartAs.PREY:
		bot_turns.append_array(people)
		return bot_turns
	people.append_array(bot_turns)
	return people


## Rounds in this match (settings.rounds; 0: one per Hunter turn).
func rounds_in_match() -> int:
	return settings.rounds if settings.rounds > 0 else maxi(hunter_order().size(), 1)


## Round `index`: its Hunter(s) at the ocean's spawn, the prey scattered.
func start_round(index: int) -> void:
	var order := hunter_order()
	var first: FishController = order[index % order.size()] if not order.is_empty() else players[0]
	var starting: Array[FishController] = [first]
	var others := players.duplicate()
	others.erase(first)
	others.shuffle()
	for i in mini(settings.hunters_per_round - 1, others.size() - 1):
		starting.append(others[i])
	var spawn := _hunter_start()
	var places := {}
	for fish in players:
		if starting.has(fish):
			places[fish] = spawn.translated(spawn.basis.x * 4.0 * starting.find(fish))
		else:
			places[fish] = _prey_spawn()
	_begin_round(index, starting, places)


func _begin_round(index: int, starting: Array[FishController], places: Dictionary, net_seed := -1, net_schools: Array = []) -> void:
	round_index = index
	hunters = starting
	round_places = places
	eaten.clear()
	_tally.clear()
	combos.clear()
	_ram_left.clear()
	round_eaten = 0
	round_spat = 0
	_daze.clear()
	satiation.clear()
	queasy.clear()
	hurled_out.clear()
	_spectating = null
	last_results = {}
	join.begin_round(players)  # everyone out of their schools before they're rebuilt
	field.prey_kinds.clear()
	field.steady = stomach()
	for fish in players:
		if not starting.has(fish) and not field.prey_kinds.has(join.class_of(fish)):
			field.prey_kinds.append(join.class_of(fish))
	var ocean_seed := net_seed if net_seed >= 0 else _rng.randi() & 0x7fffffff
	last_seed = ocean_seed
	if net_schools.is_empty():
		field.build(center, ocean_seed)
	else:
		field.build_list(center, net_schools)  # a guest: the host's schools
	shadows.build(center, ocean_seed ^ 0x5bd1e99)
	echo.begin_round(players)
	var school_homes: Array[Vector3] = []
	for school in field.schools:
		school_homes.append(school.middle())
	for fish in players:
		_tally[fish] = 0.0
		var as_hunter := starting.has(fish)
		role[fish] = Role.HUNTER if as_hunter else Role.PREY
		_restore_layers(fish)
		fish.visible = true
		fish.freeze = fish.puppet
		fish.controls_locked = false
		if not fish.puppet:
			if bots.has(fish):
				Match1v1.copy_tuning(_local, fish)  # tuning changes since the last round apply to bots too
			if places.has(fish):
				fish.revive(places[fish] as Transform3D)
			fish.linear_velocity = Vector3.ZERO
			fish.angular_velocity = Vector3.ZERO
		apply_role(fish, role[fish], school_homes)
	for fish in starting:
		if not fish.puppet:
			fish.controls_locked = true  # held at the start while the prey scatter
	field.set_threats(hunters)
	refresh_alarm()
	for hunter in hunters:
		satiation[hunter] = settings.satiation_max * settings.satiation_start
		queasy[hunter] = 0.0
	_set_phase(Phase.COUNTDOWN)
	phase_left = settings.hide_time
	time_left = settings.round_time
	if is_instance_valid(camera):
		camera.set("target", null)
		if camera.has_method("snap"):
			camera.call_deferred("snap")
	round_started.emit(index, hunters)
	_announce_local_role()


## Role values come with the role. A Hunter wears the form's monster body at the
## size dial's size (HunterSize.apply) with its Bite; prey are the player's own
## class and values again. `homes`: where a prey bot roams (a school's middle).
func apply_role(fish: FishController, new_role: int, homes: Array[Vector3] = []) -> void:
	var hunter := new_role == Role.HUNTER
	if hunter:
		_become_hunter(fish)
	else:
		_drop_bite(fish)
		_restore_look(fish)
		_restore_values(fish)
		fish.team = 0
		if fish == _local and is_instance_valid(camera):
			if "body_follow" in camera:
				camera.set("body_follow", 1.0)
			if "extra_distance" in camera:
				camera.set("extra_distance", 0.0)
				camera.set("extra_height", 0.0)
	var home := center
	if not hunter and not homes.is_empty():
		home = homes[_rng.randi() % homes.size()]
		if stomach() and settings.prey_bot_baits:
			home = _bait_home(homes)
	_set_bot(fish, new_role, home)
	role_changed.emit(fish, new_role)


## A school's middle among the third nearest the Hunter's start: prey that want to be mistaken for food wait where it hunts first.
func _bait_home(homes: Array[Vector3]) -> Vector3:
	var from := _hunter_start().origin
	var sorted := homes.duplicate()
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(from) < b.distance_squared_to(from))
	return sorted[_rng.randi() % maxi(ceili(sorted.size() / 3.0), 1)]


func _become_hunter(fish: FishController) -> void:
	_drop_bite(fish)  # first: it hands back the speed and turn a held bite cost, before the size is applied
	var form := settings.form_sheet()
	if not bool(fish.get_meta("ws_swapped", false)):
		fish.set_meta("ws_base_look", [int(fish.character), fish.species, fish.skin])
		fish.set_meta("ws_swapped", true)
	if fish.character != form["class"] or fish.species != int(form["species"]):
		fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	HunterForms.dress(fish, str(form.get("key", "")))
	fish.boost_enabled = false
	fish.team = 1
	var bite := HunterBite.new()
	bite.name = "HunterBite"
	bite.settings = settings
	bite.world = self
	fish.add_child(bite)
	bite.setup(fish, form, size)
	bite.fx().prey_source = live_prey
	bite.fx().may_unlock = func() -> bool: return phase == Phase.LIVE and not hurled_out.has(fish)
	bite.chomped.connect(_on_chomp.bind(fish, bite))
	bite.opened.connect(func() -> void:
		bite_started.emit(fish)
		refresh_alarm())
	bite.released.connect(func(charge: float) -> void:
		bite_closed.emit(fish, charge)
		refresh_alarm())
	bite.aborted.connect(func() -> void:
		bite_closed.emit(fish, -1.0)
		refresh_alarm())
	bites[fish] = bite
	if fish == _local and is_instance_valid(camera):
		size.frame(camera, fish, form)


## A Hunter's form changed mid-round (the pause menu's Change Character): the new
## form's body now, from a fresh model (the old form's rig goes with it).
func refresh_form(fish: FishController) -> void:
	if not is_hunter(fish):
		return
	var form := settings.form_sheet()
	fish.set_look(form["class"], int(form["species"]), 0)
	_become_hunter(fish)


func _drop_bite(fish: FishController) -> void:
	var bite: Variant = bites.get(fish)
	bites.erase(fish)
	if bite != null and is_instance_valid(bite):
		(bite as HunterBite).release_fish()
		(bite as Node).queue_free()
		refresh_alarm()  # an open mouth no longer counts


## The fish's own class and species again (a Hunter swapped them).
func _restore_look(fish: FishController) -> void:
	if not is_instance_valid(fish) or not bool(fish.get_meta("ws_swapped", false)):
		return
	var base: Array = fish.get_meta("ws_base_look", [int(fish.character), fish.species, fish.skin])
	fish.set_meta("ws_swapped", false)
	fish.set_look(int(base[0]) as FishCharacter.FishClass, int(base[1]), int(base[2]))


func _restore_values(fish: FishController) -> void:
	for key: String in _player_base:
		fish.set(key, _player_base[key])
	var model: Node = fish.get("_visual")
	if model != null and model.has_meta("titan_lod_rescale"):
		(model.get_meta("titan_lod_rescale") as Callable).call(fish.body_scale)


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


func _physics_process(delta: float) -> void:
	_keep_in_arena(delta)
	if not authority:
		_guest_step(delta)
		return
	match phase:
		Phase.COUNTDOWN:
			phase_left -= delta
			if phase_left <= 0.0:
				_go_live()
		Phase.LIVE:
			_live_step(delta)
		Phase.ROUND_OVER:
			phase_left -= delta
			if phase_left <= 0.0:
				if round_index + 1 < rounds_in_match():
					start_round(round_index + 1)
				else:
					_finish_match()
		Phase.OVER:
			phase_left -= delta
			if phase_left <= 0.0:
				start_match()


func _process(delta: float) -> void:
	_local_input()
	_update_spectating(delta)


func _go_live() -> void:
	for fish in hunters:
		if not fish.puppet:
			fish.controls_locked = false
	_set_phase(Phase.LIVE)
	time_left = settings.round_time


func _live_step(delta: float) -> void:
	time_left -= delta
	for fish in live_prey():
		_tally[fish] = float(_tally.get(fish, 0.0)) + settings.survive_points * delta
	if stomach():
		_stomach_step(delta)
		if phase != Phase.LIVE:
			return
	_ram_step(delta)
	if phase != Phase.LIVE:
		return
	if time_left <= 0.0:
		_end_round(false, "hungry" if stomach() else "clock")
		return
	_check_round_end()


## A Hunter's body at speed batters what its front touches (ram_speed x its size's speed):
## school fish and prey players in its hitbox's front are taken like a bite's, with no chew delay.
func _ram_step(delta: float) -> void:
	if not settings.ram:
		return
	for hunter in hunters:
		if not is_instance_valid(hunter) or hunter.puppet or hunter.battered or hunter.controls_locked or hurled_out.has(hunter):
			continue
		var tracker: NatureScore = combos.get(hunter)
		if tracker != null:
			tracker.update(delta, hunter.speed, settings.ram_speed * pow(size.size_of(hunter), size.speed_exp))
		var left := maxf(float(_ram_left.get(hunter, 0.0)) - delta, 0.0)
		_ram_left[hunter] = left
		var bite: HunterBite = bites.get(hunter)
		if bite == null or left > 0.0 or hunter.speed < settings.ram_speed * pow(size.size_of(hunter), size.speed_exp) or bite.attack.suppresses_ram(bite):
			continue
		var forward := -hunter.global_basis.z.normalized()
		var origin := hunter.global_position
		var length := hunter.hitbox_length
		var inside := func(at: Vector3) -> bool:
			var off := at - origin
			var along := off.dot(forward)
			return along >= 0.0 and along <= length * 0.6 and (off - forward * along).length() <= length * settings.ram_width
		var before := rammed_total
		_judge_bite(hunter, bite, origin + forward * length * 0.3, maxi(1, roundi(bite.capacity() * settings.ram_capacity_mult)), inside, null, true)
		if rammed_total > before:
			_ram_left[hunter] = settings.ram_cooldown


func _check_round_end() -> void:
	if authority and phase == Phase.LIVE and not stomach() and live_prey().is_empty():
		_end_round(true, "all_eaten")


## Hunger drains the bar, the queasiness settles, the daze wears off.
func _stomach_step(delta: float) -> void:
	for hunter in hunters:
		if hurled_out.has(hunter):
			continue
		if float(satiation.get(hunter, 0.0)) >= settings.satiation_max:
			_end_round(true, "full")
			return
		satiation[hunter] = maxf(float(satiation.get(hunter, 0.0)) - settings.satiation_decay * delta, 0.0)
		queasy[hunter] = maxf(float(queasy.get(hunter, 0.0)) - settings.queasy_decay * delta, 0.0)
	for prey: Variant in _daze.keys():
		_daze[prey]["left"] = float(_daze[prey]["left"]) - delta
		if float(_daze[prey]["left"]) <= 0.0:
			_undaze(prey)


func _undaze(prey: Variant) -> void:
	var was: Dictionary = _daze.get(prey, {})
	_daze.erase(prey)
	if is_instance_valid(prey) and not was.is_empty():
		(prey as FishController).boost_enabled = bool(was["boost"])


func _end_round(hunters_won: bool, reason := "") -> void:
	if reason == "":
		reason = "all_eaten" if hunters_won else "clock"
	for prey: Variant in _daze.keys():
		_undaze(prey)
	time_left = maxf(time_left, 0.0)
	if hunters_won:
		for hunter in hunters:
			_tally[hunter] = float(_tally.get(hunter, 0.0)) + settings.time_bonus * time_left / maxf(settings.round_time, 0.001)
	else:
		for fish in live_prey():
			_tally[fish] = float(_tally.get(fish, 0.0)) + settings.survivor_bonus
	for fish in players:
		match_totals[fish] = float(match_totals.get(fish, 0.0)) + float(_tally.get(fish, 0.0))
	last_results = {"hunters_won": hunters_won, "points": _tally.duplicate(), "eaten": round_eaten,
			"survivors": live_prey(), "hunters": hunters.duplicate(), "reason": reason, "spat": round_spat,
			"satiation": satiation.duplicate(), "queasy": queasy.duplicate()}
	_set_phase(Phase.ROUND_OVER)
	phase_left = settings.round_over_time
	for fish in hunters:
		if not fish.puppet:
			fish.controls_locked = true
	round_over.emit(last_results)


func _finish_match() -> void:
	var best: FishController
	var best_points := -INF
	for fish: FishController in match_totals:
		if float(match_totals[fish]) > best_points:
			best_points = float(match_totals[fish])
			best = fish
	winner = best
	_set_phase(Phase.OVER)
	phase_left = settings.match_over_time
	match_over.emit(winner)


# --- Getters ----------------------------------------------------------------

func role_of(fish: FishController) -> int:
	return int(role.get(fish, Role.PREY))


## Whether the local player sees `fish`'s name plate (Hud.plate_filter): the
## Hunter sees none of the prey's (it must read the crowd, not the names).
func shows_plate(fish: FishController) -> bool:
	if local_view_role() != Role.HUNTER or is_spectating():
		return true
	return role_of(fish) == Role.HUNTER


## Whether this is Upset Stomach.
func stomach() -> bool:
	return settings.variant == WhatStinksSettings.Variant.STOMACH


## A Hunter's satiation and queasy as shares of their bars (0..1).
func satiation_share(hunter: FishController) -> float:
	return clampf(float(satiation.get(hunter, 0.0)) / maxf(settings.satiation_max, 0.001), 0.0, 1.0)


func queasy_share(hunter: FishController) -> float:
	return clampf(float(queasy.get(hunter, 0.0)) / maxf(settings.queasy_max, 0.001), 0.0, 1.0)


func is_dazed(fish: FishController) -> bool:
	return _daze.has(fish)


## The schools' alarm range: the biggest Hunter's size, x hold_alarm_mult for one with its jaws open.
func refresh_alarm() -> void:
	if field == null:
		return
	var alarm := 0.0
	for hunter in hunters:
		var holding: HunterBite = bites.get(hunter)
		alarm = maxf(alarm, size.alarm_radius(hunter, 1.0) * (settings.hold_alarm_mult if holding != null and holding.holding() else 1.0))
	if hunters.is_empty():
		alarm = 1.0
	field.set_alarm_scale(alarm)


func is_hunter(fish: FishController) -> bool:
	return role_of(fish) == Role.HUNTER


func is_live_prey(fish: FishController) -> bool:
	return role_of(fish) == Role.PREY and not eaten.has(fish) and is_instance_valid(fish)


func live_prey() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish in players:
		if is_live_prey(fish):
			out.append(fish)
	return out


func local_fish() -> FishController:
	return _local


# The questions HiderLooks asks of a match (Marco Polo's names).

func is_live_hider(fish: FishController) -> bool:
	return is_live_prey(fish)


func seekers() -> Array[FishController]:
	return hunters


## How clearly the local Hunter sees `prey` (0..1: max of noise and echo); 0 when the local player isn't a Hunter.
func local_exposure(prey: FishController) -> float:
	if echo == null or local_view_role() != Role.HUNTER or not hunters.has(_local):
		return 0.0
	return echo.exposure(_local, prey)


## The clearest any Hunter sees `prey` (the prey's self view).
func max_exposure(prey: FishController) -> float:
	return echo.max_exposure(prey) if echo != null else 0.0


## HUNTER when the local player is a Hunter, else PREY (the eaten too).
func local_view_role() -> int:
	return role_of(_local)


func spectate_target() -> FishController:
	return _spectating


func totals() -> Dictionary:
	return match_totals


## The local player's points so far this round (their own HUD only).
func own_round_tally(fish: FishController) -> float:
	return float(_tally.get(fish, 0.0))


# --- The Bite and eating ----------------------------------------------------

## A Hunter's jaws shut: it takes the `capacity` fish nearest the bite point in
## its frustum (school fish and live prey players).
func _on_chomp(_mouth: Vector3, reach: float, _radius: float, _capacity: int, hunter: FishController, bite: HunterBite) -> void:
	if hunter.puppet:
		return  # a guest's Hunter: judged when its machine reports the landing (judge_net_bite)
	var forward := -hunter.global_basis.z.normalized()
	if not authority:
		local_bite.emit(bite.mouth_point(), forward, bite.strike_charge(), bite.attack.net_extra(bite))  # ours, on a guest: the host judges it
		return
	if phase != Phase.LIVE:
		return
	var rule := bite.attack.catch_rule(bite)  # the style's say on what the bite catches
	if bool(rule.get("frustum", true)):
		var locked := _locked_bite(hunter, bite, int(rule["capacity"]), reach)
		if not locked.is_empty():
			var mouth := bite.mouth_point()
			var span: float = locked["range"]
			rule["point"] = mouth
			rule["capacity"] = int(locked["capacity"])
			rule["inside"] = func(at: Vector3) -> bool: return at.distance_to(mouth) <= span
			rule["only"] = locked["school"]
	_judge_rule(hunter, bite, rule)


## A style's catch rule (HunterAttack.catch_rule) judged.
func _judge_rule(hunter: FishController, bite: HunterBite, rule: Dictionary) -> void:
	_judge_bite(hunter, bite, rule["point"], int(rule["capacity"]), rule["inside"], rule.get("only"), false, rule.get("extra", []))


## A bite while locked on a school (the local Hunter's lock-on): it takes fish from that school alone,
## the nearest to the mouth within lock_bite_range x reach, however many its line-up earns: how squarely
## it faces the school, how close it is and how fast it closes. Empty: not locked or too far (the plain bite).
func _locked_bite(hunter: FishController, bite: HunterBite, capacity: int, reach: float) -> Dictionary:
	if not settings.lock_bite or lock_cam == null or hunter != _local:
		return {}
	var focus := lock_cam.focus_of(hunter)
	var school := focus.get_parent() as School if focus != null else null
	if school == null or not field.schools.has(school):
		return {}
	var mouth := bite.mouth_point()
	var span := reach * settings.lock_bite_range
	var nearest := INF
	var centre := Vector3.ZERO
	var seen := 0
	for i in school.fish_count():
		if school.is_alive(i) and not school.is_claimed(i):
			var at := school.fish_position(i)
			nearest = minf(nearest, at.distance_to(mouth))
			centre += at
			seen += 1
	if seen == 0 or nearest > span:
		return {}
	var to_school := (centre / seen - hunter.global_position).normalized()
	var facing := clampf((-hunter.global_basis.z.dot(to_school) - 0.2) / 0.8, 0.0, 1.0)
	var close := 1.0 - clampf(nearest / maxf(span, 0.001), 0.0, 1.0)
	var top := maxf(hunter.max_boost_speed * hunter.top_speed_scale, 0.1)
	var rush := clampf(hunter.linear_velocity.dot(to_school) / (top * 0.6), 0.0, 1.0)
	var weights := settings.lock_w_angle + settings.lock_w_close + settings.lock_w_speed
	var score := (facing * settings.lock_w_angle + close * settings.lock_w_close + rush * settings.lock_w_speed) / maxf(weights, 0.001)
	var share := lerpf(settings.lock_bite_floor, 1.0, score)
	return {"school": school, "range": span, "capacity": maxi(1, roundi(capacity * settings.lock_bite_mult * share))}


## The camera lock-on's bonus on a bite at `school` (D8, the Fallen Angel's lock stacks with it): the multiplier
## the locked bite would give (1 when the camera is not locked on that school, or off).
func lock_stack_mult(hunter: FishController, bite: HunterBite, school: School) -> float:
	var locked := _locked_bite(hunter, bite, 100, bite.reach())
	if locked.is_empty() or locked["school"] != school:
		return 1.0
	return maxf(float(locked["capacity"]) / 100.0, 1.0)


## The host: a guest's Hunter reports a landed bite from `mouth` along `forward`. The reach, radius and
## capacity are the host's own for that Hunter (the form and size); too soon after the last is ignored.
func judge_net_bite(hunter: FishController, mouth: Vector3, forward: Vector3, charge := 0.0, extra := {}) -> void:
	var bite: HunterBite = bites.get(hunter)
	if not authority or phase != Phase.LIVE or bite == null or not is_hunter(hunter) or hurled_out.has(hunter) or not forward.is_finite() or not mouth.is_finite():
		return
	var now := Time.get_ticks_msec()
	if now - int(_net_bite_at.get(hunter, -100000)) < int(float(bite.form["bite_every"]) * 400.0):
		return
	if mouth.distance_to(hunter.global_position) > maxf(hunter.hitbox_length * 2.0, 8.0) + bite.reach():
		return  # nowhere near where we see that Hunter
	_net_bite_at[hunter] = now
	var held := clampf(minf(charge, bite.net_cap), 0.0, 1.0) if is_finite(charge) else 0.0  # no more than the host saw it hold
	bite.net_cap = 0.0
	_judge_rule(hunter, bite, bite.attack.net_catch_rule(bite, mouth, forward.normalized(), held, extra))


## The Lamprey Queen's drill (DrillAttack): the tube her disc swept this tick judged as a bite of up to `capacity` fish. The run's
## chew delay is added once, when the dash ends, so the cooldown is left as it was.
func judge_drill(hunter: FishController, bite: HunterBite, point: Vector3, capacity: int, inside: Callable) -> void:
	if not authority or phase != Phase.LIVE or hurled_out.has(hunter):
		return
	var cooldown := bite.cooldown
	_judge_bite(hunter, bite, point, capacity, inside)
	bite.cooldown = cooldown


## The Hunter's callouts for a bite or ram that took `school_fish` and the `prey` players: each fish taken adds
## to its chain (a Double Dip and up when several go at once or in quick succession) and its spree.
func _call_out(hunter: FishController, school_fish: int, prey: Array, ram: bool) -> void:
	var count := school_fish + prey.size()
	if count <= 0:
		return
	var score: NatureScore = combos.get(hunter)
	if score == null:
		score = NatureScore.new(NatureSettings.shared())
		combos[hunter] = score
	var events: Array = []
	var collect := func(event: Dictionary) -> void: events.append(event)
	score.awarded.connect(collect)
	for i in count:
		score.on_battery()
	score.awarded.disconnect(collect)
	var last: Dictionary = {}
	for event: Dictionary in events:
		if event.type == NatureScore.SPREE:
			continue
		last = event
	var source := "ram" if ram else "bite"
	if not last.is_empty():
		last = last.duplicate()
		last["count"] = count
		last["source"] = source
		last["prey"] = prey
		if int(last["chain"]) < 2:
			last["title"] = "RAMMED" if ram else ("CHOMP" if count == 1 else "BIG CHOMP")
		callout.emit(hunter, last)
	for event: Dictionary in events:
		if event.type == NatureScore.SPREE:
			var spree: Dictionary = event.duplicate()
			spree["source"] = source
			spree["count"] = count
			spree["prey"] = []
			callout.emit(hunter, spree)


## A landed bite at `point` taking up to `capacity` of what `inside` holds (the host's).
func _judge_bite(hunter: FishController, bite: HunterBite, point: Vector3, capacity: int, inside: Callable, only: School = null, ram := false, held: Array = []) -> void:
	var extra: Array = []
	if settings.bite_takes_players:
		extra.append_array(live_prey())
	for fish: FishController in held:
		if not extra.has(fish):
			extra.append(fish)
	var taken := field.eat_at(point, capacity, inside, extra, only)
	var penalty := 0.0 if ram else settings.chew_delay
	_call_out(hunter, int(taken["school_fish"]), [] if stomach() else taken["fish"], ram)
	if ram:
		rammed_total += int(taken["school_fish"]) + (taken["fish"] as Array).size()
	var prey: Array = taken["fish"]
	bite_result.emit(hunter, taken["taken"], prey)
	if not ram:
		bite.report_landing(int(taken["school_fish"]) + prey.size())
	bite.fx().prey_caught(prey, bite.mouth_point())
	if not ram:
		bite.attack.on_close(bite, taken)
	if stomach():
		_feed(hunter, float(taken["mass"]) * settings.satiation_per_fish)
		for fish: FishController in prey:
			_spit(fish, hunter, bite.mouth_point())
		if not prey.is_empty():
			penalty += settings.spit_cooldown
	else:
		for fish: FishController in prey:
			_eat(fish, hunter)
	bite.cooldown += penalty
	if hunter.puppet:
		bite_penalty.emit(hunter, penalty)  # a guest's own bite waits that long too
	bitten.emit(hunter, int(taken["school_fish"]), prey)
	if stomach() and phase == Phase.LIVE and float(satiation.get(hunter, 0.0)) >= settings.satiation_max and not hurled_out.has(hunter):
		_end_round(true, "full")


## Upset Stomach: `gain` satiation for the Hunter, and its points.
func _feed(hunter: FishController, gain: float) -> void:
	if gain <= 0.0 or hurled_out.has(hunter):
		return
	var before := float(satiation.get(hunter, 0.0))
	satiation[hunter] = minf(before + gain, settings.satiation_max)
	var earned := float(satiation[hunter]) - before
	_tally[hunter] = float(_tally.get(hunter, 0.0)) + earned * settings.satiation_points
	fed.emit(hunter, earned)


## Upset Stomach: a prey player in the bite is flung away from the mouth, dazed (no
## boost, no joining) and not eaten; the Hunter loses satiation and gets queasy,
## and hurls when the queasy bar maxes.
func _spit(prey: FishController, hunter: FishController, mouth: Vector3) -> void:
	round_spat += 1
	spat_total[hunter] = int(spat_total.get(hunter, 0)) + 1
	satiation[hunter] = maxf(float(satiation.get(hunter, 0.0)) - settings.spit_satiation_loss, 0.0)
	queasy[hunter] = float(queasy.get(hunter, 0.0)) + settings.queasy_per_spit
	_tally[prey] = float(_tally.get(prey, 0.0)) + settings.spit_points
	var away := prey.global_position - mouth
	if away.length_squared() < 0.0001:
		away = -hunter.global_basis.z
	var fling := (away.normalized() + Vector3.UP * 0.25).normalized() * settings.spit_speed
	if not prey.puppet:
		prey.freeze = false
		prey.linear_velocity = fling
		prey.angular_velocity = Vector3.ZERO
	if settings.spit_daze > 0.0:
		if not _daze.has(prey):
			_daze[prey] = {"left": settings.spit_daze, "boost": prey.boost_enabled}
		_daze[prey]["left"] = settings.spit_daze
		prey.boost_enabled = false
		if join != null:
			join.cooldown[prey] = maxf(float(join.cooldown.get(prey, 0.0)), settings.spit_daze)
	spat.emit(prey, hunter)
	spit_applied.emit(prey, hunter, fling, settings.spit_daze)
	if float(queasy[hunter]) >= settings.queasy_max and not hurled_out.has(hunter):
		_hurl(hunter)


## The Hunter's queasy bar maxed: it hurls, held for the rest of the round. The prey win once every Hunter has.
func _hurl(hunter: FishController) -> void:
	hurled_out[hunter] = true
	if not hunter.puppet:
		hunter.controls_locked = true
	hurled.emit(hunter)
	for other in hunters:
		if not hurled_out.has(other):
			return
	_end_round(false, "hurled")


## `prey` is eaten by `hunter`: out of the round, hidden, and spectating if it's ours.
func _eat(prey: FishController, hunter: FishController) -> void:
	if eaten.has(prey):
		return
	eaten[prey] = true
	round_eaten += 1
	match_eaten[hunter] = int(match_eaten.get(hunter, 0)) + 1
	_tally[hunter] = float(_tally.get(hunter, 0.0)) + settings.tag_points
	if live_prey().is_empty():
		_tally[prey] = float(_tally.get(prey, 0.0)) + settings.last_fish_bonus
	prey.visible = false
	if not prey.puppet:
		prey.freeze = true
		prey.controls_locked = true
	prey.collision_layer = 0
	prey.collision_mask = 0
	eaten_fish.emit(prey, hunter)
	if prey == _local:
		_spectate(_nearest_live_prey(prey.global_position))
	elif prey == _spectating:
		_spectate(_nearest_live_prey(prey.global_position))
	_announce_local_role()
	_check_round_end()


func _restore_layers(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	var saved: Array = _layers.get(fish, [])
	if saved.size() == 2:
		fish.collision_layer = int(saved[0])
		fish.collision_mask = int(saved[1])


# --- Spectating (eaten prey) --------------------------------------------------

func _spectate(fish: FishController) -> void:
	_spectating = fish
	if is_instance_valid(camera):
		camera.set("target", fish)
		if camera.has_method("snap"):
			camera.call("snap")
	spectate_target_changed.emit(fish)


## The next (step 1) or previous (-1) live prey to watch.
func cycle_spectate(step: int) -> void:
	var live := live_prey()
	if live.is_empty():
		return
	var at := live.find(_spectating)
	_spectate(live[posmod(at + step, live.size())] if at >= 0 else live[0])


## The live prey nearest `from`, else a Hunter (so the camera always has something to watch).
func _nearest_live_prey(from: Vector3) -> FishController:
	var best: FishController
	var best_gap := INF
	for fish in live_prey():
		var gap := fish.global_position.distance_squared_to(from)
		if gap < best_gap:
			best_gap = gap
			best = fish
	if best == null and not hunters.is_empty():
		best = hunters[0]
	return best


func is_spectating() -> bool:
	return is_instance_valid(_local) and eaten.has(_local)


func _update_spectating(_delta: float) -> void:
	if not is_spectating():
		return
	if not is_instance_valid(_spectating) or (role_of(_spectating) == Role.PREY and not is_live_prey(_spectating)):
		_spectate(_nearest_live_prey(_local.global_position))


func _local_input() -> void:
	if not is_instance_valid(_local) or Console.is_open() or get_tree().paused:
		return
	var input: PlayerInput = _local.input_source if _local.input_source else PlayerInput.everyone()
	if is_spectating():
		if input.just_pressed(&"ui_page_next") or input.just_pressed(&"ui_right"):
			cycle_spectate(1)
		elif input.just_pressed(&"ui_page_previous") or input.just_pressed(&"ui_left"):
			cycle_spectate(-1)


func _announce_local_role() -> void:
	var now := local_view_role()
	if now != _local_role:
		_local_role = now
		local_role_changed.emit(now)


# --- Online guests (WhatStinksNet) -------------------------------------------------
# The host judges everything; a guest shows what the host sends. These are the
# guest's side of each message, and mirror what the host's own code did.

## A guest: the clocks run on between the host's updates; a spat prey's daze runs out.
func _guest_step(delta: float) -> void:
	if phase == Phase.LIVE:
		time_left = maxf(time_left - delta, 0.0)
	else:
		phase_left = maxf(phase_left - delta, 0.0)
	for prey: Variant in _daze.keys():
		_daze[prey]["left"] = float(_daze[prey]["left"]) - delta
		if float(_daze[prey]["left"]) <= 0.0:
			_undaze(prey)


## A guest: a round starts on the host's say (its Hunters, our own place, everyone's totals, the ocean).
func apply_net_round(index: int, starting: Array[FishController], place: Transform3D, totals_now: Dictionary, rounds: int, ocean_seed: int, schools: Array) -> void:
	settings.rounds = rounds
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	_begin_round(index, starting, {_local: place}, ocean_seed, schools)


## A guest joining late: the match as it is (the round's schools, who's eaten, the clocks).
func apply_net_world(index: int, starting: Array[FishController], eaten_now: Array[FishController], phase_now: int, phase_left_now: float,
		time_left_now: float, totals_now: Dictionary, rounds: int, ocean_seed: int, schools: Array) -> void:
	settings.rounds = rounds
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	_begin_round(index, starting, {}, ocean_seed, schools)
	_set_phase(phase_now)
	phase_left = phase_left_now
	time_left = time_left_now
	for fish in eaten_now:
		_eat(fish, starting[0] if not starting.is_empty() else null)
	if phase_now != Phase.COUNTDOWN:
		for fish in starting:
			if not fish.puppet:
				fish.controls_locked = phase_now != Phase.LIVE


func apply_net_phase(new_phase: int, phase_left_now: float, time_left_now: float) -> void:
	if new_phase == Phase.LIVE:
		for fish in hunters:
			if not fish.puppet:
				fish.controls_locked = false
	_set_phase(new_phase)
	phase_left = phase_left_now
	time_left = time_left_now


## The host's clocks (a few times a second), when we're in the phase they're for.
func apply_net_clock(phase_now: int, phase_left_now: float, time_left_now: float) -> void:
	if phase_now == phase:
		phase_left = phase_left_now
		time_left = time_left_now


## A guest: what a bite took: the school fish (the same places), and in Clean Sweep the prey players eaten.
func apply_net_bite(hunter: FishController, taken: Dictionary, prey_list: Array) -> void:
	field.eat_taken(taken)
	var count := 0
	for id: Variant in taken:
		count += ((taken[id] as Array)[0] as Array).size()
	if not stomach():
		for fish: FishController in prey_list:
			_eat(fish, hunter)
	var guest_bite: HunterBite = bites.get(hunter)
	if guest_bite != null:
		guest_bite.fx().prey_caught(prey_list, guest_bite.mouth_point())
	bitten.emit(hunter, count, prey_list)


## A guest: `prey` was spat out (flung and dazed here if it's ours).
func apply_net_spit(prey: FishController, hunter: FishController, velocity: Vector3, daze: float) -> void:
	round_spat += 1
	spat_total[hunter] = int(spat_total.get(hunter, 0)) + 1
	if not prey.puppet:
		prey.freeze = false
		prey.linear_velocity = velocity
		prey.angular_velocity = Vector3.ZERO
	if daze > 0.0:
		if not _daze.has(prey):
			_daze[prey] = {"left": daze, "boost": prey.boost_enabled}
		_daze[prey]["left"] = daze
		if not prey.puppet:
			prey.boost_enabled = false
		if join != null:
			join.cooldown[prey] = maxf(float(join.cooldown.get(prey, 0.0)), daze)
	var spitter: HunterBite = bites.get(hunter)
	if spitter != null:
		spitter.fx().prey_caught([prey], spitter.mouth_point())
	spat.emit(prey, hunter)


func apply_net_hurl(hunter: FishController) -> void:
	hurled_out[hunter] = true
	if not hunter.puppet:
		hunter.controls_locked = true
	hurled.emit(hunter)


func apply_net_fed(hunter: FishController, gain: float) -> void:
	fed.emit(hunter, gain)


## The Hunters' bars (fish -> value), a few times a second.
func apply_net_stomach(satiation_now: Dictionary, queasy_now: Dictionary) -> void:
	for fish: FishController in satiation_now:
		satiation[fish] = float(satiation_now[fish])
	for fish: FishController in queasy_now:
		queasy[fish] = float(queasy_now[fish])


## A guest: the round is over (the host's results, fish-keyed) and everyone's totals.
func apply_net_round_over(results: Dictionary, totals_now: Dictionary) -> void:
	for prey: Variant in _daze.keys():
		_undaze(prey)
	time_left = maxf(time_left, 0.0)
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	last_results = results
	_set_phase(Phase.ROUND_OVER)
	phase_left = settings.round_over_time
	for fish in hunters:
		if not fish.puppet:
			fish.controls_locked = true
	round_over.emit(last_results)


func apply_net_match_over(best: FishController) -> void:
	winner = best
	_set_phase(Phase.OVER)
	phase_left = settings.match_over_time
	match_over.emit(winner)


# --- The arena ---------------------------------------------------------------

func _hunter_start() -> Transform3D:
	return environment.spawn_transform() if environment.has_method("spawn_transform") else Transform3D(Basis.IDENTITY, center)


## A place for a prey fish: a random point between prey_spawn_min and prey_spawn_max of the arena's radius.
func _prey_spawn() -> Transform3D:
	var share := lerpf(settings.prey_spawn_min, settings.prey_spawn_max, _rng.randf())
	var flat := Vector2.from_angle(_rng.randf() * TAU) * share * settings.arena_radius
	var at := center + Vector3(flat.x, _rng.randf_range(-6.0, 6.0), flat.y)
	return Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at)


## Past the wall (arena_radius): a push back in, as Hunt and Marco Polo's ocean.
func _keep_in_arena(delta: float) -> void:
	if not (environment is Ocean):
		return
	for fish in players:
		if not is_instance_valid(fish) or fish.freeze or fish.puppet or eaten.has(fish):
			continue
		var out := fish.global_position - center
		var past := out.length() - settings.arena_radius
		if past <= 0.0:
			continue
		var direction := out.normalized()
		var outward := maxf(fish.linear_velocity.dot(direction), 0.0)
		var push := minf(past * settings.wall_stiffness + outward * settings.wall_outward, settings.wall_max)
		fish.apply_push(-direction * push * delta)


func _wire_hud() -> void:
	if not ResourceLoader.exists(HUD_PATH):
		return
	var script := load(HUD_PATH) as GDScript
	if script == null or not script.can_instantiate():
		return
	_hud = script.new()
	_hud.name = "WhatStinksHud"
	add_child(_hud)
	_hud.call("bind", self)
