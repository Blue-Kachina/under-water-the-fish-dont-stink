class_name RaceArena
extends Node3D
## The environment Fin-ish Line is raced in (planning_race.md sections 4-6): main.gd builds it with
## ENVIRONMENTS[name].new() like any arena (spawn_transform(), configure_environment(env)). A track's own arena
## extends this and overrides track_data() (the RaceTrack dictionary), _build_world() (walls, terrain, cues, streams'
## visuals: children of this node) and, for the soft ceiling, ceiling_accel(). RaceMatch reads `track` for everything
## else, so a track swaps without touching the match.

## The course, built in _ready() from track_data() (null until then, or when the data is unusable).
var track: RaceTrack
## The water's look (a track sets these in _init or _build_world, before configure_environment runs).
var murk_density := 0.012
var murk_color := Color(0.04, 0.16, 0.2)
var background_color := Color(0.01, 0.05, 0.07)
var ambient_color := Color(0.35, 0.5, 0.55)
var ambient_energy := 0.7
## The arena has no collision to hold racers in the channel: RaceMatch leans on them softly instead (a grey box).
var soft_walls := false

var _env: Environment
var _saved := {}


func _ready() -> void:
	track = RaceTrack.build(track_data())
	if track != null:
		_build_world()


## The course as RaceTrack's dictionary (each track's own).
func track_data() -> Dictionary:
	return {}


## Builds the walls, terrain and dressing (each track's own). `track` exists.
func _build_world() -> void:
	pass


## A push (m/s^2) on a racer at world `pos` (the soft ceiling's downward current above the rim). None by default.
func ceiling_accel(_pos: Vector3) -> Vector3:
	return Vector3.ZERO


# --- The environment interface (main.gd) ---------------------------------------------

## The pole position of the grid.
func spawn_transform() -> Transform3D:
	if track == null:
		return Transform3D.IDENTITY
	return track.grid_slots(1)[0]["xform"]


func configure_environment(env: Environment) -> void:
	_env = env
	WaterLook.reset_grade(env)
	for property: String in ["background_mode", "background_color", "sky", "fog_enabled", "fog_light_color", "fog_density",
			"fog_sky_affect", "ambient_light_source", "ambient_light_color", "ambient_light_energy"]:
		_saved[property] = env.get(property)
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.sky = null
	env.fog_enabled = true
	env.fog_light_color = murk_color
	env.fog_density = murk_density
	env.fog_sky_affect = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy


func _exit_tree() -> void:
	if _env:
		for property: String in _saved:
			_env.set(property, _saved[property])
