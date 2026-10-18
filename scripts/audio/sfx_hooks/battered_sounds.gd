class_name BatteredSounds
extends Node
## A 1v1's and a Hunt's batteries (planning_audio.md §3.5): the ram you land,
## the ram you take, the Fish Fry when both land at once, and the victim going
## out. SfxHooks adds one to every Match1v1 and HuntMatch (both emit `battered`,
## with a null attacker for a Fish Fry). Hunt also gets its own three sounds
## (§3.4): the hunter locking on, catching you, and you getting away.

## The victim's "out" follows the hit by this long (s), so the two don't blur.
const OUT_DELAY := 0.35
## A battery's loudness runs from supersonic to this many times faster.
const HARD_FACTOR := 1.6

var game: Node
var player: FishController
var other: FishController

var _was_threatened := false


func _ready() -> void:
	game = get_parent()
	process_physics_priority = 100
	game.battered.connect(_on_battered)
	if game is HuntMatch:
		game.stat_event.connect(_on_hunt_event)
	else:
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var hunt := game as HuntMatch
	var threatened := hunt.phase == HuntMatch.Phase.LIVE and hunt.style.is_threatened(0)
	if threatened and not _was_threatened:
		Sfx.play("hunt/target_spotted")
	_was_threatened = threatened


func _on_battered(attacker: FishController, victim: FishController) -> void:
	player = game.player
	other = game.opponent if game is HuntMatch else game.bot_fish
	if attacker == null:
		Sfx.play("battered/fish_fry")
		Sfx.play("voice/fish_fry")
		for fish: FishController in [player, other]:
			_out(fish)
		return
	var speed := attacker.speed
	if game is HuntMatch:
		speed = float(game.last_battery.get("speed", speed))
	var hardness := inverse_lerp(FishController.SUPERSONIC_SPEED, FishController.SUPERSONIC_SPEED * HARD_FACTOR, speed)
	var yours := attacker == player
	Sfx.play_at("battered/battery" if yours else "battered/battered", victim.global_position, clampf(hardness, 0.0, 1.0))
	_out(victim)
	if game is HuntMatch and victim == player:
		Sfx.play("hunt/caught")


func _out(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	var at := fish.global_position
	get_tree().create_timer(OUT_DELAY).timeout.connect(func() -> void: Sfx.play_at("battered/out", at))


## A close call or dodge of yours: you got away.
func _on_hunt_event(event: Dictionary) -> void:
	if int(event.get("player", -1)) != 0:
		return
	var type: String = event.get("type", "")
	if type == StylePoints.CLOSE_CALL or type == StylePoints.DODGE:
		Sfx.play("hunt/escaped")
