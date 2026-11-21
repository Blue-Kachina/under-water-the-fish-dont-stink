class_name TestTankRun
extends UnnaturalRun
## The Test Tank: Unnatural's shooting range (an UnnaturalRun with test_tank set), its own mode id
## and picker tile. Immortal dummies, every stat to set, a DPS readout (TestTank).


func _init() -> void:
	test_tank = true


static func descriptor() -> Dictionary:
	return {
		"id": "Test Tank", "title": "Test Tank", "icon": "mode_test_tank",
		"colors": [Color(0.12, 0.08, 0.2), Color(0.75, 0.55, 1.0)],
		"pitch": "Unnatural's shooting range: dummies to hit, every stat to set, and a DPS readout.",
		"short": "Dummies and a DPS readout", "play": ["Solo"],
		"environment": "Ocean", "match": true, "after": "Unnatural", "tile_before": "Marco Polo",
		"tuning_preset": "res://presets/nature.cfg",
		"card_text": TestTankRun.card_text, "reset_label": "Reset the tank", "split_screen": true,
		"sfx": [[UnnaturalSounds, &"sfx_hook"]],
	}


static func card_text() -> String:
	return "Test Tank: Unnatural's shooting range. Immortal dummies wait ahead (a cluster, and lines at 10, 20 and 40 m) and the DPS readout shows each damage source. Set your level, every stat, the dummies and a chasing horde in the tuning panel's UNNATURAL > Test Tank. R resets."


func enter(world: ModeWorld) -> void:
	name = "TestTank"
	super.enter(world)
