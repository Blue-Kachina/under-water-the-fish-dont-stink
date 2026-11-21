class_name ModeSetups
extends RefCounted
## Builds the ModeSetup screens: a mode's options + character (from the mode
## picker), a joining player's character, and the pause menu's Change Character,
## and applies a confirmed one. Each mode lists its options once, in build().
## Roles (RoleCharacters): Marco Polo's seeker / hider and What Stinks?'s hunter /
## prey each have their own last character; every other mode has one (DEFAULT).
## A What Stinks? hunter picks a Hunter form instead of a fish.

const FISH_STICKS := "Fish Sticks"
const UNNATURAL := "Unnatural"
const WHAT_STINKS := "What Stinks?"
const FISH_STICKS_MODES := ["1v1", "Free Play"]


## The screen for playing `mode` (a picker mode: Fish Sticks stands for its two).
## Not in the tree yet; its "mode" meta is the picker's, apply() gives the mode to start.
static func build(main: Node, mode: String) -> ModeSetup:
	var tile: Dictionary = main.MODE_TILES.get(mode, {})
	var setup := ModeSetup.new()
	setup.title = str(tile.get("title", mode))
	setup.blurb = str(tile.get("pitch", ""))
	setup.accent = tile.colors[1] if tile.has("colors") else UITheme.AQUA
	setup.set_meta("mode", mode)
	var role := RoleCharacters.DEFAULT
	match mode:
		UNNATURAL:
			var us := UnnaturalSettings.shared()
			setup.rows.append(_row("Run length", [["Short", "One stage."], ["Standard", "%d stages." % us.standard_stages],
					["Endless", "Until the sea wins."]], clampi(us.run_length, 0, 2), func(i: int) -> void: us.run_length = i))
		FISH_STICKS:
			setup.set_meta("variant", FISH_STICKS_MODES[0])
			setup.rows.append(_row("Mode", [["1v1", "Against a bot: five minutes, overtime on a tie."], ["Free Play", "The arena and a ball, no clock."]], 0,
					func(i: int) -> void: setup.set_meta("variant", FISH_STICKS_MODES[i])))
		WHAT_STINKS:
			var ws := WhatStinksSettings.shared()
			setup.rows.append(_row("Variant", WhatStinksSettings.VARIANT_NAMES, int(ws.variant),
					func(i: int) -> void: ws.variant = i as WhatStinksSettings.Variant))
			setup.rows.append(_row("Start as", [["Hunter", "Eat the crowd first."], ["Prey", "Stay in the swim while a bot hunts."]], int(ws.start_as),
					func(i: int) -> void:
						ws.start_as = i as WhatStinksSettings.StartAs
						ModeSetups._use_role(setup, "hunter" if i == WhatStinksSettings.StartAs.HUNTER else "prey"),
					func(i: int) -> void: ws.start_as = i as WhatStinksSettings.StartAs))
			role = "hunter" if ws.start_as == WhatStinksSettings.StartAs.HUNTER else "prey"
	var registered: Variant = ModeRegistry.describe(mode).get("setup_rows", null)
	if registered is Callable:
		role = (registered as Callable).call(main, setup)  # a registered mode lists its own rows, and gives its starting role
	_use_role(setup, role)
	return setup


## The screen for changing the character of whoever plays `role` (the pause menu's).
static func build_character(main: Node, role: String) -> ModeSetup:
	var setup := ModeSetup.new()
	setup.kicker = "Change character"
	setup.title = role.capitalize() if role != RoleCharacters.DEFAULT else "Your fish"
	setup.blurb = "Playing as %s. Remembered for next time." % role if role != RoleCharacters.DEFAULT else "Remembered for next time."
	setup.confirm_text = "Apply"
	var tile: Dictionary = main.MODE_TILES.get(main.current_mode, {})
	setup.accent = tile.colors[1] if tile.has("colors") else UITheme.AQUA
	setup.set_meta("mode", main.current_mode)
	_use_role(setup, role, true)
	return setup


## A joining player's: their fish's own to start from (not the first player's).
static func build_join(player: String, pad: int, fish_class: FishCharacter.FishClass, species: int) -> ModeSetup:
	var setup := ModeSetup.new()
	setup.kicker = "Joining"
	setup.title = player
	setup.blurb = "Pick your fish. Everyone else keeps playing."
	setup.device = pad
	setup.pool = ModeSetup.fish_pool()
	setup.pool_index = ModeSetup.pool_index_of(setup.pool, fish_class)
	setup.species_index = ModeSetup.species_slot(setup.pool[setup.pool_index], species)
	return setup


## The role the player plays now: a Marco Polo / What Stinks? match's own, or
## the one it starts on from its settings, else the one every other mode has.
static func current_role(main: Node) -> String:
	var registered: Variant = ModeRegistry.describe(main.current_mode).get("current_role", null)
	if registered is Callable:
		return (registered as Callable).call(main)
	if main.current_mode == WHAT_STINKS:
		if main.what_stinks and is_instance_valid(main.what_stinks):
			return "hunter" if main.what_stinks.local_view_role() == WhatStinksMatch.Role.HUNTER else "prey"
		return "hunter" if WhatStinksSettings.shared().start_as == WhatStinksSettings.StartAs.HUNTER else "prey"
	return RoleCharacters.DEFAULT


## Whether the player's character is picked by the mode itself (Marco Polo's whale
## seeker picks on the whale card as the round starts), not from the fish classes.
static func whale_seeker_now(main: Node) -> bool:
	var registered: Variant = ModeRegistry.describe(main.current_mode).get("character_picked_by_mode", null)
	return registered is Callable and bool((registered as Callable).call(current_role(main)))


