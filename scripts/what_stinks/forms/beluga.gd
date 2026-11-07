extends RefCounted
## Hunter form: Beluga (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Stub: numbers are a first guess from titan_specs.md (length scaled from the humpback's 6.7 m), not checked. Flip ready() once it passes hunter_forms_probe and has been looked at.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return false


static func sheet() -> Dictionary:
	return {
		"name": "Beluga", "class": FishCharacter.FishClass.TITAN, "species": 2,
		"length_m": 2.2, "speed": 1.3, "accel": 0.7, "turn": 0.55,
		"bite_reach_m": 1.1, "bite_radius_m": 0.5, "bite_wind": 0.75, "bite_every": 2.0,
		"capacity": 4.0, "cam": Vector2(1.0, 1.0),
	}


## Extras on the Hunter's fish after its look and size are set (none yet). Called every round, so keep it safe to repeat.
static func dress(_fish: FishController, _sheet: Dictionary) -> void:
	pass
