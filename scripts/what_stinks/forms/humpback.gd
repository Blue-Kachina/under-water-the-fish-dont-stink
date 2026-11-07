extends RefCounted
## Hunter form: Humpback (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## The Titans' species 0 on a normal FishController (model, swim from speed and turn, hitbox all the Titan's own).
## Signature: Tail Slap as a shape of the Bite, not a second system: a short, very wide, slow-to-land sweep that
## takes a lot of fish at once (a cone about as wide as it is long, a long wind-up, a long cooldown), traded for
## the Shark's reach and speed. The numbers are first-guess defaults of settings, not tuned.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return {
		"name": "Humpback", "class": FishCharacter.FishClass.TITAN, "species": 0,
		"length_m": 6.7, "speed": 1.15, "accel": 0.6, "turn": 0.5,
		# Tail Slap: reach 2.2 m but 2.6 m half width at the far end (a ~100 degree cone), 6 fish, slow wind-up.
		"bite_reach_m": 2.2, "bite_radius_m": 2.6, "bite_wind": 0.95, "bite_every": 2.4,
		"capacity": 6.0,
		# Long body with a long fluke: the camera sits further back and a little higher than the shark's.
		"cam": Vector2(1.2, 1.1),
	}


## Extras on the Hunter's fish after its look and size are set (none: the Titan model is used as is). Called every round, so keep it safe to repeat.
static func dress(_fish: FishController, _sheet: Dictionary) -> void:
	pass
