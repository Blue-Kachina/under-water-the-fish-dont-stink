extends Node
## Display preferences (autoloaded as "UISettings"): which HUD extras show, the
## player's name, goal replays and fullscreen. Saved on this PC as soon as they
## change (user://playground.cfg, section "ui"); the tuning panel's UI section
## edits them. F11 or Alt+Enter toggles fullscreen.

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
var fullscreen := false
## Shown on the scoreboard and when you score.
var player_name := DEFAULT_NAME

const KEYS := ["show_stats", "show_input_overlay", "goal_replays", "fullscreen", "player_name"]


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		for key: String in KEYS:
			set(key, settings.get_value(SECTION, key, get(key)))
	if player_name.strip_edges().is_empty():
		player_name = DEFAULT_NAME
	_apply_fullscreen()


## Changes one setting, applies it and remembers it.
func set_value(key: String, value: Variant) -> void:
	if key not in KEYS or get(key) == value:
		return
	set(key, value)
	if key == "fullscreen":
		_apply_fullscreen()
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
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
