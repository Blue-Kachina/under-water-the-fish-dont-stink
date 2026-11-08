extends RefCounted
## Hunter form: Sperm Whale (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Engulf like the rest: a narrow hinged lower jaw of teeth under the huge box head. Numbers are a first guess from titan_specs.md (length scaled from the humpback's 6.7 m), for play-testing.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return {
		"name": "Sperm Whale", "class": FishCharacter.FishClass.TITAN, "species": 3,
		"length_m": 7.7, "speed": 1.1, "accel": 0.6, "turn": 0.5,
		"bite_reach_m": 2.5, "bite_radius_m": 1.7, "bite_wind": 0.75, "bite_every": 2.6,
		"capacity": 5.0, "cam": Vector2(1.1, 1.05),
		"attack": "engulf",
	}


## The hinged jaw (WhaleJaw: meta hunter_jaw), the same one every round. Called every round, so keep it safe to repeat.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	WhaleJaw.wear(fish)
