extends RefCounted
## Hunter form: Fallen Angel (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## The final boss's glass sea angel as a Hunter: the hidden class MONSTER (the shark's box) wearing the boss's own
## look (angel_model.gd) bent by angel_rig.gd from the controller's speed and turn, with a narrow, long, patient
## bite: Lock-on (see sheet()).
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const RIG := preload("res://scripts/what_stinks/forms/angel_rig.gd")


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


## Lock-on, as a shape of the Bite: a thin, long cone, slow to wind up, that takes few fish. Against the shark's
## chomp (reach 3.5 m, far half width 1.6 m, 4 fish, wind-up 0.75 s, every 2.0 s) it reaches further and a great
## deal narrower (an 11 degree half angle at the far end), takes half the fish and needs the crown's slow opening
## (the lock-on ring closing on the end of the cone is the tell) held on its target: aim, not sweep. A light, agile
## swimmer (it hangs and turns on its wings); the camera sits a little back and above for the long glass body.
## The sound ids are stand-ins from the boss's (boss/*), no consumer yet.
static func sheet() -> Dictionary:
	return {
		"name": "Fallen Angel", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 10.0, "speed": 1.2, "accel": 0.65, "turn": 0.7,
		"bite_reach_m": 6.5, "bite_radius_m": 1.3, "bite_wind": 1.2, "bite_every": 2.2,
		"capacity": 2.0, "cam": Vector2(1.1, 1.15), "cam_settle": 0.65, "attack": "lock",
		"sound_chomp": "boss/chomp", "sound_lock": "boss/angel_lock", "sound_miss": "boss/chomp_miss",
	}


## Swaps the shark's model for the angel's body (the shark's parts stay, hidden: the controller still animates them).
## Called every round, so a model that already wears the angel is left as it is.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	var model: Node3D = fish.get("_visual")
	if model == null or model.has_meta("angel_rig"):
		return
	for child in model.get_children():
		if child is Node3D:
			(child as Node3D).visible = false
	var rig := RIG.new()
	model.add_child(rig)
	rig.setup(fish)
	model.set_meta("hunter_jaw", rig.jaw)  # HunterBite opens the crown through it and bites from its base
	model.set_meta("angel_rig", rig)
