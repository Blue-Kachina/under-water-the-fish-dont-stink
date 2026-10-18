class_name FishSounds
extends Node
## A fish's sounds (planning_audio.md §3.2): strokes and strides, jumps,
## dodges, boost (start, loop, tail, empty), supersonic, landings and resets.
## SfxHooks adds one to every FishController. Most come from the fish's
## signals; boost, supersonic and landings are read off its state each tick.

## Below this fraction of SUPERSONIC_SPEED, crossing it again whoomps again.
const SUPERSONIC_REARM := 0.85
## In the air at least this long before touching down counts as a landing.
const MIN_AIR_TIME := 0.3
## Speed into the surface (m/s) for the quietest and the loudest landing.
const LAND_SOFT := 2.0
const LAND_HARD := 14.0
## Closing speed (m/s) for the quietest and the loudest bump.
const BUMP_SOFT := 3.0
const BUMP_HARD := 25.0
## Sliding along a surface at least this fast (m/s) scrapes; this fast is the loudest.
const SCRAPE_MIN := 3.0
const SCRAPE_FULL := 20.0
## The bow wave is heard from this much of it (0..1).
const BOW_MIN := 0.1
## A stroke's quieter beats (beat 1 and 2, before the rhythm can judge it).
const TEMPO_BEAT := 0.3

var fish: FishController

var _boost_loop := 0
var _scrape_loop := 0
var _bow_loop := 0
var _was_boosting := false
var _was_boost_held := false
var _supersonic := false
var _air_time := 0.0
var _last_velocity := Vector3.ZERO
## No landing sound straight after a reset (it drops onto its spawn).
var _settle := 0.0


func _ready() -> void:
	fish = get_parent() as FishController
	process_physics_priority = 100  # after the fish has moved this tick
	fish.stroke_beat.connect(_on_stroke_beat)
	fish.strode.connect(_on_strode)
	fish.jumped.connect(func() -> void: _play("fish/jump"))
	fish.double_jumped.connect(func() -> void: _play("fish/double_jump"))
	fish.dodged.connect(func(_direction: Vector3) -> void: _play("fish/dodge"))
	fish.respawning.connect(_on_respawning)
	fish.body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	_stop_boost(false)
	_stop_loops()


func _physics_process(delta: float) -> void:
	if fish.puppet:
		return  # an online guest's copy: its own machine plays its sounds
	if fish.battered or not fish.visible:
		_stop_boost(false)
		_stop_loops()
		_was_boost_held = fish.boost_held
		return
	_settle = maxf(_settle - delta, 0.0)
	_update_boost()
	_update_supersonic()
	_update_landing(delta)
	_update_loops()
	_last_velocity = fish.linear_velocity


## Sliding along a wall or the floor, and the bow wave: loops that follow the fish.
func _update_loops() -> void:
	var slide := 0.0
	if fish.on_surface:
		var along := fish.linear_velocity - fish.surface_normal * fish.linear_velocity.dot(fish.surface_normal)
		slide = along.length()
	var scraping := slide >= SCRAPE_MIN
	_scrape_loop = _loop(_scrape_loop, "fish/scrape_loop", scraping, clampf(inverse_lerp(SCRAPE_MIN, SCRAPE_FULL, slide), 0.2, 1.0),
			lerpf(0.9, 1.2, clampf(slide / SCRAPE_FULL, 0.0, 1.0)))
	var bow := fish.bow_wave and fish.bow_amount >= BOW_MIN
	_bow_loop = _loop(_bow_loop, "fish/bow_wave_loop", bow, clampf(fish.bow_amount * (0.5 + 0.5 * fish.bow_scale), 0.0, 1.0))


## Keeps loop `handle` going (or not) as `on` says, and tuned.
func _loop(handle: int, id: String, on: bool, volume: float, pitch := 1.0) -> int:
	if on and handle == 0:
		handle = Sfx.start_loop(id, fish)
	elif not on and handle != 0:
		Sfx.stop_loop(handle, 0.2)
		return 0
	if handle != 0:
		Sfx.set_loop(handle, volume, pitch)
	return handle


