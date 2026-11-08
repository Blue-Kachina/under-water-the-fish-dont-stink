extends RefCounted
## Hunter form: Ember Octopus (planning_new_hunters.md phase C; the sheet's keys are in hunter_forms.md).
## A giant wine-red octopus glowing with ember sparks: octopus_rig.gd wraps OctopusModel (skinned, 118 bones) and gives it the hybrid
## gait: it swims mantle first, the arms trailing in a flat swept-back delta (planning_hunter_refine.md), on siphon-vectored jet pulses
## (real thrust and torque in the fish's physics tick), a cruise undulation, a dash jet with the arms bundled tight, and an arm crawl near
## a surface. Its attack is the Grapple (attacks/grapple_attack.gd, style "grapple"): press shoots a tentacle, hold tows and grabs
## more fish, release eats them all.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const OctopusRigScript := preload("res://scripts/what_stinks/forms/octopus_rig.gd")

## The attack style the sheet names (registered in `HunterAttack.STYLES`).
const ATTACK := "grapple"


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
## The model and gait are built; the registry should only list it once the attack and integration (C3, C4) land.
static func ready() -> bool:
	return true


## A jet swimmer: quick to burst, slow to get going from rest and to turn (the jet does the work), short reach (the arms are the
## weapon). 6 m long, mantle tip to the trailing arm tips; the camera sits back and a little high to keep the trailing arms in frame.
## The hitbox is the MONSTER class box at this length (about 2.8 x 2 x 6 m): the delta's arm tips spread to about 4 m wide at rest and
## 3.3 m while jetting, a little past the box's sides; soft arm tips, so the box is kept. Sound ids are stand-ins.
static func sheet() -> Dictionary:
	return {
		"name": "Ember Octopus", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 6.0, "speed": 1.15, "accel": 0.45, "turn": 0.6,
		"bite_reach_m": 3.4, "bite_radius_m": 2.6, "bite_wind": 0.85, "bite_every": 2.4,
		"capacity": 5.0, "cam": Vector2(1.05, 1.2), "attack": ATTACK,
		"sound_chomp": "boss/chomp", "sound_miss": "boss/chomp_miss",
	}


## The octopus's body on the Hunter's fish after its look and size are set. Called every round, so a body already built at this
## length is kept; a size change builds it again.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	var visual := fish.get("_visual") as Node3D
	if visual == null:
		return
	var old := visual.get_node_or_null("OctopusRig")
	if old != null:
		if absf(float(old.get("length")) - fish.hitbox_length) < fish.hitbox_length * 0.01:
			return
		visual.remove_child(old)
		old.queue_free()
	for node in visual.get_children():
		if node is Node3D:
			(node as Node3D).visible = false  # the shark the class wears
	var body: Node3D = OctopusRigScript.new()
	visual.add_child(body)
	body.call("build", fish)
	visual.set_meta("octopus_rig", body)
