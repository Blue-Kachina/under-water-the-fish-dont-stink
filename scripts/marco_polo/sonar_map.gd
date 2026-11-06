class_name SonarMap
extends RoundMap
## Marco Polo's map (planning_marco_polo.md §4), bottom right, heading up,
## centred on the fish it's for, the arena's walls and big furniture as faint
## outlines (arena.map_outlines(); the Ocean's edge as a circle).
## - The local seeker's scope: dark green, a sweep line going round, and no
##   players but the seekers (arrows). Blips show where sound was heard (the
##   match's `pinged` for this seeker, already blurred by distance), sized and
##   brightened by loudness and flaring as the sweep passes, then fading over
##   blip_life; "Polo!" answers ringed. The Aquarium's airstones fizz
##   (arena.bubble_sources()). A Fake Fish's pings look the same as a hider's.
## - A hider's map: themself, the other live hiders, the seeker(s), Fake Fish
##   (decoy diamonds), the portholes (filled taken, ringed free), a ring round
##   their own arrow that grows with their noise, and a ring round a seeker who
##   just called "Marco!".
## - A spectator: the map of the hider they watch.

const SEEKER := 1
const COUNTDOWN := 0
const LIVE := 1
## How far in from the top-right corner it sits (px), and its size (of the view's height):
## the top right, clear of the base HUD's boost gauge in the bottom right.
const MARGIN := Vector2(18.0, 64.0)
const SIZE := 0.3
const SCOPE := Color(0.01, 0.1, 0.05, 0.9)
const SCOPE_LINE := Color(0.35, 1.0, 0.55)
const SEEKER_COLOR := Color(0.4, 1.0, 0.7)
const SWEEP_TIME := 2.4  # s a turn

var match_node: Node
## The local seeker's blips: {pos: Vector3, loudness, polo, time}.
var blips: Array[Dictionary] = []
## What it shows now: "scope", "hider" or "" (hidden).
var mode := ""
var _clock := 0.0
var _subject: Node3D
var _marks := Marks.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.map = self
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)


## Hooks the map to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	match_node = mp_match
	if mp_match.has_signal("pinged"):
		mp_match.connect("pinged", _on_pinged)
	if mp_match.has_signal("round_started"):
		mp_match.connect("round_started", func(_index: int, _seeker: Node) -> void: blips.clear())


func _on_pinged(seeker: Node, pos: Vector3, loudness: float, polo: bool) -> void:
	if seeker != _call("local_fish", [], null):
		return  # only this machine's seeker's scope
	blips.append({"pos": pos, "loudness": loudness, "polo": polo, "time": _clock})


func _call(method: String, args: Array, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node) or not match_node.has_method(method):
		return fallback
	return match_node.callv(method, args)


func _setting(setting: String, fallback: Variant) -> Variant:
	var settings: Variant = match_node.get("settings") if is_instance_valid(match_node) else null
	if settings is Resource:
		var value: Variant = (settings as Resource).get(setting)
		if value != null:
			return value
	return fallback


## The local seeker's streak heads from the scan (see MarcoScan.streak_heads), or [].
func streak_heads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_instance_valid(match_node) or not match_node.has_meta("marco_scan"):
		return out
	var scan: Variant = match_node.get_meta("marco_scan")
	var me: Variant = _call("local_fish", [], null)
	if scan is MarcoScan and is_instance_valid(scan) and me is Node:
		return (scan as MarcoScan).streak_heads(me as Node)
	return out


func arena() -> Node:
	var at: Variant = match_node.get("arena") if is_instance_valid(match_node) else null
	return at as Node if at is Node and is_instance_valid(at) else null


func _process(delta: float) -> void:
	_clock += delta
	var life := float(_setting("blip_life", 4.0))
	while not blips.is_empty() and _clock - float(blips[0].time) > life:
		blips.pop_front()
	mode = _mode()
	visible = mode != ""
	if not visible:
		return
	var view := get_viewport().get_visible_rect().size
	var area := place(view)
	var centre := _subject.global_position
	var reach := float(_setting("ocean_radius", 90.0)) * 1.05
	var world := arena()
	if world and world.has_method("map_rect"):
		var rect: Rect2 = world.call("map_rect")
		reach = maxf(rect.size.x, rect.size.y) * 0.6
	var camera_node: Variant = match_node.get("camera")
	var camera := get_viewport().get_camera_3d()
	if camera_node is Camera3D and is_instance_valid(camera_node):
		camera = camera_node
	frame(area.position, area.size.x, centre, reach, RoundMap.heading(camera, _subject), mode == "hider")
	_marks.size = size
	queue_redraw()
	_marks.queue_redraw()


