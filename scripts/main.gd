extends Node3D
## Movement playground root: global shortcuts.

@onready var _fish: FishController = $Fish
@onready var _arena: Arena = $Arena


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		_fish.request_reset()
		_arena.reset_course()
