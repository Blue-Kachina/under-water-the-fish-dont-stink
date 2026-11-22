extends Node
## Race contract check (race_phase0.md): the Grey Box track builds and closes, nearest() is monotonic along it, the
## grid and checkpoints are sane, every roster entry has a handling row and a unique key.
##   Godot_console.exe --headless --path . res://tests/race_contract_probe.tscn

var _bad := 0


func _ready() -> void:
	var track := RaceTrack.build(GreyboxTrack.data())
	_check(track != null, "track builds")
	print("lap %.1f m, %d samples, %d checkpoints" % [track.lap_length, track.count(), track.checkpoints.size()])
	_check(absf(track.lap_length - 723.0) < 25.0, "lap near 723 m")
	var a := track.sample(0.0)
	var b := track.sample(track.lap_length - 0.01)
	_check(a.pos.distance_to(b.pos) < 0.5, "the loop closes (%.3f m)" % a.pos.distance_to(b.pos))
	var hint := 0.0
	var ok := true
	for i in 400:
		var d := float(i) * 1.8
		var fix := track.nearest(track.racing_line(d) + Vector3(0, 0.5, 0), hint)
		if absf(track.delta(d, fix.d)) > 3.0:
			ok = false
		hint = fix.d
	_check(ok, "nearest() follows the racing line")
	_check(track.checkpoints[0]["d"] == 0.0, "checkpoint 0 is the line")
	var slots := track.grid_slots(8)
	_check(slots.size() == 8, "8 grid slots")
	_check(track.streams_at(track.lap_length * 0.1).size() == 1, "stream at 10%")
	var entries := RaceRoster.entries()
	var keys := {}
	var fam := {}
	for e in entries:
		keys[e["key"]] = true
		fam[e["family"]] = int(fam.get(e["family"], 0)) + 1
		var row := RaceHandling.of(e)
		_check(row["weight"] > 0.0 and row["turn_scale"] > 0.0, "handling for " + e["key"])
	_check(keys.size() == entries.size(), "unique keys")
	print("roster %d entries: %s" % [entries.size(), fam])
	var s := RaceSettings.shared()
	print("stroke cap %.2f; shared %s" % [s.stroke_cap(), s.shared_modifiers(40.0)])
	print("race_contract_probe: %s" % ("ok" if _bad == 0 else "%d failed" % _bad))
	get_tree().quit(1 if _bad else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_bad += 1
		print("FAIL ", what)
