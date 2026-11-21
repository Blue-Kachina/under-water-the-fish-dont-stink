class_name BatteredSounds
extends Node
## A 1v1's and a Hunt's batteries (planning_audio.md §3.5): the ram you land,
## the ram you take, the Fish Fry when both land at once, and the victim going
## out. SfxHooks adds one to every Match1v1 and to each game mode that lists it
## in its descriptor's "sfx" (all emit `battered`, with a null attacker for a
## Fish Fry, and have `player`, `opponent_fish()` and `battery_speed()`).

## The victim's "out" follows the hit by this long (s), so the two don't blur.
const OUT_DELAY := 0.35
## A battery's loudness runs from supersonic to this many times faster.
const HARD_FACTOR := 1.6

var game: Node
var player: FishController
var other: FishController


func _ready() -> void:
	game = get_parent()
	process_physics_priority = 100
	game.battered.connect(_on_battered)


func _on_battered(attacker: FishController, victim: FishController) -> void:
	player = game.player
	other = game.opponent_fish()
	if attacker == null:
		Sfx.play("battered/fish_fry")
		Sfx.play("voice/fish_fry")
		for fish: FishController in [player, other]:
			_out(fish)
		return
	var speed: float = game.battery_speed(attacker.speed)
	var hardness := inverse_lerp(FishController.SUPERSONIC_SPEED, FishController.SUPERSONIC_SPEED * HARD_FACTOR, speed)
	var yours := attacker == player
	Sfx.play_at("battered/battery" if yours else "battered/battered", victim.global_position, clampf(hardness, 0.0, 1.0))
	_out(victim)


func _out(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	var at := fish.global_position
	get_tree().create_timer(OUT_DELAY).timeout.connect(func() -> void: Sfx.play_at("battered/out", at))

