extends Node
## Marco Polo's arenas and portholes (planning_marco_polo.md phase 5), in both
## the Sunken Temple and the Aquarium:
## - the arena: it's what the match plays in, with 6-10 portholes none near the
##   seeker's start, hider spawns, map outlines, a sight range, collision on the
##   sight-blocker layer; the Aquarium's bubbles mask and fizz;
## - entry: a lined-up slow approach gets in; a fast, an angled, a flipping and
##   an off-centre one knock off the rim (noise + mp/bump), and so does a second
##   fish at a taken porthole;
## - inside: the fish ends up facing out at its seat; steering and pushes do
##   nothing; only jump gets it out (fast, along the axis, loud); the bow can't
##   tag it;
## - hidden: no exposure, no pings on the scope, no line of sight, no score;
## - the gauge: it fills inside and drains at porthole_recovery outside; a full
##   gauge is caught (eliminated in Last Fish Swimming, a seeker in Join the Seekers);
## - Jump entry (porthole_jump_entry, the default; the checks above run with it
##   off): Jump near a free mouth slips in quietly from any angle, too far or
##   behind the wall it's just a jump, seekers never; the HUD's prompt; a bot
##   gets in by jumping too.
##   Godot_console.exe --headless --path . res://tests/porthole_probe.tscn [-- --arena=temple|tank]

const TICKS := 120

var main: Node
var fish: FishController
var failures := 0
var mp: MarcoPoloSettings
var arenas := ["Sunken Temple", "Aquarium"]
var knocks: Array = []
var sounds: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--arena=temple":
			arenas = ["Sunken Temple"]
		elif arg == "--arena=tank":
			arenas = ["Aquarium"]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	mp = MarcoPoloSettings.shared()
	Sfx.requested.connect(func(id: String) -> void: sounds.append(id))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	mp.hide_time = 0.3
	mp.round_time = 120.0
	mp.round_over_time = 0.3
	mp.min_players = 4
	mp.rounds = 4
	mp.bot_seeker_rounds = 11  # every bot a turn (it was a bool)
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	for arena_name: String in arenas:
		await _arena_checks(arena_name)
	_finish()


