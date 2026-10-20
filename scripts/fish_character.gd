class_name FishCharacter
## The playable fish, one for each of Rocket League's six hitboxes. Picking one
## gives the fish that car's RocketSim CarConfig (hitbox, where the centre of
## mass sits in it, and its four wheels) and its own model (FishModel).
##
## Car values are RocketSim's, in uu (1 uu = 1 cm) and RL's car frame:
## (forward, right, up) from the centre of mass. `ride` is how high the hitbox's
## bottom sits off the floor with the car settled on its wheels (measured in
## RocketSim), which the fish's belly fills.

enum Family { OCTANE, DOMINUS, PLANK, BREAKOUT, HYBRID, MERC, LIONFISH, MOON_JELLY, MANTIS, WHALE_SHARK }

const CARS := {
	Family.OCTANE: {
		"key": "octane", "car": "Octane", "fish": "Clownfish",
		"hitbox": Vector3(120.507, 86.6994, 38.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-33.75, 29.5, 20.755)},
		"ride": 18.344,
	},
	Family.DOMINUS: {
		"key": "dominus", "car": "Dominus", "fish": "Shark",
		"hitbox": Vector3(130.427, 85.7799, 33.8), "offset": Vector3(9.0, 0.0, 15.75),
		"front": {"radius": 12.0, "rest": 33.95, "at": Vector3(50.3, 31.1, 15.75)},
		"back": {"radius": 13.5, "rest": 33.85, "at": Vector3(-34.75, 33.0, 15.75)},
		"ride": 15.923,
	},
	Family.PLANK: {
		"key": "plank", "car": "Plank", "fish": "String Ray",
		"hitbox": Vector3(131.32, 87.1704, 31.8944), "offset": Vector3(9.00857, 0.0, 12.0942),
		"front": {"radius": 12.5, "rest": 31.924, "at": Vector3(49.97, 27.8, 12.0942)},
		"back": {"radius": 17.0, "rest": 27.924, "at": Vector3(-35.43, 20.28, 12.0942)},
		"ride": 14.732,
	},
	Family.BREAKOUT: {
		"key": "breakout", "car": "Breakout", "fish": "Swordfish",
		"hitbox": Vector3(133.992, 83.021, 32.8), "offset": Vector3(12.5, 0.0, 11.75),
		"front": {"radius": 13.5, "rest": 29.7, "at": Vector3(51.5, 26.67, 11.75)},
		"back": {"radius": 15.0, "rest": 29.666, "at": Vector3(-35.75, 35.0, 11.75)},
		"ride": 13.704,
	},
	Family.HYBRID: {
		"key": "hybrid", "car": "Hybrid", "fish": "Butterfly Koi",
		"hitbox": Vector3(129.519, 84.6879, 36.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-34.0, 29.5, 20.755)},
		"ride": 19.342,
	},
	Family.MERC: {
		"key": "merc", "car": "Merc", "fish": "Boxfish",
		"hitbox": Vector3(123.22, 79.2103, 44.1591), "offset": Vector3(11.3757, 0.0, 21.505),
		"front": {"radius": 15.0, "rest": 39.505, "at": Vector3(51.25, 25.9, 21.505)},
		"back": {"radius": 15.0, "rest": 39.105, "at": Vector3(-33.75, 29.5, 21.505)},
		"ride": 18.147,
	},
	# The later fish share a hitbox with one of the first six (their shapes differ, the boxes don't).
	Family.LIONFISH: {
		"key": "lionfish", "car": "Octane", "fish": "Lionfish",
		"hitbox": Vector3(120.507, 86.6994, 38.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-33.75, 29.5, 20.755)},
		"ride": 18.344,
	},
	Family.MOON_JELLY: {
		"key": "moon_jelly", "car": "Hybrid", "fish": "Moon Jelly",
		"hitbox": Vector3(129.519, 84.6879, 36.6591), "offset": Vector3(13.8757, 0.0, 20.755),
		"front": {"radius": 12.5, "rest": 38.755, "at": Vector3(51.25, 25.9, 20.755)},
		"back": {"radius": 15.0, "rest": 37.055, "at": Vector3(-34.0, 29.5, 20.755)},
		"ride": 19.342,
	},
	Family.MANTIS: {
		"key": "mantis", "car": "Dominus", "fish": "Mantis Shrimp",
		"hitbox": Vector3(130.427, 85.7799, 33.8), "offset": Vector3(9.0, 0.0, 15.75),
		"front": {"radius": 12.0, "rest": 33.95, "at": Vector3(50.3, 31.1, 15.75)},
		"back": {"radius": 13.5, "rest": 33.85, "at": Vector3(-34.75, 33.0, 15.75)},
		"ride": 15.923,
	},
	Family.WHALE_SHARK: {
		"key": "whale_shark", "car": "Plank", "fish": "Baby Whale Shark",
		"hitbox": Vector3(131.32, 87.1704, 31.8944), "offset": Vector3(9.00857, 0.0, 12.0942),
		"front": {"radius": 12.5, "rest": 31.924, "at": Vector3(49.97, 27.8, 12.0942)},
		"back": {"radius": 17.0, "rest": 27.924, "at": Vector3(-35.43, 20.28, 12.0942)},
		"ride": 14.732,
	},
}
## How far a tyre reaches out past its suspension mount (uu): the belly is this
## much wider than the wheels' mounts on each side.
const TYRE_HALF_WIDTH := 5.5
const M_PER_UU := 0.01


