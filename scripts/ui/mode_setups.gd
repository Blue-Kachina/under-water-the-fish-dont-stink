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
const MARCO_POLO := "Marco Polo"
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
		MARCO_POLO:
			var mp := MarcoPoloSettings.shared()
			setup.rows.append(_row("Variant", MarcoPoloSettings.VARIANT_NAMES, int(mp.variant),
					func(i: int) -> void: mp.variant = i as MarcoPoloSettings.Variant))
			setup.rows.append(_row("Start as", [["Seeker", "Hunt the hiders first."], ["Hider", "Hide while a bot seeks."]], int(mp.start_as),
					func(i: int) -> void:
						mp.start_as = i as MarcoPoloSettings.StartAs
						ModeSetups._use_role(setup, "hider" if i == MarcoPoloSettings.StartAs.HIDER else "seeker")))
			var arenas: Array = MarcoPoloSettings.ARENAS.filter(func(arena_name: String) -> bool: return main.ENVIRONMENTS.has(arena_name))
			setup.rows.append(_row("Arena", arenas, maxi(arenas.find(mp.arena), 0), func(i: int) -> void: mp.arena = arenas[i]))
			role = "hider" if mp.start_as == MarcoPoloSettings.StartAs.HIDER else "seeker"
		WHAT_STINKS:
			var ws := WhatStinksSettings.shared()
			setup.rows.append(_row("Variant", WhatStinksSettings.VARIANT_NAMES, int(ws.variant),
					func(i: int) -> void: ws.variant = i as WhatStinksSettings.Variant))
			setup.rows.append(_row("Start as", [["Hunter", "Eat the crowd first."], ["Prey", "Stay in the swim while a bot hunts."]], int(ws.start_as),
					func(i: int) -> void:
						ws.start_as = i as WhatStinksSettings.StartAs
						ModeSetups._use_role(setup, "hunter" if i == WhatStinksSettings.StartAs.HUNTER else "prey")))
			var size := HunterSize.shared()
			var sizes: Array = WhatStinksSettings.SIZE_CHOICES.duplicate()
			if not sizes.has(size.size_mult):
				sizes.append(size.size_mult)
				sizes.sort()
			setup.rows.append(_row("Hunter size", sizes.map(func(mult: float) -> String: return "%sx" % str(snappedf(mult, 0.01))),
					maxi(sizes.find(size.size_mult), 0), func(i: int) -> void: size.size_mult = float(sizes[i])))
			role = "hunter" if ws.start_as == WhatStinksSettings.StartAs.HUNTER else "prey"
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
	_use_role(setup, role)
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
	if main.current_mode == MARCO_POLO:
		if main.marco_polo and is_instance_valid(main.marco_polo):
			return "seeker" if main.marco_polo.local_view_role() == MarcoPoloMatch.Role.SEEKER else "hider"
		return "hider" if MarcoPoloSettings.shared().start_as == MarcoPoloSettings.StartAs.HIDER else "seeker"
	if main.current_mode == WHAT_STINKS:
		if main.what_stinks and is_instance_valid(main.what_stinks):
			return "hunter" if main.what_stinks.local_view_role() == WhatStinksMatch.Role.HUNTER else "prey"
		return "hunter" if WhatStinksSettings.shared().start_as == WhatStinksSettings.StartAs.HUNTER else "prey"
	return RoleCharacters.DEFAULT


## Applies a confirmed picker screen: its options are set already (they apply as
## they change); the character is worn and remembered for its role. Returns the
## mode to start.
static func apply(main: Node, setup: ModeSetup) -> String:
	var mode: String = setup.get_meta("mode")
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("form"):
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


## Applies a confirmed Change Character screen (a hunter's is the form, from the
## next round; a fish plays as it from now, as the mode allows).
static func apply_character(main: Node, setup: ModeSetup) -> void:
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("form"):
		WhatStinksSettings.shared().form = entry.form
		RoleCharacters.store_form(role, entry.form)
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
static func _use_role(setup: ModeSetup, role: String) -> void:
	setup.set_meta("role", role)
	if role == "hunter":
		setup.pool = _form_pool()
		setup.pool_label = "Hunter"
		setup.species_label = "Form"
		var last := RoleCharacters.form("hunter")
		var ready: Array[String] = HunterForms.ready_keys()
		var at := ready.find(HunterForms.playable(last if last != "" else WhatStinksSettings.shared().form))
		setup.pool_index = maxi(at, 0)
		setup.species_index = 0
	else:
		setup.pool = ModeSetup.fish_pool(role)
		setup.pool_label = "Class"
		setup.species_label = "Species"
		var pick := ModeSetup.last_pick(setup.pool, role)
		setup.pool_index = pick.x
		setup.species_index = pick.y
	setup.refresh()


static func _form_pool() -> Array:
	var forms := []
	for key: String in HunterForms.ready_keys():
		var sheet: Dictionary = HunterForms.sheet(key)
		var fish_class: FishCharacter.FishClass = sheet["class"]
		forms.append({"name": str(sheet["name"]), "line": "", "character": fish_class, "form": key, "slot": 0,
				"species": [], "preview_species": int(sheet["species"])})  # one look each: no species tier
	return forms


static func _row(label: String, options: Array, index: int, changed: Callable) -> Dictionary:
	return {"label": label, "options": _options(options), "index": index, "changed": changed}


## [name, desc] pairs (or bare names) as ModeSetup's options.
static func _options(entries: Array) -> Array:
	return entries.map(func(entry: Variant) -> Dictionary:
		return {"name": str(entry[0]), "desc": str(entry[1])} if entry is Array else {"name": str(entry), "desc": ""})
