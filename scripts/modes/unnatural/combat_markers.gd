class_name CombatMarkers
extends Control
## What's going on round one player in Unnatural (the Playability pass, P3),
## over their view (a child of their UnnaturalHud):
## - target markers: brackets round the zombie each of their aimed weapons
##   will go for next (FishAttack.aim_target(): the bite, the lash, the thrust,
##   the bubbles), in that weapon's colour, nested when two pick the same one;
## - threat arrows at the view's edge toward what's out of view (or behind):
##   bosses, elites within threat_range, and lungers winding up at this player,
##   nearest first, at most threat_arrows_max;
## - pings on drops (hearts, magnets, hourglasses, bolts) within
##   pickup_sense_range: at the edge when they're out of view.
## The lists are looked over every SCAN s; the marks follow every frame.

const SCAN := 0.1
## Kinds of threat, most dangerous first.
enum Threat { BOSS, LUNGE, ELITE }
const THREAT_COLORS := [Color(1.0, 0.12, 0.08), Color(1.0, 0.3, 0.2), Color(1.0, 0.6, 0.15)]
## How far in from the view's edge the arrows and pings sit (px at 720p).
const EDGE := 46.0

var hud: UnnaturalHud
## The last scan's targets ([[zombie, colour], ...]) and threats ([[Threat,
## zombie slot or Boss], ...]); and how many arrows and pings the last frame drew.
var targets := []
var threats := []
var arrows_drawn := 0
var pings_drawn := 0

var _scan_left := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = BroadcastUI.font(800)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN
		scan()
	queue_redraw()


## Looks the targets and threats over now.
func scan() -> void:
	targets.clear()
	threats.clear()
	var run := hud.run if is_instance_valid(hud) else null
	var fish := hud.fish if is_instance_valid(hud) else null
	if not is_instance_valid(run) or not is_instance_valid(fish) or not run.is_up(fish) or run.is_over:
		return
	var settings := run.settings
	if settings.target_marker:
		for attack in aimed_attacks(run, fish):
			var index := attack.aim_target()
			if index >= 0 and run.horde.is_alive(index):
				targets.append([index, attack.tint()])
	if settings.threat_arrows:
		_scan_threats(run, fish)


## `fish`'s weapons that aim: its own attack, then any second ones.
static func aimed_attacks(run: UnnaturalRun, fish: FishController) -> Array[FishAttack]:
	var all: Array[FishAttack] = []
	var own := run.attack_of(fish)
	if is_instance_valid(own):
		all.append(own)
	var powerups := run.powerups_of(fish)
	for id in run.loadout_of(fish).weapons:
		if id == Weapons.ATTACK:
			continue
		var second := powerups.weapon(id) if powerups else null
		if is_instance_valid(second) and second != own:
			all.append(second)
	return all


func _scan_threats(run: UnnaturalRun, fish: FishController) -> void:
	var settings := run.settings
	var at := fish.global_position
	var found := []  # [gap, Threat, what]
	for boss in run.bosses:
		if is_instance_valid(boss) and not boss.dying:
			found.append([boss.global_position.distance_to(at), Threat.BOSS, boss])
	var horde := run.horde
	var reach := settings.threat_range
	var me := run.players.find(fish)
	for i in horde.telegraphing:
		if horde.is_alive(i) and horde.enemy_target(i) == me:
			var gap := horde.enemy_position(i).distance_to(at)
			if gap <= maxf(reach, settings.lunge_range * 2.0):
				found.append([gap, Threat.LUNGE, i])
	if reach > 0.0:
		var reach_squared := reach * reach
		for i in horde.alive:
			if horde.is_elite(i) and not horde.is_proxy(i):
				var gap_squared := horde.enemy_position(i).distance_squared_to(at)
				if gap_squared <= reach_squared:
					found.append([sqrt(gap_squared), Threat.ELITE, i])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] if a[1] != b[1] else a[0] < b[0])
	for n in mini(found.size(), maxi(settings.threat_arrows_max, 0)):
		threats.append([found[n][1], found[n][2]])


func _draw() -> void:
	arrows_drawn = 0
	pings_drawn = 0
	var run := hud.run if is_instance_valid(hud) else null
	var fish := hud.fish if is_instance_valid(hud) else null
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(run) or not is_instance_valid(fish) or camera == null:
		return
	var k := minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y)
	_draw_targets(run, camera, k)
	if run.settings.threat_arrows:
		_draw_threats(run, fish, camera, k)
	if run.settings.pickup_sense_range > 0.0:
		_draw_pickups(run, fish, camera, k)


## Brackets round each target, turning slowly, nested for a shared one.
func _draw_targets(run: UnnaturalRun, camera: Camera3D, k: float) -> void:
	var horde := run.horde
	var seen := {}
	var spin := Time.get_ticks_msec() / 1000.0 * 0.8
	for entry: Array in targets:
		var index: int = entry[0]
		if not horde.is_alive(index):
			continue
		var at := horde.enemy_position(index)
		if camera.is_position_behind(at):
			continue
		var spot := camera.unproject_position(at)
		var edge := camera.unproject_position(at + camera.global_basis.x * horde.enemy_radius(index) * 1.25)
		var nest: int = seen.get(index, 0)
		seen[index] = nest + 1
		var reach := clampf(spot.distance_to(edge), 15.0 * k, 160.0 * k) * (1.0 + 0.3 * nest)
		var color: Color = entry[1]
		color = Color(color.lightened(0.25), 0.95)
		var arm := reach * 0.32
		for corner in 4:
			# An L at each corner of a turning square, its arms along the square's sides.
			var out := Vector2.from_angle(spin + corner * PI * 0.5 + PI * 0.25)
			var tip := spot + out * reach
			var bracket := PackedVector2Array([tip - out.rotated(PI * 0.25) * arm, tip, tip - out.rotated(-PI * 0.25) * arm])
			draw_polyline(bracket, Color(0, 0, 0, 0.5), 5.0 * k)
			draw_polyline(bracket, color, 2.5 * k)


