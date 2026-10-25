class_name Traversal
extends RefCounted
## Each fish's traversal in Unnatural, the second half of every fish being
## unique (settings' Twists and Mobility groups). Two parts:
##
## A passive twist, always on:
## - Clownfish, Nimble: sharper turns (FishController.turn_scale).
## - Shark, Frenzy: faster after each kill, held a while, then fading.
## - String Ray, Glide: coasts without losing speed (FishController.drag_scale).
## - Swordfish, Streamlined: swims a little faster.
## - Butterfly Koi, Graceful: longer i-frames after a hit.
## - Boxfish, Armoured: takes less damage, swims slower.
## - Lionfish, Wake: Greek Fire burns harder the faster it swims.
## - Moon Jelly, Many Arms: one more jelly in its Halo.
## - Breachers (baby whales), Escort: heals while it holds still.
## - Mantis Shrimp, Heavy Hitter: zombies its punches knock back hurt the ones
##   they fly into (fling()).
## - Sea Hare, Unpalatable: a zombie that touches it is coated: slowed a while,
##   and Purple Haze hurts it more (is_coated()).
##
## And a mobility skill on the boost button (RB, Shift: boosting is off in
## Unnatural), on its own cooldown (mobility()):
## - Clownfish, Wriggle: a burst sideways, untouchable a moment.
## - Shark, Fin Dash: a charge that batters everything in the way.
## - String Ray, Surge: a stroke forward with no drag for a while.
## - Swordfish, Dash: a burst ahead, untouchable a moment.
## - Butterfly Koi, Leap: leaps up, and splashes down on the zombies.
## - Boxfish, Brace: takes a fraction of the damage for a few seconds.
## - Lionfish, Flare Dash: a dash with its spines flared, hurting what it passes.
## - Moon Jelly, Go Quiet: switches its stink off: nothing fires, and zombies
##   lose track of it (until it's hurt or the time's up).
## - Mantis Shrimp, Recoil Dash: punches one way, and the recoil throws it the
##   other (the way the stick leans, else backwards), untouchable a moment.
## - Breachers (baby whales), Gulp: sucks the zombies ahead of it in.
## - Sea Hare, Flutter: three big flaps carry it up and forward over the pack,
##   dropping a Purple Haze cloud where it took off.
## UnnaturalRun owns one per local player and calls update() every tick.
## Away from a run (`run` null: the Obstacle Course's CourseSkill) the skills
## still move the fish and show their effects, but there's nothing to hit,
## shield or heal.

## Passive twist titles.
const NAMES := {
	FishCharacter.FishClass.SKIRMISHER: "Nimble",
	FishCharacter.FishClass.HUNTER: "Frenzy",
	FishCharacter.FishClass.GLIDER: "Glide",
	FishCharacter.FishClass.LANCER: "Streamlined",
	FishCharacter.FishClass.CHARMER: "Graceful",
	FishCharacter.FishClass.BULWARK: "Armoured",
	FishCharacter.FishClass.SCORCHER: "Wake",
	FishCharacter.FishClass.DRIFTER: "Many Arms",
	FishCharacter.FishClass.BRAWLER: "Heavy Hitter",
	FishCharacter.FishClass.BREACHER: "Escort",
	FishCharacter.FishClass.ALCHEMIST: "Unpalatable",
}
## Mobility skill titles.
const SKILLS := {
	FishCharacter.FishClass.SKIRMISHER: "Wriggle",
	FishCharacter.FishClass.HUNTER: "Fin Dash",
	FishCharacter.FishClass.GLIDER: "Surge",
	FishCharacter.FishClass.LANCER: "Dash",
	FishCharacter.FishClass.CHARMER: "Leap",
	FishCharacter.FishClass.BULWARK: "Brace",
	FishCharacter.FishClass.SCORCHER: "Flare Dash",
	FishCharacter.FishClass.DRIFTER: "Go Quiet",
	FishCharacter.FishClass.BRAWLER: "Recoil Dash",
	FishCharacter.FishClass.BREACHER: "Gulp",
	FishCharacter.FishClass.ALCHEMIST: "Flutter",
}
## A leap splashes once its climb has slowed to this share of its push, or after LEAP_MAX s.
const LEAP_TOP := 0.35
const LEAP_MAX := 1.2
const FIN_COLOR := Color(0.55, 0.75, 0.85)

