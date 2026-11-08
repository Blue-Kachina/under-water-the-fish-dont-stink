extends RefCounted
## Hunter form: Beluga (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Engulf like the rest: the smallest mouth, peg teeth. Numbers are a first guess from titan_specs.md (length scaled from the humpback's 6.7 m), for play-testing.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return {
		"name": "Beluga", "class": FishCharacter.FishClass.TITAN, "species": 2,
		"length_m": 2.2, "speed": 1.2, "accel": 0.7, "turn": 0.55,
		"bite_reach_m": 0.75, "bite_radius_m": 0.6, "bite_wind": 0.75, "bite_every": 1.8,
		"capacity": 3.0, "cam": Vector2(1.0, 1.0),
		"attack": "engulf",
	}


## The hinged jaw (WhaleJaw: meta hunter_jaw), the same one every round. Called every round, so keep it safe to repeat.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	WhaleJaw.wear(fish)
