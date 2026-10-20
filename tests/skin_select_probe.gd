extends Node
## Skin selection: setting a fish's skin rebuilds its model in that skin; each
## family's skin is saved by key and comes back (main's saved_skin / store_skin,
## and main's set_character / set_skin through the settings file, which is put
## back afterwards); the online co-op roster carries the skin and remote fish
## wear it; a goal replay records the skin and its ghost wears it (old replays:
## the family's first).
##   Godot_console.exe --headless --path . res://tests/skin_select_probe.tscn

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const PROBE_CFG := "user://skin_select_probe.cfg"

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
	_check_saved_skins()
	await _check_main_flow()
	await _check_coop()
	await _check_replay()
	print("skin_select_probe: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _visual() -> FishModel:
	return fish.get("_visual")


func _check_fish() -> void:
	print("the fish's skin:")
	check(FishCharacter.is_skin_unlocked(FishCharacter.Family.DOMINUS, 4), "every skin is unlocked for now")
	fish.set_look(FishCharacter.Family.DOMINUS, 4)
	var model := _visual()
	check(fish.character == FishCharacter.Family.DOMINUS and fish.skin == 4, "set_look: Dominus, skin 4")
	check(model.family == FishCharacter.Family.DOMINUS and model.skin == 4, "its model is the Hammerhead (skin %d)" % model.skin)
	fish.skin = 2
	check(_visual() != model and _visual().skin == 2, "setting skin rebuilds the model in that skin (%d)" % _visual().skin)
	check(_visual().tail != null and _visual().fin_left != null, "the rebuilt model has its swim pivots")
	fish.skin = 99
	check(fish.skin == FishCharacter.skin_count(FishCharacter.Family.DOMINUS) - 1, "a skin past the last is clamped (%d)" % fish.skin)
	fish.character = FishCharacter.Family.PLANK
	check(fish.skin == 0 and _visual().family == FishCharacter.Family.PLANK and _visual().skin == 0,
			"a new character starts on its first skin")


func _check_saved_skins() -> void:
	print("saved skins (main's saved_skin / store_skin):")
	var settings := ConfigFile.new()
	MAIN_SCRIPT.store_skin(settings, FishCharacter.Family.DOMINUS, 3)
	MAIN_SCRIPT.store_skin(settings, FishCharacter.Family.PLANK, 2)
	check(settings.get_value("playground", "skin_dominus", "") == "tiger", "saved by key under playground/skin_dominus (%s)"
			% settings.get_value("playground", "skin_dominus", ""))
	check(settings.save(PROBE_CFG) == OK, "saved")
	var loaded := ConfigFile.new()
	check(loaded.load(PROBE_CFG) == OK, "loaded")
	check(MAIN_SCRIPT.saved_skin(loaded, FishCharacter.Family.DOMINUS) == 3, "Dominus's skin comes back")
	check(MAIN_SCRIPT.saved_skin(loaded, FishCharacter.Family.PLANK) == 2, "Plank's own skin comes back")
	check(MAIN_SCRIPT.saved_skin(loaded, FishCharacter.Family.OCTANE) == 0, "a family never saved: its first")
	loaded.set_value("playground", "skin_octane", "no_such_skin")
	check(MAIN_SCRIPT.saved_skin(loaded, FishCharacter.Family.OCTANE) == 0, "an unknown key: its first")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_CFG))


