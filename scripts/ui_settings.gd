extends Node
## Display preferences (autoloaded as "UISettings"): which HUD extras show, the
## player's name, goal replays and fullscreen. Saved on this PC as soon as they
## change (user://playground.cfg, section "ui"); the tuning panel's UI section
## edits them. The game always starts fullscreen (not test scenes); F11 or
## Alt+Enter toggles it.

signal changed(key: String)

const SETTINGS_PATH := "user://playground.cfg"
const SECTION := "ui"
const DEFAULT_NAME := "Player"

## The speed / forward / drift / ... readout (a tuning aid).
var show_stats := false
## The live controller-input display (a tuning aid).
var show_input_overlay := false
## A replay of each goal in a 1v1, from the net (skippable).
var goal_replays := true
var fullscreen := true
## Shown on the scoreboard and when you score.
var player_name := DEFAULT_NAME

## Set once the Konami code has been entered (in the console, or on the home
## screen): the Replays button shows from then on, and SELECT in the mode
## picker can show the hidden modes.
var konami_entered := false
## The mode picker shows the hidden modes (Fish Sticks, the Test Tank). SELECT
## toggles it there, once the Konami code's been entered.
var show_hidden_modes := false
## Shows the tuning options that aren't for everyday use (SELECT toggles it in Settings).
var show_debug_tweaks := false
## Graphics quality (WaterLook.Quality: 0 Low, 1 Medium, 2 High). High is the look as tuned; Low and Medium thin the snow, shafts, glints and bloom, and Low drops to one caustic tap and a 0.77 render scale (FSR). Never auto-detected.
var graphics_quality := 2
## Adaptive resolution: nudges the render scale down (and back up) to hold the GPU time near the frame time. Off by default.
var adaptive_resolution := false

const KEYS := ["show_stats", "show_input_overlay", "goal_replays", "fullscreen", "player_name", "konami_entered", "show_hidden_modes",
		"show_debug_tweaks", "graphics_quality", "adaptive_resolution"]


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		for key: String in KEYS:
			set(key, settings.get_value(SECTION, key, get(key)))
		if settings.get_value(SECTION, "replays_unlocked", false):
			konami_entered = true  # saved before the Konami code did more than the Replays button
	if player_name.strip_edges().is_empty():
		player_name = DEFAULT_NAME
	fullscreen = true  # every start, whatever it was left on
	_apply_quality()
	_apply_fullscreen.call_deferred()  # once the scene's known


## Changes one setting, applies it and remembers it.
func set_value(key: String, value: Variant) -> void:
	if key not in KEYS or get(key) == value:
		return
	set(key, value)
	if key == "fullscreen":
		_apply_fullscreen()
	elif key in ["graphics_quality", "adaptive_resolution"]:
		_apply_quality()
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value(SECTION, key, value)
	settings.save(SETTINGS_PATH)
	changed.emit(key)


## The name to show for the player (never empty).
func display_name() -> String:
	var trimmed := player_name.strip_edges()
	return trimmed if not trimmed.is_empty() else DEFAULT_NAME


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		set_value("fullscreen", not fullscreen)
		get_viewport().set_input_as_handled()


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path.begins_with("res://tests/"):
		return  # screenshot tools and probes keep their own window
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Hands the graphics quality to the water look and puts its render scale on the window and the split-screen views.
func _apply_quality() -> void:
	WaterLook.quality = clampi(graphics_quality, 0, 2)
	if not adaptive_resolution:
		WaterLook.auto_scale = 1.0
		_adapt_gpu_ms = 0.0
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene and scene.scene_file_path.begins_with("res://tests/") and WaterLook.shared().quality_force < 0:
		return  # screenshot tools and probes keep native resolution unless they force a tier
	WaterLook.shared().apply_scale_all(get_tree())
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), adaptive_resolution)


var _adapt_clock := 0.0
var _adapt_gpu_ms := 0.0


## Adaptive resolution (Settings): every half second, averages the GPU time and steps the render scale one notch down when it is over
## the target share of the frame time, back up when there is plenty of room. Pixels only (the plan's draw-distance step is not done).
func _process(delta: float) -> void:
	if not adaptive_resolution or DisplayServer.get_name() == "headless":
		return
	var look := WaterLook.shared()
	var ms := RenderingServer.viewport_get_measured_render_time_gpu(get_tree().root.get_viewport_rid())
	if ms <= 0.0:
		return
	_adapt_gpu_ms = ms if _adapt_gpu_ms <= 0.0 else lerpf(_adapt_gpu_ms, ms, 0.1)
	_adapt_clock += delta
	if _adapt_clock < 0.5:
		return
	_adapt_clock = 0.0
	var refresh := DisplayServer.screen_get_refresh_rate()
	var frame_ms := 1000.0 / (refresh if refresh > 1.0 else 60.0)
	var target := frame_ms * look.auto_target
	var base := maxf(look.eff_scale() / maxf(WaterLook.auto_scale, 0.01), 0.01)  # the tier's own scale
	var floor_factor := clampf(look.auto_floor / base, 0.1, 1.0)
	var next := WaterLook.auto_scale
	if _adapt_gpu_ms > target:
		next = maxf(next - 0.05, floor_factor)
	elif _adapt_gpu_ms < target * 0.6:
		next = minf(next + 0.05, 1.0)
	if not is_equal_approx(next, WaterLook.auto_scale):
		WaterLook.auto_scale = next
		look.apply_scale_all(get_tree())
