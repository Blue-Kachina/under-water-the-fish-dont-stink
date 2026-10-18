extends Node
## Sound effects (autoloaded as "Sfx", planning_audio.md). Gameplay asks for an
## event by its SoundCatalog id; the chosen sound profile decides what's heard:
##   Sfx.play("ui/select")
##   Sfx.play_at("ball/hit", ball.global_position, 0.8)   # how hard, 0..1
##   Sfx.play_pitched("nature/pearl", streak)             # climbs the scale
##   var loop := Sfx.start_loop("fish/boost_loop", fish)  # follows the fish
##   Sfx.set_loop(loop, 0.7, 1.2); Sfx.stop_loop(loop)
## A sound the profile lacks is silent, unless Beep for missing sounds is on.
## "None" (the starting profile) has nothing; "Beeps" is a made-up placeholder
## beep for every event. Real profiles are folders in PROFILE_DIR.
##
## Also the audio settings (saved on this PC, user://playground.cfg section
## "audio"; Settings > Audio edits them) and the mixer's buses:
##   Master <- Music, Voice, SFX <- UI, World <- Ambience
## World carries the underwater low-pass and reverb (a profile can turn them off).

signal changed(key: String)
## The active profile was (re)loaded.
signal profile_loaded

const SETTINGS_PATH := "user://playground.cfg"
const SECTION := "audio"
const PROFILE_DIR := "res://audio/profiles"
const NONE := "none"
const BEEPS := "beeps"
## The music profile that means "the sound profile's".
const SAME := ""
## Pooled players, beyond which the oldest one-shot is cut off.
const MAX_2D := 32
const MAX_3D := 48
## Buses: name -> the bus it sends to. In creation order.
const BUSES := {"Music": "Master", "Voice": "Master", "SFX": "Master", "UI": "SFX", "World": "SFX", "Ambience": "World"}
## Which bus each volume setting turns.
const VOLUME_BUSES := {"master_volume": "Master", "sfx_volume": "SFX", "music_volume": "Music", "voice_volume": "Voice"}
const KEYS := ["profile", "music_profile", "master_volume", "sfx_volume", "music_volume", "voice_volume", "beep_missing"]
const DEFAULTS := {"profile": NONE, "music_profile": SAME, "master_volume": 100, "sfx_volume": 100, "music_volume": 80,
		"voice_volume": 100, "beep_missing": false}
## Pitch jitter (±) for one-shots whose profile doesn't set one: no two the same.
const DEFAULT_JITTER := 0.03

## The sound profile heard (a folder name, NONE or BEEPS).
var profile: String = DEFAULTS.profile
## Whose music plays (SAME: the sound profile's).
var music_profile: String = DEFAULTS.music_profile
var master_volume: int = DEFAULTS.master_volume
var sfx_volume: int = DEFAULTS.sfx_volume
var music_volume: int = DEFAULTS.music_volume
var voice_volume: int = DEFAULTS.voice_volume
## A missing sound plays its placeholder beep (finding the gaps).
var beep_missing: bool = DEFAULTS.beep_missing
## More folders of profiles (probes); same layout as PROFILE_DIR.
var extra_roots: PackedStringArray = []
## Don't read or write the settings file (probes).
var keep_settings_off_disk := false

var _profile: SoundProfile
var _beeps: SoundProfile
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
## Event id -> its players still playing, oldest first.
var _voices := {}
## Event id -> when it last started (ms).
var _last_start := {}
## "id|list" -> the variation last picked, so it isn't picked twice running.
var _last_variation := {}
## Handle -> {id, player, follow}.
var _loops := {}
var _next_loop := 1
var _warned := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_make_buses()
	if not keep_settings_off_disk:
		var settings := ConfigFile.new()
		if settings.load(SETTINGS_PATH) == OK:
			for key: String in KEYS:
				set(key, settings.get_value(SECTION, key, get(key)))
	if profile != NONE and profile != BEEPS and not _profile_dirs().has(profile):
		profile = NONE  # its folder's gone
	_apply_volumes()
	load_profile()


