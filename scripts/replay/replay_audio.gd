class_name ReplayAudio
extends AudioStreamPlayer
## A replay's soundtrack: an audio file whose second 0 is the replay's second 0
## (tools/rl_replay/broadcast_audio.py makes one from a broadcast of the game).
## Follows the replay's clock: plays while it plays, jumps when it jumps
## (seeks, skipped pauses, loops) and speeds up and slows down with it.

const EXTENSIONS := ["ogg", "mp3", "wav"]
## Heard this far (s) from the replay's time, the audio jumps back into step.
const MAX_DRIFT := 0.1

var player: ReplayPlayer
var path := ""
## Off: silent, but stays loaded.
var enabled := true


## The soundtrack next to a replay, named like it (7.replay → 7.ogg), or "".
static func find_beside(replay_path: String) -> String:
	var file := replay_path.get_file()
	var stem := file.trim_suffix(".rlreplay.json") if file.to_lower().ends_with(".rlreplay.json") else file.get_basename()
	for extension: String in EXTENSIONS:
		var candidate := replay_path.get_base_dir().path_join("%s.%s" % [stem, extension])
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func is_audio(file_path: String) -> bool:
	return file_path.get_extension().to_lower() in EXTENSIONS


func _ready() -> void:
	name = "ReplayAudio"


## Loads `file_path` (.ogg, .mp3 or .wav). Returns a problem, or "".
func open(file_path: String) -> String:
	var loaded: AudioStream
	match file_path.get_extension().to_lower():
		"ogg":
			loaded = AudioStreamOggVorbis.load_from_file(file_path)
		"mp3":
			loaded = AudioStreamMP3.load_from_file(file_path)
		"wav":
			loaded = AudioStreamWAV.load_from_file(file_path)
		_:
			return "not an audio file (expected .ogg, .mp3 or .wav): %s" % file_path.get_file()
	if loaded == null:
		return "couldn't read %s" % file_path.get_file()
	stop()
	stream = loaded
	path = file_path
	return ""


func _process(_delta: float) -> void:
	if stream == null or player == null:
		return
	var want := player.time
	if not (player.playing and enabled and want < stream.get_length()):
		if playing:
			stop()
		return
	pitch_scale = player.speed
	if not playing:
		play(want)
		return
	var heard := get_playback_position() + AudioServer.get_time_since_last_mix() * pitch_scale
	if absf(heard - want) > MAX_DRIFT * maxf(player.speed, 1.0):
		play(want)
