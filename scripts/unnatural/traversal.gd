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
## - Baby Whale Shark, Escort: heals while it holds still.
## - Mantis Shrimp, Hammer: its mobility's shockwave (below).
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
## - Mantis Shrimp, Snap: lunges ahead and cracks a shockwave.
## - Baby Whale Shark, Gulp: sucks the zombies ahead of it in.
## UnnaturalRun owns one per local player and calls update() every tick.

## Passive twist titles.
const NAMES := {
	FishCharacter.Family.OCTANE: "Nimble",
	FishCharacter.Family.DOMINUS: "Frenzy",
	FishCharacter.Family.PLANK: "Glide",
	FishCharacter.Family.BREAKOUT: "Streamlined",
	FishCharacter.Family.HYBRID: "Graceful",
	FishCharacter.Family.MERC: "Armoured",
	FishCharacter.Family.LIONFISH: "Wake",
	FishCharacter.Family.MOON_JELLY: "Many Arms",
	FishCharacter.Family.MANTIS: "Hammer",
	FishCharacter.Family.WHALE_SHARK: "Escort",
}
## Mobility skill titles.
const SKILLS := {
	FishCharacter.Family.OCTANE: "Wriggle",
	FishCharacter.Family.DOMINUS: "Fin Dash",
	FishCharacter.Family.PLANK: "Surge",
	FishCharacter.Family.BREAKOUT: "Dash",
	FishCharacter.Family.HYBRID: "Leap",
	FishCharacter.Family.MERC: "Brace",
	FishCharacter.Family.LIONFISH: "Flare Dash",
	FishCharacter.Family.MOON_JELLY: "Go Quiet",
	FishCharacter.Family.MANTIS: "Snap",
	FishCharacter.Family.WHALE_SHARK: "Gulp",
}
## A leap splashes once its climb has slowed to this share of its push, or after LEAP_MAX s.
const LEAP_TOP := 0.35
const LEAP_MAX := 1.2
const FIN_COLOR := Color(0.55, 0.75, 0.85)

var run: UnnaturalRun
var fish: FishController
var settings: UnnaturalSettings
## The Shark's frenzy now (a share of swim speed), and how long it's held still.
var frenzy := 0.0
var frenzy_held := 0.0
## Skills used, for the probes: dashes (Swordfish), leaps and their splashes,
## snaps, wriggles, surges, braces, gulps, flares, fin dashes and quiets.
var dashes := 0
var leaps := 0
var splashes := 0
var snaps := 0
var wriggles := 0
var surges := 0
var braces := 0
var gulps := 0
var flares := 0
var fin_dashes := 0
var quiets := 0
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


func _init(owner: UnnaturalRun, of: FishController) -> void:
	run = owner
	fish = of
	settings = owner.settings


## Gives the fish its own swimming back.
func clear() -> void:
	if is_instance_valid(fish):
		fish.turn_scale = 1.0
		fish.drag_scale = 1.0
	reset()


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
	_stop_loop()


func family() -> FishCharacter.Family:
	return fish.character


## Whether `twist`'s fish is this one, with twists on.
func is_on(twist: FishCharacter.Family) -> bool:
	return settings.twists and family() == twist


static func title(of: FishCharacter.Family) -> String:
	return NAMES.get(of, "")


static func skill_title(of: FishCharacter.Family) -> String:
	return SKILLS.get(of, "")


## A multiplier on swim speed: the frenzy, or the Boxfish's armour (and brace).
func speed_factor() -> float:
	if is_on(FishCharacter.Family.DOMINUS):
		return 1.0 + frenzy
	if is_on(FishCharacter.Family.MERC):
		return settings.armour_speed * (settings.brace_speed if _brace_left > 0.0 else 1.0)
	if is_on(FishCharacter.Family.BREAKOUT):
		return 1.0 + settings.streamline_speed
	return 1.0


## A multiplier on damage taken.
func taken_factor() -> float:
	if is_on(FishCharacter.Family.MERC):
		return settings.armour_taken * (settings.brace_taken if _brace_left > 0.0 else 1.0)
	return 1.0


## A multiplier on `source`'s damage from the twist: the Lionfish's wake
## burns harder the faster it swims.
func damage_factor(source: String) -> float:
	if source == "greek_fire" and is_on(FishCharacter.Family.LIONFISH) and settings.wake_damage > 0.0:
		var top := maxf(fish.nature_batter_speed, 0.1)
		return 1.0 + settings.wake_damage * clampf(fish.speed / top, 0.0, 1.0)
	return 1.0