## An arrow at the view's edge for each threat out of view.
func _draw_threats(run: UnnaturalRun, fish: FishController, camera: Camera3D, k: float) -> void:
	var horde := run.horde
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 90.0)
	for entry: Array in threats:
		var threat: int = entry[0]
		var at: Vector3
		if threat == Threat.BOSS:
			var what: Variant = entry[1]
			if not is_instance_valid(what) or (what as Boss).dying:
				continue  # gone since the scan
			at = (what as Boss).global_position
		else:
			var index: int = entry[1]
			if not horde.is_alive(index):
				continue
			at = horde.enemy_position(index)
		var place := edge_point(camera, size, at, EDGE * k)
		if place[1]:
			continue  # in view: you can see it
		var spot := _off_minimap(place[0], k)
		var direction: Vector2 = place[2]
		var scale := k * (1.5 if threat == Threat.BOSS else (1.15 if threat == Threat.LUNGE else 0.9))
		var color: Color = THREAT_COLORS[threat]
		color.a = pulse if threat != Threat.ELITE else 0.85
		var side := Vector2(-direction.y, direction.x)
		var tip := spot + direction * 16.0 * scale
		var triangle := PackedVector2Array([tip, spot - direction * 6.0 * scale + side * 12.0 * scale, spot - direction * 6.0 * scale - side * 12.0 * scale])
		draw_colored_polygon(triangle, Color(0.05, 0.0, 0.0, 0.6 * color.a))
		draw_colored_polygon(PackedVector2Array([triangle[0], triangle[1].lerp(triangle[0], 0.2), triangle[2].lerp(triangle[0], 0.2)]), color)
		var label := ""
		if threat == Threat.BOSS:
			label = "BOSS  %d M" % roundi(at.distance_to(fish.global_position))
		elif threat == Threat.LUNGE:
			label = "!"
		if label != "":
			var px := roundi((15.0 if threat == Threat.BOSS else 13.0) * k * (1.4 if threat == Threat.LUNGE else 1.0))
			var back := spot - direction * 22.0 * scale
			BroadcastUI.text(self, _label_rect(back, Vector2(140.0, px * 1.2)), label, px, color, HORIZONTAL_ALIGNMENT_CENTER, 800)
		arrows_drawn += 1


## `spot` moved off the minimap (up above it), if it's on it.
func _off_minimap(spot: Vector2, k: float) -> Vector2:
	var rect := hud.minimap_rect().grow(12.0 * k)
	if rect.has_area() and rect.has_point(spot):
		spot.y = rect.position.y - 4.0 * k
	return spot


## A label's rect `box` big, centred on `centre` but kept inside the view.
func _label_rect(centre: Vector2, box: Vector2) -> Rect2:
	var at := (centre - box * 0.5).clamp(Vector2(4.0, 4.0), size - box - Vector2(4.0, 4.0))
	return Rect2(at, box)


## A ping on each drop within pickup_sense_range: a ring and its name, at the
## edge when it's out of view (close ones in view need none: you can see them).
func _draw_pickups(run: UnnaturalRun, fish: FishController, camera: Camera3D, k: float) -> void:
	var range_squared := run.settings.pickup_sense_range * run.settings.pickup_sense_range
	for pickup in run.pickups:
		if not is_instance_valid(pickup):
			continue
		var gap_squared := pickup.global_position.distance_squared_to(fish.global_position)
		if gap_squared > range_squared:
			continue
		var place := edge_point(camera, size, pickup.global_position, EDGE * k)
		var gap := sqrt(gap_squared)
		if place[1] and gap < 12.0:
			continue
		var spot: Vector2 = place[0] if place[1] else _off_minimap(place[0], k)
		var color: Color = Pickup.COLORS[pickup.kind]
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0 + pickup.id)
		draw_circle(spot, 9.0 * k, Color(0.03, 0.05, 0.1, 0.55))
		draw_arc(spot, 9.0 * k, 0.0, TAU, 24, Color(color, pulse), 3.0 * k)
		draw_circle(spot, 3.5 * k, color)
		var px := roundi(12.0 * k)
		BroadcastUI.text(self, _label_rect(spot + Vector2(0.0, 11.0 * k + px * 0.65), Vector2(150.0, px * 1.3)), "%s  %d M" % [Pickup.NAMES[pickup.kind], roundi(gap)],
				px, color, HORIZONTAL_ALIGNMENT_CENTER, 800)
		pings_drawn += 1


## Where world point `at` shows on a view of `view` px through `camera`:
## [spot, inside (in view, not behind), direction from the middle (unit)].
## Out of view (or behind, mirrored), the spot is pinned `margin` px in from
## the edge along that direction.
static func edge_point(camera: Camera3D, view: Vector2, at: Vector3, margin: float) -> Array:
	var behind := camera.is_position_behind(at)
	var spot := camera.unproject_position(at)
	if behind:
		spot = view - spot  # mirrored: it's behind
	var inner := Rect2(Vector2.ZERO, view).grow(-margin)
	var middle := view * 0.5
	var direction := spot - middle
	direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.DOWN
	var inside := not behind and inner.has_point(spot)
	if not inside:
		var reach := minf(absf(inner.size.x * 0.5 / direction.x) if absf(direction.x) > 0.001 else INF,
				absf(inner.size.y * 0.5 / direction.y) if absf(direction.y) > 0.001 else INF)
		spot = middle + direction * reach
	return [spot, inside, direction]
