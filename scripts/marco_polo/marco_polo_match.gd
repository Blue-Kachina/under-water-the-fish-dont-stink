class_name MarcoPoloMatch
extends Node
## Marco Polo (planning_marco_polo.md): hide-and-seek by sound. Each round one
## fish is the seeker and the rest are hiders. Hiders score while they're in a
## seeker's line of sight (SightCone), visible or not, and more the further up
## the layers the seeker sees them; their noise (NoiseMeter) is what builds
## that exposure. A seeker tags a hider by touching them (Battery.touching, no
## speed rule; the seeker's big bow wave is their reach). What a catch does is
## the variant's (MarcoPoloSettings.variant): Last Fish Swimming eliminates
## the hider (they float up belly-up, then spectate a live fish), Join the
## Seekers makes them a seeker. A round is COUNTDOWN (the seeker held while the
## hiders scatter) -> LIVE (until every hider's caught or the clock runs out)
## -> ROUND_OVER (its points), and after the last round OVER.
##
## Watching (the camera button, Y, for hiders and spectators): a tap parks a
## live hider (its fish held still) and watches someone else, and a second tap
## goes back to its own follow cam; holding it opens the WatchWheel, a slice
## per fish, picked with the left stick, watched on letting go.
##
## Points never show live (§6): they go into a hidden round tally, shown on the
## round's card; own_round_tally() is only for the local hider's own HUD.
##
## The host judges everything (`authority`): roles, noise, sight, tags,
## portholes, decoys and the score. Online guests (authority off) show what the
## host sends (CoopSession's Marco Polo messages, apply_net_*()).
##
## Lives under the environment (setup() before adding it): the plain Ocean (a
## radius push like Hunt) or a MarcoArena. Bots fill the seats up to
## min_players. end() hands the player's fish back.

signal phase_changed(phase: int)
signal round_started(index: int, seeker: FishController)
signal role_changed(fish: FishController, role: int)
## how: "tag" or "out_of_water"; by: the seeker who tagged (null out of water).
signal caught(hider: FishController, how: String, by: FishController)
signal eliminated_fish(fish: FishController)
signal round_over(results: Dictionary)
## A ping on `seeker`'s sonar: where (already blurred for them), how loud, and
## whether it's an answer to "Marco!".
signal pinged(seeker: FishController, pos: Vector3, loudness: float, polo: bool)
signal marco_called(seeker: FishController)
## A "Marco!" scan starts from `origin` (the seeker where it called), on every
## machine: for the scan pulse's look (MarcoPoloSettings.marco_scan_time).
signal marco_scan_started(origin: Vector3, seeker: FishController)
signal fooled(seeker: FishController, fake: FishController)
signal spectate_target_changed(fish: FishController)
## The local player's role (as local_view_role()) changed.
signal local_role_changed(role: int)
## Two fish bumped into each other (fish-to-fish), at `speed` (m/s closing).
signal bumped(a: FishController, b: FishController, speed: float)
## The match is over: the fish with the most points (null on no one).
signal match_over(winner: FishController)
## A guest: our own hider made a burst of noise (`amount`, before masking), for the host.
signal local_burst(amount: float)
## A guest: our own player pressed "Marco!" or threw a Fake Fish ("marco" / "fake"), for the host.
signal local_button(action: String)
## The host: bots came or went (people joined online, so fewer are needed).
signal bots_changed

enum Role { HIDER, SEEKER }
enum Phase { COUNTDOWN, LIVE, ROUND_OVER, OVER }

const FISH_SCENE := preload("res://scenes/fish.tscn")
const BOT_NAMES := ["Guppy", "Minnow", "Tetra", "Danio", "Molly", "Platy", "Rasbora", "Barb", "Loach", "Pleco", "Gourami", "Cory"]
## The sounds (world's catalogue ids).
const SOUNDS := {"bump": "mp/bump", "tag": "mp/tag", "eliminated": "mp/eliminated", "marco": "mp/marco", "polo": "mp/polo",
		"round_over": "mp/round_over", "count": "mp/count", "seen": "mp/seen", "fooled": "mp/fooled",
		"ping": "mp/ping", "aura": "mp/aura", "heartbeat": "mp/heartbeat"}
## Where the helpers others own live (wired once they parse).
const SONAR_MAP_PATH := "res://scripts/marco_polo/sonar_map.gd"
const PORTHOLE_SYSTEM_PATH := "res://scripts/marco_polo/porthole_system.gd"
const BOT_PATH := "res://scripts/marco_polo/marco_polo_bot.gd"
const FAKE_FISH_PATH := "res://scripts/marco_polo/fake_fish.gd"
## Ocean spawns: hiders on a ring this far (m) round the seeker's start.
const OCEAN_SPAWN_RING := 22.0
## Past the Ocean arena's edge: pushed back in, as Hunt.
const BOUNDARY_STIFFNESS := 2.0
const BOUNDARY_OUTWARD := 2.0
const BOUNDARY_MAX := 30.0
## The console's commands.
const COMMANDS := ["mp_role", "mp_noise", "mp_expose", "mp_tag", "mp_eliminate", "mp_round", "mp_fake", "mp_porthole", "mp_cone"]

var settings := MarcoPoloSettings.shared()
## The environment: an Ocean or a MarcoArena (`arena`, null in the Ocean).
var environment: Node3D
var arena: Node3D
var porthole_system: Node
## The world's run here (the host's, or solo); off on an online guest.
var authority := true
## Every fish in the match (people's and bots'), never assuming two.
var players: Array[FishController] = []
## Fish -> its bot (bots only).
var bots := {}
## Fish -> Role.
var role := {}
## Fish -> true, once eliminated this round (Last Fish Swimming).
var eliminated := {}
var phase := Phase.COUNTDOWN
var round_index := 0
## The round clock (s), LIVE; and how long the current phase has left (COUNTDOWN, ROUND_OVER, OVER).
var time_left := 0.0
var phase_left := 0.0
## The round's starting seekers.
var starting_seekers: Array[FishController] = []
## Between-round totals: fish -> points.
var match_totals := {}
## Fish -> {MatchStats.TAG: n, MatchStats.SEEN: [points per layer], ...}.
var stats := {}
## The follow camera (this machine's view).
var camera: Node
## The arena's centre (the Ocean's spawn).
var center := Vector3.ZERO
## The winner once OVER.
var winner: FishController
## Where each fish started this round (fish -> Transform3D; the host sends each guest its own).
var round_places := {}

## This machine's own player.
var _local: FishController
## Hidden round tallies: fish -> points (host only; a guest has only its own).
var _tally := {}
## Fish (hider or decoy) -> NoiseMeter.
var _meters := {}
## Seeker -> {hider -> exposure}.
var _exposure := {}
## Fish -> seconds left of a hold (convert_hold, fooled_hold, tag_hold): no input, no tags.
var _hold := {}
## Seeker -> [{pos, loudness, time, polo}].
var _pings := {}
## Seeker -> seconds left of Marco's cooldown.
var _marco_left := {}
## Seeker -> seconds the hiders still see the Marco ring.
var _marco_ring := {}
## Decoy (a FakeFish's fish) -> its owner.
var _decoys := {}
## Hider -> Fake Fish charges left.
var _fake_charges := {}
## Eliminated fish still floating up: fish -> seconds left.
var _floating := {}
## The fish the local spectator (or parked hider) watches, and a pending move on (s; -1 none).
var _spectating: FishController
var _spectate_move_left := -1.0
## The local live hider is parked: its fish held still while it watches `_spectating`.
var _parked := false
## How long the camera button's been held (s; -1: not held), and the watch wheel.
var _watch_held := -1.0
var _wheel: WatchWheel
## Fish -> their collision [layer, mask] from before the match.
var _layers := {}
## Fish -> their linear velocity last tick (for bump speeds).
var _last_velocity := {}
## "a|b" (instance ids) -> seconds left of its bump cooldown.
var _bump_left := {}
## Hiders in a close call now (seen at muscular+ within close_call_range).
var _close := {}
## Hiders seen this tick: hider -> {seeker -> {layer, rate}} (host; for the debug cone and stats).
var _seen_now := {}
## The local player's role last announced.
var _local_role := -1
## Online: the host's values for the local machine (a guest's): hider -> exposure (local seeker's view).
var _net_exposure := {}
var _net_own_tally := 0.0
## A guest: fish the host says are in a porthole.
var _net_hidden := {}
## A guest: the pings the host sent for our own seeker.
var _net_pings: Array = []
## The player's own values from before the match, put back on end().
var _player_base := {}
var _sight: SightCone
var _hud: Node
var _looks: Node
var _sonar: Node
var _rng := RandomNumberGenerator.new()
var _time := 0.0
## The sound cues: the count's last whole second, each hider's last layer
## (the aura flare), each hider's next heartbeat.
var _count_second := -1
var _cue_layer := {}
var _heartbeat_left := {}


