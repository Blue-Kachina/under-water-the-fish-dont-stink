class_name DamageNumbers
extends Control
## Unnatural's damage numbers (the Playability pass, P3), over one player's
## view (a child of their UnnaturalHud): each of their hits (UnnaturalRun's
## zombie_hit) floats a number up off the zombie it landed on and fades. At
## scale, with thousands of hits a second:
## - hits on the same zombie within damage_number_merge s of its number's first
##   add into that number (it bumps), so a burning crowd stays readable;
## - only numbers of damage_numbers_min or more are drawn (0: all);
## - at most damage_numbers_max are kept, a new one taking the oldest's place.
## A crit's number (UnnaturalRun.last_hit_crit) is crit_number_scale times
## bigger and gold. With damage_numbers_team, teammates' hits show too, fainter.

## How fast a number floats up (m/s), and how long its pop (or a merge's bump) lasts (s).
const RISE := 1.3
const POP := 0.12
## A number this far from the camera (m) is drawn at full size.
const NEAR := 14.0
const WHITE := Color(1.0, 1.0, 1.0)
const CRIT := Color(1.0, 0.78, 0.18)
const TEAM_ALPHA := 0.55

var hud: UnnaturalHud
## Numbers started since the run began (merges don't count), and drawn last frame.
var made := 0
var drawn := 0

var _zombie := PackedInt32Array()
var _at := PackedVector3Array()
var _amount := PackedFloat32Array()
var _crit := PackedByteArray()
var _own := PackedByteArray()
var _age := PackedFloat32Array()
var _bump := PackedFloat32Array()
## Zombie slot -> its number still open to merges.
var _open := {}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = BroadcastUI.font(800)
	if is_instance_valid(hud) and is_instance_valid(hud.run):
		hud.run.zombie_hit.connect(_on_hit)
		hud.run.restarted.connect(clear)


## Every number gone.
func clear() -> void:
	_age.fill(INF)
	_open.clear()
	drawn = 0


## How many numbers are up now.
func count() -> int:
	var n := 0
	for age in _age:
		n += 1 if age < INF else 0
	return n


## How many of those are big enough to show (damage_numbers_min).
func showable() -> int:
	var n := 0
	for k in _age.size():
		n += 1 if _age[k] < INF and _amount[k] >= hud.run.settings.damage_numbers_min else 0
	return n


## The number on zombie `index` still open to merges: [amount, crit] ([] none).
func number_on(index: int) -> Array:
	var k: int = _open.get(index, -1)
	return [] if k < 0 else [_amount[k], _crit[k] == 1]


func _on_hit(index: int, amount: float, by: FishController, _source: String, _chain: Array) -> void:
	var run := hud.run
	var settings := run.settings
	if not settings.damage_numbers or amount <= 0.0 or by == null:
		return
	var own := by == hud.fish
	if not own and not settings.damage_numbers_team:
		return
	var crit := run.last_hit_crit
	amount = run.last_hit_dealt  # a killing blow shows what it took, not its overkill
	if amount <= 0.0:
		return
	var k: int = _open.get(index, -1)
	if k >= 0 and _age[k] < settings.damage_number_merge and _zombie[k] == index and (_own[k] == 1) == own:
		_amount[k] += amount
		_crit[k] = 1 if crit or _crit[k] == 1 else 0
		_bump[k] = _age[k]
		return
	var room := maxi(settings.damage_numbers_max, 1)
	if _age.size() != room:
		_fit(room)
	# A free slot, or the oldest.
	k = 0
	var oldest := -1.0
	for n in _age.size():
		if _age[n] == INF:
			k = n
			break
		if _age[n] > oldest:
			oldest = _age[n]
			k = n
	if _age[k] < INF:
		_open.erase(_zombie[k])
	var horde := run.horde
	# Anywhere over its body, so a crowd's numbers don't stack on one spot.
	var radius := horde.enemy_radius(index)
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 0.8), randf_range(-1.0, 1.0)) * minf(radius, 4.0)
	_zombie[k] = index
	_at[k] = horde.enemy_position(index) + Vector3.UP * (minf(radius, 4.0) + 0.2) + jitter
	_amount[k] = amount
	_crit[k] = 1 if crit else 0
	_own[k] = 1 if own else 0
	_age[k] = 0.0
	_bump[k] = 0.0
	_open[index] = k
	made += 1


func _fit(room: int) -> void:
	_zombie.resize(room)
	_at.resize(room)
	_amount.resize(room)
	_crit.resize(room)
	_own.resize(room)
	_age.resize(room)
	_age.fill(INF)
	_bump.resize(room)
	_open.clear()


func _process(delta: float) -> void:
	if not is_instance_valid(hud) or not is_instance_valid(hud.run):
		return
	var settings := hud.run.settings
	var life := maxf(settings.damage_number_time, 0.05)
	for k in _age.size():
		if _age[k] == INF:
			continue
		_age[k] += delta
		if _age[k] >= settings.damage_number_merge and _open.get(_zombie[k], -1) == k:
			_open.erase(_zombie[k])
		if _age[k] >= life:
			_age[k] = INF
	queue_redraw()


func _draw() -> void:
	drawn = 0
	if not is_instance_valid(hud) or not is_instance_valid(hud.run):
		return
	var settings := hud.run.settings
	if not settings.damage_numbers:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var life := maxf(settings.damage_number_time, 0.05)
	var k := minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y)
	for n in _age.size():
		var age := _age[n]
		if age == INF or _amount[n] < settings.damage_numbers_min:
			continue
		var at := _at[n] + Vector3.UP * RISE * age
		if camera.is_position_behind(at):
			continue
		var spot := camera.unproject_position(at)
		if not Rect2(Vector2.ZERO, size).grow(40.0).has_point(spot):
			continue
		var crit := _crit[n] == 1
		var pop := 1.0 + 0.35 * (1.0 - clampf((age - _bump[n]) / POP, 0.0, 1.0))
		# Smaller further off (as far as half size), a little bigger for big hits.
		var near := clampf(NEAR / maxf(camera.global_position.distance_to(at), 0.1), 0.5, 1.2)
		var px := settings.damage_number_size * k * pop * near * (settings.crit_number_scale if crit else 1.0) \
				* (1.0 + 0.08 * log(maxf(_amount[n], 1.0)) / log(10.0))
		var fade := 1.0 - smoothstep(0.6, 1.0, age / life)
		var color := CRIT if crit else WHITE
		color.a = fade * (1.0 if _own[n] == 1 else TEAM_ALPHA)
		var text := _text(_amount[n]) + ("!" if crit else "")
		var font_size := maxi(roundi(px), 6)
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var base := spot + Vector2(-width * 0.5, font_size * 0.35)
		draw_string_outline(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(roundi(font_size * 0.22), 2), Color(0.05, 0.02, 0.03, color.a * 0.85))
		draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		drawn += 1


static func _text(amount: float) -> String:
	if amount >= 100000.0:
		return "%dk" % roundi(amount / 1000.0)
	if amount >= 10000.0:
		return "%.1fk" % (amount / 1000.0)
	return str(maxi(roundi(amount), 1))
