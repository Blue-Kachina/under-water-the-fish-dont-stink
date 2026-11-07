extends RefCounted
## Hunter form: Drowned Shark (what_stinks.md section 2; the sheet's keys are in hunter_forms.md).
## Done (Phase 0): the hidden class MONSTER, HunterFormModel, HunterJaw, HunterBite.
## This file is the form's own: its sheet, its ready flag and its dress hook (see HunterForms).


## Offered on the match card only once this is true (the form plays end to end: model, swim, bite, camera, hitbox).
static func ready() -> bool:
	return true


static func sheet() -> Dictionary:
	return HunterForm.SHARK


## Extras on the Hunter's fish after its look and size are set (none yet). Called every round, so keep it safe to repeat.
static func dress(_fish: FishController, _sheet: Dictionary) -> void:
	pass
