class_name WhatStinksEcho
extends Node
## What the Hunter can see of each prey player in What Stinks? (what_stinks.md
## section 4). Two things build the picture, per Hunter view, and the reveal
## layers (HiderLooks / FishAnatomy: skeleton, heart, muscle, skin, aura) show
## the larger of them:
## - noise: Marco Polo's NoiseMeter on every prey (loud swimming, flips, jumps,
##   strides, a loud Leave), seen out to noise_sight and falling with distance;
##   a joined player is silent (it moves with the school);
## - echo (new): a value 0..1 per Hunter and prey. It builds while the prey is
##   inside the Hunter's echo cone (an angle and a range scaled by hunter size),
##   fastest when the prey is still and near and slowing to smear_floor at
##   smear_speed or more (a fast fish is a smeared echo), x blend_echo_mult for a
##   school member (the crowd's clutter), x shadow_mult in an echo shadow
##   (WhatStinksShadows); it dies away at echo_decay outside the cone and in a
##   shadow. exposure = max(noise, echo): a still loner is skin-deep seen in
##   ~5 s and a school member ~10x slower, its faint skeleton the tell.
## - Click: the Hunter's ping (auto on its cooldown, as the Titan's auto Marco,
##   or on a button): every prey in the cone gets click_gain at once (a school
##   member x blend_echo_mult).
## - Sniff (hold a button): the cone narrows, echo builds x sniff_mult, and the
##   Hunter swims at sniff_speed of its speed.
## The match calls begin_round(); the host judges everything here (a guest's
## values arrive with Phase 6). Prey see how clear the Hunter's picture of them
## is on their echo and noise rings (WhatStinksHud).

## A Click went out from `hunter` at `origin`, reaching `reached` prey.
signal clicked(hunter: FishController, origin: Vector3, reached: int)
signal sniff_changed(hunter: FishController, on: bool)
## A guest: which of the four buttons our Hunter holds changed (a bitmask in BUTTONS order), and a burst of noise our own prey made; the host judges both.
signal local_buttons(mask: int)
signal local_burst(amount: float)

const BUTTONS := ["jump", "boost", "powerslide", "air_roll"]

var game: WhatStinksMatch
var settings := WhatStinksSettings.shared()
## The noise settings (Marco Polo's: speeds, bursts, layer bands) NoiseMeter and the reveal layers read.
var noise_settings := MarcoPoloSettings.shared()
var size := HunterSize.shared()
var shadows: WhatStinksShadows
## hunter -> {prey -> echo 0..1}.
var echo := {}
## prey -> its NoiseMeter.
var meters := {}
## prey -> exposure forced for every Hunter (probes, shots, the console); erase to release.
var forced := {}
## hunter -> seconds until its next Click.
var click_left := {}
## hunter -> Clicks sent this round.
var clicks := {}
## hunter -> sniffing now.
var sniffing := {}

## A guest: what the host sends of the clearest view: prey -> exposure (a Hunter: every live prey; a prey: itself), a prey's own echo and noise rings.
var net_view := {}
var net_echo := 0.0
var net_noise := 0.0
var _sniff_saved := {}
var _last_mask := -1
var _pressed := {}  # hunter -> {button -> held last tick}
var _ring: MeshInstance3D
var _ring_age := 99.0
var _ring_reach := 1.0


func bind(match_node: WhatStinksMatch) -> void:
	game = match_node
	if game.join != null:
		game.join.echo_reset.connect(_on_echo_reset)
		game.join.left.connect(_on_left)
		game.join.joined.connect(_on_joined)
	game.phase_changed.connect(_on_phase)
	_ring = MeshInstance3D.new()
	_ring.name = "ClickRing"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_ring.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.albedo_color = Color(0.7, 0.9, 1.0, 0.0)
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


