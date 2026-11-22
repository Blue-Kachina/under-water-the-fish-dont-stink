class_name RaceBest
extends RefCounted
## The personal bests per track and lap count (planning_race.md section 7): the fastest finish and the fastest lap,
## kept in the playground settings file beside the UI settings ([race_best] "<track>/<laps>/total" and ".../lap").

const PATH := "user://playground.cfg"
const SECTION := "race_best"

## Probes switch this off so a headless race doesn't write to the player's settings file.
static var persist := true


## The best total time for `track` over `laps` (INF: none yet).
static func total(track: String, laps: int) -> float:
	return _read("%s/%d/total" % [track, laps])


## The best single lap on `track` (INF: none yet).
static func lap(track: String, laps: int) -> float:
	return _read("%s/%d/lap" % [track, laps])


## Records a finish; returns which bests it beat: {"total": bool, "lap": bool}.
static func record(track: String, laps: int, total_time: float, best_lap: float) -> Dictionary:
	var beat := {"total": false, "lap": false}
	if not persist:
		return beat
	var settings := ConfigFile.new()
	settings.load(PATH)
	var total_key := "%s/%d/total" % [track, laps]
	var lap_key := "%s/%d/lap" % [track, laps]
	if total_time < float(settings.get_value(SECTION, total_key, INF)):
		settings.set_value(SECTION, total_key, total_time)
		beat["total"] = true
	if best_lap < float(settings.get_value(SECTION, lap_key, INF)):
		settings.set_value(SECTION, lap_key, best_lap)
		beat["lap"] = true
	if beat["total"] or beat["lap"]:
		settings.save(PATH)
	return beat


## "m:ss.cc" (or "--" for none).
static func clock(seconds: float) -> String:
	if is_inf(seconds) or seconds < 0.0:
		return "--"
	var whole := int(seconds)
	return "%d:%02d.%02d" % [whole / 60, whole % 60, int((seconds - float(whole)) * 100.0)]


static func _read(key: String) -> float:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return float(settings.get_value(SECTION, key, INF))
