class_name FishCharacter
## The playable classes: groups of fish that play the same way (hitbox, starting
## weapon, signature stat, twist, mobility skill), each made up of species that
## change only the look. Every class's hitbox is one of Rocket League's six
## (`rl_hitbox`, which RL replays name), so picking one gives the fish that
## hitbox's RocketSim values (box, where the centre of mass sits in it, and its
## four wheels) and the class its own model (FishModel).
##
## Hitbox values are RocketSim's, in uu (1 uu = 1 cm) and RL's frame:
## (forward, right, up) from the centre of mass. `ride` is how high the hitbox's
## bottom sits off the floor settled on its wheels (measured in RocketSim),
## which the fish's belly fills.

## The order goes over the network (and into anything stored by index): add new
## classes at the end, never reorder.
enum FishClass { SKIRMISHER, HUNTER, GLIDER, LANCER, CHARMER, BULWARK, SCORCHER, DRIFTER, BRAWLER, BREACHER, ALCHEMIST }

## Per class: `key` (saves and our clips), `name` (the role name the picker
## shows), `rl_hitbox` (the RL hitbox it uses, as RL replays key it), `aliases`
## (keys from before classes, still read), then that hitbox's RocketSim values.
const CLASSES := {
	FishClass.SKIRMISHER: {
		"key": "skirmisher", "name": "Skirmishers", "rl_hitbox": "octane", "aliases": ["octane"],
		"hitbox": Vector3(120.507, 86.6994, 38.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-33.75, 29.5, 20.755)},
		"ride": 18.344,
	},
	FishClass.HUNTER: {
		"key": "hunter", "name": "Hunters", "rl_hitbox": "dominus", "aliases": ["dominus"],
		"hitbox": Vector3(130.427, 85.7799, 33.8), "offset": Vector3(9.0, 0.0, 15.75),
		"front": {"radius": 12.0, "rest": 33.95, "at": Vector3(50.3, 31.1, 15.75)},
		"back": {"radius": 13.5, "rest": 33.85, "at": Vector3(-34.75, 33.0, 15.75)},
		"ride": 15.923,
	},
	FishClass.GLIDER: {
		"key": "glider", "name": "Gliders", "rl_hitbox": "plank", "aliases": ["plank"],
		"hitbox": Vector3(131.32, 87.1704, 31.8944), "offset": Vector3(9.00857, 0.0, 12.0942),
		"front": {"radius": 12.5, "rest": 31.924, "at": Vector3(49.97, 27.8, 12.0942)},
		"back": {"radius": 17.0, "rest": 27.924, "at": Vector3(-35.43, 20.28, 12.0942)},
		"ride": 14.732,
	},
	FishClass.LANCER: {
		"key": "lancer", "name": "Lancers", "rl_hitbox": "breakout", "aliases": ["breakout"],
		"hitbox": Vector3(133.992, 83.021, 32.8), "offset": Vector3(12.5, 0.0, 11.75),
		"front": {"radius": 13.5, "rest": 29.7, "at": Vector3(51.5, 26.67, 11.75)},
		"back": {"radius": 15.0, "rest": 29.666, "at": Vector3(-35.75, 35.0, 11.75)},
		"ride": 13.704,
	},
	FishClass.CHARMER: {
		"key": "charmer", "name": "Charmers", "rl_hitbox": "hybrid", "aliases": ["hybrid"],
		"hitbox": Vector3(129.519, 84.6879, 36.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-34.0, 29.5, 20.755)},
		"ride": 19.342,
	},
	FishClass.BULWARK: {
		"key": "bulwark", "name": "Bulwarks", "rl_hitbox": "merc", "aliases": ["merc"],
		"hitbox": Vector3(123.22, 79.2103, 44.1591), "offset": Vector3(11.3757, 0.0, 21.505),
		"front": {"radius": 15.0, "rest": 39.505, "at": Vector3(51.25, 25.9, 21.505)},
		"back": {"radius": 15.0, "rest": 39.105, "at": Vector3(-33.75, 29.5, 21.505)},
		"ride": 18.147,
	},
	# The later classes share a hitbox with one of the first six (their shapes differ, the boxes don't).
	FishClass.SCORCHER: {
		"key": "scorcher", "name": "Scorchers", "rl_hitbox": "octane", "aliases": ["lionfish"],
		"hitbox": Vector3(120.507, 86.6994, 38.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-33.75, 29.5, 20.755)},
		"ride": 18.344,
	},
	FishClass.DRIFTER: {
		"key": "drifter", "name": "Drifters", "rl_hitbox": "hybrid", "aliases": ["moon_jelly"],
		"hitbox": Vector3(129.519, 84.6879, 36.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-34.0, 29.5, 20.755)},
		"ride": 19.342,
	},
	FishClass.BRAWLER: {
		"key": "brawler", "name": "Brawlers", "rl_hitbox": "dominus", "aliases": ["mantis"],
		"hitbox": Vector3(130.427, 85.7799, 33.8), "offset": Vector3(9.0, 0.0, 15.75),
		"front": {"radius": 12.0, "rest": 33.95, "at": Vector3(50.3, 31.1, 15.75)},
		"back": {"radius": 13.5, "rest": 33.85, "at": Vector3(-34.75, 33.0, 15.75)},
		"ride": 15.923,
	},
	FishClass.BREACHER: {
		"key": "breacher", "name": "Breachers", "rl_hitbox": "plank", "aliases": ["whale_shark"],
		"hitbox": Vector3(131.32, 87.1704, 31.8944), "offset": Vector3(9.00857, 0.0, 12.0942),
		"front": {"radius": 12.5, "rest": 31.924, "at": Vector3(49.97, 27.8, 12.0942)},
		"back": {"radius": 17.0, "rest": 27.924, "at": Vector3(-35.43, 20.28, 12.0942)},
		"ride": 14.732,
	},
	FishClass.ALCHEMIST: {
		"key": "alchemist", "name": "Alchemists", "rl_hitbox": "merc", "aliases": ["sea_hare"],
		"hitbox": Vector3(123.22, 79.2103, 44.1591), "offset": Vector3(11.3757, 0.0, 21.505),
		"front": {"radius": 15.0, "rest": 39.505, "at": Vector3(51.25, 25.9, 21.505)},
		"back": {"radius": 15.0, "rest": 39.105, "at": Vector3(-33.75, 29.5, 21.505)},
		"ride": 18.147,
	},
}
## How far a tyre reaches out past its suspension mount (uu): the belly is this
## much wider than the wheels' mounts on each side.
const TYRE_HALF_WIDTH := 5.5
const M_PER_UU := 0.01