## A new round: every prey gets a fresh meter and a clean echo, the Hunters their cooldowns.
func begin_round(prey_and_hunters: Array[FishController]) -> void:
	_drop_sniff_all()
	for meter: NoiseMeter in meters.values():
		meter.detach()
	meters.clear()
	echo.clear()
	forced.clear()
	click_left.clear()
	clicks.clear()
	_pressed.clear()
	for fish in prey_and_hunters:
		if is_instance_valid(fish) and not game.hunters.has(fish):
			meters[fish] = NoiseMeter.new(fish, noise_settings)
			if not game.authority and fish == game.local_fish():
				(meters[fish] as NoiseMeter).burst.connect(func(amount: float) -> void: local_burst.emit(amount))
	for hunter in game.hunters:
		echo[hunter] = {}
		click_left[hunter] = settings.click_cooldown
		clicks[hunter] = 0
	net_view.clear()
	net_echo = 0.0
	net_noise = 0.0
	_last_mask = -1
	_ring.visible = false
	_ring_age = 99.0


## Everything let go (end of the match).
func clear() -> void:
	_drop_sniff_all()
	for meter: NoiseMeter in meters.values():
		meter.detach()
	meters.clear()
	echo.clear()
	forced.clear()


func _exit_tree() -> void:
	clear()


func _on_phase(phase: int) -> void:
	if phase == WhatStinksMatch.Phase.LIVE:
		for meter: NoiseMeter in meters.values():
			meter.reset()  # what the countdown's scatter made is forgotten


func _on_echo_reset(fish: FishController) -> void:
	for hunter: Variant in echo:
		(echo[hunter] as Dictionary)[fish] = 0.0


func _on_joined(fish: FishController, _school: School, _index: int) -> void:
	var meter := meters.get(fish) as NoiseMeter
	if meter != null:
		meter.muted = true  # in lockstep with the crowd: no wake, no strides


func _on_left(fish: FishController, loud: bool) -> void:
	var meter := meters.get(fish) as NoiseMeter
	if meter != null:
		meter.muted = false
		if loud:
			meter.add(settings.leave_noise)


# --- Asking -------------------------------------------------------------------

func is_joined(prey: FishController) -> bool:
	return game != null and game.join != null and game.join.is_joined(prey)


## The echo cone's half angle (radians) for `hunter` now (sniffing narrows it).
func cone_half_angle(hunter: FishController) -> float:
	var angle := deg_to_rad(clampf(settings.echo_cone_deg, 1.0, 180.0))
	return angle * (settings.sniff_cone_mult if is_sniffing(hunter) else 1.0)


## The cone's range and full-build distance (m), x the Hunter's size^echo_size_exp.
func cone_range(hunter: FishController) -> float:
	return settings.echo_range * pow(size.size_of(hunter), settings.echo_size_exp)


func cone_near(hunter: FishController) -> float:
	return minf(settings.echo_near * pow(size.size_of(hunter), settings.echo_size_exp), cone_range(hunter))


## Whether `point` is inside `hunter`'s echo cone (the angle and the range).
func in_cone(hunter: FishController, point: Vector3) -> bool:
	var off := point - hunter.global_position
	var gap := off.length()
	if gap > cone_range(hunter):
		return false
	if gap < 0.001:
		return true
	var forward := -hunter.global_basis.z.normalized()
	return forward.angle_to(off / gap) <= cone_half_angle(hunter)


## 1 within the near range, falling to 0 at the range.
func range_falloff(hunter: FishController, gap: float) -> float:
	var reach := cone_range(hunter)
	var near := cone_near(hunter)
	if gap <= near:
		return 1.0
	if gap >= reach:
		return 0.0
	return 1.0 - (gap - near) / maxf(reach - near, 0.001)


## The share of the full build a prey at `speed` (m/s) gets: 1 still, smear_floor at smear_speed and more.
func smear(speed: float) -> float:
	var t := clampf(speed / maxf(settings.smear_speed, 0.01), 0.0, 1.0)
	return settings.smear_floor + (1.0 - settings.smear_floor) * pow(1.0 - t, settings.smear_curve)


