class_name CompassStrip
extends Control
## Unnatural's heading strip (planning_environment.md, E5): a rounded band
## across the top of each player's view, under the top row (level, XP and
## pearls), showing compass_fov degrees round the way the camera looks. Ticks
## every 15 degrees (longer every 45), N, E, S, W (north is the arena's -Z, as
## on the minimap's ring), and markers (HudIcons), each with its distance in
## metres:
## - shrines the team has found (Shrine.discovered): a temple in their colour;
## - the final boss (a devil's head), a mini-boss (a skull) and the whirlpool (a spiral);
## - the boss rift (a big red skull), from the start, until the final boss comes;
## - teammates (a diamond in their colour, a cross while down);
## - your shut chests within chest_sense_range (a chest).
## A marker past either end sticks there, smaller, with a chevron.

## Its height and its top (px at the 1280x720 design's scale).
const HEIGHT := 29.0
const TOP := 52.0
const TICK := 15.0
## Where what sits under the top row starts when there's no strip (px): the
## clock's top (UnnaturalHud).
const BASE := 58.0
## The XP bar's blue (the straight-ahead notch matches it).
const XP_TINT := Color(70 / 255.0, 214 / 255.0, 1.0)

var hud: UnnaturalHud
## The heading shown (radians, clockwise from north), for the probes.
var heading := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How far down the strip pushes what sits under the top row (px; 0: hidden).
func push() -> float:
	return maxf(position.y + size.y + 8.0 * _k() - BASE, 0.0) if visible else 0.0


## A world direction's bearing (radians, clockwise from north = -Z).
static func bearing_of(direction: Vector3) -> float:
	return atan2(direction.x, -direction.z)


## Where `bearing` lands across the strip (px from its left), and whether it's
## within the strip's span.
func place(bearing: float) -> Array:
	var span := deg_to_rad(maxf(hud.run.settings.compass_fov, 1.0))
	var inner := size.x - size.y  # the rounded ends hold no ticks
	var off := wrapf(bearing - heading, -PI, PI)
	var x := size.x * 0.5 + off / span * inner
	return [clampf(x, size.y * 0.5, size.x - size.y * 0.5), absf(off) <= span * 0.5]


func _process(_delta: float) -> void:
	var run := hud.run if hud else null
	visible = is_instance_valid(run) and run.settings.compass_strip and is_instance_valid(hud.fish) and not hud.cards_up()
	if not visible:
		return
	var view := get_viewport().get_visible_rect().size
	var k := _k()
	size = Vector2(roundf(view.x * clampf(run.settings.compass_width, 0.1, 1.0)), roundf(HEIGHT * k))
	position = Vector2(roundf((view.x - size.x) * 0.5), roundf(TOP * k))
	modulate.a = run.settings.compass_opacity
	var camera := hud.player_camera if is_instance_valid(hud.player_camera) else get_viewport().get_camera_3d()
	var basis := camera.global_basis if camera else hud.fish.global_basis
	var ahead := -basis.z
	if Vector2(ahead.x, ahead.z).length_squared() > 0.0001:
		heading = bearing_of(ahead)
	queue_redraw()


func _k() -> float:
	var view := get_viewport().get_visible_rect().size
	return maxf(minf(view.x / UITheme.REF_SIZE.x, view.y / UITheme.REF_SIZE.y), 0.75)