## Each family's skins (FishModel.build's `skin`): real species or colour
## morphs sharing its shape, hitbox and moves. The first is the family's own
## look; the rest are to unlock (meta progression, later).
const SKINS := {
	Family.OCTANE: [
		{"key": "ocellaris", "name": "Ocellaris"},
		{"key": "black_percula", "name": "Black Percula"},
		{"key": "tomato", "name": "Tomato Clownfish"},
		{"key": "maroon", "name": "Gold-stripe Maroon"},
	],
	Family.DOMINUS: [
		{"key": "great_white", "name": "Great White"},
		{"key": "mako", "name": "Shortfin Mako"},
		{"key": "blacktip", "name": "Blacktip Reef"},
		{"key": "tiger", "name": "Tiger Shark"},
		{"key": "hammerhead", "name": "Hammerhead"},
	],
	Family.PLANK: [
		{"key": "manta", "name": "Manta"},
		{"key": "eagle_ray", "name": "Spotted Eagle Ray"},
		{"key": "southern_stingray", "name": "Southern Stingray"},
		{"key": "ribbontail", "name": "Blue-spotted Ribbontail"},
	],
	Family.BREAKOUT: [
		{"key": "broadbill", "name": "Broadbill Swordfish"},
		{"key": "blue_marlin", "name": "Blue Marlin"},
		{"key": "sailfish", "name": "Sailfish"},
		{"key": "striped_marlin", "name": "Striped Marlin"},
	],
	Family.HYBRID: [
		{"key": "kohaku", "name": "Kohaku"},
		{"key": "showa", "name": "Showa"},
		{"key": "yamabuki", "name": "Yamabuki Ogon"},
		{"key": "asagi", "name": "Asagi"},
	],
	Family.MERC: [
		{"key": "yellow_boxfish", "name": "Yellow Boxfish"},
		{"key": "longhorn", "name": "Longhorn Cowfish"},
		{"key": "spotted_boxfish", "name": "Spotted Boxfish"},
		{"key": "scrawled", "name": "Scrawled Cowfish"},
	],
	Family.LIONFISH: [
		{"key": "red", "name": "Red Lionfish"},
		{"key": "clearfin", "name": "Clearfin Lionfish"},
		{"key": "fuzzy_dwarf", "name": "Fuzzy Dwarf"},
		{"key": "spotfin", "name": "Spotfin Lionfish"},
	],
	Family.MOON_JELLY: [
		{"key": "moon", "name": "Moon Jelly"},
		{"key": "sea_nettle", "name": "Pacific Sea Nettle"},
		{"key": "lions_mane", "name": "Lion's Mane"},
		{"key": "purple_striped", "name": "Purple-striped Jelly"},
	],
	Family.MANTIS: [
		{"key": "peacock", "name": "Peacock Mantis"},
		{"key": "zebra", "name": "Zebra Mantis"},
		{"key": "purple_spot", "name": "Purple-spot Mantis"},
		{"key": "pink_eared", "name": "Pink-eared Mantis"},
	],
	Family.WHALE_SHARK: [
		{"key": "indo_pacific", "name": "Whale Shark"},
		{"key": "deep_charcoal", "name": "Deep Charcoal"},
		{"key": "juvenile", "name": "Juvenile"},
		{"key": "basking", "name": "Basking Shark"},
	],
}