func in_shadow(point: Vector3) -> bool:
	return shadows != null and shadows.in_shadow(point)


## `hunter`'s echo of `prey` (0..1).
func echo_of(hunter: FishController, prey: FishController) -> float:
	var seen: Dictionary = echo.get(hunter, {})
	return float(seen.get(prey, 0.0))


## The clearest any Hunter's echo of `prey` is (the prey's own ring).
func echo_max(prey: FishController) -> float:
	if game != null and not game.authority:
		return net_echo if prey == game.local_fish() else 0.0
	var best := 0.0
	for hunter: Variant in echo:
		best = maxf(best, float((echo[hunter] as Dictionary).get(prey, 0.0)))
	return best


func meter_of(prey: FishController) -> NoiseMeter:
	return meters.get(prey) as NoiseMeter


## `prey`'s noise now (0..1; the NoiseMeter).
func noise_of(prey: FishController) -> float:
	if game != null and not game.authority:
		return net_noise if prey == game.local_fish() else 0.0
	var meter := meters.get(prey) as NoiseMeter
	return meter.noise if meter != null else 0.0


## The distance falloff of noise at `gap` m from `hunter` (1 near, 0.5 half way, 0 at noise_sight).
func noise_falloff(hunter: FishController, gap: float) -> float:
	var reach := settings.noise_sight * pow(size.size_of(hunter), settings.echo_size_exp)
	var near := reach * settings.noise_near_share
	var half := clampf(reach * settings.noise_half_share, near, reach)
	if gap <= near:
		return 1.0
	if gap >= reach:
		return 0.0
	if gap <= half:
		return lerpf(1.0, 0.5, (gap - near) / maxf(half - near, 0.001))
	return lerpf(0.5, 0.0, (gap - half) / maxf(reach - half, 0.001))


## What `hunter` hears of `prey`'s noise (0..1).
func noise_exposure(hunter: FishController, prey: FishController) -> float:
	var raw := pow(clampf(noise_of(prey), 0.0, 1.0), noise_settings.exposure_curve)
	return raw * noise_falloff(hunter, prey.global_position.distance_to(hunter.global_position))


## How clearly `hunter` sees `prey`: max(noise, echo), 0..1 (what the reveal layers show).
func exposure(hunter: FishController, prey: FishController) -> float:
	if forced.has(prey):
		return float(forced[prey])
	if game == null or not game.is_live_prey(prey):
		return 0.0
	if not game.authority:
		return float(net_view.get(prey, 0.0))  # what the host says our view is
	return maxf(noise_exposure(hunter, prey), echo_of(hunter, prey))


## The clearest any Hunter sees `prey` (the prey's self view).
func max_exposure(prey: FishController) -> float:
	var best := float(forced[prey]) if forced.has(prey) else 0.0
	if not game.authority:
		return maxf(best, float(net_view.get(prey, 0.0)))
	for hunter in game.hunters:
		best = maxf(best, exposure(hunter, prey))
	return best


func is_sniffing(hunter: FishController) -> bool:
	return bool(sniffing.get(hunter, false))


## Seconds until `hunter` can Click again.
func click_ready_in(hunter: FishController) -> float:
	return float(click_left.get(hunter, 0.0))


# --- Doing --------------------------------------------------------------------

## Sets every Hunter's echo of `prey` (probes, shots).
func set_echo(prey: FishController, value: float) -> void:
	for hunter: Variant in echo:
		(echo[hunter] as Dictionary)[prey] = clampf(value, 0.0, 1.0)


