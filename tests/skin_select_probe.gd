extends Node
## Species selection: setting a fish's species rebuilds its model in that species; each
## class's species is saved by key and comes back (main's saved_species / store_species,
## and main's set_character / set_species through the settings file, which is put
## back afterwards); the online co-op roster carries the species and remote fish
## wear it; a goal replay records the species and its ghost wears it (old replays:
## the class's first).
##   Godot_console.exe --headless --path . res://tests/species_select_probe.tscn

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const PROBE_CFG := "user://species_select_probe.cfg"

var main: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	await _ticks(3)
	_check_fish()
	_check_saved_species()
	await _check_main_flow()
	await _check_coop()
	await _check_replay()
	print("species_select_probe: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _visual() -> FishModel:
	return fish.get("_visual")


func _check_fish() -> void:
	print("the fish's species:")
	check(FishCharacter.is_species_unlocked(FishCharacter.FishClass.HUNTER, 4), "every species is unlocked for now")
	fish.set_look(FishCharacter.FishClass.HUNTER, 4)
	var model := _visual()
	check(fish.character == FishCharacter.FishClass.HUNTER and fish.species == 4, "set_look: Hunters, species 4")
	check(model.fish_class == FishCharacter.FishClass.HUNTER and model.species == 4, "its model is the Hammerhead (species %d)" % model.species)
	fish.species = 2
	check(_visual() != model and _visual().species == 2, "setting species rebuilds the model in that species (%d)" % _visual().species)
	check(_visual().tail != null and _visual().fin_left != null, "the rebuilt model has its swim pivots")
	fish.species = 99
	check(fish.species == FishCharacter.species_count(FishCharacter.FishClass.HUNTER) - 1, "a species past the last is clamped (%d)" % fish.species)
	fish.character = FishCharacter.FishClass.GLIDER
	check(fish.species == 0 and _visual().fish_class == FishCharacter.FishClass.GLIDER and _visual().species == 0,
			"a new character starts on its first species")


func _check_saved_species() -> void:
	print("saved species (main's saved_species / store_species):")
	var settings := ConfigFile.new()
	MAIN_SCRIPT.store_species(settings, FishCharacter.FishClass.HUNTER, 3)
	MAIN_SCRIPT.store_species(settings, FishCharacter.FishClass.GLIDER, 2)
	check(settings.get_value("playground", "species_hunter", "") == "tiger", "saved by key under playground/species_hunter (%s)"
			% settings.get_value("playground", "species_hunter", ""))
	check(settings.save(PROBE_CFG) == OK, "saved")
	var loaded := ConfigFile.new()
	check(loaded.load(PROBE_CFG) == OK, "loaded")
	check(MAIN_SCRIPT.saved_species(loaded, FishCharacter.FishClass.HUNTER) == 3, "the Hunters' species comes back")
	check(MAIN_SCRIPT.saved_species(loaded, FishCharacter.FishClass.GLIDER) == 2, "the Gliders' own species comes back")
	check(MAIN_SCRIPT.saved_species(loaded, FishCharacter.FishClass.SKIRMISHER) == 0, "a class never saved: its first")
	loaded.set_value("playground", "species_skirmisher", "no_such_species")
	check(MAIN_SCRIPT.saved_species(loaded, FishCharacter.FishClass.SKIRMISHER) == 0, "an unknown key: its first")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_CFG))


