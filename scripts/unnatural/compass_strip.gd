class_name CompassStrip
extends Control
## Unnatural's heading strip (planning_environment.md, E5): a band across the
## top of each player's view, under the XP bar, showing compass_fov degrees
## round the way the camera looks. Ticks every 15 degrees (longer every 45),
## N, E, S, W (north is the arena's -Z, as on the minimap's ring), and
## markers, each with its distance in metres:
## - shrines the team has found (Shrine.discovered), in their colour;
## - bosses (a skull) and the whirlpool (a spiral);
## - the boss rift (a big red skull), from the start, until the final boss comes;
## - teammates (an arrow in their colour, a cross while down);
## - your shut chests within chest_sense_range (a box).
## A marker past either end sticks there, half-size, with a chevron.

## Its height (px at the 1280x720 design's scale) and its top (px, like the XP bar above it).
const HEIGHT := 26.0
const TOP := 30.0
const TICK := 15.0

var hud: UnnaturalHud
## The heading shown (radians, clockwise from north), for the probes.
var heading := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How far down the strip pushes what sits under the XP bar (px; 0: hidden).
func push() -> float:
	return TOP + size.y + 18.0 * _k() - 20.0 if visible else 0.0


## A world direction's bearing (radians, clockwise from north = -Z).
static func bearing_of(direction: Vector3) -> float:
	return atan2(direction.x, -direction.z)


## Where `bearing` lands across the strip (px from its left), and whether it's
## within the strip's span.
func place(bearing: float) -> Array:
	var span := deg_to_rad(maxf(hud.run.settings.compass_fov, 1.0))
	var off := wrapf(bearing - heading, -PI, PI)
	var x := size.x * 0.5 + off / span * size.x
	return [clampf(x, 0.0, size.x), absf(off) <= span * 0.5]


func _process(_delta: float) -> void:
	var run := hud.run if hud else null
	visible = is_instance_valid(run) and run.settings.compass_strip and is_instance_valid(hud.fish) and not hud.cards_up()
	if not visible:
		return
	var view := get_viewport().get_visible_rect().size
	var k := _k()
	size = Vector2(roundf(view.x * clampf(run.settings.compass_width, 0.1, 1.0)), HEIGHT * k)
	position = Vector2(roundf((view.x - size.x) * 0.5), TOP)
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
	draw_rect(band, Color(BroadcastUI.INK, 0.72))
	draw_line(Vector2(0.0, size.y), Vector2(size.x, size.y), Color(1, 1, 1, 0.25), 1.0)
	# Fade the band's ends.
	var fade := minf(size.x * 0.08, 48.0)
	for n in 6:
		var w := fade / 6.0
		var a := 0.5 * (1.0 - n / 6.0)
		draw_rect(Rect2(n * w, 0.0, w, size.y), Color(BroadcastUI.INK, a))
		draw_rect(Rect2(size.x - (n + 1) * w, 0.0, w, size.y), Color(BroadcastUI.INK, a))
	# Ticks and letters.
	for n in 24:
		var at := place(deg_to_rad(n * TICK))
		if not at[1]:
			continue
		var x: float = at[0]
		if n % 6 == 0:
			var tint := UITheme.CORAL if n == 0 else Color.WHITE
			BroadcastUI.text(self, Rect2(x - 14.0 * k, 0.0, 28.0 * k, size.y), Minimap.CARDINALS[n / 6], roundi(16.0 * k), tint,
					HORIZONTAL_ALIGNMENT_CENTER, 800)
		else:
			var tall := size.y * (0.42 if n % 3 == 0 else 0.25)
			draw_line(Vector2(x, size.y - tall), Vector2(x, size.y - 2.0), Color(1, 1, 1, 0.6 if n % 3 == 0 else 0.35), 1.5 if n % 3 == 0 else 1.0)
	# Straight ahead.
	var mid := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(mid - 5.0 * k, size.y + 6.0 * k), Vector2(mid + 5.0 * k, size.y + 6.0 * k),
			Vector2(mid, size.y + 1.0)]), Color(1, 1, 1, 0.85))
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
	var scale := k * (1.0 if inside else 0.65)
	var spot := Vector2(x, size.y * 0.5)
	var thing: Object = mark[2]
	match mark[1]:
		"shrine":
			var shrine := thing as Shrine
			Minimap.draw_shrine(self, spot, shrine.tint(), shrine.tide_active, scale * 1.3)
		"boss":
			Minimap.draw_skull(self, spot, 8.0 * scale)
		"whirlpool":
			Minimap.draw_whirlpool(self, spot, 8.0 * scale)
		"rift":
			Minimap.draw_rift(self, spot, 9.5 * scale)
		"player":
			var fish := thing as FishController
			var color := fish.body_color()
			color.a = 1.0
			Minimap.draw_arrow(self, spot, Vector2.DOWN, color, Color(BroadcastUI.INK, 0.9), 8.0 * scale)
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
				Color(1, 1, 1, 0.8))
		return
	var metres := roundi(where.distance_to(from))
	BroadcastUI.text(self, Rect2(x - 24.0 * k, size.y + 1.0, 48.0 * k, 14.0 * k), "%d m" % metres, roundi(11.0 * k),
			Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 700)
