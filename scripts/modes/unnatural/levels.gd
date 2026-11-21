class_name Levels
extends RefCounted
## The team's level in Unnatural (planning_unnatural.md §6, D2: one shared
## level, everyone levels together). XP pearls add XP (times xp_gain); each
## level takes xp_base * level ^ xp_curve.

signal leveled_up(level: int)

var settings: UnnaturalSettings
var level := 1
## XP towards the next level, and in all this run.
var xp := 0.0
var total_xp := 0.0


func _init(level_settings: UnnaturalSettings) -> void:
	settings = level_settings


func reset() -> void:
	level = 1
	xp = 0.0
	total_xp = 0.0


## XP from level `at` to the next.
func xp_to_next(at := -1) -> float:
	var from := level if at < 0 else at
	return maxf(ceilf(settings.xp_base * pow(float(from), settings.xp_curve)), 1.0)


## Adds `amount` XP (xp_gain applies), levelling up as often as it covers.
func add(amount: float) -> void:
	var gained := amount * settings.xp_gain
	if gained <= 0.0:
		return
	xp += gained
	total_xp += gained
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		leveled_up.emit(level)


## The team's level and XP as the host has them (an online guest): each
## level gained levels up here too.
func set_state(new_level: int, new_xp: float) -> void:
	while level < new_level:
		level += 1
		leveled_up.emit(level)
	level = maxi(new_level, 1)
	xp = new_xp


## How far to the next level, 0..1.
func progress() -> float:
	return clampf(xp / xp_to_next(), 0.0, 1.0)
