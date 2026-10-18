class_name BedSounds
extends Node
## A place's ambience (planning_audio.md §3.9): the bed under an environment
## while it's there. SfxHooks adds one to every Arena (the obstacle course), every
## AquariumArena (Free Play, 1v1) and every Ocean (Free Swim, Nature, Hunt). An
## Unnatural run has its own seabed (UnnaturalSounds), so the Ocean's bed gives
## way to it. The Ocean also reads how thick its water is: the murk loop swells
## with it and the underwater low-pass closes down.

## The scene's clear water (its fog density), and how much past it is the thickest murk.
const CLEAR_FOG := 0.012
const THICKEST_FOG := 0.06
## Looked after this often (s).
const INTERVAL := 0.25

var place: Node

var _bed := 0
var _bed_id := ""
var _murk_loop := 0
var _left := 0.0


func _ready() -> void:
	place = get_parent()
	_update()


func _exit_tree() -> void:
	Sfx.stop_loop(_bed, 0.5)
	Sfx.stop_loop(_murk_loop, 0.5)
	if place is Ocean:
		Sfx.set_murk(0.0)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = INTERVAL
		_update()


## The bed this place has now ("" for none).
func wanted() -> String:
	var main := place.get_parent()
	if main != null and main.get("current_mode") == "Replays":
		return ""  # a replay has its own soundtrack
	if place is Arena:
		return "amb/arena_loop"
	if place is AquariumArena:
		return "amb/aquarium_loop"
	if place is Ocean:
		for child in place.get_children():
			if child is UnnaturalRun:
				return ""
		return "amb/ocean_loop"
	return ""


func _update() -> void:
	var id := wanted()
	if id != _bed_id:
		Sfx.stop_loop(_bed, 1.0)
		_bed = Sfx.start_loop(id) if id != "" else 0
		_bed_id = id
	if place is Ocean:
		var thickness := _thickness(place as Ocean)
		Sfx.set_murk(thickness)
		if thickness > 0.02 and _murk_loop == 0:
			_murk_loop = Sfx.start_loop("amb/murk_loop")
		elif thickness <= 0.02 and _murk_loop != 0:
			Sfx.stop_loop(_murk_loop, 1.0)
			_murk_loop = 0
		Sfx.set_loop(_murk_loop, thickness)


## How thick the Ocean's water is, 0 (the scene's clear water) to 1 (the thickest murk).
func _thickness(ocean: Ocean) -> float:
	var environment := ocean.environment()
	if environment == null or not environment.fog_enabled:
		return 0.0
	return clampf((environment.fog_density - CLEAR_FOG) / THICKEST_FOG, 0.0, 1.0)