## `env`: the Ocean or a MarcoArena; `player_fish`: this machine's player;
## `follow_camera`: its camera.
func setup(env: Node3D, player_fish: FishController, follow_camera: Node = null) -> void:
	environment = env
	_local = player_fish
	camera = follow_camera
	arena = env if env.has_method("hider_spawns") else null
	if not players.has(player_fish):
		players.insert(0, player_fish)


func _ready() -> void:
	_rng.randomize()
	center = environment.spawn_transform().origin if environment.has_method("spawn_transform") else Vector3.ZERO
	_player_base = {"buoyancy": _local.buoyancy, "boost_enabled": _local.boost_enabled, "bow_scale": _local.bow_scale,
			"speed_scale": _local.speed_scale, "rl_surface_mechanics": _local.rl_surface_mechanics}
	if authority:
		_fill_with_bots()
	for fish in players:
		_layers[fish] = [fish.collision_layer, fish.collision_mask]
	_set_collisions(settings.fish_collide)
	if environment is Ocean and arena == null:
		(environment as Ocean).boundary_center = center
		(environment as Ocean).boundary_radius = settings.ocean_radius
	_sight = SightCone.new()
	_sight.name = "SightCone"
	add_child(_sight)
	_wire_helpers()
	if is_instance_valid(camera) and "pose_override" in camera:
		camera.set("pose_override", _porthole_pose)
	_register_commands()
	start_match()


## Hands the player's fish back. Call before freeing the match.
func end() -> void:
	_unregister_commands()
	_reset_portholes()
	for meter: NoiseMeter in _meters.values():
		meter.detach()
	_meters.clear()
	_set_collisions(true)
	if is_instance_valid(environment) and environment is Ocean and arena == null:
		(environment as Ocean).boundary_radius = 0.0
	if is_instance_valid(camera):
		camera.set("target", null)
		if "button_taken" in camera:
			camera.set("button_taken", false)
		if "pose_override" in camera:
			camera.set("pose_override", Callable())
		UnnaturalRun.steady_camera(camera, false, UnnaturalSettings.shared())
	if not is_instance_valid(_local):
		return
	for key: String in _player_base:
		_local.set(key, _player_base[key])
	_restore_layers(_local)
	_local.team = -1
	_local.controls_locked = false
	_local.freeze = false
	_local.visible = true


# --- The roster -------------------------------------------------------------

## Adds a fish driven elsewhere (an online player's puppet, or on a guest the
## host's bots) to the match. Joining during the countdown it hides; once the
## round's LIVE it spectates until the next round (on the host; a guest's
## roles come from the host).
func add_player(fish: FishController) -> void:
	if players.has(fish):
		return
	players.append(fish)
	_layers[fish] = [fish.collision_layer, fish.collision_mask]
	match_totals[fish] = match_totals.get(fish, 0.0)
	stats[fish] = _new_stats()
	_tally[fish] = 0.0
	role[fish] = Role.HIDER
	if not authority:
		return
	if phase == Phase.LIVE:
		eliminated[fish] = true  # joining mid-round: a spectator until the next round
	else:
		apply_role(fish, Role.HIDER)


func remove_player(fish: FishController) -> void:
	players.erase(fish)
	role.erase(fish)
	eliminated.erase(fish)
	_floating.erase(fish)
	_tally.erase(fish)
	match_totals.erase(fish)  # it's leaving (a bot trimmed, a player gone): off the board
	stats.erase(fish)
	_fake_charges.erase(fish)
	_hold.erase(fish)
	_cue_layer.erase(fish)
	_heartbeat_left.erase(fish)
	_net_exposure.erase(fish)
	_net_hidden.erase(fish)
	starting_seekers.erase(fish)
	if _spectating == fish:
		_spectating = null
	_exposure.erase(fish)
	for seen: Dictionary in _exposure.values():
		seen.erase(fish)
	if _meters.has(fish):
		(_meters[fish] as NoiseMeter).detach()
		_meters.erase(fish)
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
	var have := players.size()
	for i in range(have, maxi(settings.min_players, 2)):
		var fish: FishController = FISH_SCENE.instantiate()
		fish.name = "MarcoBot%d" % i
		fish.character = FishCharacter.CLASSES.keys().pick_random()
		fish.display_name = String(names[i % names.size()])
		add_child(fish)
		Match1v1.copy_tuning(_local, fish)
		var bot := _make_bot(fish)
		bots[fish] = bot
		players.append(fish)


## A bot for `fish`: world's MarcoPoloBot once it's there, else a WanderBot.
func _make_bot(fish: FishController) -> Node:
	var bot: Node
	if ResourceLoader.exists(BOT_PATH):
		var script := load(BOT_PATH) as GDScript
		if script and script.can_instantiate():
			bot = script.new()
	if bot == null:
		var wander := WanderBot.new()
		wander.fish = fish
		wander.home = center
		wander.pace = 0.5
		bot = wander
	else:
		bot.set("fish", fish)
	bot.name = "%sBot" % fish.name
	add_child(bot)
	if bot.has_method("bind"):
		bot.call("bind", self)
	return bot


# --- Rounds -----------------------------------------------------------------

## A new match from the first round.
func start_match() -> void:
	match_totals.clear()
	stats.clear()
	for fish in players:
		match_totals[fish] = 0.0
		stats[fish] = _new_stats()
	winner = null
	round_index = 0
	if authority:
		start_round(0)


## The order seekers take their turns: each person once, and bot_seeker_rounds
## bots (in turn) while the people hide; the people first, or the bots first
## with start_as Hider. No people: every bot.
func seeker_order() -> Array[FishController]:
	var people := humans()
	var robots: Array[FishController] = []
	for fish in players:
		if bots.has(fish):
			robots.append(fish)
	if people.is_empty():
		return robots
	var bot_turns: Array[FishController] = []
	if not robots.is_empty():
		for i in maxi(settings.bot_seeker_rounds, 0):
			bot_turns.append(robots[i % robots.size()])
	if settings.start_as == MarcoPoloSettings.StartAs.HIDER:
		bot_turns.append_array(people)
		return bot_turns
	people.append_array(bot_turns)
	return people


## Rounds in this match (settings.rounds; 0: one per person, plus bots with bot_seeker_rounds).
func rounds_in_match() -> int:
	return settings.rounds if settings.rounds > 0 else maxi(seeker_order().size(), 1)


## Round `index`: its seeker(s) start held at the seeker's start, the hiders
## scatter from theirs, everyone's role values applied (the host's call; a
## guest gets it from apply_net_round()).
func start_round(index: int) -> void:
	_trim_bots()
	var order := seeker_order()
	var first: FishController = order[index % order.size()] if not order.is_empty() else players[0]
	var starting: Array[FishController] = [first]
	var others := players.duplicate()
	others.erase(first)
	others.shuffle()
	for i in mini(settings.seekers - 1, others.size() - 1):
		starting.append(others[i])
	var spawns := _hider_spawns(players.size() - starting.size())
	var seeker_spot := _seeker_start()
	var spawn_at := 0
	var places := {}
	for fish in players:
		var at: Transform3D = seeker_spot
		if not starting.has(fish):
			at = spawns[spawn_at % spawns.size()]
			spawn_at += 1
		elif starting.find(fish) > 0:
			at = seeker_spot.translated(seeker_spot.basis.x * 3.0 * starting.find(fish))
		places[fish] = at
	_begin_round(index, starting, places)


## Every machine's start of a round: `starting` seek, everyone else hides; our
## own fish (and bots) go to `places` (fish -> Transform3D); puppets are placed
## by their own machines.
func _begin_round(index: int, starting: Array[FishController], places: Dictionary) -> void:
	_reset_portholes()  # everyone out before the new round unfreezes them
	round_index = index
	round_places = places
	starting_seekers = starting
	eliminated.clear()
	_floating.clear()
	_tally.clear()
	_exposure.clear()
	_pings.clear()
	_hold.clear()
	_close.clear()
	_marco_left.clear()
	_marco_ring.clear()
	_net_exposure.clear()
	_net_hidden.clear()
	_net_own_tally = 0.0
	_spectating = null
	_spectate_move_left = -1.0
	_parked = false
	_watch_held = -1.0
	if _wheel and _wheel.is_open:
		_wheel.close()
	_bump_left.clear()
	for fake: FishController in _decoys.keys():
		unregister_decoy(fake)
	for fish in players:
		_tally[fish] = 0.0
		var as_seeker := starting.has(fish)
		role[fish] = Role.SEEKER if as_seeker else Role.HIDER
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
		apply_role(fish, role[fish])
		_fake_charges[fish] = settings.fake_charges if not as_seeker else 0
	for fish in starting:
		if not fish.puppet:
			fish.controls_locked = true  # counting to ten, held at the start (neutral buoyancy)
	_set_phase(Phase.COUNTDOWN)
	phase_left = settings.hide_time
	time_left = settings.round_time
	if is_instance_valid(camera):
		camera.set("target", null)
		if camera.has_method("snap"):
			camera.call_deferred("snap")
	round_started.emit(index, starting[0] if not starting.is_empty() else null)
	_announce_local_role()