func _stop_loops() -> void:
	Sfx.stop_loop(_scrape_loop)
	Sfx.stop_loop(_bow_loop)
	_scrape_loop = 0
	_bow_loop = 0


func _update_boost() -> void:
	var boosting := fish.is_boosting
	if boosting and not _was_boosting:
		_play("fish/boost_start")
		_boost_loop = Sfx.start_loop("fish/boost_loop", fish)
	elif not boosting and _was_boosting:
		_stop_boost(true)
	if boosting:
		var fraction := clampf(fish.speed / maxf(fish.max_boost_speed, 1.0), 0.0, 1.0)
		Sfx.set_loop(_boost_loop, 1.0, lerpf(0.85, 1.25, fraction))
	var pressed := fish.boost_held and not _was_boost_held
	if pressed and not boosting and fish.boost_enabled and not fish.boost_button_locks and not fish.controls_locked:
		_play("fish/boost_empty")
	_was_boost_held = fish.boost_held
	_was_boosting = boosting


func _stop_boost(tail: bool) -> void:
	if _boost_loop:
		Sfx.stop_loop(_boost_loop)
		_boost_loop = 0
		if tail and is_inside_tree():
			_play("fish/boost_stop")
	_was_boosting = false


func _update_supersonic() -> void:
	var speed := fish.linear_velocity.length()
	if not _supersonic and speed >= FishController.SUPERSONIC_SPEED:
		_supersonic = true
		_play("fish/supersonic")
	elif _supersonic and speed < FishController.SUPERSONIC_SPEED * SUPERSONIC_REARM:
		_supersonic = false


func _update_landing(delta: float) -> void:
	if not fish.on_surface:
		_air_time += delta
		return
	if _air_time >= MIN_AIR_TIME and _settle <= 0.0:
		var into := -_last_velocity.dot(fish.surface_normal)
		if into >= LAND_SOFT:
			_play("fish/land", inverse_lerp(LAND_SOFT, LAND_HARD, into))
	_air_time = 0.0


func _on_stroke_beat(quality: float, missed: bool) -> void:
	if missed:
		_play("fish/stroke_miss")
	else:
		_play("fish/stroke", lerpf(TEMPO_BEAT, 1.0, quality))


## Climbs the scale as the flow builds; louder the better the timing (a fresh
## stride, timing -1, sits in the middle).
func _on_strode(timing: float, flow: float) -> void:
	var step := roundi(7.0 * flow / maxf(fish.stride_flow_max, 0.01))
	var intensity := 0.5 if timing < 0.0 else lerpf(TEMPO_BEAT, 1.0, timing)
	Sfx.play_pitched("fish/stride", step, fish.global_position, intensity)


## Two fish touching that didn't batter each other: a bump. A battery hides its
## victim in the same tick, so it's judged one physics step later.
func _on_body_entered(body: Node) -> void:
	if body.get_parent() is Hoop and not fish.puppet:
		_play("arena/hoop_rim")
		return
	if not body is FishController or fish.puppet or fish.get_instance_id() > body.get_instance_id():
		return  # one sound for the pair
	var other := body as FishController
	var closing := (fish.linear_velocity - other.linear_velocity).length()
	await get_tree().physics_frame
	if is_instance_valid(fish) and is_instance_valid(other) and not fish.battered and not other.battered:
		_play("fish/bump", clampf(inverse_lerp(BUMP_SOFT, BUMP_HARD, closing), 0.0, 1.0))


## Heard where it lands: the move happens on the next physics step.
func _on_respawning() -> void:
	_stop_boost(false)
	_settle = 0.5
	_air_time = 0.0
	_supersonic = false
	if fish.controls_locked:
		return  # a kickoff lines everyone up in silence
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(fish):
		_play("fish/reset")


func _play(id: String, intensity := 1.0) -> void:
	Sfx.play_at(id, fish.global_position, clampf(intensity, 0.0, 1.0))
