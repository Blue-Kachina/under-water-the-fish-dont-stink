extends RefCounted
## Hunter form: Drowned Shark (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Done (Phase 0): the hidden class MONSTER, HunterFormModel, HunterJaw, HunterBite.
## Phase B2: the chomp's exaggeration (shark_rig.gd on AttackExaggerate): the head thrusts, the jaw unhinges wider, the teeth
## row grows, the eyes flare. This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).

const SharkRig := preload("res://scripts/what_stinks/forms/shark_rig.gd")

## The shark's own tuning of the exaggeration kit (channels: the kit's names; "teeth" and "eye" are the shark's). Peaks are
## multiples of rest at hunter_exaggeration 1; the master and the sheet's "exaggeration" scale the departure from 1.
const EXAGGERATE := {
	"snap_omega": 32.0, "snap_zeta": 0.7, "snap_time": 0.09,
	"channels": {
		"jaw": {"hold_peak": 2.2, "squash": 0.78, "release_peak": 0.7, "omega": 24.0, "zeta": 0.38},
		"head": {"hold_peak": 1.8, "squash": 0.8, "release_peak": 2.4, "omega": 20.0, "zeta": 0.4, "volume": 0.5},
		"teeth": {"hold_peak": 1.9, "squash": 0.85, "release_peak": 2.5, "omega": 20.0, "zeta": 0.35, "volume": 0.0},
		"eye": {"hold_peak": 1.8, "squash": 0.8, "release_peak": 2.3, "omega": 18.0, "zeta": 0.4, "volume": 0.0},
	},
}


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	var out := HunterForm.SHARK.duplicate(true)
	out["exaggerate"] = EXAGGERATE.duplicate(true)
	return out


## Extras on the Hunter's fish after its look and size are set: the chomp's exaggeration rig on the model. Called every
## round, so a rig already on this model is kept (and re-reads the panel's tuning).
static func dress(fish: FishController, sheet_now: Dictionary) -> void:
	var visual := fish.get("_visual") as Node3D
	if visual == null:
		return
	var old := visual.get_node_or_null("SharkRig")
	if old != null:
		old.call("build", fish, sheet_now)
		return
	var rig: Node = SharkRig.new()
	visual.add_child(rig)
	rig.call("build", fish, sheet_now)
