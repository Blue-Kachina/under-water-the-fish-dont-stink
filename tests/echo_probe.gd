extends Node
## What Stinks? Phase 3 (what_stinks.md section 4): the Hunter's picture of a
## prey player. Plays the real mode through Main. Part one (the local player is
## prey, a bot hunts) drives WhatStinksEcho by hand, step by step (its own
## physics tick is off): the cone (angle, range, scaled by the Hunter's size),
## the build rate by speed (smear_floor / smear_speed), decay outside the cone,
## echo shadows, a school member's blend_echo_mult, the time to the skeleton and
## to the skin layer for a still loner, a middle-speed one and a school member
## (the spec's ~5 s and ~10x slower: printed, not tuned), noise (NoiseMeter, a
## joined player silent, a loud Leave heard), exposure = max(noise, echo), Click
## (cone, gain, school member, cooldown, auto), Sniff (narrow cone, x2, slower
## swimming, restored), the prey's rings, a new round clearing it all. Part two
## (the local player hunts) checks the reveal layers on a loner and on a school
## slot (the joined player's model drawn only as the reveal, in the Hunter's
## view only), hunter_blind, and that eaten prey lose their look.
##   Godot_console.exe --headless --path . res://tests/echo_probe.tscn

const DT := 1.0 / 120.0

var main: Node
var game: WhatStinksMatch
var fish: FishController
var hunter: FishController
var echo: WhatStinksEcho
var failures := 0
var checks := 0
var camera := Camera3D.new()


func _ready() -> void:
	add_child(camera)
	camera.global_position = Vector3(0, 900, 0)
	camera.make_current()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(done: Callable, seconds: float) -> bool:
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _configure(start_as: int) -> void:
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 1.0
	settings.round_time = 900.0
	settings.round_over_time = 0.5
	settings.match_over_time = 900.0
	settings.arena_radius = 150.0
	settings.school_count = 6
	settings.school_min = 30
	settings.school_max = 40
	settings.min_players = 3
	settings.bot_hunter_rounds = 1
	settings.start_as = start_as
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.bots_join = false
	settings.join_any_class = true
	settings.join_radius = 6.0
	settings.join_ease = 0.2
	settings.shadow_count = 3
	settings.click_auto = false
	settings.hunter_blind = true
	HunterSize.shared().size_mult = 1.0
	WhatStinksSettings.shared().leave_noise = 0.7


func _start(start_as: int) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _frames(5)
	_configure(start_as)
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	echo = game.echo
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 4.0)


func _stop() -> void:
	main.queue_free()
	await _frames(5)