func _draw() -> void:
	var run := hud.run
	var me := hud.fish
	if not is_instance_valid(run) or not is_instance_valid(me):
		return
	var k := _k()
	var band := Rect2(Vector2.ZERO, size)
	UITheme.draw_box(self, band, Color(UITheme.DEEP, 0.6), size.y * 0.5, Minimap.PANEL_RIM, 1.0)
	# Ticks and letters, fading towards the ends.
	var mid := size.x * 0.5
	for n in 24:
		var at := place(deg_to_rad(n * TICK))
		if not at[1]:
			continue
		var x: float = at[0]
		var fade := 1.0 - smoothstep(0.7, 1.0, absf(x - mid) / maxf(mid - size.y * 0.5, 1.0))
		if n % 6 == 0:
			var tint := UITheme.CORAL if n == 0 else UITheme.INK
			UITheme.draw_text(self, Rect2(x - 14.0 * k, 0.0, 28.0 * k, size.y), Minimap.CARDINALS[n / 6], UITheme.condensed(700),
					roundi(15.0 * k), Color(tint, fade))
		else:
			var tall := size.y * (0.3 if n % 3 == 0 else 0.18)
			draw_line(Vector2(x, size.y - tall - 2.0), Vector2(x, size.y - 3.0), Color(0.78, 0.9, 1.0, (0.5 if n % 3 == 0 else 0.3) * fade),
					1.5 if n % 3 == 0 else 1.0)
	# Straight ahead: a small notch over the strip.
	draw_colored_polygon(PackedVector2Array([Vector2(mid - 5.0 * k, -6.0 * k), Vector2(mid + 5.0 * k, -6.0 * k),
			Vector2(mid, -1.0)]), XP_TINT)
	# Markers, nearest drawn last (on top).
	var marks := []
	for shrine in run.shrines:
		if is_instance_valid(shrine) and shrine.discovered and not shrine.spent:
			marks.append([shrine.global_position, "shrine", shrine])
	for boss in run.bosses:
		if is_instance_valid(boss) and not boss.dying:
			marks.append([boss.global_position, "boss", boss])
	if is_instance_valid(run.whirlpool):
		marks.append([run.whirlpool.global_position, "whirlpool", run.whirlpool])
	if is_instance_valid(run.rift) and not run.rift.spent:
		marks.append([run.rift.global_position, "rift", run.rift])
	for fish in run.players:
		if is_instance_valid(fish) and fish != me:
			marks.append([fish.global_position, "player", fish])
	for chest in run.shut_chests_for(me):
		if chest.global_position.distance_to(me.global_position) <= run.settings.chest_sense_range:
			marks.append([chest.global_position, "chest", chest])
	var at_me := me.global_position
	marks.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Vector3).distance_squared_to(at_me) > (b[0] as Vector3).distance_squared_to(at_me))
	for mark: Array in marks:
		_draw_mark(run, mark, at_me, k)


func _draw_mark(run: UnnaturalRun, mark: Array, from: Vector3, k: float) -> void:
	var where: Vector3 = mark[0]
	var flat := Vector3(where.x - from.x, 0.0, where.z - from.z)
	if flat.length_squared() < 0.01:
		return
	var at := place(bearing_of(flat))
	var inside: bool = at[1]
	var x: float = at[0]
	var scale := k * (1.0 if inside else 0.7)
	var spot := Vector2(x, size.y * 0.5)
	var thing: Object = mark[2]
	match mark[1]:
		"shrine":
			var shrine := thing as Shrine
			Minimap.draw_shrine(self, spot, shrine.tint(), shrine.tide_active, scale * 1.15)
		"boss":
			Minimap.draw_boss(self, spot, thing as Boss, scale * 1.05)
		"whirlpool":
			Minimap.draw_whirlpool(self, spot, 8.0 * scale)
		"rift":
			Minimap.draw_rift(self, spot, 9.0 * scale)
		"player":
			var fish := thing as FishController
			var color := fish.body_color()
			color.a = 1.0
			HudIcons.draw_mate(self, spot, 13.0 * scale, color)
			var health := run.health_of(fish)
			if health and health.down:
				var c := 5.0 * scale
				draw_line(spot + Vector2(-c, -c), spot + Vector2(c, c), Minimap.ELITE_COLOR, 2.5)
				draw_line(spot + Vector2(-c, c), spot + Vector2(c, -c), Minimap.ELITE_COLOR, 2.5)
		"chest":
			Minimap.draw_chest(self, spot, (thing as TreasureChest).tint(), scale)
	if not inside:
		var way := -1.0 if x < size.x * 0.5 else 1.0
		var tip := spot + Vector2(way * 11.0 * scale, 0.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(way * 4.0 * k, 0.0), tip + Vector2(0.0, -4.0 * k), tip + Vector2(0.0, 4.0 * k)]),
				Color(UITheme.INK, 0.8))
		return
	var metres := roundi(where.distance_to(from))
	UITheme.draw_text(self, Rect2(x - 24.0 * k, size.y + 1.0, 48.0 * k, 14.0 * k), "%d m" % metres, UITheme.condensed(600),
			roundi(11.0 * k), Color(UITheme.INK, 0.85))
