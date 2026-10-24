class_name StatBlock
extends RefCounted
## A player's stats in Unnatural (planning_unnatural.md §6): what level-up
## cards (and later powerups) add to. Every stat starts at 0 and is a bonus:
## flat ones (hp, hp/s, armour, quantity, luck) add, the rest are shares
## (0.1 = +10%). Each has a step, what one common card gives; rarer cards give
## more (Rarity's multipliers). Each fish has a signature stat it gets +1 step
## of every level (SIGNATURE).
##
## In the card pool: the stats something uses. Quantity and Projectile Speed are
## offered only to fish whose attack uses them (FishAttack.uses_stat);
## duration waits for something that uses it.

## Stat id -> [name, step, percent?, in every card pool?].
const STATS := {
	"max_hp": ["Max HP", 10.0, false, true],
	"regen": ["Regen", 0.4, false, true],
	"armour": ["Armour", 1.0, false, true],
	"damage": ["Damage", 0.1, true, true],
	"attack_speed": ["Attack Speed", 0.08, true, true],
	"size": ["Size", 0.1, true, true],
	"quantity": ["Quantity", 1.0, false, false],
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
	"pearl_chance": ["Pearl Chance", 0.15, true, true],
	"luck": ["Luck", 0.1, false, true],
}
## Each fish's signature stat (+1 step every level).
const SIGNATURE := {
	FishCharacter.FishClass.HUNTER: "damage",
	FishCharacter.FishClass.SKIRMISHER: "size",
	FishCharacter.FishClass.LANCER: "projectile_speed",
	FishCharacter.FishClass.CHARMER: "luck",
	FishCharacter.FishClass.BULWARK: "armour",
	FishCharacter.FishClass.GLIDER: "attack_speed",
	FishCharacter.FishClass.SCORCHER: "duration",
	FishCharacter.FishClass.DRIFTER: "quantity",
	FishCharacter.FishClass.BRAWLER: "knockback",
	FishCharacter.FishClass.BREACHER: "pearl_chance",
	FishCharacter.FishClass.ALCHEMIST: "regen",
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


## A stat as play uses it: its total, with P4's limits on it (Limits.stat():
## Crit Chance bent short of 100%, Size soft-capped). raw() is the plain total.
func value(id: String) -> float:
	return Limits.stat(id, raw(id), UnnaturalSettings.shared())


func raw(id: String) -> float:
	return values.get(id, 0.0) + bonus.get(id, 0.0)


func add(id: String, amount: float) -> void:
	values[id] = values.get(id, 0.0) + amount


## What one card of `id` at `multiplier` (its rarity's) gives. Whole stats
## (projectiles) round up.
static func amount(id: String, multiplier := 1.0) -> float:
	var step: float = STATS[id][1]
	var given := step * multiplier
	return ceilf(given) if id == "quantity" else given


static func title(id: String) -> String:
	return STATS[id][0]


## "+15% Damage", "+12 Max HP": how a card says what it gives.
## "Damage +15%", "Armour +2": the stat first, then its change.
static func describe(id: String, given: float) -> String:
	if STATS[id][2]:
		return "%s +%s%%" % [title(id), _number(given * 100.0)]
	return "%s +%s" % [title(id), _number(given)]


## The stats a card can offer, with those only `attack` uses (if given).
static func pool(attack: FishAttack = null) -> Array[String]:
	var ids: Array[String] = []
	for id: String in STATS:
		if STATS[id][3] or (attack != null and attack.uses_stat(id)):
			ids.append(id)
	return ids


static func signature(fish_class: FishCharacter.FishClass) -> String:
	return SIGNATURE.get(fish_class, "damage")


## What `fish_class`'s signature gives each level, `steps` steps of it. Quantity
## (the Drifters') isn't a card's whole +1: settings.signature_quantity a
## step (D8: Quantity is a real number; what spawns uses the floor).
static func signature_amount(fish_class: FishCharacter.FishClass, steps: float, settings: UnnaturalSettings) -> float:
	var id := signature(fish_class)
	if id == "quantity":
		return settings.signature_quantity * steps
	return amount(id, steps)


## A stat's total as it's shown: Quantity's floor (what spawns), the rest as is.
static func shown(id: String, total: float) -> float:
	return floorf(total + 0.0001) if id == "quantity" else total


static func _number(x: float) -> String:
	return str(roundi(x)) if absf(x - roundf(x)) < 0.05 else "%.1f" % x