## Null away from a run.
var run: UnnaturalRun
var fish: FishController
var settings: UnnaturalSettings
## Where the skills' effects go: the run, else the node given.
var host: Node
## The Shark's frenzy now (a share of swim speed), and how long it's held still.
var frenzy := 0.0
var frenzy_held := 0.0
## Skills used, for the probes: dashes (Swordfish), leaps and their splashes,
## recoils, wriggles, surges, braces, gulps, flares, fin dashes and quiets;
## Heavy Hitter's flings and the zombies they hit.
var dashes := 0
var leaps := 0
var splashes := 0
var recoils := 0
var flings := 0
var fling_hits := 0
var wriggles := 0
var surges := 0
var braces := 0
var gulps := 0
var flares := 0
var fin_dashes := 0
var quiets := 0
var flutters := 0
var flaps := 0
var coats := 0
## The Moon Jelly's stink is off: nothing fires, and zombies can't find it.
var quiet := false

var _cool := 0.0
var _cool_total := 1.0
var _leap_age := -1.0
var _dash_left := 0.0
var _dash_heading := Vector3.FORWARD
var _dash_hit := {}
var _dash_kind := ""
var _dash_loop := 0
var _surge_left := 0.0
var _brace_left := 0.0
var _quiet_left := 0.0
var _recoil_left := 0.0
var _recoil_heading := Vector3.BACK
## Heavy Hitter's missiles: {index, left, damage, hits, hit (index -> true)}.
var _flings: Array[Dictionary] = []
## The Recoil Dash's punch when the fish has no Cavitation Punch of its own
## (the panel's fish_attack gave it another).
var _spare_punch: CavitationPunch
## Flutter's flaps still to come, and seconds to the next.
var _flaps_left := 0
var _flap_wait := 0.0
## Flutter's cloud when the fish has no Purple Haze of its own (likewise).
var _spare_haze: PurpleHaze
## Unpalatable: coated zombies (index -> when the coat wears off, on _clock).
var _coated := {}
var _clock := 0.0


func _init(owner: UnnaturalRun, of: FishController, effects_in: Node = null) -> void:
	run = owner
	fish = of
	settings = owner.settings if owner else UnnaturalSettings.shared()
	host = owner if owner else effects_in


## Gives the fish its own swimming back.
func clear() -> void:
	if is_instance_valid(fish):
		fish.turn_scale = 1.0
		fish.drag_scale = 1.0
	reset()
	if is_instance_valid(_spare_punch):
		_spare_punch.queue_free()
	_spare_punch = null
	if is_instance_valid(_spare_haze):
		_spare_haze.queue_free()
	_spare_haze = null


func reset() -> void:
	frenzy = 0.0
	frenzy_held = 0.0
	quiet = false
	_cool = 0.0
	_leap_age = -1.0
	_dash_left = 0.0
	_surge_left = 0.0
	_brace_left = 0.0
	_quiet_left = 0.0
	_recoil_left = 0.0
	_flings.clear()
	_flaps_left = 0
	_coated.clear()
	_stop_loop()


func fish_class() -> FishCharacter.FishClass:
	return fish.character


## Whether `twist`'s fish is this one, with twists on.
func is_on(twist: FishCharacter.FishClass) -> bool:
	return settings.twists and fish_class() == twist


static func title(of: FishCharacter.FishClass) -> String:
	return NAMES.get(of, "")


static func skill_title(of: FishCharacter.FishClass) -> String:
	return SKILLS.get(of, "")


## A multiplier on swim speed: the frenzy, or the Boxfish's armour (and brace).
func speed_factor() -> float:
	if is_on(FishCharacter.FishClass.HUNTER):
		return 1.0 + frenzy
	if is_on(FishCharacter.FishClass.BULWARK):
		return settings.armour_speed * (settings.brace_speed if _brace_left > 0.0 else 1.0)
	if is_on(FishCharacter.FishClass.LANCER):
		return 1.0 + settings.streamline_speed
	return 1.0


## A multiplier on damage taken.
func taken_factor() -> float:
	if is_on(FishCharacter.FishClass.BULWARK):
		return settings.armour_taken * (settings.brace_taken if _brace_left > 0.0 else 1.0)
	return 1.0


## A multiplier on `source`'s damage from the twist: the Lionfish's wake
## burns harder the faster it swims.
func damage_factor(source: String) -> float:
	if source == "greek_fire" and is_on(FishCharacter.FishClass.SCORCHER) and settings.wake_damage > 0.0:
		var top := maxf(fish.nature_batter_speed, 0.1)
		return 1.0 + settings.wake_damage * clampf(fish.speed / top, 0.0, 1.0)
	return 1.0