func _arena_checks(arena_name: String) -> void:
	print("%s:" % arena_name)
	mp.arena = arena_name
	mp.porthole_time = 8.0
	# Nose first, for the entry and knock checks, as it was built: fish sticking
	# to the walls (off, they bounce off the rim and these approaches miss).
	mp.porthole_jump_entry = false
	mp.stick_to_surfaces = true
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	if main.marco_polo:
		main.set_mode(main.FREE_SWIM)
		await _ticks(3)
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null and game.arena is MarcoArena, "the match plays in the %s" % arena_name)
	if game == null or not game.arena is MarcoArena:
		return
	var arena := game.arena as MarcoArena
	var system := game.porthole_system as PortholeSystem
	var holes := arena.portholes()
	check(system != null and system.portholes().size() == holes.size(), "the match runs a PortholeSystem with the arena's %d portholes" % holes.size())
	if system == null:
		return
	system.knocked.connect(func(who: FishController, p: Porthole, speed: float) -> void:
		knocks.append([who, p, speed, system.entry_problem(who, p)]))
	check(holes.size() >= 6 and holes.size() <= 10, "6 to 10 portholes")
	var start := arena.seeker_start().origin
	var nearest := INF
	for p in holes:
		nearest = minf(nearest, p.mouth().distance_to(start))
	check(nearest > 25.0, "none near the seeker's start (nearest %.1f m)" % nearest)
	check(arena.hider_spawns().size() >= 6, "hider spawns (%d)" % arena.hider_spawns().size())
	check(arena.map_outlines().size() >= 8, "map outlines (%d)" % arena.map_outlines().size())
	check(arena.sight_range() > 30.0 and arena.sight_range() < 120.0, "murk sight range %.1f m" % arena.sight_range())
	var space := arena.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(start, start + Vector3(0.0, 0.0, -200.0) if start.z > 0.0 else start + Vector3(0.0, 0.0, 200.0), arena.sight_blockers_mask())
	check(not space.intersect_ray(ray).is_empty(), "walls and furniture are on the sight-blocker layer")
	if arena is FishTankArena:
		var masked := false
		for curtain in arena.curtains():
			if curtain.active and arena.bubble_mask_at(curtain.global_position + Vector3.UP * 5.0) < 1.0:
				masked = true
		check(masked and arena.bubble_mask_at(arena.seeker_start().origin) == 1.0, "a working bubble curtain masks, open water doesn't")
		check(not arena.bubble_sources().is_empty(), "the bubbles fizz on the scope (%d spots)" % arena.bubble_sources().size())

	# A round where a bot seeks and the player hides.
	game.start_round(1)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	check(game.phase == MarcoPoloMatch.Phase.LIVE and game.is_live_hider(fish), "live, the player hiding")
	var seeker: FishController = game.seekers()[0]
	_park(seeker, start)
	var p: Porthole = _pick(holes, start)

	print(" entry:")
	await _approach(fish, p, 2.5, 0.0, 0.0, false)
	check(system.is_hidden(fish) and system.porthole_of(fish) == p and p.occupant == fish, "a lined-up slow approach gets in")
	await _seconds(mp.porthole_turn_time + 0.1)
	var facing := -fish.global_basis.z
	check(facing.dot(p.axis()) > 0.98, "the fish ends up facing out (%.3f)" % facing.dot(p.axis()))
	check(fish.global_position.distance_to(p.seat(fish.hitbox_length).origin) < 0.05, "at its seat, head just inside the opening")
	check(sounds.has("mp/porthole_in"), "mp/porthole_in")

	print(" inside:")
	var held := fish.global_transform
	fish.apply_push(Vector3(5.0, 0.0, 5.0))
	fish.linear_velocity = p.axis() * 6.0
	await _seconds(0.5)
	check(system.is_hidden(fish) and fish.global_transform.origin.distance_to(held.origin) < 0.01, "steering and pushes do nothing inside")
	# The seeker's bow right at the opening, coming in at speed.
	seeker.freeze = false
	seeker.global_transform = Transform3D(Basis.looking_at(-p.axis(), Vector3.UP), p.mouth() + p.axis() * (seeker.hitbox_length * 0.5 + 0.3))
	for i in 20:
		seeker.linear_velocity = -p.axis() * 12.0
		await get_tree().physics_frame
	check(game.is_live_hider(fish), "the bow can't tag a hider in a porthole")
	_park(seeker, start)
	print(" hidden:")
	_park(seeker, p.mouth() + p.axis() * 8.0, -p.axis())
	var tally := game.own_round_tally(fish)
	var pings := game.recent_pings(seeker).size()
	game.add_noise(fish, 1.0)
	await _seconds(1.0)
	check(game.exposure(seeker, fish) == 0.0, "no exposure in any seeker's view")
	check(game.recent_pings(seeker).size() == pings, "nothing on the scope (%d -> %d pings)" % [pings, game.recent_pings(seeker).size()])
	check(not game.in_sight(seeker, fish), "out of line of sight")
	check(is_equal_approx(game.own_round_tally(fish), tally), "no score from inside (%.2f -> %.2f)" % [tally, game.own_round_tally(fish)])
	var inside_for := 2.0 + mp.porthole_turn_time + 0.1
	check(absf(system.gauge(fish) - inside_for / mp.porthole_time) < 0.06, "the gauge fills (%.2f after ~%.1f s)" % [system.gauge(fish), inside_for])
	_park(seeker, start)

	print(" out:")
	var input := FishInput.new()
	fish.controls = input
	var before_noise := game.noise(fish)
	await _ticks(2)
	input.jump = true
	await _ticks(2)
	input.jump = false
	check(not system.is_hidden(fish) and p.is_free(), "jump gets it out")
	check(fish.linear_velocity.normalized().dot(p.axis()) > 0.95 and fish.linear_velocity.length() > mp.porthole_exit_speed * 0.8,
			"straight out along the axis at porthole_exit_speed (%.1f m/s)" % fish.linear_velocity.length())
	var mask := arena.bubble_mask_at(fish.global_position)
	check(game.noise(fish) >= mp.porthole_exit_noise * mask * 0.8 and game.noise(fish) > before_noise,
			"a loud exit (noise %.2f, bubble mask %.2f)" % [game.noise(fish), mask])
	check(sounds.has("mp/porthole_out"), "mp/porthole_out")
	fish.controls = null
	var gauge_out := system.gauge(fish)
	await _seconds(3.0)
	var drained := gauge_out - system.gauge(fish)
	var expected := 3.0 / mp.porthole_time * mp.porthole_recovery
	check(absf(drained - expected) < 0.04, "it drains at porthole_recovery outside (%.3f, expected %.3f)" % [drained, expected])

	print(" knocks:")
	for case: Array in [["fast", 8.0, 0.0, 0.0, false], ["angled", 2.5, 35.0, 0.0, false], ["off centre", 2.5, 0.0, 0.95, false],
			["mid-flip", 2.5, 0.0, 0.0, true]]:
		knocks.clear()
		sounds.clear()
		await _seconds(0.7)  # past the knock cooldown
		var noise_before := game.noise(fish)
		await _approach(fish, p, case[1], case[2], case[3], case[4])
		check(not system.is_hidden(fish) and _knocked(fish) != "", "%s: knocks off the rim (%s)" % [case[0], _knocked(fish)])
		check(sounds.has("mp/bump") and game.noise(fish) > noise_before, "%s: a knock is noise (%.2f -> %.2f) and mp/bump" % [case[0], noise_before, game.noise(fish)])
	# A taken porthole: a bot hider sits in it; the player knocks.
	var other: FishController = _bot_hiders(game)[0]
	_park(fish, p.mouth() + p.axis() * 12.0)
	other.freeze = false
	await _approach(other, p, 2.0, 0.0, 0.0, false)
	check(system.is_hidden(other), "a bot hider gets in too%s" % _why(other))
	knocks.clear()
	await _seconds(0.7)
	await _approach(fish, p, 2.0, 0.0, 0.0, false)
	check(not system.is_hidden(fish) and _knocked(fish) == "taken", "one fish per porthole: a taken one knocks (%s)" % _knocked(fish))
	# Seekers never get in.
	system.request_exit(other)
	await _ticks(2)
	knocks.clear()
	await _approach(seeker, p, 2.0, 0.0, 0.0, false)
	check(not system.is_hidden(seeker), "a seeker can't get in")
	_park(seeker, start)

	print(" out of water:")
	mp.porthole_time = 1.2
	var dried: Array = []
	system.dried_out.connect(func(who: FishController) -> void: dried.append(who), CONNECT_ONE_SHOT)
	await _seconds(0.7)
	_park(fish, p.mouth() + p.axis() * 12.0)
	other.freeze = false
	await _approach(other, p, 2.0, 0.0, 0.0, false)
	check(system.is_hidden(other), "in again%s" % _why(other))
	await _until(func() -> bool: return not dried.is_empty(), 3.0)
	check(dried.has(other) and game.eliminated.has(other), "Last Fish Swimming: a full gauge is caught (eliminated)")
	check(not system.is_hidden(other), "the fish flops out")
	mp.variant = MarcoPoloSettings.Variant.CONVERSION
	game.start_round(2)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	var hider: FishController = _bot_hiders(game)[0] if not _bot_hiders(game).is_empty() else null
	check(hider != null, "a bot hider in the new round")
	if hider:
		check(system.gauge(hider) == 0.0 and not system.is_hidden(hider), "a new round starts with empty gauges, nobody inside")
		dried.clear()
		system.dried_out.connect(func(who: FishController) -> void: dried.append(who), CONNECT_ONE_SHOT)
		hider.freeze = false
		await _approach(hider, p, 2.0, 0.0, 0.0, false)
		await _until(func() -> bool: return not dried.is_empty(), 3.0)
		check(dried.has(hider) and game.role_of(hider) == MarcoPoloMatch.Role.SEEKER, "Join the Seekers: a full gauge is caught (joins the seekers)")
	mp.porthole_time = 8.0
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION

	print(" a bot lines up by itself:")
	game.start_round(3)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	_park(game.seekers()[0], start)
	var bots_hiding := _bot_hiders(game)
	if not bots_hiding.is_empty():
		var lone: FishController = bots_hiding[0]
		var bot: MarcoPoloBot = game.bots[lone]
		var target := _open_porthole(holes, arena)
		# Bots can miss and knock like people, so it gets a few tries from the same place.
		var took := 0.0
		var tries := 0
		bot.process_mode = Node.PROCESS_MODE_INHERIT
		while tries < 5 and not system.is_hidden(lone):
			tries += 1
			_park(lone, target.mouth() + target.axis() * 14.0 + target.axis().cross(Vector3.UP).normalized() * 3.0)
			lone.freeze = false
			bot.go_to_porthole(target)
			took = 0.0
			for i in 15 * TICKS:
				if system.is_hidden(lone):
					break
				took += 1.0 / TICKS
				if OS.get_cmdline_user_args().has("--trace") and i % 120 == 0:
					print("    try %d t %.0f: along %.1f off %.1f speed %.1f plan %d %s" % [tries, took, target.along(lone.global_position),
							target.off_axis(lone.global_position), lone.linear_velocity.length(), bot.plan, lone.global_position])
				await get_tree().physics_frame
		check(system.is_hidden(lone), "a bot hider gets itself into a porthole (try %d of 5, %.1f s)%s" % [tries, took, _why(lone)])
	await _jump_checks(game, system, holes, arena)
	mp.porthole_jump_entry = true