func _check_main_flow() -> void:
	print("main's set_character / set_species (settings file put back after):")
	var path: String = MAIN_SCRIPT.SETTINGS_PATH
	var had_file := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_bytes(path) if had_file else PackedByteArray()
	var panel: Node = main.get_node("DebugPanel")
	main.set_character(FishCharacter.FishClass.HUNTER)
	main.set_species(3)
	await _ticks(2)
	check(fish.character == FishCharacter.FishClass.HUNTER and fish.species == 3 and _visual().species == 3, "Hunters in species 3")
	check(panel.get("_species") == 3, "the settings' Species row shows it")
	main.set_character(FishCharacter.FishClass.GLIDER)
	main.set_species(1)
	await _ticks(2)
	check(fish.character == FishCharacter.FishClass.GLIDER and fish.species == 1, "Gliders in species 1")
	main.set_character(FishCharacter.FishClass.HUNTER)
	await _ticks(2)
	check(fish.species == 3 and _visual().species == 3, "back to Hunters: its own species again (%d)" % fish.species)
	main.set_character(FishCharacter.FishClass.GLIDER)
	check(fish.species == 1, "back to Gliders: its own species again (%d)" % fish.species)
	var settings := ConfigFile.new()
	settings.load(path)
	check(settings.get_value("playground", "species_hunter", "") == "tiger" and settings.get_value("playground", "species_glider", "") == "eagle_ray",
			"both are in the settings file by key")
	var home: Node = main.get("_home")
	main.set_character(FishCharacter.FishClass.HUNTER)
	home.call("_cycle_species", 1)
	check(fish.species == 4, "the home screen's next species: species 4 (%d)" % fish.species)
	home.call("_cycle_species", 1)
	check(fish.species == 0, "and round to the first (%d)" % fish.species)
	check((home.get("_species_name") as Label).text == FishCharacter.species_name(FishCharacter.FishClass.HUNTER, 0), "the home screen names the species")
	# Put the player's settings back.
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(before)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_coop() -> void:
	print("online co-op roster:")
	fish.set_look(FishCharacter.FishClass.CHARMER, 2)
	var entry := CoopSession.player_entry(101, fish)
	check(entry.get("species") == "yamabuki" and entry.get("character") == int(FishCharacter.FishClass.CHARMER), "the roster entry carries the species' key (%s)" % entry.get("species"))
	check(CoopSession.entry_species(entry) == 2, "and it reads back as species 2")
	check(CoopSession.entry_species({"character": int(FishCharacter.FishClass.CHARMER)}) == 0, "an entry with no species (older build): the first")
	var coop: CoopSession = NetSession.coop
	var pid := 9901
	coop.roster[pid] = {"pid": pid, "peer": 99, "name": "Remote", "character": int(FishCharacter.FishClass.LANCER), "species": "sailfish", "index": 5}
	coop.call("_sync_puppets")
	await _ticks(2)
	var remote: FishController = coop.fish_of(pid)
	check(remote != null and remote.character == FishCharacter.FishClass.LANCER and remote.species == 2, "the remote fish wears its species")
	coop.roster[pid]["species"] = "striped_marlin"
	coop.call("_sync_puppets")
	check(remote != null and remote.species == 3, "and changes when its player's does")
	coop.roster.erase(pid)
	coop.call("_sync_puppets")


func _check_replay() -> void:
	print("replays:")
	fish.set_look(FishCharacter.FishClass.BULWARK, 3)
	var recorder := GoalRecorder.new()
	var fishes: Array[FishController] = [fish]
	recorder.setup(null, fishes)
	for i in 4:
		recorder.record(1.0 / 120.0)
	var data := recorder.clip(0.0, recorder.time)
	var player: Dictionary = data.players[0]
	check(player.get("species") == "scrawled" and player.get("hitbox_family") == "merc", "the clip's player carries the species' key (%s)" % player.get("species"))
	check(ReplayCar.species_of(player) == 3, "it reads back as species 3")
	var old := player.duplicate()
	old.erase("species")
	check(ReplayCar.species_of(old) == 0, "a replay with no species: the first")
	var car := ReplayCar.new()
	car.setup(player)
	add_child(car)
	var model: FishModel = car.get("_visual")
	check(model != null and model.fish_class == FishCharacter.FishClass.BULWARK and model.species == 3, "the replay's fish wears it")
	car.queue_free()
	var old_car := ReplayCar.new()
	old_car.setup(old)
	add_child(old_car)
	var old_model: FishModel = old_car.get("_visual")
	check(old_model != null and old_model.species == 0, "an old replay's fish wears its first")
	old_car.queue_free()
	await _ticks(1)
