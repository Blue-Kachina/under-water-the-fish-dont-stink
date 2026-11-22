extends RefCounted
## What the race probes share (not a probe itself): starting a Grey Box race on main, a throttle-only driver that
## follows the racing line (no strides: slow but dependable, and independent of RaceBot), and a few helpers.

const MODE := "race"


## main with the race mode started on the Grey Box: returns the RaceMatch. Settings are for a short race.
static func start(probe: Node, main: Node, laps := 1, field := 3) -> RaceMatch:
	RaceBest.persist = false
	RaceMatch.forced_pick = str(RaceRoster.entries()[0]["key"])  # the same racer for the human on every machine
	var rs := RaceSettings.shared()
	rs.track = "Grey Box"
	rs.laps = laps
	rs.field_size = field
	rs.countdown = 1.0
	rs.finish_clock = 4.0
	main.set_mode(MODE)
	for i in 3:
		await probe.get_tree().physics_frame
	main.play_match()
	for i in 5:
		await probe.get_tree().physics_frame
	var race := main.active_mode() as RaceMatch
	if race == null:
		return null
	for r in race.racers:  # the probe drives: no bot node (RaceBot) fights it
		if r.bot != null and is_instance_valid(r.bot):
			r.bot.queue_free()
			r.bot = null
		if r.fish.controls == null:
			r.fish.controls = FishInput.new()
	return race


## One driving step for `r`: throttle `throttle`, steering at a point on the racing line ahead.
static func drive(race: RaceMatch, r: RaceMatch.Racer, throttle := 1.0, reverse_gear := false) -> void:
	var fish := r.fish
	var input := fish.controls as FishInput
	if input == null or r.fix == null:
		return
	var look := maxf(10.0, fish.speed * 0.9)
	var target := race.track.racing_line(r.d + look)
	var local := fish.global_basis.inverse() * (target - fish.global_position)
	var yaw := atan2(local.x, -local.z)
	input.forward = throttle
	input.stick = Vector2(clampf(yaw * 1.6, -1.0, 1.0), clampf(local.y / maxf(local.length(), 1.0) * 3.0, -1.0, 1.0))
	if reverse_gear:
		input.forward = 0.0


## Puts `r` on the track at distance `d`, facing along it (or against), and tells the match.
static func place(race: RaceMatch, r: RaceMatch.Racer, d: float, backwards := false, lateral := 0.0) -> void:
	var fix := race.track.sample(d)
	var forward := -fix.forward if backwards else fix.forward
	var at := fix.pos + fix.right * lateral
	r.fish.revive(Transform3D(Basis.looking_at(forward, fix.up), at))
	r.d = fix.d
	r.prev_side = NAN
	r.fix = race.track.nearest(at, r.d)


static func frames(probe: Node, count: int) -> void:
	for i in count:
		await probe.get_tree().physics_frame