func _jump_checks(game: MarcoPoloMatch, system: PortholeSystem, holes: Array[Porthole], arena: MarcoArena) -> void:
	print(" jump entry:")
	mp.porthole_jump_entry = true
	mp.stick_to_surfaces = false  # Marco Polo's default
	game.start_round(1)
	await _ticks(2)
	_still_bots(game)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	var start := arena.seeker_start().origin
	var seeker: FishController = game.seekers()[0]
	_park(seeker, start)
	check(game.is_live_hider(fish), "the player hides")
	var p := _open_porthole(holes, arena)
	var input := FishInput.new()
	fish.controls = input
	# Side on, swimming past fast: Jump still takes it in.
	var side := p.axis().cross(Vector3.UP).normalized()
	_park(fish, p.mouth() + p.axis() * 2.0, side)
	fish.freeze = false
	fish.linear_velocity = side * 9.0
	await _ticks(3)
	check(system.jump_porthole(fish) == p, "by the mouth, side on: Jump would take it in")
	var noise_before := game.noise(fish)
	input.jump = true
	await _ticks(3)
	input.jump = false
	check(system.is_hidden(fish) and system.porthole_of(fish) == p, "Jump slips it in, side on and fast")
	check(game.noise(fish) <= noise_before + 0.01, "quietly: no jump noise (%.2f -> %.2f)" % [noise_before, game.noise(fish)])
	await _seconds(mp.porthole_turn_time + 0.1)
	check(fish.global_position.distance_to(p.seat(fish.hitbox_length).origin) < 0.05, "at its seat")
	input.jump = true
	await _ticks(3)
	input.jump = false
	check(not system.is_hidden(fish), "Jump gets it out again")
	await _ticks(3)
	check(not system.is_hidden(fish) and system.jump_porthole(fish) == null, "and not straight back in")
	await _seconds(PortholeSystem.JUMP_IN_COOLDOWN + 0.1)
	# Too far out: just a jump (with its noise).
	_park(fish, p.mouth() + p.axis() * (mp.porthole_jump_range + 2.0), -p.axis())
	fish.freeze = false
	await _ticks(3)
	noise_before = game.noise(fish)
	input.jump = true
	await _ticks(3)
	input.jump = false
	check(not system.is_hidden(fish) and game.noise(fish) > noise_before, "too far: a plain jump, noise and all (%.2f -> %.2f)" % [noise_before, game.noise(fish)])
	fish.controls = null
	# Seekers never get in.
	var seeker_input := FishInput.new()
	seeker.controls = seeker_input
	_park(seeker, p.mouth() + p.axis() * 1.5, -p.axis())
	seeker.freeze = false
	await _ticks(3)
	seeker_input.jump = true
	await _ticks(3)
	seeker_input.jump = false
	check(not system.is_hidden(seeker) and system.jump_porthole(seeker) == null, "a seeker can't jump in")
	seeker.controls = null
	_park(seeker, start)
	# A bot hider swims up and jumps in by itself.
	var bots_hiding := _bot_hiders(game)
	if bots_hiding.is_empty():
		return
	var lone: FishController = bots_hiding[0]
	var bot: MarcoPoloBot = game.bots[lone]
	_park(fish, p.mouth() + p.axis() * 14.0 - side * 6.0)
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	_park(lone, p.mouth() + p.axis() * 14.0 + side * 3.0)
	lone.freeze = false
	bot.go_to_porthole(p)
	var took := 0.0
	for i in 20 * TICKS:
		if system.is_hidden(lone):
			break
		took += 1.0 / TICKS
		if OS.get_cmdline_user_args().has("--trace") and i % 120 == 0:
			print("    t %.0f: along %.1f off %.1f to mouth %.1f speed %.1f plan %d jump_porthole %s" % [took, p.along(lone.global_position),
					p.off_axis(lone.global_position), lone.global_position.distance_to(p.mouth()), lone.linear_velocity.length(), bot.plan,
					system.jump_porthole(lone)])
			print("      y %.2f floor-ish contacts %d fwd %.1f stick %s phase %.2f facing %s" % [lone.global_position.y, lone.get_contact_count(),
					bot.input.forward, bot.input.stick, lone.swishy.phase, -lone.global_basis.z])
		await get_tree().physics_frame
	check(system.is_hidden(lone), "a bot hider swims up and jumps into a porthole (%.1f s)" % took)


