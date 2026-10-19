extends Node
## Sound effects, phase 0 (planning_audio.md): the catalog's ids, profile file
## names (variations, layers, notes), the None / Beeps profiles, a profile
## folder made here (user://sfx_probe) picked, played from, reloaded with a new
## file, its trims and scale; missing sounds silent unless they beep; voices,
## cooldowns, loops; the buses and volumes; Settings > Audio and its Sound Board.
##   Godot_console.exe --headless --path . res://tests/audio_probe.tscn

const ROOT := "user://sfx_probe/profiles"
const KIT := ROOT + "/probe_kit"

var failures := 0
var _saved := {}


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for key: String in Sfx.KEYS:
		_saved[key] = Sfx.get(key)
	Sfx.keep_settings_off_disk = true
	_catalog()
	_names()
	_none_and_beeps()
	_make_kit()
	Sfx.extra_roots = PackedStringArray([ROOT])
	_kit()
	await _loops()
	_reload()
	_loose()
	_buses()
	await _panel()
	for key: String in _saved:
		Sfx.set(key, _saved[key])
	Sfx.extra_roots = PackedStringArray()
	Sfx.load_profile()
	_remove(ROOT.get_base_dir())
	print("audio_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _catalog() -> void:
	print("catalog:")
	var events := SoundCatalog.events()
	check(events.size() == SoundCatalog.ROWS.size(), "every id is listed once (%d events)" % events.size())
	var shape := RegEx.create_from_string("^[a-z]+/[a-z0-9_]+$")
	var notes := RegEx.create_from_string("_n\\d\\d$")
	var bad := []
	for id: String in events:
		if shape.search(id) == null or notes.search(id) != null or not SoundCatalog.CATEGORIES.has(events[id].category):
			bad.append(id)
	check(bad.is_empty(), "ids are folder/name, lower case, in a category, not note-like %s" % [bad])
	var loops_ok := true
	for id: String in events:
		if id.ends_with("_loop") and not events[id].loop:
			loops_ok = false
	check(loops_ok, "every *_loop id loops")
	var falls_ok := true
	for id: String in SoundCatalog.FALLBACKS:
		falls_ok = falls_ok and SoundCatalog.has(id) and SoundCatalog.has(SoundCatalog.FALLBACKS[id])
	check(falls_ok, "fallbacks are between events")
	var hit := SoundCatalog.info("ball/hit")
	check(hit.is_3d and hit.layers and hit.voices == 3 and hit.bus == "World", "flags parse (ball/hit: 3d layers voices=3, World)")
	check(SoundCatalog.info("ui/select").bus == "UI" and SoundCatalog.info("music/menu").bus == "Music"
			and SoundCatalog.info("voice/go").bus == "Voice" and SoundCatalog.info("amb/ocean_loop").bus == "Ambience", "buses from the folder")
	check(is_equal_approx(SoundCatalog.info("fish/boost_empty").cooldown, 0.5), "cooldowns parse")
	var sheet := SoundCatalog.sheet([])
	check(sheet.split("\n", false).size() == events.size() + 1 and sheet.contains("ball/hit,ball/hit.wav,P1"), "the recording sheet lists every event")


func _names() -> void:
	print("file names:")
	check(SoundProfile.parse_name("ball/hit.wav") == {"id": "ball/hit", "note": -1, "layer": -1, "variation": 0}, "plain")
	check(SoundProfile.parse_name("ball/hit-3.ogg").variation == 3, "variation")
	var both := SoundProfile.parse_name("ball/hit@2-3.wav")
	check(both.id == "ball/hit" and both.layer == 2 and both.variation == 3, "layer and variation")
	var note := SoundProfile.parse_name("nature/pearl_n07-2.wav")
	check(note.id == "nature/pearl" and note.note == 7 and note.variation == 2, "note and variation")
	check(SoundProfile.parse_name("fish/boost_loop.mp3").id == "fish/boost_loop", "underscores stay in the id")
	check(SoundProfile.parse_name("profile.cfg").is_empty() and SoundProfile.parse_name("ball/hit.wav.import").is_empty(), "not sounds")
	var scale := SoundProfile.built_in("x", "X")
	scale.scale = "major"
	check([scale.semitone(0), scale.semitone(2), scale.semitone(7), scale.semitone(9)] == [0, 4, 12, 16], "major scale steps climb octaves")
	scale.scale = "major_pentatonic"
	check(scale.semitone(5) == 12, "pentatonic's sixth step is the octave")


func _none_and_beeps() -> void:
	print("None and Beeps:")
	Sfx.set_value("beep_missing", false)
	Sfx.set_value("profile", Sfx.NONE)
	check(Sfx.active_profile() == null and Sfx.status("ball/hit") == "none", "None loads nothing")
	check(Sfx.play("ui/select") == null and Sfx.play_at("ball/hit", Vector3.ZERO) == null, "None is silent")
	Sfx.set_value("beep_missing", true)
	var beep: Node = Sfx.play("ui/select")
	check(beep is AudioStreamPlayer and (beep as AudioStreamPlayer).playing, "with Beep for missing sounds, a missing sound beeps")
	check(Sfx.play_at("ball/hit", Vector3(1, 2, 3)) is AudioStreamPlayer3D, "a 3D beep is placed in the world")
	Sfx.set_value("beep_missing", false)
	check(Sfx.audition("ball/bounce") == "beep", "the Sound Board plays the beep under None")
	Sfx.set_value("profile", Sfx.BEEPS)
	check(Sfx.status("arena/goal_net") == "have" and Sfx.play("match/go") != null, "Beeps has every event")
	var choices: Array = Sfx.profile_choices()
	check(choices[0] == ["None", Sfx.NONE] and choices[1][1] == Sfx.BEEPS, "None and Beeps head the profile list")
	check(Sfx.play("nope/never") == null, "an id not in the catalog plays nothing")
	Sfx.stop_all()


func _make_kit() -> void:
	_remove(ROOT.get_base_dir())
	for file: String in ["ball/hit@1.wav", "ball/hit@2.wav", "ui/select-1.wav", "ui/select-2.wav", "ui/move.wav",
			"nature/pearl_n00.wav", "nature/pearl_n04.wav", "unnatural/zombie_die.wav", "fish/boost_loop.wav", "typo/nothing.wav"]:
		_write_wav(KIT.path_join(file), 0.3 if file.contains("loop") else 0.2)
	var config := ConfigFile.new()
	config.set_value("profile", "name", "Probe Kit")
	config.set_value("profile", "scale", "major")
	config.set_value("profile", "underwater_filter", false)
	config.set_value("mix", "ui/select", {"volume_db": -6.0, "pitch_jitter": 0.0})
	config.save(KIT.path_join(SoundProfile.CONFIG))


func _kit() -> void:
	print("a profile folder:")
	var found := false
	for choice: Array in Sfx.profile_choices():
		found = found or choice == ["Probe Kit", "probe_kit"]
	check(found, "it's offered by its profile.cfg name")
	Sfx.set_value("profile", "probe_kit")
	var kit: SoundProfile = Sfx.active_profile()
	check(kit != null and kit.title == "Probe Kit" and kit.scale == "major", "picked, with its config")
	check(Array(kit.unknown_files) == ["typo/nothing.wav"], "a file that isn't an event is reported")
	check(Sfx.summary().contains("typo/nothing.wav"), "and said when it loads")
	check(Sfx.status("ball/hit") == "have" and Sfx.status("unnatural/zombie_die_tank") == "borrowed"
			and Sfx.status("ball/bounce") == "missing", "have / borrowed / missing")
	check(Sfx.play("ball/bounce") == null, "a missing sound is silent")
	check(Sfx.play("unnatural/zombie_die_tank") != null, "a borrowed one plays the sound it borrows")
	# Variations: never the same twice running.
	var last: AudioStream
	var repeats := 0
	for i in 12:
		var player: AudioStreamPlayer = Sfx.play("ui/select")
		if player.stream == last:
			repeats += 1
		last = player.stream
	check(repeats == 0, "variations never repeat back to back")
	check(is_equal_approx((Sfx.play("ui/select") as AudioStreamPlayer).volume_db, -6.0), "the profile's trim sets the volume")
	# Layers by intensity.
	var hit: Dictionary = kit.events["ball/hit"]
	check((Sfx.play_at("ball/hit", Vector3.ZERO, 0.2) as AudioStreamPlayer3D).stream == hit.layers[1][0], "soft hit: layer 1")
	check((Sfx.play_at("ball/hit", Vector3.ZERO, 0.9) as AudioStreamPlayer3D).stream == hit.layers[2][0], "hard hit: layer 2")
	# Notes of a pitched event (major: steps 0, 1, 2 are semitones 0, 2, 4).
	var pearl: Dictionary = kit.events["nature/pearl"]
	var root: AudioStreamPlayer = Sfx.play_pitched("nature/pearl", 0)
	check(root.stream == pearl.notes[0][0] and is_equal_approx(root.pitch_scale, 1.0), "step 0: the root note's file")
	var second: AudioStreamPlayer = Sfx.play_pitched("nature/pearl", 1)
	check(second.stream == pearl.notes[0][0] and is_equal_approx(second.pitch_scale, pow(2.0, 2.0 / 12.0)), "step 1: the root bent up a tone")
	var third: AudioStreamPlayer = Sfx.play_pitched("nature/pearl", 2)
	check(third.stream == pearl.notes[4][0] and is_equal_approx(third.pitch_scale, 1.0), "step 2: its own note's file")
	# Voices and cooldowns.
	Sfx.stop_all()
	for i in 4:
		Sfx.play("ui/move")
	var moving := 0
	for player in Sfx.get_children():
		if player is AudioStreamPlayer and (player as AudioStreamPlayer).playing and player.get_meta("sfx_id", "") == "ui/move":
			moving += 1
	check(moving == 2, "ui/move plays at most 2 at once (%d)" % moving)
	Sfx.set_value("beep_missing", true)
	check(Sfx.play("fish/boost_empty") != null and Sfx.play("fish/boost_empty") == null, "a cooldown drops a start too soon after the last")
	Sfx.set_value("beep_missing", false)
	check(not AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("World"), 0), "underwater_filter=false turns the filter off")