## How many more jellies the Moon Jelly's Halo has.
func halo_bonus() -> int:
	return settings.arms_extra if is_on(FishCharacter.FishClass.DRIFTER) else 0


func update(delta: float) -> void:
	fish.turn_scale = settings.nimble_turn if is_on(FishCharacter.FishClass.SKIRMISHER) else 1.0
	_surge_left = maxf(_surge_left - delta, 0.0)
	_brace_left = maxf(_brace_left - delta, 0.0)
	fish.drag_scale = 0.0 if _surge_left > 0.0 or _recoil_left > 0.0 else (settings.glide_drag if is_on(FishCharacter.FishClass.GLIDER) else 1.0)
	if run and is_on(FishCharacter.FishClass.BREACHER) and settings.escort_regen > 0.0 and fish.speed <= settings.chest_still_speed:
		var health := run.health_of(fish)
		if health and not health.down:
			health.heal(settings.escort_regen * delta)
	if frenzy > 0.0:
		frenzy_held -= delta
		if frenzy_held <= 0.0:
			frenzy = maxf(frenzy - settings.frenzy_max * delta / maxf(settings.frenzy_time, 0.25), 0.0)
	_cool = maxf(_cool - delta, 0.0)
	if quiet:
		_quiet_left -= delta
		if _quiet_left <= 0.0:
			_end_quiet()
	if _dash_left > 0.0:
		_dash_left -= delta
		_dash_step()
		if _dash_left <= 0.0:
			_stop_loop()
	if _recoil_left > 0.0:
		_recoil_left -= delta  # no drag meanwhile (above): the throw carries
	if not _flings.is_empty():
		_fling_step(delta)
	_clock += delta
	_tick_spare(delta)
	if run and is_on(FishCharacter.FishClass.ALCHEMIST):
		_coat_touching()
	if _flaps_left > 0:
		_flap_wait -= delta
		if _flap_wait <= 0.0:
			_flap()
	if _leap_age >= 0.0:
		_leap_age += delta
		var climb := fish.linear_velocity.y
		if _leap_age >= LEAP_MAX or (_leap_age > 0.15 and climb <= settings.leap_impulse * LEAP_TOP):
			_splash()
	if not fish.puppet and fish.controls == null and settings.twists and fish._player_input().just_pressed("boost"):
		mobility()


## The mobility skill's button was pressed: use it, if it's ready. Whether it went off.
func mobility() -> bool:
	if not settings.twists or (run and (not run.is_up(fish) or run.is_picking(fish))):
		return false
	if quiet:
		_end_quiet()  # pressing again brings the stink back
		return true
	if _cool > 0.0 or _dash_left > 0.0:
		return false
	var nose := -fish.global_basis.z
	match fish_class():
		FishCharacter.FishClass.HUNTER:
			_start_dash("fin", settings.fin_dash_time, settings.fin_dash_speed, settings.fin_cooldown, nose)
			fin_dashes += 1
		FishCharacter.FishClass.SCORCHER:
			_start_dash("flare", settings.flare_time, settings.flare_speed, settings.flare_cooldown, nose)
			flares += 1
			Explosion.spawn(run.ocean if run else host, fish.global_position, Color(1.0, 0.5, 0.2), settings.flare_radius, 0.0, 0.3)
		FishCharacter.FishClass.LANCER:
			if settings.dash_speed <= 0.0:
				return false
			dashes += 1
			_cool_for(settings.dash_cooldown)
			fish.apply_push(nose * settings.dash_speed)
			_shield(settings.dash_iframes)
		FishCharacter.FishClass.SKIRMISHER:
			wriggles += 1
			_cool_for(settings.wriggle_cooldown)
			var lean := fish._player_input().strength("stick_right") - fish._player_input().strength("stick_left")
			var side := fish.global_basis.x * signf(lean) if absf(lean) > 0.25 else nose.rotated(Vector3.UP, PI)
			fish.apply_push(side * settings.wriggle_speed)
			_shield(settings.wriggle_iframes)
			PowerupFx.ring(host, fish.global_position, 1.2, Color(1.0, 0.6, 0.2), side, 0.25)
		FishCharacter.FishClass.GLIDER:
			surges += 1
			_cool_for(settings.surge_cooldown)
			_surge_left = settings.surge_time
			fish.apply_push(nose * settings.surge_speed)
			PowerupFx.ring(host, fish.global_position, 1.6, Color(0.7, 0.85, 1.0), nose, 0.3)
		FishCharacter.FishClass.BULWARK:
			braces += 1
			_cool_for(settings.brace_cooldown)
			_brace_left = settings.brace_time
			PowerupFx.ring(host, fish.global_position, 1.8, Color(1.0, 0.85, 0.2), nose, 0.3)
		FishCharacter.FishClass.CHARMER:
			if settings.leap_impulse <= 0.0 or _leap_age >= 0.0:
				return false
			leaps += 1
			_leap_age = 0.0
			_cool_for(settings.leap_cooldown)
			fish.apply_push(Vector3.UP * settings.leap_impulse)
		FishCharacter.FishClass.BRAWLER:
			_recoil()
		FishCharacter.FishClass.BREACHER:
			_gulp(nose)
		FishCharacter.FishClass.ALCHEMIST:
			_flutter()
		FishCharacter.FishClass.DRIFTER:
			quiets += 1
			quiet = true
			_quiet_left = settings.quiet_time
			PowerupFx.ring(host, fish.global_position, 2.0, Color(0.8, 0.7, 1.0), Vector3.UP, 0.5)
		_:
			return false
	return true


