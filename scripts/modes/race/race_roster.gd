class_name RaceRoster
extends RefCounted
## Every playable model as a racer (planning_race.md section 2). entries() reads the existing lists (FishCharacter's
## classes and species, HunterForms.FORMS, the Titans' species and skins) and keeps no copy, so a new model shows up in
## the race by itself. Every racer is one FishController: dress() puts the look and the size cap on a fish that exists,
## so the shared speed and handling (RaceSettings, RaceHandling) work the same for all of them.
##
## Families (the setup screen's groups):
##   FISH    each pickable FishCharacter class x species (the "skins": species is the model's look); the Breacher's calves
##           are fish. 46 entries.
##   HUNTER  the ready HunterForms that wear the MONSTER class (Drowned Shark, King of Herrings, Gulper Mother, Lamprey
##           Queen, Fallen Angel, Ember Octopus, Lantern Angler). The whale forms (Humpback...Blue) are the TITANs below
##           (same body), so they aren't listed twice. 7 entries.
##   TITAN   the adult whales (FishClass.TITAN, "Titans" in Marco Polo) x species x skin. 5 species x 3 skins = 15 entries.
## Entry keys: unique, stable strings for saves and nets, "fish/<class key>/<species key>",
## "hunter/<form key>", "titan/<species key>/<skin index>".
##
## An entry: {"family", "key", "label", "class": FishClass, "species": int, "skin": int, "form": String (hunters),
##   "length_m": natural body length (m), "scale": body scale at the size cap (<= 1 is a cap, 1 = true size),
##   "skill_class": FishClass whose mobility skill it uses, "build": Callable(FishController) -> void (same as dress)}.

const FISH := "fish"
const HUNTER := "hunter"
const TITAN := "titan"
const FAMILIES := [FISH, HUNTER, TITAN]
## The family names on the setup screen.
const FAMILY_NAMES := {FISH: "Fish", HUNTER: "Hunters", TITAN: "Titans"}
## The modifier set dress() pushes for the cap (RaceMatch.MODS_SIZE): {"body": scale}.
const MODS_SIZE := "race.size"
## titan_model.gd has no class_name (FishModel loads it by path too).
const TITAN_MODEL := "res://scripts/fish_models/titan_model.gd"


## Every entry, grouped by family in FAMILIES order (fish classes in FishClass order, then species).
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fish_class: FishCharacter.FishClass in FishCharacter.pickable_classes():
		if fish_class == FishCharacter.FishClass.MONSTER:
			continue  # the Hunters' own body (the forms below)
		for species in FishCharacter.species_count(fish_class):
			out.append(_fish_entry(fish_class, species))
	for key: String in HunterForms.ready_keys():
		var sheet := HunterForms.sheet(key)
		if int(sheet["class"]) == FishCharacter.FishClass.MONSTER:
			out.append(_hunter_entry(key, sheet))
	var titans := FishCharacter.FishClass.TITAN
	for species in FishCharacter.species_count(titans):
		for skin in (load(TITAN_MODEL) as GDScript).call("skin_keys", species).size():
			out.append(_titan_entry(species, skin))
	return out


## The entries of one family.
static func of_family(family: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries():
		if e["family"] == family:
			out.append(e)
	return out


## The entry with `key` ({} when none).
static func find(key: String) -> Dictionary:
	for e in entries():
		if e["key"] == key:
			return e
	return {}


## The entry a fish wears now ({} when it matches none): its class, species and skin (Titans), or the hunter form.
static func entry_of(fish: FishController, form := "") -> Dictionary:
	for e in entries():
		if form != "":
			if e["form"] == form:
				return e
		elif e["form"] == "" and int(e["class"]) == int(fish.character) and int(e["species"]) == fish.species \
				and (e["family"] != TITAN or int(e["skin"]) == fish.skin):
			return e
	return {}


## The body scale that fits `length_m` under `cap` (m): 1 when it already fits or the cap is off (0).
static func cap_scale(length_m: float, cap: float) -> float:
	return 1.0 if cap <= 0.0 or length_m <= cap else cap / length_m


## Puts `entry` on `fish`: its look, then the size cap as the "race.size" modifier {"body": scale} (and the Hunter
## form's own rig through HunterForms.dress). The hitbox follows the body scale (FishController._apply_size). It does
## NOT push the form's speed, accel or turn: those are shared (RaceSettings) or RaceHandling's. `cap` is the longest
## body allowed (m), 0 for none. Safe to call twice.
static func dress(fish: FishController, entry: Dictionary, cap: float) -> void:
	fish.set_look(int(entry["class"]) as FishCharacter.FishClass, int(entry["species"]), int(entry["skin"]))
	var natural := float(entry["length_m"])
	var scale := cap_scale(natural, cap) * (natural / FishCharacter.hitbox_size(int(entry["class"]) as FishCharacter.FishClass).z)
	fish.modifiers.push(MODS_SIZE, {"body": scale})
	if str(entry["family"]) == HUNTER:
		HunterForms.dress(fish, str(entry["form"]))
	var model: Node = fish.get("_visual")
	if model != null and model.has_meta("titan_lod_rescale"):
		(model.get_meta("titan_lod_rescale") as Callable).call(fish.body_scale)


static func _fish_entry(fish_class: FishCharacter.FishClass, species: int) -> Dictionary:
	var length := FishCharacter.hitbox_size(fish_class).z
	return _make(FISH, "fish/%s/%s" % [FishCharacter.CLASSES[fish_class]["key"], FishCharacter.species_key(fish_class, species)],
			FishCharacter.full_name(fish_class, species), fish_class, species, 0, "", length, fish_class)


static func _hunter_entry(key: String, sheet: Dictionary) -> Dictionary:
	return _make(HUNTER, "hunter/%s" % key, str(sheet["name"]), int(sheet["class"]) as FishCharacter.FishClass,
			int(sheet["species"]), 0, key, float(sheet["length_m"]), FishCharacter.FishClass.SKIRMISHER)


static func _titan_entry(species: int, skin: int) -> Dictionary:
	var titans := FishCharacter.FishClass.TITAN
	var label := "%s  ·  %s" % [FishCharacter.species_name(titans, species), ((load(TITAN_MODEL) as GDScript).call("skin_names", species) as Array)[skin]]
	return _make(TITAN, "titan/%s/%d" % [FishCharacter.species_key(titans, species), skin], label, titans, species, skin, "",
			FishCharacter.hitbox_size(titans).z, FishCharacter.FishClass.SKIRMISHER)


static func _make(family: String, key: String, label: String, fish_class: FishCharacter.FishClass, species: int,
		skin: int, form: String, length_m: float, skill_class: FishCharacter.FishClass) -> Dictionary:
	var entry := {"family": family, "key": key, "label": label, "class": fish_class, "species": species, "skin": skin,
			"form": form, "length_m": length_m, "scale": cap_scale(length_m, RaceSettings.shared().race_size_cap),
			"skill_class": skill_class}
	entry["build"] = func(fish: FishController) -> void: RaceRoster.dress(fish, entry, RaceSettings.shared().race_size_cap)
	return entry
