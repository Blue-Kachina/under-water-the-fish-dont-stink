class_name Weapons
## Unnatural's weapons (planning_unnatural.md, "Playability pass" P1): what
## does damage by itself, on its own timer. A player holds weapon_slots of them
## (Loadout); the fish's own attack ("attack") is always one. The others are
## powerups (Powerup) of kind WEAPON, got from level-up cards, not chests.
##
## Each weapon has facets it can improve (FACETS). A card for one rolls which
## facets it raises and by how much (roll()): its rarity sets how many facets
## (UnnaturalSettings.facets_*) and how big each step is (facet_size_*). A
## facet's step is a PowerupSettings value (its third entry). Kinds:
## - "pct": a share (0.2 = +20%) on its number;
## - "add": added to its number, in the unit given;
## - "count": whole, rounded (a common step adds the step, a legendary 2.5x).
## The weapon reads its total with Loadout.facet().

## The fish's own attack's weapon id.
const ATTACK := "attack"
## The chest powerups that are weapons, in the order cards list them. The
## attack_* ones are the fish's attacks held as an extra weapon (AttackWeapon):
## every fish's weapon can be any fish's second (not its own again).
const POWERUPS: Array[String] = ["greek_fire", "jellyfish_halo", "depth_charges", "remora_buddy", "leviathans_coil",
		"attack_sting", "attack_bite", "attack_lash", "attack_thrust", "attack_bubbles", "attack_spines"]
## Weapons only a boss gives (never offered on a level-up card).
const BOSS_ONLY: Array[String] = ["leviathans_coil"]
## The fish attacks as extra weapons: weapon id -> its attack's kind.
const ATTACK_WEAPONS := {
	"attack_sting": FishAttack.Kind.STING,
	"attack_bite": FishAttack.Kind.BITE,
	"attack_lash": FishAttack.Kind.LASH,
	"attack_thrust": FishAttack.Kind.THRUST,
	"attack_bubbles": FishAttack.Kind.BUBBLES,
	"attack_spines": FishAttack.Kind.SPINES,
}

