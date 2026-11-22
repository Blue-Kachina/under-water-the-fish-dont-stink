class_name RaceSimRig
extends RefCounted
## Shared set-up for race_sim and race_roster_bench (Fin-ish Line, planning_race.md section 9): the Ocean with Nature's
## tuning, a RaceTrack, and racers built the way RaceMatch builds them (the roster entry's look and size cap, the shared
## speed and the handling row as FishModifiers, a RaceBot, a Traversal for the mobility skill). It stands in for
## RaceMatch's own spawning so the balance data can be gathered before (and apart from) the match.

const FISH_SCENE := preload("res://scenes/fish.tscn")
## The modifier names RaceMatch uses (race_phase0.md).
const MODS_SHARED := "race.shared"
const MODS_HANDLING := "race.handling"


## One racer: fish + bot + skill + stats.
class Racer extends RefCounted:
	var fish: FishController
	var bot: RaceBot
	var entry: Dictionary
	var row: Dictionary
	var skill: Traversal
	var laps_done := 0
	var lap_start := 0.0
	var lap_times: Array[float] = []
	var finished_at := -1.0
	var rescues := 0
	var best_d := 0.0
	var last_d := 0.0
	var still := 0.0
	var oob := 0.0
	var last_checkpoint := 0


var main: Node
var host: Node
var track: RaceTrack
var settings := RaceSettings.shared()
var racers: Array[Racer] = []


func _init(main_in: Node, host_in: Node) -> void:
	main = main_in
	host = host_in


## The track script's name to its data: the Grey Box, or the Canyon Reef Circuit once its script exists.
static func track_data(name: String) -> Dictionary:
	if name.to_lower().begins_with("canyon") and ResourceLoader.exists("res://scripts/modes/race/tracks/canyon_reef_track.gd"):
		return (load("res://scripts/modes/race/tracks/canyon_reef_track.gd") as GDScript).call("data")
	return GreyboxTrack.data()


func build_track(name: String) -> void:
	track = RaceTrack.build(track_data(name))


## Adds a racer for `entry` on grid slot `slot` (a Dictionary from RaceTrack.grid_slots) with a bot of `tier`.
func add(entry: Dictionary, slot: Dictionary, tier: RaceSettings.Bots, ideal := false) -> Racer:
	var r := Racer.new()
	r.entry = entry
	r.row = RaceHandling.of(entry)
	var fish: FishController = FISH_SCENE.instantiate()
	fish.name = "Racer%d" % racers.size()
	host.add_child(fish)
	Match1v1.copy_tuning(main.get_node("Fish"), fish)
	(entry["build"] as Callable).call(fish)
	fish.modifiers.push(MODS_SHARED, settings.shared_modifiers(fish.stroke_max_speed))
	fish.modifiers.push(MODS_HANDLING, RaceHandling.modifiers(r.row))
	fish.global_transform = slot["xform"]
	fish.linear_velocity = Vector3.ZERO
	r.fish = fish
	if settings.skills:
		r.skill = Traversal.new(null, fish, host)
	var bot := RaceBot.new()
	bot.fish = fish
	bot.track = track
	bot.tier = tier
	bot.ideal = ideal
	bot.handling = r.row
	bot.skill = r.skill
	bot.name = "%sBot" % fish.name
	bot.go = false
	bot.progress_of = progress_of
	host.add_child(bot)
	r.bot = bot
	racers.append(r)
	for other in racers:
		other.bot.rivals = fish_list()
	return r


func fish_list() -> Array[FishController]:
	var out: Array[FishController] = []
	for r in racers:
		out.append(r.fish)
	return out


## Total progress (m) of a fish (its bot's own tracking).
func progress_of(fish: FishController) -> float:
	for r in racers:
		if r.fish == fish:
			return r.bot.lap_progress
	return 0.0


## Per physics tick: skill updates, laps, rescues. Returns true once every racer has finished `laps`.
func tick(delta: float, time: float, laps: int) -> bool:
	var all_done := true
	for r in racers:
		if r.skill != null:
			r.skill.update(delta)
			r.fish.speed_scale = r.skill.speed_factor()
		if r.finished_at >= 0.0:
			continue
		all_done = false
		var p := r.bot.lap_progress
		var lap_now := int(floorf(p / track.lap_length))
		if lap_now > r.laps_done and lap_now >= 1:
			r.lap_times.append(time - r.lap_start)
			r.lap_start = time
			r.laps_done = lap_now
			if r.laps_done >= laps:
				r.finished_at = time
		_rescue(r, delta)
	return all_done


## RaceMatch's rules in miniature, for the rescue count: outside the channel or nearly still for too long.
func _rescue(r: Racer, delta: float) -> void:
	var fix := track.nearest(r.fish.global_position, r.bot.d_now, 20.0)
	r.oob = r.oob + delta if not fix.inside(1.15) else 0.0
	r.still = r.still + delta if r.fish.swim_velocity().length() < settings.stuck_speed else 0.0
	if (r.oob > settings.race_oob_time and settings.race_oob_time > 0.0) or (r.still > settings.stuck_time and settings.stuck_time > 0.0):
		r.rescues += 1
		r.oob = 0.0
		r.still = 0.0
		var cp := track.checkpoints[track.checkpoint_before(r.bot.d_now)]
		var basis := Basis(cp["right"], cp["up"], -(cp["forward"] as Vector3))
		r.fish.global_transform = Transform3D(basis, cp["pos"])
		r.fish.linear_velocity = (cp["forward"] as Vector3) * 8.0
		r.bot.reset(float(cp["d"]))


## Spread of a list of floats: [mean, min, max, (max - min) / mean].
static func spread(values: Array) -> Array:
	if values.is_empty():
		return [0.0, 0.0, 0.0, 0.0]
	var lo: float = values[0]
	var hi: float = values[0]
	var sum := 0.0
	for v: float in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	var mean := sum / values.size()
	return [mean, lo, hi, (hi - lo) / maxf(mean, 0.0001)]