## Applies a confirmed picker screen: its options are set already (they apply as
## they change); the character is worn and remembered for its role. Returns the
## mode to start.
static func apply(main: Node, setup: ModeSetup) -> String:
	var mode: String = setup.get_meta("mode")
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("mode_pick"):
		# The mode picks it itself (a whale seeker: the whale card); it says what to wear meanwhile.
		(ModeRegistry.describe(str(entry.mode_pick))["apply_pick"] as Callable).call(main)
	elif entry.has("form"):
		# A What Stinks? hunter: the form, and the fish worn as prey is the prey's last.
		WhatStinksSettings.shared().form = entry.form
		RoleCharacters.store_form(role, entry.form)
		var prey := RoleCharacters.character("prey")
		main.apply_look(prey, RoleCharacters.species("prey", prey))
	else:
		var species := ModeSetup.species_of(entry, setup.species_index)
		RoleCharacters.store(role, entry.character, species)
		main.apply_look(entry.character, species)
	return str(setup.get_meta("variant")) if mode == FISH_STICKS else mode


## The picks of a confirmed picker screen again, once its mode's been entered (see
## Main.start_mode): the options, and a hunter's form.
static func settle(setup: ModeSetup) -> void:
	setup.reapply()
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("form"):
		WhatStinksSettings.shared().form = entry.form


## Applies a confirmed Change Character screen: a hunter's form or a fish plays as
## the pick from now, mid-round (a seeker whale's or a hunter's body keeps the pick
## for when it comes off).
static func apply_character(main: Node, setup: ModeSetup) -> void:
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("mode_pick"):
		return  # the mode's to pick (the whale card)
	if entry.has("form"):
		WhatStinksSettings.shared().form = entry.form
		RoleCharacters.store_form(role, entry.form)
		if main.what_stinks and is_instance_valid(main.what_stinks):
			main.what_stinks.refresh_form(main.get_node("Fish"))  # a Hunter wears it now
		return
	var species := ModeSetup.species_of(entry, setup.species_index)
	RoleCharacters.store(role, entry.character, species)
	main.set_character(entry.character)
	main.set_species(species)


## Their pick on a joined player's fish.
static func wear(setup: ModeSetup, fish: FishController) -> void:
	var entry: Dictionary = setup.pool[setup.pool_index]
	fish.set_look(entry.character, ModeSetup.species_of(entry, setup.species_index))


## Offers `role`'s characters: the fish pool opening on the one last played in it,
## or a hunter's forms.
static func _use_role(setup: ModeSetup, role: String, current := false) -> void:
	setup.set_meta("role", role)
	if role == "hunter":
		setup.pool = _form_pool()
		setup.pool_label = "Hunter"
		setup.species_label = "Form"
		var last := RoleCharacters.form("hunter")
		if current or last == "":
			last = WhatStinksSettings.shared().form  # the form in play (mid-match), not the one last remembered
		var ready: Array[String] = HunterForms.ready_keys()
		var at := ready.find(HunterForms.playable(last))
		setup.pool_index = maxi(at, 0)
		setup.species_index = 0
	elif not _role_pool(role).is_empty():
		var special := _role_pool(role)  # a registered mode's own pick for the role (Marco Polo's whale seeker)
		setup.pool = [special.entry]
		setup.pool_label = special.label
		setup.pool_index = 0
		setup.species_index = 0
	else:
		setup.pool = ModeSetup.fish_pool(role)
		setup.pool_label = "Class"
		setup.species_label = "Species"
		var pick := ModeSetup.last_pick(setup.pool, role)
		setup.pool_index = pick.x
		setup.species_index = pick.y
	setup.refresh()


## What a registered mode offers instead of the fish classes for `role`: {"entry", "label"}
## (descriptor "role_pool"), or {}.
static func _role_pool(role: String) -> Dictionary:
	for d: Dictionary in ModeRegistry.descriptors():
		if d.has("role_pool"):
			var pool: Dictionary = (d["role_pool"] as Callable).call(role)
			if not pool.is_empty():
				return pool
	return {}


## Public for the descriptors' "setup_rows": one option row of a mode's setup screen.
static func row(label: String, options: Array, index: int, changed: Callable, setter := Callable()) -> Dictionary:
	return _row(label, options, index, changed, setter)


## Public for the descriptors' "setup_rows": the character pool of `role`.
static func use_role(setup: ModeSetup, role: String) -> void:
	_use_role(setup, role)


static func _form_pool() -> Array:
	var forms := []
	for key: String in HunterForms.ready_keys():
		var sheet: Dictionary = HunterForms.sheet(key)
		var fish_class: FishCharacter.FishClass = sheet["class"]
		forms.append({"name": str(sheet["name"]), "line": "", "character": fish_class, "form": key, "slot": 0,
				"species": [], "preview_species": int(sheet["species"])})  # one look each: no species tier
	return forms


## `setter`: just the setting (for re-applying it after Nature's tuning restore has had its
## say); `changed` when it also has side effects (a role switch).
static func _row(label: String, options: Array, index: int, changed: Callable, setter := Callable()) -> Dictionary:
	return {"label": label, "options": _options(options), "index": index, "changed": changed, "set": setter if setter.is_valid() else changed}


## [name, desc] pairs (or bare names) as ModeSetup's options.
static func _options(entries: Array) -> Array:
	return entries.map(func(entry: Variant) -> Dictionary:
		return {"name": str(entry[0]), "desc": str(entry[1])} if entry is Array else {"name": str(entry), "desc": ""})
