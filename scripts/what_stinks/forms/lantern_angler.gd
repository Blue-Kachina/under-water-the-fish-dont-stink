extends RefCounted
## Hunter form: Lantern Angler (planning_new_hunters.md phase D; the sheet's keys are in hunter_forms.md).
## A heavy-headed deep-sea ambusher: lantern_rig.gd wraps AnglerModel (D1's one spine-bent mesh with a shader-hinged jaw, needle teeth
## and a spring-chain lure stalk) and gives it the ambush gait (stiff body, slow pectoral scull, bursty tail snap, physical stalk).
## The Lure attack is D3's (attacks/lure_attack.gd); until it lands the sheet's attack is the plain chomp.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const LanternRig := preload("res://scripts/what_stinks/forms/lantern_rig.gd")

## The attack style the sheet names. D3 sets this to "lure" when `HunterAttack.STYLES` knows it.
const ATTACK := "lure"


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


## An ambusher: a short, sudden cone (the globe jaw opens wide), a long wind-up and a long rest between bites; slow to turn and
## to get going, but the tail snap lunge makes the speed. 7 m long (a big head on a real fish body); the camera sits back and high to keep the lure stalk in frame.
## Sound ids are stand-ins.
static func sheet() -> Dictionary:
	return {
		"name": "Lantern Angler", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 7.0, "speed": 1.1, "accel": 0.55, "turn": 0.5,
		"bite_reach_m": 3.2, "bite_radius_m": 2.2, "bite_wind": 0.9, "bite_every": 2.6,
		"capacity": 5.0, "cam": Vector2(1.0, 1.2), "attack": ATTACK,
		"sound_chomp": "boss/chomp", "sound_miss": "boss/chomp_miss",
	}


## The angler's body on the Hunter's fish after its look and size are set. Called every round, so a body already built at this
## length is kept; a size change builds it again.
static func dress(fish: FishController, _sheet: Dictionary) -> void:
	var visual := fish.get("_visual") as Node3D
	if visual == null:
		return
	var old := visual.get_node_or_null("LanternRig")
	if old != null:
		if absf(float(old.get("length")) - fish.hitbox_length) < fish.hitbox_length * 0.01:
			return
		visual.remove_child(old)
		old.queue_free()
	for node in visual.get_children():
		if node is Node3D:
			(node as Node3D).visible = false  # the shark the class wears
	var body: Node3D = LanternRig.new()
	visual.add_child(body)
	body.call("build", fish)
	visual.set_meta("hunter_jaw", body.get("jaw"))
	visual.set_meta("lantern_rig", body)
