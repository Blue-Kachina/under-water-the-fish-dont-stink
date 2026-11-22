class_name RaceSetup
extends RefCounted
## Fin-ish Line's part of the mode setup screens (ui/mode_setups.gd asks it through the descriptor's "setup" key): the
## rows of its picker screen and the whole RaceRoster as one character pool, grouped Fish, Hunters, Titans. The fish
## classes are the usual two-tier pick (class, species); a Hunter form is one entry; a Titan is one entry per species
## with its skins as the second tier. The pick is the role "racer"'s own save (RoleCharacters), so each player's
## racer is remembered apart from their other modes' characters.
##   fish pick   RoleCharacters.store("racer", class, species) (the screen's own)
##   form pick   RoleCharacters.store_form("racer", HunterForms key) and "racer_skin" (a Titan's skin)
##   "racer_kind" ("fish" or "form") says which of the two the last confirmed pick was.

const ROLE := "racer"
const KIND_KEY := "racer_kind"
const SKIN_KEY := "racer_skin"
const META_FORM := &"race_form"
const META_SKIN := &"race_skin"


## The picker screen's rows (laps, field size, bots); returns the role the player is in.
static func rows(setup: ModeSetup, _main: Node) -> String:
	var rs := RaceSettings.shared()
	setup.rows.append(ModeSetups.row("Laps", _numbers(1, 9), clampi(rs.laps, 1, 9) - 1, func(i: int) -> void: rs.laps = i + 1))
	setup.rows.append(ModeSetups.row("Racers", _numbers(2, 12), clampi(rs.field_size, 2, 12) - 2, func(i: int) -> void: rs.field_size = i + 2))
	setup.rows.append(ModeSetups.row("Bots", RaceSettings.BOT_NAMES, int(rs.bot_difficulty), func(i: int) -> void: rs.bot_difficulty = i as RaceSettings.Bots))
	return ROLE


## Every race is raced as the "racer" role.
static func current_role(_main: Node) -> String:
	return ROLE


## Offers the whole roster as `role`'s character pool.
static func use_role(setup: ModeSetup, role: String, _current: bool) -> bool:
	if role != ROLE:
		return false
	setup.pool = pool()
	setup.pool_label = "Racer"
	setup.species_label = "Species"
	var at := _opening(setup.pool)
	setup.pool_index = at.x
	setup.species_index = at.y
	if not setup.confirmed.is_connected(_remember.bind(setup)):
		setup.confirmed.connect(_remember.bind(setup))  # before the host applies the pick: which kind it was
	return true


## A confirmed picker screen's form pick (a Hunter or a Titan): worn from now, remembered for `role`.
static func apply_form(_main: Node, role: String, entry: Dictionary) -> void:
	RoleCharacters.store_form(role, str(entry["form"]))


## The same pick again, once the mode's been entered: nothing to restore, the match reads the saves.
static func settle_form(_entry: Dictionary) -> void:
	pass


## Change Character mid-race: remembered; the match dresses the racer from it (RaceMatch re-reads its pick).
static func change_form(_main: Node, role: String, entry: Dictionary) -> void:
	RoleCharacters.store_form(role, str(entry["form"]))


## The pool: fish classes, then Hunter forms, then Titans (one entry each; a Titan's skins are its species tier).
static func pool() -> Array:
	var entries := []
	for entry: Dictionary in ModeSetup.fish_pool(ROLE):
		if int(entry["character"]) != int(FishCharacter.FishClass.MONSTER):
			entry["line"] = "Fish"
			entries.append(entry)
	var skins_of := load(RaceRoster.TITAN_MODEL) as GDScript
	for key: String in HunterForms.ready_keys():
		var sheet := HunterForms.sheet(key)
		var fish_class: FishCharacter.FishClass = sheet["class"]
		if fish_class == FishCharacter.FishClass.MONSTER:
			entries.append({"name": str(sheet["name"]), "line": "Hunter", "character": fish_class, "form": key, "slot": 0,
					"species": [], "preview_species": int(sheet["species"])})
		elif fish_class == FishCharacter.FishClass.TITAN:
			var skins := []
			for name: String in skins_of.call("skin_names", int(sheet["species"])):
				skins.append({"name": name, "note": "", "index": int(sheet["species"])})
			entries.append({"name": str(sheet["name"]), "line": "Titan", "character": fish_class, "form": key, "slot": 0,
					"species": skins, "preview_species": int(sheet["species"])})
	return entries


