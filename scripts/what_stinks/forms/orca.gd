extends RefCounted
## Hunter form: Orca (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Engulf like the rest: a mouth of conical teeth (small, fast, agile). Numbers are a first guess from titan_specs.md (length scaled from the humpback's 6.7 m), for play-testing.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return {
		"name": "Orca", "class": FishCharacter.FishClass.TITAN, "species": 1,
		"length_m": 3.6, "speed": 1.3, "accel": 0.7, "turn": 0.55,
		"bite_reach_m": 1.2, "bite_radius_m": 1.0, "bite_wind": 0.75, "bite_every": 2.0,
		"capacity": 4.0, "cam": Vector2(1.0, 1.0),
		"attack": "engulf",
		# Attack exaggeration (AttackExaggerate over WhaleJaw's whale preset, B1): snappy jaw, big teeth pop, lunge
		"exaggerate": {"channels": {"jaw": {"hold_peak": 2.3, "omega": 30.0}, "teeth": {"hold_peak": 1.7, "release_peak": 2.8}, "tail": {"release_peak": 2.1}, "throat": {"hold_peak": 1.6}}},
	}


## The hinged jaw (WhaleJaw: meta hunter_jaw), the same one every round. Called every round, so keep it safe to repeat.
static func dress(fish: FishController, sheet: Dictionary) -> void:
	WhaleJaw.wear(fish, sheet)