func _loops() -> void:
	print("loops:")
	var boost: int = Sfx.start_loop("fish/boost_loop")
	var player: AudioStreamPlayer3D = Sfx._loops[boost].player
	check(player.playing and (player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "a loop plays, looping")
	Sfx.set_loop(boost, 0.5, 1.5)
	check(is_equal_approx(player.pitch_scale, 1.5) and is_equal_approx(player.volume_db, linear_to_db(0.5)), "set_loop moves its volume and pitch")
	Sfx.stop_loop(boost, 0.05)
	check(not Sfx.is_looping(boost), "stop_loop ends it")
	await get_tree().create_timer(0.2).timeout
	check(not is_instance_valid(player), "and it fades out and goes")
	var follow := Node3D.new()
	add_child(follow)
	follow.position = Vector3(5, 0, 0)
	var scrape: int = Sfx.start_loop("fish/scrape_loop", follow)
	var scraper: AudioStreamPlayer3D = Sfx._loops[scrape].player
	check(scraper.stream == null and Sfx.is_looping(scrape), "a loop the profile lacks waits, silent")
	await get_tree().process_frame
	check(scraper.global_position.is_equal_approx(Vector3(5, 0, 0)), "a 3D loop follows its node")
	_write_wav(KIT.path_join("fish/scrape_loop.wav"), 0.3)
	Sfx.load_profile()
	check(scraper.stream != null and scraper.playing, "and starts when a reload brings its file")
	Sfx.stop_loop(scrape, 0.0)
	follow.queue_free()


func _reload() -> void:
	print("hot reload:")
	check(Sfx.status("ball/bounce") == "missing", "ball/bounce missing")
	_write_wav(KIT.path_join("ball/bounce.wav"), 0.1)
	var said: String = Sfx.load_profile()
	check(Sfx.status("ball/bounce") == "have" and Sfx.play_at("ball/bounce", Vector3.ZERO) != null, "a file saved, then Reload, plays")
	check(said.begins_with("Sound profile: Probe Kit"), "Reload says what it loaded: %s" % said)


## An exported game's loose profiles (audio/profiles beside the .exe): a
## profile only there is offered; one also bundled gains the loose files, and
## an event the loose folder has is its alone.
func _loose() -> void:
	print("loose profiles beside the game:")
	var loose := ROOT.get_base_dir().path_join("loose")
	_write_wav(loose.path_join("probe_kit/ball/hit.wav"), 0.1)
	_write_wav(loose.path_join("probe_kit/fish/jump.wav"), 0.1)
	_write_wav(loose.path_join("loose_only/ui/back.wav"), 0.1)
	var was := Sfx.loose_root
	Sfx.loose_root = loose
	check(Sfx.profile_choices().has(["Loose Only", "loose_only"]), "a profile only beside the game is offered")
	var said: String = Sfx.load_profile()
	var kit: SoundProfile = Sfx.active_profile()
	check(Sfx.status("fish/jump") == "have" and Sfx.status("ui/select") == "have", "the bundled profile gains the loose files and keeps its own")
	check(Array(kit.events["ball/hit"].files) == ["ball/hit.wav"] and kit.events["ball/hit"].layers.is_empty(),
			"an event in the loose folder is its alone (ball/hit's bundled layers dropped)")
	check(kit.title == "Probe Kit" and said.contains("loose files"), "its name stays, and Reload says loose files are in: %s" % said)
	Sfx.loose_root = was
	Sfx.load_profile()
	check(Sfx.status("fish/jump") == "missing", "without them, back to the bundled files")


func _buses() -> void:
	print("buses:")
	var ok := true
	for bus: String in Sfx.BUSES:
		var index := AudioServer.get_bus_index(bus)
		ok = ok and index != -1 and AudioServer.get_bus_send(index) == Sfx.BUSES[bus]
	check(ok, "Music, Voice, SFX, UI, World, Ambience, each sending where it should")
	Sfx.set_value("master_volume", 50)
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Master volume 50 is half")
	Sfx.set_value("sfx_volume", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "0 mutes")
	Sfx.set_value("sfx_volume", 100)
	Sfx.set_value("master_volume", 100)
	check((Sfx.play("ui/move") as AudioStreamPlayer).process_mode == Node.PROCESS_MODE_ALWAYS
			and (Sfx.play_at("ball/hit", Vector3.ZERO) as Node).process_mode == Node.PROCESS_MODE_PAUSABLE,
			"menu sounds play through a pause, the world's pause with it")
	var bed := Sfx.start_loop("amb/ocean_loop")
	var moon := Sfx.start_loop("stage/blood_moon_loop")
	check(Sfx._loops[bed].player.process_mode == Node.PROCESS_MODE_ALWAYS and Sfx._loops[moon].player.process_mode == Node.PROCESS_MODE_ALWAYS,
			"ambient beds and the blood moon's loop keep playing while paused (card picks)")
	Sfx.stop_loop(bed)
	Sfx.stop_loop(moon)


func _panel() -> void:
	print("Settings > Audio:")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel: Node = main.get_node("DebugPanel")
	var rows: Dictionary = panel._rows
	check(rows.has("audio/profile") and rows.has("audio/master_volume") and rows.has("audio/reload")
			and rows.has("audio/beep_missing") and rows.has("audio/sheet") and rows.has("audio/music_profile"), "its options")
	var board := 0
	for key: String in rows:
		if key.begins_with("audio/board:"):
			board += 1
	check(board == SoundCatalog.events().size(), "the Sound Board has every event (%d)" % board)
	var titles := []
	for tab: Dictionary in panel._tabs["audio"]:
		titles.append(tab.title)
	check(titles == ["Sound", "Sound Board"], "two tabs: Sound, Sound Board")
	check(panel._value_text("audio/board:ball/hit")[0] == "HAVE ›" and panel._value_text("audio/board:ball/bounce")[0] == "HAVE ›"
			and panel._value_text("audio/board:ui/back")[0] == "MISSING ›", "rows say what the profile has")
	var kit_offered := false
	for choice: Array in panel._meta["audio/profile"].choices:
		kit_offered = kit_offered or choice[1] == "probe_kit"
	check(kit_offered, "the profile picker offers the folders")
	panel._step("audio/master_volume", -1)
	check(Sfx.master_volume == 95, "left on Master volume: 95")
	panel._set_value("audio/master_volume", 100)
	panel._act("audio/board:ui/back")
	check(String(panel._status.text).contains("placeholder beep"), "A on a missing sound plays its beep and says so")
	panel._set_value("audio/profile", Sfx.NONE)
	check(Sfx.active_profile() == null and panel._value_text("audio/board:ball/hit")[0] == "›", "picking None from Settings")
	main.queue_free()
	await get_tree().process_frame


func _write_wav(path: String, seconds: float) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(seconds * rate) * 2)
	var frequency := 200.0 + randf() * 600.0
	for i in data.size() / 2:
		data.encode_s16(i * 2, int(sin(TAU * frequency * i / rate) * 8000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.save_to_wav(path)


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(sub))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