func _process(_delta: float) -> void:
	for handle: int in _loops:
		var loop: Dictionary = _loops[handle]
		if loop.player is AudioStreamPlayer3D and is_instance_valid(loop.follow) and loop.follow is Node3D:
			(loop.player as AudioStreamPlayer3D).global_position = (loop.follow as Node3D).global_position


# --- Playing ---------------------------------------------------------------------

## Plays event `id` (2D; a 3D event plays where the listener is). `intensity`
## 0..1 picks its @layer. The player, or null if nothing played.
func play(id: String, intensity := 1.0) -> Node:
	return _start(id, intensity, null, -1)


## Plays event `id` at `at` in the world.
func play_at(id: String, at: Vector3, intensity := 1.0) -> Node:
	return _start(id, intensity, at, -1)


## Plays pitched event `id` at step `step` of the profile's scale (0 is the
## root; a streak counts up). `at` (a Vector3) places it in the world.
func play_pitched(id: String, step: int, at: Variant = null, intensity := 1.0) -> Node:
	return _start(id, intensity, at, maxi(step, 0))


## Starts looping event `id`, following `follow` (a Node3D) if given. A handle
## for set_loop / stop_loop; it keeps going (silent) when the profile has no
## sound for it, and picks one up on a reload.
func start_loop(id: String, follow: Node = null) -> int:
	_check_id(id)
	var info := SoundCatalog.info(id)
	var player: Node
	if info.get("is_3d", false):
		player = AudioStreamPlayer3D.new()
	else:
		player = AudioStreamPlayer.new()
	player.bus = info.get("bus", "World")
	player.process_mode = _process_mode_for(player.bus)
	add_child(player)
	var handle := _next_loop
	_next_loop += 1
	_loops[handle] = {"id": id, "player": player, "follow": follow, "volume": 1.0, "pitch": 1.0}
	_fill_loop(handle)
	_process(0.0)
	return handle


## A loop's loudness (0..1) and pitch (1 = as recorded).
func set_loop(handle: int, volume := 1.0, pitch := 1.0) -> void:
	if not _loops.has(handle):
		return
	var loop: Dictionary = _loops[handle]
	loop.volume = volume
	loop.pitch = pitch
	_tune_loop(loop)


## Stops a loop, fading over `fade` seconds.
func stop_loop(handle: int, fade := 0.12) -> void:
	if not _loops.has(handle):
		return
	var player: Node = _loops[handle].player
	_loops.erase(handle)
	if fade <= 0.0 or not player.is_inside_tree():
		player.queue_free()
		return
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", -60.0, fade)
	tween.tween_callback(player.queue_free)


func is_looping(handle: int) -> bool:
	return _loops.has(handle)


## Stops everything playing (a mode ending).
func stop_all() -> void:
	for handle: int in _loops.keys():
		stop_loop(handle, 0.0)
	for player in _pool_2d:
		player.stop()
	for player in _pool_3d:
		player.stop()
	_voices.clear()


# --- The Sound Board ---------------------------------------------------------------

## Whether the sound profile has event `id`: "have", "borrowed" (another
## event's, SoundCatalog.FALLBACKS) or "missing". "none" for the None profile.
func status(id: String) -> String:
	if _profile == null:
		return NONE
	if _profile == _beeps or _profile.has(id):
		return "have"
	if _profile.has(SoundCatalog.FALLBACKS.get(id, "")):
		return "borrowed"
	return "missing"


## Plays event `id` to hear it (2D, whatever the event): the profile's sound,
## else its placeholder beep. What played: "profile", "beep" ("" for an id
## that isn't an event).
func audition(id: String) -> String:
	var found := _resolve(id, true)
	if found.is_empty():
		return ""
	var from_profile: bool = found[0] != _beeps
	_play_from(found[0], found[1], id, 1.0, null, 0 if SoundCatalog.info(id).get("pitched", false) else -1)
	return "profile" if from_profile else "beep"


# --- Profiles -----------------------------------------------------------------------