func _run() -> void:
	await _start(WhatStinksSettings.StartAs.PREY)
	await _part_one()
	await _stop()
	await _start(WhatStinksSettings.StartAs.HUNTER)
	await _part_two()
	await _stop()
	print("echo_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Holds the Hunter still at the origin looking down -Z, the player's fish (prey) frozen `gap` m ahead.
func _stage(gap: float, speed := 0.0) -> void:
	hunter.global_transform = Transform3D(Basis.IDENTITY, Vector3(1000, 0, 1000))
	hunter.freeze = true
	hunter.linear_velocity = Vector3.ZERO
	hunter.controls_locked = false
	fish.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	fish.freeze = true
	fish.global_transform = Transform3D(Basis.IDENTITY, hunter.global_position + Vector3(0, 0, -gap))
	fish.linear_velocity = Vector3(0, 0, -speed)
	echo.set_echo(fish, 0.0)
	echo.meter_of(fish).reset()


func _step(seconds: float) -> void:
	for i in int(seconds / DT):
		echo._physics_process(DT)


## Seconds of stepping until the Hunter's echo of `fish` reaches `level` (-1 if it never does within `limit`).
func _time_to(level: float, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if echo.echo_of(hunter, fish) >= level:
			return t
		echo._physics_process(DT)
		t += DT
	return -1.0


func _part_one() -> void:
	print("the round:")
	check(echo != null and game.shadows != null and game.looks != null, "the match has an echo, shadows and looks")
	hunter = game.hunters[0]
	check(game.bots.has(hunter), "a bot hunts, the local fish is prey")
	var bot: Variant = game.bots[hunter]
	if bot != null and is_instance_valid(bot):
		(bot as Node).queue_free()
	echo.set_physics_process(false)
	var settings := WhatStinksSettings.shared()
	var noise := MarcoPoloSettings.shared()
	check(game.shadows.count() == 3, "shadows placed (%d)" % game.shadows.count())
	check(echo.meter_of(fish) != null and echo.meter_of(hunter) == null, "prey have noise meters, the Hunter none")
	var seeded := echo.cone_range(hunter) == settings.echo_range and absf(echo.cone_half_angle(hunter) - deg_to_rad(settings.echo_cone_deg)) < 0.0001
	check(seeded, "the cone is the settings' (range %.0f m, half angle %.0f deg)" % [echo.cone_range(hunter), rad_to_deg(echo.cone_half_angle(hunter))])

	print("the cone:")
	_stage(5.0)
	check(echo.in_cone(hunter, fish.global_position), "a fish dead ahead at 5 m is in the cone")
	check(not echo.in_cone(hunter, hunter.global_position + Vector3(0, 0, 5.0)), "one behind is not")
	var edge := deg_to_rad(settings.echo_cone_deg)
	check(echo.in_cone(hunter, hunter.global_position + Vector3(sin(edge * 0.9), 0, -cos(edge * 0.9)) * 20.0), "just inside the angle is in")
	check(not echo.in_cone(hunter, hunter.global_position + Vector3(sin(edge * 1.2), 0, -cos(edge * 1.2)) * 20.0), "just outside it is out")
	check(echo.in_cone(hunter, hunter.global_position + Vector3(0, 0, -settings.echo_range * 0.98)) and not echo.in_cone(hunter, hunter.global_position + Vector3(0, 0, -settings.echo_range * 1.05)), "the range ends the cone")
	HunterSize.shared().size_mult = 4.0
	check(absf(echo.cone_range(hunter) - settings.echo_range * 2.0) < 0.01, "a size 4 Hunter's cone reaches x2 (%.0f m)" % echo.cone_range(hunter))
	HunterSize.shared().size_mult = 1.0
	check(absf(echo.range_falloff(hunter, settings.echo_near * 0.5) - 1.0) < 0.001 and echo.range_falloff(hunter, settings.echo_range) < 0.001, "the build is full near and nothing at the range")
	var half := (settings.echo_near + settings.echo_range) * 0.5
	check(absf(echo.range_falloff(hunter, half) - 0.5) < 0.01, "and half way between")

	print("the build, by speed:")
	var rate_still := echo.build_rate(hunter, fish)
	check(absf(rate_still - settings.echo_build) < 0.0001, "a still loner builds at echo_build (%.3f/s)" % rate_still)
	_stage(5.0, settings.smear_speed * 0.5)
	var rate_mid := echo.build_rate(hunter, fish)
	_stage(5.0, settings.smear_speed)
	var rate_fast := echo.build_rate(hunter, fish)
	_stage(5.0, settings.smear_speed * 3.0)
	var rate_faster := echo.build_rate(hunter, fish)
	check(absf(fish.swim_velocity().length() - settings.smear_speed * 3.0) < 0.01, "the staged speed holds (%.1f m/s)" % fish.swim_velocity().length())
	check(rate_mid < rate_still and rate_mid > rate_fast, "a middle speed builds slower (%.3f), a fast one slower still (%.3f)" % [rate_mid, rate_fast])
	check(absf(rate_fast / rate_still - settings.smear_floor) < 0.001 and absf(rate_faster - rate_fast) < 0.0001, "at smear_speed and past it the build is smear_floor of full (%.2f)" % (rate_fast / rate_still))

	print("time to seen (printed against the spec: still ~5 s, in a school ~10x slower):")
	_stage(5.0)
	var t_skeleton := _time_to(noise.layer_skeleton, 60.0)
	_stage(5.0)
	var t_skin := _time_to(noise.layer_skin, 60.0)
	_stage(5.0)
	var t_full := _time_to(1.0, 60.0)
	print("    still loner at 5 m: skeleton %.2f s, skin %.2f s, full %.2f s" % [t_skeleton, t_skin, t_full])
	check(absf(t_skin - 5.0) < 0.3, "a still loner at point-blank is at the skin layer in ~5 s (%.2f)" % t_skin)
	_stage(5.0, settings.smear_speed * 0.5)
	var t_mid := _time_to(noise.layer_skin, 120.0)
	print("    middle speed (%.0f m/s): skin %.2f s" % [settings.smear_speed * 0.5, t_mid])
	check(absf(t_mid - 15.0) < 2.0, "a middle speed takes ~15 s (%.2f)" % t_mid)
	_stage(5.0, settings.smear_speed * 3.0)
	var t_fast := _time_to(noise.layer_skin, 600.0)
	print("    fast (%.0f m/s): skin %.1f s (echo alone; noise handles a fast fish)" % [settings.smear_speed * 3.0, t_fast])
	check(t_fast > t_skin * 3.0, "a fast one builds far slower (%.1f s)" % t_fast)
	_stage(35.0)
	var t_far := _time_to(noise.layer_skin, 600.0)
	print("    still loner at 35 m: skin %.1f s" % t_far)
	check(t_far > t_skin * 1.5, "further out is slower (%.1f s)" % t_far)

	print("decay:")
	_stage(5.0)
	echo.set_echo(fish, 0.5)
	fish.global_position = hunter.global_position + Vector3(0, 0, 5.0)  # behind
	_step(2.0)
	check(absf(echo.echo_of(hunter, fish) - (0.5 - settings.echo_decay * 2.0)) < 0.01, "out of the cone it fades at echo_decay (%.3f after 2 s)" % echo.echo_of(hunter, fish))
	_step(20.0)
	check(echo.echo_of(hunter, fish) == 0.0, "and bottoms at 0")
	_stage(5.0)
	echo.set_echo(fish, 0.5)
	_step(1.0)
	check(echo.echo_of(hunter, fish) > 0.5, "in the cone it rises instead")

	print("echo shadows:")
	_stage(5.0)
	game.shadows.add_spot(fish.global_position, 6.0, "kelp", 5)
	check(echo.in_shadow(fish.global_position) and not echo.in_shadow(fish.global_position + Vector3(0, 0, 40)), "a prey inside a shadow's sphere is in shadow, outside is not")
	check(absf(echo.build_rate(hunter, fish) - settings.echo_build * settings.shadow_mult) < 0.0001, "the build is x shadow_mult there (%.3f/s)" % echo.build_rate(hunter, fish))
	_step(10.0)
	check(echo.echo_of(hunter, fish) == 0.0, "and with the decay on top a loner in a shadow stays unseen (%.3f after 10 s)" % echo.echo_of(hunter, fish))
	var shadow_seed := game.shadows.count()
	game.shadows.build(game.center, 77)
	var again := game.shadows.spots.duplicate(true)
	game.shadows.build(game.center, 77)
	check(shadow_seed >= 1 and again == game.shadows.spots and game.shadows.count() == settings.shadow_count, "the same seed places the same shadows (%d)" % game.shadows.count())
	check(get_tree().get_nodes_in_group("ws_echo_shadow").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size() == settings.shadow_count, "and they are in the node group")

	print("in a school:")
	var school: School = game.field.schools[0]
	await _frames(2)
	fish.freeze = false
	var place := school.nearest_free(fish.global_position)
	fish.global_position = school.fish_position(place) + Vector3(1.0, 0.0, 0.0)
	fish.controls_locked = false
	var joined := game.join.join(fish, school)
	check(joined and game.join.is_joined(fish), "the player joins a school")
	check(echo.meter_of(fish).muted, "its noise meter is muted")
	# Hold the Hunter 6 m in front of the claimed fish, facing it.
	var face_at := func() -> void:
		var at := fish.global_position
		hunter.global_transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0, 6.0))
	face_at.call()
	var school_rate := echo.build_rate(hunter, fish)
	check(absf(school_rate - settings.echo_build * settings.blend_echo_mult) < 0.0001, "a school member builds at blend_echo_mult (%.4f/s)" % school_rate)
	echo.set_echo(fish, 0.0)
	var t_school := 0.0
	var school_skeleton := -1.0
	while t_school < 120.0 and echo.echo_of(hunter, fish) < noise.layer_skin:
		face_at.call()
		echo._physics_process(DT)
		t_school += DT
		if school_skeleton < 0.0 and echo.echo_of(hunter, fish) >= noise.layer_skeleton:
			school_skeleton = t_school
	print("    school member at 6 m: skeleton %.1f s, skin %.1f s" % [school_skeleton, t_school])
	check(absf(t_school / t_skin - 10.0) < 1.0, "about 10x slower than the loner (%.1fx)" % (t_school / t_skin))
	check(school_skeleton > 0.0 and school_skeleton < t_school * 0.25, "its faint skeleton shows first (at %.1f s of %.1f)" % [school_skeleton, t_school])
	check(echo.noise_of(fish) < 0.01, "the school's own speed (%.1f m/s) makes it no noise" % fish.swim_velocity().length())

	print("noise and exposure:")
	var spooked := fish
	game.join.leave(fish)
	check(not echo.meter_of(fish).muted and echo.noise_of(fish) >= settings.leave_noise - 0.01, "a loud Leave is heard (noise %.2f)" % echo.noise_of(fish))
	check(echo.echo_of(hunter, fish) == 0.0, "and starts the echo over")
	_stage(5.0)
	echo.meter_of(fish).noise = 0.8
	var n_near := echo.noise_exposure(hunter, fish)
	check(absf(n_near - 0.8) < 0.001, "loud noise near the Hunter is seen as it is (%.2f)" % n_near)
	check(absf(echo.exposure(hunter, fish) - 0.8) < 0.001, "exposure is max(noise, echo): noise leads (%.2f)" % echo.exposure(hunter, fish))
	echo.set_echo(fish, 0.9)
	check(absf(echo.exposure(hunter, fish) - 0.9) < 0.001, "echo leads when it is the bigger (%.2f)" % echo.exposure(hunter, fish))
	_stage(5.0)
	fish.global_position = hunter.global_position + Vector3(0, 0, -(settings.noise_sight * 0.6))
	echo.meter_of(fish).noise = 0.8
	var n_mid := echo.noise_exposure(hunter, fish)
	fish.global_position = hunter.global_position + Vector3(0, 0, -(settings.noise_sight * 1.1))
	check(n_mid < 0.8 and n_mid > 0.1 and echo.noise_exposure(hunter, fish) == 0.0, "noise fades with distance (%.2f at 60%%, 0 past the range)" % n_mid)
	echo.forced[fish] = 0.33
	check(absf(echo.exposure(hunter, fish) - 0.33) < 0.0001 and absf(echo.max_exposure(fish) - 0.33) < 0.0001, "a forced exposure overrides (probes, shots)")
	echo.forced.erase(fish)
	game.join.reset_echo(fish)
	check(echo.echo_max(fish) == 0.0, "a school's echo reset zeroes the echo")
	_stage(5.0)
	echo.meter_of(fish).noise = 0.0
	spooked = null

	print("Click:")
	_stage(5.0)
	var other := game.live_prey().filter(func(p: FishController) -> bool: return p != fish)
	var behind: FishController = other[0] if not other.is_empty() else null
	if behind != null:
		behind.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		behind.freeze = true
		behind.global_position = hunter.global_position + Vector3(0, 0, 8.0)  # outside the cone
		echo.set_echo(behind, 0.0)
	echo.click_left[hunter] = 0.0
	var reached := echo.click(hunter)
	check(reached >= 1 and absf(echo.echo_of(hunter, fish) - settings.click_gain) < 0.0001, "a Click gives the prey in the cone click_gain (%.2f)" % echo.echo_of(hunter, fish))
	check(behind == null or echo.echo_of(hunter, behind) == 0.0, "but not one outside it")
	check(echo.click(hunter) == -1 and echo.click_ready_in(hunter) > 0.0, "it is on a cooldown (%.1f s)" % echo.click_ready_in(hunter))
	var bumped := echo.echo_of(hunter, fish)
	_stage(5.0)
	var school2: School = game.field.schools[1]
	var place2 := school2.nearest_free(fish.global_position)
	fish.freeze = false
	fish.global_position = school2.fish_position(place2) + Vector3(1.0, 0.0, 0.0)
	game.join.cooldown.erase(fish)
	check(game.join.join(fish, school2) and game.join.is_joined(fish), "joins a second school")
	hunter.global_transform = Transform3D(Basis.IDENTITY, fish.global_position + Vector3(0, 0, 6.0))
	echo.set_echo(fish, 0.0)
	echo.click(hunter, true)
	check(absf(echo.echo_of(hunter, fish) - settings.click_gain * settings.blend_echo_mult) < 0.0001, "a school member only gets click_gain x blend_echo_mult (%.3f)" % echo.echo_of(hunter, fish))
	game.join.leave(fish, false)
	_stage(5.0)
	game.shadows.build(game.center, 5)
	game.shadows.add_spot(fish.global_position, 6.0, "arch", 5)
	echo.click(hunter, true)
	check(absf(echo.echo_of(hunter, fish) - settings.click_gain * settings.shadow_mult) < 0.0001, "a Click into a shadow is x shadow_mult (%.3f)" % echo.echo_of(hunter, fish))
	game.shadows.build(game.center, 5)
	settings.click_auto = true
	echo.click_left[hunter] = 0.3
	var before := int(echo.clicks.get(hunter, 0))
	_step(0.5)
	check(int(echo.clicks.get(hunter, 0)) == before + 1, "with click_auto it Clicks by itself when ready")
	_step(settings.click_cooldown - 0.6)
	check(int(echo.clicks.get(hunter, 0)) == before + 1, "and not before the cooldown is up")
	_step(0.5)
	check(int(echo.clicks.get(hunter, 0)) == before + 2, "then again")
	settings.click_auto = false
	check(bumped > 0.0, "(the first Click's bump was kept: %.2f)" % bumped)

	print("Sniff:")
	_stage(5.0)
	var wide := echo.cone_half_angle(hunter)
	var base_speed := [hunter.speed_scale, hunter.top_speed_scale, hunter.boost_scale]
	var rate_before := echo.build_rate(hunter, fish)
	hunter.powerslide_held = true
	_step(0.1)
	check(echo.is_sniffing(hunter), "holding the sniff button sniffs")
	check(absf(echo.cone_half_angle(hunter) - wide * settings.sniff_cone_mult) < 0.0001, "the cone narrows (%.0f deg)" % rad_to_deg(echo.cone_half_angle(hunter)))
	check(absf(echo.build_rate(hunter, fish) - rate_before * settings.sniff_mult) < 0.0001, "the build is x sniff_mult (%.3f/s)" % echo.build_rate(hunter, fish))
	check(absf(hunter.speed_scale - base_speed[0] * settings.sniff_speed) < 0.0001 and absf(hunter.top_speed_scale - base_speed[1] * settings.sniff_speed) < 0.0001, "the Hunter swims at sniff_speed of its speed (x%.2f)" % (hunter.speed_scale / base_speed[0]))
	var side := hunter.global_position + Vector3(sin(wide * 0.7), 0, -cos(wide * 0.7)) * 10.0
	check(not echo.in_cone(hunter, side), "a fish at 70%% of the old angle falls out of the narrow cone")
	_step(0.1)
	check(absf(hunter.speed_scale - base_speed[0] * settings.sniff_speed) < 0.0001, "holding on does not stack the slowdown")
	hunter.powerslide_held = false
	_step(0.1)
	check(not echo.is_sniffing(hunter) and absf(hunter.speed_scale - base_speed[0]) < 0.0001 and absf(hunter.top_speed_scale - base_speed[1]) < 0.0001 and absf(hunter.boost_scale - base_speed[2]) < 0.0001, "letting go restores the speed and the cone")
	hunter.powerslide_held = true
	_step(0.1)
	echo.begin_round(game.players)
	check(not echo.is_sniffing(hunter) and absf(hunter.speed_scale - base_speed[0]) < 0.0001, "a new round while sniffing hands the speed back")
	hunter.powerslide_held = false

	print("the prey's rings and a new round:")
	var hud: Node = game.get("_hud")
	check(hud != null, "the HUD exists")
	_stage(5.0)
	echo.set_echo(fish, 0.6)
	echo.meter_of(fish).noise = 0.4
	check(absf(echo.echo_max(fish) - 0.6) < 0.001 and absf(echo.noise_of(fish) - 0.4) < 0.001, "the rings read echo %.2f and noise %.2f" % [echo.echo_max(fish), echo.noise_of(fish)])
	await _frames(3)  # the HUD draws with the prey panel (map and rings)
	check(is_instance_valid(hud), "the prey panel draws without trouble")
	game.start_round(1)
	await _frames(3)
	check(echo.echo_max(fish) == 0.0 and echo.noise_of(fish) == 0.0, "a new round starts clear")
	check(echo.meters.size() == game.players.size() - game.hunters.size(), "with a meter for every prey")
	var eaten_one: FishController = game.live_prey()[0]
	game._eat(eaten_one, game.hunters[0])
	check(echo.exposure(game.hunters[0], eaten_one) == 0.0, "an eaten prey is not seen")


