## Replay loading: the converter's fixture (tools/rl_replay/make_fixture.py)
## loads, lands where Rocket League puts things, and samples sensibly between
## frames and across teleports. With a converted real replay as well, checks
## it against RL's known facts (ball spin cap, kickoff spots and facings).
## Run headless: Godot_console.exe --headless --path . res://tests/replay_data_probe.tscn [-- REAL.rlreplay.json]
extends Node

const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"

var failures := 0


func _ready() -> void:
	_check_fixture()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_check_real(args[0])
	print("replay_data_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _check_fixture() -> void:
	print("fixture:")
	var rl := ReplayData.new()  # RL's own orientation
	var problem := rl.load_file(FIXTURE, false)
	check(problem == "", "loads (%s)" % (problem if problem else "ok"))
	if problem:
		return
	check(rl.times.size() == 360 and rl.players.size() == 2, "360 frames, 2 players")
	check(rl.players[0].hitbox_size.is_equal_approx(Vector3(0.866994, 0.386591, 1.20507)), "Octane hitbox in metres: %s" % rl.players[0].hitbox_size)
	check(rl.players[1].hitbox_offset.is_equal_approx(Vector3(0.0, 0.1575, -0.09)), "Dominus hitbox offset (forward is -Z): %s" % rl.players[1].hitbox_offset)

	var s := ReplayData.Sample.new()
	# RLSpace sanity (plan §5.1): Blue's car at (0, -4608, 17), yaw 1/2 pi, is at
	# (0, 0.17, -46.08) with its nose along +Z.
	rl.sample_car(0, rl.times[90], s)
	check(s.position.is_equal_approx(Vector3(0.0, 0.17, -46.08)), "Blue kickoff spot in Godot: %s" % s.position)
	check((Basis(s.rotation) * Vector3.FORWARD).is_equal_approx(Vector3.BACK), "Blue's nose faces +Z (toward Orange)")
	rl.sample_ball(rl.times[90], s)
	check(is_equal_approx(s.position.y, 0.9275), "kickoff ball rests at 0.9275 m: %.4f" % s.position.y)

	var data := ReplayData.new()  # turned for the Aquarium: Blue defends +Z
	data.load_file(FIXTURE)
	data.sample_car(0, data.times[90], s)
	check(s.position.is_equal_approx(Vector3(0.0, 0.17, 46.08)), "turned: Blue starts at the Aquarium's Blue end: %s" % s.position)
	check((Basis(s.rotation) * Vector3.FORWARD).is_equal_approx(Vector3.FORWARD), "turned: Blue faces -Z, like the live fish's spawn")
	var hitbox_centre: Vector3 = s.position + Basis(s.rotation) * data.players[0].hitbox_offset
	check(is_equal_approx(hitbox_centre.y, 0.17 + 0.20755) and is_equal_approx(hitbox_centre.z, 46.08 - 0.138757),
			"hitbox centre 0.21 m above and 0.14 m ahead of the centre of mass: %s" % hitbox_centre)

	# Rolling ball: speed 18 m/s toward Orange (-Z once turned), spin 6 rad/s.
	data.sample_ball(data.times[200], s)
	check(s.velocity.is_equal_approx(Vector3(0, 0, -18)), "ball velocity converted: %s" % s.velocity)
	check(is_equal_approx(s.angular_velocity.length(), 6.0), "ball spin in rad/s: %.3f" % s.angular_velocity.length())

	# Halfway between two frames: on the curve between them.
	var t0 := data.times[100]
	var t1 := data.times[101]
	var a := data.sample_car(0, t0, ReplayData.Sample.new()).position
	var b := data.sample_car(0, t1, ReplayData.Sample.new()).position
	var mid := data.sample_car(0, (t0 + t1) / 2.0, s).position
	check(mid.is_equal_approx((a + b) / 2.0), "blends between frames: %s" % mid)

	# Demolished: absent, then back at the respawn spot with no blend into it.
	check(not data.sample_car(1, data.times[190], s).present, "demolished car is absent")
	data.sample_car(1, data.times[200] + 0.01, s)
	check(not s.present, "still absent just before its respawn frame")
	data.sample_car(1, data.times[201] + 0.01, s)
	check(s.present and s.position.is_equal_approx(Vector3(-23.04, 0.36, -46.08)), "respawned at (2304, 4608, 36) uu, turned: %s" % s.position)
	check(data.sample_car(1, data.times[195], s).flags == 0 and data.cars[1].flags[180] & ReplayData.FLAG_DEMOLISHED != 0, "demolished flag on the demo frame")

	# The second kickoff teleports: just before it, hold the old spot.
	var before := data.sample_car(0, data.times[299], ReplayData.Sample.new()).position
	var held := data.sample_car(0, data.times[299] + 0.02, s).position
	check(held == before, "holds across the kickoff teleport (no blend)")

	check(data.score_at(data.times[236]) == [0, 0] and data.score_at(data.times[237]) == [1, 0], "score counts the goal from its frame")
	check(is_equal_approx(data.next_event_time("goal", 0.0), data.times[237]), "next goal found")
	check(data.state_at(1.0) == ReplayData.GAME_COUNTDOWN and data.state_at(5.0) == ReplayData.GAME_LIVE
			and data.state_at(9.0) == ReplayData.GAME_POST_GOAL, "game states")
	check(data.frame_at(-1.0) == 0 and data.frame_at(1e9) == 359, "frame_at clamps")

	var broken := ReplayData.new()
	check(broken.load_document({"format": "something else"}) != "", "rejects other files")
	check(broken.load_document({"format": ReplayData.FORMAT, "version": 99}) != "", "rejects other versions")


## A real replay: RL's facts must hold. Every kickoff has its cars on RL's
## kickoff spots, Blue at the Aquarium's +Z end, each facing the ball.
func _check_real(path: String) -> void:
	print("real replay %s:" % path.get_file())
	var data := ReplayData.new()
	var started := Time.get_ticks_msec()
	var problem := data.load_file(path)
	check(problem == "", "loads in %d ms (%s)" % [Time.get_ticks_msec() - started, problem if problem else "ok"])
	if problem:
		return
	var s := ReplayData.Sample.new()
	var top_spin := 0.0
	for i in data.times.size():
		if data.ball.present[i]:
			top_spin = maxf(top_spin, data.ball.ang_vel[i].length())
	check(top_spin > 5.5 and top_spin < 6.2, "ball spin tops out at RL's 6 rad/s: %.3f" % top_spin)
	# A ball rolling on the floor has its contact point still: v + w x (-r up) = 0.
	# A wrong sign on the angular velocity would make it twice the ball's speed.
	# (RL's ball mostly slides along the floor, so only frames where its spin
	# matches its speed count.)
	var rolling := 0
	var slip := 0.0
	var moving := 0.0
	for i in data.times.size():
		var v := data.ball.vel[i]
		var w := data.ball.ang_vel[i]
		var flat_speed := Vector2(v.x, v.z).length()
		if data.ball.present[i] and data.ball.pos[i].y < 0.96 and absf(v.y) < 0.5 and flat_speed > 3.0 				and absf(w.length() * 0.9275 / flat_speed - 1.0) < 0.1:
			rolling += 1
			slip += (v + w.cross(Vector3(0.0, -0.9275, 0.0))).length()
			moving += flat_speed
	if rolling < 3:
		print("  SKIP  spin sign: the ball never rolls cleanly on the floor in this replay")
	else:
		check(slip / moving < 0.2, "rolling ball's contact point is still (spin sign right): slip %.0f%% of speed over %d frames" % [100.0 * slip / moving, rolling])
	# Smoothness as rendered: sampled 144 times a second, the speed a car shows
	# between two rendered frames should match its own speed. On the frames' own
	# times it doesn't: each sample comes from a physics tick a little off its frame.
	var on_frame_times := _jerkiness(data, true)
	var corrected := _jerkiness(data, false)
	# (What's left over is mostly frames holding a hit, landing, jump or dodge,
	# where the speed really does change within the frame.)
	check(corrected < 0.2 and corrected < on_frame_times / 2.0,
			"smooth: shown speed within %.0f%% of the car's speed (95%% of frames; %.0f%% on the frames' own times)" % [100.0 * corrected, 100.0 * on_frame_times])
	var kickoffs := data.events_of("kickoff")
	check(not kickoffs.is_empty(), "%d kickoffs" % kickoffs.size())
	var wrong := 0
	var cars_checked := 0
	for kickoff in kickoffs:
		var t: float = kickoff.time
		data.sample_ball(t, s)
		if not is_equal_approx(snappedf(s.position.y, 0.01), 0.93) or s.position.length() > 1.0:
			wrong += 1
			print("    kickoff at %.1f s: ball at %s" % [t, s.position])
		for i in data.cars.size():
			data.sample_car(i, t, s)
			if not s.present:
				continue
			cars_checked += 1
			var team: int = data.players[i].team
			var own_end := signf(s.position.z) == (1.0 if team == 0 else -1.0)
			var nose := Basis(s.rotation) * Vector3.FORWARD
			var facing_ball := nose.dot(-Vector3(s.position.x, 0.0, s.position.z).normalized()) > 0.95
			var on_floor := absf(s.position.y - 0.17) < 0.03
			if not (own_end and facing_ball and on_floor):
				wrong += 1
				print("    kickoff at %.1f s: %s (%s) at %s, nose %s" % [t, data.players[i].name, ["Blue", "Orange"][team], s.position, nose])
	check(wrong == 0, "kickoffs: ball at the centre spot, %d cars at their own end, on the floor, facing the ball" % cars_checked)


## The 95th percentile of |shown speed / actual speed - 1| over rendered frames
## at 144 Hz, for every car moving faster than 6 m/s in live play.
## `frame_times`: ignore the converter's per-sample times.
func _jerkiness(data: ReplayData, frame_times: bool) -> float:
	var saved: Array[PackedFloat64Array] = []
	if frame_times:
		for track in data.cars:
			saved.append(track.times)
			track.times = data.times.duplicate()
	var errors := PackedFloat32Array()
	var a := ReplayData.Sample.new()
	var b := ReplayData.Sample.new()
	var step := 1.0 / 144.0
	for i in data.cars.size():
		var t := 0.0
		while t < data.duration - step:
			data.sample_car(i, t, a)
			data.sample_car(i, t + step, b)
			var speed := (a.velocity.length() + b.velocity.length()) / 2.0
			if a.present and b.present and speed > 6.0 and data.state_at(t) == ReplayData.GAME_LIVE 					and a.position.distance_to(b.position) < speed * step * 3.0:
				errors.append(absf(a.position.distance_to(b.position) / step / speed - 1.0))
			t += step * 7.0  # every 7th rendered frame is plenty
	if frame_times:
		for i in data.cars.size():
			data.cars[i].times = saved[i]
	errors.sort()
	return errors[int(errors.size() * 0.95)] if not errors.is_empty() else 0.0