## The profiles to pick from: [[title, id], ...], None and Beeps first.
func profile_choices() -> Array:
	var choices := [["None", NONE], ["Beeps (placeholders)", BEEPS]]
	var dirs := _profile_dirs()
	for profile_id: String in dirs:
		var config := ConfigFile.new()
		var title := profile_id.capitalize()
		if config.load(String(dirs[profile_id]).path_join(SoundProfile.CONFIG)) == OK:
			title = str(config.get_value("profile", "name", title))
		choices.append([title, profile_id])
	return choices


## The music picker's choices: "Same as sound profile", then the profiles.
func music_choices() -> Array:
	return [["Same as sound profile", SAME]] + profile_choices()


## The loaded sound profile (null for None).
func active_profile() -> SoundProfile:
	return _profile


## Whose music plays (a profile id).
func music_profile_id() -> String:
	return profile if music_profile == SAME else music_profile


## (Re)loads the sound profile from disk, so a file just saved is heard. Says
## what it found.
func load_profile() -> String:
	match profile:
		NONE:
			_profile = null
		BEEPS:
			_profile = _beeps_profile()
		_:
			_profile = SoundProfile.open(_profile_dirs().get(profile, ""))
	_apply_underwater()
	for handle: int in _loops:
		_fill_loop(handle)
	profile_loaded.emit()
	return summary()


## A line about the sound profile: how many events it covers, and any files
## that don't name an event.
func summary() -> String:
	if _profile == null:
		return "Sound profile: None (silent)"
	if profile == BEEPS:
		return "Sound profile: placeholder beeps for every event"
	var files := 0
	for event: String in _profile.events:
		files += _profile.file_count(event)
	var text := "Sound profile: %s · %d of %d events (%d files)" % [_profile.title, _profile.events.size(),
			SoundCatalog.events().size(), files]
	if not _profile.unknown_files.is_empty():
		text += " · not events: %s" % ", ".join(_profile.unknown_files)
	return text


## Writes the recording sheet (SoundCatalog.sheet) for every profile folder.
## Beside the profiles when running from the project, else in user://. Its path.
func write_sheet() -> String:
	var profiles := []
	var dirs := _profile_dirs()
	for profile_id: String in dirs:
		var opened := SoundProfile.open(dirs[profile_id])
		if opened:
			profiles.append(opened)
	var path := "res://audio/sound_sheet.csv" if OS.has_feature("editor") else "user://sound_sheet.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(SoundCatalog.sheet(profiles))
	file.close()
	return ProjectSettings.globalize_path(path)


## Profile folders: id -> path.
func _profile_dirs() -> Dictionary:
	var dirs := {}
	for root: String in [PROFILE_DIR] + Array(extra_roots):
		if not DirAccess.dir_exists_absolute(root):
			continue
		for folder in DirAccess.get_directories_at(root):
			if folder not in [NONE, BEEPS] and not folder.begins_with("."):
				dirs[folder] = root.path_join(folder)
	return dirs


# --- Settings -----------------------------------------------------------------------

## Changes one audio setting, applies it and remembers it.
func set_value(key: String, value: Variant) -> void:
	if key not in KEYS or get(key) == value:
		return
	set(key, value)
	if key == "profile":
		load_profile()
	elif VOLUME_BUSES.has(key):
		_apply_volumes()
	if not keep_settings_off_disk:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value(SECTION, key, value)
		settings.save(SETTINGS_PATH)
	changed.emit(key)


# --- Inside -----------------------------------------------------------------------

func _start(id: String, intensity: float, at: Variant, step: int) -> Node:
	_check_id(id)
	var found := _resolve(id, beep_missing)
	if found.is_empty():
		return null
	return _play_from(found[0], found[1], id, intensity, at, step)


## Where event `id`'s sound comes from: [profile, the event it has], or [].
## The sound profile's own, or the one it borrows (SoundCatalog.FALLBACKS),
## else the placeholder beep when `beep` (missing sounds beep).
func _resolve(id: String, beep: bool) -> Array:
	if _profile and _profile == _beeps:
		beep = true
	elif _profile:
		if _profile.has(id):
			return [_profile, id]
		var other: String = SoundCatalog.FALLBACKS.get(id, "")
		if _profile.has(other):
			return [_profile, other]
	if beep and SoundCatalog.has(id):
		_ensure_beep(id)
		return [_beeps_profile(), id]
	return []