func _part_two() -> void:
	print("the Hunter's view:")
	check(game.local_view_role() == WhatStinksMatch.Role.HUNTER and game.hunters.has(fish), "the local player hunts")
	hunter = fish
	await _settle()
	var prey := game.live_prey()
	var loner: FishController = prey[0]
	var member: FishController = prey[1]
	for p in prey:
		if p.get_parent() != null:
			p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			p.freeze = true
	echo.set_physics_process(false)
	await _settle()
	var looks := game.looks
	check(looks.seeker_view, "the looks are on the Hunter's view")
	check(looks.concealed(loner) and looks.concealed(member), "every live prey is drawn as a reveal")
	echo.forced[loner] = 0.0
	await _settle()
	var reveal := looks.reveal_of(loner)
	check(reveal != null and reveal.exposure == 0.0, "an unseen prey has exposure 0")
	var noise := MarcoPoloSettings.shared()
	# Layers by exposure, the loner's exposure forced.
	var seen := {}
	for level in [0.04, 0.16, 0.35, 0.55, 0.75, 0.92]:
		echo.forced[loner] = level
		await _settle()
		seen[level] = Vector4(reveal.layers)
	check(reveal.exposure > 0.9, "the reveal takes the exposure (%.2f)" % reveal.exposure)
	echo.forced[loner] = 0.04
	await _settle()
	for node: Node in loner._visual.find_children("*", "GeometryInstance3D", true, false):
		if not node.has_meta("marco_reveal") and (node as GeometryInstance3D).layers != 0:
			print("   still drawn: ", loner._visual.get_path_to(node), " ", node.get_class(), " ", node.visible)
	check(seen[0.04] == Vector4.ZERO and not _real_shown(loner, true), "below the skeleton band nothing shows (the real model is off)")
	check((seen[0.16] as Vector4).x > 0.0 and (seen[0.16] as Vector4).y == 0.0, "the skeleton band shows bones (%.2f)" % (seen[0.16] as Vector4).x)
	check((seen[0.35] as Vector4).y > 0.0, "then the heart")
	check((seen[0.55] as Vector4).z > 0.0, "then the muscle")
	check((seen[0.75] as Vector4).w > 0.0, "then the skin")
	echo.forced[loner] = 1.0
	await _settle()
	check(_real_shown(loner, true), "fully seen the real model is back")
	echo.forced.erase(loner)
	# Echo, not forced, drives it too.
	echo.set_echo(loner, 0.2)
	await _settle()
	check(reveal.exposure >= 0.19 and reveal.layers.x > 0.0, "a built echo shows the skeleton (%.2f)" % reveal.exposure)
	echo.set_echo(loner, 0.0)
	await _settle()
	# A school slot.
	var school: School = game.field.schools[0]
	member.freeze = false
	member.global_position = school.fish_position(school.nearest_free(member.global_position)) + Vector3(1, 0, 0)
	var joined := game.join.join(member, school)
	check(joined and game.join.is_joined(member), "a prey joins a school")
	await _settle()
	var member_reveal := looks.reveal_of(member)
	check(member_reveal != null, "its slot is still drawn as a reveal in the Hunter's view")
	check(member._visual.visible, "and its model is on in the Hunter's view (under the reveal, not by itself)")
	check(not _real_shown(member, false), "but the real model draws nothing at exposure 0")
	echo.set_echo(member, 0.14)
	await _settle()
	check(member_reveal.layers.x > 0.0 and member_reveal.layers.x < 1.0, "a faint skeleton shows on the claimed slot (%.2f)" % member_reveal.layers.x)
	check(game.join.school_of(member).claim_of(member) >= 0, "the slot is the school's own place")
	echo.set_echo(member, 0.0)
	# hunter_blind off.
	WhatStinksSettings.shared().hunter_blind = false
	await _settle()
	check(not looks.concealed(loner) and not looks.concealed(member), "hunter_blind off: everyone is drawn as ever")
	WhatStinksSettings.shared().hunter_blind = true
	await _settle()
	check(looks.concealed(loner), "and on again")
	# Eaten prey lose their look.
	game._eat(loner, hunter)
	await _settle()
	check(not looks.concealed(loner), "an eaten prey is not drawn as a reveal")
	# A prey's view of itself and others (a new round with the local fish as prey).
	game.settings.start_as = WhatStinksSettings.StartAs.PREY
	game.start_match()
	await _frames(4)
	check(game.local_view_role() == WhatStinksMatch.Role.PREY and not looks.seeker_view, "as prey the looks are off")
	check(not looks.concealed(member), "prey are drawn as they are")
	check(game.join != null and not game.join.is_joined(member), "(a new round let everyone go)")


## Whether `who`'s real model parts are drawn (their layers mask is on) by the first one found; `any`: any part.
func _real_shown(who: FishController, any: bool) -> bool:
	var shown := 0
	var total := 0
	for node: Node in who._visual.find_children("*", "GeometryInstance3D", true, false):
		if node.has_meta("marco_reveal"):
			continue
		total += 1
		if (node as GeometryInstance3D).layers != 0:
			shown += 1
	return shown > 0 if any else shown == total


## Process frames, where the looks update.
func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