## Each class's species (FishModel.build's `species`): real species or colour
## morphs sharing its shape, hitbox and moves. The first is the class's own
## look; the rest are to unlock (meta progression, later).
const SPECIES := {
	FishClass.SKIRMISHER: [
		{"key": "ocellaris", "name": "Ocellaris"},
		{"key": "black_percula", "name": "Black Percula"},
		{"key": "tomato", "name": "Tomato Clownfish"},
		{"key": "maroon", "name": "Gold-stripe Maroon"},
	],
	FishClass.HUNTER: [
		{"key": "great_white", "name": "Great White"},
		{"key": "mako", "name": "Shortfin Mako"},
		{"key": "blacktip", "name": "Blacktip Reef"},
		{"key": "tiger", "name": "Tiger Shark"},
		{"key": "hammerhead", "name": "Hammerhead"},
	],
	FishClass.GLIDER: [
		{"key": "manta", "name": "Manta"},
		{"key": "eagle_ray", "name": "Spotted Eagle Ray"},
		{"key": "southern_stingray", "name": "Southern Stingray"},
		{"key": "ribbontail", "name": "Blue-spotted Ribbontail"},
	],
	FishClass.LANCER: [
		{"key": "broadbill", "name": "Broadbill Swordfish"},
		{"key": "blue_marlin", "name": "Blue Marlin"},
		{"key": "sailfish", "name": "Sailfish"},
		{"key": "striped_marlin", "name": "Striped Marlin"},
	],
	FishClass.CHARMER: [
		{"key": "kohaku", "name": "Kohaku"},
		{"key": "showa", "name": "Showa"},
		{"key": "yamabuki", "name": "Yamabuki Ogon"},
		{"key": "asagi", "name": "Asagi"},
	],
	FishClass.BULWARK: [
		{"key": "yellow_boxfish", "name": "Yellow Boxfish"},
		{"key": "longhorn", "name": "Longhorn Cowfish"},
		{"key": "spotted_boxfish", "name": "Spotted Boxfish"},
		{"key": "scrawled", "name": "Scrawled Cowfish"},
	],
	FishClass.SCORCHER: [
		{"key": "red", "name": "Red Lionfish"},
		{"key": "clearfin", "name": "Clearfin Lionfish"},
		{"key": "fuzzy_dwarf", "name": "Fuzzy Dwarf"},
		{"key": "spotfin", "name": "Spotfin Lionfish"},
	],
	FishClass.DRIFTER: [
		{"key": "moon", "name": "Moon Jelly"},
		{"key": "sea_nettle", "name": "Pacific Sea Nettle"},
		{"key": "lions_mane", "name": "Lion's Mane"},
		{"key": "purple_striped", "name": "Purple-striped Jelly"},
	],
	FishClass.BRAWLER: [
		{"key": "peacock", "name": "Peacock Mantis"},
		{"key": "zebra", "name": "Zebra Mantis"},
		{"key": "purple_spot", "name": "Purple-spot Mantis"},
		{"key": "pink_eared", "name": "Pink-eared Mantis"},
	],
	FishClass.BREACHER: [
		{"key": "indo_pacific", "name": "Whale Shark"},
		{"key": "deep_charcoal", "name": "Deep Charcoal"},
		{"key": "juvenile", "name": "Juvenile"},
		{"key": "basking", "name": "Basking Shark"},
	],
	FishClass.ALCHEMIST: [
		{"key": "california", "name": "California Sea Hare"},
		{"key": "spotted", "name": "Spotted Sea Hare"},
		{"key": "ragged", "name": "Ragged Sea Hare"},
		{"key": "tinctoria", "name": "Tinctoria"},
	],
}


