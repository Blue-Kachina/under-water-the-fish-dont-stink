extends RefCounted
## Hunter form: Humpback (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## The Titans' species 0 on a normal FishController (model, swim from speed and turn, hitbox all the Titan's own).
## Signature: the engulf (two-stage-attack.md 4b): the press drops a huge hinged jaw and anything that swims into the
## mouth is held in it, the release slams it shut on all of it. The reach and radius size the mouth's box (a Tail Slap
## shaped cone as a sheet: short, very wide), and the cooldown is long. The numbers are first-guess defaults of settings.
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
		"capacity": 6.0, "attack": "engulf",
		# Long body with a long fluke: the camera sits further back and a little higher than the shark's.
		"cam": Vector2(1.2, 1.1),
	}


## The hinged jaw (WhaleJaw: meta hunter_jaw), the same one every round. Called every round, so keep it safe to repeat.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	WhaleJaw.wear(fish)
