extends RefCounted
## Hunter form: Whale Fall (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## The final boss's dead whale as a Hunter: the hidden class MONSTER (the shark's box) wearing the boss's own
## carcass and giant hagfish (whalefall_model.gd) driven by whalefall_rig.gd from the controller's speed and
## turn, with a short, wide, slow bite: Hagfish knot. The hagfish lash into the cone, tie themselves in a
## knot and leave a cloud of slime that scatters fish (see sheet()).
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const RIG := preload("res://scripts/what_stinks/forms/whalefall_rig.gd")


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
## Switched off for now (2026-11-07): the idea doesn't fit yet; flip back to true to bring it back.
static func ready() -> bool:
	return false


## Hagfish knot: against the shark's chomp (reach 3.5 m, far half width 1.6 m, 4 fish, wind-up 0.75 s, every
## 2.0 s) a short, wide cone (a 39 degree half angle at the far end), 6 fish, slow to open (the hagfish rear
## back and glow: the tell) and a long rest. The carcass is a heavy drifter (speed 0.9, accel 0.5, turn 0.45),
## so the fish it takes are the ones that stay near; the slime that scatters the rest is a hook for the mode
## (the rig's `slimed` signal and the model's "hunter_cloud" meta). The camera sits further back and higher
## for the ropes. The sound ids are stand-ins from the boss's (boss/*).
static func sheet() -> Dictionary:
	return {
		"name": "Whale Fall", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 12.0, "speed": 0.9, "accel": 0.5, "turn": 0.45,
		"bite_reach_m": 4.5, "bite_radius_m": 3.6, "bite_wind": 0.9, "bite_every": 2.6,
		"capacity": 6.0, "cam": Vector2(1.25, 1.15),
		"sound_slime": "boss/leviathan_spit", "sound_grab": "boss/grab", "sound_arrive": "boss/leviathan_arrive",
	}


## Swaps the shark's model for the carcass and its hagfish (the shark's parts stay, hidden: the controller still
## animates them). Called every round, so a model that already wears the Whale Fall is left as it is.
static func dress(fish: FishController, sheet_now: Dictionary) -> void:
	var model: Node3D = fish.get("_visual")
	if model == null:
		return
	var old: Node = model.get_meta("whalefall_rig") if model.has_meta("whalefall_rig") else null
	if old != null and is_instance_valid(old):
		old.set("sheet", sheet_now)
		return
	for child in model.get_children():
		if child is Node3D:
			(child as Node3D).visible = false
	var rig: Node3D = RIG.new()
	model.add_child(rig)
	rig.set("slime_sound", str(sheet_now.get("sound_slime", "")))
	rig.call("setup", fish, sheet_now)
	model.set_meta("hunter_jaw", rig.get("jaw"))  # HunterBite bites from its mouth and reads its open
	model.set_meta("whalefall_rig", rig)
	model.set_meta("hunter_cloud", rig)
