class_name BossSounds
extends Node
## A boss's moves (planning_audio.md §3.7): the Drowned Shark's wind-up, charge
## and chomp, the Blood Leviathan's phases, spit and chomp, a final boss's grab
## and the stride that breaks free of it, the Gulper's suck and the Fallen
## Angel's lock-on. Its arrival, rage and defeat are UnnaturalSounds'; its hits
## are gathered there too. SfxHooks adds one to every Boss. A puppet boss (an
## online guest's) makes the same sounds: its mode and phase follow the host's.

var boss: Boss

var _mode := -1
var _sucking := false
var _locking := false


func _ready() -> void:
	boss = get_parent() as Boss
	if boss is BloodLeviathan:
		var leviathan := boss as BloodLeviathan
		leviathan.phase_changed.connect(func(_phase: int) -> void: Sfx.play("boss/leviathan_phase"))
		leviathan.spat.connect(func(from: Vector3, _directions: PackedVector3Array) -> void: Sfx.play_at("boss/leviathan_spit", from))
		leviathan.chomped.connect(func(at: Vector3, _bit: int) -> void: Sfx.play_at("boss/chomp", at))
		leviathan.held_changed.connect(func(fish: FishController, on: bool) -> void:
			if on:
				Sfx.play_at("boss/grab", fish.global_position)
			elif leviathan.hold_strides >= leviathan.settings.final_hold_strides:
				Sfx.play("boss/break_free"))
	if boss is DrownedShark:
		_mode = (boss as DrownedShark).mode
		(boss as DrownedShark).chomped.connect(func(at: Vector3, _bit: int) -> void: Sfx.play_at("boss/chomp", at))
	elif not (boss is GulperBoss or boss is FallenAngelBoss):
		set_process(false)


func _process(_delta: float) -> void:
	if boss is GulperBoss:
		var sucking := (boss as GulperBoss).sucking
		if sucking and not _sucking:
			Sfx.play_at("boss/gulper_suck", (boss as GulperBoss).mouth_point())
		_sucking = sucking
		return
	if boss is FallenAngelBoss:
		var locking := (boss as FallenAngelBoss).state == FallenAngelBoss.State.LOCK
		if locking and not _locking:
			Sfx.play_at("boss/angel_lock", boss.global_position)
		_locking = locking
		return
	var mode := (boss as DrownedShark).mode
	if mode != _mode:
		if mode == DrownedShark.Mode.TELEGRAPH:
			Sfx.play_at("boss/shark_telegraph", boss.global_position)
		elif mode == DrownedShark.Mode.CHARGE:
			Sfx.play_at("boss/shark_charge", boss.global_position)
	_mode = mode