## How many more jellies the Moon Jelly's Halo has.
func halo_bonus() -> int:
	return settings.arms_extra if is_on(FishCharacter.Family.MOON_JELLY) else 0


func update(delta: float) -> void:
	fish.turn_scale = settings.nimble_turn if is_on(FishCharacter.Family.OCTANE) else 1.0
	_surge_left = maxf(_surge_left - delta, 0.0)
	_brace_left = maxf(_brace_left - delta, 0.0)
	fish.drag_scale = 0.0 if _surge_left > 0.0 else (settings.glide_drag if is_on(FishCharacter.Family.PLANK) else 1.0)
	if is_on(FishCharacter.Family.WHALE_SHARK) and settings.escort_regen > 0.0 and fish.speed <= settings.chest_still_speed:
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
	if _leap_age >= 0.0:
		_leap_age += delta
		var climb := fish.linear_velocity.y
		if _leap_age >= LEAP_MAX or (_leap_age > 0.15 and climb <= settings.leap_impulse * LEAP_TOP):
			_splash()
	if not fish.puppet and fish.controls == null and settings.twists and fish._player_input().just_pressed("boost"):
		mobility()


## The mobility skill's button was pressed: use it, if it's ready. Whether it went off.
func mobility() -> bool:
	if not settings.twists or not run.is_up(fish) or run.is_picking(fish):
		return false
	if quiet:
		_end_quiet()  # pressing again brings the stink back
		return true
	if _cool > 0.0 or _dash_left > 0.0:
		return false
	var nose := -fish.global_basis.z
	match family():
		FishCharacter.Family.DOMINUS:
			_start_dash("fin", settings.fin_dash_time, settings.fin_dash_speed, settings.fin_cooldown, nose)
			fin_dashes += 1
		FishCharacter.Family.LIONFISH:
			_start_dash("flare", settings.flare_time, settings.flare_speed, settings.flare_cooldown, nose)
			flares += 1
			Explosion.spawn(run.ocean, fish.global_position, Color(1.0, 0.5, 0.2), settings.flare_radius, 0.0, 0.3)
		FishCharacter.Family.BREAKOUT:
			if settings.dash_speed <= 0.0:
				return false
			dashes += 1
			_cool_for(settings.dash_cooldown)
			fish.apply_push(nose * settings.dash_speed)
			_shield(settings.dash_iframes)
		FishCharacter.Family.OCTANE:
			wriggles += 1
			_cool_for(settings.wriggle_cooldown)
			var lean := fish._player_input().strength("stick_right") - fish._player_input().strength("stick_left")
			var side := fish.global_basis.x * signf(lean) if absf(lean) > 0.25 else nose.rotated(Vector3.UP, PI)
			fish.apply_push(side * settings.wriggle_speed)
			_shield(settings.wriggle_iframes)
			PowerupFx.ring(run, fish.global_position, 1.2, Color(1.0, 0.6, 0.2), side, 0.25)
		FishCharacter.Family.PLANK:
			surges += 1
			_cool_for(settings.surge_cooldown)
			_surge_left = settings.surge_time
			fish.apply_push(nose * settings.surge_speed)
			PowerupFx.ring(run, fish.global_position, 1.6, Color(0.7, 0.85, 1.0), nose, 0.3)
		FishCharacter.Family.MERC:
			braces += 1
			_cool_for(settings.brace_cooldown)
			_brace_left = settings.brace_time
			PowerupFx.ring(run, fish.global_position, 1.8, Color(1.0, 0.85, 0.2), nose, 0.3)
		FishCharacter.Family.HYBRID:
			if settings.leap_impulse <= 0.0 or _leap_age >= 0.0:
				return false
			leaps += 1
			_leap_age = 0.0
			_cool_for(settings.leap_cooldown)
			fish.apply_push(Vector3.UP * settings.leap_impulse)
		FishCharacter.Family.MANTIS:
			if settings.snap_damage <= 0.0 and settings.snap_speed <= 0.0:
				return false
			_snap(nose)
		FishCharacter.Family.WHALE_SHARK:
			_gulp(nose)
		FishCharacter.Family.MOON_JELLY:
			quiets += 1
			quiet = true
			_quiet_left = settings.quiet_time
			PowerupFx.ring(run, fish.global_position, 2.0, Color(0.8, 0.7, 1.0), Vector3.UP, 0.5)
		_:
			return false
	return true