## Weapon id -> [[facet id, label, kind, step setting, unit]...]. The fish's
## attack's depend on its kind (ATTACK_FACETS).
const FACETS := {
	"greek_fire": [
		["burn", "Burn damage", "pct", "fire_dps_step", ""],
		["life", "Patch life", "add", "fire_life_per_stack", " s"],
		["radius", "Patch size", "pct", "fire_radius_step", ""],
		["density", "Denser trail", "pct", "fire_density_step", ""],
		["patches", "Max patches", "count", "fire_patches_step", ""],
	],
	"jellyfish_halo": [
		["count", "Jellies", "count", "jelly_count_per_stack", ""],
		["damage", "Sting damage", "pct", "jelly_damage_step", ""],
		["radius", "Orbit size", "pct", "halo_radius_step", ""],
		["spin", "Orbit speed", "pct", "halo_spin_step", ""],
		["rate", "Sting rate", "pct", "jelly_rate_step", ""],
	],
	"depth_charges": [
		["damage", "Blast damage", "pct", "charge_damage_step", ""],
		["blast", "Blast size", "pct", "charge_blast_step", ""],
		["rate", "Drop rate", "pct", "charge_rate_step", ""],
		["mines", "Mines out", "count", "charge_max_step", ""],
		["arm", "Arming speed", "pct", "charge_arm_step", ""],
	],
	"remora_buddy": [
		["count", "Remoras", "count", "remora_count_per_stack", ""],
		["damage", "Bite damage", "pct", "remora_damage_step", ""],
		["rate", "Bite rate", "pct", "remora_rate_step", ""],
		["reach", "Reach", "pct", "remora_range_step", ""],
	],
	"leviathans_coil": [
		["count", "Coils", "count", "coil_segments_per_stack", ""],
		["damage", "Coil damage", "pct", "coil_damage_step", ""],
		["size", "Coil size", "pct", "coil_radius_step", ""],
		["rate", "Hit rate", "pct", "coil_rate_step", ""],
	],
}
## The fish's attack's facets, by its kind (FishAttack.Kind).
const ATTACK_FACETS := {
	FishAttack.Kind.STING: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Attack rate", "pct", "attack_rate_step", ""],
		["size", "Pulse size", "pct", "attack_size_step", ""],
		["knock", "Knockback", "pct", "attack_knock_step", ""],
	],
	FishAttack.Kind.BITE: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Bite rate", "pct", "attack_rate_step", ""],
		["size", "Jaw size", "pct", "attack_size_step", ""],
		["knock", "Knockback", "pct", "attack_knock_step", ""],
	],
	FishAttack.Kind.LASH: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Lash rate", "pct", "attack_rate_step", ""],
		["size", "Lash reach", "pct", "attack_size_step", ""],
		["count", "Arcs", "count", "attack_count_step", ""],
	],
	FishAttack.Kind.THRUST: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Thrust rate", "pct", "attack_rate_step", ""],
		["count", "Spears", "count", "attack_count_step", ""],
		["speed", "Spear speed", "pct", "attack_speed_step", ""],
	],
	FishAttack.Kind.BUBBLES: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Volley rate", "pct", "attack_rate_step", ""],
		["count", "Bubbles", "count", "attack_count_step", ""],
		["speed", "Bubble speed", "pct", "attack_speed_step", ""],
	],
	FishAttack.Kind.SPINES: [
		["damage", "Damage", "pct", "attack_damage_step", ""],
		["rate", "Burst rate", "pct", "attack_rate_step", ""],
		["count", "Spine rings", "count", "attack_count_step", ""],
		["size", "Spine range", "pct", "attack_size_step", ""],
	],
}
## What each Lv milestone does, per weapon (shown on the card that reaches it).
const MILESTONES := {
	"greek_fire": ["Zombies that burn to death leave a patch behind", "The trail fans out three wide",
			"Patches flare up every few seconds, scorching wider", "The flames creep toward the nearest zombie"],
	"jellyfish_halo": ["Each jelly trails a ghost that stings too", "The halo swings out wide every few seconds",
			"A second, wider halo circles the other way", "Stings jump on to the nearest zombie"],
	"depth_charges": ["A triggered mine pulls zombies in, then blows", "Every fourth blast is a cluster bomb",
			"Armed mines drift toward zombies close by", "Every blast goes off again a moment later"],
	"remora_buddy": ["Remoras latch on and keep biting", "A kill splits a remora in two for a while",
			"Bites tear into the zombies round the one bitten", "Remora kills heal you a little"],
	"leviathans_coil": ["Coils slow the zombies they touch", "The coil's head snaps at zombies near it",
			"The tail lashes out in a shock ring", "The coil grows twice as long"],
	FishAttack.Kind.STING: ["A second, wider pulse follows each sting", "Stings slow what they hit",
			"Pulses draw zombies in from further out", "A third pulse follows, wider still"],
	FishAttack.Kind.BITE: ["A second set of jaws snaps behind you", "Jaws snap at both sides too",
			"Jaws snap above and below you too", "Every bite snaps twice"],
	FishAttack.Kind.LASH: ["Each lash strikes a second zombie too", "Arcs jump twice as far",
			"Each arc jumps on to two more zombies", "Each lash strikes a third zombie too"],
	FishAttack.Kind.THRUST: ["Spears pierce one more zombie", "Spears burst at the end of their flight",
			"Two more spears fan out with each thrust", "Spears pierce everything in their way"],
	FishAttack.Kind.BUBBLES: ["Bubbles pop in a wider splash", "Every volley ends with one big bubble",
			"Each volley blows twice as many bubbles", "Every volley ends with three big bubbles"],
	FishAttack.Kind.SPINES: ["Spines fly further", "A second ring of spines follows each burst",
			"Spines pierce two more zombies", "A third, full ring follows the second"],
}


static func is_weapon(id: String) -> bool:
	return id == ATTACK or id in POWERUPS


