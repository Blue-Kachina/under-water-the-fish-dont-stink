class_name FishTuning
extends RefCounted
## Fish tuning helpers shared by every mode.


## Copies `from`'s tunable settings (everything exported but the character and
## the hitbox view) onto `to`, so a bot plays by the same physics as the player.
static func copy(from: FishController, to: FishController) -> void:
	for property in from.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		if property.name in ["character", "show_hitbox"]:
			continue
		to.set(property.name, from.get(property.name))