## How the skill's doing, for the HUD: its title, whether it's on now, and
## seconds until it's ready again (0: ready).
func skill_title_now() -> String:
	return skill_title(family())


func skill_active() -> bool:
	return quiet or _dash_left > 0.0 or _brace_left > 0.0 or _surge_left > 0.0 or _leap_age >= 0.0


func skill_wait() -> float:
	return _cool


## 0..1: how far through its cooldown.
func skill_fill() -> float:
	return 1.0 - clampf(_cool / maxf(_cool_total, 0.01), 0.0, 1.0)


## `fish` killed a zombie.
func on_kill() -> void:
	if not is_on(FishCharacter.Family.DOMINUS):
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
	var health := run.health_of(fish)
	if health and seconds > 0.0:
		health.shield(seconds)


func _end_quiet() -> void:
	quiet = false
	_cool_for(settings.quiet_cooldown)
	PowerupFx.ring(run, fish.global_position, 1.4, Color(0.8, 0.7, 1.0), Vector3.UP, 0.3)


## A charge: `speed` along `heading` for `time` s, untouchable, hurting what it passes.
func _start_dash(kind: String, time: float, speed: float, cooldown: float, heading: Vector3) -> void:
	_dash_kind = kind
	_dash_left = time
	_dash_hit.clear()
	_dash_heading = heading
	_cool_for(cooldown)
	fish.apply_push(heading * maxf(speed - fish.linear_velocity.dot(heading), 0.0))
	_shield(time + 0.1)
	PowerupFx.ring(run, fish.global_position, 1.5, FIN_COLOR if kind == "fin" else Color(1.0, 0.5, 0.2), heading, 0.3)
	_stop_loop()
	Sfx.play_at("pw/drowned_fin_dash", fish.global_position)
	_dash_loop = Sfx.start_loop("pw/drowned_fin_charge_loop")


func _stop_loop() -> void:
	if _dash_loop != 0:
		Sfx.stop_loop(_dash_loop)
		_dash_loop = 0


func _dash_step() -> void:
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
	Explosion.spawn(run.ocean, at, Color(0.7, 0.95, 1.0), settings.leap_radius, 0.0, 0.3)
	for i in run.horde.query_sphere(at, settings.leap_radius):
		var away := run.horde.enemy_position(i) - at
		run.hit(i, settings.leap_damage, fish, "splash", away.normalized() if away.length_squared() > 0.0001 else Vector3.UP)


## The Mantis Shrimp: lunges along its nose, cracking a shockwave where it was.
func _snap(nose: Vector3) -> void:
	snaps += 1
	_cool_for(settings.snap_cooldown)
	var at := fish.global_position
	fish.apply_push(nose * settings.snap_speed)
	Explosion.spawn(run.ocean, at, Color(1.0, 0.6, 0.2), settings.snap_radius, 0.0, 0.25)
	for i in run.horde.query_sphere(at, settings.snap_radius):
		var away := run.horde.enemy_position(i) - at
		run.hit(i, settings.snap_damage, fish, "snap", away.normalized() if away.length_squared() > 0.0001 else Vector3.UP)


## The Baby Whale Shark: every zombie in the cone ahead is sucked in to its mouth.
func _gulp(nose: Vector3) -> void:
	gulps += 1
	_cool_for(settings.gulp_cooldown)
	var mouth := fish.global_position + nose * 1.2
	PowerupFx.ring(run, mouth + nose * settings.gulp_range * 0.5, settings.gulp_range * 0.5, Color(0.5, 0.75, 0.95), -nose, 0.35)
	for i in run.horde.query_sphere(fish.global_position, settings.gulp_range):
		var offset := run.horde.enemy_position(i) - fish.global_position
		if offset.length_squared() < 0.0001 or offset.normalized().dot(nose) < 0.5:
			continue
		var pull := (mouth - run.horde.enemy_position(i)).normalized() * settings.gulp_pull
		run.hit(i, settings.gulp_damage, fish, "gulp", pull, 0.5)


## More i-frames after a hit (s): the Koi's grace.
func iframe_bonus() -> float:
	return settings.graceful_iframes if is_on(FishCharacter.Family.HYBRID) else 0.0