func _check_main_flow() -> void:
	print("main's set_character / set_skin (settings file put back after):")
	var path: String = MAIN_SCRIPT.SETTINGS_PATH
	var had_file := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_bytes(path) if had_file else PackedByteArray()
	var panel: Node = main.get_node("DebugPanel")
	main.set_character(FishCharacter.Family.DOMINUS)
	main.set_skin(3)
	await _ticks(2)
	check(fish.character == FishCharacter.Family.DOMINUS and fish.skin == 3 and _visual().skin == 3, "Dominus in skin 3")
	check(panel.get("_skin") == 3, "the settings' Skin row shows it")
	main.set_character(FishCharacter.Family.PLANK)
	main.set_skin(1)
	await _ticks(2)
	check(fish.character == FishCharacter.Family.PLANK and fish.skin == 1, "Plank in skin 1")
	main.set_character(FishCharacter.Family.DOMINUS)
	await _ticks(2)
	check(fish.skin == 3 and _visual().skin == 3, "back to Dominus: its own skin again (%d)" % fish.skin)
	main.set_character(FishCharacter.Family.PLANK)
	check(fish.skin == 1, "back to Plank: its own skin again (%d)" % fish.skin)
	var settings := ConfigFile.new()
	settings.load(path)
	check(settings.get_value("playground", "skin_dominus", "") == "tiger" and settings.get_value("playground", "skin_plank", "") == "eagle_ray",
			"both are in the settings file by key")
	var home: Node = main.get("_home")
	main.set_character(FishCharacter.Family.DOMINUS)
	home.call("_cycle_skin", 1)
	check(fish.skin == 4, "the home screen's next skin: skin 4 (%d)" % fish.skin)
	home.call("_cycle_skin", 1)
	check(fish.skin == 0, "and round to the first (%d)" % fish.skin)
	check((home.get("_skin_name") as Label).text == FishCharacter.skin_name(FishCharacter.Family.DOMINUS, 0), "the home screen names the skin")
	# Put the player's settings back.
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(before)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_coop() -> void:
	print("online co-op roster:")
	fish.set_look(FishCharacter.Family.HYBRID, 2)
	var entry := CoopSession.player_entry(101, fish)
	check(entry.get("skin") == "yamabuki" and entry.get("character") == int(FishCharacter.Family.HYBRID), "the roster entry carries the skin's key (%s)" % entry.get("skin"))
	check(CoopSession.entry_skin(entry) == 2, "and it reads back as skin 2")
	check(CoopSession.entry_skin({"character": int(FishCharacter.Family.HYBRID)}) == 0, "an entry with no skin (older build): the first")
	var coop: CoopSession = NetSession.coop
	var pid := 9901
	coop.roster[pid] = {"pid": pid, "peer": 99, "name": "Remote", "character": int(FishCharacter.Family.BREAKOUT), "skin": "sailfish", "index": 5}
	coop.call("_sync_puppets")
	await _ticks(2)
	var remote: FishController = coop.fish_of(pid)
	check(remote != null and remote.character == FishCharacter.Family.BREAKOUT and remote.skin == 2, "the remote fish wears its skin")
	coop.roster[pid]["skin"] = "striped_marlin"
	coop.call("_sync_puppets")
	check(remote != null and remote.skin == 3, "and changes when its player's does")
	coop.roster.erase(pid)
	coop.call("_sync_puppets")


func _check_replay() -> void:
	print("replays:")
	fish.set_look(FishCharacter.Family.MERC, 3)
	var recorder := GoalRecorder.new()
	var fishes: Array[FishController] = [fish]
	recorder.setup(null, fishes)
	for i in 4:
		recorder.record(1.0 / 120.0)
	var data := recorder.clip(0.0, recorder.time)
	var player: Dictionary = data.players[0]
	check(player.get("skin") == "scrawled" and player.get("hitbox_family") == "merc", "the clip's player carries the skin's key (%s)" % player.get("skin"))
	check(ReplayCar.skin_of(player) == 3, "it reads back as skin 3")
	var old := player.duplicate()
	old.erase("skin")
	check(ReplayCar.skin_of(old) == 0, "a replay with no skin: the first")
	var car := ReplayCar.new()
	car.setup(player)
	add_child(car)
	var model: FishModel = car.get("_visual")
	check(model != null and model.family == FishCharacter.Family.MERC and model.skin == 3, "the replay's fish wears it")
	car.queue_free()
	var old_car := ReplayCar.new()
	old_car.setup(old)
	add_child(old_car)
	var old_model: FishModel = old_car.get("_visual")
	check(old_model != null and old_model.skin == 0, "an old replay's fish wears its first")
	old_car.queue_free()
	await _ticks(1)