## A free porthole with 15 m of open water straight out in front of it.
func _open_porthole(holes: Array[Porthole], arena: MarcoArena) -> Porthole:
	var space := arena.get_world_3d().direct_space_state
	for p in holes:
		if not p.is_free():
			continue
		var ray := PhysicsRayQueryParameters3D.create(p.mouth() + p.axis() * 0.6, p.mouth() + p.axis() * 15.0, arena.sight_blockers_mask())
		if space.intersect_ray(ray).is_empty():
			return p
	return holes[0]


## The porthole furthest from `start`.
func _pick(holes: Array[Porthole], start: Vector3) -> Porthole:
	var best: Porthole = holes[0]
	for p in holes:
		if p.mouth().distance_to(start) > best.mouth().distance_to(start):
			best = p
	return best


## `who` comes at `p` from 3 m out at `speed`, `angle` degrees off its axis
## (turned and offset to match), `off` m to the side, flipping if `flipping`,
## until it's in or knocked (or 2 s pass).
func _approach(who: FishController, p: Porthole, speed: float, angle: float, off: float, flipping: bool) -> void:
	var side := p.axis().cross(Vector3.UP).normalized()
	var heading := (-p.axis()).rotated(Vector3.UP, deg_to_rad(angle))
	var nose_at := p.mouth() + side * off + p.axis() * 0.02
	var start := nose_at - heading * (3.0 + who.hitbox_length * 0.5)
	who.freeze = false
	who.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), start)
	var system := (main.marco_polo as MarcoPoloMatch).porthole_system as PortholeSystem
	knocks = knocks.filter(func(k: Array) -> bool: return k[0] != who)
	for i in 2 * TICKS:
		if system.is_hidden(who) or _knocked(who) != "":
			break
		who.linear_velocity = heading * speed
		who.angular_velocity = Vector3.ZERO
		if flipping:
			who.is_dodging = true
		await get_tree().physics_frame
	who.is_dodging = false
	await _ticks(2)


