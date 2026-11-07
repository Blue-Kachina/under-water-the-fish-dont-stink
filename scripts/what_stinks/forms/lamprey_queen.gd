extends RefCounted
## Hunter form: Lamprey Queen (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## LampreyBoss's look on a normal FishController (the hidden MONSTER class's box, the shark's model hidden):
## lamprey_rig.gd lays the boss's one spine-bent mesh along the trail the head leaves, lamprey_jaw.gd flares
## its oral disc from the bite. The bite is the Corkscrew latch: a narrow, short cone that takes one fish (her
## prey), wound up as the disc flares; when it lands the disc clamps and she rolls round her length.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const LampreyRig := preload("res://scripts/what_stinks/forms/lamprey_rig.gd")
const LampreyJaw := preload("res://scripts/what_stinks/forms/lamprey_jaw.gd")


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


## Corkscrew latch (hunter_forms.md): reach 3.2 m, 1.0 m half width at the far end (about 17 degrees, the
## shark's is 25), capacity 1 (one target, the size's capacity exponent lifts it at larger sizes), 0.8 s wind-up
## and 3.0 s before the next (she holds on and rolls for `latch_s` of that). Length 14 m (the boss is ~88 m), a
## long slender swimmer: slower to turn than the shark. The camera sits further back and higher so the
## trailing body is seen. The sound ids are stand-ins from the boss's (boss/*).
static func sheet() -> Dictionary:
	return {
		"name": "Lamprey Queen", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 14.0, "speed": 1.2, "accel": 0.6, "turn": 0.45,
		"bite_reach_m": 3.2, "bite_radius_m": 1.0, "bite_wind": 0.8, "bite_every": 3.0,
		"capacity": 1.0, "cam": Vector2(0.9, 1.3), "latch_s": 1.1,
		"sound_chomp": "boss/grab", "sound_arrive": "boss/leviathan_arrive", "sound_miss": "boss/chomp_miss",
	}


## The Queen's body on the Hunter's fish after its look and size are set. Called every round, so a body already
## built at this length is kept; a size change builds it again.
static func dress(fish: FishController, sheet_now: Dictionary) -> void:
	var visual := fish.get("_visual") as Node3D
	if visual == null:
		return
	var old := visual.get_node_or_null("LampreyRig")
	if old != null:
		if absf(float(old.get("length")) - fish.hitbox_length) < fish.hitbox_length * 0.01:
			old.set("chomp_sound", str(sheet_now.get("sound_chomp", "")))
			old.set("latch_time", float(sheet_now.get("latch_s", 1.1)))
			return
		visual.remove_child(old)
		old.queue_free()
	for node in visual.get_children():
		if node is Node3D:
			(node as Node3D).visible = false  # the shark the class wears
	var body: Node3D = LampreyRig.new()
	body.name = "LampreyRig"
	body.set("chomp_sound", str(sheet_now.get("sound_chomp", "")))
	body.set("latch_time", float(sheet_now.get("latch_s", 1.1)))
	visual.add_child(body)
	body.call("build", fish)
	var jaw := LampreyJaw.new()
	jaw.rig = body
	visual.set_meta("hunter_jaw", jaw)
