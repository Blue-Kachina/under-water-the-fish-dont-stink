extends RefCounted
## Hunter form: Blue Whale (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Engulf like the rest: the biggest mouth, baleen, a slow heavy swimmer. Numbers are a first guess from titan_specs.md (length scaled from the humpback's 6.7 m), for play-testing.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return {
		"name": "Blue Whale", "class": FishCharacter.FishClass.TITAN, "species": 4,
		"length_m": 12.0, "speed": 1.05, "accel": 0.45, "turn": 0.4,
		"bite_reach_m": 4.0, "bite_radius_m": 4.4, "bite_wind": 0.75, "bite_every": 3.0,
		"capacity": 9.0, "cam": Vector2(1.3, 1.2),
		"attack": "engulf",
	}


## The hinged jaw (WhaleJaw: meta hunter_jaw), the same one every round. Called every round, so keep it safe to repeat.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	WhaleJaw.wear(fish)
