extends Node
## Probe for the module boundary rule (planning_core_roadmap.md 3.2): modes
## import core and kits; core and kits never import a mode. A text scan, no
## scene needed: it reads scripts/**/*.gd with comments stripped, finds every
## use of a mode's class name (outside string literals) or a res://scripts
## path inside a mode, in a core or kit file, and prints a per-file table.
##
## HOW TO RUN (reporting only; exits 0 unless --strict finds something new):
##   Godot_console.exe --headless --path . res://tests/mode_boundary_probe.tscn
##   ... -- --record    rewrite tests/fixtures/mode_boundary_baseline.json
##                      with today's violations (do this when fixing some:
##                      the baseline should only ever shrink)
##   ... -- --strict    exit 1 on any violation not in the baseline (a new
##                      file, a new mode symbol in a file, or a higher count)
##   ... -- --verbose   also list each violation's line numbers
##
## The lists below are TODAY's locations; when the folder move (3.2) happens,
## point CORE / KITS at scripts/core and scripts/kits and the MODE_ tables at
## scripts/modes/<id>. A file in none of the lists is unclassified and not
## scanned (the probe prints how many, so the lists can be kept complete).

const SCRIPTS := "res://scripts"
## The registry is the one core file that names modes: one line each.
const REGISTRY := "core/mode_registry.gd"
const BASELINE := "res://tests/fixtures/mode_boundary_baseline.json"

## Core: relative to scripts/; an entry ending in "/" is a whole folder.
const CORE := [
	"main.gd", "hud.gd", "follow_camera.gd", "local_coop.gd", "fish_controller.gd",
	"fish_character.gd", "fish_model.gd", "fish_input.gd", "player_input.gd", "player_slot.gd",
	"split_screen.gd", "controls.gd", "swishy_swim.gd", "gait.gd", "gait_settings.gd",
	"stride_stream.gd", "pause_menu.gd", "debug_panel.gd", "role_characters.gd", "ui_settings.gd",
	"broadcast_ui.gd", "match_card.gd", "ocean.gd",
	"ui/", "fish_models/", "core/",
	"audio/sfx.gd", "audio/sound_catalog.gd", "audio/sound_profile.gd", "audio/sfx_hooks/sfx_hooks.gd",
	"net/net_session.gd", "net/coop_session.gd", "net/net_fish.gd",
]
## Kits (shared building blocks), where they live today (Seabed, Traversal, ChompKit and
## the survivor cam moved to kits/ in the Unnatural migration, step A).
const KITS := [
	"terrain/",
	"battery.gd", "style_points.gd", "match_stats.gd",
	"goal_recorder.gd", "goal_replay.gd", "replay/", "fish_bot.gd", "kits/",
	"fx_kit.gd", "scenery/", "water_look.gd", "fx/", "xray_outline.gd",
	"rl/",
]
## Mode folders (every .gd below is that mode's) and single mode files.
const MODE_DIRS := {
	"unnatural/": "unnatural", "modes/hunt/": "hunt", "modes/nature/": "nature", "marco_polo/": "marco", "what_stinks/": "what_stinks",
}
const MODE_FILES := {
	"net/unnatural_net.gd": "unnatural", "net/marco_polo_net.gd": "marco",
	"net/what_stinks_net.gd": "what_stinks",
	"match_1v1.gd": "1v1", "course_skill.gd": "course",
	"audio/sfx_hooks/unnatural_sounds.gd": "unnatural",
	"audio/sfx_hooks/boss_sounds.gd": "unnatural", "audio/sfx_hooks/battered_sounds.gd": "unnatural",
}

var failures := 0
var strict := false
var record := false
var verbose := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--strict":
				strict = true
			"--record":
				record = true
			"--verbose":
				verbose = true
	_run.call_deferred()


