class_name WhatStinksSetup
extends RefCounted
## What Stinks?'s part of the mode setup screens (ui/mode_setups.gd asks it through the descriptor's
## "setup" key): the rows of its picker screen, which role the player has now, and the Hunter's
## forms as a role's character pool. The screens themselves (ModeSetup, RoleCharacters) are core.

const MODE := "What Stinks?"


## The picker screen's rows (variant, Start as); returns the role the player starts in.
static func rows(setup: ModeSetup, _main: Node) -> String:
	var ws := WhatStinksSettings.shared()
	setup.rows.append(ModeSetups._row("Variant", WhatStinksSettings.VARIANT_NAMES, int(ws.variant),
			func(i: int) -> void: ws.variant = i as WhatStinksSettings.Variant))
	setup.rows.append(ModeSetups._row("Start as", [["Hunter", "Eat the crowd first."], ["Prey", "Stay in the swim while a bot hunts."]], int(ws.start_as),
			func(i: int) -> void:
				ws.start_as = i as WhatStinksSettings.StartAs
				ModeSetups._use_role(setup, "hunter" if i == WhatStinksSettings.StartAs.HUNTER else "prey"),
			func(i: int) -> void: ws.start_as = i as WhatStinksSettings.StartAs))
	return "hunter" if ws.start_as == WhatStinksSettings.StartAs.HUNTER else "prey"


## The role the local player plays now: the match's, else the one its settings start on.
static func current_role(main: Node) -> String:
	if main.what_stinks and is_instance_valid(main.what_stinks):
		return "hunter" if main.what_stinks.local_view_role() == WhatStinksMatch.Role.HUNTER else "prey"
	return "hunter" if WhatStinksSettings.shared().start_as == WhatStinksSettings.StartAs.HUNTER else "prey"


## Offers the Hunter's forms when `role` is the hunter's; false for any other role.
static func use_role(setup: ModeSetup, role: String, current: bool) -> bool:
	if role != "hunter":
		return false
	setup.pool = _form_pool()
	setup.pool_label = "Hunter"
	setup.species_label = "Form"
	var last := RoleCharacters.form("hunter")
	if current or last == "":
		last = WhatStinksSettings.shared().form  # the form in play (mid-match), not the one last remembered
	var ready: Array[String] = HunterForms.ready_keys()
	setup.pool_index = maxi(ready.find(HunterForms.playable(last)), 0)
	setup.species_index = 0
	return true


## A confirmed picker screen's Hunter form pick (a pool entry with "form"): the form is worn from
## now, remembered for `role`; and the fish worn as prey is the prey's last.
static func apply_form(main: Node, role: String, entry: Dictionary) -> void:
	WhatStinksSettings.shared().form = entry.form
	RoleCharacters.store_form(role, entry.form)
	var prey := RoleCharacters.character("prey")
	main.apply_look(prey, RoleCharacters.species("prey", prey))


## The same pick again, once the mode's been entered (the options' own restore has had its say).
static func settle_form(entry: Dictionary) -> void:
	WhatStinksSettings.shared().form = entry.form


## Change Character mid-round: the form is worn now (a Hunter in play wears it at once).
static func change_form(main: Node, role: String, entry: Dictionary) -> void:
	WhatStinksSettings.shared().form = entry.form
	RoleCharacters.store_form(role, entry.form)
	if main.what_stinks and is_instance_valid(main.what_stinks):
		main.what_stinks.refresh_form(main.get_node("Fish"))


static func _form_pool() -> Array:
	var forms := []
	for key: String in HunterForms.ready_keys():
		var sheet: Dictionary = HunterForms.sheet(key)
		var fish_class: FishCharacter.FishClass = sheet["class"]
		forms.append({"name": str(sheet["name"]), "line": "", "character": fish_class, "form": key, "slot": 0,
				"species": [], "preview_species": int(sheet["species"])})  # one look each: no species tier
	return forms