## Why `who` last knocked ("" if it hasn't since its approach began).
func _knocked(who: FishController) -> String:
	for k: Array in knocks:
		if k[0] == who:
			return k[3]
	return ""


func _why(who: FishController) -> String:
	return "" if _knocked(who) == "" else " (knocked: %s)" % _knocked(who)


func _finish() -> void:
	print("porthole_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


## Bots off, and every bot hider but the first parked out of the way by the
## seeker's start (frozen: a sinking fish mustn't drift into a porthole's mouth).
func _still_bots(game: MarcoPoloMatch) -> void:
	for bot: Node in game.bots.values():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		var input: Variant = bot.get("input")
		if input is FishInput:
			(input as FishInput).clear()
	var spare := _bot_hiders(game)
	var arena := game.arena as MarcoArena
	if arena == null:
		return
	for i in range(1, spare.size()):
		_park(spare[i], arena.seeker_start().origin + Vector3(3.0 * i, 0.0, 4.0))


func _bot_hiders(game: MarcoPoloMatch) -> Array[FishController]:
	var out: Array[FishController] = []
	for f in game.live_hiders():
		if game.bots.has(f):
			out.append(f)
	return out


func _park(who: FishController, at: Vector3, facing := Vector3.FORWARD) -> void:
	who.freeze = true
	who.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), at)
	who.linear_velocity = Vector3.ZERO
	who.angular_velocity = Vector3.ZERO


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _ticks(roundi(s * TICKS))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