## `hunter` Clicks (if its cooldown is up, or `force`): an instant bump of
## click_gain (a school member's x blend_echo_mult, an echo shadow's x
## shadow_mult) to every live prey in the cone. Returns how many it reached, -1 if not ready.
func click(hunter: FishController, force := false) -> int:
	if not force and float(click_left.get(hunter, 0.0)) > 0.0:
		return -1
	click_left[hunter] = settings.click_cooldown
	clicks[hunter] = int(clicks.get(hunter, 0)) + 1
	var reached := 0  # (apply_net_click shows it on a guest)
	var seen: Dictionary = echo.get(hunter, {})
	for prey in game.live_prey():
		if not in_cone(hunter, prey.global_position):
			continue
		var bump := settings.click_gain
		if is_joined(prey):
			bump *= settings.blend_echo_mult
		if in_shadow(prey.global_position):
			bump *= settings.shadow_mult
		seen[prey] = minf(float(seen.get(prey, 0.0)) + bump, 1.0)
		reached += 1
	echo[hunter] = seen
	_show_ring(hunter)
	clicked.emit(hunter, hunter.global_position, reached)
	return reached


func _show_ring(hunter: FishController) -> void:
	if hunter == game.local_fish():
		_ring.global_position = hunter.global_position
		_ring_age = 0.0
		_ring_reach = cone_range(hunter)
		_ring.visible = true


## A burst of noise from `prey` (a guest's own, sent to the host).
func add_noise(prey: FishController, amount: float) -> void:
	var meter := meters.get(prey) as NoiseMeter
	if meter != null:
		meter.add(amount)


## A guest: the host's Hunter Clicked (the ring on ours, the cooldown running).
func apply_net_click(hunter: FishController, origin: Vector3, reached: int) -> void:
	click_left[hunter] = settings.click_cooldown
	clicks[hunter] = int(clicks.get(hunter, 0)) + 1
	_show_ring(hunter)
	clicked.emit(hunter, origin, reached)


## A guest: the host's say on whether `hunter` sniffs (the slowdown on ours, the cone on the host).
func apply_net_sniff(hunter: FishController, on: bool) -> void:
	_set_sniff(hunter, on)


## A guest: our view as the host sends it (see net_view), and our Click's cooldown if we Hunt.
func apply_net_view(view: Dictionary, own_echo: float, own_noise: float, click_in: float) -> void:
	net_view = view
	net_echo = own_echo
	net_noise = own_noise
	var me := game.local_fish()
	if game.hunters.has(me):
		click_left[me] = click_in


## Echo `prey` gains per second from `hunter` now (before decay); 0 outside the cone.
func build_rate(hunter: FishController, prey: FishController) -> float:
	var at := prey.global_position
	if not in_cone(hunter, at):
		return 0.0
	var rate := settings.echo_build * range_falloff(hunter, at.distance_to(hunter.global_position))
	var joined := is_joined(prey)
	rate *= 1.0 if joined else smear(prey.swim_velocity().length())  # in the crowd it moves with the crowd: still, to it
	if joined:
		rate *= settings.blend_echo_mult
	if is_sniffing(hunter):
		rate *= settings.sniff_mult
	if in_shadow(at):
		rate *= settings.shadow_mult
	return rate


# --- Each tick ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if not game.authority:
		_guest_step(delta)
		return
	if game.phase != WhatStinksMatch.Phase.LIVE:
		return
	for key: Variant in meters.keys():
		if not is_instance_valid(key):
			meters.erase(key)  # a fish that left
			continue
		var prey := key as FishController
		var meter: NoiseMeter = meters[prey]
		meter.muted = is_joined(prey) or not game.is_live_prey(prey)
		meter.step(delta)
	for hunter in game.hunters:
		if not is_instance_valid(hunter):
			continue
		_read_buttons(hunter, delta)
		var seen: Dictionary = echo.get(hunter, {})
		for prey in game.live_prey():
			var now := float(seen.get(prey, 0.0))
			var rate := build_rate(hunter, prey)
			if rate > 0.0:
				now += rate * delta
			if rate <= 0.0 or in_shadow(prey.global_position):
				now -= settings.echo_decay * delta
			seen[prey] = clampf(now, 0.0, 1.0)
		for gone: Variant in seen.keys():
			if not is_instance_valid(gone) or not game.is_live_prey(gone):
				seen.erase(gone)
		echo[hunter] = seen
	_mirror_to_join()


