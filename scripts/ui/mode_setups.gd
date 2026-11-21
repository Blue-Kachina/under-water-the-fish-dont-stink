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
	var registered_rows: Variant = ModeRegistry.describe(mode).get("setup_rows", null)
	if registered_rows is Callable:
		(registered_rows as Callable).call(setup, _row)  # a registered mode lists its own rows (its descriptor)
	match mode:
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
						ModeSetups._use_role(setup, "hider" if i == MarcoPoloSettings.StartAs.HIDER else "seeker"),
					func(i: int) -> void: mp.start_as = i as MarcoPoloSettings.StartAs))
			var arenas: Array = MarcoPoloSettings.ARENAS.filter(func(arena_name: String) -> bool: return main.ENVIRONMENTS.has(arena_name))
			setup.rows.append(_row("Arena", arenas, maxi(arenas.find(mp.arena), 0), func(i: int) -> void: mp.arena = arenas[i]))
			role = "hider" if mp.start_as == MarcoPoloSettings.StartAs.HIDER else "seeker"
		_:
			var registered := ModeRegistry.describe(mode)  # a registered mode's own rows (descriptor "setup")
			if registered.has("setup"):
				role = (registered["setup"] as GDScript).call("rows", setup, main)
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
	if main.current_mode == MARCO_POLO:
		if main.marco_polo and is_instance_valid(main.marco_polo):
			return "seeker" if main.marco_polo.local_view_role() == MarcoPoloMatch.Role.SEEKER else "hider"
		return "hider" if MarcoPoloSettings.shared().start_as == MarcoPoloSettings.StartAs.HIDER else "seeker"
	var registered := ModeRegistry.describe(main.current_mode)
	if registered.has("setup"):
		return (registered["setup"] as GDScript).call("current_role", main)
	return RoleCharacters.DEFAULT


## Whether the player is a Marco Polo seeker that's a whale: they pick it on the whale
## card (whale_pick_card.gd) as the round starts, not from the fish classes.
static func whale_seeker_now(main: Node) -> bool:
	return main.current_mode == MARCO_POLO and MarcoPoloSettings.shared().whale_seeker and current_role(main) == "seeker"


## Applies a confirmed picker screen: its options are set already (they apply as
## they change); the character is worn and remembered for its role. Returns the
## mode to start.
static func apply(main: Node, setup: ModeSetup) -> String:
	var mode: String = setup.get_meta("mode")
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("whale"):
		# A whale seeker: the whale card picks it; the fish under it (worn as a hider) is the hider's last.
		var hider := RoleCharacters.character("hider")
		main.apply_look(hider, RoleCharacters.species("hider", hider))
	elif entry.has("form"):
		# A hunter form (a registered mode's "setup"): the form, and the fish worn as prey is the prey's last.
		(ModeRegistry.describe(mode)["setup"] as GDScript).call("apply_form", main, role, entry)
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
		(ModeRegistry.describe(str(setup.get_meta("mode")))["setup"] as GDScript).call("settle_form", entry)


## Applies a confirmed Change Character screen: a hunter's form or a fish plays as
## the pick from now, mid-round (a seeker whale's or a hunter's body keeps the pick
## for when it comes off).
static func apply_character(main: Node, setup: ModeSetup) -> void:
	var role: String = setup.get_meta("role", RoleCharacters.DEFAULT)
	var entry: Dictionary = setup.pool[setup.pool_index]
	if entry.has("whale"):
		return  # the whale card's to pick
	if entry.has("form"):
		(ModeRegistry.describe(main.current_mode)["setup"] as GDScript).call("change_form", main, role, entry)
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
	var registered := ModeRegistry.describe(str(setup.get_meta("mode", "")))
	if registered.has("setup") and (registered["setup"] as GDScript).call("use_role", setup, role, current):
		pass  # the mode's own pool (What Stinks?'s Hunter forms)
	elif role == "seeker" and MarcoPoloSettings.shared().whale_seeker:
		setup.pool = [_whale_entry()]
		setup.pool_label = "Whale"
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


## A whale seeker's one item: no fish to choose, the whale card does it.
static func _whale_entry() -> Dictionary:
	return {"name": "Your whale", "character": FishCharacter.FishClass.TITAN, "whale": true, "slot": 0, "species": [],
			"preview_species": 0, "line": "As the round starts a card shows your whale: left / right the species, up / down the skin, A locks it in."}


## `setter`: just the setting (for re-applying it after Nature's tuning restore has had its
## say); `changed` when it also has side effects (a role switch).
static func _row(label: String, options: Array, index: int, changed: Callable, setter := Callable()) -> Dictionary:
	return {"label": label, "options": _options(options), "index": index, "changed": changed, "set": setter if setter.is_valid() else changed}


## [name, desc] pairs (or bare names) as ModeSetup's options.
static func _options(entries: Array) -> Array:
	return entries.map(func(entry: Variant) -> Dictionary:
		return {"name": str(entry[0]), "desc": str(entry[1])} if entry is Array else {"name": str(entry), "desc": ""})
