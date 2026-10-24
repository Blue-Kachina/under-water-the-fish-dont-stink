extends Node
## Classes and species (big_changes.md Phase 0): every class has a role name,
## an RL hitbox and at least 3 species; the keys from before classes still
## resolve (saved picks, old clips); an RL replay's hitbox_family picks the
## first class on that hitbox; our clips carry the class itself.
##   Godot_console.exe --headless --path . res://tests/class_species_probe.tscn

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"
const RL_HITBOXES := ["octane", "dominus", "plank", "breakout", "hybrid", "merc"]

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("Classes:")
	var keys := {}
	for fish_class: FishCharacter.FishClass in FishCharacter.CLASSES:
		var entry: Dictionary = FishCharacter.CLASSES[fish_class]
		var title := FishCharacter.display_name(fish_class)
		check(title != "" and not keys.has(entry.key), "%s: a role name and its own key (%s)" % [title, entry.key])
		keys[entry.key] = true
		check(FishCharacter.species_count(fish_class) >= 3, "%s: %d species" % [title, FishCharacter.species_count(fish_class)])
		check(entry.rl_hitbox in RL_HITBOXES, "%s: on an RL hitbox (%s)" % [title, entry.rl_hitbox])
		check(FishCharacter.from_key(entry.key) == fish_class, "%s: its key resolves" % title)
		for alias: String in entry.aliases:
			check(FishCharacter.from_key(alias) == fish_class, "%s: old key %s resolves" % [title, alias])
		for i in FishCharacter.species_count(fish_class):
			check(FishCharacter.species_from_key(fish_class, FishCharacter.species_key(fish_class, i)) == i,
					"%s: species %s round-trips" % [title, FishCharacter.species_name(fish_class, i)])
	check(FishCharacter.CLASSES.size() == FishCharacter.FishClass.size() and FishCharacter.SPECIES.size() == FishCharacter.FishClass.size(),
			"every enum entry has a class and species")
	check(FishCharacter.FishClass.SKIRMISHER == 0 and FishCharacter.FishClass.BREACHER == 9, "the enum keeps its network order")
	check(FishCharacter.from_key("nonsense") == FishCharacter.FishClass.SKIRMISHER, "an unknown key: Skirmishers")
	check(FishCharacter.from_key("MANTIS") == FishCharacter.FishClass.BRAWLER, "keys ignore case")
	check(FishCharacter.full_name(FishCharacter.FishClass.BRAWLER, 0) == "Brawlers  ·  Peacock Mantis",
			"the card line (%s)" % FishCharacter.full_name(FishCharacter.FishClass.BRAWLER, 0))

	print("Saved picks from before classes:")
	var old := ConfigFile.new()
	old.set_value("playground", "character", "mantis")
	old.set_value("playground", "skin_mantis", "zebra")
	old.set_value("playground", "skin_whale_shark", "basking")
	check(FishCharacter.from_key(str(old.get_value("playground", "character"))) == FishCharacter.FishClass.BRAWLER, "character mantis: Brawlers")
	check(MAIN_SCRIPT.saved_species(old, FishCharacter.FishClass.BRAWLER) == 1, "skin_mantis zebra: the Brawlers' species 1")
	check(MAIN_SCRIPT.saved_species(old, FishCharacter.FishClass.BREACHER) == 3, "skin_whale_shark basking: the Breachers' species 3")
	MAIN_SCRIPT.store_species(old, FishCharacter.FishClass.BRAWLER, 2)
	check(old.get_value("playground", "species_brawler", "") == "purple_spot", "a new pick is stored as species_brawler")
	check(MAIN_SCRIPT.saved_species(old, FishCharacter.FishClass.BRAWLER) == 2, "and the new key wins over the old")

	print("Replays:")
	var rl := ReplayData.new()
	var problem := rl.load_file(FIXTURE)
	check(problem == "", "the RL fixture loads (%s)" % problem)
	if problem == "":
		check(FishCharacter.class_of(rl.players[0]) == FishCharacter.FishClass.SKIRMISHER, "RL octane: Skirmishers")
		check(FishCharacter.class_of(rl.players[1]) == FishCharacter.FishClass.HUNTER, "RL dominus: Hunters")
	var old_clip := {"hitbox_family": "octane", "skin": ""}
	check(FishCharacter.class_of(old_clip) == FishCharacter.FishClass.SKIRMISHER, "an old clip with hitbox_family octane loads as Skirmishers")
	check(FishCharacter.class_of({"hitbox_family": "whale_shark"}) == FishCharacter.FishClass.BREACHER, "an old clip's whale_shark: Breachers")
	var clip := {"fish_class": "scorcher", "hitbox_family": "octane", "species": "clearfin"}
	check(FishCharacter.class_of(clip) == FishCharacter.FishClass.SCORCHER, "a new clip's fish_class beats its shared hitbox")
	check(ReplayCar.species_of(clip) == 1, "and its species is worn")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)