## A guest: our Hunter's buttons go to the host (it builds the cone, Clicks, judges), and Sniff
## slows us here at once (the host says the same back). Our Click's cooldown runs down between its views.
func _guest_step(delta: float) -> void:
	var me := game.local_fish()
	if not is_instance_valid(me) or not game.hunters.has(me) or game.phase != WhatStinksMatch.Phase.LIVE:
		_last_mask = -1
		return
	click_left[me] = maxf(float(click_left.get(me, 0.0)) - delta, 0.0)
	var mask := 0
	for i in BUTTONS.size():
		if _held(me, BUTTONS[i]):
			mask |= 1 << i
	if mask != _last_mask:
		_last_mask = mask
		local_buttons.emit(mask)
	var sniff_now := _held(me, settings.sniff_button) and not me.controls_locked
	if sniff_now != is_sniffing(me):
		_set_sniff(me, sniff_now)


## Join's `echo` (the placeholder Phase 2 left) shows the clearest Hunter's echo.
func _mirror_to_join() -> void:
	if game.join == null:
		return
	for prey in game.players:
		if game.join.echo.has(prey):
			game.join.echo[prey] = echo_max(prey)


func _read_buttons(hunter: FishController, delta: float) -> void:
	click_left[hunter] = maxf(float(click_left.get(hunter, 0.0)) - delta, 0.0)
	var pressed: Dictionary = _pressed.get(hunter, {})
	var click_now := _held(hunter, settings.click_button)
	var sniff_now := _held(hunter, settings.sniff_button) and not hunter.controls_locked
	if settings.click_auto:
		if float(click_left[hunter]) <= 0.0:
			click(hunter)
	elif click_now and not bool(pressed.get("click", false)) and not hunter.controls_locked:
		click(hunter)
	pressed["click"] = click_now
	_pressed[hunter] = pressed
	if sniff_now != is_sniffing(hunter):
		_set_sniff(hunter, sniff_now)


## Whether `fish` holds `button` (a controller or bot input alike, as HunterBite reads).
func _held(fish: FishController, button: String) -> bool:
	if fish.puppet:  # a guest's Hunter: the host knows its buttons from what the guest sent
		return (int(fish.get_meta("ws_buttons", 0)) >> maxi(BUTTONS.find(button), 0)) & 1 == 1
	match button:
		"boost":
			return fish.boost_held
		"powerslide":
			return fish.powerslide_held
		"air_roll":
			return fish.air_roll_held
	return fish.jump_held


func _set_sniff(hunter: FishController, on: bool) -> void:
	if on == is_sniffing(hunter):
		return
	sniffing[hunter] = on
	if on:
		_sniff_saved[hunter] = [hunter.speed_scale, hunter.top_speed_scale, hunter.boost_scale]
		hunter.speed_scale *= settings.sniff_speed
		hunter.top_speed_scale *= settings.sniff_speed
		hunter.boost_scale *= settings.sniff_speed
	else:
		_restore_sniff(hunter)
	sniff_changed.emit(hunter, on)


func _restore_sniff(hunter: FishController) -> void:
	var saved: Array = _sniff_saved.get(hunter, [])
	_sniff_saved.erase(hunter)
	if saved.size() == 3 and is_instance_valid(hunter):
		hunter.speed_scale = float(saved[0])
		hunter.top_speed_scale = float(saved[1])
		hunter.boost_scale = float(saved[2])


func _drop_sniff_all() -> void:
	for hunter: Variant in sniffing.keys():
		if bool(sniffing[hunter]):
			_restore_sniff(hunter as FishController)
	sniffing.clear()
	_sniff_saved.clear()


func _process(delta: float) -> void:
	if _ring == null or not _ring.visible:
		return
	_ring_age += delta
	var t := _ring_age / 0.9
	if t >= 1.0:
		_ring.visible = false
		return
	_ring.scale = Vector3.ONE * maxf(_ring_reach * t, 0.1)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.18 * (1.0 - t)
