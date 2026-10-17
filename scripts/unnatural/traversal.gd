class_name Traversal
extends RefCounted
## Each fish's traversal twist in Unnatural (planning_unnatural.md §5), the
## second half of every fish being unique (settings' Twists group):
## - Clownfish, Nimble: sharper turns (FishController.turn_scale).
## - Shark, Frenzy: faster after each kill, held a while, then fading.
## - String Ray, Glide: coasts without losing speed (FishController.drag_scale).
## - Swordfish, Dash: a dodge bursts on along it, untouchable for a moment.
## - Butterfly Koi, Leap: a jump also leaps up, and splashes down as it tops
##   out, hurting the zombies round it.
## - Boxfish, Armoured: takes less damage, swims slower.
## UnnaturalRun owns one per local player and calls update() every tick.

const NAMES := {
	FishCharacter.Family.OCTANE: "Nimble",
	FishCharacter.Family.DOMINUS: "Frenzy",
	FishCharacter.Family.PLANK: "Glide",
	FishCharacter.Family.BREAKOUT: "Dash",
	FishCharacter.Family.HYBRID: "Leap",
	FishCharacter.Family.MERC: "Armoured",
}
## A leap splashes once its climb has slowed to this share of its push, or after LEAP_MAX s.
const LEAP_TOP := 0.35
const LEAP_MAX := 1.2

var run: UnnaturalRun
var fish: FishController
var settings: UnnaturalSettings
## The Shark's frenzy now (a share of swim speed), and how long it's held still.
var frenzy := 0.0
var frenzy_held := 0.0
## Dashes, leaps and splashes so far, for the probes.
var dashes := 0
var leaps := 0
var splashes := 0

var _leap_age := -1.0
var _leap_left := 0.0
var _on_dodged: Callable
var _on_jumped: Callable


func _init(owner: UnnaturalRun, of: FishController) -> void:
	run = owner
	fish = of
	settings = owner.settings
	_on_dodged = func(direction: Vector3) -> void: _dash(direction)
	_on_jumped = func() -> void: _leap()
	fish.dodged.connect(_on_dodged)
	fish.jumped.connect(_on_jumped)


## Unhooks from the fish and gives it its own swimming back.
func clear() -> void:
	if is_instance_valid(fish):
		if fish.dodged.is_connected(_on_dodged):
			fish.dodged.disconnect(_on_dodged)
		if fish.jumped.is_connected(_on_jumped):
			fish.jumped.disconnect(_on_jumped)
		fish.turn_scale = 1.0
		fish.drag_scale = 1.0
	reset()


func reset() -> void:
	frenzy = 0.0
	frenzy_held = 0.0
	_leap_age = -1.0
	_leap_left = 0.0


func family() -> FishCharacter.Family:
	return fish.character


## Whether `twist`'s fish is this one, with twists on.
func is_on(twist: FishCharacter.Family) -> bool:
	return settings.twists and family() == twist


static func title(of: FishCharacter.Family) -> String:
	return NAMES.get(of, "")


## A multiplier on swim speed: the frenzy, or the Boxfish's armour.
func speed_factor() -> float:
	if is_on(FishCharacter.Family.DOMINUS):
		return 1.0 + frenzy
	if is_on(FishCharacter.Family.MERC):
		return settings.armour_speed
	return 1.0


## A multiplier on damage taken.
func taken_factor() -> float:
	return settings.armour_taken if is_on(FishCharacter.Family.MERC) else 1.0


func update(delta: float) -> void:
	fish.turn_scale = settings.nimble_turn if is_on(FishCharacter.Family.OCTANE) else 1.0
	fish.drag_scale = settings.glide_drag if is_on(FishCharacter.Family.PLANK) else 1.0
	if frenzy > 0.0:
		frenzy_held -= delta
		if frenzy_held <= 0.0:
			frenzy = maxf(frenzy - settings.frenzy_max * delta / maxf(settings.frenzy_time, 0.25), 0.0)
	_leap_left = maxf(_leap_left - delta, 0.0)
	if _leap_age >= 0.0:
		_leap_age += delta
		var climb := fish.linear_velocity.y
		if _leap_age >= LEAP_MAX or (_leap_age > 0.15 and climb <= settings.leap_impulse * LEAP_TOP):
			_splash()


## `fish` killed a zombie.
func on_kill() -> void:
	if not is_on(FishCharacter.Family.DOMINUS):
		return
	frenzy = minf(frenzy + settings.frenzy_per_kill, settings.frenzy_max)
	frenzy_held = settings.frenzy_time


func _dash(direction: Vector3) -> void:
	if not is_on(FishCharacter.Family.BREAKOUT) or settings.dash_speed <= 0.0 or not run.is_up(fish):
		return
	dashes += 1
	fish.apply_push(direction.normalized() * settings.dash_speed)
	var health := run.health_of(fish)
	if health:
		health.shield(settings.dash_iframes)


func _leap() -> void:
	if not is_on(FishCharacter.Family.HYBRID) or settings.leap_impulse <= 0.0 or _leap_left > 0.0 or _leap_age >= 0.0 or not run.is_up(fish):
		return
	leaps += 1
	_leap_age = 0.0
	_leap_left = settings.leap_cooldown
	fish.apply_push(Vector3.UP * settings.leap_impulse)


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