## Role values come with the role: boost, bow, buoyancy, speed, team (plan §1).
func apply_role(fish: FishController, new_role: int) -> void:
	var seeker := new_role == Role.SEEKER
	fish.boost_enabled = seeker and settings.seeker_boost
	fish.boost_amount = 100.0
	fish.bow_scale = settings.seeker_bow_scale if seeker else 1.0
	fish.buoyancy = settings.seeker_buoyancy if seeker else settings.hider_buoyancy
	fish.speed_scale = settings.seeker_speed_scale if seeker else 1.0
	fish.rl_surface_mechanics = settings.stick_to_surfaces
	fish.team = 1 if seeker else 0
	if seeker:
		_fake_charges[fish] = 0
		if _meters.has(fish):
			(_meters[fish] as NoiseMeter).detach()
			_meters.erase(fish)
		_exposure[fish] = {}
		_pings[fish] = []
		_marco_left[fish] = 0.0
	elif not _meters.has(fish) and (authority or fish == _local):
		_meters[fish] = _new_meter(fish)
	if _meters.has(fish):
		(_meters[fish] as NoiseMeter).reset()


## A fish's NoiseMeter. The host's ping the seekers; a guest keeps one for its
## own hider only (its HUD's noise ring), whose bursts go to the host (local_burst).
func _new_meter(fish: FishController) -> NoiseMeter:
	var meter := NoiseMeter.new(fish, settings)
	if arena and arena.has_method("bubble_mask_at"):
		meter.mask_at = Callable(arena, "bubble_mask_at")
	if authority:
		meter.pinged.connect(func(at: Vector3, loudness: float) -> void: _ping_seekers(at, loudness, false))
	elif fish == _local:
		meter.burst.connect(func(amount: float) -> void: local_burst.emit(amount))
	return meter


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


func _physics_process(delta: float) -> void:
	_time += delta
	_hold_parked()
	for fish in players:
		if is_instance_valid(fish) and fish.rl_surface_mechanics != settings.stick_to_surfaces:
			fish.rl_surface_mechanics = settings.stick_to_surfaces  # the panel's changes, live
	_float_eliminated(delta)
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
	if is_instance_valid(camera):
		camera.set("ball_cam", false)
		camera.set("hold_opens_wheel", false)  # Y swaps views, never a wheel
		# Unnatural's two views (follow and free cam, Y swaps them) for every role
		# and the spectator; a porthole's view (pose_override) comes first.
		UnnaturalRun.steady_camera(camera, true, UnnaturalSettings.shared())
	_local_input()
	_watch_button(delta)
	_update_spectating(delta)
	_draw_debug_cone()
	_sound_cues(delta)


func _go_live() -> void:
	for fish in starting_seekers:
		if not fish.puppet:
			fish.controls_locked = false
	_set_phase(Phase.LIVE)
	time_left = settings.round_time


func _live_step(delta: float) -> void:
	if porthole_system and porthole_system.has_method("step"):
		porthole_system.call("step", delta)
	_tick_holds(delta)
	_tick_marco(delta)
	for fish: FishController in _meters.keys():
		var meter: NoiseMeter = _meters[fish]
		meter.muted = is_hidden(fish) or eliminated.has(fish)
		meter.step(delta)
	_update_exposure(delta)
	_score_sight(delta)
	_check_bumps(delta)
	_check_tags()
	if phase != Phase.LIVE:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end_round()


## Holds (convert_hold, fooled_hold, tag_hold) run out: the fish's controls come back.
func _tick_holds(delta: float) -> void:
	for fish: FishController in _hold.keys():
		var left: float = _hold[fish] - delta
		if left <= 0.0:
			_hold.erase(fish)
			if is_instance_valid(fish) and not fish.puppet and not eliminated.has(fish) \
					and not (phase == Phase.COUNTDOWN and starting_seekers.has(fish)) and not (fish == _local and _parked):
				fish.controls_locked = false
		else:
			_hold[fish] = left


func _tick_marco(delta: float) -> void:
	for seeker: FishController in _marco_left.keys():
		_marco_left[seeker] = maxf(float(_marco_left[seeker]) - delta, 0.0)
	for seeker: FishController in _marco_ring.keys():
		_marco_ring[seeker] = maxf(float(_marco_ring[seeker]) - delta, 0.0)


## A guest's own tick: the holds, the Marco cooldowns and ring (as the host
## said), and our own hider's NoiseMeter (its bursts go to the host), counting
## the clocks down between the host's updates.
func _guest_step(delta: float) -> void:
	_tick_holds(delta)
	_tick_marco(delta)
	if phase == Phase.LIVE:
		time_left = maxf(time_left - delta, 0.0)
	else:
		phase_left = maxf(phase_left - delta, 0.0)
	for fish: FishController in _meters.keys():
		var meter: NoiseMeter = _meters[fish]
		meter.muted = phase != Phase.LIVE or is_hidden(fish) or eliminated.has(fish)
		meter.step(delta)


## Every hider caught: the round's over.
func _check_round_end() -> void:
	if phase == Phase.LIVE and live_hiders().is_empty():
		_end_round()


func _end_round() -> void:
	var survivors := live_hiders()
	var cleared := survivors.is_empty()
	for fish in survivors:
		var bonus := settings.survive_bonus
		if settings.variant == MarcoPoloSettings.Variant.CONVERSION and survivors.size() == 1 and players.size() > 2:
			bonus *= settings.last_fish_scale  # the Last Fish
		_tally[fish] = float(_tally.get(fish, 0.0)) + bonus
		_stat_add(fish, MatchStats.SURVIVED, 1)
	if cleared and time_left > 0.0:
		for fish in starting_seekers:
			_tally[fish] = float(_tally.get(fish, 0.0)) + settings.clear_bonus_max * time_left / maxf(settings.round_time, 0.01)
	var points := {}
	for fish in players:
		points[fish] = float(_tally.get(fish, 0.0))
		match_totals[fish] = float(match_totals.get(fish, 0.0)) + float(points[fish])
	_reset_portholes()
	_set_phase(Phase.ROUND_OVER)
	phase_left = settings.round_over_time
	_play(SOUNDS.round_over)
	round_over.emit({"round": round_index, "seekers": starting_seekers.duplicate(), "points": points, "totals": match_totals.duplicate(),
			"survivors": survivors, "cleared": cleared, "time_left": time_left})


## Everyone out of the portholes, every gauge empty (PortholeSystem.reset()).
func _reset_portholes() -> void:
	if is_instance_valid(porthole_system) and porthole_system.has_method("reset"):
		porthole_system.call("reset")


func _finish_match() -> void:
	var best := -INF
	winner = null
	for fish in players:
		if float(match_totals.get(fish, 0.0)) > best:
			best = float(match_totals.get(fish, 0.0))
			winner = fish
	_set_phase(Phase.OVER)
	phase_left = settings.match_over_time
	match_over.emit(winner)


# --- Getters ----------------------------------------------------------------

func role_of(fish: FishController) -> int:
	return int(role.get(fish, Role.HIDER))


func is_live_hider(fish: FishController) -> bool:
	return players.has(fish) and role_of(fish) == Role.HIDER and not eliminated.has(fish)


func seekers() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish in players:
		if role_of(fish) == Role.SEEKER:
			out.append(fish)
	return out


func live_hiders() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish in players:
		if is_live_hider(fish):
			out.append(fish)
	return out


## A seeker past any hold, in LIVE: their tags count.
func is_seeking(fish: FishController) -> bool:
	return phase == Phase.LIVE and role_of(fish) == Role.SEEKER and not _hold.has(fish)


func local_fish() -> FishController:
	return _local


## SEEKER when the local player is a seeker, else HIDER (spectators too).
func local_view_role() -> int:
	return Role.SEEKER if is_instance_valid(_local) and role_of(_local) == Role.SEEKER else Role.HIDER


func spectate_target() -> FishController:
	return _spectating


## Whether the local player sees `fish`'s name plate (Hud.plate_filter). To a
## seeker a hider or a Fake Fish shows one only from the skin layer up in
## their view, never from a porthole; hiders and spectators see every plate.
func shows_plate(fish: FishController) -> bool:
	if local_view_role() != Role.SEEKER or is_spectating():
		return true
	var decoy := _decoys.has(fish)
	if not decoy and (not players.has(fish) or role_of(fish) == Role.SEEKER):
		return true
	if is_hidden(fish):
		return false
	return settings.layer_for(local_exposure(fish)) >= MarcoPoloSettings.Layer.SKIN


