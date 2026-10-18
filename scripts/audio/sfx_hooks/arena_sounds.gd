class_name ArenaSounds
extends Node
## The aquarium's goals (planning_audio.md §3.3, §3.4): the net and the horn,
## in Free Play and matches alike. SfxHooks adds one to every AquariumArena.

## The arena's own horn, which falls back to match/goal_horn (decision A5).
const HORN := "match/goal_horn_aquarium"
## Ball speed (m/s) into the net for the softest and the hardest layer.
const NET_SOFT := 4.0
const NET_HARD := 30.0

var arena: AquariumArena


func _ready() -> void:
	arena = get_parent() as AquariumArena
	arena.goal_scored.connect(_on_goal_scored)


func _on_goal_scored(_team: int) -> void:
	var speed: float = arena.last_goal.get("speed", 0.0)
	Sfx.play_at("arena/goal_net", arena.ball.global_position, inverse_lerp(NET_SOFT, NET_HARD, speed))
	Sfx.play(HORN)