## How the skill's doing, for the HUD: its title, whether it's on now, and
## seconds until it's ready again (0: ready).
func skill_title_now() -> String:
	return skill_title(fish_class())


func skill_active() -> bool:
	return quiet or _dash_left > 0.0 or _brace_left > 0.0 or _surge_left > 0.0 or _leap_age >= 0.0 or _recoil_left > 0.0 \
			or _flaps_left > 0


func skill_wait() -> float:
	return _cool


## 0..1: how far through its cooldown.
func skill_fill() -> float:
	return 1.0 - clampf(_cool / maxf(_cool_total, 0.01), 0.0, 1.0)


## `fish` killed a zombie.
func on_kill() -> void:
	if not is_on(FishCharacter.FishClass.HUNTER):
		return
	frenzy = minf(frenzy + settings.frenzy_per_kill, settings.frenzy_max)
	frenzy_held = settings.frenzy_time


## `fish` took a hit: the Jelly's quiet ends.
func on_hurt() -> void:
	if quiet:
		_end_quiet()


func _cool_for(seconds: float) -> void:
	_cool = seconds
	_cool_total = seconds


func _shield(seconds: float) -> void:
	if run == null:
		return
	var health := run.health_of(fish)
	if health and seconds > 0.0:
		health.shield(seconds)


func _end_quiet() -> void:
	quiet = false
	_cool_for(settings.quiet_cooldown)
	PowerupFx.ring(host, fish.global_position, 1.4, Color(0.8, 0.7, 1.0), Vector3.UP, 0.3)


## A charge: `speed` along `heading` for `time` s, untouchable, hurting what it passes.
func _start_dash(kind: String, time: float, speed: float, cooldown: float, heading: Vector3) -> void:
	_dash_kind = kind
	_dash_left = time
	_dash_hit.clear()
	_dash_heading = heading
	_cool_for(cooldown)
	fish.apply_push(heading * maxf(speed - fish.linear_velocity.dot(heading), 0.0))
	_shield(time + 0.1)
	PowerupFx.ring(host, fish.global_position, 1.5, FIN_COLOR if kind == "fin" else Color(1.0, 0.5, 0.2), heading, 0.3)
	_stop_loop()
	Sfx.play_at("pw/drowned_fin_dash", fish.global_position)
	_dash_loop = Sfx.start_loop("pw/drowned_fin_charge_loop")


func _stop_loop() -> void:
	if _dash_loop != 0:
		Sfx.stop_loop(_dash_loop)
		_dash_loop = 0


func _dash_step() -> void:
	if run == null:
		return
	var radius := settings.fin_radius if _dash_kind == "fin" else settings.flare_radius
	var damage := settings.fin_damage if _dash_kind == "fin" else settings.flare_damage
	var source := "fin_dash" if _dash_kind == "fin" else "flare"
	for i in run.horde.query_sphere(fish.global_position, radius):
		if _dash_hit.has(i):
			continue
		_dash_hit[i] = true
		run.hit(i, damage, fish, source, _dash_heading)