## The follow cam's view while what it follows hides in a porthole: looking
## out of the porthole (no wall pull-in), else null (FollowCamera.pose_override).
## On a guest our own fish is in the porthole it got into here (PortholeSystem
## runs it); for anyone else the host says who's hidden, the nearest porthole theirs.
func _porthole_pose(subject: Variant) -> Variant:
	var fish := subject as FishController
	if fish == null or porthole_system == null:
		return null
	if not authority and fish == _local:
		return porthole_system.call("camera_transform", fish) if porthole_system.call("porthole_of", fish) != null else null
	if not is_hidden(fish):
		return null
	if authority:
		return porthole_system.call("camera_transform", fish)
	var best: Node3D = null
	for p: Node3D in porthole_system.call("portholes"):
		if best == null or p.global_position.distance_squared_to(fish.global_position) < best.global_position.distance_squared_to(fish.global_position):
			best = p
	return best.call("camera_transform", fish.hitbox_length) if best else null


## A fish in a porthole (PortholeSystem), out of every seeker's view. On a
## guest, as the host says.
func is_hidden(fish: FishController) -> bool:
	if not authority:
		return _net_hidden.has(fish)
	return porthole_system != null and porthole_system.has_method("is_hidden") and bool(porthole_system.call("is_hidden", fish))


## How far up the layers `seeker` sees `hider` (0..1; on a guest, the host's).
func exposure(seeker: FishController, hider: FishController) -> float:
	if not authority:
		return float(_net_exposure.get(hider, 0.0)) if seeker == _local else 0.0
	var seen: Dictionary = _exposure.get(seeker, {})
	return float(seen.get(hider, 0.0))


## The highest any seeker sees `hider` (for the hider's own layer pip).
func max_exposure(hider: FishController) -> float:
	if not authority:
		return float(_net_exposure.get(hider, 0.0))
	var best := 0.0
	for seeker in seekers():
		best = maxf(best, exposure(seeker, hider))
	return best


func noise(hider: FishController) -> float:
	return (_meters[hider] as NoiseMeter).noise if _meters.has(hider) else 0.0


func noise_meter(hider: FishController) -> NoiseMeter:
	return _meters.get(hider) as NoiseMeter


## exposure(local seeker, hider); 0 when the local player isn't a seeker.
func local_exposure(hider: FishController) -> float:
	if local_view_role() != Role.SEEKER:
		return 0.0
	return exposure(_local, hider)


## `fish`'s hidden round tally: only for the local player's own HUD (0 for anyone else's while the round's on).
func own_round_tally(fish: FishController) -> float:
	if fish != _local and phase in [Phase.COUNTDOWN, Phase.LIVE]:
		return 0.0
	if not authority:
		return _net_own_tally if fish == _local else 0.0
	return float(_tally.get(fish, 0.0))


## Between-round totals: fish -> points.
func totals() -> Dictionary:
	return match_totals.duplicate()


## Whether `seeker` has `hider` in direct line of sight now (host).
func in_sight(seeker: FishController, hider: FishController) -> bool:
	return sight_share(seeker, hider) >= 0.0


## -1 when out of `seeker`'s line of sight, else where in the cone (0 centre .. 1 edge).
func sight_share(seeker: FishController, hider: FishController) -> float:
	if not is_instance_valid(seeker) or not is_instance_valid(hider) or is_hidden(hider) or not hider.visible:
		return -1.0
	var eye := eye_of(seeker)
	var share := SightCone.cone_share(view_of(seeker), eye, hider.global_position, settings, sight_range())
	if share < 0.0:
		return -1.0
	if not SightCone.clear_line(seeker.get_world_3d().direct_space_state, eye, SightCone.body_points(hider), _fish_rids(), _blockers_mask()):
		return -1.0
	return share


## The sight cone's length: los_range, else the arena's murk sight distance.
func sight_range() -> float:
	if settings.los_range > 0.0:
		return settings.los_range
	if arena and arena.has_method("sight_range"):
		return float(arena.call("sight_range"))
	return settings.default_sight_range


## Where `seeker` looks from, and which way: the local seeker's camera, else the fish.
func eye_of(seeker: FishController) -> Vector3:
	return seeker.global_position + seeker.global_basis.y * 0.25


func view_of(seeker: FishController) -> Basis:
	if seeker == _local and is_instance_valid(camera) and camera is Node3D and (camera as Node3D).is_inside_tree():
		return (camera as Node3D).global_basis
	if seeker.has_meta("mp_view"):
		return seeker.get_meta("mp_view") as Basis  # a guest's camera, sent to the host
	return seeker.global_basis


func _blockers_mask() -> int:
	if arena and arena.has_method("sight_blockers_mask"):
		return int(arena.call("sight_blockers_mask"))
	return AquariumArena.WORLD_QUERY_MASK


func _fish_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for fish in players:
		rids.append(fish.get_rid())
	for fake: FishController in _decoys:
		if is_instance_valid(fake):
			rids.append(fake.get_rid())
	return rids


# --- Noise, exposure and sight ----------------------------------------------

## A burst of noise from `fish` (porthole knocks, rim bumps, exits, chest burps).
func add_noise(fish: FishController, amount: float) -> void:
	if _meters.has(fish):
		(_meters[fish] as NoiseMeter).add(amount)


## The distance falloff of exposure (1 within near_sight, 0.5 at half_sight, 0 at the sight range).
func distance_falloff(distance: float) -> float:
	var reach := sight_range()
	if distance <= settings.near_sight:
		return 1.0
	if distance >= reach:
		return 0.0
	var half := clampf(settings.half_sight, settings.near_sight, reach)
	if distance <= half:
		return lerpf(1.0, 0.5, (distance - settings.near_sight) / maxf(half - settings.near_sight, 0.001))
	return lerpf(0.5, 0.0, (distance - half) / maxf(reach - half, 0.001))


## What `seeker` would see of `hider` now, before the fade.
func exposure_target(seeker: FishController, hider: FishController) -> float:
	if is_hidden(hider) or eliminated.has(hider):
		return 0.0
	var v := hider.swim_velocity()
	if Vector2(v.x, v.z).length() < settings.still_speed:
		return 0.0  # stationary = invisible
	var raw := pow(clampf(noise(hider), 0.0, 1.0), settings.exposure_curve)
	var falloff := distance_falloff(hider.global_position.distance_to(seeker.global_position))
	if raw >= settings.layer_aura:
		falloff = maxf(falloff, settings.aura_min_falloff)
	return raw * falloff


func _update_exposure(delta: float) -> void:
	var watched := live_hiders()
	for fake: FishController in _decoys:
		if is_instance_valid(fake):
			watched.append(fake)
	for seeker in seekers():
		var seen: Dictionary = _exposure.get(seeker, {})
		for hider in watched:
			var target := exposure_target(seeker, hider)
			var now := float(seen.get(hider, 0.0))
			seen[hider] = target if target >= now else maxf(now - settings.exposure_fade * delta, target)
		for hider: FishController in seen.keys():
			if not watched.has(hider):
				seen.erase(hider)
		_exposure[seeker] = seen


## Sets every seeker's view of `hider` (the console's mp_expose, probes).
func set_exposure(hider: FishController, value: float) -> void:
	for seeker in seekers():
		var seen: Dictionary = _exposure.get(seeker, {})
		seen[hider] = clampf(value, 0.0, 1.0)
		_exposure[seeker] = seen


## Hiders in a seeker's direct line of sight score per second, once per seeker,
## at the layer that seeker sees (plan §6).
func _score_sight(delta: float) -> void:
	_seen_now.clear()
	var close_now := {}
	for seeker in seekers():
		if not is_seeking(seeker):
			continue
		for hider in live_hiders():
			var share := sight_share(seeker, hider)
			if share < 0.0:
				continue
			var layer := settings.layer_for(exposure(seeker, hider))
			var rate := settings.seen_points(layer)
			if settings.los_falloff:
				rate *= 1.0 - 0.75 * share
			_tally[hider] = float(_tally.get(hider, 0.0)) + rate * delta
			var line: Dictionary = _stats_of(hider)
			var by_layer: Array = line[MatchStats.SEEN]
			by_layer[layer] = float(by_layer[layer]) + rate * delta
			var seen: Dictionary = _seen_now.get(hider, {})
			seen[seeker] = {"layer": layer, "rate": rate}
			_seen_now[hider] = seen
			if layer >= MarcoPoloSettings.Layer.MUSCLE and hider.global_position.distance_to(seeker.global_position) <= settings.close_call_range:
				close_now[hider] = true
	for hider: FishController in _close.keys():
		if not close_now.has(hider):
			_close.erase(hider)
			if is_live_hider(hider):
				_stat_add(hider, MatchStats.CLOSE_CALL, 1)
	for hider: FishController in close_now:
		_close[hider] = true