## "Clownfish": how the picker lists it (the hitbox's car name stays out of the UI).
static func display_name(family: Family) -> String:
	return CARS[family].fish


## How many skins `family` has (SKINS).
static func skin_count(family: Family) -> int:
	return (SKINS[family] as Array).size()


## Skin `skin` of `family`'s name, as the picker shows it ("Great White").
static func skin_name(family: Family, skin: int) -> String:
	return SKINS[family][clampi(skin, 0, skin_count(family) - 1)].name


## Skin `skin` of `family`'s key ("great_white"), for saves and replays.
static func skin_key(family: Family, skin: int) -> String:
	return SKINS[family][clampi(skin, 0, skin_count(family) - 1)].key


## The skin of `family` with `key`; its first if unknown.
static func skin_from_key(family: Family, key: String) -> int:
	var skins: Array = SKINS[family]
	for i in skins.size():
		if skins[i].key == key:
			return i
	return 0


## Whether the player may pick skin `skin` of `family`. Every skin for now;
## the one place a meta-progression unlock check slots in later (the pickers
## skip locked skins, the saved/remote/replay skins are taken as given).
static func is_skin_unlocked(_family: Family, _skin: int) -> bool:
	return true


## The family for a replay's hitbox_family key ("octane", ...); Octane if unknown.
static func from_key(key: String) -> Family:
	for family: Family in CARS:
		if CARS[family].key == key.to_lower():
			return family
	return Family.OCTANE


## Hitbox size (m) as the fish's exports have it: width, height, length.
static func hitbox_size(family: Family) -> Vector3:
	var h: Vector3 = CARS[family].hitbox
	return Vector3(h.y, h.z, h.x) * M_PER_UU


## Where the centre of mass is from the hitbox centre, in the fish's frame (m;
## nose -Z): behind and below it.
static func com_from_hitbox(family: Family) -> Vector3:
	var offset: Vector3 = CARS[family].offset
	return Vector3(0.0, -offset.z, offset.x) * M_PER_UU


## The four wheels (front left, front right, back left, back right): suspension
## mount in the fish's frame from the hitbox centre (m), wheel radius (m) and
## suspension rest length (m), as FishController's suspension reads them.
static func wheels(family: Family) -> Array[Dictionary]:
	var car: Dictionary = CARS[family]
	var offset: Vector3 = car.offset
	var result: Array[Dictionary] = []
	for end: String in ["front", "back"]:
		var wheel: Dictionary = car[end]
		var at: Vector3 = wheel.at
		for side: float in [-1.0, 1.0]:
			result.append({
				"mount": Vector3(side * at.y, at.z - offset.z, -(at.x - offset.x)) * M_PER_UU,
				"radius": wheel.radius * M_PER_UU,
				"rest": wheel.rest * M_PER_UU,
			})
	return result


## The axles' distances (m) ahead of and behind the centre of mass.
static func axles(family: Family) -> Vector2:
	var car: Dictionary = CARS[family]
	return Vector2(car.front.at.x, -car.back.at.x) * M_PER_UU


## The belly under the hitbox where the wheels are (m; width, height, length):
## as high as the car rides, as long and wide as its tyres reach.
static func belly(family: Family) -> Vector3:
	var car: Dictionary = CARS[family]
	var length: float = car.front.at.x + car.front.radius - car.back.at.x + car.back.radius
	var width: float = 2.0 * maxf(car.front.at.y, car.back.at.y) + 2.0 * TYRE_HALF_WIDTH
	return Vector3(width, car.ride, length) * M_PER_UU
