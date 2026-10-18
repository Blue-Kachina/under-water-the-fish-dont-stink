class_name BossSounds
extends Node
## A boss's moves (planning_audio.md §3.7): the Drowned Shark's wind-up and
## charge, the Blood Leviathan's phases and spit. Its arrival, rage and defeat
## are UnnaturalSounds'; its hits are gathered there too. SfxHooks adds one to
## every Boss. A puppet boss (an online guest's) makes the same sounds: its
## mode and phase follow the host's.

var boss: Boss

var _mode := -1


func _ready() -> void:
	boss = get_parent() as Boss
	if boss is BloodLeviathan:
		var leviathan := boss as BloodLeviathan
		leviathan.phase_changed.connect(func(_phase: int) -> void: Sfx.play("boss/leviathan_phase"))
		leviathan.spat.connect(func(from: Vector3, _directions: PackedVector3Array) -> void: Sfx.play_at("boss/leviathan_spit", from))
	if boss is DrownedShark:
		_mode = (boss as DrownedShark).mode
	else:
		set_process(false)


func _process(_delta: float) -> void:
	var mode := (boss as DrownedShark).mode
	if mode != _mode:
		if mode == DrownedShark.Mode.TELEGRAPH:
			Sfx.play_at("boss/shark_telegraph", boss.global_position)
		elif mode == DrownedShark.Mode.CHARGE:
			Sfx.play_at("boss/shark_charge", boss.global_position)
	_mode = mode
