class_name RoundMap
extends Control
## A flat, round, top-down map: the base of Unnatural's Minimap and Marco Polo's
## SonarMap. It holds this frame's layout (`frame`), the world <-> map maths
## (`to_map`, `from_map`, `turn`, `on_map`, `to_rim`), the plate and compass
## bezel, and the painters any round map can use (`draw_arrow`, `draw_skull`).

const SIDES := 48
const BONE := Color(0.92, 0.88, 0.8)
## The compass ring's width (px) round the map, and its letters.
const BEZEL := 15.0
const CARDINALS := ["N", "E", "S", "W"]
## The thin pale rim round the HUD's panels (the HUD redesign).
const PANEL_RIM := Color(150 / 255.0, 215 / 255.0, 1.0, 0.22)

## This frame's map: the middle (world and px), its axes (flat world, unit),
## px per metre and the radius (px).
var _centre := Vector3.ZERO
var _right := Vector2.RIGHT
var _forward := Vector2.UP
var _scale := 1.0
var _radius := 1.0
var _middle := Vector2.ZERO


## Lays the map out for this frame: `side` px square at `at` (top-left), centred
## on `centre`, `reach` m from the middle to the rim, `forward` (flat world, unit)
## pointing up, with room for the bezel when `bezel`.
func frame(at: Vector2, side: float, centre: Vector3, reach: float, forward: Vector2, bezel: bool) -> void:
	size = Vector2(side, side)
	position = at
	_middle = size * 0.5
	_radius = side * 0.5 - (BEZEL if bezel else 3.0)
	_centre = centre
	_scale = _radius / maxf(reach, 1.0)
	_forward = forward
	_right = Vector2(-_forward.y, _forward.x)


## Where up points for a heading-up map: where `camera` looks (or `fallback`
## faces), or north when neither gives a flat direction.
static func heading(camera: Camera3D, fallback: Node3D) -> Vector2:
	var basis := camera.global_basis if camera else (fallback.global_basis if fallback else Basis.IDENTITY)
	var ahead := Vector2(-basis.z.x, -basis.z.z)
	if ahead.length_squared() > 0.0001:
		return ahead.normalized()
	return Vector2(0.0, -1.0)


## `at` on the map (px, from its top-left corner).
func to_map(at: Vector3) -> Vector2:
	var d := Vector2(at.x - _centre.x, at.z - _centre.z)
	return _middle + Vector2(d.dot(_right), -d.dot(_forward)) * _scale


## A world point given flat (x, z) on the map.
func flat_to_map(at: Vector2) -> Vector2:
	var d := Vector2(at.x - _centre.x, at.y - _centre.z)
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


## The map's dark plate, and the bezel or a thin rim round it.
func draw_plate(plate: Color, bezel: bool) -> void:
	draw_circle(_middle, _radius, plate, true, -1.0, true)
	if bezel:
		draw_bezel()
	else:
		draw_arc(_middle, _radius, 0.0, TAU, SIDES * 2, PANEL_RIM, 1.5, true)


## The compass ring (planning_environment.md, E5): a band round the map with a
## tick every 15 degrees (longer every 45) and N, E, S, W where they lie,
## turning with the map. North is the arena's -Z.
func draw_bezel(north := UITheme.CORAL) -> void:
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
			var tint := north if n == 0 else Color(1, 1, 1, 0.9)
			UITheme.draw_text(self, Rect2(spot - Vector2(10.0, 8.0), Vector2(20.0, 16.0)), letter, UITheme.condensed(700),
					maxi(roundi(band * 0.85), 8), tint)
			continue
		var long := n % 3 == 0
		var inner := _radius + band * (0.3 if long else 0.55)
		draw_line(_middle + way * inner, _middle + way * (outer - band * 0.15), Color(1, 1, 1, 0.55 if long else 0.35), 1.5 if long else 1.0, true)


## A player's arrow pointing `ahead` (unit, on the canvas), in `color`.
static func draw_arrow(canvas: CanvasItem, spot: Vector2, ahead: Vector2, color: Color, outline: Color, length: float) -> void:
	var side := Vector2(-ahead.y, ahead.x)
	var arrow := PackedVector2Array([spot + ahead * length, spot - ahead * length * 0.6 + side * length * 0.65,
			spot - ahead * length * 0.25, spot - ahead * length * 0.6 - side * length * 0.65])
	var ring := arrow.duplicate()
	ring.append(arrow[0])
	canvas.draw_colored_polygon(arrow, color)
	canvas.draw_polyline(ring, outline, 1.5, true)


static func draw_skull(canvas: CanvasItem, spot: Vector2, radius: float) -> void:
	canvas.draw_circle(spot, radius + 1.5, Color(BroadcastUI.INK, 0.9))
	canvas.draw_circle(spot + Vector2(0.0, -radius * 0.15), radius * 0.85, BONE)
	canvas.draw_rect(Rect2(spot + Vector2(-radius * 0.5, radius * 0.25), Vector2(radius, radius * 0.6)), BONE)
	canvas.draw_circle(spot + Vector2(-radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))
	canvas.draw_circle(spot + Vector2(radius * 0.35, -radius * 0.15), radius * 0.24, Color(0.6, 0.0, 0.0))