func _play_from(from: SoundProfile, event: String, id: String, intensity: float, at: Variant, step: int) -> Node:
	var info := SoundCatalog.info(id)
	var trims: Dictionary = from.mix.get(event, {})
	var cooldown: float = info.get("cooldown", 0.0)
	var now := Time.get_ticks_msec()
	if cooldown > 0.0 and now - int(_last_start.get(id, -100000)) < cooldown * 1000.0:
		return null
	var picked := _pick(from, event, clampf(intensity, 0.0, 1.0), step)
	if picked.is_empty():
		return null
	_last_start[id] = now
	# Voices: past its limit, the oldest one stops.
	var playing: Array = _voices.get_or_add(id, [])
	playing = playing.filter(func(p: Node) -> bool: return is_instance_valid(p) and p.playing and p.get_meta("sfx_id", "") == id)
	var limit := int(trims.get("voices", info.get("voices", SoundCatalog.DEFAULT_VOICES)))
	while playing.size() >= maxi(limit, 1):
		playing.pop_front().stop()
	var player := _free_player(at != null)
	player.stream = picked.stream
	player.bus = info.get("bus", "World")
	player.process_mode = _process_mode_for(player.bus)
	var jitter := float(trims.get("pitch_jitter", 0.0 if step >= 0 else DEFAULT_JITTER))
	player.pitch_scale = picked.pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	player.volume_db = float(trims.get("volume_db", 0.0)) + picked.volume_db
	if at != null:
		(player as AudioStreamPlayer3D).global_position = at
	player.set_meta("sfx_id", id)
	player.play()
	playing.append(player)
	_voices[id] = playing
	return player


## The stream to play for `event`: {stream, pitch, volume_db}, or {}.
func _pick(from: SoundProfile, event: String, intensity: float, step: int) -> Dictionary:
	var entry: Dictionary = from.events[event]
	var choices: Array = entry.plain
	var pitch := 1.0
	var volume_db := 0.0
	if step >= 0:
		var wanted := from.semitone(step)
		if not entry.notes.is_empty():
			var below: Array = entry.notes.keys().filter(func(n: int) -> bool: return n <= wanted)
			var note: int = below.max() if not below.is_empty() else entry.notes.keys().min()
			choices = entry.notes[note]
			pitch = pow(2.0, (wanted - note) / 12.0)
		else:
			pitch = pow(2.0, wanted / 12.0)
	if not entry.layers.is_empty() and (choices.is_empty() or step < 0):
		var layers: Array = entry.layers.keys()
		layers.sort()
		var at := clampi(ceili(intensity * layers.size()) - 1, 0, layers.size() - 1)
		choices = entry.layers[layers[at]]
	elif SoundCatalog.info(event).get("layers", false):
		volume_db = linear_to_db(lerpf(0.45, 1.0, intensity))  # one file: softer when it's soft
	if choices.is_empty():
		choices = entry.plain if not entry.plain.is_empty() else (entry.layers.values() + entry.notes.values())[0]
	var key := "%s|%s|%d" % [from.id, event, choices.size()]
	var index := 0
	if choices.size() > 1:
		index = _rng.randi_range(0, choices.size() - 2)
		if index >= int(_last_variation.get(key, -1)):
			index += 1  # never the same twice running
	_last_variation[key] = index
	return {"stream": choices[index], "pitch": pitch, "volume_db": volume_db}


func _free_player(in_world: bool) -> Node:
	var pool: Array = _pool_3d if in_world else _pool_2d
	for player: Node in pool:
		if not player.playing:
			return player
	if pool.size() < (MAX_3D if in_world else MAX_2D):
		var player: Node = AudioStreamPlayer3D.new() if in_world else AudioStreamPlayer.new()
		if in_world:
			(player as AudioStreamPlayer3D).unit_size = 12.0
		add_child(player)
		pool.append(player)
		return player
	# All busy: cut off the one that's played longest.
	var oldest: Node = pool[0]
	for player: Node in pool:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	oldest.stop()
	return oldest


