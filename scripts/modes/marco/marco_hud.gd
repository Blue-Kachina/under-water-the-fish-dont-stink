class_name MarcoHud
extends ModeHud
## What Marco Polo tells the core HUD (hud.gd): the survivor cam hint (Y swaps
## follow and free cam, no controls line) and the name-plate filter (the seeker
## sees a hider's plate only once they show). The mode's own panels are
## MarcoPoloHud, a CanvasLayer the match adds itself.

var game: MarcoPoloMatch
var _hud: Node


func _init(match_node: MarcoPoloMatch) -> void:
	game = match_node
	restart_hint = "restart match"
	camera_word = "follow/free"


func attach(hud: Node) -> void:
	_hud = hud
	hud.survivor_cam = true
	hud.plate_filter = game.shows_plate


func detach() -> void:
	if is_instance_valid(_hud):
		_hud.survivor_cam = false
		_hud.plate_filter = Callable()
	_hud = null


func live() -> bool:
	return is_instance_valid(game)