func _run() -> void:
	var files: Array[String] = []
	_collect(SCRIPTS, files)
	files.sort()
	var kind := {}  # rel path -> "core" | "kit" | "mode:<id>" | ""
	var classes := {}  # mode class name -> mode id
	var path_mode := {}  # res:// path -> mode id
	var unclassified := 0
	for rel in files:
		var k := _classify(rel)
		kind[rel] = k
		if k == "":
			unclassified += 1
		elif k.begins_with("mode:"):
			var mode := k.substr(5)
			path_mode[SCRIPTS + "/" + rel] = mode
			for line in FileAccess.get_file_as_string(SCRIPTS + "/" + rel).split("\n"):
				if line.begins_with("class_name "):
					classes[line.get_slice(" ", 1).strip_edges()] = mode
	var found := {}  # rel -> {symbol: count}
	var lines := {}  # rel -> {symbol: [line numbers]}
	var rx_cache := {}
	for rel in files:
		var k: String = kind[rel]
		if (k != "core" and k != "kit") or rel == REGISTRY:
			continue
		var src_lines := FileAccess.get_file_as_string(SCRIPTS + "/" + rel).split("\n")
		for i in src_lines.size():
			var line := _drop_comment(src_lines[i])
			var from := 0
			while true:
				var at := line.find("res://scripts/", from)
				if at < 0:
					break
				var end := line.find("\"", at)
				if end < 0:
					end = line.length()
				var p := line.substr(at, end - at)
				from = end
				if path_mode.has(p):
					_hit(found, lines, rel, "path:" + p.trim_prefix("res://scripts/"), i + 1)
			var code := _strip_strings(line)
			for cname: String in classes:
				if code.find(cname) < 0:
					continue
				if not rx_cache.has(cname):
					var rx := RegEx.new()
					rx.compile("(?<![A-Za-z0-9_])" + cname + "(?![A-Za-z0-9_])")
					rx_cache[cname] = rx
				var m := (rx_cache[cname] as RegEx).search_all(code)
				for _j in m.size():
					_hit(found, lines, rel, cname, i + 1)
	var rows: Array = []
	var total := 0
	var by_mode := {}  # mode -> {"hits": n, "files": {rel: true}}
	for rel: String in found:
		var n := 0
		var modes := {}
		for sym: String in found[rel]:
			var c: int = found[rel][sym]
			n += c
			var mode := _mode_of(sym, classes, path_mode)
			modes[mode] = int(modes.get(mode, 0)) + c
			var bm: Dictionary = by_mode.get(mode, {"hits": 0, "files": {}})
			bm["hits"] = int(bm["hits"]) + c
			bm["files"][rel] = true
			by_mode[mode] = bm
		total += n
		rows.append([n, rel, kind[rel], modes])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("mode_boundary_probe: %d scripts, %d unclassified (not scanned), %d mode classes" % [files.size(), unclassified, classes.size()])
	print("  %5s  %-5s  %-44s  %s" % ["count", "kind", "file (core/kit naming a mode)", "per mode"])
	for r: Array in rows:
		var parts: Array[String] = []
		for mode: String in r[3]:
			parts.append("%s=%d" % [mode, r[3][mode]])
		print("  %5d  %-5s  %-44s  %s" % [r[0], r[2], r[1], ", ".join(parts)])
		if verbose:
			for sym: String in lines[r[1]]:
				print("           %s: lines %s" % [sym, str(lines[r[1]][sym])])
	print("  per mode (hits in core/kit files that name it):")
	var mode_names: Array = by_mode.keys()
	mode_names.sort()
	for mode: String in mode_names:
		print("    %-12s %4d hits in %2d files" % [mode, by_mode[mode]["hits"], by_mode[mode]["files"].size()])
	print("  total: %d violations in %d files" % [total, rows.size()])
	if record:
		var f := FileAccess.open(BASELINE, FileAccess.WRITE)
		if f == null:
			check(false, "cannot write " + BASELINE)
		else:
			f.store_string(JSON.stringify({"note": "Today's violations. tests/mode_boundary_probe.gd --record rewrites it; it should only ever shrink.", "total": total, "violations": found}, "\t", true))
			f.close()
			print("  baseline recorded: %s" % BASELINE)
	elif strict:
		var base := _load_baseline()
		for rel: String in found:
			for sym: String in found[rel]:
				var allowed := int((base.get(rel, {}) as Dictionary).get(sym, 0))
				if int(found[rel][sym]) > allowed:
					check(false, "NEW %s uses %s x%d (baseline %d)" % [rel, sym, found[rel][sym], allowed])
		print("mode_boundary_probe (strict): %s" % ("no new violations" if failures == 0 else "%d NEW" % failures))
	else:
		print("mode_boundary_probe: report only (pass -- --strict to enforce the baseline)")
	get_tree().quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _load_baseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("violations", {})
	return {}


func _hit(found: Dictionary, lines: Dictionary, rel: String, sym: String, line_no: int) -> void:
	var d: Dictionary = found.get(rel, {})
	d[sym] = int(d.get(sym, 0)) + 1
	found[rel] = d
	var l: Dictionary = lines.get(rel, {})
	var arr: Array = l.get(sym, [])
	arr.append(line_no)
	l[sym] = arr
	lines[rel] = l


func _mode_of(sym: String, classes: Dictionary, path_mode: Dictionary) -> String:
	if sym.begins_with("path:"):
		return path_mode.get("res://scripts/" + sym.trim_prefix("path:"), "?")
	return classes.get(sym, "?")


func _classify(rel: String) -> String:
	if MODE_FILES.has(rel):
		return "mode:" + MODE_FILES[rel]
	if _listed(rel, KITS):
		return "kit"
	if _listed(rel, CORE):
		return "core"
	for d: String in MODE_DIRS:
		if rel.begins_with(d):
			return "mode:" + MODE_DIRS[d]
	return ""


func _listed(rel: String, list: Array) -> bool:
	for p: String in list:
		if rel == p or (p.ends_with("/") and rel.begins_with(p)):
			return true
	return false


func _collect(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append((dir + "/" + f).trim_prefix(SCRIPTS + "/"))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)


## The line without its # comment (a # inside a string stays).
func _drop_comment(line: String) -> String:
	var quote := ""
	var esc := false
	for i in line.length():
		var c := line[i]
		if quote != "":
			if esc:
				esc = false
			elif c == "\\":
				esc = true
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
	return line


## The line with string contents removed, so class names in text don't count.
func _strip_strings(line: String) -> String:
	var out := ""
	var quote := ""
	var esc := false
	for i in line.length():
		var c := line[i]
		if quote != "":
			if esc:
				esc = false
			elif c == "\\":
				esc = true
			elif c == quote:
				quote = ""
				out += c
		else:
			if c == "\"" or c == "'":
				quote = c
			out += c
	return out