## Where the map sits in a view of `view` (px): MarcoPoloHud starts its feed below it.
static func place(view: Vector2) -> Rect2:
	var side := roundf(SIZE * view.y)
	return Rect2(Vector2(view.x - side - MARGIN.x, MARGIN.y), Vector2(side, side))


## "scope" for the local seeker, "hider" for a hider or a spectator (the
## watched hider's), "" outside a round.
func _mode() -> String:
	if not is_instance_valid(match_node):
		return ""
	var phase := int(match_node.get("phase"))
	if phase != COUNTDOWN and phase != LIVE:
		return ""
	var me: Node = _call("local_fish", [], null)
	if bool(_call("is_spectating", [], false)):
		_subject = _call("spectate_target", [], null) as Node3D
		return "hider" if is_instance_valid(_subject) else ""
	_subject = me as Node3D
	if not is_instance_valid(_subject):
		return ""
	return "scope" if int(_call("role_of", [me], 0)) == SEEKER else "hider"


func _draw() -> void:
	if mode == "scope":
		draw_circle(_middle, _radius, SCOPE, true, -1.0, true)
		for k in 3:
			draw_arc(_middle, _radius * (k + 1) / 3.0, 0.0, TAU, SIDES * 2, Color(SCOPE_LINE, 0.16), 1.0, true)
		draw_line(_middle - Vector2(_radius, 0.0), _middle + Vector2(_radius, 0.0), Color(SCOPE_LINE, 0.1), 1.0)
		draw_line(_middle - Vector2(0.0, _radius), _middle + Vector2(0.0, _radius), Color(SCOPE_LINE, 0.1), 1.0)
		draw_arc(_middle, _radius, 0.0, TAU, SIDES * 2, Color(SCOPE_LINE, 0.55), 2.0, true)
	else:
		draw_plate(Color(UITheme.DEEP, 0.62), true)


## The sweep's angle now (rad, on the canvas).
func sweep_angle() -> float:
	return fposmod(_clock / SWEEP_TIME, 1.0) * TAU - PI * 0.5