## "Brawlers": the class's role name, as the picker lists it.
static func display_name(fish_class: FishClass) -> String:
	return CLASSES[fish_class].name


## "Brawlers · Peacock Mantis": the class with species `species` under it, on one line.
static func full_name(fish_class: FishClass, species: int) -> String:
	return "%s  ·  %s" % [display_name(fish_class), species_name(fish_class, species)]


## How many species `fish_class` has (SPECIES).
static func species_count(fish_class: FishClass) -> int:
	return (SPECIES[fish_class] as Array).size()


## Species `species` of `fish_class`'s name, as the picker shows it ("Great White").
static func species_name(fish_class: FishClass, species: int) -> String:
	return SPECIES[fish_class][clampi(species, 0, species_count(fish_class) - 1)].name


## Species `species` of `fish_class`'s key ("great_white"), for saves and replays.
static func species_key(fish_class: FishClass, species: int) -> String:
	return SPECIES[fish_class][clampi(species, 0, species_count(fish_class) - 1)].key


## The species of `fish_class` with `key`; its first if unknown.
static func species_from_key(fish_class: FishClass, key: String) -> int:
	var all: Array = SPECIES[fish_class]
	for i in all.size():
		if all[i].key == key:
			return i
	return 0


## Whether the player may pick species `species` of `fish_class`. Every species
## for now; the one place a meta-progression unlock check slots in later (the
## pickers skip locked species, the saved/remote/replay ones are taken as given).
static func is_species_unlocked(_fish_class: FishClass, _species: int) -> bool:
	return true


## The class for `key`: a class key ("brawler"), a key from before classes
## ("mantis", "whale_shark"), or an RL replay's hitbox_family ("octane": the
## first class on that hitbox). Skirmishers if unknown.
static func from_key(key: String) -> FishClass:
	var k := key.to_lower()
	for fish_class: FishClass in CLASSES:
		if CLASSES[fish_class].key == k or k in CLASSES[fish_class].aliases:
			return fish_class
	for fish_class: FishClass in CLASSES:
		if CLASSES[fish_class].rl_hitbox == k:
			return fish_class
	return FishClass.SKIRMISHER


## A replay player's class: its recorded fish_class key, else (RL replays,
## older clips) its hitbox_family's.
static func class_of(replay_player: Dictionary) -> FishClass:
	var key := str(replay_player.get("fish_class", ""))
	return from_key(key if key != "" else str(replay_player.get("hitbox_family", "octane")))


## The RL hitbox `fish_class` uses, as RL replays key it ("octane").
static func rl_hitbox(fish_class: FishClass) -> String:
	return CLASSES[fish_class].rl_hitbox


## Hitbox size (m) as the fish's exports have it: width, height, length.
static func hitbox_size(fish_class: FishClass) -> Vector3:
	var h: Vector3 = CLASSES[fish_class].hitbox
	return Vector3(h.y, h.z, h.x) * M_PER_UU


## Where the centre of mass is from the hitbox centre, in the fish's frame (m;
## nose -Z): behind and below it.
static func com_from_hitbox(fish_class: FishClass) -> Vector3:
	var offset: Vector3 = CLASSES[fish_class].offset
	return Vector3(0.0, -offset.z, offset.x) * M_PER_UU


## The four wheels (front left, front right, back left, back right): suspension
## mount in the fish's frame from the hitbox centre (m), wheel radius (m) and
## suspension rest length (m), as FishController's suspension reads them.
static func wheels(fish_class: FishClass) -> Array[Dictionary]:
	var box: Dictionary = CLASSES[fish_class]
	var offset: Vector3 = box.offset
	var result: Array[Dictionary] = []
	for end: String in ["front", "back"]:
		var wheel: Dictionary = box[end]
		var at: Vector3 = wheel.at
		for side: float in [-1.0, 1.0]:
			result.append({
				"mount": Vector3(side * at.y, at.z - offset.z, -(at.x - offset.x)) * M_PER_UU,
				"radius": wheel.radius * M_PER_UU,
				"rest": wheel.rest * M_PER_UU,
			})
	return result


## The axles' distances (m) ahead of and behind the centre of mass.
static func axles(fish_class: FishClass) -> Vector2:
	var box: Dictionary = CLASSES[fish_class]
	return Vector2(box.front.at.x, -box.back.at.x) * M_PER_UU


## The belly under the hitbox where the wheels are (m; width, height, length):
## as high as the hitbox rides, as long and wide as its tyres reach.
static func belly(fish_class: FishClass) -> Vector3:
	var box: Dictionary = CLASSES[fish_class]
	var length: float = box.front.at.x + box.front.radius - box.back.at.x + box.back.radius
	var width: float = 2.0 * maxf(box.front.at.y, box.back.at.y) + 2.0 * TYRE_HALF_WIDTH
	return Vector3(width, box.ride, length) * M_PER_UU
