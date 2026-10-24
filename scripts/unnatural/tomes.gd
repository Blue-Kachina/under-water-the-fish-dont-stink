class_name Tomes
## Unnatural's tomes (planning_unnatural.md, "Playability pass" P1, D21): a
## global stat that levels up. A player holds tome_slots of them (Loadout).
## The 18 stats (StatBlock) fold into 12 broad tomes: a tome card adds one
## step of each of its stats (StatBlock.amount), times the card's rarity; a
## tome with more than one stat gives each tome_multi_share of a step.

## Tome id -> [name, its stats, colour].
const TOMES := {
	"teeth": ["Tome of Teeth", ["damage"], Color(1.0, 0.45, 0.4)],
	"tides": ["Tome of Tides", ["attack_speed"], Color(0.45, 0.85, 1.0)],
	"reef": ["Tome of the Reef", ["size"], Color(1.0, 0.55, 0.75)],
	"schools": ["Tome of Schools", ["quantity"], Color(0.6, 0.75, 1.0)],
	"currents": ["Tome of Currents", ["projectile_speed", "knockback"], Color(0.4, 0.7, 0.95)],
	"kill": ["Tome of the Kill", ["crit_chance", "crit_damage"], Color(1.0, 0.3, 0.3)],
	"fins": ["Tome of Fins", ["swim_speed", "stride_power"], Color(0.55, 1.0, 0.8)],
	"ram": ["Tome of the Ram", ["battery_damage"], Color(1.0, 0.7, 0.3)],
	"shell": ["Tome of the Shell", ["max_hp", "armour", "regen"], Color(0.95, 0.75, 0.55)],
	"pearls": ["Tome of Pearls", ["xp_gain", "pearl_chance", "pickup_range"], Color(0.85, 0.9, 1.0)],
	"fortune": ["Tome of Fortune", ["luck"], Color(1.0, 0.85, 0.35)],
	"ages": ["Tome of Ages", ["duration"], Color(0.75, 0.6, 1.0)],
}
## What Tome of Ages' duration lasts longer: these weapons' (by their attack's
## kind) and items' effects.
const DURATION_WEAPONS: Array[FishAttack.Kind] = [FishAttack.Kind.FIRE, FishAttack.Kind.CHARGES]
const DURATION_ITEMS: Array[String] = ["anglerfish_lure"]


static func ids() -> Array[String]:
	var all: Array[String] = []
	for id: String in TOMES:
		all.append(id)
	return all


static func title(id: String) -> String:
	return TOMES[id][0] if TOMES.has(id) else id


static func stats(id: String) -> Array:
	return TOMES[id][1] if TOMES.has(id) else []


static func color(id: String) -> Color:
	return TOMES[id][2] if TOMES.has(id) else Color.WHITE


static func glyph(id: String) -> String:
	return "tome_" + id


## What one card of tome `id` at rarity multiplier `multiplier` gives: stat -> amount.
static func gives(id: String, multiplier: float, settings: UnnaturalSettings) -> Dictionary:
	var list := stats(id)
	var share := 1.0 if list.size() <= 1 else settings.tome_multi_share
	var given := {}
	for stat: String in list:
		given[stat] = StatBlock.amount(stat, multiplier * share)
	return given


## ["Damage +15%", "Armour +2"]: one stat a line.
static func describe(given: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	for stat: String in given:
		parts.append(StatBlock.describe(stat, given[stat]))
	return parts