func _fill_loop(handle: int) -> void:
	var loop: Dictionary = _loops[handle]
	var player: Node = loop.player
	var found := _resolve(loop.id, beep_missing)
	var picked := {} if found.is_empty() else _pick(found[0], found[1], 1.0, -1)
	if picked.is_empty():
		player.stop()
		player.stream = null
		return
	loop.base_db = float(found[0].mix.get(found[1], {}).get("volume_db", 0.0))
	if player.stream != picked.stream:
		player.stream = picked.stream
		player.play()
	_tune_loop(loop)


func _tune_loop(loop: Dictionary) -> void:
	var player: Node = loop.player
	player.volume_db = float(loop.get("base_db", 0.0)) + linear_to_db(maxf(loop.volume, 0.0001))
	player.pitch_scale = maxf(loop.pitch, 0.01)


## UI, callouts and music carry on while paused; the world's sounds pause with it.
func _process_mode_for(bus: String) -> ProcessMode:
	return Node.PROCESS_MODE_ALWAYS if bus in ["UI", "Voice", "Music"] else Node.PROCESS_MODE_PAUSABLE


func _check_id(id: String) -> void:
	if not SoundCatalog.has(id) and not _warned.has(id):
		_warned[id] = true
		push_warning("Sfx: \"%s\" isn't in SoundCatalog" % id)


func _make_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus), BUSES[bus])
	var world := AudioServer.get_bus_index("World")
	if AudioServer.get_bus_effect_count(world) == 0:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 4200.0
		low_pass.resonance = 0.5
		AudioServer.add_bus_effect(world, low_pass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.55
		reverb.damping = 0.6
		reverb.wet = 0.12
		reverb.dry = 1.0
		AudioServer.add_bus_effect(world, reverb)


func _apply_volumes() -> void:
	for key: String in VOLUME_BUSES:
		var index := AudioServer.get_bus_index(VOLUME_BUSES[key])
		var level := clampf(float(get(key)) / 100.0, 0.0, 1.0)
		AudioServer.set_bus_mute(index, level <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


func _apply_underwater() -> void:
	var on := _profile == null or _profile.underwater_filter
	var world := AudioServer.get_bus_index("World")
	for i in AudioServer.get_bus_effect_count(world):
		AudioServer.set_bus_effect_enabled(world, i, on)


func _beeps_profile() -> SoundProfile:
	if _beeps == null:
		_beeps = SoundProfile.built_in(BEEPS, "Beeps (placeholders)")
	return _beeps


## Makes event `id`'s placeholder beep if it isn't made yet: a tone whose pitch
## comes from the id (so each event is told apart), short for one-shots, a
## steady tone for loops, a plain A for pitched events (so the scale's heard).
func _ensure_beep(id: String) -> void:
	var beeps := _beeps_profile()
	if beeps.has(id) or not SoundCatalog.has(id):
		return
	var info := SoundCatalog.info(id)
	var rate := 22050
	var semis := [0, 2, 4, 7, 9]
	var h := absi(hash(id))
	var frequency := 440.0 if info.pitched else 220.0 * pow(2.0, (semis[h % 5] + 12 * ((h / 5) % 3)) / 12.0)
	var length := 0.06 if info.category == "ui" else 0.14
	var samples := int(length * rate)
	if info.loop:  # whole cycles, so it loops without a click
		var cycles := roundi(0.5 * frequency)
		samples = roundi(cycles * rate / frequency)
		frequency = cycles * float(rate) / samples
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / rate
		var envelope := 1.0 if info.loop else minf(t / 0.005, 1.0) * exp(-t / (length * 0.35))
		var wave := sin(TAU * frequency * t)
		if info.category != "ui" and not info.loop:
			wave += 0.3 * sin(TAU * frequency * 3.0 * t)
		data.encode_s16(i * 2, int(clampf(wave * envelope * 0.3, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if info.loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples
	beeps.add_stream(id, stream)
	beeps.events[id].files.append("(beep)")