## Whether `hider` scored this tick (in some seeker's sight) — only for the local hider's eye pip.
func is_seen_now(hider: FishController) -> bool:
	if hider != _local:
		return false
	if not authority:
		return bool(_local.get_meta("mp_seen", false))
	return _seen_now.has(hider)


# --- Tags and catches -------------------------------------------------------

func _check_tags() -> void:
	for seeker in seekers():
		if not is_seeking(seeker):
			continue
		for hider in live_hiders():
			if is_hidden(hider):
				continue  # the bow can't reach into a porthole
			if Battery.touching(seeker, hider):
				tag(seeker, hider)
				if phase != Phase.LIVE:
					return
		for fake: FishController in _decoys.keys():
			if is_instance_valid(fake) and Battery.touching(seeker, fake):
				_fool(seeker, fake)


## `seeker` tags `hider`.
func tag(seeker: FishController, hider: FishController) -> void:
	if not is_live_hider(hider):
		return
	if is_instance_valid(seeker):
		_tally[seeker] = float(_tally.get(seeker, 0.0)) + settings.tag_points
		_stat_add(seeker, MatchStats.TAG, 1)
		_hold_fish(seeker, settings.tag_hold)
	_play_at(SOUNDS.tag, hider.global_position)
	_on_caught(hider, "tag", seeker)


## A catch (a tag, or fish out of water): the variant decides what happens.
func _on_caught(hider: FishController, how: String, by: FishController) -> void:
	if not is_live_hider(hider):
		return
	_close.erase(hider)
	if how == "out_of_water":
		_stat_add(hider, MatchStats.OUT_OF_WATER, 1)
	caught.emit(hider, how, by)
	if settings.variant == MarcoPoloSettings.Variant.CONVERSION:
		role[hider] = Role.SEEKER
		apply_role(hider, Role.SEEKER)
		_hold_fish(hider, settings.convert_hold)
		role_changed.emit(hider, Role.SEEKER)
	else:
		_eliminate(hider)
	_announce_local_role()
	_check_round_end()


## Fish out of water (PortholeSystem's dried_out): caught, in both variants.
func dried_out(fish: FishController) -> void:
	_on_caught(fish, "out_of_water", null)


func _eliminate(hider: FishController) -> void:
	eliminated[hider] = true
	if _meters.has(hider):
		(_meters[hider] as NoiseMeter).reset()
	_play_at(SOUNDS.eliminated, hider.global_position)
	_float_up(hider)
	eliminated_fish.emit(hider)
	if hider == _local:
		_parked = false
		_spectate(_nearest_watchable(hider.global_position))
	elif hider == _spectating:
		_spectate_move_left = settings.spectate_switch_delay


## The eliminated fish floats up belly-up and fades (eliminated_float).
func _float_up(fish: FishController) -> void:
	fish.controls_locked = true
	fish.collision_layer = 0
	fish.collision_mask = 0
	if not fish.puppet:
		fish.freeze = true
	_floating[fish] = settings.eliminated_float
	if fish.puppet:
		return  # its own machine floats it
	fish.linear_velocity = Vector3.ZERO
	var flat := -fish.global_basis.z
	flat.y = 0.0
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	# Belly up: the fish's up points down.
	fish.global_basis = Basis.looking_at(flat.normalized(), Vector3.DOWN)
	_floating[fish] = settings.eliminated_float


func _float_eliminated(delta: float) -> void:
	for fish: FishController in _floating.keys():
		if not is_instance_valid(fish):
			_floating.erase(fish)
			continue
		var left: float = _floating[fish] - delta
		if not fish.puppet:
			fish.global_position += Vector3.UP * settings.eliminated_float_speed * delta
		if left <= 0.0:
			_floating.erase(fish)
			fish.visible = false
		else:
			_floating[fish] = left


func _hold_fish(fish: FishController, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hold[fish] = maxf(float(_hold.get(fish, 0.0)), seconds)
	if not fish.puppet:
		fish.controls_locked = true


# --- Decoys -----------------------------------------------------------------

## A Fake Fish (world's FakeFish) joins: a NoiseMeter, exposure, pings and the
## tag check; it answers Marco and never scores.
func register_decoy(fake: FishController, owner: FishController) -> void:
	_decoys[fake] = owner
	_meters[fake] = _new_meter(fake)


func unregister_decoy(fake: FishController) -> void:
	_decoys.erase(fake)
	if _meters.has(fake):
		(_meters[fake] as NoiseMeter).detach()
		_meters.erase(fake)
	for seen: Dictionary in _exposure.values():
		seen.erase(fake)


func decoys() -> Array[FishController]:
	var out: Array[FishController] = []
	for fake: FishController in _decoys:
		if is_instance_valid(fake):
			out.append(fake)
	return out


func decoy_owner(fake: FishController) -> FishController:
	return _decoys.get(fake) as FishController


func fake_charges(hider: FishController) -> int:
	return int(_fake_charges.get(hider, 0))


## The hider's skill button: a Fake Fish, if they've a charge (world's FakeFish.throw).
func throw_fake(hider: FishController) -> bool:
	if not is_live_hider(hider) or phase != Phase.LIVE or fake_charges(hider) <= 0 or is_hidden(hider):
		return false
	if not authority:
		_fake_charges[hider] = fake_charges(hider) - 1
		local_button.emit("fake")  # the host throws it (and tells everyone)
		return true
	if not ResourceLoader.exists(FAKE_FISH_PATH):
		return false
	var script := load(FAKE_FISH_PATH) as GDScript
	if script == null or not script.can_instantiate():
		return false
	_fake_charges[hider] = fake_charges(hider) - 1
	script.call("throw", self, hider)
	return true


func _fool(seeker: FishController, fake: FishController) -> void:
	_stat_add(seeker, MatchStats.FOOLED, 1)
	_hold_fish(seeker, settings.fooled_hold)
	_play_at(SOUNDS.fooled, fake.global_position)
	fooled.emit(seeker, fake)
	if fake.has_method("pop"):
		fake.call("pop")
	elif fake.get_parent() and fake.get_parent().has_method("pop"):
		fake.get_parent().call("pop")
	unregister_decoy(fake)


# --- Sonar ------------------------------------------------------------------

## "Marco!": on its cooldown, every live hider (not in a porthole) and every
## Fake Fish answers "Polo!" on every seeker's scope, with a big blur and an
## exposure bump; the hiders see a ring round the caller for a moment.
func marco(seeker: FishController) -> bool:
	if not is_seeking(seeker) or marco_ready(seeker) < 1.0:
		return false
	if not authority:
		local_button.emit("marco")  # the host calls it (and tells everyone)
		return true
	_marco_effects(seeker)
	var answering: Array[FishController] = []
	for hider in live_hiders():
		if not is_hidden(hider):
			answering.append(hider)
	answering.append_array(decoys())
	for hider in answering:
		_ping_seekers(hider.global_position, 1.0, true)
		for other in seekers():
			var seen: Dictionary = _exposure.get(other, {})
			seen[hider] = maxf(float(seen.get(hider, 0.0)), settings.polo_exposure)
			_exposure[other] = seen
	return true


## What every machine sees of a "Marco!": its cooldown, the ring, the call.
func _marco_effects(seeker: FishController) -> void:
	_marco_left[seeker] = settings.marco_cooldown
	_marco_ring[seeker] = settings.marco_reveal_time
	_play_at(SOUNDS.marco, seeker.global_position)
	marco_called.emit(seeker)
	marco_scan_started.emit(seeker.global_position, seeker)


## How ready `seeker`'s "Marco!" is (0 just used .. 1 ready).
func marco_ready(seeker: FishController) -> float:
	if settings.marco_cooldown <= 0.0:
		return 1.0
	return 1.0 - clampf(float(_marco_left.get(seeker, 0.0)) / settings.marco_cooldown, 0.0, 1.0)


## Seconds the hiders still see `seeker`'s Marco ring.
func marco_ring_left(seeker: FishController) -> float:
	return float(_marco_ring.get(seeker, 0.0))


## `seeker`'s pings, newest last: {pos (blurred for them), loudness, time, polo}.
func recent_pings(seeker: FishController) -> Array:
	var kept: Array = []
	for ping: Dictionary in _pings.get(seeker, []):
		if _time - float(ping.time) <= settings.blip_life:
			kept.append(ping)
	return kept


## A ping from `at` to every seeker, blurred by each one's own distance.
func _ping_seekers(at: Vector3, loudness: float, polo: bool) -> void:
	if phase != Phase.LIVE:
		return
	for seeker in seekers():
		var fuzz := settings.blip_fuzz * (settings.polo_fuzz if polo else 1.0) * at.distance_to(seeker.global_position)
		var off := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.0, 1.0)).limit_length(1.0) * fuzz
		var ping := {"pos": at + off, "loudness": clampf(loudness, 0.0, 1.0), "time": _time, "polo": polo}
		var list: Array = _pings.get(seeker, [])
		list.append(ping)
		while list.size() > settings.max_pings:
			list.pop_front()
		_pings[seeker] = list
		pinged.emit(seeker, ping.pos, ping.loudness, polo)
		if seeker == _local:
			_ping_sound(ping.pos, polo)


