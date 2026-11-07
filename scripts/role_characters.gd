class_name RoleCharacters
extends RefCounted
## The character last played in each role (a mode's "default" one, or Marco Polo's
## seeker / hider, What Stinks?'s hunter / prey), so the character screens open on
## it. Kept beside the playground settings ([roles] character_<role>, and
## species_<role>_<class key> for the species worn in it); a role that's never
## been played falls back to the last character picked anywhere.

const PATH := "user://playground.cfg"
const DEFAULT := "default"
const SECTION := "roles"


## The character last played in `role`.
static func character(role: String) -> FishCharacter.FishClass:
	var settings := _load()
	var fallback: String = str(settings.get_value("playground", "character", ""))
	var key: String = str(settings.get_value(SECTION, "character_" + role, fallback))
	var picked := FishCharacter.from_key(key) if key != "" else FishCharacter.FishClass.SKIRMISHER
	var pickable := FishCharacter.pickable_classes()
	return picked if picked in pickable else pickable[0]


## The species of `fish_class` last worn in `role`.
static func species(role: String, fish_class: FishCharacter.FishClass) -> int:
	var settings := _load()
	var entry: Dictionary = FishCharacter.CLASSES[fish_class]
	var key: String = str(settings.get_value(SECTION, "species_%s_%s" % [role, entry.key], ""))
	if key == "":
		key = str(settings.get_value("playground", "species_" + entry.key, ""))
	var picked := FishCharacter.species_from_key(fish_class, key)
	return picked if FishCharacter.is_species_unlocked(fish_class, picked) else 0


## Remembers `fish_class` in `species` as `role`'s.
static func store(role: String, fish_class: FishCharacter.FishClass, species_index: int) -> void:
	var settings := _load()
	var entry: Dictionary = FishCharacter.CLASSES[fish_class]
	settings.set_value(SECTION, "character_" + role, entry.key)
	settings.set_value(SECTION, "species_%s_%s" % [role, entry.key], FishCharacter.species_key(fish_class, species_index))
	settings.save(PATH)


## What the Hunter form last played in `role` was (a key of its pool), or "".
static func form(role: String) -> String:
	return str(_load().get_value(SECTION, "form_" + role, ""))


static func store_form(role: String, key: String) -> void:
	var settings := _load()
	settings.set_value(SECTION, "form_" + role, key)
	settings.save(PATH)


static func _load() -> ConfigFile:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return settings