## The weapons a level-up card may offer as new to a fish whose own attack is
## `own` (not boss ones, not its own attack again), each equally likely.
static func card_pool(own := FishAttack.Kind.NONE) -> Array[String]:
	var pool: Array[String] = []
	for id in POWERUPS:
		if id not in BOSS_ONLY and ATTACK_WEAPONS.get(id, -1) != own:
			pool.append(id)
	return pool


## The attack kind weapon `id` fires: the fish's own (`kind`) for ATTACK, an
## extra attack's own, or NONE (a powerup weapon).
static func attack_kind_of(id: String, kind := FishAttack.Kind.BITE) -> FishAttack.Kind:
	if id == ATTACK:
		return kind
	return ATTACK_WEAPONS.get(id, FishAttack.Kind.NONE)


## Weapon `id`'s facets, for a fish whose attack is `kind`.
static func facets(id: String, kind := FishAttack.Kind.BITE) -> Array:
	if id == ATTACK:
		return ATTACK_FACETS.get(kind, ATTACK_FACETS[FishAttack.Kind.BITE])
	if ATTACK_WEAPONS.has(id):
		return ATTACK_FACETS[ATTACK_WEAPONS[id]]
	return FACETS.get(id, [])


static func facet_def(id: String, facet: String, kind := FishAttack.Kind.BITE) -> Array:
	for entry: Array in facets(id, kind):
		if entry[0] == facet:
			return entry
	return []


## Weapon `id`'s name (the attack's is its kind's).
static func title(id: String, kind := FishAttack.Kind.BITE) -> String:
	return FishAttack.title(kind) if id == ATTACK else Powerup.title(id)


## Its glyph (HexBadge): a powerup's own, or the attack's kind's.
static func glyph(id: String, kind := FishAttack.Kind.BITE) -> String:
	return "attack_" + FishAttack.source_of(kind) if id == ATTACK else id


## Its milestone lines ([first, second, third, fourth]).
static func milestones(id: String, kind := FishAttack.Kind.BITE) -> Array:
	if ATTACK_WEAPONS.has(id):
		return MILESTONES.get(ATTACK_WEAPONS[id], [])
	return MILESTONES.get(kind if id == ATTACK else id, [])


## What one step of `entry` (a facet) is worth at `size` (the rarity's).
static func step_amount(entry: Array, size: float, powerup_settings: PowerupSettings) -> float:
	var step: float = powerup_settings.get(entry[3])
	if entry[2] == "count":
		return float(maxi(roundi(step * size), 1)) if step > 0.0 else 0.0
	return step * size


## A card's gains for weapon `id` at rarity `tier`: facet id -> amount.
## Different facets, as many as the rarity says.
static func roll(rng: RandomNumberGenerator, id: String, kind: FishAttack.Kind, tier: int, settings: UnnaturalSettings,
		powerup_settings: PowerupSettings) -> Dictionary:
	var pool := facets(id, kind).duplicate()
	var count := clampi(settings.facets_for(tier), 1, maxi(pool.size(), 1))
	var size := settings.facet_size_for(tier)
	var gains := {}
	while gains.size() < count and not pool.is_empty():
		var entry: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		gains[entry[0]] = step_amount(entry, size, powerup_settings)
	return gains


## Each of `gains` (facet id -> amount) described, one a line, stat first.
static func describe_all(id: String, gains: Dictionary, kind := FishAttack.Kind.BITE) -> PackedStringArray:
	var lines := PackedStringArray()
	for facet: String in gains:
		var entry := facet_def(id, facet, kind)
		if not entry.is_empty():
			lines.append(describe(entry, gains[facet]))
	return lines


## "Burn damage +20%", "Patch life +1.5 s", "Jellies +1".
static func describe(entry: Array, amount: float) -> String:
	match entry[2]:
		"pct":
			return "%s +%s%%" % [entry[1], StatBlock._number(amount * 100.0)]
		"count":
			return "%s +%d" % [entry[1], roundi(amount)]
	return "%s +%s%s" % [entry[1], StatBlock._number(amount), entry[4]]