# --- Bumping ----------------------------------------------------------------

## Fish bump into each other (fish_collide): a hider bumping a hider (or a
## Fake Fish) is a bump_noise burst for both, plus the mp_bump thud.
func _check_bumps(delta: float) -> void:
	for key: String in _bump_left.keys():
		_bump_left[key] = float(_bump_left[key]) - delta
		if float(_bump_left[key]) <= 0.0:
			_bump_left.erase(key)
	var movers: Array[FishController] = live_hiders()
	movers.append_array(decoys())
	for i in movers.size():
		for j in range(i + 1, movers.size()):
			var a := movers[i]
			var b := movers[j]
			if a.global_position.distance_to(b.global_position) > 6.0:
				continue
			var key := "%d|%d" % [a.get_instance_id(), b.get_instance_id()]
			if _bump_left.has(key) or not _bodies_touch(a, b):
				continue
			var apart := (a.global_position - b.global_position).normalized()
			var va: Vector3 = _last_velocity.get(a, a.swim_velocity())
			var vb: Vector3 = _last_velocity.get(b, b.swim_velocity())
			var closing := (vb - va).dot(apart)
			if closing < settings.bump_speed:
				continue
			_bump_left[key] = settings.bump_cooldown
			add_noise(a, settings.bump_noise)
			add_noise(b, settings.bump_noise)
			_play_at(SOUNDS.bump, (a.global_position + b.global_position) * 0.5, clampf(closing / 10.0, 0.2, 1.0))
			bumped.emit(a, b, closing)
	for fish in players:
		_last_velocity[fish] = fish.swim_velocity()
	for fake in decoys():
		_last_velocity[fake] = fake.swim_velocity()


## The two fish's hitboxes (grown by Battery.REACH) overlap: no bow.
func _bodies_touch(a: FishController, b: FishController) -> bool:
	var hitbox := a.get_node_or_null("Collision") as CollisionShape3D
	if hitbox == null or not (hitbox.shape is BoxShape3D):
		return false
	var box := BoxShape3D.new()
	box.size = (hitbox.shape as BoxShape3D).size + Vector3.ONE * (Battery.REACH * 2.0 + 0.15)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = hitbox.global_transform
	query.exclude = [a.get_rid()]
	for hit in a.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == b:
			return true
	return false


func _set_collisions(collide: bool) -> void:
	for fish in players:
		for other in players:
			if fish == other:
				continue
			if collide:
				fish.remove_collision_exception_with(other)
			else:
				fish.add_collision_exception_with(other)


func _restore_layers(fish: FishController) -> void:
	if _layers.has(fish) and not fish.battered:
		var saved: Array = _layers[fish]
		fish.collision_layer = int(saved[0])
		fish.collision_mask = int(saved[1])


# --- Spectating -------------------------------------------------------------

func _spectate(fish: FishController) -> void:
	_spectating = fish
	_spectate_move_left = -1.0
	if is_instance_valid(camera):
		camera.set("target", fish)
		if camera.has_method("snap"):
			camera.call("snap")
	spectate_target_changed.emit(fish)
	_announce_local_role()


## The next (step 1) or previous (-1) fish to watch.
func cycle_spectate(step: int) -> void:
	var live := watchable()
	if live.is_empty():
		return
	var at := live.find(_spectating)
	_spectate(live[posmod(at + step, live.size())] if at >= 0 else live[0])


func _nearest_live_hider(from: Vector3) -> FishController:
	var best: FishController = null
	var best_distance := INF
	for fish in live_hiders():
		var d := fish.global_position.distance_to(from)
		if d < best_distance:
			best_distance = d
			best = fish
	return best


## Every fish still in the round but the local player's: who they can watch.
func watchable() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish in players:
		if fish != _local and is_instance_valid(fish) and not eliminated.has(fish):
			out.append(fish)
	return out


## Who to watch next from `from`: the nearest live hider, else the nearest fish in the round.
func _nearest_watchable(from: Vector3) -> FishController:
	var hider := _nearest_live_hider(from)
	if hider and hider != _local:
		return hider
	var best: FishController = null
	var best_distance := INF
	for fish in watchable():
		var d := fish.global_position.distance_to(from)
		if d < best_distance:
			best_distance = d
			best = fish
	return best


func is_spectating() -> bool:
	return eliminated.has(_local)


## A live hider parked, watching someone (spectate_target()).
func is_parked() -> bool:
	return _parked


func watch_wheel() -> WatchWheel:
	return _wheel


func _update_spectating(delta: float) -> void:
	if not is_spectating() and not _parked:
		return
	if _spectate_move_left >= 0.0:
		_spectate_move_left -= delta
		if _spectate_move_left < 0.0:
			var next := _nearest_watchable(_spectating.global_position if is_instance_valid(_spectating) else center)
			if next == null and _parked:
				_unpark()
			else:
				_spectate(next)
	elif not is_instance_valid(_spectating) or not watchable().has(_spectating):
		_spectate_move_left = settings.spectate_switch_delay


## The camera button for a hider or a spectator: a tap parks a live hider and
## watches someone (the one it last watched, else the nearest) or goes back to
## its own follow cam; a spectator's tap moves on. Held watch_hold_time it opens
## the WatchWheel, and letting go watches the fish picked there (a hider's own
## slice: back to its own cam). Seekers keep the button's view swap.
func _watch_button(delta: float) -> void:
	var can := is_instance_valid(_local) and (is_spectating() or (is_live_hider(_local) and phase in [Phase.COUNTDOWN, Phase.LIVE]))
	if is_instance_valid(camera) and "button_taken" in camera:
		if can and not bool(camera.get("button_taken")):
			camera.set("free_cam", false)  # a hider's own view is the follow cam: Y watches instead
		camera.set("button_taken", can)
	if not can:
		_watch_held = -1.0
		if _wheel and _wheel.is_open:
			_wheel.close()
			_release_controls()
		_unpark()
		return
	if Console.is_open() or get_tree().paused or _wheel == null:
		return
	var input: PlayerInput = _local.input_source if _local.input_source else PlayerInput.everyone()
	if input.just_pressed(&"ball_cam"):
		_watch_held = 0.0
	if _watch_held < 0.0:
		return
	if input.pressed(&"ball_cam"):
		_watch_held += delta
		if not _wheel.is_open and _watch_held >= settings.watch_hold_time:
			_wheel.open(_wheel_entries(), _spectating if is_instance_valid(_spectating) else _local, input)
			_hold_parked()
		return
	_watch_held = -1.0
	if _wheel.is_open:
		var pick := _wheel.close()
		if pick == _local:
			_unpark()
		elif pick != null:
			_watch(pick)
		_release_controls()
	elif is_spectating():
		cycle_spectate(1)
	elif _parked:
		_unpark()
	else:
		var other := _spectating if is_instance_valid(_spectating) and watchable().has(_spectating) else _nearest_watchable(_local.global_position)
		if other:
			_watch(other)


## The watch wheel's slices: the hider's own fish first (its own cam), then everyone it can watch.
func _wheel_entries() -> Array[FishController]:
	var out: Array[FishController] = []
	if not is_spectating():
		out.append(_local)
	out.append_array(watchable())
	return out


## Watches `fish`: a live hider parks to.
func _watch(fish: FishController) -> void:
	if not is_spectating():
		_parked = true
		_hold_parked()
	_spectate(fish)


## Back to the hider's own follow cam, its fish its own again.
func _unpark() -> void:
	if not _parked:
		return
	_parked = false
	_spectating = null
	_spectate_move_left = -1.0
	_release_controls()
	if is_instance_valid(camera):
		camera.set("target", null)
		if camera.has_method("snap"):
			camera.call("snap")
	spectate_target_changed.emit(null)
	_announce_local_role()


## A parked hider, or one picking on the wheel, holds still (no controls).
func _hold_parked() -> void:
	if not is_instance_valid(_local) or _local.puppet or is_spectating():
		return
	if _parked or (_wheel and _wheel.is_open):
		_local.controls_locked = true


## The local hider's controls back, unless it's parked, held or out.
func _release_controls() -> void:
	if not is_instance_valid(_local) or _local.puppet or eliminated.has(_local) or _parked:
		return
	_local.controls_locked = _hold.has(_local) or (phase == Phase.COUNTDOWN and starting_seekers.has(_local))


# --- The local player's buttons ---------------------------------------------

