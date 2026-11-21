class_name HuntSounds
extends Node
## Hunt's own sounds (planning_audio.md 3.4): the hunter locking on, catching
## you, and you getting away. The match's and batteries' sounds are the shared
## MatchSounds and BatteredSounds. Attached through HuntMatch's descriptor
## ("sfx"), one per Hunt.

var game: HuntMatch

var _was_threatened := false


func _ready() -> void:
	game = get_parent() as HuntMatch
	process_physics_priority = 100
	game.battered.connect(_on_battered)
	game.stat_event.connect(_on_event)


func _physics_process(_delta: float) -> void:
	var threatened := game.phase == HuntMatch.Phase.LIVE and game.style.is_threatened(0)
	if threatened and not _was_threatened:
		Sfx.play("hunt/target_spotted")
	_was_threatened = threatened


## The hunter batters you.
func _on_battered(attacker: FishController, victim: FishController) -> void:
	if attacker != null and victim == game.player:
		Sfx.play("hunt/caught")


## A close call or dodge of yours: you got away.
func _on_event(event: Dictionary) -> void:
	if int(event.get("player", -1)) != 0:
		return
	var type: String = event.get("type", "")
	if type == StylePoints.CLOSE_CALL or type == StylePoints.DODGE:
		Sfx.play("hunt/escaped")