## The roster entry the local player's saved pick is ({} when it matches none): a fish class and species, or the
## Hunter form / Titan species and skin. `entries` is RaceRoster.entries() (passed in: building it costs).
static func picked_entry(entries: Array) -> Dictionary:
	if RoleCharacters.form(KIND_KEY) == "form" and RoleCharacters.form(ROLE) != "":
		var form := RoleCharacters.form(ROLE)
		if HunterForms.has(form):
			var sheet := HunterForms.sheet(form)
			var skin := int(RoleCharacters.form(SKIN_KEY))
			for e: Dictionary in entries:
				if int(sheet["class"]) == int(FishCharacter.FishClass.TITAN):
					if e["family"] == RaceRoster.TITAN and int(e["species"]) == int(sheet["species"]) and int(e["skin"]) == skin:
						return e
				elif e["form"] == form:
					return e
	var fish_class := RoleCharacters.character(ROLE)
	var species := RoleCharacters.species(ROLE, fish_class)
	for e: Dictionary in entries:
		if e["family"] == RaceRoster.FISH and int(e["class"]) == int(fish_class) and int(e["species"]) == species:
			return e
	return {}


## Remembers which kind of pick was confirmed (and a Titan's skin).
static func _remember(setup: ModeSetup) -> void:
	var entry: Dictionary = setup.pool[setup.pool_index]
	var is_form := entry.has("form")
	RoleCharacters.store_form(KIND_KEY, "form" if is_form else "fish")
	if is_form:
		RoleCharacters.store_form(SKIN_KEY, str(setup.species_index))


## Where the screen opens: the saved pick's entry and species or skin slot.
static func _opening(entries: Array) -> Vector2i:
	if RoleCharacters.form(KIND_KEY) == "form" and RoleCharacters.form(ROLE) != "":
		for i in entries.size():
			if entries[i].get("form", "") == RoleCharacters.form(ROLE):
				return Vector2i(i, clampi(int(RoleCharacters.form(SKIN_KEY)), 0, maxi(entries[i]["species"].size() - 1, 0)))
	var at := ModeSetup.pool_index_of(entries, RoleCharacters.character(ROLE))
	return Vector2i(at, ModeSetup.species_slot(entries[at], RoleCharacters.species(ROLE, RoleCharacters.character(ROLE))))


static func _numbers(first: int, last: int) -> Array:
	var out := []
	for n in range(first, last + 1):
		out.append(str(n))
	return out


# --- Joining a running race (descriptor "join_pick"; LocalCoop calls these through ModeSetups) ---------------------------

## A split-screen joiner's character screen: the whole roster, opening on the fish they have now.
static func join_setup(setup: ModeSetup, fish: FishController) -> void:
	setup.pool = pool()
	setup.pool_label = "Racer"
	setup.species_label = "Species"
	setup.pool_index = 0
	setup.species_index = 0
	if fish != null:
		setup.pool_index = ModeSetup.pool_index_of(setup.pool, fish.character)
		setup.species_index = ModeSetup.species_slot(setup.pool[setup.pool_index], fish.species)


## Wears the joiner's pick: a Hunter form or a Titan skin is remembered on the fish (RaceMatch.add_player reads it);
## true when handled here, false for a plain fish (the default wear).
static func join_wear(setup: ModeSetup, fish: FishController) -> bool:
	var entry: Dictionary = setup.pool[setup.pool_index]
	if not entry.has("form"):
		fish.remove_meta(META_FORM)
		return false
	fish.set_meta(META_FORM, str(entry["form"]))
	fish.set_meta(META_SKIN, setup.species_index)
	var skin := setup.species_index if int(entry["character"]) == int(FishCharacter.FishClass.TITAN) else 0
	fish.set_look(entry["character"], ModeSetup.species_of(entry, setup.species_index), skin)
	return true


## The roster entry a joined fish was given (join_wear), or {}.
static func joined_entry(fish: FishController, entries: Array) -> Dictionary:
	if not fish.has_meta(META_FORM):
		return {}
	var form := str(fish.get_meta(META_FORM))
	if not HunterForms.has(form):
		return {}
	var sheet := HunterForms.sheet(form)
	var skin := int(fish.get_meta(META_SKIN, 0))
	for e: Dictionary in entries:
		if int(sheet["class"]) == int(FishCharacter.FishClass.TITAN):
			if e["family"] == RaceRoster.TITAN and int(e["species"]) == int(sheet["species"]) and int(e["skin"]) == skin:
				return e
		elif e["form"] == form:
			return e
	return {}
