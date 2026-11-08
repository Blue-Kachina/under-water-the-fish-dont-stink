extends RefCounted
## Hunter form: Gulper Mother (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## The final boss's eel as a Hunter: the hidden class MONSTER (the shark's box) wearing the boss's own
## mesh and skin (gulper_model.gd) bent by gulper_rig.gd from the controller's speed and turn, with
## a wide, slow, greedy bite: Swallow, a vacuum cone (see sheet()).
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const RIG := preload("res://scripts/what_stinks/forms/gulper_rig.gd")


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


## Swallow: a wide vacuum cone (the held bite is the suction style, attacks/suction_attack.gd: the pull in, the snap shut). Against the shark's chomp (reach 3.5 m, far half width 1.6 m, 4 fish, wind-up
## 0.75 s, every 2.0 s) it reaches nearly twice as far and a good deal wider (a 33 degree half angle at the far
## end), takes twice the fish, but opens slowly (the suction streaks and the gaping pouch are the tell) and
## rests longer. A slower, heavier swimmer than the shark; the camera sits further back and higher for the pouch.
static func sheet() -> Dictionary:
	return {
		"name": "Gulper Mother", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 9.0, "speed": 1.15, "accel": 0.6, "turn": 0.5,
		"bite_reach_m": 6.0, "bite_radius_m": 4.0, "bite_wind": 1.0, "bite_every": 2.5,
		"capacity": 8.0, "cam": Vector2(1.15, 1.1), "attack": "suction",
	}


## Swaps the shark's model for the Gulper's body (the shark's parts stay, hidden: the controller still animates them).
## Called every round, so a model that already wears the Gulper is left as it is.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	var model: Node3D = fish.get("_visual")
	if model == null or model.has_meta("gulper_rig"):
		return
	for child in model.get_children():
		if child is Node3D:
			(child as Node3D).visible = false
	var rig := RIG.new()
	model.add_child(rig)
	rig.setup(fish)
	model.set_meta("hunter_jaw", rig.jaw)  # HunterBite opens the pouch through it and bites from its mouth
	model.set_meta("gulper_rig", rig)
