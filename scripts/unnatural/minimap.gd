class_name Minimap
extends Control
## Unnatural's minimap (planning_murk.md §7): a flat, round, top-down map in
## the bottom-right of each player's view (one per UnnaturalHud, so split-screen
## gets one each). Your heading is up (minimap_heading_up; off: north is up),
## minimap_range m from the middle to the rim (0: the whole arena).
## - players: an arrow each, in their fish's colour, the way they face (you
##   outlined in white; a cross while down);
## - bosses: the final boss a devil's head, a mini-boss a skull, pinned to the
##   rim when out of range (icons: HudIcons);
## - shrines the team has found: a temple in its colour (grey outline once used);
## - the boss rift (BossRift): a big red skull, always shown (pinned to the rim);
## - elites: a red dot;
## - the zombie swarms: soft red clouds, from the Horde's survey (a coarse
##   count per arena cell, redone minimap_rate times a second and shared by
##   every map), blurred by a shader;
## - your shut chests in range: a box in their colour (gold, cursed red, boss blue);
## - the arena's edge, where it's in range.

const CLOUD_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.12, 1.0);
uniform float strength = 0.6;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).r * 0.4;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).r * 0.15;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).r * 0.15;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).r * 0.15;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).r * 0.15;
	COLOR = vec4(tint.rgb, clamp(a * 1.5, 0.0, 1.0) * strength);
}
"""
## The swarms' grid cell (m).
const CLOUD_CELL := 4.0
## How far in from the bottom-right corner it sits (px).
const MARGIN := Vector2(18.0, 48.0)
const ELITE_COLOR := Color(1.0, 0.2, 0.15)
const BONE := Color(0.92, 0.88, 0.8)
## The boss rift's skull.
const RIFT_COLOR := Color(1.0, 0.16, 0.1)
const SIDES := 48
## The compass ring's width (px) round the map, and its letters.
const BEZEL := 15.0
const CARDINALS := ["N", "E", "S", "W"]
## The thin pale rim round the HUD's panels (the HUD redesign).
const PANEL_RIM := Color(150 / 255.0, 215 / 255.0, 1.0, 0.22)

## The swarms' texture, shared by every map, and the survey it shows.
static var _cloud_texture: ImageTexture
static var _cloud_version := -1
static var _cloud_cells := 0
static var _cloud_bytes := PackedByteArray()

var hud: UnnaturalHud
var _clouds := Clouds.new()
var _marks := Marks.new()
var _cloud_material := ShaderMaterial.new()
## This frame's map: the middle (world and px), its axes (flat world, unit),
## px per metre and the radius (px).
var _centre := Vector3.ZERO
var _right := Vector2.RIGHT
var _forward := Vector2.UP
var _scale := 1.0
var _radius := 1.0
var _middle := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	_cloud_material.shader = shader
	_clouds.map = self
	_clouds.material = _cloud_material
	_clouds.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clouds)
	_marks.map = self
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)


func _process(_delta: float) -> void:
	var run := hud.run if hud else null
	visible = is_instance_valid(run) and run.settings.minimap and is_instance_valid(hud.fish)
	if not visible:
		return
	var settings := run.settings
	var view := get_viewport().get_visible_rect().size
	var side := roundf(clampf(settings.minimap_size, 0.05, 0.6) * view.y)
	size = Vector2(side, side)
	position = view - size - MARGIN
	_clouds.size = size
	_marks.size = size
	modulate.a = settings.minimap_opacity
	_middle = size * 0.5
	_radius = side * 0.5 - (BEZEL if settings.compass_ring else 3.0)
	# The middle and how far it reaches.
	var reach := settings.minimap_range
	_centre = hud.fish.global_position
	if reach <= 0.0:
		_centre = run.centre
		reach = settings.arena_radius * 1.05
	_scale = _radius / maxf(reach, 1.0)
	# Which way is up: where the camera looks (or the fish faces), or north.
	_forward = Vector2(0.0, -1.0)
	if settings.minimap_heading_up:
		var camera := hud.player_camera if is_instance_valid(hud.player_camera) else get_viewport().get_camera_3d()
		var basis := camera.global_basis if camera else hud.fish.global_basis
		var ahead := Vector2(-basis.z.x, -basis.z.z)
		if ahead.length_squared() > 0.0001:
			_forward = ahead.normalized()
	_right = Vector2(-_forward.y, _forward.x)
	if is_instance_valid(run.horde):
		run.horde.survey(CLOUD_CELL, 1.0 / maxf(settings.minimap_rate, 1.0))
		_refresh_clouds(run.horde)
	queue_redraw()
	_clouds.queue_redraw()
	_marks.queue_redraw()


## `at` on the map (px, from its top-left corner).
func to_map(at: Vector3) -> Vector2:
	var d := Vector2(at.x - _centre.x, at.z - _centre.z)
	return _middle + Vector2(d.dot(_right), -d.dot(_forward)) * _scale


## A direction on the flat world (x, z) as one on the map.
func turn(direction: Vector2) -> Vector2:
	return Vector2(direction.dot(_right), -direction.dot(_forward))


## The world point (x, z) under `spot` on the map.
func from_map(spot: Vector2) -> Vector2:
	var s := (spot - _middle) / _scale
	return Vector2(_centre.x, _centre.z) + _right * s.x - _forward * s.y


## Whether `spot` is on the map (within `inset` px of the rim).
func on_map(spot: Vector2, inset := 0.0) -> bool:
	return spot.distance_to(_middle) <= _radius - inset


## `spot` pulled in to the rim (less `inset` px), if it's off the map.
func to_rim(spot: Vector2, inset: float) -> Vector2:
	var off := spot - _middle
	var most := _radius - inset
	return _middle + off.limit_length(most)


func _draw() -> void:
	draw_circle(_middle, _radius, Color(UITheme.DEEP, 0.62), true, -1.0, true)
	if hud and is_instance_valid(hud.run) and hud.run.settings.compass_ring:
		_draw_bezel()
	else:
		draw_arc(_middle, _radius, 0.0, TAU, SIDES * 2, PANEL_RIM, 1.5, true)


## The compass ring (planning_environment.md, E5): a band round the map with a
## tick every 15 degrees (longer every 45) and N, E, S, W where they lie,
## turning with the map. North is the arena's -Z.
func _draw_bezel() -> void:
	var outer := size.x * 0.5 - 1.0
	var band := outer - _radius
	if band < 2.0:
		return  # not laid out yet
	draw_circle(_middle, _radius + band * 0.5, Color(UITheme.DEEP, 0.78), false, band, true)
	draw_arc(_middle, outer, 0.0, TAU, SIDES * 2, PANEL_RIM, 1.5, true)
	for n in 24:
		var bearing := TAU * n / 24.0
		var way := turn(Vector2(sin(bearing), -cos(bearing)))
		var major := n % 6 == 0
		if major:
			var letter: String = CARDINALS[n / 6]
			var spot := _middle + way * (_radius + band * 0.5)
			var tint := UITheme.CORAL if n == 0 else Color(1, 1, 1, 0.9)
			UITheme.draw_text(self, Rect2(spot - Vector2(10.0, 8.0), Vector2(20.0, 16.0)), letter, UITheme.condensed(700),
					maxi(roundi(band * 0.85), 8), tint)
			continue
		var long := n % 3 == 0
		var inner := _radius + band * (0.3 if long else 0.55)
		draw_line(_middle + way * inner, _middle + way * (outer - band * 0.15), Color(1, 1, 1, 0.55 if long else 0.35), 1.5 if long else 1.0, true)


## Icon painters, shared with the compass strip (CompassStrip).
## A shrine (P5): a temple in its colour (HudIcons), pulsing while its Tide
## runs; its grey outline once `used`.
static func draw_shrine(canvas: CanvasItem, spot: Vector2, tint: Color, running: bool, scale := 1.0, used := false) -> void:
	HudIcons.draw_shrine(canvas, spot, 16.0 * scale, tint, used, running)


static func draw_chest(canvas: CanvasItem, spot: Vector2, tint: Color, scale := 1.0) -> void:
	HudIcons.draw_chest(canvas, spot, 15.0 * scale, tint)


## A boss: the final boss's devil head, or a mini-boss's bone skull.
static func draw_boss(canvas: CanvasItem, spot: Vector2, boss: Boss, scale := 1.0) -> void:
	if boss is BloodLeviathan:
		HudIcons.draw_boss(canvas, spot, 24.0 * scale)
	else:
		draw_skull(canvas, spot, 6.5 * scale)


## The way out: a pale spiral on a dark disc.
static func draw_whirlpool(canvas: CanvasItem, spot: Vector2, radius: float) -> void:
	var phase := Time.get_ticks_msec() / 900.0
	canvas.draw_circle(spot, radius + 1.5, Color(BroadcastUI.INK, 0.9))
	canvas.draw_circle(spot, radius, Color(0.1, 0.3, 0.45))
	var points := PackedVector2Array()
	for n in 24:
		var t := n / 23.0
		points.append(spot + Vector2.from_angle(phase + t * TAU * 1.5) * radius * 0.9 * t)
	canvas.draw_polyline(points, Whirlpool.COLOR, 2.0, true)


static func draw_skull(canvas: CanvasItem, spot: Vector2, radius: float) -> void:
	canvas.draw_circle(spot, radius + 1.5, Color(BroadcastUI.INK, 0.9))
	canvas.draw_circle(spot + Vector2(0.0, -radius * 0.15), radius * 0.85, BONE)
	canvas.draw_rect(Rect2(spot + Vector2(-radius * 0.5, radius * 0.25), Vector2(radius, radius * 0.6)), BONE)
	canvas.draw_circle(spot + Vector2(-radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))
	canvas.draw_circle(spot + Vector2(radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))


## The boss rift: a big red skull on a dark disc, ringed red, slowly pulsing.
static func draw_rift(canvas: CanvasItem, spot: Vector2, radius: float) -> void:
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	canvas.draw_circle(spot, radius + 3.5 + beat * 2.0, Color(RIFT_COLOR, 0.25 + 0.2 * beat))
	canvas.draw_circle(spot, radius + 2.0, Color(BroadcastUI.INK, 0.95))
	canvas.draw_arc(spot, radius + 1.0, 0.0, TAU, 24, RIFT_COLOR, 1.5, true)
	var r := radius * 0.92
	canvas.draw_circle(spot + Vector2(0.0, -r * 0.15), r * 0.85, RIFT_COLOR)
	canvas.draw_rect(Rect2(spot + Vector2(-r * 0.5, r * 0.25), Vector2(r, r * 0.6)), RIFT_COLOR)
	var socket := Color(0.12, 0.0, 0.0)
	canvas.draw_circle(spot + Vector2(-r * 0.35, -r * 0.15), r * 0.26, socket)
	canvas.draw_circle(spot + Vector2(r * 0.35, -r * 0.15), r * 0.26, socket)
	canvas.draw_colored_polygon(PackedVector2Array([spot + Vector2(0.0, r * 0.12), spot + Vector2(-r * 0.12, r * 0.38),
			spot + Vector2(r * 0.12, r * 0.38)]), socket)
	for n in 3:
		var x := (n - 1) * r * 0.3
		canvas.draw_line(spot + Vector2(x, r * 0.55), spot + Vector2(x, r * 0.85), socket, maxf(r * 0.1, 1.0))


## A player's arrow pointing `ahead` (unit, on the canvas), in `color`.
static func draw_arrow(canvas: CanvasItem, spot: Vector2, ahead: Vector2, color: Color, outline: Color, length: float) -> void:
	var side := Vector2(-ahead.y, ahead.x)
	var arrow := PackedVector2Array([spot + ahead * length, spot - ahead * length * 0.6 + side * length * 0.65,
			spot - ahead * length * 0.25, spot - ahead * length * 0.6 - side * length * 0.65])
	var ring := arrow.duplicate()
	ring.append(arrow[0])
	canvas.draw_colored_polygon(arrow, color)
	canvas.draw_polyline(ring, outline, 1.5, true)


## The swarms' texture from the Horde's survey, when there's a new one.
static func _refresh_clouds(horde: Horde) -> void:
	if horde.survey_version == _cloud_version and _cloud_texture:
		return
	_cloud_version = horde.survey_version
	var cells := horde.survey_cells
	if cells <= 0:
		return
	var counts := horde.survey_counts
	if _cloud_bytes.size() != cells * cells:
		_cloud_bytes.resize(cells * cells)
	for n in counts.size():
		var count := counts[n]
		_cloud_bytes[n] = 0 if count <= 0.0 else mini(roundi(255.0 * (1.0 - exp(-count * 0.45))), 255)
	var image := Image.create_from_data(cells, cells, false, Image.FORMAT_L8, _cloud_bytes)
	if _cloud_texture == null or _cloud_cells != cells:
		_cloud_texture = ImageTexture.create_from_image(image)
		_cloud_cells = cells
	else:
		_cloud_texture.update(image)


## The swarms: a disc the size of the map, its texture coordinates where each
## rim point lands in the survey's grid.
class Clouds extends Control:
	var map: Minimap

	func _draw() -> void:
		var run := map.hud.run
		if not is_instance_valid(run) or not is_instance_valid(run.horde) or Minimap._cloud_texture == null:
			return
		var horde := run.horde
		var span := horde.survey_cell * horde.survey_cells
		if span <= 0.0:
			return
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		for n in Minimap.SIDES:
			var spot := map._middle + Vector2.from_angle(TAU * n / Minimap.SIDES) * map._radius
			var world := map.from_map(spot)
			points.append(spot)
			uvs.append(Vector2((world.x - horde.survey_origin.x) / span, (world.y - horde.survey_origin.z) / span))
			colors.append(Color.WHITE)
		draw_polygon(points, colors, uvs, Minimap._cloud_texture)


## Everything over the clouds: the arena's edge, chests, elites, bosses and players.
class Marks extends Control:
	var map: Minimap

	func _draw() -> void:
		var run := map.hud.run
		var me := map.hud.fish
		if not is_instance_valid(run) or not is_instance_valid(me):
			return
		draw_arc(map._middle, map._radius, 0.0, TAU, Minimap.SIDES, Color(1, 1, 1, 0.35), 2.0, true)
		_draw_edge(run)
		for chest in run.shut_chests_for(me):
			var spot := map.to_map(chest.global_position)
			if map.on_map(spot, 5.0):
				Minimap.draw_chest(self, spot, chest.tint())
		for shrine in run.shrines:
			if is_instance_valid(shrine) and shrine.discovered:
				var spot := map.to_map(shrine.global_position)
				if map.on_map(spot, 6.0):
					Minimap.draw_shrine(self, spot, shrine.tint(), shrine.tide_active, 1.0, shrine.spent)
		if is_instance_valid(run.horde):
			for at in run.horde.survey_elites:
				var spot := map.to_map(at)
				if map.on_map(spot, 3.0):
					draw_circle(spot, 3.0, Minimap.ELITE_COLOR)
		for boss in run.bosses:
			if not is_instance_valid(boss) or boss.dying:
				continue
			var spot := map.to_map(boss.global_position)
			Minimap.draw_boss(self, map.to_rim(spot, 10.0), boss)
		if is_instance_valid(run.whirlpool):
			Minimap.draw_whirlpool(self, map.to_rim(map.to_map(run.whirlpool.global_position), 9.0), 8.0)
		if is_instance_valid(run.rift) and not run.rift.spent:
			Minimap.draw_rift(self, map.to_rim(map.to_map(run.rift.global_position), 14.0), 10.0)
		for fish in run.players:
			if is_instance_valid(fish) and fish != me:
				_draw_player(run, fish, false)
		_draw_player(run, me, true)

	## The arena's rim, wherever it crosses the map.
	func _draw_edge(run: UnnaturalRun) -> void:
		var last := Vector2.ZERO
		var last_in := false
		var steps := 128
		for n in steps + 1:
			var angle := TAU * n / steps
			var at := run.centre + Vector3(cos(angle), 0.0, sin(angle)) * run.settings.arena_radius
			var spot := map.to_map(at)
			var inside := map.on_map(spot, 1.0)
			if n > 0 and inside and last_in:
				draw_line(last, spot, Color(1.0, 0.45, 0.4, 0.7), 2.0, true)
			last = spot
			last_in = inside

	func _draw_player(run: UnnaturalRun, fish: FishController, mine: bool) -> void:
		var spot := map.to_map(fish.global_position)
		if not map.on_map(spot, 6.0):
			spot = map.to_rim(spot, 6.0)
		var facing := Vector2(-fish.global_basis.z.x, -fish.global_basis.z.z)
		var ahead := map.turn(facing.normalized()) if facing.length_squared() > 0.0001 else Vector2.UP
		var color := fish.body_color()
		color.a = 1.0
		Minimap.draw_arrow(self, spot, ahead, color, Color.WHITE if mine else Color(BroadcastUI.INK, 0.9), 9.0 if mine else 7.5)
		var health := run.health_of(fish)
		if health and health.down:
			var x := 5.0
			draw_line(spot + Vector2(-x, -x), spot + Vector2(x, x), Minimap.ELITE_COLOR, 2.5)
			draw_line(spot + Vector2(-x, x), spot + Vector2(x, -x), Minimap.ELITE_COLOR, 2.5)
