class_name CourseMode
extends GameMode
## The Obstacle Course as a GameMode (planning_core_roadmap.md 3.3, item 4): hoops, ramps and walls
## in the Obstacle Course environment (Arena, a core environment: its hoops, ring cam and course
## timer are the arena's own). No card: it plays as soon as it's picked. It plays like Unnatural:
## Nature's tuning (the descriptor's preset), the survivor cam (the SurvivorCam kit, live from the
## panel) with the ball cam off, and each fish's traversal with the mobility skill on the boost
## button (CourseSkill, Traversal with no run).

var skill: CourseSkill
var _world: ModeWorld


static func descriptor() -> Dictionary:
	return {
		"id": "Obstacle Course", "title": "Obstacle Course", "icon": "mode_obstacle_course",
		"colors": [Color(0.16, 0.12, 0.05), Color(1.0, 0.8, 0.3)],
		"pitch": "Hoops, ramps and walls to swim through, round and over.",
		"short": "Hoops, ramps and walls", "play": ["Solo"],
		"environment": "Obstacle Course", "after": "Test Tank", "tile_before": "Test Tank",
		"tuning_preset": "res://presets/nature.cfg", "reset_label": "Reset",
	}


func enter(world: ModeWorld) -> void:
	_world = world


## On: the survivor cam with no ball cam, and the fish's traversal.
func start() -> void:
	var camera: Node = _world.camera
	camera.ball_cam = false
	skill = CourseSkill.new()
	skill.name = "CourseSkill"
	skill.fish = _world.fish
	add_child(skill)
	SurvivorCam.apply(camera, true, SurvivorCamSettings.shared())
	_world.hud.survivor_cam = true
	camera.snap()


func _process(_delta: float) -> void:
	SurvivorCam.apply(_world.camera, true, SurvivorCamSettings.shared())  # live from the panel


## R: the fish back at the start and the course's hoops and timer reset.
func reset() -> void:
	var arena := _world.environment as Arena
	_world.fish.set_spawn(_world.environment.spawn_transform())
	_world.fish.respawning.emit()
	if arena:
		arena.reset_course()


## Leaving: the fish's own swimming back (now, not when the node goes), and the usual camera.
func end() -> void:
	if skill:
		remove_child(skill)
		skill.queue_free()
		skill = null
	SurvivorCam.apply(_world.camera, false, SurvivorCamSettings.shared())
	_world.hud.survivor_cam = false
	_world.camera.snap()
