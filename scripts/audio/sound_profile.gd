class_name SoundProfile
extends RefCounted
## One sound profile: a folder of sound files named after SoundCatalog's event
## ids (planning_audio.md §1). Inside it, ball/hit.wav is event "ball/hit", and
##   ball/hit-1.wav, ball/hit-2.wav     variations (picked at random)
##   ball/hit@1.wav .. ball/hit@3.wav   intensity layers, soft to hard
##   ball/hit@2-3.wav                   layer 2, variation 3
##   nature/pearl_n00 .. _n11           a pitched event's notes (semitones up)
## and profile.cfg (optional) holds its name, scale and mix trims.
##
## Files load straight from disk while the game runs from the project folder,
## so saving a file and reloading the profile is heard at once; an exported
## game loads the imported copies instead.

const EXTENSIONS := ["wav", "ogg", "mp3"]
const CONFIG := "profile.cfg"
## Scale name -> its semitones above the root, climbed by pitched events.
const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"major_pentatonic": [0, 2, 4, 7, 9],
	"minor_pentatonic": [0, 3, 5, 7, 10],
	"blues": [0, 3, 5, 6, 7, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	"whole_tone": [0, 2, 4, 6, 8, 10],
}

## The folder name: what Settings saves.
var id := ""
var dir := ""
var title := ""
var author := ""
var description := ""
## The note plain files of pitched events are recorded at (for the sheet).
var root_note := "C"
var scale := "major_pentatonic"
## The World bus's underwater low-pass and reverb (off: play as recorded).
var underwater_filter := true
## Event id -> {volume_db, pitch_jitter, voices} trims ([mix] in profile.cfg).
var mix := {}
## Event id -> {"plain": [AudioStream], "layers": {n: [AudioStream]},
## "notes": {semitone: [AudioStream]}, "files": [path]}.
var events := {}
## Files that don't name a catalog event (typos, or events not hooked up yet).
var unknown_files: PackedStringArray = []

static var _name_pattern: RegEx


## Reads the profile in folder `folder` (its streams too). Null if it's not a folder.
static func open(folder: String) -> SoundProfile:
	if not DirAccess.dir_exists_absolute(folder):
		return null
	var profile := SoundProfile.new()
	profile.dir = folder
	profile.id = folder.trim_suffix("/").get_file()
	profile.title = profile.id.capitalize()
	profile._read_config()
	for path in _files_under(folder, ""):
		profile._add_file(path)
	return profile


## A profile made in code (Settings' built-in ones, probes).
static func built_in(profile_id: String, profile_title: String) -> SoundProfile:
	var profile := SoundProfile.new()
	profile.id = profile_id
	profile.title = profile_title
	return profile


## Splits a file's path inside the profile ("ball/hit@2-3.wav") into
## {id, layer, variation, note}; layer / note -1 when it has none. {} if it's not a sound.
static func parse_name(relative: String) -> Dictionary:
	if relative.get_extension().to_lower() not in EXTENSIONS:
		return {}
	if _name_pattern == null:
		_name_pattern = RegEx.create_from_string("^(?<id>.+?)(?:_n(?<note>\\d\\d))?(?:@(?<layer>\\d+))?(?:-(?<variation>\\d+))?$")
	var found := _name_pattern.search(relative.get_basename())
	if found == null:
		return {}
	return {
		"id": found.get_string("id"),
		"note": found.get_string("note").to_int() if found.get_string("note") else -1,
		"layer": found.get_string("layer").to_int() if found.get_string("layer") else -1,
		"variation": found.get_string("variation").to_int() if found.get_string("variation") else 0,
	}


func has(event: String) -> bool:
	return events.has(event)


func file_count(event: String) -> int:
	return events[event].files.size() if events.has(event) else 0


## Adds `stream` as event `event`'s (probes and built-in profiles).
func add_stream(event: String, stream: AudioStream, layer := -1, note := -1) -> void:
	var entry := _entry(event)
	if note >= 0:
		entry.notes.get_or_add(note, []).append(stream)
	elif layer >= 0:
		entry.layers.get_or_add(layer, []).append(stream)
	else:
		entry.plain.append(stream)


## The semitone above the root that step `step` of the scale is (0 is the root,
## and steps past the top go up an octave).
func semitone(step: int) -> int:
	var degrees: Array = SCALES.get(scale, SCALES.major_pentatonic)
	var count := degrees.size()
	return int(degrees[posmod(step, count)]) + 12 * floori(float(step) / count)


func _entry(event: String) -> Dictionary:
	if not events.has(event):
		events[event] = {"plain": [], "layers": {}, "notes": {}, "files": []}
	return events[event]


func _read_config() -> void:
	var config := ConfigFile.new()
	if config.load(dir.path_join(CONFIG)) != OK:
		return
	title = str(config.get_value("profile", "name", title))
	author = str(config.get_value("profile", "author", ""))
	description = str(config.get_value("profile", "description", ""))
	root_note = str(config.get_value("profile", "root_note", root_note))
	scale = str(config.get_value("profile", "scale", scale))
	if not SCALES.has(scale):
		push_warning("Sound profile %s: unknown scale \"%s\" (using major_pentatonic)" % [id, scale])
		scale = "major_pentatonic"
	underwater_filter = bool(config.get_value("profile", "underwater_filter", true))
	if config.has_section("mix"):
		for event in config.get_section_keys("mix"):
			var trims: Variant = config.get_value("mix", event)
			if trims is Dictionary:
				mix[event] = trims


func _add_file(relative: String) -> void:
	var parsed := parse_name(relative)
	if parsed.is_empty():
		return
	if not SoundCatalog.has(parsed.id):
		unknown_files.append(relative)
		return
	var path := dir.path_join(relative)
	var stream := load_stream(path)
	if stream == null:
		push_warning("Sound profile %s: couldn't read %s" % [id, relative])
		return
	if SoundCatalog.info(parsed.id).loop:
		_set_loop(stream)
	add_stream(parsed.id, stream, parsed.layer, parsed.note)
	_entry(parsed.id).files.append(relative)


## A sound file as a stream: from disk when it's there (running from the
## project), else its imported copy (an exported game).
static func load_stream(path: String) -> AudioStream:
	if FileAccess.file_exists(path):
		match path.get_extension().to_lower():
			"wav":
				return AudioStreamWAV.load_from_file(path)
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				return AudioStreamMP3.load_from_file(path)
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


## Sound files under `root`/`sub`, as paths relative to `root`. Lists the files
## on disk and, in an exported game, the imported ones.
static func _files_under(root: String, sub: String) -> PackedStringArray:
	var found := PackedStringArray()
	var here := root.path_join(sub) if sub else root
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(here):
		names.append(file.trim_suffix(".import").trim_suffix(".remap"))
	if here.begins_with("res://"):
		for file in ResourceLoader.list_directory(here):
			if not file.ends_with("/"):
				names.append(file)
	for file in names:
		var relative := sub.path_join(file) if sub else file
		if file.get_extension().to_lower() in EXTENSIONS and relative not in found:
			found.append(relative)
	for folder in DirAccess.get_directories_at(here):
		found.append_array(_files_under(root, sub.path_join(folder) if sub else folder))
	found.sort()
	return found