func _splash() -> void:
	_leap_age = -1.0
	if settings.leap_damage <= 0.0 or settings.leap_radius <= 0.0:
		return
	splashes += 1
	var at := fish.global_position
	Explosion.spawn(run.ocean if run else host, at, Color(0.7, 0.95, 1.0), settings.leap_radius, 0.0, 0.3)
	if run == null:
		return
	for i in run.horde.query_sphere(at, settings.leap_radius):
		var away := run.horde.enemy_position(i) - at
		run.hit(i, settings.leap_damage, fish, "splash", away.normalized() if away.length_squared() > 0.0001 else Vector3.UP)


## The Mantis Shrimp's Recoil Dash: a full punch one way, thrown the other.
func _recoil() -> void:
	recoils += 1
	_cool_for(settings.recoil_cooldown)
	_recoil_heading = recoil_heading()
	_recoil_left = settings.recoil_time
	_shield(settings.recoil_iframes)
	var punch := punch_for_recoil()
	if punch:
		punch.punch(-_recoil_heading)
	var short := settings.recoil_speed - fish.linear_velocity.dot(_recoil_heading)
	if short > 0.0:
		fish.apply_push(_recoil_heading * short)
	PowerupFx.ring(host, fish.global_position, 1.4, CavitationPunch.BUBBLE_COLOR, _recoil_heading, 0.25)


## The way the Recoil Dash throws the fish (unit): the way the stick leans
## (right / left, and up / down as it pitches), else backwards.
func recoil_heading() -> Vector3:
	var input := fish._player_input()
	var lean := Vector2(input.strength("stick_right") - input.strength("stick_left"),
			input.strength("stick_down") - input.strength("stick_up"))
	if lean.length() < 0.25:
		return fish.global_basis.z
	return (fish.global_basis.x * lean.x + fish.global_basis.y * lean.y).normalized()


## The punch the Recoil Dash throws: the fish's own Cavitation Punch, else a
## second one it holds, else a spare at its stats (the panel gave it another attack).
func punch_for_recoil() -> CavitationPunch:
	if run == null:
		return null
	var own := run.attack_of(fish) as CavitationPunch
	if own:
		return own
	var powerups := run.powerups_of(fish)
	var held: CavitationPunch = powerups.weapon("attack_punch") as CavitationPunch if powerups else null
	if held:
		return held
	if not is_instance_valid(_spare_punch):
		_spare_punch = FishAttack.make(FishAttack.Kind.PUNCH) as CavitationPunch
		_spare_punch.fish = fish
		_spare_punch.horde = run.horde
		_spare_punch.settings = settings
		_spare_punch.run = run
		_spare_punch.powers = run.powerup_settings
		_spare_punch.on_hit = run.hit
		run.add_child(_spare_punch)
	_spare_punch.configure(run.block_of(fish), {}, 1)
	return _spare_punch


## Heavy Hitter: zombie `index`, just punched for `amount`, flies as a missile
## for heavy_time s, hurting the zombies it hits.
func fling(index: int, amount: float) -> void:
	if not is_on(FishCharacter.FishClass.BRAWLER) or settings.heavy_share <= 0.0 or settings.heavy_max <= 0:
		return
	if not run.horde.is_alive(index) or run.horde.is_proxy(index):
		return
	for f in _flings:
		if f.index == index:
			f.left = settings.heavy_time
			f.damage = maxf(f.damage, amount)
			return
	if _flings.size() >= settings.heavy_flings:
		_flings.pop_front()
	flings += 1
	_flings.append({"index": index, "left": settings.heavy_time, "damage": amount, "hits": 0, "hit": {index: true}})


## Whether zombie `index` is one of Heavy Hitter's missiles now.
func is_flung(index: int) -> bool:
	for f in _flings:
		if f.index == index:
			return true
	return false


func _fling_step(delta: float) -> void:
	var horde := run.horde
	var n := 0
	while n < _flings.size():
		var f := _flings[n]
		f.left -= delta
		var index: int = f.index
		if f.left <= 0.0 or not horde.is_alive(index) or f.hits >= settings.heavy_max:
			_flings.remove_at(n)
			continue
		n += 1
		var flying := horde.enemy_velocity(index)
		if flying.length_squared() < 1.0:
			continue
		var at := horde.enemy_position(index)
		for j in horde.query_sphere(at, horde.enemy_radius(index)):
			if f.hit.has(j):
				continue
			f.hit[j] = true
			f.hits += 1
			fling_hits += 1
			run.hit(j, f.damage * settings.heavy_share, fish, "heavy_hitter", flying.normalized(), 0.3)
			if f.hits >= settings.heavy_max:
				break


