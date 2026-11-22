class_name RaceMatch
extends GameMode
## Fin-ish Line (planning_race.md): a lap race round one track, humans and bots together. Every racer is one
## FishController swimming Nature's strides with the same top speed, acceleration and stride push
## (RaceSettings.shared_modifiers, pushed as the "race.shared" set) and its own handling (RaceHandling, "race.handling"):
## turning, how it coasts, how heavy it is in a bump, how a stream and a slipstream help it, its mobility skill's
## cooldown. A model too big for the race is scaled down (RaceRoster.dress, "race.size").
##
## A race is COUNTDOWN (racers held on the grid, steering but not moving) -> RACING -> OVER. Checkpoints are gates
## along the track (RaceTrack.checkpoints) passed in order: a lap counts only when every one was (so a skipped gate or
## a backwards lap doesn't), the start line being the first and last. Progress (laps, then the last gate and the
## distance past it) gives the positions. When the first human finishes the others get settings.finish_clock s; whoever
## hasn't finished is placed by progress. A racer out of the channel, facing the wrong way or stuck too long (or who
## asks, by holding the powerslide button) is rescued: faded out and back in at their last gate with the speed they had.
##
## Bumps are done here, not by physics: racers never collide (contact exceptions between them), and overlapping ones
## are pushed apart by weight (RaceHandling "weight"): heavy bodies push light ones aside, nobody is hurt.
## Streams (the track's bubble currents) push, and a wake behind a racer gives the one in it a little extra top speed.
##
## `racers` are everyone (RaceMatch.Racer: fish, entry, handling, laps, times). Bots are driven by RaceBot (race_bot.gd:
## a node given fish, race, track, difficulty, handling, traversal). Humans' views are attach_player()'d (split-screen
## too). Lives under the environment (a RaceArena); end() hands the players' fish back.

signal fish_teleported(fish: FishController)
signal phase_changed(phase: int)
## A racer finished a lap: laps done so far and that lap's time.
signal lap_completed(fish: FishController, laps_done: int, lap_time: float)
signal racer_finished(fish: FishController, place: int, time: float)
## A racer was put back on the track: "out of bounds", "wrong way", "stuck" or "button".
signal rescued(fish: FishController, reason: String)
## Two racers bumped: how hard (the closing speed, m/s).
signal bumped(a: FishController, b: FishController, strength: float)
signal race_over(results: Array)
## Online, host: a racer's rescue fade is over and they go back to `at` carrying `push` (a guest moves its own fish).
signal put_back(fish: FishController, at: Transform3D, push: Vector3)
## Online, guest: the local player held the rescue button (the host decides).
signal local_rescue_requested

enum Phase { COUNTDOWN, RACING, OVER }

const ID := "race"
const TITLE := "Fin-ish Line"
const FISH_SCENE := preload("res://scenes/fish.tscn")
## The modifier sets the match pushes on every racer (and pops when it ends).
const MODS_SHARED := "race.shared"
const MODS_HANDLING := "race.handling"
const MODS_RUBBER := "race.rubber"
const MODS_SLIP := "race.slip"
const BOT_PATH := "res://scripts/modes/race/race_bot.gd"
const CANYON_PATH := "res://scripts/modes/race/canyon_reef_arena.gd"
const NET_PATH := "res://scripts/modes/race/race_net.gd"
const GREY_BOX := "Grey Box"
const BOT_NAMES := ["Bubbles", "Finley", "Coral", "Squirt", "Gill", "Dory", "Marlin", "Sandy", "Pearl", "Nemo-ish", "Wanda", "Kelp", "Skipper", "Ripple"]
## How far outside the channel's ellipse (a factor) a racer counts as out of bounds.
const OOB_MARGIN := 1.3
## Facing against the track (cosine) and the speed (m/s) that count as going the wrong way.
const WRONG_WAY_DOT := -0.3
const WRONG_WAY_SPEED := 1.0
## Seconds the powerslide button is held to ask for a rescue.
const RESCUE_HOLD := 0.9
## Seconds after GO before "stuck" is judged.
const STUCK_GRACE := 2.0
## A bump's give: the closing speed handed back (1.3: a little bounce), the push apart at full overlap (m/s^2), and
## the body radius as a share of its length.
const BUMP_BOUNCE := 1.3
const BUMP_SEPARATE := 40.0
const BODY_RADIUS := 0.3
## Inside the channel, how far the soft walls (an arena with no collision) start leaning on a racer (ellipse units).
const WALL_START := 0.92
const WALL_PUSH := 60.0
## Seconds the GO! shows.
const GO_TIME := 1.2
## The entry's weight in a pick for a bot: fish, hunters, titans.
const BOT_FAMILY_WEIGHTS := {RaceRoster.FISH: 0.7, RaceRoster.HUNTER: 0.15, RaceRoster.TITAN: 0.15}


## One racer: a fish, its model, its handling and where it is in the race.
class Racer extends RefCounted:
	var fish: FishController
	var entry: Dictionary = {}
	var row: Dictionary = {}
	var name := ""
	var human := false
	var color := Color.WHITE
	var bot: Node
	var traversal: Traversal
	## The fish's look before the race dressed it ([class, species, skin]), for end().
	var base_look: Array = []
	## The track: last distance (the search's hint) and fix.
	var d := 0.0
	var fix: RaceTrack.Fix
	## Gates: the one to pass next, how many passed, the start line crossed, laps done.
	var next_cp := 0
	var passes := 0
	var started := false
	var laps := 0
	var prev_side := NAN
	var progress := 0.0
	var place := 0
	var lap_start := 0.0
	var lap_times: Array[float] = []
	var best_lap := INF
	var finished := false
	var finish_time := -1.0
	var speed_at_gate := 0.0
	## Rules: seconds out of the channel, facing wrong, nearly still, and the rescue button held.
	var oob_t := 0.0
	var wrong_t := 0.0
	var still_t := 0.0
	var hold_t := 0.0
	var rescue_cd := 0.0
	## No contact for this long (s).
	var ghost := 0.0
	## A rescue under way: 0 none, 1 fading out, 2 fading in; seconds left in the stage and its reason.
	var rescue_stage := 0
	var rescue_left := 0.0
	var rescue_reason := ""
	## A push to give after the next physics ticks (a rescue's carried speed).
	var push_wait := 0
	var push := Vector3.ZERO
	## The start surge: a stride near GO gives it once.
	var surged := false
	## msec of the last stride (a human's), for the start surge.
	var last_stroke := -1000000
	var stroke_hook: Callable
	## Slipstream: seconds in a wake, and the gain (m/s) it gives now.
	var slip_in := 0.0
	var slip_gain := 0.0
	var rubber := 1.0
	## The banner a racer's HUD shows (FINAL LAP, WRONG WAY...) and its counter, so a HUD shows each once.
	var banner := ""
	var banner_left := 0.0
	var banner_serial := 0
	## Seconds of the clock it counts (for stats).
	var in_stream := 0.0
	var in_slip := 0.0
	var rescues := 0
	## Online: a fish another machine drives (its numbers come from the host; no judging and no skill here).
	var puppet := false


