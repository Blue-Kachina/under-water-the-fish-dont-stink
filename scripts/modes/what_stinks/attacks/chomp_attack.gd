class_name ChompAttack
extends HunterAttack
## The Drowned Shark's style, the default (two-stage-attack.md 4a): the jaws gape on the press, tremble
## while held and slam shut on the release. The hold buys capacity and reach with the charge
## (WhatStinksSettings hold_capacity_mult, hold_reach_mult); the lunge is the snap's.


func _init() -> void:
	key = "chomp"


func reach_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.hold_reach_mult, charge)


func capacity_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.hold_capacity_mult, charge)


## Tap mode: close enough, press once. Hold mode: open on the way in, shut once a fish is in the
## frustum and the charge is up (or the fish is getting away); the Upset Stomach rule (a stinker in
## the frustum) holds the release back.
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.4 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_open_gap, "hold": false}
	var in_frustum := bite.in_bite(bot.target_at)
	var getting_away := gap > bot.target_prev_gap + 0.001 and gap <= bite.reach() * 1.2
	var gave_up := gap > bite.reach() * settings.hunter_bot_open_gap * 2.0
	var release := (in_frustum and bite.charge() >= settings.hunter_bot_charge) or getting_away or gave_up
	if bot.stinker_blocks and not gave_up:
		release = false
	return {"press": false, "hold": not release}


## The held bite was called off (or the Hunter went): the Shark's exaggeration rig lets go of its pose (forms/shark_rig.gd).
## Press, release and landing reach the rig through the bite's own signals, so a tap, a hold and a puppet all play it.
func on_cancel(bite: HunterBite) -> void:
	var model: Node = bite.fish.get("_visual") if is_instance_valid(bite.fish) else null
	var rig: Node = model.get_node_or_null("SharkRig") if model != null else null
	if rig != null:
		rig.call("cancel")