func _local_input() -> void:
	if not is_instance_valid(_local) or Console.is_open() or get_tree().paused:
		return
	if _wheel and _wheel.is_open:
		return  # the left stick is picking on the wheel
	var input: PlayerInput = _local.input_source if _local.input_source else PlayerInput.everyone()
	if is_spectating() or _parked:
		if input.just_pressed(&"ui_page_next") or input.just_pressed(&"ui_right"):
			cycle_spectate(1)
		elif input.just_pressed(&"ui_page_previous") or input.just_pressed(&"ui_left"):
			cycle_spectate(-1)
		return
	if phase != Phase.LIVE:
		return
	if role_of(_local) == Role.SEEKER:
		if input.just_pressed(&"marco"):  # the left stick (or M); Y swaps the camera
			marco(_local)
	elif input.just_pressed(&"boost"):
		throw_fake(_local)


func _announce_local_role() -> void:
	var now := local_view_role()
	if now != _local_role:
		_local_role = now
		local_role_changed.emit(now)


# --- Spawns and the arena ---------------------------------------------------

func _seeker_start() -> Transform3D:
	if arena and arena.has_method("seeker_start"):
		return arena.call("seeker_start") as Transform3D
	return Transform3D(Basis.IDENTITY, center)


func _hider_spawns(count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if arena and arena.has_method("hider_spawns"):
		for spawn: Transform3D in arena.call("hider_spawns"):
			out.append(spawn)
		out.shuffle()
	if out.is_empty():
		var turn := _rng.randf() * TAU
		for i in maxi(count, 1):
			var a := turn + TAU * float(i) / maxi(count, 1)
			var at := center + Vector3(cos(a), 0.0, sin(a)) * OCEAN_SPAWN_RING
			var away := (at - center).normalized()
			out.append(Transform3D(Basis.looking_at(away, Vector3.UP), at))
	return out


## The Ocean (no walls): past its edge a push back in, as Hunt.
func _keep_in_arena(delta: float) -> void:
	if arena != null or not (environment is Ocean):
		return
	for fish in players:
		if fish.freeze or fish.puppet or eliminated.has(fish):
			continue
		var out := fish.global_position - center
		var past := out.length() - settings.ocean_radius
		if past <= 0.0:
			continue
		var direction := out.normalized()
		var outward := maxf(fish.linear_velocity.dot(direction), 0.0)
		var push := minf(past * BOUNDARY_STIFFNESS + outward * BOUNDARY_OUTWARD, BOUNDARY_MAX)
		fish.apply_push(-direction * push * delta)


# --- Helpers others own -----------------------------------------------------

func _wire_helpers() -> void:
	_hud = MarcoPoloHud.new()
	_hud.name = "MarcoPoloHud"
	add_child(_hud)
	_hud.call("bind", self)
	_looks = HiderLooks.new()
	_looks.name = "HiderLooks"
	add_child(_looks)
	_looks.call("bind", self)
	_wheel = WatchWheel.new()
	_wheel.name = "WatchWheel"
	add_child(_wheel)
	_wheel.match_node = self
	_sonar = _optional(SONAR_MAP_PATH, "SonarMap")
	if _sonar:
		_sonar.call("bind", self)
	porthole_system = _optional(PORTHOLE_SYSTEM_PATH, "PortholeSystem")
	if porthole_system:
		var holes: Array = arena.call("portholes") if arena and arena.has_method("portholes") else []
		porthole_system.call("setup", self, holes)
		if porthole_system.has_signal("dried_out"):
			porthole_system.connect("dried_out", dried_out)


## A helper that may not be written yet: an instance of `path`'s script, added
## as a child named `node_name`, or null.
func _optional(path: String, node_name: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	var node: Node = script.new()
	node.name = node_name
	add_child(node)
	return node


# --- Stats ------------------------------------------------------------------

func _new_stats() -> Dictionary:
	return {MatchStats.TAG: 0, MatchStats.SEEN: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], MatchStats.CLOSE_CALL: 0, MatchStats.SURVIVED: 0,
			MatchStats.FOOLED: 0, MatchStats.OUT_OF_WATER: 0}


func _stats_of(fish: FishController) -> Dictionary:
	if not stats.has(fish):
		stats[fish] = _new_stats()
	return stats[fish]


func _stat_add(fish: FishController, type: String, amount: int) -> void:
	var line := _stats_of(fish)
	line[type] = int(line[type]) + amount


# --- Sound ------------------------------------------------------------------

## A ping on the local seeker's scope: Polo! from where it came, else a blip.
func _ping_sound(at: Vector3, polo: bool) -> void:
	if polo:
		_play_at(SOUNDS.polo, at)
	else:
		_play(SOUNDS.ping)


## The cues every machine plays for itself: the seeker's count (climbing) while
## the hiders scatter, the local hider's tick while seen, a hider flaring into
## the aura, and (for the local seeker) heartbeats from cardiovascular hiders.
func _sound_cues(delta: float) -> void:
	if phase == Phase.COUNTDOWN:
		var second := ceili(phase_left)
		if second != _count_second and second > 0:
			Sfx.play_pitched(SOUNDS.count, maxi(ceili(settings.hide_time) - second, 0))
			_count_second = second
		return
	_count_second = -1
	if phase != Phase.LIVE:
		_cue_layer.clear()
		return
	if is_instance_valid(_local) and is_seen_now(_local):
		_play(SOUNDS.seen)  # its catalogue cooldown paces the tick
	var seeing := local_view_role() == Role.SEEKER
	for hider in live_hiders():
		var layer := settings.layer_for(max_exposure(hider))
		if layer == MarcoPoloSettings.Layer.AURA and int(_cue_layer.get(hider, 0)) != layer:
			_play_at(SOUNDS.aura, hider.global_position)
		_cue_layer[hider] = layer
		var left := float(_heartbeat_left.get(hider, 0.0)) - delta
		if seeing and settings.heartbeat_interval > 0.0 and settings.layer_for(local_exposure(hider)) == MarcoPoloSettings.Layer.CARDIO:
			if left <= 0.0:
				_play_at(SOUNDS.heartbeat, hider.global_position, 0.6)
				left = settings.heartbeat_interval
		else:
			left = 0.0
		_heartbeat_left[hider] = left


func _play(id: String) -> void:
	if not id.is_empty():
		Sfx.play(id)


func _play_at(id: String, at: Vector3, intensity := 1.0) -> void:
	if not id.is_empty():
		Sfx.play_at(id, at, intensity)


# --- The debug cone ---------------------------------------------------------

func _draw_debug_cone() -> void:
	if _sight == null:
		return
	var cones: Array = []
	var rays: Array = []
	if settings.debug_show_los_cone and phase == Phase.LIVE:
		var reach := sight_range()
		for seeker in seekers():
			cones.append({"eye": eye_of(seeker), "view": view_of(seeker), "reach": reach})
			for hider in live_hiders():
				var eye := eye_of(seeker)
				var state := "outside"
				var rate := 0.0
				if SightCone.cone_share(view_of(seeker), eye, hider.global_position, settings, reach) >= 0.0 and not is_hidden(hider):
					state = "counts" if sight_share(seeker, hider) >= 0.0 else "blocked"
					if state == "counts":
						rate = settings.seen_points(settings.layer_for(exposure(seeker, hider)))
				rays.append({"from": eye, "to": hider.global_position, "state": state, "rate": rate})
	_sight.draw(settings, cones, rays)


# --- Online (CoopSession's Marco Polo messages) -----------------------------

## A guest: the host's view of the local seeker's exposures (hider -> 0..1).
func apply_net_exposure(values: Dictionary) -> void:
	_net_exposure = values


## A guest: the host's tally for our own hider (the only one sent during a round).
func apply_net_own_tally(points: float, seen: bool) -> void:
	_net_own_tally = points
	if is_instance_valid(_local):
		_local.set_meta("mp_seen", seen)


## A guest: a round starts. `starting` seek; our own fish goes to `place`;
## `totals` are everyone's between-round points (fish -> points).
func apply_net_round(index: int, starting: Array[FishController], place: Transform3D, totals_now: Dictionary, rounds: int) -> void:
	settings.rounds = rounds
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	_begin_round(index, starting, {_local: place})


## A guest: the host's phase and clocks.
func apply_net_phase(new_phase: int, new_phase_left: float, new_time_left: float) -> void:
	phase_left = new_phase_left
	time_left = new_time_left
	if new_phase == phase:
		return
	if new_phase == Phase.LIVE:
		_go_live()
		time_left = new_time_left
	else:
		_set_phase(new_phase)


## A guest: the host's catch (`how` "tag" / "out_of_water", `by` the tagger or null).
func apply_net_caught(hider: FishController, how: String, by: FishController) -> void:
	if not is_live_hider(hider):
		return
	if how == "tag" and by:
		_hold_fish(by, settings.tag_hold)
		_play_at(SOUNDS.tag, hider.global_position)
	caught.emit(hider, how, by)
	if settings.variant == MarcoPoloSettings.Variant.CONVERSION:
		role[hider] = Role.SEEKER
		apply_role(hider, Role.SEEKER)
		_hold_fish(hider, settings.convert_hold)
		role_changed.emit(hider, Role.SEEKER)
	else:
		_eliminate(hider)
	_announce_local_role()


## A guest: the round's over, with everyone's points now (fish -> points) and the totals.
func apply_net_round_over(points: Dictionary, totals_now: Dictionary, survivors: Array[FishController], cleared: bool) -> void:
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	for fish: FishController in points:
		_tally[fish] = float(points[fish])
	_set_phase(Phase.ROUND_OVER)
	phase_left = settings.round_over_time
	_play(SOUNDS.round_over)
	round_over.emit({"round": round_index, "seekers": starting_seekers.duplicate(), "points": points, "totals": match_totals.duplicate(),
			"survivors": survivors, "cleared": cleared, "time_left": time_left})


## A guest: the match is over.
func apply_net_match_over(best: FishController) -> void:
	winner = best
	_set_phase(Phase.OVER)
	phase_left = settings.match_over_time
	match_over.emit(best)


## A guest: `seeker` called "Marco!".
func apply_net_marco(seeker: FishController) -> void:
	_marco_effects(seeker)


## A guest: a ping on our own seeker's scope (already blurred by the host).
func apply_net_ping(at: Vector3, loudness: float, polo: bool) -> void:
	if not is_instance_valid(_local):
		return
	var ping := {"pos": at, "loudness": loudness, "time": _time, "polo": polo}
	var list: Array = _pings.get(_local, [])
	list.append(ping)
	while list.size() > settings.max_pings:
		list.pop_front()
	_pings[_local] = list
	pinged.emit(_local, at, loudness, polo)
	_ping_sound(at, polo)


## A guest: `fish` went into a porthole (or came out).
func apply_net_hidden(fish: FishController, hidden: bool) -> void:
	if hidden:
		_net_hidden[fish] = true
	else:
		_net_hidden.erase(fish)


## A guest: a seeker tagged a Fake Fish.
func apply_net_fooled(seeker: FishController, fake: FishController) -> void:
	_hold_fish(seeker, settings.fooled_hold)
	fooled.emit(seeker, fake)


## The host: points each fish has this round, for the network (sent only at ROUND_OVER, but to each guest its own).
func round_tally(fish: FishController) -> float:
	return float(_tally.get(fish, 0.0)) if authority else (_net_own_tally if fish == _local else 0.0)


## A guest joining: the match as the host has it (roles: fish -> Role,
## eliminated: fish caught this round; our own fish spectates if it's one).
func apply_net_state(index: int, roles_now: Dictionary, out: Array[FishController], new_phase: int, new_phase_left: float,
		new_time_left: float, totals_now: Dictionary, rounds: int) -> void:
	settings.rounds = rounds
	round_index = index
	for fish: FishController in totals_now:
		match_totals[fish] = float(totals_now[fish])
	for fish: FishController in roles_now:
		role[fish] = int(roles_now[fish])
		apply_role(fish, role[fish])
	eliminated.clear()
	for fish in out:
		eliminated[fish] = true
		fish.visible = false
	phase_left = new_phase_left
	time_left = new_time_left
	_set_phase(new_phase)
	if eliminated.has(_local):
		_local.controls_locked = true
		_local.visible = false
		_spectate(_nearest_live_hider(_local.global_position))
	_announce_local_role()


## The host: fewer bots once people fill the seats (min_players), at a round's start.
func _trim_bots() -> void:
	var dropped := false
	while players.size() > maxi(settings.min_players, 2) and not bots.is_empty():
		var fish: FishController = bots.keys().back()
		var bot: Node = bots[fish]
		bots.erase(fish)
		remove_player(fish)
		bot.queue_free()
		fish.queue_free()
		dropped = true
	if dropped:
		bots_changed.emit()


# --- Console ----------------------------------------------------------------

func _register_commands() -> void:
	Console.register_command("mp_role", "mp_role [seeker|hider]: your role now (or show it)", _cmd_role)
	Console.register_command("mp_noise", "mp_noise [0..1]: your noise (or show every hider's noise)", _cmd_noise)
	Console.register_command("mp_expose", "mp_expose <0..1> [all]: every seeker's view of you (or every hider)", _cmd_expose)
	Console.register_command("mp_tag", "mp_tag: the seeker tags the nearest live hider (you, if you're one)", _cmd_tag)
	Console.register_command("mp_eliminate", "mp_eliminate: you (or, as seeker, the nearest hider) are caught", _cmd_eliminate)
	Console.register_command("mp_round", "mp_round [n|end]: skip to round n, or end this one", _cmd_round)
	Console.register_command("mp_fake", "mp_fake: throw a Fake Fish (a charge back first)", _cmd_fake)
	Console.register_command("mp_porthole", "mp_porthole: the porthole system's state", _cmd_porthole)
	Console.register_command("mp_cone", "mp_cone [on|off]: the DEBUG sight cone", _cmd_cone)


func _unregister_commands() -> void:
	for command: String in COMMANDS:
		Console.unregister_command(command)


func _cmd_role(args: PackedStringArray) -> String:
	if not args.is_empty():
		var wanted := Role.SEEKER if args[0].begins_with("s") else Role.HIDER
		role[_local] = wanted
		eliminated.erase(_local)
		apply_role(_local, wanted)
		role_changed.emit(_local, wanted)
		_announce_local_role()
	return "You: %s (phase %s, round %d/%d)" % ["seeker" if role_of(_local) == Role.SEEKER else "hider", Phase.keys()[phase],
			round_index + 1, rounds_in_match()]


func _cmd_noise(args: PackedStringArray) -> String:
	if not args.is_empty() and _meters.has(_local):
		(_meters[_local] as NoiseMeter).noise = clampf(args[0].to_float(), 0.0, 1.0)
	var lines := PackedStringArray()
	for fish: FishController in _meters:
		lines.append("%s %.2f (exposure %.2f)" % [fish.display_name if fish.display_name else fish.name, noise(fish), max_exposure(fish)])
	return ", ".join(lines) if not lines.is_empty() else "No hiders"


func _cmd_expose(args: PackedStringArray) -> String:
	var value := args[0].to_float() if not args.is_empty() else 0.0
	var who: Array[FishController] = live_hiders() if args.size() > 1 and args[1] == "all" else [_local]
	for hider in who:
		set_exposure(hider, value)
	return "Exposure %.2f (%s) for %d" % [value, MarcoPoloSettings.LAYER_NAMES[settings.layer_for(value)], who.size()]


func _cmd_tag(_args: PackedStringArray) -> String:
	var seeker: FishController = seekers()[0] if not seekers().is_empty() else null
	var hider: FishController = _local if is_live_hider(_local) else (_nearest_live_hider(seeker.global_position) if seeker else null)
	if seeker == null or hider == null:
		return "Nobody to tag"
	tag(seeker, hider)
	return "%s tagged %s" % [seeker.display_name, hider.display_name]


func _cmd_eliminate(_args: PackedStringArray) -> String:
	var hider: FishController = _local if is_live_hider(_local) else _nearest_live_hider(_local.global_position)
	if hider == null:
		return "No live hider"
	_on_caught(hider, "tag", null)
	return "%s caught" % hider.display_name


func _cmd_round(args: PackedStringArray) -> String:
	if not args.is_empty() and args[0] == "end":
		if phase == Phase.LIVE:
			_end_round()
		return "Round over"
	var n := args[0].to_int() - 1 if not args.is_empty() else round_index + 1
	start_round(clampi(n, 0, maxi(rounds_in_match() - 1, 0)))
	return "Round %d" % (round_index + 1)


func _cmd_fake(_args: PackedStringArray) -> String:
	_fake_charges[_local] = maxi(fake_charges(_local), 1)
	return "Fake Fish thrown" if throw_fake(_local) else "No Fake Fish (not a live hider, not live, or FakeFish isn't built yet)"


func _cmd_porthole(_args: PackedStringArray) -> String:
	if porthole_system == null:
		return "No portholes here"
	var hole: Variant = porthole_system.call("porthole_of", _local) if porthole_system.has_method("porthole_of") else null
	var gauge := float(porthole_system.call("gauge", _local)) if porthole_system.has_method("gauge") else 0.0
	return "In a porthole: %s, Out of Water %.0f%%" % ["yes" if hole != null else "no", gauge * 100.0]


func _cmd_cone(args: PackedStringArray) -> String:
	settings.debug_show_los_cone = not settings.debug_show_los_cone if args.is_empty() else args[0] == "on"
	return "Sight cone %s" % ("on" if settings.debug_show_los_cone else "off")