var settings := RaceSettings.shared()
var arena: RaceArena
var track: RaceTrack
## This machine runs the race (offline, or the online host).
var authority := true
var phase := Phase.COUNTDOWN
var racers: Array[Racer] = []
## Seconds of the race (from GO), the countdown left, and the finish clock left (-1: not running).
var race_time := 0.0
var count_left := 0.0
var clock_left := -1.0
var go_flash := 0.0
## The last race's results, best first: {fish, name, place, time, best_lap, finished, human, laps}.
var results: Array[Dictionary] = []
## What the local players beat in their personal bests, by fish.
var personal_bests := {}
var rng := RandomNumberGenerator.new()

## A probe forces the first local player's roster key here (instead of their saved pick), so its race is the same on
## every machine. "" in play.
static var forced_pick := ""

var _world: ModeWorld
var _humans: Array[FishController] = []
var _entries: Array[Dictionary] = []
var _by_fish := {}
## Each local player's slot, by their fish (attach_player()), and the camera style pushed on its view.
var _slots := {}
var _tuning_source: FishController
var _look_clock := 0.0
var _rubber_clock := 0.0
var _modifier_clock := 0.0
var _bot_serial := 0
var _go_msec := 0
var _cam_wide := 1.0
var _cam_clock := 0.0
var _built := false


## The mode's picker tile, environment, tuning, card and settings (read through ModeRegistry).
static func descriptor() -> Dictionary:
	var environments := {GREY_BOX: GreyboxArena}
	var canyon: GDScript = _optional(CANYON_PATH)
	if canyon != null:
		environments["Canyon Reef Circuit"] = canyon
	var play := ["Solo", "Split-screen"]
	var out := {
		"id": ID, "title": TITLE, "icon": "mode_obstacle_course",
		"colors": [Color(0.02, 0.15, 0.2), Color(0.35, 0.85, 1.0)],
		"pitch": "Lap racing round a canyon reef: the same speed for everyone, so it is handling, lines and slipstream that win.",
		"short": "Race laps round a canyon reef",
		"environment": RaceMatch.environment_for, "environments": environments, "match": true, "after": "What Stinks?",
		"tuning_preset": "res://presets/nature.cfg",
		"card_text": RaceMatch.card_text, "card_choices": RaceMatch.card_choices, "reset_label": "Restart race",
		"split_screen": true, "join_pick": RaceSetup, "sfx": [[RaceSounds, &"sfx_hook"]], "settings": RaceSettings, "settings_key": RaceSettings.KEY, "settings_after": "what_stinks",
		"setup": RaceSetup,
	}
	var net: GDScript = _optional(NET_PATH)
	if net != null:
		out["net"] = net
		out["net_key"] = RaceSettings.KEY
		play.append("Online")
	out["play"] = play
	return out


