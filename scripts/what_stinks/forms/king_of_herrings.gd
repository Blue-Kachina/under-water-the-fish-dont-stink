extends RefCounted
## Hunter form: King of Herrings (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## BloodLeviathan's look on a normal FishController (the hidden MONSTER class's box, the shark's model hidden):
## king_rig.gd lays the boss's one spine-bent mesh along the trail the head leaves, king_jaw.gd gapes its jaw
## from the bite. The bite is the Coil sweep: a short, very wide cone that takes a big mouthful, slow to wind up.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const KingRig := preload("res://scripts/what_stinks/forms/king_rig.gd")
const KingJaw := preload("res://scripts/what_stinks/forms/king_jaw.gd")


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


## Coil sweep (hunter_forms.md): the cone opens to a 4.5 m half width over 5.5 m (about 39 degrees, wider than
## the shark's 24), 7 fish a bite, 1.0 s wind-up and 2.8 s between bites: it takes more but is slower to start
## and to come back. Length 16 m (the boss is ~109 m: a Hunter's box cannot hold that; the probe wants the mesh to
## match the hitbox). Slower to turn than the shark: a long eel. The camera sits a little closer (a slim body is a small share of the screen) and higher, so the body
## trailing behind it is seen from above. The sound ids are stand-ins from the boss's (boss/*).
static func sheet() -> Dictionary:
	return {
		"name": "King of Herrings", "class": FishCharacter.FishClass.MONSTER, "species": 0,
		"length_m": 16.0, "speed": 1.2, "accel": 0.6, "turn": 0.45,
		"bite_reach_m": 5.5, "bite_radius_m": 4.5, "bite_wind": 1.0, "bite_every": 2.8,
		"capacity": 7.0, "cam": Vector2(0.8, 1.35),
		"sound_chomp": "boss/chomp", "sound_arrive": "boss/leviathan_arrive", "sound_miss": "boss/chomp_miss",
		"sound_grab": "boss/grab",
	}


## The King's body on the Hunter's fish after its look and size are set. Called every round, so a body already
## built at this length is kept; a size change builds it again.
static func dress(fish: FishController, sheet_now: Dictionary) -> void:
	var visual := fish.get("_visual") as Node3D
	if visual == null:
		return
	var old := visual.get_node_or_null("KingRig")
	if old != null:
		if absf(float(old.get("length")) - fish.hitbox_length) < fish.hitbox_length * 0.01:
			old.set("chomp_sound", str(sheet_now.get("sound_chomp", "")))
			return
		visual.remove_child(old)
		old.queue_free()
	for node in visual.get_children():
		if node is Node3D:
			(node as Node3D).visible = false  # the shark the class wears
	var body: Node3D = KingRig.new()
	body.name = "KingRig"
	body.set("chomp_sound", str(sheet_now.get("sound_chomp", "")))
	visual.add_child(body)
	body.call("build", fish)
	var jaw := KingJaw.new()
	jaw.rig = body
	visual.set_meta("hunter_jaw", jaw)
