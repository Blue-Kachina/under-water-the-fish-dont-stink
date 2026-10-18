class_name Minimap
extends Control
## Unnatural's minimap (planning_murk.md §7): a flat, round, top-down map in
## the bottom-right of each player's view (one per UnnaturalHud, so split-screen
## gets one each). Your heading is up (minimap_heading_up; off: north is up),
## minimap_range m from the middle to the rim (0: the whole arena).
## - players: an arrow each, in their fish's colour, the way they face (you
##   outlined in white; a cross while down);
## - bosses: a skull (the mini-boss smaller), pinned to the rim when out of range;
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
const SIDES := 48

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
	_radius = side * 0.5 - 3.0
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
	draw_circle(_middle, _radius, Color(BroadcastUI.INK, 0.72))


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
				_draw_chest(spot, chest.tint())
		if is_instance_valid(run.horde):
			for at in run.horde.survey_elites:
				var spot := map.to_map(at)
				if map.on_map(spot, 3.0):
					draw_circle(spot, 3.0, Minimap.ELITE_COLOR)
		for boss in run.bosses:
			if not is_instance_valid(boss) or boss.dying:
				continue
			var spot := map.to_map(boss.global_position)
			_draw_skull(map.to_rim(spot, 9.0), 9.0 if boss is BloodLeviathan else 6.5)
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

	func _draw_chest(spot: Vector2, tint: Color) -> void:
		var box := Rect2(spot - Vector2(5.0, 4.0), Vector2(10.0, 8.0))
		draw_rect(box.grow(1.5), Color(BroadcastUI.INK, 0.9))
		draw_rect(box, tint)
		draw_line(Vector2(box.position.x, box.get_center().y - 1.0), Vector2(box.end.x, box.get_center().y - 1.0), Color(0.35, 0.2, 0.05), 1.0)

	func _draw_skull(spot: Vector2, radius: float) -> void:
		draw_circle(spot, radius + 1.5, Color(BroadcastUI.INK, 0.9))
		draw_circle(spot + Vector2(0.0, -radius * 0.15), radius * 0.85, Minimap.BONE)
		draw_rect(Rect2(spot + Vector2(-radius * 0.5, radius * 0.25), Vector2(radius, radius * 0.6)), Minimap.BONE)
		draw_circle(spot + Vector2(-radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))
		draw_circle(spot + Vector2(radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))

	func _draw_player(run: UnnaturalRun, fish: FishController, mine: bool) -> void:
		var spot := map.to_map(fish.global_position)
		if not map.on_map(spot, 6.0):
			spot = map.to_rim(spot, 6.0)
		var facing := Vector2(-fish.global_basis.z.x, -fish.global_basis.z.z)
		var ahead := map.turn(facing.normalized()) if facing.length_squared() > 0.0001 else Vector2.UP
		var side := Vector2(-ahead.y, ahead.x)
		var length := 9.0 if mine else 7.5
		var arrow := PackedVector2Array([spot + ahead * length, spot - ahead * length * 0.6 + side * length * 0.65,
				spot - ahead * length * 0.25, spot - ahead * length * 0.6 - side * length * 0.65])
		var color := fish.body_color()
		color.a = 1.0
		var outline := Color.WHITE if mine else Color(BroadcastUI.INK, 0.9)
		var ring := arrow.duplicate()
		ring.append(arrow[0])
		draw_colored_polygon(arrow, color)
		draw_polyline(ring, outline, 1.5, true)
		var health := run.health_of(fish)
		if health and health.down:
			var x := 5.0
			draw_line(spot + Vector2(-x, -x), spot + Vector2(x, x), Minimap.ELITE_COLOR, 2.5)
			draw_line(spot + Vector2(-x, x), spot + Vector2(x, -x), Minimap.ELITE_COLOR, 2.5)
