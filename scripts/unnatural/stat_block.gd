class_name StatBlock
extends RefCounted
## A player's stats in Unnatural (planning_unnatural.md §6): what level-up
## cards (and later powerups) add to. Every stat starts at 0 and is a bonus:
## flat ones (hp, hp/s, armour, projectiles, luck) add, the rest are shares
## (0.1 = +10%). Each has a step, what one common card gives; rarer cards give
## more (Rarity's multipliers). Each fish has a signature stat it gets +1 step
## of every level (SIGNATURE).
##
## In the card pool: the stats something uses. Projectile count and speed are
## offered only to fish whose attack uses them (FishAttack.uses_stat);
## duration waits for something that uses it.

## Stat id -> [name, step, percent?, in every card pool?].
const STATS := {
	"max_hp": ["Max HP", 10.0, false, true],
	"regen": ["Regen", 0.4, false, true],
	"armour": ["Armour", 1.0, false, true],
	"damage": ["Damage", 0.1, true, true],
	"attack_speed": ["Attack Speed", 0.08, true, true],
	"area": ["Area", 0.1, true, true],
	"projectile_count": ["Projectiles", 1.0, false, false],
	"projectile_speed": ["Projectile Speed", 0.1, true, false],
	"crit_chance": ["Crit Chance", 0.05, true, true],
	"crit_damage": ["Crit Damage", 0.2, true, true],
	"swim_speed": ["Swim Speed", 0.05, true, true],
	"stride_power": ["Stride Power", 0.06, true, true],
	"battery_damage": ["Battery Damage", 0.15, true, true],
	"knockback": ["Knockback", 0.15, true, true],
	"duration": ["Duration", 0.1, true, false],
	"pickup_range": ["Pickup Range", 0.15, true, true],
	"xp_gain": ["XP Gain", 0.08, true, true],
	"luck": ["Luck", 0.1, false, true],
}
## Each fish's signature stat (+1 step every level).
const SIGNATURE := {
	FishCharacter.Family.DOMINUS: "damage",
	FishCharacter.Family.OCTANE: "area",
	FishCharacter.Family.BREAKOUT: "projectile_speed",
	FishCharacter.Family.HYBRID: "luck",
	FishCharacter.Family.MERC: "armour",
	FishCharacter.Family.PLANK: "attack_speed",
}

var values := {}
## What powerups add on top (Powerups keeps it up to date): Hermit Shell's max
## hp, Barnacle Plating's armour...
var bonus := {}


func _init() -> void:
	reset()


func reset() -> void:
	values.clear()
	for id: String in STATS:
		values[id] = 0.0


func value(id: String) -> float:
	return values.get(id, 0.0) + bonus.get(id, 0.0)


func add(id: String, amount: float) -> void:
	values[id] = values.get(id, 0.0) + amount


## What one card of `id` at `multiplier` (its rarity's) gives. Whole stats
## (projectiles) round up.
static func amount(id: String, multiplier := 1.0) -> float:
	var step: float = STATS[id][1]
	var given := step * multiplier
	return ceilf(given) if id == "projectile_count" else given


static func title(id: String) -> String:
	return STATS[id][0]


## "+15% Damage", "+12 Max HP": how a card says what it gives.
static func describe(id: String, given: float) -> String:
	if STATS[id][2]:
		return "+%s%% %s" % [_number(given * 100.0), title(id)]
	return "+%s %s" % [_number(given), title(id)]


## The stats a card can offer, with those only `attack` uses (if given).
static func pool(attack: FishAttack = null) -> Array[String]:
	var ids: Array[String] = []
	for id: String in STATS:
		if STATS[id][3] or (attack != null and attack.uses_stat(id)):
			ids.append(id)
	return ids


static func signature(family: FishCharacter.Family) -> String:
	return SIGNATURE.get(family, "damage")


static func _number(x: float) -> String:
	return str(roundi(x)) if absf(x - roundf(x)) < 0.05 else "%.1f" % x