## The Breachers (baby whales): every zombie in the cone ahead is sucked in to its mouth.
func _gulp(nose: Vector3) -> void:
	gulps += 1
	_cool_for(settings.gulp_cooldown)
	var mouth := fish.global_position + nose * 1.2
	PowerupFx.ring(host, mouth + nose * settings.gulp_range * 0.5, settings.gulp_range * 0.5, Color(0.5, 0.75, 0.95), -nose, 0.35)
	if run == null:
		return
	for i in run.horde.query_sphere(fish.global_position, settings.gulp_range):
		var offset := run.horde.enemy_position(i) - fish.global_position
		if offset.length_squared() < 0.0001 or offset.normalized().dot(nose) < 0.5:
			continue
		var pull := (mouth - run.horde.enemy_position(i)).normalized() * settings.gulp_pull
		run.hit(i, settings.gulp_damage, fish, "gulp", pull, 0.5)


## Unpalatable: every zombie touching the sea hare is coated, slowed
## coat_slow for coat_time s, and takes coat_bonus more from Purple Haze meanwhile.
func _coat_touching() -> void:
	if settings.coat_time <= 0.0:
		return
	for i in run.horde.query_sphere(fish.global_position, UnnaturalRun.PLAYER_RADIUS):
		if not _coated.has(i) or _coated[i] < _clock:
			coats += 1
		_coated[i] = _clock + settings.coat_time
		run.horde.slow(i, settings.coat_slow, settings.coat_time)
	if _coated.size() > 256:  # forget the worn-off ones now and then
		for i: int in _coated.keys():
			if _coated[i] < _clock:
				_coated.erase(i)


## Whether zombie `index` wears Unpalatable's coat now (Purple Haze hurts it more).
func is_coated(index: int) -> bool:
	return is_on(FishCharacter.FishClass.ALCHEMIST) and _coated.get(index, -1.0) >= _clock and run.horde.is_alive(index)


## The Sea Hare's Flutter: flutter_flaps big flaps up and forward, one every
## flutter_gap s, and a Purple Haze cloud where it took off.
func _flutter() -> void:
	flutters += 1
	_cool_for(settings.flutter_cooldown)
	_flaps_left = maxi(settings.flutter_flaps, 1)
	_flap()
	var haze := haze_for_flutter()
	if haze:
		haze.open_cloud(fish.global_position, haze.radius(), haze.life())


## One of Flutter's flaps: a push up and along the nose (flutter_lift of it up).
func _flap() -> void:
	flaps += 1
	_flaps_left -= 1
	_flap_wait = settings.flutter_gap
	var nose := -fish.global_basis.z
	var flat := Vector3(nose.x, 0.0, nose.z)
	var ahead := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var heading := (ahead * (1.0 - settings.flutter_lift) + Vector3.UP * settings.flutter_lift).normalized()
	fish.apply_push(heading * settings.flutter_speed)
	PowerupFx.ring(host, fish.global_position, 1.3, PurpleHaze.COLOR, Vector3.UP, 0.25)


## The Purple Haze Flutter drops its cloud with: the fish's own, else one it
## holds, else a spare at its stats (the panel gave it another attack).
func haze_for_flutter() -> PurpleHaze:
	if run == null:
		return null
	var own := run.attack_of(fish) as PurpleHaze
	if own:
		return own
	var powerups := run.powerups_of(fish)
	var held: PurpleHaze = powerups.weapon("attack_purple_haze") as PurpleHaze if powerups else null
	if held:
		return held
	if not is_instance_valid(_spare_haze):
		_spare_haze = FishAttack.make(FishAttack.Kind.HAZE) as PurpleHaze
		_spare_haze.fish = fish
		_spare_haze.horde = run.horde
		_spare_haze.settings = settings
		_spare_haze.run = run
		_spare_haze.powers = run.powerup_settings
		_spare_haze.on_hit = run.hit
		run.add_child(_spare_haze)
	_spare_haze.configure(run.block_of(fish), {}, 1)
	return _spare_haze


## Ticks the spare haze's clouds (it isn't the fish's attack, so nothing else does).
func _tick_spare(delta: float) -> void:
	if is_instance_valid(_spare_haze) and not _spare_haze.clouds.is_empty():
		_spare_haze._tick_clouds(delta)


## More i-frames after a hit (s): the Koi's grace.
func iframe_bonus() -> float:
	return settings.graceful_iframes if is_on(FishCharacter.FishClass.CHARMER) else 0.0