## A script another worker's file provides (the Canyon Reef arena, the net adapter), or null while it is missing or
## doesn't compile: the mode runs without it.
static func _optional(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	return script if script != null and script.can_instantiate() else null


static func card_text() -> String:
	return "Fin-ish Line: race laps round a canyon reef against bots and friends. Everyone swims at the same top speed: sweep the stick side to side and stride on the glow. Pass every gate in order, use your skill (RB / Shift) and sit in a rival's wake for a free tow. Hold Ctrl / LB for a rescue if you are stuck."


## The environment the race is on: its card's track (the Grey Box when that track has no arena of its own yet).
static func environment_for(host: Node) -> String:
	var wanted := RaceSettings.shared().track
	var available: Dictionary = host.ENVIRONMENTS
	if available.has(wanted):
		return wanted
	return GREY_BOX


## The match card's choices: track, laps, field size, bots, slipstream, skills.
static func card_choices(card: MatchCard, host: Node) -> void:
	var rs := RaceSettings.shared()
	var tracks: Array = RaceSettings.TRACKS.filter(func(track_name: String) -> bool: return host.ENVIRONMENTS.has(track_name))
	if tracks.size() > 1:
		card.choices.append({"title": "Track", "options": tracks, "index": maxi(tracks.find(rs.track), 0),
				"changed": func(i: int) -> void:
					rs.track = tracks[i]
					host.call_deferred("set_mode", ID)})  # the environment changes: the mode comes back on a new card
	var laps: Array = []
	for n in range(1, 10):
		laps.append("%d lap%s" % [n, "" if n == 1 else "s"])
	card.choices.append({"title": "Laps", "options": laps, "index": clampi(rs.laps, 1, 9) - 1,
			"changed": func(i: int) -> void: rs.laps = i + 1})
	var field: Array = []
	for n in range(2, 13):
		field.append("%d racers" % n)
	card.choices.append({"title": "Field", "options": field, "index": clampi(rs.field_size, 2, 12) - 2,
			"changed": func(i: int) -> void: rs.field_size = i + 2})
	card.choices.append({"title": "Bots", "options": RaceSettings.BOT_NAMES, "index": int(rs.bot_difficulty),
			"changed": func(i: int) -> void: rs.bot_difficulty = i as RaceSettings.Bots})
	card.choices.append({"title": "Slipstream", "options": ["On", "Off"], "index": 0 if rs.slipstream else 1,
			"changed": func(i: int) -> void: rs.slipstream = i == 0})
	card.choices.append({"title": "Skills", "options": ["On", "Off"], "index": 0 if rs.skills else 1,
			"changed": func(i: int) -> void: rs.skills = i == 0})


# --- Mode lifecycle --------------------------------------------------------------

## The environment is ready and the players are known (before the node joins the tree).
func enter(world: ModeWorld) -> void:
	_world = world
	authority = world.options.get("authority", true)
	arena = world.environment as RaceArena
	for slot: PlayerSlot in world.slots:
		_humans.append(slot.fish)
		slot.fish.set_meta("coop_index", slot.index)
	if _humans.is_empty():
		_humans.append(world.fish)


## Play: each local player's camera and HUD.
func start() -> void:
	_world.host.attach_local_players(self)


func _ready() -> void:
	rng.randomize()
	track = arena.track if arena != null else null
	if track == null:
		push_error("RaceMatch: the environment has no race track")
		return
	_entries = RaceRoster.entries()
	_tuning_source = _humans[0]
	_build_racers()
	_built = true
	restart()


func playing() -> bool:
	return true


## R: the host restarts the race (an online guest's can't).
func reset() -> void:
	if authority:
		restart()


func can_reset() -> bool:
	return authority


## Hands the players' fish back: their own look and swimming. Call before freeing the match.
func end() -> void:
	if _world and is_instance_valid(_world.host):
		_world.host.detach_local_players()
	for r in racers:
		_undress(r)
		if r.bot != null and is_instance_valid(r.bot):
			r.bot.queue_free()
		if not r.human and is_instance_valid(r.fish):
			r.fish.queue_free()
	racers.clear()
	_by_fish.clear()


## A local player's own camera, HUD and rescue/skill readouts (LocalCoop calls it for each slot, and for anyone
## joining later).
func attach_player(slot: PlayerSlot) -> void:
	_slots[slot.fish] = slot
	var camera: Node = slot.camera
	camera.claim(null, false)
	camera.push_style(&"race", CameraStyle.settle())
	slot.hud.set_mode_hud(RaceHud.new(self, slot.fish))


func detach_player(slot: PlayerSlot) -> void:
	_slots.erase(slot.fish)
	var camera: Node = slot.camera
	if is_instance_valid(camera):
		camera.release()
		camera.pop_style(&"race")
	if is_instance_valid(slot.hud):
		slot.hud.set_mode_hud(null)


## A split-screen player joining (their fish is in the tree): a racer on the grid, taking a bot's place if the field
## is full.
func add_player(fish: FishController) -> void:
	if _by_fish.has(fish) or track == null:
		return
	if fish.puppet and not authority:
		# Another machine's fish: dressed when its roster key arrives (apply_net_roster_key), placed by its own machine.
		_humans.append(fish)
		_new_racer(fish, _entries[0], true)
		_link_contacts()
		return
	var slot_index := racers.size()
	if racers.size() >= maxi(settings.field_size, 2):
		for i in range(racers.size() - 1, -1, -1):
			if not racers[i].human:
				slot_index = i  # the newcomer takes the dropped bot's grid slot
				_remove_racer(racers[i], true)
				break
	var entry := RaceSetup.joined_entry(fish, _entries)
	if entry.is_empty():
		entry = RaceRoster.entry_of(fish)
	if entry.is_empty():
		entry = _entries[0]
	_humans.append(fish)
	var r := _new_racer(fish, entry, true)
	if r.puppet:  # the host's copy of a guest's fish: it swims on its own machine
		_link_contacts()
		_reset_racer(r, track.grid_slots(maxi(racers.size(), slot_index + 1))[slot_index])
		_announce([fish])
		return
	_dress(r)
	_attach_extras(r)
	var slots := track.grid_slots(maxi(racers.size(), slot_index + 1))
	_reset_racer(r, slots[mini(slot_index, slots.size() - 1)])
	_announce([fish])


## A player leaves (their fish is theirs to free).
func remove_player(fish: FishController) -> void:
	var r: Racer = _by_fish.get(fish)
	if r == null:
		return
	_humans.erase(fish)
	_remove_racer(r, false)


# --- Racers -----------------------------------------------------------------------

func _build_racers() -> void:
	var first := true
	for fish in _humans:
		var entry := _local_pick() if first else RaceRoster.entry_of(fish)
		if entry.is_empty():
			entry = RaceRoster.entry_of(fish)
		if entry.is_empty():
			entry = _entries[0]
		first = false
		_new_racer(fish, entry, true)
	var names: Array = BOT_NAMES.duplicate()
	names.shuffle()
	var taken := {}
	for r in racers:
		taken[r.entry["key"]] = true
	for i in range(racers.size(), maxi(settings.field_size, racers.size()) if authority else 0):  # a guest's bots are puppets
		var entry := _pick_bot_entry(taken)
		taken[entry["key"]] = true
		var fish: FishController = FISH_SCENE.instantiate()
		fish.name = "RaceBot%d" % _bot_serial
		fish.display_name = String(names[_bot_serial % names.size()])
		_bot_serial += 1
		add_child(fish)
		FishTuning.copy(_tuning_source, fish)  # before anything is pushed on the human's
		fish.controls = FishInput.new()  # a bot reads its own controls, never the keyboard
		_new_racer(fish, entry, false)
	for r in racers:
		_dress(r)
	for r in racers:
		_attach_extras(r)
		if not r.human:
			_spawn_bot(r)
	_link_contacts()


func _new_racer(fish: FishController, entry: Dictionary, human: bool) -> Racer:
	var r := Racer.new()
	r.fish = fish
	r.entry = entry
	r.human = human
	r.puppet = fish.puppet
	r.row = RaceHandling.of(entry)
	r.name = fish.display_name if fish.display_name != "" else str(entry["label"])
	r.color = Color.from_hsv(fposmod(float(racers.size()) * 0.137, 1.0), 0.65, 1.0)
	r.base_look = [int(fish.character), fish.species, fish.skin]
	racers.append(r)
	_by_fish[fish] = r
	return r


## A bot's model: a random roster entry (the families weighted), one not worn yet when there is one.
func _pick_bot_entry(taken: Dictionary) -> Dictionary:
	var pool: Array[Dictionary] = []
	for e in _entries:
		if not taken.has(e["key"]):
			pool.append(e)
	if pool.is_empty():
		pool = _entries
	var total := 0.0
	for e in pool:
		total += float(BOT_FAMILY_WEIGHTS.get(e["family"], 0.1)) / float(_family_count(pool, e["family"]))
	var roll := rng.randf() * total
	for e in pool:
		roll -= float(BOT_FAMILY_WEIGHTS.get(e["family"], 0.1)) / float(_family_count(pool, e["family"]))
		if roll <= 0.0:
			return e
	return pool[0]


func _family_count(pool: Array[Dictionary], family: String) -> int:
	var n := 0
	for e in pool:
		if e["family"] == family:
			n += 1
	return maxi(n, 1)


## The racer's model, size cap and the shared and handling modifier sets.
func _dress(r: Racer) -> void:
	r.row = RaceHandling.of(r.entry)
	RaceRoster.dress(r.fish, r.entry, settings.race_size_cap)
	r.fish.team = -1
	_push_modifiers(r)


func _push_modifiers(r: Racer) -> void:
	r.fish.modifiers.push(MODS_SHARED, settings.shared_modifiers(r.fish.stroke_max_speed))
	r.fish.modifiers.push(MODS_HANDLING, RaceHandling.modifiers(r.row))


## Takes off everything the race pushed (and the look a hunter or titan pick changed).
func _undress(r: Racer) -> void:
	if not is_instance_valid(r.fish):
		return
	for set_name in [MODS_SHARED, MODS_HANDLING, MODS_RUBBER, MODS_SLIP, RaceRoster.MODS_SIZE]:
		r.fish.modifiers.pop(set_name)
	if r.traversal != null:
		r.traversal.clear()
		r.fish.speed_scale = 1.0
		r.traversal = null
	if r.stroke_hook.is_valid() and r.fish.stroked.is_connected(r.stroke_hook):
		r.fish.stroked.disconnect(r.stroke_hook)
	if r.human and r.base_look.size() == 3 and (int(r.fish.character) != int(r.base_look[0]) or r.fish.species != int(r.base_look[1]) or r.fish.skin != int(r.base_look[2])):
		r.fish.set_look(int(r.base_look[0]) as FishCharacter.FishClass, int(r.base_look[1]), int(r.base_look[2]))
	r.fish.controls_locked = false
	r.fish.set_model_visible(true)
	for other in racers:
		if other != r and is_instance_valid(other.fish):
			r.fish.remove_collision_exception_with(other.fish)
			other.fish.remove_collision_exception_with(r.fish)


## The skill (a Traversal), the stride hook for the start surge and, for a bot, its driver.
func _attach_extras(r: Racer) -> void:
	if not settings.skills and r.traversal != null:
		r.traversal.clear()
		r.fish.speed_scale = 1.0
		r.traversal = null
	if settings.skills and r.traversal == null:
		var twist := Traversal.new(null, r.fish, self)
		var tuned := TraversalSettings.shared().duplicate() as TraversalSettings
		tuned.twists = true
		tuned.nimble_turn = 1.0  # the passive twists are RaceHandling's job here: nothing but the skill itself
		tuned.glide_drag = 1.0
		tuned.armour_speed = 1.0
		tuned.streamline_speed = 0.0
		twist.settings = tuned
		var skill_class := int(r.entry["skill_class"])
		if skill_class != int(r.fish.character):
			twist.skill_class = skill_class
		r.traversal = twist
	if r.traversal != null:
		r.traversal.cooldown_scale = settings.skill_cooldown_scale * float(r.row["skill_cooldown"])
	if r.human and not r.stroke_hook.is_valid():
		r.stroke_hook = func(_quality: float) -> void: _on_stroke(r)
		r.fish.stroked.connect(r.stroke_hook)


## A bot's driver (RaceBot, race_bot.gd): none while that file is missing or doesn't compile.
func _spawn_bot(r: Racer) -> void:
	var bot_script := _optional(BOT_PATH)
	if bot_script == null:
		return
	var bot: Node = bot_script.new()
	bot.set("fish", r.fish)
	bot.set("race", self)
	bot.set("track", track)
	bot.set("difficulty", int(settings.bot_difficulty))
	bot.set("handling", r.row)
	bot.set("traversal", r.traversal)
	bot.name = "%sDriver" % r.fish.name
	add_child(bot)
	r.bot = bot


## Every pair of racers passes through each other in the physics engine: bumps are _bump()'s.
func _link_contacts() -> void:
	for a in racers:
		for b in racers:
			if a != b:
				a.fish.add_collision_exception_with(b.fish)


func _remove_racer(r: Racer, free_fish: bool) -> void:
	_undress(r)
	if r.bot != null and is_instance_valid(r.bot):
		r.bot.queue_free()
	racers.erase(r)
	_by_fish.erase(r.fish)
	if free_fish and is_instance_valid(r.fish):
		r.fish.queue_free()


# --- A race ------------------------------------------------------------------------

## Back to the grid: a new race, with the countdown.
func restart() -> void:
	if not _built:
		return
	phase = Phase.COUNTDOWN
	race_time = 0.0
	clock_left = -1.0
	go_flash = 0.0
	count_left = settings.countdown
	results.clear()
	personal_bests.clear()
	_resolve_picks()
	var slots := track.grid_slots(racers.size())
	var moved: Array = []
	for i in racers.size():
		_reset_racer(racers[i], slots[i])
		moved.append(racers[i].fish)
	phase_changed.emit(phase)
	_announce(moved)
	if count_left <= 0.0:
		_go()


## `slot` empty (a guest's restart): the state only, the fish is put on the grid by the host.
func _reset_racer(r: Racer, slot: Dictionary = {}) -> void:
	r.next_cp = 0
	r.passes = 0
	r.started = false
	r.laps = 0
	r.prev_side = NAN
	r.lap_start = 0.0
	r.lap_times.clear()
	r.best_lap = INF
	r.finished = false
	r.finish_time = -1.0
	r.place = 0
	r.oob_t = 0.0
	r.wrong_t = 0.0
	r.still_t = 0.0
	r.hold_t = 0.0
	r.rescue_cd = 0.0
	r.ghost = INF  # no contact on the grid; GO sets the grace
	r.rescue_stage = 0
	r.push_wait = 0
	r.surged = false
	r.last_stroke = -1000000
	r.slip_in = 0.0
	r.slip_gain = 0.0
	r.rubber = 1.0
	r.banner = ""
	r.banner_left = 0.0
	r.in_stream = 0.0
	r.in_slip = 0.0
	r.rescues = 0
	r.speed_at_gate = 0.0
	if r.traversal != null:
		r.traversal.reset()
	r.fish.set_model_visible(true)
	if slot.is_empty():
		r.fish.modifiers.pop(MODS_RUBBER)
		r.fish.modifiers.pop(MODS_SLIP)
		return
	r.d = float(slot["d"])
	r.fix = track.nearest((slot["xform"] as Transform3D).origin, r.d)
	r.progress = track.delta(0.0, r.d)
	r.fish.revive(slot["xform"])
	r.fish.modifiers.pop(MODS_RUBBER)
	r.fish.modifiers.pop(MODS_SLIP)


## GO: the racers are released, a stride near now gets the surge, contact is back after the grace.
func _go() -> void:
	phase = Phase.RACING
	race_time = 0.0
	go_flash = GO_TIME
	_go_msec = Time.get_ticks_msec()
	for r in racers:
		r.ghost = settings.ghost_time
		r.prev_side = NAN
		r.lap_start = 0.0
		if r.puppet:
			continue
		if not r.human:
			_surge(r, 0.5 + 0.25 * float(int(settings.bot_difficulty)))
		elif float(_go_msec - r.last_stroke) <= settings.start_window * 1000.0:
			_surge(r, 1.0)
	phase_changed.emit(phase)


## A human's stride: inside the start window around GO it earns the surge (once).
func _on_stroke(r: Racer) -> void:
	r.last_stroke = Time.get_ticks_msec()
	if phase == Phase.RACING and not r.surged and race_time <= settings.start_window:
		_surge(r, 1.0)


func _surge(r: Racer, share: float) -> void:
	if r.surged or settings.start_surge <= 0.0:
		return
	r.surged = true
	r.fish.apply_push(-r.fish.global_basis.z * settings.start_surge * share)


# --- The tick ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _built or racers.is_empty():
		return
	_look_clock += delta
	if _look_clock >= 0.5:
		_look_clock = 0.0
		_resolve_picks()
	_modifier_clock += delta
	if _modifier_clock >= 0.25:
		_modifier_clock = 0.0
		for r in racers:
			if not r.puppet:
				_push_modifiers(r)
				_attach_extras(r)  # a skill switched on in the panel; cooldowns follow it
	go_flash = maxf(go_flash - delta, 0.0)
	_tick_cameras(delta)
	for r in racers:
		_tick_racer(r, delta)
	match phase:
		Phase.COUNTDOWN:
			for r in racers:
				if not r.puppet:
					r.fish.apply_push(-r.fish.linear_velocity)  # held on the grid (steering still turns the nose)
			if authority:
				count_left -= delta
				if count_left <= 0.0:
					_go()
			else:
				count_left = maxf(count_left - delta, 0.0)  # the host says when GO is
		Phase.RACING:
			race_time += delta
			if authority:
				for r in racers:
					_track(r, delta)
					_watch(r, delta)
					if not r.puppet:
						_currents(r, delta)
				_rubber_band(delta)
				_rank()
				_run_clock(delta)
				_check_end()
			else:
				for r in racers:
					_guest_watch(r, delta)
				if clock_left > 0.0:
					clock_left = maxf(clock_left - delta, 0.0)
		Phase.OVER:
			if authority:
				for r in racers:
					_track_free(r)
	if authority:
		_bump(delta)
	_environment_forces(delta)


## Per racer and tick: the skill, the carried push, the ghost, a rescue's fade and the banner.
func _tick_racer(r: Racer, delta: float) -> void:
	if not is_instance_valid(r.fish):
		return
	if r.traversal != null and not r.puppet:
		r.traversal.update(delta)
		r.fish.speed_scale = r.traversal.speed_factor()
	r.ghost = maxf(r.ghost - delta, 0.0) if not is_inf(r.ghost) else r.ghost
	r.rescue_cd = maxf(r.rescue_cd - delta, 0.0)
	r.banner_left = maxf(r.banner_left - delta, 0.0)
	if r.push_wait > 0:
		r.push_wait -= 1
		if r.push_wait == 0:
			r.fish.apply_push(r.push)
	if r.rescue_stage != 0:
		r.rescue_left -= delta
		if r.rescue_left <= 0.0:
			if r.rescue_stage == 1:
				if authority:
					_put_back(r)
				else:
					r.rescue_left = 0.0  # faded out: waiting for the host's put-back (apply_net_put_back)
			else:
				r.rescue_stage = 0
				r.fish.set_model_visible(true)


## Which gate a racer's passed, their lap and place.
func _track(r: Racer, delta: float) -> void:
	if r.finished or r.rescue_stage != 0 or not is_instance_valid(r.fish):
		return
	var p := r.fish.global_position
	r.fix = track.nearest(p, r.d)
	r.d = r.fix.d
	var cp: Dictionary = track.checkpoints[r.next_cp]
	var gate_pos: Vector3 = cp["pos"]
	var side := (p - gate_pos).dot(cp["forward"] as Vector3)
	if not is_nan(r.prev_side) and r.prev_side < 0.0 and side >= 0.0 and side < 12.0 and _in_gate(cp, p):
		_pass_gate(r)
	r.prev_side = side
	r.progress = _progress_of(r)
	if not track.streams_at(r.d).is_empty():
		r.in_stream += delta


## A point inside the gate's ellipse (a little generous: the gate is crossed, not hit).
func _in_gate(cp: Dictionary, p: Vector3) -> bool:
	var rel := p - (cp["pos"] as Vector3)
	var a := float(cp["width"]) * 0.5 * 1.15
	var b := float(cp["height"]) * 0.5 * 1.15
	var lateral := rel.dot(cp["right"] as Vector3)
	var vertical := rel.dot(cp["up"] as Vector3)
	return (lateral * lateral) / (a * a) + (vertical * vertical) / (b * b) <= 1.0


func _pass_gate(r: Racer) -> void:
	var index := r.next_cp
	r.passes += 1
	r.speed_at_gate = r.fish.speed
	r.next_cp = (index + 1) % track.checkpoints.size()
	if index != 0:
		return
	if not r.started:
		r.started = true  # the first crossing after GO starts lap 1
		return
	var lap_time := race_time - r.lap_start
	r.lap_start = race_time
	r.laps += 1
	r.lap_times.append(lap_time)
	r.best_lap = minf(r.best_lap, lap_time)
	lap_completed.emit(r.fish, r.laps, lap_time)
	if r.laps >= settings.laps:
		_finish(r)
	elif r.laps == settings.laps - 1:
		_banner(r, "FINAL LAP", 2.5)
	else:
		_banner(r, "LAP %d / %d" % [r.laps + 1, settings.laps], 1.8)


## Laps, then the last gate passed and the distance past it (not past the next gate): skipping gates gains nothing.
func _progress_of(r: Racer) -> float:
	var count := track.checkpoints.size()
	if not r.started:
		return track.delta(0.0, r.d)
	var base := (r.next_cp - 1 + count) % count
	var base_d := float((track.checkpoints[base] as Dictionary)["d"])
	var next_d := float((track.checkpoints[r.next_cp] as Dictionary)["d"]) if r.next_cp != 0 else track.lap_length
	var gap := maxf(next_d - base_d, 0.001)
	var past := clampf(track.delta(base_d, r.d), 0.0, gap)
	return float(r.laps) * track.lap_length + base_d + past


func _finish(r: Racer) -> void:
	r.finished = true
	r.finish_time = race_time
	var done := 0
	for other in racers:
		if other.finished and other != r:
			done += 1
	r.place = done + 1
	r.progress = float(settings.laps) * track.lap_length
	_banner(r, "FINISHED  %s" % _ordinal(r.place), 4.0)
	if r.human:
		personal_bests[r.fish] = RaceBest.record(track.track_name, settings.laps, r.finish_time, r.best_lap)
	racer_finished.emit(r.fish, r.place, r.finish_time)


## The finish clock starts when the first human finishes (or, with every bot home and no human done, from the last bot).
func _run_clock(delta: float) -> void:
	if clock_left < 0.0:
		var human_done := false
		var bots_left := 0
		for r in racers:
			if r.human and r.finished:
				human_done = true
			elif not r.human and not r.finished:
				bots_left += 1
		if human_done or (bots_left == 0 and not racers.is_empty()):
			clock_left = settings.finish_clock
		return
	clock_left = maxf(clock_left - delta, 0.0)


## The race ends when everyone's done, every human is, or the finish clock runs out.
func _check_end() -> void:
	var unfinished := 0
	for r in racers:
		if not r.finished:
			unfinished += 1
	var over := unfinished == 0
	if not over and clock_left == 0.0:
		over = true
	if not over and not _humans.is_empty() and humans_unfinished() == 0:
		over = true
	if over:
		_end_race()


func _end_race() -> void:
	phase = Phase.OVER
	_rank()
	results.clear()
	var total := float(settings.laps) * track.lap_length
	for r in _ranked():
		var projected := -1.0
		if not r.finished:
			var average := maxf(r.progress, 1.0) / maxf(race_time, 1.0)
			projected = race_time + (total - r.progress) / maxf(average, 5.0)
		results.append({"fish": r.fish, "name": r.name, "place": r.place, "time": r.finish_time if r.finished else projected,
				"best_lap": r.best_lap, "finished": r.finished, "human": r.human, "laps": r.laps, "entry": str(r.entry["label"])})
	phase_changed.emit(phase)
	race_over.emit(results)


## Positions, 1 first: finishers by their finish, then everyone by progress.
func _rank() -> void:
	var order := _ranked()
	for i in order.size():
		order[i].place = i + 1


func _ranked() -> Array[Racer]:
	var order: Array[Racer] = []
	order.assign(racers)
	order.sort_custom(func(a: Racer, b: Racer) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time or (a.finish_time == b.finish_time and a.place < b.place)
		if absf(a.progress - b.progress) > 0.001:
			return a.progress > b.progress
		return a.place < b.place)
	return order


## After the race: just where the racers are (their bots may keep swimming).
func _track_free(r: Racer) -> void:
	if r.finished or not is_instance_valid(r.fish):
		return
	r.fix = track.nearest(r.fish.global_position, r.d)
	r.d = r.fix.d


# --- Rules: out of bounds, wrong way, stuck, the rescue button -----------------------

func _watch(r: Racer, delta: float) -> void:
	if r.finished or r.rescue_stage != 0 or r.fix == null or not is_instance_valid(r.fish):
		return
	var fish := r.fish
	var reason := ""
	r.oob_t = r.oob_t + delta if not track.in_reach(r.fix, OOB_MARGIN) else maxf(r.oob_t - delta * 2.0, 0.0)
	if settings.race_oob_time > 0.0 and r.oob_t >= settings.race_oob_time:
		reason = "out of bounds"
	var against := (-fish.global_basis.z).dot(r.fix.forward) < WRONG_WAY_DOT and fish.speed > WRONG_WAY_SPEED
	r.wrong_t = r.wrong_t + delta if against else maxf(r.wrong_t - delta * 2.0, 0.0)
	if r.wrong_t >= settings.wrong_way_banner:
		if r.banner != "WRONG WAY":
			_banner(r, "WRONG WAY", 0.6)
		else:
			r.banner_left = 0.6  # held while it lasts
	if reason == "" and settings.race_wrong_way_time > 0.0 and r.wrong_t >= settings.race_wrong_way_time:
		reason = "wrong way"
	var still := fish.speed < settings.stuck_speed and race_time > STUCK_GRACE
	r.still_t = r.still_t + delta if still else 0.0
	if reason == "" and settings.stuck_time > 0.0 and r.still_t >= settings.stuck_time:
		reason = "stuck"
	if r.human and r.rescue_cd <= 0.0:
		var asked := fish._player_input().pressed("powerslide") if fish.controls == null else false
		r.hold_t = r.hold_t + delta if asked else 0.0
		if reason == "" and r.hold_t >= RESCUE_HOLD:
			reason = "button"
	if reason != "":
		rescue(r.fish, reason)


## Puts `fish` back at its last gate (fading out first), whatever the reason; false when it can't be now.
func rescue(fish: FishController, reason: String) -> bool:
	var r: Racer = _by_fish.get(fish)
	if r == null or r.finished or r.rescue_stage != 0 or phase == Phase.COUNTDOWN:
		return false
	r.rescue_stage = 1
	r.rescue_left = settings.rescue_fade
	r.rescue_reason = reason
	r.rescue_cd = settings.rescue_cooldown
	r.hold_t = 0.0
	r.oob_t = 0.0
	r.wrong_t = 0.0
	r.still_t = 0.0
	r.ghost = INF
	r.rescues += 1
	_banner(r, "RESCUED  (%s)" % reason.to_upper(), 2.0)
	rescued.emit(fish, reason)
	return true


## The fade-out's over: back at the last gate's centre, facing along the track, carrying the speed it had there.
func _put_back(r: Racer) -> void:
	var count := track.checkpoints.size()
	var last := (r.next_cp - 1 + count) % count if r.started else 0
	var cp: Dictionary = track.checkpoints[last]
	var forward: Vector3 = cp["forward"]
	var at := (cp["pos"] as Vector3) + (cp["right"] as Vector3) * track.line_offset(float(cp["d"]))
	r.fish.revive(Transform3D(Basis((cp["right"] as Vector3), (cp["up"] as Vector3), -forward), at))
	r.d = float(cp["d"])
	r.fix = track.nearest(at, r.d)
	r.prev_side = NAN
	r.push = forward * minf(r.speed_at_gate, settings.race_top_speed)
	r.push_wait = 3
	r.rescue_stage = 2
	r.rescue_left = settings.rescue_fade
	r.ghost = settings.ghost_time + settings.rescue_fade
	r.fish.set_model_visible(true)
	_announce([r.fish])
	put_back.emit(r.fish, Transform3D(Basis((cp["right"] as Vector3), (cp["up"] as Vector3), -forward), at), r.push)


# --- Bumps, currents, bots' catch-up ------------------------------------------------

## Overlapping racers push each other apart by weight: the lighter one moves more. No damage.
func _bump(delta: float) -> void:
	if not settings.bumps:
		return
	var n := racers.size()
	for i in n:
		var a := racers[i]
		if a.ghost > 0.0 or a.rescue_stage != 0 or not is_instance_valid(a.fish):
			continue
		for j in range(i + 1, n):
			var b := racers[j]
			if b.ghost > 0.0 or b.rescue_stage != 0 or not is_instance_valid(b.fish):
				continue
			var off := a.fish.global_position - b.fish.global_position
			var reach := _radius(a) + _radius(b)
			var dist := off.length()
			if dist >= reach or dist < 0.001:
				continue
			var normal := off / dist
			var mass_a := maxf(float(a.row["weight"]) * settings.bump_strength, 0.05)
			var mass_b := maxf(float(b.row["weight"]) * settings.bump_strength, 0.05)
			var closing := -(a.fish.linear_velocity - b.fish.linear_velocity).dot(normal)
			var overlap := (reach - dist) / reach
			var impulse := (maxf(closing * BUMP_BOUNCE, 0.0) + overlap * BUMP_SEPARATE * delta) / (1.0 / mass_a + 1.0 / mass_b)
			a.fish.apply_push(normal * impulse / mass_a)
			b.fish.apply_push(-normal * impulse / mass_b)
			if closing > 1.0:
				bumped.emit(a.fish, b.fish, closing)


func _radius(r: Racer) -> float:
	return r.fish.hitbox_length * BODY_RADIUS + 0.1


## Bubble streams push along the track; a wake gives a racer behind another extra top speed.
func _currents(r: Racer, delta: float) -> void:
	if r.finished or r.rescue_stage != 0 or r.fix == null or not is_instance_valid(r.fish):
		return
	var fish := r.fish
	var forward_speed := fish.linear_velocity.dot(r.fix.forward)
	for index in track.streams_at(r.fix.d):
		var stream: Dictionary = track.streams[index]
		var offset: Vector2 = stream["offset"]
		var radius := float(stream["radius"])
		var dist := Vector2(r.fix.lateral - offset.x, r.fix.vertical - offset.y).length()
		if dist >= radius or forward_speed >= settings.race_top_speed + settings.stream_max_gain:
			continue
		var core := 1.0 - dist / radius
		fish.apply_push(r.fix.forward * settings.stream_push * float(r.row["stream_grip"]) * core * delta)
	var gain := 0.0
	if settings.slipstream:
		var in_wake := false
		for other in racers:
			if other != r and is_instance_valid(other.fish) and other.rescue_stage == 0 and _in_wake(r, other):
				in_wake = true
				break
		r.slip_in = r.slip_in + delta if in_wake else 0.0
		if in_wake and r.slip_in >= settings.slip_delay:
			r.slip_gain = settings.slip_gain * float(r.row["slip_gain"])
			r.in_slip += delta
		elif not in_wake and settings.slip_fade > 0.0:
			r.slip_gain = maxf(r.slip_gain - settings.slip_gain * float(r.row["slip_gain"]) * delta / settings.slip_fade, 0.0)
		elif not in_wake:
			r.slip_gain = 0.0
		gain = r.slip_gain
	if gain > 0.001:
		fish.modifiers.push(MODS_SLIP, {"top_speed": 1.0 + gain / maxf(settings.race_top_speed, 1.0)})
	else:
		fish.modifiers.pop(MODS_SLIP)


## `r` sits in `other`'s wake: behind it, inside the cone.
func _in_wake(r: Racer, other: Racer) -> bool:
	var heading := -other.fish.global_basis.z
	var behind := r.fish.global_position - other.fish.global_position
	var length := behind.length()
	var reach := settings.slip_length * maxf(other.fish.hitbox_length, 0.5)
	if length < 0.5 or length > reach:
		return false
	return (-heading).dot(behind / length) >= cos(deg_to_rad(settings.slip_angle))


## Bots only: a little faster behind the leading human, a little slower far ahead of them (RaceSettings.rubber_for).
func _rubber_band(delta: float) -> void:
	_rubber_clock += delta
	if _rubber_clock < 0.2:
		return
	_rubber_clock = 0.0
	var band := settings.rubber_for()
	var lead_human := -INF
	for r in racers:
		if r.human and not r.finished:
			lead_human = maxf(lead_human, r.progress)
	for r in racers:
		if r.human or not is_instance_valid(r.fish):
			continue
		if band <= 0.0 or is_inf(lead_human):
			r.rubber = 1.0
			r.fish.modifiers.pop(MODS_RUBBER)
			continue
		var gap := clampf((r.progress - lead_human) / maxf(settings.rubber_gap, 1.0), -1.0, 1.0)  # + ahead of the human
		r.rubber = 1.0 - band * gap
		r.fish.modifiers.push(MODS_RUBBER, {"top_speed": r.rubber})


## The track's own forces on every racer: the soft ceiling, and (an arena with no collision) the soft walls.
func _environment_forces(delta: float) -> void:
	if arena == null:
		return
	for r in racers:
		if not is_instance_valid(r.fish) or r.fix == null or r.rescue_stage != 0:
			continue
		var ceiling := arena.ceiling_accel(r.fish.global_position)
		if ceiling != Vector3.ZERO:
			r.fish.apply_push(ceiling * delta)
		if arena.soft_walls:
			_lean_in(r, delta)


## A racer past the channel's edge is leaned back in, the way out damped.
func _lean_in(r: Racer, delta: float) -> void:
	var fix := r.fix
	var a := fix.width * 0.5
	var b := fix.height * 0.5
	var level := sqrt((fix.lateral * fix.lateral) / (a * a) + (fix.vertical * fix.vertical) / (b * b))
	if level <= WALL_START:
		return
	var inward := -(fix.right * (fix.lateral / (a * a)) + fix.up * (fix.vertical / (b * b))).normalized()
	var depth := level - WALL_START
	r.fish.apply_push(inward * WALL_PUSH * depth * delta)
	var out_speed := -r.fish.linear_velocity.dot(inward)
	if out_speed > 0.0 and level > 1.0:
		r.fish.apply_push(inward * out_speed * minf(depth * 40.0 * delta, 1.0))


# --- Picks -------------------------------------------------------------------------

## The first local player's saved pick is their model: a changed one (Change Character, a rematch) is worn now.
func _resolve_picks() -> void:
	var r: Racer = null
	for fish in _humans:
		var candidate: Racer = _by_fish.get(fish)
		if candidate != null and not candidate.puppet:
			r = candidate
			break
	if r == null:
		return
	var entry := _local_pick()
	if entry.is_empty() or entry["key"] == r.entry["key"]:
		return
	_undress_model(r)
	r.entry = entry
	_dress(r)
	_attach_extras(r)
	_announce([r.fish])


## The first local player's model: the saved pick (RaceSetup), or the roster key a probe forced.
func _local_pick() -> Dictionary:
	if forced_pick != "":
		for e in _entries:
			if e["key"] == forced_pick:
				return e
	return RaceSetup.picked_entry(_entries)


## Takes the size cap and the race sets off, so a new model is dressed fresh.
func _undress_model(r: Racer) -> void:
	for set_name in [RaceRoster.MODS_SIZE]:
		r.fish.modifiers.pop(set_name)
	if r.traversal != null:
		r.traversal.clear()
		r.traversal = null


# --- For the HUD and the bots --------------------------------------------------------

func racer_of(fish: FishController) -> Racer:
	return _by_fish.get(fish)


## True from GO until the race is over: the bots drive.
var racing: bool:
	get:
		return phase == Phase.RACING


## Every racer's fish (humans and bots).
func racer_fish() -> Array[FishController]:
	var out: Array[FishController] = []
	for r in racers:
		out.append(r.fish)
	return out


func progress_of(fish: FishController) -> float:
	var r: Racer = _by_fish.get(fish)
	return r.progress if r != null else 0.0


## 1-based position (0 for a fish not racing).
func position_of(fish: FishController) -> int:
	var r: Racer = _by_fish.get(fish)
	return r.place if r != null else 0


func fix_of(fish: FishController) -> RaceTrack.Fix:
	var r: Racer = _by_fish.get(fish)
	return r.fix if r != null else null


func rubber_of(fish: FishController) -> float:
	var r: Racer = _by_fish.get(fish)
	return r.rubber if r != null else 1.0


func is_human(fish: FishController) -> bool:
	var r: Racer = _by_fish.get(fish)
	return r != null and r.human


func humans_unfinished() -> int:
	var n := 0
	for r in racers:
		if r.human and not r.finished:
			n += 1
	return n


## 0..1 black over a racer's view while they are rescued.
func fade_of(fish: FishController) -> float:
	var r: Racer = _by_fish.get(fish)
	if r == null or r.rescue_stage == 0:
		return 0.0
	var span := maxf(settings.rescue_fade, 0.001)
	var share := clampf(r.rescue_left / span, 0.0, 1.0)
	return 1.0 - share if r.rescue_stage == 1 else share


## The 3-2-1-GO text.
func countdown_text() -> String:
	if phase == Phase.COUNTDOWN:
		return str(maxi(ceili(count_left), 1)) if count_left > 0.0 else "GO!"
	if go_flash > 0.0:
		return "GO!"
	return ""


## The seconds the racer's current lap has run.
func lap_time_of(fish: FishController) -> float:
	var r: Racer = _by_fish.get(fish)
	if r == null or phase == Phase.COUNTDOWN:
		return 0.0
	return (r.finish_time if r.finished else race_time) - r.lap_start


func _banner(r: Racer, text: String, seconds: float) -> void:
	r.banner = text
	r.banner_left = seconds
	r.banner_serial += 1


static func _ordinal(n: int) -> String:
	var tail := n % 100
	if tail >= 11 and tail <= 13:
		return "%dth" % n
	match n % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n


## Cameras snap to racers that were moved (after the physics has placed them).
func _announce(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)


# --- Online (RaceNet, race_net.gd) ---------------------------------------------------
# The host (authority) judges everything above. A guest runs its own fish (skill, surge, streams, banners, fade) and
# shows the host's numbers: these are what RaceNet feeds it.

## A guest's local player: the rescue button asks the host; the stream push is theirs; their fix follows their fish.
func _guest_watch(r: Racer, delta: float) -> void:
	if r.puppet or not is_instance_valid(r.fish):
		return
	r.fix = track.nearest(r.fish.global_position, r.d)
	r.d = r.fix.d
	if r.finished or r.rescue_stage != 0:
		return
	_currents(r, delta)
	if r.human and r.fish.controls == null:
		var asked: bool = r.fish._player_input().pressed("powerslide")
		r.hold_t = r.hold_t + delta if asked else 0.0
		if r.hold_t >= RESCUE_HOLD:
			r.hold_t = 0.0
			local_rescue_requested.emit()


## A host's bot as a puppet on this machine (hidden by RaceNet until its first snapshot).
func spawn_net_bot(id: int, key: String, display: String) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	fish.name = "RaceBot%d" % id
	fish.display_name = display
	fish.puppet = true
	add_child(fish)
	var entry := RaceRoster.find(key)
	var r := _new_racer(fish, entry if not entry.is_empty() else _entries[0], false)
	if not entry.is_empty():
		_dress(r)
	_link_contacts()
	return fish


## Dresses a puppet as the roster entry `key` (a human's, whose look the host knows).
func apply_net_roster_key(fish: FishController, key: String) -> void:
	var r: Racer = _by_fish.get(fish)
	var entry := RaceRoster.find(key)
	if r == null or entry.is_empty() or str(r.entry["key"]) == key:
		return
	r.entry = entry
	r.row = RaceHandling.of(entry)
	_dress(r)


## The host's phase and clocks. COUNTDOWN -> RACING does GO's effects here.
func apply_net_phase(new_phase: int, count: float, time: float, clock: float) -> void:
	var before := phase
	count_left = count
	race_time = time
	clock_left = clock
	if new_phase == before:
		return
	if new_phase == Phase.RACING and before == Phase.COUNTDOWN:
		_go()  # sets the phase, the grace and our own surge, and emits phase_changed
		race_time = time
		clock_left = clock
		return
	phase = new_phase as Phase
	phase_changed.emit(phase)


func apply_net_clock(time: float, clock: float) -> void:
	race_time = time
	clock_left = clock


## Back to the grid for a new race (the host puts the fish there).
func apply_net_restart(count: float) -> void:
	phase = Phase.COUNTDOWN
	race_time = 0.0
	clock_left = -1.0
	go_flash = 0.0
	count_left = count
	results.clear()
	personal_bests.clear()
	for r in racers:
		_reset_racer(r)
	phase_changed.emit(phase)


## Rows: {fish, laps, d, progress, place, next_cp, started, finished, best_lap, finish_time, rescue_stage}.
func apply_net_standings(rows: Array[Dictionary]) -> void:
	for row in rows:
		var r: Racer = _by_fish.get(row["fish"])
		if r == null:
			continue
		r.laps = int(row["laps"])
		r.progress = float(row["progress"])
		r.place = int(row["place"])
		r.next_cp = int(row["next_cp"])
		r.started = bool(row["started"])
		r.finished = bool(row["finished"])
		r.best_lap = float(row["best_lap"])
		r.finish_time = float(row["finish_time"])
		if r.puppet:
			r.d = float(row["d"])
			r.rescue_stage = int(row["rescue_stage"])
			if is_instance_valid(r.fish):
				r.fix = track.nearest(r.fish.global_position, r.d)


func apply_net_lap(fish: FishController, laps_done: int, lap_time: float) -> void:
	var r: Racer = _by_fish.get(fish)
	if r == null:
		return
	r.laps = laps_done
	r.lap_times.append(lap_time)
	r.best_lap = minf(r.best_lap, lap_time)
	lap_completed.emit(fish, laps_done, lap_time)
	if laps_done >= settings.laps:
		return
	if laps_done == settings.laps - 1:
		_banner(r, "FINAL LAP", 2.5)
	else:
		_banner(r, "LAP %d / %d" % [laps_done + 1, settings.laps], 1.8)


func apply_net_finish(fish: FishController, place: int, time: float, best_lap: float) -> void:
	var r: Racer = _by_fish.get(fish)
	if r == null:
		return
	r.finished = true
	r.place = place
	r.finish_time = time
	r.best_lap = best_lap
	_banner(r, "FINISHED  %s" % _ordinal(place), 4.0)
	if r.human and not r.puppet:
		personal_bests[fish] = RaceBest.record(track.track_name, settings.laps, time, best_lap)
	racer_finished.emit(fish, place, time)


## A rescue began (anyone's): the fade-out and the banner.
func apply_net_rescue_begin(fish: FishController, reason: String) -> void:
	var r: Racer = _by_fish.get(fish)
	if r == null:
		return
	r.rescue_stage = 1
	r.rescue_left = settings.rescue_fade
	r.rescue_reason = reason
	r.hold_t = 0.0
	r.rescues += 1
	_banner(r, "RESCUED  (%s)" % reason.to_upper(), 2.0)
	rescued.emit(fish, reason)


## The host's put-back for our own fish: moved here, the carried push, the fade-in.
func apply_net_put_back(fish: FishController, at: Transform3D, push: Vector3) -> void:
	var r: Racer = _by_fish.get(fish)
	if r == null:
		return
	r.fish.revive(at)
	r.fix = track.nearest(at.origin, r.d)
	r.d = r.fix.d
	r.prev_side = NAN
	r.push = push
	r.push_wait = 3
	r.rescue_stage = 2
	r.rescue_left = settings.rescue_fade
	r.ghost = settings.ghost_time + settings.rescue_fade
	r.fish.set_model_visible(true)
	_announce([fish])


## Rows: {fish, name, place, time, best_lap, finished, human, laps, entry}.
func apply_net_results(rows: Array[Dictionary]) -> void:
	results.assign(rows)
	phase = Phase.OVER
	phase_changed.emit(phase)
	race_over.emit(results)


# --- Cameras -----------------------------------------------------------------------

## The chase view per local player: further back with a bigger body and more speed, and wide on the grid (easing in to
## the normal view after GO). Re-pushed at 4 Hz: a pushed style is read when it is pushed.
func _tick_cameras(delta: float) -> void:
	_cam_wide = move_toward(_cam_wide, 1.0 if phase == Phase.COUNTDOWN else 0.0, delta / 1.5)
	_cam_clock += delta
	if _cam_clock < 0.25:
		return
	_cam_clock = 0.0
	for fish: FishController in _slots:
		var slot: PlayerSlot = _slots[fish]
		if not is_instance_valid(fish) or not is_instance_valid(slot.camera):
			continue
		var style := CameraStyle.settle()
		var body := maxf(fish.hitbox_length / 1.2, 1.0)  # a Skirmisher's view is the 1.0 one
		style.extra_distance = (body - 1.0) * settings.cam_size_back + fish.speed * settings.cam_speed_back + _cam_wide * settings.cam_grid_back
		style.extra_height = (body - 1.0) * settings.cam_size_up + _cam_wide * settings.cam_grid_up
		(slot.camera as Node).call(&"push_style", &"race", style)
