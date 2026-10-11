## Replay soundtracks: a soundtrack next to a replay with its name loads with
## it, and follows the replay's clock: plays while it plays, stops when it
## pauses, jumps when it seeks, pitches with its speed, goes quiet past its end
## or when switched off. A dropped audio file replaces it; a bad one is refused.
## Run headless: Godot_console.exe --headless --path . res://tests/replay_audio_probe.tscn
extends Node

const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"
const DIR := "user://replay_audio_probe"
const SOUNDTRACK_LENGTH := 9.0  # the fixture is 12 s

var main: Node
var failures := 0
var stage := "loading"
var wait := 0.0
var _closed_audio: ReplayAudio


func _ready() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	_check_naming(dir)
	# The fixture with a silent soundtrack next to it.
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), dir.path_join("game.rlreplay.json"))
	_silence(SOUNDTRACK_LENGTH).save_to_wav(dir.path_join("game.wav"))
	_silence(2.0).save_to_wav(dir.path_join("other.wav"))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.load_replay(dir.path_join("game.rlreplay.json"))


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _silence(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var bytes := PackedByteArray()
	bytes.resize(int(seconds * wav.mix_rate) * 2)
	wav.data = bytes
	return wav


func _check_naming(dir: String) -> void:
	for file: String in ["7.ogg", "8.mp3", "9.txt"]:
		FileAccess.open(dir.path_join(file), FileAccess.WRITE).store_string("x")
	check(ReplayAudio.find_beside(dir.path_join("7.replay")) == dir.path_join("7.ogg"), "7.replay finds 7.ogg")
	check(ReplayAudio.find_beside(dir.path_join("8.rlreplay.json")) == dir.path_join("8.mp3"), "8.rlreplay.json finds 8.mp3")
	check(ReplayAudio.find_beside(dir.path_join("9.replay")) == "", "9.replay finds nothing (9.txt isn't audio)")
	check(ReplayAudio.is_audio("a/B.OGG") and not ReplayAudio.is_audio("a/b.replay"), "audio files are told from replays")


func _process(delta: float) -> void:
	wait += delta
	var replay: ReplayPlayer = main.replay
	match stage:
		"loading":
			if replay != null:
				check(replay.audio.stream != null and replay.audio.path.get_file() == "game.wav",
						"the soundtrack next to the replay loads with it")
				replay.seek(1.0)
				stage = "playing"
				wait = 0.0
			elif wait > 10.0:
				check(false, "the replay loads within 10 s")
				_finish()
		"playing":
			if wait > 0.5:
				var audio := replay.audio
				check(audio.playing, "the soundtrack plays while the replay plays")
				check(absf(audio.get_playback_position() - replay.time) < 0.25,
						"and in step with it (%.2f s vs %.2f s)" % [audio.get_playback_position(), replay.time])
				replay.seek(6.0)
				replay.speed = 2.0
				stage = "seeked"
				wait = 0.0
		"seeked":
			if wait > 0.2:
				var audio := replay.audio
				check(absf(audio.get_playback_position() - replay.time) < 0.3,
						"a seek takes it along (%.2f s vs %.2f s)" % [audio.get_playback_position(), replay.time])
				check(is_equal_approx(audio.pitch_scale, 2.0), "it speeds up with the replay")
				replay.speed = 1.0
				replay.playing = false
				stage = "paused"
				wait = 0.0
		"paused":
			if wait > 0.1:
				check(not replay.audio.playing, "it stops when the replay pauses")
				replay.playing = true
				replay.audio.enabled = false
				stage = "off"
				wait = 0.0
		"off":
			if wait > 0.1:
				check(not replay.audio.playing, "switched off, it stays quiet")
				replay.audio.enabled = true
				replay.seek(SOUNDTRACK_LENGTH + 1.0)
				stage = "past_end"
				wait = 0.0
		"past_end":
			if wait > 0.1:
				check(replay.playing and not replay.audio.playing, "past the soundtrack's end, the replay plays on in silence")
				replay.seek(1.0)
				var dir := ProjectSettings.globalize_path(DIR)
				FileAccess.open(dir.path_join("broken.ogg"), FileAccess.WRITE).store_string("not vorbis")
				check(replay.load_audio(dir.path_join("broken.ogg")) != "", "a broken file is refused")
				check(replay.load_audio(dir.path_join("notes.txt")) != "", "so is one that isn't audio")
				check(replay.audio.path.get_file() == "game.wav", "and the soundtrack stays")
				main.get_window().files_dropped.emit(PackedStringArray([dir.path_join("other.wav")]))
				check(replay.audio.path.get_file() == "other.wav", "dropping an audio file on the window replaces it")
				check(main.replay == replay, "without leaving the replay")
				_closed_audio = replay.audio
				main.stop_replay()
				stage = "closed"
				wait = 0.0
		"closed":
			if wait > 0.1:
				check(main.replay == null and not is_instance_valid(_closed_audio), "closing the replay takes its soundtrack too")
				_finish()


func _finish() -> void:
	print("replay audio probe: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)
