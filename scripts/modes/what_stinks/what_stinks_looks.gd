class_name WhatStinksLooks
extends HiderLooks
## The Hunter's view of the prey in What Stinks? (what_stinks.md section 4): the
## same reveal layers as Marco Polo (HiderLooks: nothing, skeleton, heart,
## muscle, skin, aura), built up by WhatStinksEcho's exposure instead of a
## MarcoPoloMatch's. Binds to a WhatStinksMatch, which answers the same few
## questions (local_view_role, is_live_hider, local_exposure, max_exposure,
## seekers, local_fish, players); none of Marco Polo's scan pulse, murk view,
## wake or pick card come with it.
##
## Two differences from Marco Polo:
## - a prey player joined to a school has its own model hidden (the school fish
##   it stands in for shows). In the Hunter's view its model is turned back on
##   under the reveal, so the faint skeleton (and later the rest) builds on the
##   claimed slot, over the school fish that is drawn there as ever;
## - settings.hunter_blind off: the Hunter sees everyone as normal.

var ws_settings := WhatStinksSettings.shared()


func bind(stinks_match: Node) -> void:
	match_node = stinks_match
	settings = MarcoPoloSettings.shared()  # the layer bands and the self view
	for entry: Dictionary in stinks_match.get_signal_list():
		if entry.name in ["local_role_changed", "role_changed", "round_started", "spectate_target_changed", "eaten_fish"]:
			stinks_match.connect(entry.name, _on_roles_changed.unbind((entry.args as Array).size()))


func _refresh(delta: float) -> void:
	if not is_instance_valid(match_node):
		return
	var game := match_node as WhatStinksMatch
	if game == null:
		return
	if not ws_settings.hunter_blind and game.local_view_role() == WhatStinksMatch.Role.HUNTER:
		for key: Variant in _looks.keys():
			if is_instance_valid(key):
				(_looks[key] as HiderLooks.Reveal).restore()
		_looks.clear()
		seeker_view = false
		self_fish = null
		return
	super._refresh(delta)
	# A joined player's model stays off in everyone's view but the Hunter's reveal.
	for fish in game.players:
		if is_instance_valid(fish) and fish._visual != null and game.join != null and game.join.is_joined(fish):
			fish._visual.visible = seeker_view and _looks.has(fish)