## Everything over the plate.
class Marks extends Control:
	var map: SonarMap

	func _draw() -> void:
		if map.mode == "":
			return
		_draw_outlines()
		if map.mode == "scope":
			_draw_sweep()
			_draw_fizz()
			_draw_blips()
			_draw_streaks()
			_draw_seekers(true)
		else:
			_draw_portholes()
			_draw_decoys()
			_draw_hiders()
			_draw_seekers(false)

	func _line_tint() -> Color:
		return Color(SonarMap.SCOPE_LINE, 0.4) if map.mode == "scope" else Color(1, 1, 1, 0.3)

	func _draw_outlines() -> void:
		var tint := _line_tint()
		var world := map.arena()
		if world and world.has_method("map_outlines"):
			for outline: PackedVector2Array in world.call("map_outlines"):
				_draw_polyline_clipped(outline, tint, true)
			return
		# The Ocean: its edge.
		var centre: Vector3 = map.match_node.get("center") if map.match_node.get("center") is Vector3 else Vector3.ZERO
		var radius := float(map._setting("ocean_radius", 90.0))
		var ring := PackedVector2Array()
		for n in 97:
			var angle := TAU * n / 96.0
			ring.append(Vector2(centre.x + cos(angle) * radius, centre.z + sin(angle) * radius))
		_draw_polyline_clipped(ring, tint, false)

	## A world (x, z) outline, the bits inside the map.
	func _draw_polyline_clipped(outline: PackedVector2Array, tint: Color, closed: bool) -> void:
		var count := outline.size()
		if count < 2:
			return
		var last := map.flat_to_map(outline[0])
		var last_in := map.on_map(last, 1.0)
		for i in range(1, count + (1 if closed else 0)):
			var spot := map.flat_to_map(outline[i % count])
			var inside := map.on_map(spot, 1.0)
			if inside and last_in:
				draw_line(last, spot, tint, 1.5, true)
			last = spot
			last_in = inside

	func _draw_sweep() -> void:
		var angle := map.sweep_angle()
		for k in 10:
			var a := angle - k * 0.06
			draw_line(map._middle, map._middle + Vector2.from_angle(a) * map._radius, Color(SonarMap.SCOPE_LINE, 0.4 * (1.0 - k / 10.0)), 2.0, true)

	## The airstones: a steady fizz of small, short-lived blips round each.
	func _draw_fizz() -> void:
		var world := map.arena()
		if world == null or not world.has_method("bubble_sources"):
			return
		var tick := int(map._clock * 12.0)
		var n := 0
		for source: Vector3 in world.call("bubble_sources"):
			n += 1
			for k in 4:
				var h := hash(Vector3i(tick, n, k))
				var jitter := Vector3(float(h % 200) / 100.0 - 1.0, 0.0, float((h / 200) % 200) / 100.0 - 1.0) * 2.5
				var spot := map.to_map(source + jitter)
				if map.on_map(spot, 2.0):
					draw_circle(spot, 1.6, Color(SonarMap.SCOPE_LINE, 0.25 + 0.35 * float(h % 7) / 6.0))

	func _draw_blips() -> void:
		var life := maxf(float(map._setting("blip_life", 4.0)), 0.01)
		var sweep := map.sweep_angle()
		for blip in map.blips:
			var spot := map.to_map(blip.pos as Vector3)
			if not map.on_map(spot, 3.0):
				continue
			var age := map._clock - float(blip.time)
			var fade := clampf(1.0 - age / life, 0.0, 1.0)
			var loud := clampf(float(blip.loudness), 0.0, 1.0)
			# Brighter as the sweep passes over it.
			var off := fposmod(sweep - (spot - map._middle).angle(), TAU)
			var flare := exp(-off * 3.0)
			var r := lerpf(2.5, 7.0, loud) * (1.0 + 0.25 * flare)
			var tint := Color(SonarMap.SCOPE_LINE.lerp(Color.WHITE, 0.3 * flare), fade * lerpf(0.55, 1.0, loud))
			draw_circle(spot, r * 1.8, Color(tint, tint.a * 0.2))
			draw_circle(spot, r, tint)
			if blip.polo:
				draw_arc(spot, r + 4.0, 0.0, TAU, 20, Color(tint, tint.a * 0.8), 1.5, true)
			if age < 0.4:
				draw_arc(spot, r + age * 40.0, 0.0, TAU, 20, Color(tint, 0.6 * (1.0 - age / 0.4)), 1.5, true)

	## The local seeker's streak heads (MarcoScan.streak_heads): a blue diamond with
	## a tick the way the hider went, fading over ghost_scope_blip s, so the map
	## and the world agree.
	func _draw_streaks() -> void:
		var life := float(map._setting("ghost_scope_blip", 3.0))
		var strength := float(map._setting("ghost_scope_strength", 1.0))
		if life <= 0.0 or strength <= 0.0:
			return
		for head: Dictionary in map.streak_heads():
			var age := float(head.age)
			if age > life:
				continue
			var spot := map.to_map(head.pos as Vector3)
			if not map.on_map(spot, 3.0):
				continue
			var fade := clampf(1.0 - age / life, 0.0, 1.0) * strength
			var tint := Color(0.45, 0.72, 1.0, clampf(fade, 0.0, 1.0))
			var r := lerpf(3.0, 6.0, float(head.strength))
			draw_circle(spot, r * 1.8, Color(tint, tint.a * 0.2))
			var diamond := PackedVector2Array([spot + Vector2(0, -r), spot + Vector2(r, 0), spot + Vector2(0, r), spot + Vector2(-r, 0)])
			draw_colored_polygon(diamond, tint)
			var heading: Vector3 = head.heading
			if heading.length() > 0.1:
				var ahead := map.to_map((head.pos as Vector3) + heading * 3.0) - spot
				if ahead.length() > 0.1:
					draw_line(spot, spot + ahead.normalized() * (r + 6.0), Color(0.9, 0.97, 1.0, tint.a), 1.5, true)

	## The seekers: arrows (on the scope, the others in Join the Seekers and you
	## in the middle); on a hider's map, a ring round one who just called Marco.
	func _draw_seekers(scope: bool) -> void:
		var seekers: Array = map._call("seekers", [], [])
		var me := map._subject
		for fish: Variant in seekers:
			if not is_instance_valid(fish) or not fish is Node3D:
				continue
			var body := fish as Node3D
			var spot := map.to_map(body.global_position)
			if not map.on_map(spot, 6.0):
				spot = map.to_rim(spot, 6.0)
			var mine: bool = fish == me
			RoundMap.draw_arrow(self, spot, _ahead(body), SonarMap.SEEKER_COLOR, Color.WHITE if mine else Color(BroadcastUI.INK, 0.9), 9.0 if mine else 8.0)
			if not scope:
				var ring := float(map._call("marco_ring_left", [fish], 0.0))
				if ring > 0.0:
					var t := fposmod(map._clock * 1.5, 1.0)
					draw_arc(spot, 8.0 + t * 26.0, 0.0, TAU, 32, Color(SonarMap.SEEKER_COLOR, 0.8 * (1.0 - t)), 2.0, true)

	func _draw_hiders() -> void:
		var me := map._subject
		var hiders: Array = map._call("live_hiders", [], [])
		for fish: Variant in hiders:
			if is_instance_valid(fish) and fish != me and fish is Node3D:
				_draw_fish(fish as Node3D, false)
		if is_instance_valid(me):
			var noise := clampf(float(map._call("noise", [me], 0.0)), 0.0, 1.0)
			var spot := map.to_map(me.global_position)
			if noise > 0.02:
				var tint := Color(0.4, 0.9, 0.6).lerp(UITheme.CORAL, noise)
				draw_arc(spot, 9.0 + noise * 24.0, 0.0, TAU, 32, Color(tint, 0.35 + 0.45 * noise), 2.0, true)
			_draw_fish(me, true)

	func _draw_fish(fish: Node3D, mine: bool) -> void:
		var spot := map.to_map(fish.global_position)
		if not map.on_map(spot, 6.0):
			spot = map.to_rim(spot, 6.0)
		var color := Color(1, 1, 1)
		if fish.has_method("body_color"):
			color = fish.call("body_color")
			color.a = 1.0
		RoundMap.draw_arrow(self, spot, _ahead(fish), color, Color.WHITE if mine else Color(BroadcastUI.INK, 0.9), 9.0 if mine else 7.0)

	func _draw_decoys() -> void:
		for fake: Variant in map._call("decoys", [], []):
			if not is_instance_valid(fake) or not fake is Node3D:
				continue
			var spot := map.to_map((fake as Node3D).global_position)
			if map.on_map(spot, 5.0):
				HudIcons.draw_mate(self, spot, 11.0, Color(UITheme.GOLD, 0.85))

	func _draw_portholes() -> void:
		var world := map.arena()
		if world == null or not world.has_method("portholes"):
			return
		for hole: Variant in world.call("portholes"):
			if not is_instance_valid(hole) or not hole is Node3D:
				continue
			var spot := map.to_map((hole as Node3D).global_position)
			if not map.on_map(spot, 4.0):
				continue
			var free := bool(hole.call("is_free")) if hole.has_method("is_free") else true
			draw_circle(spot, 5.0, Color(BroadcastUI.INK, 0.8))
			if free:
				draw_arc(spot, 4.0, 0.0, TAU, 16, Color(0.6, 0.85, 1.0), 1.5, true)
			else:
				draw_circle(spot, 4.0, Color(0.6, 0.85, 1.0))

	func _ahead(body: Node3D) -> Vector2:
		var facing := Vector2(-body.global_basis.z.x, -body.global_basis.z.z)
		return map.turn(facing.normalized()) if facing.length_squared() > 0.0001 else Vector2.UP
